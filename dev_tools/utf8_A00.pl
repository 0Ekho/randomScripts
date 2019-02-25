#!/usr/bin/env perl

=encoding utf8

=pod LICENSE

 BSD-0
 Copyright (C) 2018, Ekho <ekho@ekho.email>

 Permission to use, copy, modify, and/or distribute this software for any
 purpose with or without fee is hereby granted.

 THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 ------------------------------------------------------------------------------

=cut

=head4

 script to convert UTF-8 strings into uint8_t arrays of HD44780U Codepage A00
 for use with AVR microcontrollers
 Example usage:
     `./utf8_A00.pl 'English & ﾆﾎﾝｺ'`

=cut

# -----------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

use Encode qw(decode_utf8);
 
binmode(STDOUT, ":utf8");
binmode(STDIN, ":encoding(UTF-8)");

# -----------------------------------------------------------------------------

# 0 is empty / invalid pattern
# codepage is pretty much SHIFT-JIS, with a few replaced / added characters
my @codepoints = (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ' ', '!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ':', ';', '<', '=', '>', '?',
    '@', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '[', '¥', ']', '^', '_',
    '`', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o',
    'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '{', '|', '}', '→', '←',
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

    0,   '｡', '｢', '｣', '､', '･', 'ｦ', 'ｧ', 'ｨ', 'ｩ', 'ｪ', 'ｫ', 'ｬ', 'ｭ', 'ｮ', 'ｯ',
    'ｰ', 'ｱ', 'ｲ', 'ｳ', 'ｴ', 'ｵ', 'ｶ', 'ｷ', 'ｸ', 'ｹ', 'ｺ', 'ｻ', 'ｼ', 'ｽ', 'ｾ', 'ｿ',
    'ﾀ', 'ﾁ', 'ﾂ', 'ﾃ', 'ﾄ', 'ﾅ', 'ﾆ', 'ﾇ', 'ﾈ', 'ﾉ', 'ﾊ', 'ﾋ', 'ﾌ', 'ﾍ', 'ﾎ', 'ﾏ',
    'ﾐ', 'ﾑ', 'ﾒ', 'ﾓ', 'ﾔ', 'ﾕ', 'ﾖ', 'ﾗ', 'ﾘ', 'ﾙ', 'ﾚ', 'ﾛ', 'ﾜ', 'ﾝ', 'ﾞ', 'ﾟ',
    # all characers below are for 5x10 dot display
    '', 'ä', 'β', 'ε', 'μ', 'σ', 'ρ', '', '√', '', '', '×', '¢', '', '', 'ö',
    '', '', 'θ', '∞', 'Ω', 'ü', '∑', 'π', '', '', '千', '万', '円', '÷',   0, '█',
    # not sure on the unicode equivalent of every character in the 5x10 dot
    # section, if you know the missing ones please let me know.
);

my %utf8_cp = map { $codepoints[$_] => $_ } 0..@codepoints - 1;

print("uint8_t string[] = {\n    ");
my $i = 0;
foreach (split //, decode_utf8($ARGV[0])) {
    printf("0x%02X, ", $utf8_cp{$_});
    $i++;
    if ($i % 12 == 0) {
        print("\n    ");
    }
}
print("0x00\n};\n");
