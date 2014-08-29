use strict;
use warnings;
use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../t/lib";
use Test::Requires { 'Search::Elasticsearch' => 1.10, };
use_ok 'Catalyst::Model::Search::ElasticSearch';



SKIP: {
  skip "Environment variable ES_HOME not set", 11
    unless defined $ENV{ES_HOME};
  use Test::Exception;
  use HTTP::Request::Common;

  use Test::Requires {
    'Search::Elasticsearch::TestServer' => 1.10,
    'Search::Elasticsearch::Transport'  => 1.10
  };

  use Catalyst::Test 'Test::App';

  BEGIN {
    use_ok 'Search::Elasticsearch'             || print "Bail out!";
    use_ok 'Search::Elasticsearch::TestServer' || print "Bail out!";
    use_ok 'Search::Elasticsearch::Transport'  || print "Bail out!";
  }

  my $test_server = Search::Elasticsearch::TestServer->new(
    instances => 1,
    es_home   => $ENV{ES_HOME}
  );
  my $nodes = $test_server->start();
  {
    package TestES;
    use Moose;
    use namespace::autoclean;
    extends 'Catalyst::Model::Search::ElasticSearch';

    use Search::Elasticsearch::TestServer;

    sub _build_es {
      return Search::Elasticsearch->new( nodes => $nodes );
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
      body    => { schpongle => 'bongle' },
      refresh => 1,
    );
  };
  my $search = $es_model->search(
    index => 'test',
    type  => 'test',
    body  => { query => { term => { schpongle => 'bongle' } } }
  );
  my $expected = { _source => { schpongle => 'bongle', }, };
  is_deeply( $search->{hits}{hits}->[0]->{_source}, $expected->{_source} );

  ## Catalyst App testing
  Test::App->model('Search')->servers( $nodes );
  ok my $res = request( GET '/test?q=bongle' );
  my $VAR1;
  local $Data::Dumper::Purity = 1;
  my $data = eval( $res->content );
  is_deeply( $data->{hits}{hits}->[0]->{_source}, $expected->{_source} );
  ok my $config = request( GET '/dump_config' );
  my $config_data     = eval( $config->content );
  my $expected_config = {
    servers      => 'localhost:9200',
    timeout      => 30,
    max_requests => 10_000
  };
  is_deeply $config_data, $expected_config;
}
done_testing;
