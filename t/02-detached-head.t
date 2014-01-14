use strict;
use warnings;

use Test::More;
use Path::Tiny;
use FindBin;
use Cwd qw( cwd );
use File::Copy::Recursive qw( rcopy );
use Git::Wrapper::Plus::Tester;
use Git::Wrapper::Plus::Support;

use Test::Fatal;
use Test::DZil;

my $dist   = 'fake_dist_02';
my $source = path($FindBin::Bin)->parent()->child('corpus')->child($dist);

my $t = Git::Wrapper::Plus::Tester->new();
my $s = Git::Wrapper::Plus::Support->new( git => $t->git );

my $tempdir = $t->repo_dir;

rcopy( "$source", "$tempdir" );

$t->run_env(
  sub {

    my $git = $t->git;

    if ( not $s->supports_behavior('can-checkout-detached') ) {
      plan skip_all => 'This version of Git cannot checkout detached heads';
      return;
    }
    if ( not $s->supports_command('init-db') ) {
      plan skip_all => 'This version of Git cannot init-db';
      return;
    }
    if ( not $s->supports_command('update-index') ) {
      plan skip_all => 'This version of Git cannot update-index';
      return;
    }

    my $excp = exception {
      $git->init_db();
      $git->add('Changes');
      $git->add('dist.ini');
      $git->add('lib/E.pm');
      local $ENV{'GIT_COMMITTER_DATE'} = '1388534400 +1300';
      $git->commit( '-m', 'First Commit' );
      $tempdir->child('Changes')->spew_raw('Sample modification');
      $git->update_index('Changes');
      local $ENV{'GIT_COMMITTER_DATE'} = '1388534500 +1300';
      $git->commit( '-m', 'Second commit' );
      $git->checkout('HEAD^1');
    };
    is( $excp, undef, 'Git::Wrapper test preparation did not fail' )
      or diag $excp;

    my $dist_ini = $tempdir->child('dist.ini');
    BAIL_OUT("test setup failed to copy to tempdir")
      if not -e $dist_ini and -f $dist_ini;

    my $conf;
    is(
      exception {

        $conf = Builder->from_config( { dist_root => "$tempdir" } );
        $conf->build;

      },
      undef,
      "dzil build ran ok"
    );
    for my $file ( @{ $conf->files } ) {
      next if $file->name ne 'Changes';
      like( $file->encoded_content, qr/0.01\s+2014-01-01\s+00:01:40/, "Specified commit timestamp in changelog" );
    }
  }
);
done_testing;

