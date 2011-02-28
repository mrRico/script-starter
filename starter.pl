#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Digest::MD5 qw();
use POSIX qw(:errno_h :sys_wait_h :signal_h);

=head1 NAME

    starter.pl    

=head1 DESCRIPTION

    Starts and maintains a system of a specified number of copies of a given script.

=head1 SYNOPSIS
   
   perl starter.pl --workers 5 --script "perl path_to/any_script.pl --any param"

=head1 NOTE
   
    start this script over cron

=cut

{  
    my ($num,$lib_dirs,$script,$help,$work_dir,$pid_dir) = (0);   
        GetOptions(
            'lib_dirs=s' => \$lib_dirs,
            'script=s' => \$script,
            'help' => \$help,
            'workers=i' => \$num,
            'work_dir=s' => \$work_dir,
            'pid_dir=s' => \$pid_dir
        );   
   
    # directory to hold semaphores
    $pid_dir ||= '/var/spool/fork_demon/pids/';
    # path to create tmp-file for childs
    $work_dir ||= '/var/spool/fork_demon/work/';
    
    die "Pleese create $pid_dir or enable access"   unless (-d $pid_dir  and -w _);
    die "Pleese create $work_dir or enable access"  unless (-d $work_dir and -w _);
    die "Script not found" unless $script;
    my $md5_script = Digest::MD5::md5_hex($script);
    
    $num ||= 1;
    
    # show --help
    if ($help) {
        print "
        Example
            perl starter.pl --workers 5 --script \"perl path_to/any_script.pl --any param\"
        ";
        exit(0);
    }
    
    # separator for semaphores file name
    my $sp = '_';
    
    # read file from semaphores directory
    $pid_dir .= '/' unless $pid_dir =~ /\/$/;
    local *DIR;
    opendir(DIR,$pid_dir) or die $!;
        my $running = 0;
        while (my $sem = readdir(DIR)) {
            next unless $sem;
            next if $sem =~ /^\./;
            next unless -f $pid_dir.$sem;
            my($pid) = $sem =~ /${sp}(\d+)$/o;
            unless ($pid and kill(0,$pid)) {
                unlink("${pid_dir}${sem}");
                next;
            };
            $running++ if $sem =~ /${md5_script}${sp}\d+/;
        }
    closedir(DIR);

    # doing fork
    while ($running < $num) {
        if (my $pid = fork()) {
            # parent
            # create semaphore for child
            my $fn = $pid_dir.$md5_script.$sp.$pid;
            open(FILE,">$fn") ? close(FILE) : die("Cant't create semaphore file for pid '$fn': $!") unless -e $fn;
            $running++;
        } else {
            # child
            # disable parents output
            close STDOUT;
            close STDIN;
            # change to $work_dir
            chdir $work_dir;
            # broken links to parent
            die("[$pid] Can't detach from parents process") unless POSIX::setsid();
            # start scripts in this child
            exec $script;
            die( "Can't start script '$script': $!");
        }
    }
   
}

exit(0);