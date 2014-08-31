use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::Git::NextRelease;

our $VERSION = '0.003000';

# ABSTRACT: Use time-stamp from Git instead of process start time.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( extends has around );
extends 'Dist::Zilla::Plugin::NextRelease';

use Git::Wrapper::Plus 0.003100;    # Fixed shallow commits
use DateTime;
use Dist::Zilla::Util::ConfigDumper qw( config_dumper );

use String::Formatter 0.100680 stringf => {
  -as => '_format_version',

  input_processor => 'require_single_input',
  string_replacer => 'method_replace',
  codes           => {
    v => sub { $_[0]->zilla->version },
    d => sub {
      my $t = $_[0]->_git_timestamp;
      $t = $t->set_time_zone( $_[0]->time_zone );
      return $t->format_cldr( $_[1] ),;
    },
    t => sub { "\t" },
    n => sub { "\n" },
    E => sub { $_[0]->_user_info('email') },
    U => sub { $_[0]->_user_info('name') },
    T => sub {
      $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : q[];
    },
    V => sub {
      $_[0]->zilla->version . ( $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : q[] );
    },
  },
};









has 'branch' => (
  is         => ro =>,
  lazy_build => 1,
);









has 'default_branch' => (
  is         => ro =>,
  lazy_build => 1,
  predicate  => 'has_default_branch',
);

sub _build_default_branch {
  my ($self) = @_;
  return $self->log_fatal('default_branch was used but not specified');
}

has _git_timestamp => (
  init_arg   => undef,
  is         => ro =>,
  lazy_build => 1,
);
has '_gwp' => (
  init_arg   => undef,
  is         => ro =>,
  lazy_build => 1,
);

around dump_config => config_dumper( __PACKAGE__, { attrs => [ 'default_branch', 'branch' ] } );

sub _build__gwp {
  my ($self) = @_;
  return Git::Wrapper::Plus->new( q[] . $self->zilla->root );
}

sub _build_branch {
  my ($self) = @_;
  my $cb = $self->_gwp->branches->current_branch;
  if ( not $cb ) {
    if ( not $self->has_default_branch ) {
      $self->log_fatal(
        [
              q[Cannot determine branch to get timestamp from when not on a branch.]
            . q[Specify default_branch if you want this to work here.],
        ],
      );
    }
    return $self->default_branch;
  }
  return $cb->name;
}

sub _build__git_timestamp {
  my ($self) = @_;
  my ( $branch, ) = $self->_gwp->branches->get_branch( $self->branch );
  if ( not $branch ) {
    $self->log_fatal( [ q[Branch %s does not exist], $self->branch ] );
  }
  my ( $committer, ) = grep { $_ =~ /\Acommitter /msx } $self->_gwp->git->cat_file( 'commit', $branch->sha1 );
  chomp $committer;
  ## no critic ( Compatibility::PerlMinimumVersionAndWhy )
  if ( $committer =~ qr/\s+(\d+)\s+(\S+)\z/msx ) {
    return DateTime->from_epoch( epoch => $1, time_zone => $2 );
  }
  return $self->log_fatal( [ q[Could not parse timestamp and timezone from string <%s>], $committer ] );
}










sub section_header {
  my ($self) = @_;

  return _format_version( $self->format, $self );
}
__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Git::NextRelease - Use time-stamp from Git instead of process start time.

=head1 VERSION

version 0.003000

=head1 SYNOPSIS

This module acts as a moderately thin wrapper to L<< C<[NextRelease]>|Dist::Zilla::Plugin::NextRelease >>
so that the time-stamps produced are generated by asking C<git> for the time-stamp of the current branch.

If you always require a specific branch for generating time-stamps, it can be specified as a parameter.

    -[NextRelease]
    +[Git::NextRelease]

Optionally:

    +branch = master

Or:

    +default_branch = master

( The latter only having impact in detached-head conditions )

This exists mostly because of my extensive use of L<< C<[Git::CommitBuild]>|Dist::Zilla::Plugin::Git::CommitBuild >>, to provide
a commit series for both releases, and builds of all changes/commits in order to push them to Travis for testing. ( Mostly,
because testing a build branch is substantially faster than testing a master that requires C<Dist::Zilla>, especially if you're
doing "Fresh install" testing like I am. )

=head1 METHODS

=head2 C<section_header>

This is the sole method of L<< C<[NextRelease]>|Dist::Zilla::Plugin::NextRelease >> that we override,
in order for it to inject the right things.

This method basically returns the date string to append to the Changes header.

=head1 ATTRIBUTES

=head2 C<branch>

If set, always use the specified branch to determine time-stamp.

Default value is resolved from determining "current" branch.

=head2 C<default_branch>

If you want being on a branch to always resolve to that branch,
but you still want a useful behavior when on a detached head,
specifying this value means that on a detached head, the stated branch will be used instead.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
