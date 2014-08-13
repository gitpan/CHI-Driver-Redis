package CHI::Driver::Redis::t::CHIDriverTests;
use strict;
use warnings;
use CHI::Test;

use base qw(CHI::t::Driver);

use Test::Mock::Redis;

sub testing_driver_class { 'CHI::Driver::Redis' }

sub supports_expires_on_backend { 1 }

sub new_cache_options {
    my $self = shift;

    return (
        $self->SUPER::new_cache_options(),
        driver_class => 'CHI::Driver::Redis',
        redis_class => (defined $ENV{CHI_REDIS_SERVER} ? 'Redis' : 'Test::Mock::Redis'),
        server => $ENV{CHI_REDIS_SERVER} || undef,
        ($ENV{CHI_REDIS_PASSWORD} ? ( password => $ENV{CHI_REDIS_PASSWORD} ) : ()),
        prefix => 'test' . $$ . ':',
    );
}

sub clear_redis : Test(setup) {
    my ($self) = @_;

    my $cache = $self->new_cache;
    $cache->_verify_redis_connection;
    $cache->redis->flushall;
}

1;
