#!/usr/bin/perl

# To those who will use, support or modify this crap :)
#
# This script have (at least, must have :) modal structure.
# It have one bind (/sysinfo) and one main subroutine (sysinfo). Sysinfo call all other subroutines before printing message.
# All subroutines named in "getWhatYouWantToGet" style and placed in the end of script.
# Script have one variable called $format where format of message stored (hard to guess, sure? :). If you want to change format — please change only this variable.


# TODO: Add:
#       - disks usage
#       - network stats
#       - load averages
#       - graphs for RAM and swap usage (something like colored [||||||||||]). It may be called $RAMGraph and $SwapGraph
#       - possibility to change Kb to Mb or Gb in memory info; MHz to GHz in CPU info
#       - load averages (/proc/loadavg)

use strict;
use Irssi;

use vars qw{$VERSION %IRSSI};

$VERSION="0.1";
%IRSSI = (
        name => 'SysInfo',
        authors => 'Minoru',
        contact => 'eual.jp@gmail.com',
        license => 'GPLv3',
        description => 'Print info about your system',
        );

sub sysinfo {
    my ($data,$server,$witem) = @_;

    # If window exist and it's channel or query (no sense to print info to any other window)
    if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
        # Initialize varibles where real values of kernel version, architecture, machine uptime etc. stored
        my $kernelVersion = &getKernelVersion;
        my $uptime = &getUptime;
        my ($CPUModel,$CPUFreq,$bogomips) = &getCPUInfo;
        my ($RAMTotal,$RAMFree,$RAMCached,$SwapTotal,$SwapFree,$SwapCached) = &getMemInfo;
        my ($audioDev,$videoDev) = &getPCIDevsInfo;
    
        # Set format of message. You may use any variables initialized above and codes listed below
        # \002 mean bold (Usage: \002Here is bold text\002)
        # \037 mean underlined text (Usage: \037Here is underlined text\037)
        # \003fg[,bg] — set foreground and background colors (Usage: \0033Here is green text\003  or \0038,1Here is yellow text at black background\003)
        # Table of mIRC colors (it's standard de-facto in IRC world):
        #  0  white
        #  1  black
        #  2  blue
        #  3  green
        #  4  lightred
        #  5  brown
        #  6  purple
        #  7  orange
        #  8  yellow
        #  9  lightgreen
        # 10  cyan
        # 11  lightcyan
        # 12  lightblue
        # 13  pink
        # 14  grey
        # 15  lightgrey
        # NOTE: Irssi can not display all this colors because it run in terminal which have limited number of colors (8, if I remember correctly), but other users (which use X clients, not irssi or wechat :) will see it properly
        my $format = "[\002Kernel:\002 $kernelVersion] [\002Uptime:\002 $uptime] [\002CPU:\002 $CPUModel $CPUFreq MHz] [\002RAM:\002 $RAMFree/$RAMTotal free ($RAMCached cached)] [\002Swap:\002 $SwapFree/$SwapTotal free ($SwapCached cached)] [\002Audio:\002 $audioDev] [\002Video:\002 $videoDev]";
        # Print message to current channel or query (if it exist)
        $witem->command("MSG " . $witem->{name} . " $format");
    }
}

sub getKernelVersion {
    # Return kernel version
    open(OSR,"/proc/sys/kernel/osrelease") || die "Can't open /proc/sys/kernel/osrelease: $!";
    my $osrelease = <OSR>;
    close(OSR) || die "Can't close /proc/sys/kernel/osrelease: $!";
    chomp($osrelease);
    return $osrelease;
}

