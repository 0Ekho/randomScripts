#!/usr/bin/perl

=encoding utf8

=pod LICENSE

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

 Very basic timer, needs perl Tk

 Mask        | Value | Key
 ------------+-------+-----------------
 ShiftMask   |     1 | Shift
 LockMask    |     2 | Caps Lock
 ControlMask |     4 | Ctrl
 Mod1Mask    |     8 | Alt
 Mod2Mask    |    16 | Num Lock
 Mod3Mask    |    32 | Scroll Lock
 Mod4Mask    |    64 | Windows
 Mod5Mask    |   128 | ISO_Level3_Shift

 # TODO: cleanup / refactoring
 # TODO: better help layout / i18n (lang setting?)
 # TODO: proper settings not hardcoded values
 # TODO: error handling
 # TODO: right click menu, not just hotkeys?
 # TODO: hide all window borders option, note that window can not be moved when
 # borders are hidden it seems

=cut

# -----------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

use Time::HiRes qw(time);

use Tk;
use Tk::Dialog;
use Tk::Font;
use Tk::LabEntry;
# Linux / BSD?
use X11::Xlib qw(XGrabKey GrabModeAsync XCheckTypedEvent KeyPress 
    Mod1Mask Mod2Mask);
# Win32
#use Win32::GlobalHotkey;
#use threads::shared;
# windows is only kind of supported, I do not have windows install and cannot
# test anything, nor do I actually know what I am doing

binmode STDOUT, ":utf8";
binmode STDIN, ":encoding(UTF-8)";

# -----------------------------------------------------------------------------

# constants
use constant {
    VERSION_STRING => '0.0.1-alpha',
    # Versioning follows Semantic Versioning 2.0.0 [https://semver.org]
    I_TIME => 41,
    GLOBAL_KEYCODE => 33 # p
};
my $icon_gif_b64 = 'R0lGODlhIAAgAKECAP8A6gBs/////////yH5BAEKAAIALAAAAAAgACAAA'.
 'AJolI+py+0Popy0WgSC3rz7DmDfSGrhkZUqdxrWW4Htw0Qy7djsjCf6FunVUkCe0EU0GY8/5VHR'.
 'DASfmKR0KYxOqcgbt7v7gotigRbbO5fVYvbXzYVTz7C6aIWfWfEjPX+lVydYUVYoVgAAOw==';
my $icon_pixmap = <<EOPM;
 /* XPM */
 static char * zsplit_xpm[] = {
 "32 32 3 1",
 " 	c None",
 ".	c #FF00EA",
 "+	c #006CFF",
 "                                ",
 "                                ",
 "  ............................  ",
 "  .++++++++++++++++++++++++++.  ",
 "  .++++++++++++++++++++++++++.  ",
 "  .++++++++++++++++++++++++++.  ",
 "  .....................+++++..  ",
 "                    ..+++++..   ",
 "                   ..+++++..    ",
 "                  ..+++++..     ",
 "                 ..+++++..      ",
 "                ..+++++..       ",
 "               ..+++++..        ",
 "              ..+++++..         ",
 "             ..+++++..          ",
 "            ..+++++..           ",
 "           ..+++++..            ",
 "          ..+++++..             ",
 "         ..+++++..              ",
 "        ..+++++..               ",
 "       ..+++++..                ",
 "      ..+++++..                 ",
 "     ..+++++..                  ",
 "    ..+++++..                   ",
 "   ..+++++..                    ",
 "  ..+++++.....................  ",
 "  .++++++++++++++++++++++++++.  ",
 "  .++++++++++++++++++++++++++.  ",
 "  .++++++++++++++++++++++++++.  ",
 "  ............................  ",
 "                                ",
 "                                "};
EOPM

# -----------------------------------------------------------------------------

sub new_time;
sub toggle_time;
sub start_at;
sub clean_exit;

# -----------------------------------------------------------------------------
my $ms = 0;
my $lt;
my $dt = 'Press \'h\'';
my $c;
my $r = 0;

my $w = MainWindow->new();

$w->geometry("260x65");
$w->title('zsplit'.' | version: '.VERSION_STRING);
# Linux / BSD
$w->iconphoto($w->Photo(-format => 'gif', -data => $icon_gif_b64));
# Win32
#$w->iconimage($w->Pixmap(-data => $icon_pixmap));

