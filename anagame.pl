#!/usr/bin/perl
# My very basic Anagram game
# Copyright (C) 2018 Robert Lee

    # This program is free software: you can redistribute it and/or modify
    # it under the terms of the GNU Affero General Public License as published
    # by the Free Software Foundation, either version 3 of the License, or
    # (at your option) any later version.

    # This program is distributed in the hope that it will be useful,
    # but WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    # GNU Affero General Public License for more details.

    # You should have received a copy of the GNU Affero General Public License
    # along with this program.  If not, see <https://www.gnu.org/licenses/>.


use warnings;
use strict;
our $VERSION = "1.0";

use List::Util qw/shuffle/; # standard with Perl 5.8.0+
BEGIN {
    $ENV{PERL_RL}=" o=0"     # Use best available ReadLine sans ornaments
}
use Term::ReadLine; # shell history

use Pod::Usage;

# declare variables at top-level for scoping.
# declarations run first, then BEGIN-blocks, then initialisers.
my ($wordfile, $start, $end, $allowunsafe, $isunsafe, $alphagrams);
# Command-line options. If you don't install the library, you get a warning and sensible defaults.
BEGIN {

    # defaults set in begin block, to run before getopts.
    $wordfile = "/usr/share/dict/words";
    ($start, $end) = (4, 22); # good for British English ispell dictionary

    # getopts must be in begin block to read the termfix param.
eval { require Getopt::Long;
       Getopt::Long->import("GetOptions");
       Getopt::Long::Configure("auto_version","auto_help");
       GetOptions(
	   "words|file=s" => \$wordfile,
	   "start|begin|min=i" => \$start,
	   "end|fin=i" => \$end,
	   "hints!" => \$alphagrams, # includes -hint
	   "termfix!" => \$allowunsafe,
	   "usage" => sub { pod2usage(-exitval => 0, -verbose => 2) }
	   );
       1 }
    or warn "Install GetOpt::Long from CPAN to enable command-line options.\n".
	"  - Default configuration will be used.\n";

# WORKAROUND:
# Term::ReadLine::GNU is the best implementation, and the one that's
# chosen first if available (at time of writing); however, Perl blocks
# signal handlers until you press enter.  We can work around that using
# unsafe signals (which may cause some corruption but this is minimal
# as we kill the program in the signal handler, at least for SIGINT.)
# So we test for it and tell the user if they need to install it.
    my $isgnu = defined &Term::ReadLine::Gnu::readline;
    if ($isgnu) {
	my $hassafesigs = eval {
	    require Perl::Unsafe::Signals;
	};
	if ($hassafesigs && !$allowunsafe) {
	    warn "Running in safe mode with Term::ReadLine::GNU.\n".
		"To fix ctrl+c to exit, run with --termfix.\n";
	} elsif (!$hassafesigs && !$allowunsafe) {
	    warn "Running in safe mode with Term::ReadLine::GNU.\n".
		"To fix ctrl+c to exit, install Perl::Unsafe::Signals from CPAN\n".
		"then run with --termfix.\n";
	} else {
	    $isunsafe = eval {
		Perl::Unsafe::Signals->import();
		1;
	    };
	    warn "Termfix didn't work; maybe Perl::Unsafe::Signals isn't installed properly.\n" 
		unless $isunsafe;
	}
    }
};


srand;
my $term = Term::ReadLine->new('anagame');

my $answer;


$SIG{'INT'} = sub {print "\nGiving up? The word was $answer\nhttp://www.dictionary.com/browse/$answer\n" if defined $answer; exit 0;};


# gimme a random word
# based on https://www.perlmonks.org/?node_id=1910
# - except we use our own counter as we only check matching lines
sub rndword {
    my $len = shift() + 1;
    my $counter=0;
    my $line;
    open FILE, "<$wordfile" or die "Could not open file: $wordfile\n";
    length($_) == $len and /^[[:lower:]]+$/  # skip lines that aren't valid words
	and rand(++$counter)<1  # increment counter and do a 1-in-COUNT chance of continuing
	and ($line=$_) # overwrite with this line if 1-in-COUNT passed. Mathemagically makes a uniform distribution regardless of file length.
	while (<FILE>); # ... for each line.
    close FILE;
    die "No suitable word. Try again?" unless defined $line;
    chomp $line;
    return $line;
}

# read a line; with workaround to use unsafe signals only if needed and available:
sub readlin {
    my $prompt = shift;
    if ($isunsafe) {
	UNSAFE_SIGNALS {
	    return $term->readline($prompt);
	};
    } else {
	return $term->readline($prompt);
    }
};


# prompt until correct.
sub play {
    my $anagram = shift;
    $answer = shift;
    my $clue = shift;
    my $hint = defined $clue ? " (hint: $clue)" : "";
    my $prompt = "Which word is: [$anagram]$hint? ";
    
  play:
    my $guess = readlin $prompt;
    kill INT => $$ unless defined $guess;
    $guess = lc $guess;
    chomp $guess;
    if (lc $answer eq lc $guess) {
	print "Correct!\n";
	return;
    }
    print "No; guess again...\n";
    goto play; # yeah, but there are many ways to do an infinite loop. They all compile down to this anyway.
}

