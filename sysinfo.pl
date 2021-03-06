#!/usr/bin/perl

#
#  irssi sysinfo script
#

#
#   Copyright 2009, 2010 Alexander Batischev <eual.jp@gmail.com>
#

#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use Irssi;

use vars qw{$VERSION %IRSSI %SYSINFO};

$VERSION="0.4.1";
%IRSSI = (
        name => 'SysInfo',
        authors => 'Alexander Batischev aka Minoru',
        contact => 'eual.jp@gmail.com',
        license => 'GPLv3',
        description => 'Prints info about your Linux PC',
        );

my $help = <<EOF;

  SysInfo Script by Minoru (eual.jp\@gmail.com)
================================================================

\002USAGE:\002
/sysinfo [help]

/sysinfo       Prints information about your system to current channel or query.
/sysinfo help  Prints this text
EOF

# This variables are in global scope for a performance optimization
# They will be initialized at first run of sysinfo subroutine
# Values represented by this variables can not be changed during runtime for
# hardware reasons so there are no need to re-initialize them on each run of
# 'sysinfo' subroutine
# Parts of CPU and RAM info can't be optimized that way due to script
# architecture limitations
my $kernelVersion = "";
my $audioDev      = "";
my $videoDev      = "";
 

sub sysinfo {
    my ($data,$server,$witem) = @_;

    # If window exist and it's channel or query (no sense to print info to any
    #  other window)
    if ($data eq "help") {
        print $help;
    } else {
        if ($witem && ($witem->{type} eq "CHANNEL"
                                                || $witem->{type} eq "QUERY")) {

            if ($kernelVersion == "") {
                $kernelVersion = &getKernelVersion;
            }
            my $uptime = &getUptime;
            my ($CPUModel,$CPUFreq,$bogomips) = &getCPUInfo;
            my ($RAMTotal,$RAMFree,$RAMUsed,$RAMCached,
                      $swapTotal,$swapFree,$swapUsed,$swapCached) = &getMemInfo;
            if ($audioDev eq "" && $videoDev eq "") {
                ($audioDev, $videoDev) = &getPCIDevsInfo;
            }
            my ($loadAvg1,$loadAvg5,$loadAvg10,$processesRunnning,
                                                 $processesTotal) = &getLoadAvg;
            my ($disksTotal,$disksUsed,$disksFree) = &getDisksInfo;
            my ($netReceived, $netTransmitted) = &getNetInfo;
        
            # Set format of message. You may use any variables initialized above
            # and codes listed below
            # \002 mean bold (Usage: \002Here is bold text\002)
            # \037 mean underlined text (Usage: \037Here is underlined text\037)
            # \003fg[,bg] — set foreground and background colors
            #  (Usage: \0033Here is green text\003  or \0038,1Here is yellow
            #  text at black background\003)
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
            # NOTE: Irssi can not display all this colors because it run in
            #  terminal which have limited number of colors (8, if I remember
            #  correctly), but other users (which use X clients, not irssi or
            #  wechat :) will see it properly
            my $format = "[\002Kernel:\002 $kernelVersion]";
            $format .= " [\002Uptime:\002 $uptime]";
            $format .= " [\002CPU:\002 $CPUModel $CPUFreq]";
            $format .= " [\002Load average:\002 $loadAvg1 $loadAvg5 " .
                                                                  "$loadAvg10]";
            $format .= " [\002RAM:\002 $RAMUsed of $RAMTotal used]";
            $format .= " [\002Swap:\002 $swapUsed of $swapTotal used]";
            $format .= " [\002Disks:\002 $disksFree of $disksTotal free]";
            $format .= " [\002Network:\002 $netReceived received, " .
                                                 "$netTransmitted transmitted]";
            $format .= " [\002Audio:\002 $audioDev] [\002Video:\002 $videoDev]";
            # Print message to current channel or query (if it exist)
            #$witem->command("MSG " . $witem->{name} . " $format");
            # Following code send message part-by-part if ir may be wrapped by
            #  server
            my $header = $server->{userhost};
            $header =~ s/^~//;
            $header = ":" . $server->{nick} . "!" . $header . " PRIVMSG "
                                                        . $witem->{name} . " :";
            
            my $canBeSent = 512 - length($header);
            if (length($format) <= $canBeSent) {
                # If message can be sent without being wrapped — just send it!
                $witem->command("MSG " . $witem->{name} . " $format");
            } else {
                my $msg = $format;
                my $i = 0;
                while (length($msg) > 0) {
                    my $tmp = substr $msg, 0, $canBeSent;
                    $witem->command("MSG " . $witem->{name} . " $tmp");
                    $msg =~ s/.{0,$canBeSent}//;
                    $i++; if ($i > 3) { last };
                }
            }
        }
    }
}

