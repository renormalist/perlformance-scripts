#! /usr/bin/env perl

use strict;
use warnings;

local $| = 1; # autoflush

use JSON;
use Data::Dumper;
use File::HomeDir;
use File::Basename "basename", "dirname";
use File::Temp "tempfile";

print "BENCHMARKANYTHING_CONFIGFILE = @{[ $ENV{BENCHMARKANYTHING_CONFIGFILE} || 'undef' ]}\n";
print "Searching files...\n";

my $basename;
my @files = map { chomp;$_ } qx(find ~/perlformance/testplan/XXX74 -type f -name "*.json");

# Sort by their numerical basename; regardless of their testplan
# subdir, and potentially different naming number schemes.
# Schwartzian transformation.
@files =
 map  { $_->[0]                       }
 sort { $a->[1] <=> $b->[1]           }
 map  { [ $_, basename($_, ".json") ] }
 @files;

my %testruns;
my %testplans;

print "Importing files";

my @patched_data;

print "(";
FILE: foreach my $file (@files)
{
        eval
        {
                print ".";

                # ----- read -----
                local $/;
                open (my $FH, "<", $file) or die "cannot open input file: $file\n";
                my $json = <$FH>;
                close $FH;

                # ----- decode -----
                my $data     = JSON::decode_json($json);

                # ----- augment with context -----
                my $testrun  = 0+basename($file, ".json");
                my $testplan = 0+basename(dirname($file));
                print STDERR "Duplicate testrun: $testrun\n" if defined $testruns{$testrun}; # twice?
                push @{$testruns{$testrun}},   $file;
                push @{$testplans{$testplan}}, $testrun;

                # ----- decode -----
                foreach my $chunk (@{$data->{BenchmarkAnythingData}})
                {
                        $chunk->{perlformance_testrun}  = $testrun;
                        $chunk->{perlformance_testplan} = $testplan;
                        push @patched_data, $chunk;
                }
        };
        if ($@)
        {
                print STDERR "[skip:".basename($file)."]";
        }
}
print ")";

# ----- write file -----
print "[";
my ($PATCHED_FH, $patched_filename) = tempfile("perlformance_results_XXXXX", UNLINK => 1);
print $PATCHED_FH JSON->new->encode ({ BenchmarkAnythingData => \@patched_data })
 or die $!;
print "]";

# ----- import into storage -----
my $cmd = "benchmarkanything-storage add $patched_filename";
#print STDERR "$cmd\n";
system ($cmd);

print "\nDone.\n";
