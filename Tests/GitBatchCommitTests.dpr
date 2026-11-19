{---------------------------------------------------------------------------}
{ GitBatchCommit - DUnitX console test runner                               }
{                                                                           }
{ Tests the engine unit, uGitRepoManager.  Every test works in its own      }
{ temporary folder: the configuration file, every Git repository and every  }
{ "origin" live there, and nothing contacts the network or reads the        }
{ user's configuration or repositories.                                     }
{                                                                           }
{ Exit code: 0 green; failures plus errors clamped at 249; 250 no tests     }
{ ran; 251 the runner itself raised ( an unknown option included ).         }
{                                                                           }
{ (c) 2026 GITLAK Software.                                                 }
{---------------------------------------------------------------------------}
program GitBatchCommitTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  // FastMM5 FIRST, as the memory manager the per-test leak check measures ( GllDUnitX.SuiteRunner )
  FastMM5,
  System.SysUtils,
  DUnitX.TestFramework,
  GllDUnitX.SuiteRunner,
  uGitRepoManager in '..\uGitRepoManager.pas',
  Test.Support in 'Test.Support.pas',
  Test.GitRepoManager.Pure in 'Test.GitRepoManager.Pure.pas',
  Test.GitRepoManager.Config in 'Test.GitRepoManager.Config.pas',
  Test.GitRepoManager.Git in 'Test.GitRepoManager.Git.pas',
  Test.GitRepoManager.Parallel in 'Test.GitRepoManager.Parallel.pas',
  Test.GitRepoManager.Http in 'Test.GitRepoManager.Http.pas';

{$R *.res}

begin

  // Every test is checked for memory leaks by GllDUnitX.SuiteRunner ( 2026-11-19 ): a warm-up pass, the measured pass
  // under FastMM5, then a re-run of each flagged test; only a leak that repeats counts.  It also checks the command
  // line ( --run:<names>; an unknown option exits 251 ), keeps both discovery mechanisms ( gllDUnitX dedupes a fixture
  // registered both ways ) and FailsOnNoAsserts, writes the NUnit XML to <exeDir>\<exeBaseName>-results.xml where the
  // estate runner looks, and sets the exit code: 0 all passed; n = failures + errors ( warm-up failures and confirmed
  // leaks included ), clamped to 249; 250 no tests found; 251 the runner itself raised.
  try
    // Strict string comparison by default: paths, branch names and log text are compared exactly.
    Assert.IgnoreCaseDefault := False;

    RunGllSuite( TGllSuiteOptions.Defaults );
  except
    on E: Exception do
    begin
      Writeln( 'Runner error  : ', E.ClassName, ': ', E.Message );
      System.ExitCode := 251;
    end;
  end;

end.