sub getUptime {
    # Return uptime

    open(UPTIME,"/proc/uptime") || die "Can't open /proc/uptime: $!";
    my ($uptime,$idle) = split "\s", <UPTIME>;
    close(UPTIME) || die "Can't close /proc/uptime: $!";
    # $uptime now contain uptime of system in seconds
    # Let's split it to minutes, hours, days, months and years
    my $seconds = $uptime % 60;
    $uptime /= 60; # $uptime now contain uptime in minutes
    my $minutes = $uptime % 60;
    $uptime /= 60; # $uptime now contain uptime in hours
    my $hours = $uptime % 24;
    $uptime /= 24; # $uptime now contain uptime in days
    my $days = $uptime % 30;
    $uptime /= 30; # $uptime now contain uptime in monts
    my $months = $uptime % 12;
    $uptime /= 12; # $uptime now contain uptime in years
    my $years = $uptime;

    my $msg = ""; # this is what we will return
    $msg .= "$years years, " if $years >= 1;
    $msg .= "$months months, " if $months != 0;
    $msg .= "$days days, " if $days != 0;
    $msg .= "$hours:";
    if ($minutes < 10)
    {
        $msg .= "0$minutes";
    } else {
        $msg .= "$minutes";
    };

    return $msg;
}

sub getCPUInfo {
    # Return info about your CPU
    my ($crap,$line,$model,$freq,$bogomips);
    open(PROC, "/proc/cpuinfo") || die "Can't open /proc/cpuinfo: $!";
    while(defined($line = <PROC>)) {
        chomp $line;
        $line =~ s/\s+/ /g;
        if ($line =~ /^model name/) {
            ($crap,$model) = split " : ", $line;
        }
        elsif ($line =~ /^bogomips/) {
            # In fact, BogoMIPS isn't that value which can be used for comparing computers, so I get it (may be somebody will be interested to show it to others), but don't show in message by default
            # Change $format variable in sysinfo subroutine if you want to show bogomips value to others
            ($crap,$bogomips) = split " : ", $line;
        }
        elsif ($line =~ /MHz/) {
            ($crap,$freq) = split " : ", $line;
        }
    }
    close(PROC) || die "Can't close /proc/cpuinfo";
    return ($model,$freq,$bogomips);
}

sub getMemInfo {
    # Return info about RAM and swap
    my ($crap,$line,$RAMTotal,$RAMFree,$RAMCached,$SwapTotal,$SwapFree,$SwapCached);
    open(MEM,"/proc/meminfo") || die "Can't open /proc/meminfo: $!";
    while(defined($line = <MEM>)) {
        chomp $line;
        $line =~ s/\s+/ /g;
        if ($line =~ /^MemTotal/) {
            ($crap,$RAMTotal) = split ": ", $line;
        }
        elsif ($line =~ /^MemFree/) {
            ($crap,$RAMFree) = split ": ", $line;
        }
        elsif ($line =~ /^Cached/) {
            ($crap,$RAMCached) = split ": ", $line;
        }
        elsif ($line =~ /^SwapTotal/) {
            ($crap,$SwapTotal) = split ": ", $line;
        }
        elsif ($line =~ /^SwapFree/) {
            ($crap,$SwapFree) = split ": ", $line;
        }
        elsif ($line =~ /^SwapCached/) {
            ($crap,$SwapCached) = split ": ", $line;
        }
    }
    close(MEM) || die "Can't close /proc/meminfo: $!";
    return ($RAMTotal,$RAMFree,$RAMCached,$SwapTotal,$SwapFree,$SwapCached);
}

sub getPCIDevsInfo {
    my ($line,$crap,$busID,$audioDev,$videoDev);
    open(LSPCI,"lspci|") || die "Can't open lspci output: $!";
    while(defined($line = <LSPCI>)) {
        chomp($line);
        $line =~ s/\d\d:[\da-f]{2}.\d //;
        if($line =~ /audio/i) {
            ($crap,$audioDev) = split ": ", $line;
        } elsif ($line =~ /vga/i) {
            ($crap,$videoDev) = split ": ", $line;
        }
    }
    close(LSPCI) || die "Can't close reading lspci output: $!";
    return ($audioDev,$videoDev);
}

Irssi::command_bind sysinfo => \&sysinfo;

