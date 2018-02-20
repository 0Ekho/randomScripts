#!/usr/bin/perl

=encoding utf8

=pod LICENCE

 MIT License

 Copyright (c) 2018, Ekho

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

 requires curl, though if you don't have curl already...

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

use JSON qw(decode_json);
use List::MoreUtils qw(natatime);

binmode STDOUT, ":utf8";
binmode STDIN, ":encoding(UTF-8)";

# -----------------------------------------------------------------------------

# constants
use constant {
    T_PARAM_LIMIT => 80
};
my $CHATTY_DIR = "$ENV{'HOME'}/.chatty";

# read oauth from chatty
open(my $login_file, "<", "$CHATTY_DIR/login")
    or die "cannot open login file: $!\n";
my $oauth = decode_json(<$login_file>)->{token};
close($login_file);

# -----------------------------------------------------------------------------

sub twitch_req;

# -----------------------------------------------------------------------------

my (@users, @streams, %user_ids, %game_ids);

# Get all usernames with the "follow" tag in the adressbook.
open(my $adrssb, "<", "$CHATTY_DIR/addressbook")
    or die "cannot open adressbook: $!\n";
foreach my $line (grep {$_ =~ " follow"} <$adrssb>) {
    push(@users, $line =~ /^(\w+)/);
}
close($adrssb);

print("Looking up live streams, please wait");
twitch_req(\@users, "streams", "user_login", sub {
    my $live = shift;
    push(@streams, $live);
    $user_ids{$live->{user_id}} = 0;
    $game_ids{$live->{game_id}} = 0;
});

print("Looking up game ID's, Please wait");
twitch_req([keys %game_ids], "games", "id", sub {
    my $game = shift;
    $game_ids{$game->{id}} = $game->{name};
});

print("Looking up user ID's, Please wait");
twitch_req([keys %user_ids], "users", "id", sub {
    my $user = shift;
    $user_ids{$user->{id}} = $user->{display_name};
});

print("\n┌────────────────────────┬──────────────────────────────────┬───",
    "───────────────────────────────────────────────────────────────┐\n");
my $itr = 0;
foreach my $live (@streams) {
    # some games have very long names, truncate to 30 characters
    my $gn = sprintf('%.30s', $game_ids{$live->{game_id}});
    printf("│ %-22s │%-32s│〈%s〉\n", $user_ids{$live->{user_id}},
        "「$gn」", $live->{title});
    $itr++;
    if ($itr < scalar @streams) {
    print("├────────────────────────┼──────────────────────────────────┼───",
        "───────────────────────────────────────────────────────────────┤\n");
    }
}
print("└────────────────────────┴──────────────────────────────────┴───",
    "───────────────────────────────────────────────────────────────┘\n");

# -----------------------------------------------------------------------------

sub twitch_req {
    my ($vals, $ep, $param, $callback) = @_;
    my $req_seg;

    $req_seg = natatime(T_PARAM_LIMIT, @{$vals});
    while (my @vs = $req_seg->()) {
        my ($req, $resp, $dec_resp);
        print(".");
        $req = "https://api.twitch.tv/helix/$ep?";
        foreach my $v (@vs) {
            $req .= "&$param=$v";
        }
        # TODO: replace this at some point maybe.
        $resp = `curl -sH "Authorization: Bearer $oauth" '$req'`;
        if ($resp !~ /{"data":/) {
            print("$resp\n");
            die "Error | Twitch returned $resp, please try again.\n";
        }
        $dec_resp = decode_json($resp);
        foreach my $live (@{$dec_resp->{data}}) {
            $callback->($live);
        }
        sleep 1; # TODO: make sleep only run if more then N reqests?
    }
    print("\n");
}