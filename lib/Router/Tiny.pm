package Router::Tiny;

# ABSTRACT: a tiny route matching system

use strict;
use warnings;
use Carp ();

sub new {
  my $class = shift;
  return bless {
    rules => [],

    ## TODO: match_ops should have API to add new match ops
    ## this are only the default ones, for each criteria, which $env key to use
    ## MAYBE: support criteria => sub {}
    match_ops => {
      host   => 'HTTP_HOST',
      path   => 'PATH_INFO',
      method => 'REQUEST_METHOD',
    },
  }, $class;
}

sub add {
  my ($self, $rule, @rest) = shift;

  push @{$self->{rules}}, [$rule, \@rest];

  return;
}

sub match_order {qw( host path method )}

sub match {
  my ($self, $env) = @_;

  my $rules       = $self->{rules};
  my $match_ops   = $self->{match_ops};
  my @match_order = $self->match_order;
  my $best_match;

  ## TODO: try to precalculate $env fields to match based on @match_order
  ## Something like:
  ##
  ##  my %relevant_env = ( map { $_ => $env->{$match_ops->{$_}} } @match_order );
  ##
  ## We would loose flexibility if we ever decide to support match_ops as sub {} though

RULE: for my $rule_spec (@$rules) {
    my $rule = $rule_spec->[0];

    my %cur_match;
  CRITERIA: for my $criteria (@match_order) {
      next CRITERIA unless exists $rule->{$criteria};

      my $match_rule = $rule->{$criteria};
      my $req_value  = $env->{$match_ops->{$criteria}};

      my $stuff = _match($match_rule, $req_value);
      if (!defined $stuff) {    ## Failed to match
        $best_match = $self->best_match($best_match, \%cur_match);
        next RULE;
      }

      $cur_match{$criteria} = $stuff;
    }

    ## Match found!
    return {
      matched   => $rule,
      collected => \%cur_match,
      info      => $rule_spec->[1],
    };
  }

  return {best => $best_match};
}

## TODO: _match could be relevant to subclasses that want to add there own match_ops, maybe export_ok it?
sub _match {
  my ($rule, $value) = @_;
  my $type = ref($rule);

  return $value eq $rule unless $type;
  return $value =~ $rule if $type eq 'Regexp';
  return $rule->match($value) if blessed($rule);

  Carp::confess("Don't know how to match $rule, ");
}

sub best_match {
  my ($self, $cur, $new) = @_;

  ## TBD: is this the best we can do *by default*?
  ## If want smarter, you can always subclass and override
  return $new unless defined $cur;
  return $new if keys %$new > keys %$cur;
  return $cur;
}

1;
