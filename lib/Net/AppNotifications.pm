package Net::AppNotifications;

use strict;
use 5.008_001;
our $VERSION = '0.01';
use AnyEvent::HTTP;
use Carp;
use URI::Escape 'uri_escape_utf8';

use constant POST_URI =>
    q{https://www.appnotifications.com/account/notifications.xml};

# TODO: get key from user/pass
sub new {
    my $class = shift;
    my %param = @_;
    my $notifier = bless { %param }, ref $class || $class;
    croak "Key is needed" unless $param{key};
    return $notifier;
}

sub send {
    my $notifier = shift;

    my %cbs;
    my $key    = $notifier->{key};
    my $finish = sub {};
    my $message;

    if (scalar @_ == 1) {
        $message = shift;
        unless (defined $message && length $message) {
            croak "Please, give me a message to push";
        }
        my $done = AnyEvent->condvar;

        $cbs{on_posted} = sub {
            my ($data, $hds) = @_;
            $done->send;
            croak "Something happend" unless defined $data;
        };

        $cbs{on_timeout} = sub {
            $done->send;
            croak "timeout";
        };
        $cbs{on_error} = sub {
            $done->send;
            croak "Error $_[0]";
        };

        $finish = sub {
            $done->recv;
        };
    }
    else {
        my %param = @_;

        $message = $param{message};
        $cbs{$_} = $param{$_} for qw{on_error on_timeout};

        my $early_error = $cbs{on_error} || sub { croak "$_[0]" }; 

        my $on_success = $param{on_success}
            or $early_error->("On success must be passed");

        ## callback definitions
        $cbs{on_posted} = sub {
            my $data = shift;
            unless (defined $data) {
                $cbs{on_error}->("Something happened");
                return;
            }
            $on_success->($data, @_);
        };

        $cbs{on_error} ||= sub {
            warn "Error: $_[0]";
        };

        $cbs{on_timeout} ||= sub {
            warn "Timeout: $_[0]";
        };

    } 
    $notifier->post_request($key, $message, %cbs);

    ## wait here for synchronous calls
    $finish->();
    return;
}

sub post_request {
    my $notifier = shift;
    my ($key, $message, %cbs) = @_;

    my $uri  = POST_URI; 
    my $body = build_body($key, $message);

    http_request
        POST      => $uri,
        body      => $body,
        headers   => {
            'Content-Type' => 'application/x-www-form-urlencoded',
            'User-Agent'   => q{yann's Net::AppNotifications},
        },
        on_header => sub {
            my ($hds) = @_;
            if ($hds->{Status} ne '200') {
                return $cbs{on_error}->("$hds->{Status}: $hds->{Reason}");
            }
            return 1;
        },
        $cbs{on_posted};
    return
}

sub build_body {
    my ($key, $message) = @_;
    return join "&", map { uri_escape_utf8($_) }
            "user_credentials=$key",
            "notification[message]=$message";
}


1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Net::AppNotifications - send notifications to your iPhone.

=head1 SYNOPSIS

  use Net::AppNotifications;
  $notifier = Net::AppNotifications->new(
      key => $key,
  );

  ## Synchronous blocking notification
  if ($notifier->send("Hello, Mr Jobs")) {
      print "Notification delivered";
  }

  ## Asynchronous non-blocking notification
  my $sent = AnyEvent->condvar;
  my $handle = $notifier->send(
    message    => "Hello (when you have time)",
    on_error   => $error_cb,
    on_timeout => $timeout_cb,
    on_success => sub { $sent->send },
  );
  $sent->recv;

=head1 DESCRIPTION

Net::AppNotifications is a wrapper around appnotifications.com. It allows
you to push notifications to your iPhone registered with the service.

A visual and audible alert (like for SMS) will arrive on your device
in a limited timeframe.

If you already have an APNS key, I recommend using L<AnyEvent::APNS>,
directly. 

=head1 AUTHOR

Yann Kerherve E<lt>yannk@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::APNS>

=cut
