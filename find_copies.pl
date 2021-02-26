#!/usr/bin/env perl

# name:       find_copies.pl
# version:    0.0.2
# date:       20210223
# desc:       Tool to help clean up old versions of files.

## TODO

use strict;
use warnings;
use File::Basename;
use Data::Dumper;
use Getopt::Long;

my %known_dirs;
my %known_files;
my @dir_queue;

# Used to see how many copies we have.
my $total_file_count  = 0;
my $actual_file_count = 0;
my $logdir;     
my $exclude_list_file;
my %exclude_list;
my $exclude_dir_file;
my %exclude_dir;
my $seed_file;     # The results of 'locate <filename>'.

my $output_dir;

# Methods
sub usage {
  print "Usage: find_copies.pl --file <path/seed_file> \n";
  print "  --logdir \n";
  print "  --exclude_list <file of files to not deal with> \n";
  exit;
};

# Pretty sure these could be made into one method.
sub build_exclude_dir {
  open my $exclude_dirs, '<', $exclude_dir_file or die "Can't open $exclude_dir_file: $!";
  for my $dir ( <$exclude_dirs> ) { 
    chomp $dir;
    if ( -d $dir ) {
      $exclude_dir{$dir} = 1;
    }
  }
  close $exclude_dirs;
}

sub build_exclude_list {
  open my $exclude_files, '<', $exclude_list_file or die "Can't open $exclude_list_file: $!";
  for my $file ( <$exclude_files> ) {
    chomp $file;
    $exclude_list{$file} = 1;
  }
  close $exclude_files;
}

sub build_file_list {
  foreach my $search_dir ( @dir_queue ) {
    opendir( my $dir, $search_dir ) or die "Can't open $search_dir: $!";
    foreach my $file ( readdir($dir)) {
      next if $file =~ m/^\.\.?$/;
      if ( -d "$search_dir/$file" ) {
        next if ( defined ($exclude_dir{"$search_dir/$file"}) );
        $known_dirs{"$search_dir/$file"} = 1;
        push ( @dir_queue, "$search_dir/$file");
      } else {
        next if ( defined( $exclude_list{$file} ));
        $total_file_count++;
        my $size = -s "$search_dir/$file";
        $known_files{$file}{$size} = 1;
      }
    }
    closedir($dir);
  }
}

sub write_list_to_logfile {
  my ( $list, $logfile ) = @_;
  open my $file, '>', $logfile or die "Can't open $logfile: $!";
  foreach my $line ( @$list ){
    print $file "$line\n";
  }
  close $file;
}

sub write_log { 
  my ( $dir ) = @_;
  #print Dumper(%known_files);
  $actual_file_count = scalar(keys(%known_files));
  print "With $actual_file_count unique files, there are $total_file_count copies.\n";
  my @single_version_files;
  my @multiple_version_files;
  foreach my $file ( keys( %known_files ) ){
    my @values = keys(%{$known_files{$file}});
    if ( scalar(@values)  > 1 ) {
      push @multiple_version_files, $file;
    } else {
      push @single_version_files, $file;
    }
  }
  @multiple_version_files  = sort(@multiple_version_files);
  @single_version_files    = sort(@single_version_files);
  if ( scalar( @multiple_version_files ) ) {
    my $mvf_filename = "$dir/multiple_version_files.list";
    write_list_to_logfile(\@multiple_version_files, $mvf_filename);
  }
  if ( scalar( @single_version_files ) ){
    my $svf_filename = "$dir/single_version_files.list";
    write_list_to_logfile(\@single_version_files, $svf_filename);
  }
  if ( keys(%exclude_dir) ){
    my @excluded_dirs = ( keys(%exclude_dir) );
    my $excluded_dirs_filename = "$dir/excluded_dirs.list";
    write_list_to_logfile(\@excluded_dirs, $excluded_dirs_filename);
  }
  if ( keys( %exclude_list ) ) {
    my @excluded_files = keys(%exclude_list);
    my $excluded_files_filename = "$dir/excluded_files.list";
    write_list_to_logfile(\@excluded_files, $excluded_files_filename);
  }
  if ( keys(%known_dirs) ) {
    my @known_dirs = keys(%known_dirs);
    my $known_dirs_filename = "$dir/known_dirs.list";
    write_list_to_logfile(\@known_dirs, $known_dirs_filename);
  }
}

GetOptions(
  "--logdir=s"        => \$logdir,
  "--file=s"          => \$seed_file, 
  "--exclude_files=s" => \$exclude_list_file,
  "--exclude_dirs=s"  => \$exclude_dir_file,
);

usage() unless ( defined($seed_file) );
open my $seed_data_file, '<', $seed_file or die "Can't open $seed_file: $!";

build_exclude_list() if $exclude_list_file;
build_exclude_dir() if $exclude_dir_file;

# Build the list of directories to search.
for my $line ( <$seed_data_file>) {
  chomp $line;
  my $dirname   = dirname($line);
  $known_dirs{$dirname} = 1 unless defined( $exclude_dir{$dirname} );
  push( @dir_queue, $dirname);
}
close $seed_data_file;

build_file_list();

if ( defined($logdir) ){
  unless ( -d $logdir ) {
    mkdir $logdir;
  }
  write_log($logdir);
}



