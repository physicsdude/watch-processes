#!/usr/bin/perl 
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

=head1 NAME 

watch-processes.pl - keep track of processes on a *nix box

=cut

=head1 DESCRIPTION

You can use this script to get a birds eye view of what processes 
are using resources on a *nix box over time.
I'm sure there are better ways but this is so simple it might just work for you.

=cut

=head1 COMMAND LINE OPTIONS 
=over4
=cut
my %o;
my $result = GetOptions(
        \%o,
		"cpu_min|cm=i",
		"mem_min|mm=i",
		"delay|de=i",
		"proc|p=s",
		"logfile|l=s",
		"verbose|v!",
		"alarm|a!",	
);

=item logfile - the name of the file to log to, default procwatch.log (will be overwritten)
=cut
$o{logfile} ||= 'procwatch.txt';
=item proc - process names (regex) or leave blank for all
=cut
$o{proc}    ||= '.*';
$o{proc}      = qr/$o{proc}/;
=item cpu_min - the minimum cpu usage for one process to trigger logging
=cut
$o{cpu_min} ||= 20;
=item mem_min - the minimum memory usage to trigger logging
=cut
$o{mem_min} ||= 20;
=item delay - (seconds) delay between checks
=cut
$o{delay}   ||= 1;
=item verbose - be verbose or not
=cut
=item alarm - sound a system bell alarm when an offending process is seen
=cut

=back
=cut
open my $logfh, '>', $o{logfile} or die "Couldnt' open logfile '$o{logfile}': $!";
my $headt;
while (1) {
	my @res = `ps auxwww`;

	my $head = shift @res;
	my @headf = split(/\s+/,$head);
	#my $headcmd = pop @headf;
	my $headcount = @headf;
	my $unixtime = time();
	#print "fields: @headf\n";
	if (not $headt) {
		#$headt = '"UNIXTIME","'.join('","',@headf)."\"\n";
		$headt = "UNIXTIME\t".join("\t",@headf)."\n";

		print $logfh $headt;
		mutter($headt);
	}
	foreach my $line (@res) {
# USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
#USER             PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND
#bgmyrek          648  10.7  1.9  3646360 318900   ??  S     9:41AM   0:27.98 /Applications/Firefox.app/Contents/MacOS/firefox -foreground
#USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
#root         1  0.0  0.0  10372   644 ?        Ss   Mar26   0:57 init [3]         

		# get the results of the ps command into a hash
		my (%info,@values,@cmda);
		my $i = 0;
		while ( $line =~ /([^\s]+)(?:\s+)?/g ) {
			if    ( $i <  @headf-1 ) {
				#$info{$headf[$i]}  = $1;
				$values[$i] = $1;
				$i++;
			}
			elsif ( $i == @headf-1 ) {
				#$info{$headf[$i]} .= ' '.$1;
				push(@cmda,$1);
			}
		}
		$values[$i] = join(' ',@cmda);
		@info{@headf} = @values;
		#$info{$headf[$i]} =~ s/^\s//;

		# if the cpu or ram was over the threshold, log it
		if ($info{'%MEM'} > $o{mem_min} or $info{'%CPU'} > $o{cpu_min}) {
			#my $logline = "\"$unixtime\",\"".join('","',@values).'"'."\n";
			my $logline = "$unixtime\t".join("\t",@values)."\n";
			mutter($logline);
			print $logfh $logline;
			print "\a" if $o{alarm};
		}
	}

	sleep $o{delay};
}
close $logfh;

sub whisper { print $_[0] if $o{debug}; }
sub mutter  { print $_[0] if $o{verbose}; }

=head1 EXAMPLE

It's a lot less noisy than top.

$ ./watch-processes.pl --verbose --cpu_min 10 --delay 3
UNIXTIME	USER	PID	%CPU	%MEM	VSZ	RSS	TT	STAT	STARTED	TIME	COMMAND
1381428720	bgmyrek	163	59.8	2.6	4113436	434500	??	R	Wed08AM	30:01.56	/Applications/Mail.app/Contents/MacOS/Mail -psn_0_53261
1381428738	bgmyrek	161	40.4	4.7	3350764	792380	??	S	Wed08AM	43:46.19	/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal -psn_0_45067
...

And it's tab separated, so it's easy to make a graph with the data in openoffice.

=cut

=head1 AUTHOR

Bryan Gmyrek <bryangmyrek@gmail.com>

=cut
