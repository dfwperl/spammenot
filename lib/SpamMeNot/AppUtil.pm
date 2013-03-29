package SpamMeNot::AppUtil;

use utf8;

use Moose;
use namespace::autoclean;

use Data::Validate::IP qw( is_ipv4  is_ipv6 );
use Data::Validate::Domain qw( is_domain );
use Email::Valid;
use Net::IDN::Encode;

sub resolve_hostname
{
   my ( $self, $hostname ) = @_;

   $hostname = $self->hostname_sanitary_IDN( $hostname );

   return unless $hostname;

   # by now, "$hostname" is safe to send to shell:

   my $digged = qx(/usr/bin/dig +short a '$hostname') || undef;

   return unless $digged;

   chomp $digged;

   ( $digged ) = split /\n/, $digged;

   return $digged;
}

sub email_valid
{
   my ( $self, $addr ) = @_;

   my ( $user, $domain ) = split /\@/, $addr;

   $domain = $self->hostname_valid( $domain );

   return unless $domain;

   $addr = join '@', $user, $domain;

   return Email::Valid->address( $addr )
}

sub hostname_valid
{
   my ( $self, $hostname ) = @_;

   $hostname = $self->hostname_sanitary_IDN( $hostname );

   return is_domain( $hostname, { domain_allow_underscore => 1 } );
}

sub hostname_sanitary_IDN
{
   my ( $self, $hostname ) = @_;

   my $error_count = ( $hostname ) =~ /([^[:alnum:]\.\-])/;

   return if $error_count;

   return Net::IDN::Encode::domain_to_ascii( $hostname );
}

sub ip_valid
{
   my ( $self, $ip ) = @_;

   return is_ipv4( $ip ) || is_ipv6( $ip );
}

sub trim
{
   my ( $self, $input ) = @_;

   return unless $input;

   $input =~ s/[[:space:]\r\n]+//g;

   return $input;
}

1;
