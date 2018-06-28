#!/usr/bin/env perl

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

 horrifying script to allow a tasker scene to use netcat to control music

=cut

# -----------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

use Switch;
use IO::Socket::INET;

binmode(STDOUT, ":utf8");
binmode(STDIN, ":encoding(UTF-8)");

# -----------------------------------------------------------------------------

# constants
use constant {
    VERSION_STRING => '0.0.1-alpha',
};

# -----------------------------------------------------------------------------

sub trim;

# -----------------------------------------------------------------------------
# main

my $socket = new IO::Socket::INET (
    LocalAddr => '192.168.2.21:9010',
    Proto => 'tcp',
    Listen => 5,
    ReuseAddr => 1
);
die "cannot create socket $!\n" unless $socket;

while(1) {
    my $data;
    my $client_socket = $socket->accept();
    my $client_address = $client_socket->peerhost();

    # read up to 1024 bytes from the client
    $client_socket->recv($data, 1024);
    $data = trim($data);
    print "received: $data from: $client_address\n";
    
    # music controls, no output normally but capture anyway
    switch ($data) {
        case '1' {$data = `mocp --toggle-pause`;}
        case '2' {$data = `mocp --previous`;}
        case '3' {$data = `mocp --next`;}
        case '4' {$data = `mocp --seek -1000`;}
        case '5' {$data = `mocp --volume +5`;}
        case '6' {$data = `mocp --volume -5`;}
    }

    $client_socket->send($data);
    shutdown($client_socket, 1);
}

$socket->close();

# -----------------------------------------------------------------------------
# subroutines

sub trim {
    my $s = shift;

    $s =~ s/^\s+|\s+$//g;
    return $s;
}
