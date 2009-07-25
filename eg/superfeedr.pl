use strict;
use warnings;
use Find::Lib '../lib';
use Net::AppNotifications;
use AnyEvent::Superfeedr;

my @subs = qw(
    http://friendfeed.com/public?format=atom
);

my ($key, $jid, $pass) = @ARGV;

die "usage: $0 <key> <jid> <pass>"
    unless $key && $jid;

my $end = AnyEvent->condvar;
my $n   = 0;

my $notifier   = Net::AppNotifications->new(key => $key);
my $superfeedr; $superfeedr = AnyEvent::Superfeedr->new(
    jid => $jid,
    password => $pass,
    subscription => {
        interval => 60,
        cb => sub { [ shift @subs ] },
    },
    on_notification => sub { 
        my $entry = shift;
        my $title = Encode::decode_utf8($entry->title); 
        $title =~ s/\s+/ /gs;

        my $l = length $title;
        my $max = 50;
        if ($l > $max) {
            substr $title, $max - 3, $l - $max + 3, '...';
        }

        ## achevons la bete
        $end->send if $n++ > 10;

        my $message = sprintf "~ %-50s\n", $title;
        $notifier->send(
            message    => $message,
            on_success => sub { print "Delivered $message\n" },
            on_error   => $end,
        );
    },
);

$end->recv;