my $f_S7 = $w->Font(-family => 'DSEG7 Classic', -size  => 27);
my $f_sa = $w->Font(-family => 'Sans', -size  => 30);

my $l = $w->Label(-textvariable => \$dt, -background => 'black', -font => $f_sa,
    -foreground => 'white', -height => 65, -width =>250)->pack(-fill => 'both');

$l->after(1600, sub {$dt = '00:00:00.00';});
$l->after(1600, sub {$l->configure(-font => $f_S7)});
# ---------------------------------------------

$w->bind('<KeyPress-p>' => \&toggle_time);
$w->bind('<KeyPress-r>' => sub {
    if ($r == 0 && $ms == 0) {
        start_at();
        return 0;
    }
    if ($r == 0) {
        $c->cancel;
        $ms = 0;
        $dt = "00:00:00.00";
    }
});
$w->bind('<KeyPress-q>' => sub {
    if ($r == 0) {
        clean_exit();
    }
});

$w->bind('<KeyPress-h>' => sub {
    # TODO: better layout help, windows breaks formating (no monospace?)
    my $ht = <<EOHT;
                    | Usage         | 用法
 ===================|===============|======================
  'p'               | start / pause | 開始 / 一時停止
  'r' @ pause       | reset         | リセット
  'r' @ 00:00:00.00 | settings      | 設定
  'q' @ pause       | quit          | 終了
  'h'               | help          | ヘルプ
  'Alt+p'           | global hotkey | グローバルホットキー
EOHT
    my $msg = $w->DialogBox(-title => 'Help | ヘルプ',
        -buttons => ['Close | 閉じる'],
        -default_button => 'Close | 閉じる');
    $msg->add('Message', -width => 650,
        -font => $w->Font(-family => 'Monospace', -size  => 14),
        -text => "$ht",)->pack();
    $msg->Show();
});
# ---------------------------------------------

#=pod DISABLED

# Linux / BSD hotkey code

my $display= X11::Xlib->new();
my $window = $display->RootWindow();
XGrabKey($display, GLOBAL_KEYCODE, Mod1Mask|Mod2Mask, $window, 1, 
    GrabModeAsync, GrabModeAsync);

$l->repeat(75, sub {
    if (XCheckTypedEvent($display, KeyPress, my $er)) {
        if ($er->keycode == GLOBAL_KEYCODE) {
            toggle_time();
        }
    }
});

#=cut

=pod DISABLED

# Win32 hotkey code
# No clue on Windows, Probably wrong.

my $hkp :shared;
my $hk = Win32::GlobalHotkey->new();
$hk->PrepareHotkey( 
    vkey => 'p', 
    modifier => Win32::GlobalHotkey::MOD_ALT, 
    cb => sub { $hkp = 1; }, # in another thread.
);

$hkp = 0;
$hk->StartEventLoop();

$l->repeat(75, sub {
    if ($hkp == 1) {
        $hkp = 0;
        toggle_time();
    }
});

=cut

# ---------------------------------------------

MainLoop;

# -----------------------------------------------------------------------------

sub new_time {
    my $ct = time();
    $ms += ($ct - $lt) * 1000;
    $lt = $ct;
    my $s = int($ms / 1000);

    $dt = sprintf('%02d:%02d:%02d.%02d',
     $s / 3600, ($s / 60 ) % 60, $s % 60, int(($ms % 1000 ) / 10));
}
sub toggle_time {
    if ($r == 1) {
        $c->cancel;
        $r = 0;
    } else {
        $lt = time();
        $c = $l->repeat(I_TIME, \&new_time);
        $r = 1;
    }
}
sub start_at {
    my $text = $dt;
    my $dia = $w->DialogBox(-title => 'Settings | 設定',
        -default_button => 'OK', -buttons => [qw/OK Cancel/]);
    $dia->add('LabEntry', -textvariable => \$text, -width => 12,
        -label => "start time | 開始時間",
        -labelPack => [-side => 'left'])->pack();
    my $sel = $dia->Show();

    if ($sel eq 'OK') {
        my ($t2, $s_cs) = split(/\./, "$text");
        my ($s_h, $s_m, $s_s,) = split(/:/, "$t2");
        $ms = ($s_h * 3600 + $s_m * 60 + $s_s) * 1000 + $s_cs * 10;
        $dt = $text;
    }
}
sub clean_exit {
    # Win32
    #$hk->StopEventLoop();
    Tk::exit(0);
}