sub getKernelVersion {
    # Return kernel version
    open(OSR,"/proc/sys/kernel/osrelease")
                             || die "Can't open /proc/sys/kernel/osrelease: $!";
    my $osrelease = <OSR>;
    close(OSR) || die "Can't close /proc/sys/kernel/osrelease: $!";
    chomp($osrelease);
    return $osrelease;
}

sub getUptime {
    # Returns uptime

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
    
    if ($years >= 1) {
        if ($years == 1) {
            $msg .= "1 year";
        } else {
            $msg .= "$years years";
        }
        $msg .= ", "
    }
    
    if ($months != 0) {
        if ($months == 1) {
            $msg .= "1 month"
        } else {
            $msg .= "$months months"
        }
        $msg .= ", "
    }
    
    if ($days != 0) {
        if ($days == 1) {
            $msg .= "1 day"
        } else {
            $msg .= "$days days"
        }
        $msg .= ", "
    }
    
    $msg .= "$hours:";
    if ($minutes < 10)
    {
        $msg .= "0$minutes";
    } else {
        $msg .= "$minutes";
    };
    if ($seconds < 10)
    {
        $msg .= ":0$seconds";
    } else {
        $msg .= ":$seconds";
    }

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
            # In fact, BogoMIPS isn't that value which can be used for comparing
            #  computers, so I get it (may be somebody will be interested to
            #  show it to others), but don't show in message by default
            # Change $format variable in sysinfo subroutine if you want to show
            #  bogomips value to others
            ($crap,$bogomips) = split " : ", $line;
        }
        elsif ($line =~ /MHz/) {
            ($crap,$freq) = split " : ", $line;
        }
    }
    close(PROC) || die "Can't close /proc/cpuinfo";
    # Convert MHz to GHz is freq is more than 1000
    my ($freq_num,$numeric) = split " ", $freq;
    if ($freq_num > 1000) {
        $freq = $freq_num / 1000;
        # Keep 1 digit after decimal point
        $freq = sprintf("%.1f", $freq);
        $freq .= " GHz";
    } else {
        $freq .= " MHz";
    };
    return ($model,$freq,$bogomips);
}

sub kbToOther {
    # Convert KB to MB and GB
    my $size = $_[0];
    my $numeric = "KB";
    $size =~ s/\s+.*/ /g;
    if ($size >= 1048576) { # if size is more than GB
        $size = $size / 1048576;
        $numeric = "GB";
    } elsif ($size >= 1024) { # if size is more than MB
        $size = $size / 1024;
        $numeric = "MB";
    }
    # It may be writen as "use POSIX; ... $size = POSIX::floor($size);" too,
    #  but...
    # ... but I didn't use POSIX anywhere here so why should I use it here? :)
    $size = sprintf("%.0f", $size);
    return $size . " " . $numeric;
}

