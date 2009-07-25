use strict;
use warnings;
use Find::Lib '../lib';
use Net::AppNotifications;

my $key = shift
    or die "usage: $0 <key> <message>";
my $message = shift || "hello";

my $notifier = Net::AppNotifications->new(key => $key);
$notifier->send($message);
