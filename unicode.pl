#!/usr/bin/perl
use warnings;
use strict;

use HTML::Entities qw(encode_entities decode_entities);
use Unicode::UCD qw(charinfo);
use charnames qw();
use Text::Iconv;
use Encode;
use open ":encoding(utf8)";

my $table;

sub preamble {
    return if $table;
    $table = 1;
    print(<<"END");
<table class="unicodeCharacterTable">
<thead>
<tr>
<th>Windows</th>
<th colspan="3">Codepoint</th>
<th>Character Name</th>
<th>Glyph</th>
<th>Comments</th>
</tr>
</thead>
<tbody>
END
}

sub postamble {
    return if !$table;
    $table = 0;
    print(<<"END");
</tbody>
</table>
END
}

use vars qw($current_section_name);

sub section {
    my ($section_name) = @_;
    postamble();
    if ($section_name ne "-") {
	my $h_section_name = $section_name;
	unless ($h_section_name =~ s{^HTML:}{}) {
	    $h_section_name = encode_entities($section_name);
	}
	printf("<h2>%s</h2>\n", $h_section_name);
	$current_section_name = $section_name;
    }
    preamble();
}

while (<>) {
    chomp();
    s{\r}{};
    next unless m{\S};
    next if m{^\s*\#};
    my $comment;
    s{^\s+}{};
    s{\s+$}{};
    s{\s+}{ }g;
    if (s{(^|\s+)\#+\s*(.*?)\s*$}{}) {
	$comment = $2;
    }
    if (m{^\s*U\+([0-9A-Fa-f]+)}i) {
	if (!hexadecimal_codepoint($1, $comment)) {
	}
    }
    elsif (m{^\s*(\&\S+\;)}) {
	if (!entity($1, $comment)) {
	}
    }
    elsif (defined(my $codepoint = charnames::vianame(uc $_))) {
	if (!decimal_codepoint($codepoint, $comment)) {
	}
    }
    elsif (m{^\s*\@section\s+(.*?)\s*$}i) {
	if (!section($1)) {
	}
    }
    elsif (m{^\s*-+\s*$}) {
	section("-");
    }
    elsif (length($_) == 1) {
	character($_);
    }
    else {
	warn(length($_));
	warn("No match for '$_'\n");
    }
}
postamble();

###############################################################################
sub commaize {
    my ($number) = @_;
    foreach (my $p = length($number) - 3;
	     $p > 0;
	     $p -= 3) {
	substr($number, $p, 0) = ",";
    }
    return $number;
}
sub hexadecimal_codepoint {
    my ($hex, $comment) = @_;
    decimal_codepoint(hex($hex), $comment);
}
sub entity {
    my ($entity, $comment) = @_;
    my $dec = decode_entities($entity);
    character($dec, $comment);
}
sub character {
    my ($char, $comment) = @_;
    decimal_codepoint(ord($char), $comment);
}

use vars qw(%CP437);
BEGIN {
    %CP437 = (
	0x263A => 1,
	0x263B => 2,
	0x2665 => 3,
	0x2666 => 4,
	0x2663 => 5,
	0x2660 => 6,
	0x2022 => 7,
	0x25D8 => 8,
	0x25CB => 9,
	0x25D9 => 10,
	0x2642 => 11,
	0x2640 => 12,
	0x266A => 13,
	0x266C => 14,
	0x263C => 15,
	0x25BA => 16,
	0x25C4 => 17,
	0x2195 => 18,
	0x203C => 19,
	0x00B6 => 20,
	0x00A7 => 21,
	0x25AC => 22,
	0x21A8 => 23,
	0x2191 => 24,
	0x2193 => 25,
	0x2192 => 26,
	0x2190 => 27,
	0x221F => 28,
	0x2194 => 29,
	0x25B2 => 30,
	0x25BC => 31,
	0x2302 => 127,
       );
}

sub get_alt_code {
    my ($chr) = @_;
    my $ord = ord($chr);

    my $windows_1252 = encode("windows-1252", $chr);
    my $cp_437       = encode("cp437", $chr);
    if (!defined $cp_437 || $cp_437 eq "" || $cp_437 eq "?") {
	if (defined $CP437{$ord}) {
	    $cp_437 = chr($CP437{$ord});
	    if (!$cp_437 || !ord($cp_437)) {
		undef $cp_437;
	    }
	}
    }

    my $alt_A;
    if (defined $cp_437 && $cp_437 ne "" && $cp_437 ne $chr && $cp_437 ne "?") {
	$alt_A = "Alt+" . ord($cp_437);
    } else {
	undef $alt_A;
    }

    my $alt_B;
    if (defined $windows_1252 && $windows_1252 ne "" && ord($windows_1252) >= 128 && ord($windows_1252) <= 255) {
	$alt_B = "Alt+0" . ord($windows_1252);
    } else {
	undef $alt_B;
    }

    if ($current_section_name =~ m{\b437\b}) {
	return $alt_A // $alt_B // "";
    } else {
	return $alt_B // $alt_A // "";
    }
}

sub decimal_codepoint {
    my ($dec, $comment) = @_;
    $comment //= "";

    my $h_comment;
    if ($comment =~ s{^HTML:}{}) {
	$h_comment = $comment;
    } else {
	$h_comment = encode_entities($comment);
    }

    my $chr = chr($dec);
    my $charinfo = charinfo($dec);

    my $h_decimal    = commaize($dec);
    my $h_entity     = encode_entities(encode_entities($chr));
    my $h_codepoint  = "U+" . sprintf("%04X", $dec);
    my $h_charname   = encode_entities($charinfo->{name});
    my $h_glyph      = encode_entities($chr);
    my $h_win        = get_alt_code($chr);

    preamble if !$table;
    print(<<"END");
<tr>
<td class="win">$h_win</td>
<td class="decimal">$h_decimal</td>
<td class="html-entity">$h_entity</td>
<td class="hexadecimal">$h_codepoint</td>
<td class="charname">$h_charname</td>
<td class="glyph"><span class="glyph">$h_glyph</span></td>
<td class="comment">$h_comment</td>
</tr>
END
}

__DATA__

