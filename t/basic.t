use strict;
use warnings;
use Test::More;
use Test::Exception;
use FindBin qw/$Bin/;
use lib "$Bin/../t/lib";
use Catalyst::Test 'Test::App';
use ElasticSearch::TestServer;
use HTTP::Request::Common;

BEGIN {
  $ENV{ES_TRANSPORT} = 'http';
  use_ok 'ElasticSearch'             || print "Bail out!";
  use_ok 'ElasticSearch::TestServer' || print "Bail out!";
  use_ok 'ElasticSearch::Transport'  || print "Bail out!";
}

{

  package TestES;
  use Moose;
  use namespace::autoclean;
  extends 'Catalyst::Model::Search::ElasticSearch';

  use ElasticSearch::TestServer;

  sub _build_es {
    return ElasticSearch::TestServer->new(
      home      => '/opt/elasticsearch/',
      instances => 1
    );
  }

  __PACKAGE__->meta->make_immutable;
}

use Data::Dumper;
use_ok 'Catalyst::Model::Search::ElasticSearch';
my $es_model;
lives_ok { $es_model = TestES->new() };
lives_ok {
  $es_model->index(
    index   => 'test',
    type    => 'test',
    data    => { schpongle => 'bongle' },
    create  => 1,
    refresh => 1,
  );
};
my $search = $es_model->search(
  index => 'test',
  type  => 'test',
  query => { term => { schpongle => 'bongle' } }
);
my $expected = { _source => { schpongle => 'bongle', }, };
is_deeply( $search->{hits}{hits}->[0]->{_source}, $expected->{_source} );

## Catalyst App testing
ok my $res = request( GET '/test?q=bongle' );
my $VAR1;
local $Data::Dumper::Purity = 1;
my $data = eval( $res->content );
is_deeply( $data->{hits}{hits}->[0]->{_source}, $expected->{_source} );
ok my $config = request( GET '/dump_config' );
my $config_data     = eval( $config->content );
my $expected_config = {
  transport    => 'http',
  servers      => 'localhost:9200',
  timeout      => 30,
  max_requests => 10_000
};
is_deeply $config_data, $expected_config;
done_testing;