for my $len ($start..$end) {
    eval {
	print "length=$len\n";
	my $answer = rndword($len);

	# join/split method seems fastest https://stackoverflow.com/questions/8840917/perl-sort-characters-within-a-string#
	my $anagram = $answer;
	for (1..3) {
	    last unless $anagram eq $answer;
	    $anagram = join '', shuffle split (//, lc $answer);
	}
	my $alphagram;
	$alphagram = join '', sort { $a cmp $b } split (//, lc $answer) if $alphagrams;

	play($anagram, $answer, $alphagram);
    };
    print "$@\n" if $@;
}
print "Be seeing you.\n";


__END__

=head1 NAME

Anagame, an anagram training game.

=head1 SYNOPSIS

anagame [--words=/usr/share/dict/words] [--start=4] [--end=22] [--hint]

anagame --version

anagame --help

anagame --usage

 Options:
   -words/w/file	specifies a dictionary file
   -start/s/begin/min	smallest number of letters
   -end/e/fin		largest number of letters
   -hints		enable alphagram hints
   -termfix		fix ctrl+C (terminate signal) under Term::Readline::Gnu
   -version/v		print version information and exit
   -help/h/?		show this message and exit
   -usage/u		show a complete usage manual

Dashes may be doubled and/or equals signs omitted.

=head1 OPTIONS

=over 8

=item B<-words>

    This specifies a dictionary file. Suitable dictionaries are
    available for common spellcheckers such as ispell.  Each line in
    the file should contain a correctly-spelled word.  Any words that
    consist entirely of lower-case letters (in the current locale)
    will be considered as anagram solutions. B<-w> and B<-file> are
    understood as synonyms.

=item B<-start>

    The number of letters in the shortest anagram. This option is an
    integer, although values that are not counting numbers will not
    yield anagrams.  B<-s>, B<-begin> and B<-min> are understood as
    synonyms.


=item B<-end>

    This is the longest length of anagram to attempt to find.
    Completing an anagram of this length may be considered a win. If
    start is greater than end, you will not get any anagrams. This
    option is an integer.  B<-e> and B<-fin> are understood as
    synonyms.

=item B<-hints>

    If set, alphagram hints will be shown on the prompt. Alphagrams
    are the letters of the anagram sorted into alphabetical order; one
    technique for solving anagrams is to memorise the alphagram of
    each word. B<-hint> and B<-h> are understood as synonyms.

=item B<-version>

    Basic version information. B<-v> is understood as a synonym.
    Use of this option will prevent the game from running.

=item B<-help>

    A help message. B<-he> and B<-?> are understood as synonyms.
    Use of this option will prevent the game from running.

=back

=head1 DESCRIPTION

The user is presented with a number of randomised anagrams of
increasing length. Upon solving and typing in the correct word, a
longer anagram puzzle is presented. Where more than one anagram
exists, one specific anagram is required; this assists the user with
learning anagrams.

The user can give up at any time by sending an end-of-file (usually
I<ctrl+D>) or interrupt signal (usually I<ctrl+C>); the solution to
the current anagram will be displayed.

=head1 WARNING

If the dictionary file contains rude words, or other words of dubious
origin, then these may be produced by the program. It has no taste
filter.

The words produced by this game come from the dictionary file of your
computer, and the author of this package is not responsible for them.

=head1 DEPENDENCIES

=over 8

=item B<List::Util>

Standard with Perl 5.8.0+. Used to create the anagrams.

=item B<Term::ReadLine>

Standard with Perl 5.8.0+, but a stub library. This is used for
console interaction. See the section L<READLINE NOTE> below for
compatibility with other Readline packages.

=item B<Perl::Unsafe::Signals>

This package can be installed through B<CPAN>, perhaps like this:
C<perl -MCPAN -e 'install Perl::Unsafe::Signals'>.  This works around
an annoying bug with B<Term::ReadLine::GNU> if used; see the section
on L<READLINE NOTE> for further details. In a nutshell, it allows the
game to exit when you press I<Ctrl+C>, without requiring you to then
press I<Enter>.

=item B<Pod::Usage>

Standard with Perl 5.8.0+. Used along with B<Getopt::Long> for, to
implement the B<help> and B<usage> command-line options.

=item B<Getopt::Long>

This package can be installed through B<CPAN>, perhaps like this:
C<perl -MCPAN -e 'install Getopt::Long'>.  If available, this allows
you to control the game through the command-line options, perhaps to
specify a different dictionary file or to turn on alphagram hints.

=back

=head1 READLINE NOTE

Having installed B<Term::ReadLine>, Anagame has basic support to ask
the user for their guesses. However, some obvious features won't work,
such as using the cursor keys to navigate to previous answers.

To fix this, you can install other packages, such as:

=over 8

=item L<Term::ReadLine::Perl>

This package can be installed through B<CPAN>, perhaps like this:
C<perl -MCPAN -e 'install Term::ReadLine::Perl'>.  This package
provides Perl functions to provide basic shell history.

=item L<Term::ReadLine::Gnu>

This package can be installed through B<CPAN>, perhaps like this:
C<perl -MCPAN -e 'install Term::ReadLine::Gnu'>. The standard
installation requires the GNU B<readline> development files to be
installed on your computer, along with a suitable C language compiler;
Windows users may find this as an optional extra when they install
Perl.  This package will be used in preference to
B<Term::ReadLine::Perl> (or any other implementation) if available, as
it provides additional features, to allow callback handling, password
input and filename completion. These are of no use to Anagame, but we
have no way to indicate this to B<Term::ReadLine>.

=back

If you are unfortunate enough to have I<Term::ReadLine::Gnu>
installed, then it is suggested that you also install
L<Perl::Unsafe::Signals>. As the name suggests, there is a slight risk
to this package, as it can allow the program to be interrupted at any
time, including during memory allocation and deallocation; this may
cause memory corruption that could conceivably be used to breach the
operating system security. To minimise that risk, the unsafe signals
are enabled only when actually asking the user for the response, not
when calculating the anagram itself. There is no risk if the game is
idle waiting for a keypress when an interrupt occurs.

You can further minimise any risk by always running the game as a
regular user, never as a superuser or administrator.

=cut
