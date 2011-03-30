#!/usr/bin/perl -p

# this replaces the pre-1.88 colors by 1.88-style colors.

# use this script as a filter, like you would an awk program, e.g.
# mend_colors.pl ~/.pfm/.pfmrc > ~/.pfm/.pfmrc.new


BEGIN {
    %attributes = reverse (
                               'black'      => 30,  'on_black'   => 40,
        'reset'      => '00',  'red'        => 31,  'on_red'     => 41,
        'bold'       => '01',  'green'      => 32,  'on_green'   => 42, 
        'underline'  => '04',  'yellow'     => 33,  'on_yellow'  => 43,
                               'blue'       => 34,  'on_blue'    => 44,
        'blink'      => '05',  'magenta'    => 35,  'on_magenta' => 45,
        'inverse'    => '07',  'cyan'       => 36,  'on_cyan'    => 46,
        'concealed'  => '08',  'white'      => 37,  'on_white'   => 47,
    );
}

!/^#/ && /[=;]/ && s/\b([034]\d)\b/$attributes{$1}/g && tr/;/ /;

