package Cicindela::Filters::RawSQL;

# $Id$

use strict;
use base qw(Cicindela::Filters);
use Cicindela::Config::MixIn;
use Cicindela::Utils qw(:standard);

our $LOGGER = init_logger(config->log_conf, 1);

sub online_swaps { shift->{online_swaps} }
sub lock_tables { shift->{lock_tables} }
sub sqls {
    my $self = shift;

    return $self->{sqls},
}

1;
