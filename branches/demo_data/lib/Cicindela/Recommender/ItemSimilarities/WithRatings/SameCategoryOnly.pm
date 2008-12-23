package Cicindela::Recommender::ItemSimilarities::WithRatings::SameCategoryOnly;

# $Id$

use strict;
use base qw(Cicindela::Recommender::ItemSimilarities::SameCategoryOnly Cicindela::Recommender::ItemSimilarities::WithRatings);
use Cicindela::Config::MixIn;
use Cicindela::Utils qw(:standard);

our $LOGGER = init_logger(config->log_conf, 1);

1;
