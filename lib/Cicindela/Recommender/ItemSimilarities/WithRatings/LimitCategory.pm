package Cicindela::Recommender::ItemSimilarities::WithRatings::LimitCategory;

# $Id$

use strict;
use base qw(Cicindela::Recommender::ItemSimilarities::LimitCategory Cicindela::Recommender::ItemSimilarities::WithRatings);
use Cicindela::Config::MixIn;
use Cicindela::Utils qw(:standard);

our $LOGGER = init_logger(config->log_conf, 1);

1;