sub getMemInfo {
    # Return info about RAM and swap
    my ($crap,$line,$RAMTotal,$RAMFree,$RAMUsed,$RAMCached,
                                    $SwapTotal,$SwapFree,$SwapUsed,$SwapCached);
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

    $RAMUsed  = $RAMTotal  - $RAMFree  - $RAMCached;
    $SwapUsed = $SwapTotal - $SwapFree - $SwapCached;

    $RAMTotal   = &kbToOther($RAMTotal);
    $RAMFree    = &kbToOther($RAMFree);
    $RAMUsed    = &kbToOther($RAMUsed);
    $RAMCached  = &kbToOther($RAMCached);
    $SwapTotal  = &kbToOther($SwapTotal);
    $SwapFree   = &kbToOther($SwapFree);
    $SwapUsed   = &kbToOther($SwapUsed);
    $SwapCached = &kbToOther($SwapCached);

    return ($RAMTotal,$RAMFree,$RAMUsed,$RAMCached,
                                    $SwapTotal,$SwapFree,$SwapUsed,$SwapCached);
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

sub getLoadAvg {
    my ($crap,$loadAvg1,$loadAvg5,$loadAvg10,$processesRunning,$processesTotal,
                                                                $processesInfo);
    open(LOADAVG,"/proc/loadavg") || die "Can't open /proc/loadavg: $!";
    ($loadAvg1,$loadAvg5,$loadAvg10,$processesInfo,$crap) 
                                                         = split " ", <LOADAVG>;
    close(LOADAVG) || die "Can't close /proc/loadavg: $!";
    ($processesRunning,$processesTotal) = split "/", $processesInfo;
    return ($loadAvg1,$loadAvg5,$loadAvg10,$processesRunning,$processesTotal);
}

sub getDisksInfo {
    my ($disksTotal, $disksUsed, $disksFree) = (0,0,0);
    # Run df and read output
    open(DF,"df|") or die "Can't run df: $!";
    my $line;
    # Skip first line - it's header, we don't need it
    $line = <DF>;
    while(defined($line = <DF>)) {
        chomp $line;
        if($line =~ m#^/dev/#) {
            # Process only those lines which starts with /dev/
            $line =~ s/\s+/ /g;
            my ($name,$size,$used,$free,$percent,$mount) = split " ", $line;
            $disksTotal += $size;
            $disksUsed += $used;
            $disksFree += $free;
        }
    }
    close(DF) or die "Can't finish reading df's output: $!";
    # Now we have sizes of total, used and free space in Kbytes. Let's convert
    #  it to normal format via kbToOther
    $disksTotal = &kbToOther($disksTotal);
    $disksFree = &kbToOther($disksFree);
    $disksUsed = &kbToOther($disksUsed);
    return ($disksTotal, $disksUsed, $disksFree);
}

sub getNetInfo {
    my ($received, $transmitted, $crap, $line);
    open(NETDEV,"/proc/net/dev") or die "Can't open /proc/net/dev: $!";
    # Skip first two lines, which contain names of rows
    $crap = <NETDEV>;
    $crap = <NETDEV>;
    while(defined($line = <NETDEV>)) {
        chomp $line;
        if ($line =~ "$SYSINFO{'network_interface'}") {
            # Remove first space symbols
            $line =~ s/^\s*//g;
            # Remove name of interface
            $line =~ s/.*://g;
            $line =~ s/\s+/ /g;
            # We need to remove first space symbols again because line may look
            #  like "eth1:   3545"
            $line =~ s/^\s*//g;
            # Read data
            ($received,$crap,$crap,$crap,$crap,$crap,$crap,$crap,$transmitted,
                  $crap,$crap,$crap,$crap,$crap,$crap,$crap) = split " ", $line;
        }
    }
    close(NETDEV) or die "Can't close /proc/net/dev: $!";
    $received = kbToOther(sprintf("%.0f", $received/1024));
    $transmitted = kbToOther(sprintf("%.0f", $transmitted/1024));
    return ($received, $transmitted);
}

Irssi::settings_add_str('sysinfo', 'network_interface', 'ppp0');

Irssi::command_bind sysinfo => \&sysinfo;

