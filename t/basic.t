use strict;
use warnings;
use Test::More;
use Test::Exception;
use ElasticSearch::TestServer;
BEGIN {
  $ENV{ES_HOME} = '/opt/elasticsearch/bin';
  $ENV{ES_TRANSPORT} = 'http';
};
use Data::Dumper;
use_ok 'Catalyst::Model::Search::ElasticSearch';
my $es_model;
lives_ok { $es_model = Catalyst::Model::Search::ElasticSearch->new() };
lives_ok { $es_model->index( index => 'test', type => 'test', data => { schpongle => 'bongle' }, create => 1,); };
my $search = $es_model->search( index => 'test', type => 'test', query => { term => { schpongle => 'bongle' } } );
warn Dumper $search;
my $expected = [ 
    {
    _source => {
      schpongle => 'bongle',
    },
  }  
];
is_deeply( $search->{hits}{hits}, $expected );
done_testing;
