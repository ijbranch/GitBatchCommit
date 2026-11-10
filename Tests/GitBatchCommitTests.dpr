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
  FastMM5,
  System.SysUtils,
  System.Math,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.Exceptions,
  DUnitX.TestFramework,
  uGitRepoManager in '..\uGitRepoManager.pas',
  Test.Support in 'Test.Support.pas',
  Test.GitRepoManager.Pure in 'Test.GitRepoManager.Pure.pas',
  Test.GitRepoManager.Config in 'Test.GitRepoManager.Config.pas',
  Test.GitRepoManager.Git in 'Test.GitRepoManager.Git.pas',
  Test.GitRepoManager.Parallel in 'Test.GitRepoManager.Parallel.pas';

{$R *.res}

var
  intfRunner: ITestRunner;
  intfResults: IRunResults;
  intfLogger: ITestLogger;
  intfNUnitLogger: ITestLogger;
  sXmlFile: string;

begin

  // Honour DUnitX's own options, above all --run:<names>.  An unknown option exits 251
  // rather than silently running the whole suite; a filter matching nothing exits 250.
  try
    TDUnitX.CheckCommandLine;
  except
    on E: ECommandLineError do
    begin
      Writeln( 'Command-line error: ' + E.Message );
      System.ExitCode := 251;
      Exit;
    end;
  end;

  try
    intfRunner := TDUnitX.CreateRunner;

    // Strict string comparison by default: paths, branch names and log text are compared exactly.
    Assert.IgnoreCaseDefault := False;

    // KEEP BOTH discovery mechanisms: gllDUnitX dedupes a fixture registered both ways.
    intfRunner.UseRTTI := True;

    intfLogger := TDUnitXConsoleLogger.Create( True );
    intfRunner.AddLogger( intfLogger );

    // The estate runner looks for <exeDir>\<exeBaseName>-results.xml.
    sXmlFile := TDUnitX.Options.XMLOutputFile;

    if ( sXmlFile = '' ) or SameText( ExtractFileName( sXmlFile ), 'dunitx-results.xml' ) then
      sXmlFile := ChangeFileExt( ParamStr( 0 ), '' ) + '-results.xml';

    intfNUnitLogger := TDUnitXXMLNUnitFileLogger.Create( sXmlFile );
    intfRunner.AddLogger( intfNUnitLogger );
    intfRunner.FailsOnNoAsserts := True;
    intfResults                 := intfRunner.Execute;

    if intfResults.TestCount = 0 then
      System.ExitCode := 250 // an empty run must never read as success
    else if ( not intfResults.AllPassed ) then
      System.ExitCode := Min( intfResults.FailureCount + intfResults.ErrorCount, 249 );
  except
    on E: Exception do
    begin
      Writeln( E.ClassName, ': ', E.Message );
      System.ExitCode := 251;
    end;
  end;

end.
