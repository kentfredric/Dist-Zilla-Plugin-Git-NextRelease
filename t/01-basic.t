use strict;
use warnings;

use Test::More;
use Path::Tiny;
use FindBin;
use Cwd qw( cwd );
use File::Copy::Recursive qw( rcopy );
use Git::Wrapper::Plus::Tester;
use Git::Wrapper::Plus::Versions;

use Test::Fatal;
use Test::DZil;

my $dist   = 'fake_dist_01';
my $source = path($FindBin::Bin)->parent()->child('corpus')->child($dist);

my $t = Git::Wrapper::Plus::Tester->new();
my $v = Git::Wrapper::Plus::Versions->new( git => $t->git );

my $tempdir = $t->repo_dir;

rcopy( "$source", "$tempdir" );

$t->run_env(
  sub {

    my $git = $t->git;

    my $excp = exception {
      if ( $v->newer_than('1.5') ) {
        $git->init();
      }
      else {
        $git->init_db();
      }
      $git->add('Changes');
      $git->add('dist.ini');
      $git->add('lib/E.pm');
      local $ENV{'GIT_COMMITTER_DATE'} = '1388534400 +1300';
      $git->commit('-m First Commit');
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
      like( $file->encoded_content, qr/0.01\s+2014-01-01\s+00:00:00/, "Specified commit timestamp in changelog" );
    }
  }
);
done_testing;

