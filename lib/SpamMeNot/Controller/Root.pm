package SpamMeNot::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use Data::Dumper;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config( namespace => '' );

=head1 NAME

SpamMeNot::Controller::Root - Root Controller for SpamMeNot

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0)
{
    my ( $self, $c ) = @_;

    $c->detach( 'default' );
}

sub begin :Private
{
    my ( $self, $c ) = @_;

    $c->response->header( 'Content-type' => 'text/plain; charset=utf-8' );
 }

=head1 SUPPORTED COMMANDS

HELO     EHLO     AUTH     RSET     NOOP     HELP
MAIL     RCPT     DATA     VRFY     QUIT     MOO

=cut

sub helo :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'HELO => ' . Dumper $c->request->params );
}

sub ehlo :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'EHLO => ' . Dumper $c->request->params );
}

sub auth :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'AUTH IS A NOOP => ' . Dumper $c->request->params );
}

sub rset :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'RSET YOSELF => ' . Dumper $c->request->params );
}

sub noop :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'NOOP => ' . Dumper $c->request->params );
}

sub help :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'HELP => ' . Dumper $c->request->params );
}

sub mail :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'MAIL => ' . Dumper $c->request->params );
}

sub rcpt :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'RCPT => ' . Dumper $c->request->params );
}

sub data :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'DATA => ' . Dumper $c->request->params );
}

sub vrfy :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'VRFY => ' . Dumper $c->request->params );
}

sub quit :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( '221 Bye' );
}

sub moo :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'These are not the droids you\'re looking for.' );
}


=head2 default

Standard 404 error page

=cut

sub default :Path
{
    my ( $self, $c ) = @_;

    $c->response->body( '503 Error: command not recognized' );

    $c->response->status( 503 );
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

superman,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
