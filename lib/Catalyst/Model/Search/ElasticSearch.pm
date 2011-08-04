package Catalyst::Model::Search::ElasticSearch;
use Moose;
use namespace::autoclean;
use ElasticSearch;
extends 'Catalyst::Model';


# ABSTRACT: A simple Catalyst model to interface with L<ElasticSearch>

=head1 NAME

Catalyst::Model::Search::ElasticSearch

=cut

=head1 SYNOPSIS

    package My::App;
    use strict;
    use warnings;

    use Catalyst;;

    our $VERSION = '0.01';
    __PACKAGE__->config(
      name            => 'Test::App',
      'Model::Search' => {
        transport    => 'http',
        servers      => 'localhost:9200',
        timeout      => 30,
        max_requests => 10_000
      }
    );

    __PACKAGE__->setup;


    package My::App::Model::Search;
    use Moose;
    use namespace::autoclean;
    extends 'Catalyst::Model::Search::ElasticSearch';

    __PACKAGE__->meta->make_immutable;
    1;

    package My::App::Controller::Root;
    use base 'Catalyst::Controller';
    __PACKAGE__->config(namespace => '');

    sub search : Local {
      my ($self, $c) = @_;
      my $params = $c->req->params;
      my $search = $c->model('Search');
      my $results = $search->search(
        index => 'test',
        type  => 'test',
        query => { term => { schpongle => $params->{'q'} } }
      );
      $c->stash( results => $results );

    }


=cut

=head1 WARNING

This is in very alpha stages.  More testing and production use are coming up, but be warned until then.

=cut

=head2 servers

A list of servers to connect to

=cut

has 'servers' => (
  is      => 'rw',
  lazy    => 1,
  default => "localhost:9200",
);

=head2 transport

The transport to use to interact with the ElasticSearch API.  See L<https://metacpan.org/module/ElasticSearch#Transport-Backends> for options.

=cut

has 'transport' => (
  is      => 'rw',
  lazy    => 1,
  default => "http",
);

=head2 _additional_opts

Stores other key/value pairs to pass to ElasticSearch

=cut

has '_additional_opts' => (
  is      => 'rw',
  lazy    => 1,
  isa     => 'HashRef',
  default => sub { {} },
);

=head2 _es

The ElasticSearch object.

=cut

has '_es' => (
  is       => 'ro',
  lazy     => 1,
  required => 1,
  builder  => '_build_es',
  handles  => {
    map { $_ => $_ }
      qw(
      search index get mget create delete reindex
      bulk bulk_index bulk_create bulk_delete
      )
  },
);

sub _build_es {
  my $self = shift;
  return ElasticSearch->new(
    servers   => $self->servers,
    transport => $self->transport,
    %{ $self->_additional_opts },
  );

}

around BUILDARGS => sub {
  my $orig   = shift;
  my $class  = shift;
  my %params = @_;

  delete $params{$_} for qw/ servers transport /;
  $class->$orig(_additional_opts => \%params);
  return $class->$orig(@_);

};

__PACKAGE__->meta->make_immutable;
1;
