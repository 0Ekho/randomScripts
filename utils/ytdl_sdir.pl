#!/usr/bin/env perl

=encoding utf8

=pod LICENSE

 BSD-0
 Copyright (C) 2018, Ekho <ekho@ekho,email>

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

 script to use metadata files from youtube-dl to sort videos from a specified
 channel into their own directory.

 Don't actually use this, it's slow, and buggy, and overall bad

 Usage:
    ytdl_sdir.pl "uploader_id" "metadata dir" "in dir" "out dir"
 Example:
    $ ytdl_sdir.pl "theCodyReeder" "Video/+meta" "Video/ytdl" "Video/codyslab"

=cut

# -----------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

use File::Basename qw(basename);
use File::Copy qw(move);
use JSON::MaybeXS qw(decode_json);
use List::Util qw(first);
use Path::Tiny qw(path);

binmode(STDOUT, ":utf8");
binmode(STDIN, ":encoding(UTF-8)");

# -----------------------------------------------------------------------------

# constants
use constant {
    VERSION_STRING => '0.0.1-alpha',
    UPLOADER => "$ARGV[0]",
    META_DIR => "$ARGV[1]",
    IN_DIR => "$ARGV[2]",
    OUT_DIR => "$ARGV[3]"
};

# -----------------------------------------------------------------------------
# main #

opendir my $i_dir, IN_DIR or die "Unable to open input directory: $!";

my @m_files = glob(META_DIR . "/*.info.json");
my @i_files = readdir($i_dir);

closedir($i_dir);

foreach my $f (@m_files) {
    my $json = decode_json(path($f)->slurp);
    if ($json->{uploader_id} eq UPLOADER) {
        my $bfn = substr(basename($f), 0, -10);
        my $ftm = first { /^\Q$bfn\E\.(webm|mp4|mp3|mkv|ogg|ogv)$/ } @i_files;
        if (defined $ftm && -e IN_DIR . "/$ftm") {
            if (-e OUT_DIR . "/$ftm") {
                print("WARNING: $ftm already exsists at ".OUT_DIR." file not moved.\n")
            } else {
                print("moving: $ftm to " . OUT_DIR . "\n");
                move(IN_DIR . "/$ftm", OUT_DIR);
            }
        }
    }
}
