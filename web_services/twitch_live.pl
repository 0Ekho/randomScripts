#!/usr/bin/perl

=encoding utf8

=pod LICENCE

 MIT License

 Copyright (c) 2017 Ekho

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

 ------------------------------------------------------------------------------

=cut

=head4

 Short script for showing live twitch streams based on chatty's
 (https://github.com/chatty/chatty) adressbook.

 Depends on "JSON" and "List::MoreUtils" from CPAN.

 requires curl, sed, and rg (ripgrep: https://github.com/BurntSushi/ripgrep)
 currently as this is a hurried rewrite of a bash script and I'm to lazy to
 replace those parts.

 Expects chatty to be installed in $HOME/.chatty, if you have installed chatty
 elsewhere please change the CHATTY_DIR constant to the correct location.

 To use: add users to your chatty address book and give them the category
 "follow"; then, to see all live streams, run this script.

 No idea how reliable this is, has no actual testing.

=cut

# -----------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

use JSON qw( decode_json );
use List::MoreUtils qw(natatime);

binmode STDOUT, ":utf8";
binmode STDIN, ":encoding(UTF-8)";

# -----------------------------------------------------------------------------

# constants
use constant {
    T_PARAM_LIMIT => 80
};
my $CHATTY_DIR = "$ENV{'HOME'}/.chatty";
my $t_r503 = '{"error":"Service Unavailable","status":503,"message":""}';

local $/=undef;
open(my $login_file, "<", "$CHATTY_DIR/login")
    or die "cannot open login file: $!\n";
my $oauth = decode_json(<$login_file>)->{token};
close($login_file);

# -----------------------------------------------------------------------------

# TODO: replace shell commands copied from old bash version of script with perl
my $rg_out = `\
rg 'follow' "$CHATTY_DIR/addressbook" | sed 's/ follow//'`;

my @users = split("\n", $rg_out);

my (@streams, %user_ids, %game_ids);
my $reg_seg;

# get all live streams.
$reg_seg = natatime(T_PARAM_LIMIT, @users);
print("Looking up live streams, please wait");
while (my @usrs = $reg_seg->()) {
    my ($req, $resp, $dec_resp);
    print(".");
    $req = 'https://api.twitch.tv/helix/streams?';
    foreach my $usr (@usrs) {
        $req .= "&user_login=$usr";
    }
    $resp = `curl -sH "Authorization: Bearer $oauth" '$req'`;
    if ($resp eq $t_r503) {
        die "Error | Twitch returned 503, please try again.\n";
    }
    $dec_resp = decode_json($resp);
    foreach my $live (@{$dec_resp->{data}}) {
        push(@streams, $live);
        $user_ids{$live->{user_id}} = 0;
        $game_ids{$live->{game_id}} = 0;
    }
    sleep 1;
}
print("\n");

# lookup all game ID's
$reg_seg = natatime(T_PARAM_LIMIT, (keys %game_ids));
print("Looking up game ID's, Please wait");
while (my @ids = $reg_seg->()) {
    my ($req, $resp, $dec_resp);
    print(".");
    $req = 'https://api.twitch.tv/helix/games?';
    foreach my $id (@ids) {
        $req .= "&id=$id";
    }
    $resp = `curl -sH "Authorization: Bearer $oauth" '$req'`;
    if ($resp eq $t_r503) {
        die "Error | Twitch returned 503, please try again.\n";
    }
    $dec_resp = decode_json($resp);
    foreach my $game (@{$dec_resp->{data}}) {
        $game_ids{$game->{id}} = $game->{name};
    }
    sleep 1;
}
print("\n");

# lookup all user ID's
$reg_seg = natatime(T_PARAM_LIMIT, (keys %user_ids));
print("Looking up user ID's, Please wait");
while (my @ids = $reg_seg->()) {
    my ($req, $resp, $dec_resp);
    print(".");
    $req = 'https://api.twitch.tv/helix/users?';
    foreach my $id (@ids) {
        $req .= "&id=$id";
    }
    $resp = `curl -sH "Authorization: Bearer $oauth" '$req'`;
    if ($resp eq $t_r503) {
        die "Error | Twitch returned 503, please try again.\n";
    }
    $dec_resp = decode_json($resp);
    foreach my $user (@{$dec_resp->{data}}) {
        $user_ids{$user->{id}} = $user->{display_name};
    }
    sleep 1;
}
print("\n");

# print all live streams
print("\n┌──────────────────────────┬────────────────────────────────────");
print("┬──────────────────────────────────────────────────────────────┐\n");
my $itr = 0;
foreach my $live (@streams) {
        printf("│ %-24s │%-34s│〈%s〉\n", $user_ids{$live->{user_id}},
    "「$game_ids{$live->{game_id}}」", $live->{title});
    $itr++;
    if ($itr < scalar @streams) {
    print("├──────────────────────────┼────────────────────────────────────");
    print("┼──────────────────────────────────────────────────────────────┤\n");
    }
}
print("└──────────────────────────┴────────────────────────────────────");
print("┴──────────────────────────────────────────────────────────────┘\n");
