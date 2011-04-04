#!/usr/bin/perl -p

# this updates quoting in commands for version 1.89

# use this script as a filter, like you would an awk program, e.g.
# mend_quotes.pl ~/.pfm/.pfmrc > ~/.pfm/.pfmrc.new

BEGIN {
	$warned = 0;
}

s/(['"])(\\[1-6])\1/$2/g;
s/(printcmd:.*)/$1 \\2/g;

/cp.*date.*touch.*date/ && s/"(
	[^"()]*
	\$\(
		[^")]*
		(?:"[^"]*")*
	\)
)"/$1/gx;

if (/\$\(.*\)/ and !$warned) {
	print STDERR "Quoting \$(..) constructs can be tricky.\nPlease double-check your .pfmrc. I'm imperfect.\n";
	$warned++;
}


