package CHI::Driver::Redis;
use Moose;

use Redis;
use Try::Tiny;
use URI::Escape qw(uri_escape uri_unescape);

our $VERSION = '0.01';

extends 'CHI::Driver';

has '_redis' => (
    is => 'rw',
    isa => 'Redis'
);

has '_params' => (
    is => 'rw'
);

sub BUILD {
    my ($self, $params) = @_;

    $self->_params($params);
    $self->_redis(
        Redis->new(
            server => $params->{server} || '127.0.0.1:6379',
            debug => $params->{debug} || 0
        )
    );
}

sub fetch {
    my ($self, $key) = @_;

    $self->_verify_redis_connection;

    my $eskey = uri_escape($key);
    return $self->_redis->get($self->namespace."||$eskey");
}

sub XXfetch_multi_hashref {
    my ($self, $keys) = @_;

    return unless scalar(@{ $keys });

    my %kv;
    foreach my $k (@{ $keys }) {
        my $esk = uri_escape($k);
        $kv{$self->namespace."||$esk"} = undef;
    }

    my @vals = $self->_redis->mget(keys %kv);

    my $count = 0;
    my %resp;
    foreach my $k (@{ $keys }) {
        $resp{$k} = $vals[$count];
        $count++;
    }

    return \%resp;
}

sub get_keys {
    my ($self) = @_;

    my @keys = $self->_redis->smembers($self->namespace);

    my @unesckeys = ();

    foreach my $k (@keys) {
        # Getting an empty key here for some reason...
        next unless defined $k;
        push(@unesckeys, uri_unescape($k));
    }
    return @unesckeys;
}

sub get_namespaces {
    my ($self) = @_;

    return $self->_redis->smembers('chinamespaces');
}

sub remove {
    my ($self, $key) = @_;

    return unless defined($key);

    $self->_verify_redis_connection;

    my $ns = $self->namespace;

    my $skey = uri_escape($key);

    $self->_redis->srem($ns, $skey);
    $self->_redis->del("$ns||$skey");
}

sub store {
    my ($self, $key, $data, $expires_at, $options) = @_;

    $self->_verify_redis_connection;

    my $ns = $self->namespace;

    my $skey = uri_escape($key);
    my $realkey = "$ns||$skey";

    $self->_redis->sadd('chinamespaces', $ns);
    unless($self->_redis->sismember($ns, $skey)) {
        $self->_redis->sadd($ns, $skey) ;
    }
    $self->_redis->set($realkey => $data);

    if(defined($expires_at)) {
        my $secs = $expires_at - time;
        $self->_redis->expire($realkey, $secs);
    }
}

sub _verify_redis_connection {
    my ($self) = @_;

    try {
        $self->_redis->ping;
    } catch {
        my $params = $self->_params;
        $self->_redis(
            Redis->new(
                server => $params->{server} || '127.0.0.1:6379',
                debug => $params->{debug} || 0
            )
        );
    };
}

__PACKAGE__->meta->make_immutable;

no Moose;

__END__

=head1 NAME

CHI::Driver::Redis - CHI Driver for Redis

=head1 SYNOPSIS

    use CHI::Driver::Redis;

    my $foo = CHI::Driver::Redis->new(driver => 'Redis');
    ...

=head1 DESCRIPTION

This cache driver uses Redis as a backend for storing data.

=head1 AUTHOR

Cory G Watson, C<< <gphat at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Cold Hard Code, LLC.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
