use strict;
use warnings;

package Dist::Zilla::Plugin::Git::NextRelease;
BEGIN {
  $Dist::Zilla::Plugin::Git::NextRelease::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::Git::NextRelease::VERSION = '0.001000';
}

# ABSTRACT: Use timestamp from Git instead of process start time.

use Moose;
extends 'Dist::Zilla::Plugin::NextRelease';

use Git::Wrapper::Plus;
use DateTime;

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
      $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : '';
    },
    V => sub {
      $_[0]->zilla->version . ( $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : '' );
    },
  },
};

has 'branch' => (
  is         => ro =>,
  lazy_build => 1,
);
has _git_timestamp => (
  is         => ro =>,
  lazy_build => 1,
);
has '_gwp' => (
  is         => ro =>,
  lazy_build => 1,
);

sub _build__gwp {
  my ($self) = @_;
  return Git::Wrapper::Plus->new( '' . $self->zilla->root );
}

sub _build_branch {
  my ($self) = @_;
  my $cb = $self->_gwp->branches->current_branch;
  if ( not $cb ) {
    $self->log_fatal("Cannot determine branch to get timestamp from when not on a branch");
    die;
  }
  return $cb->name;
}

sub _build__git_timestamp {
  my ($self) = @_;
  my ( $branch, ) = $self->_gwp->branches->get_branch( $self->branch );
  if ( not $branch ) {
    $self->log_fatal( [ "Branch %s does not exist" . $self->branch ] );
  }
  my $sha1 = $branch->sha1;
  my ( $committer, ) = grep { $_ =~ /\Acommitter /msx } $self->_gwp->git->cat_file( 'commit', $sha1 );
  chomp $committer;
  if ( $committer =~ qr/\s+([0-9]+)\s+(\S+)$/ ) {
    return DateTime->from_epoch( epoch => $1, time_zone => $2 );
  }
  return $self->log_fatal( [ "Could not parse timestamp and timezone from string <%s>", $committer ] );
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

Dist::Zilla::Plugin::Git::NextRelease - Use timestamp from Git instead of process start time.

=head1 VERSION

version 0.001000

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
