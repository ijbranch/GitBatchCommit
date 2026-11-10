(* GITLAK Software
  ***************************************************************************

    © 2026 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit test suite.

  Test.GitRepoManager.Pure.pas - the routines of uGitRepoManager that need no
  Git repository: names, paths, patterns, redaction, decoding and the child
  process runner.

  ***************************************************************************
*)

unit Test.GitRepoManager.Pure;

interface

uses
  DUnitX.TestFramework,
  uGitRepoManager,
  Test.Support;

{$M+}

type
  /// <summary>
  ///   Repository names, repository paths, staging patterns and the
  ///   <c>.git</c> probe.
  /// </summary>
  [TestFixture]
  TTestNamesAndPaths = class
  private
    /// <summary>
    ///   The temporary folder of the running test.
    /// </summary>
    FSandbox: TGitSandbox;
  public
    /// <summary>
    ///   Creates the test's temporary folder.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the test's temporary folder.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves whitespace is DROPPED, not replaced, so a "Title Case" folder
    ///   gives one unbroken name - the documented reason the routine exists.
    /// </summary>
    [Test]
    procedure SanitiseDropsWhitespace;

    /// <summary>
    ///   Proves every other character outside [A-Za-z0-9._-] becomes '-', runs
    ///   of '-' collapse to one, and leading and trailing separators go.
    /// </summary>
    [Test]
    procedure SanitiseReplacesCollapsesAndTrims;

    /// <summary>
    ///   Proves a name with nothing usable in it yields 'repo' and never an
    ///   empty string GitHub would reject.
    /// </summary>
    [Test]
    procedure SanitiseFallsBackToRepo;

    /// <summary>
    ///   Proves whatever the sanitiser returns is accepted by the validator,
    ///   which is the contract the New Repository dialog depends on.
    /// </summary>
    [Test]
    procedure SanitisedNamesAreValid;

    /// <summary>
    ///   Proves names made only of the permitted characters are accepted,
    ///   including the 100-character maximum.
    /// </summary>
    [Test]
    procedure ValidNamesAreAccepted;

    /// <summary>
    ///   Proves the documented refusals: empty, the two reserved directory
    ///   names, 101 characters, and any character outside the permitted set.
    /// </summary>
    [Test]
    procedure InvalidNamesAreRefused;

    /// <summary>
    ///   Proves a name ending in a line feed is refused.  The name is sent
    ///   "exactly as it would be sent", so a trailing newline is not one of
    ///   the permitted characters.
    /// </summary>
    [Test]
    procedure NameEndingInLineFeedIsRefused;

    /// <summary>
    ///   Proves an empty pattern and ordinary comma- or space-separated globs
    ///   are safe.
    /// </summary>
    [Test]
    procedure GlobPatternsAreSafe;

    /// <summary>
    ///   Proves each shell metacharacter and a control character makes a
    ///   pattern unsafe, one character at a time so that no single one can be
    ///   let through unnoticed.
    /// </summary>
    [Test]
    procedure ShellMetacharactersAreUnsafe;

    /// <summary>
    ///   Proves a pattern starting with '-' is accepted: '-' is a path
    ///   character, and the staging command ends option parsing before the
    ///   pattern ( see TTestCommitAndPush.PatternStartingWithDashIsAPath ).
    /// </summary>
    [Test]
    procedure PatternStartingWithDashIsAccepted;

    /// <summary>
    ///   Proves a path is trimmed and loses its trailing delimiter, so one
    ///   folder has one spelling.
    /// </summary>
    [Test]
    procedure NormaliseTrimsAndDropsTrailingDelimiter;

    /// <summary>
    ///   Proves a <c>.git</c> FOLDER counts, as in an ordinary clone.
    /// </summary>
    [Test]
    procedure GitFolderIsAGitEntry;

    /// <summary>
    ///   Proves a <c>.git</c> FILE counts, as in a linked worktree or a
    ///   submodule.
    /// </summary>
    [Test]
    procedure GitFileIsAGitEntry;

    /// <summary>
    ///   Proves a folder with neither is not reported as a repository.
    /// </summary>
    [Test]
    procedure FolderWithoutGitIsNotAGitEntry;
  end;

  /// <summary>
  ///   Secret redaction, the two enumeration labels and lenient decoding.
  /// </summary>
  [TestFixture]
  TTestTextHelpers = class
  private
    /// <summary>
    ///   The temporary folder of the running test.
    /// </summary>
    FSandbox: TGitSandbox;
    /// <summary>
    ///   A manager on the sandbox's configuration file; assigning its token
    ///   registers the token for redaction.
    /// </summary>
    FManager: TGitRepoManager;
  public
    /// <summary>
    ///   Creates the temporary folder and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Clears the registered token, then frees the manager and the folder.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves both halves of <c>https://user:token@host</c> are masked and
    ///   the rest of the line, host and path included, is kept.
    /// </summary>
    [Test]
    procedure UserAndTokenInUrlAreMasked;

    /// <summary>
    ///   Proves the scheme is matched whatever its case and that every URL in
    ///   a text is masked, not only the first.
    /// </summary>
    [Test]
    procedure EveryUrlIsMaskedWhateverTheSchemeCase;

    /// <summary>
    ///   Proves a long opaque userinfo is masked while a short owner name,
    ///   which is no secret, is kept.
    /// </summary>
    [Test]
    procedure LongUserInfoIsMaskedShortOwnerIsKept;

    /// <summary>
    ///   Proves bare provider token literals and Authorization header values
    ///   are masked, keeping the prefix that says what they were.
    /// </summary>
    [Test]
    procedure TokenLiteralsAndHeadersAreMasked;

    /// <summary>
    ///   Proves text holding no credential, and empty text, come back
    ///   unchanged.
    /// </summary>
    [Test]
    procedure TextWithoutSecretsIsUnchanged;

    /// <summary>
    ///   Proves the token assigned to the manager is masked by exact match
    ///   wherever it appears, and is no longer masked once cleared.
    /// </summary>
    [Test]
    procedure TheLiveTokenIsMaskedByValue;

    /// <summary>
    ///   Proves every status has its own label, against labels typed out here.
    /// </summary>
    [Test]
    procedure EveryStatusHasItsLabel;

    /// <summary>
    ///   Proves every provider has its own label, against labels typed out
    ///   here.
    /// </summary>
    [Test]
    procedure EveryProviderHasItsLabel;

    /// <summary>
    ///   Proves valid UTF-8 decodes to the characters it encodes.
    /// </summary>
    [Test]
    procedure ValidUtf8Decodes;

    /// <summary>
    ///   Proves an invalid byte becomes U+FFFD between its intact neighbours
    ///   instead of raising.
    /// </summary>
    [Test]
    procedure InvalidByteBecomesReplacementCharacter;

    /// <summary>
    ///   Proves a multi-byte character cut short at the end of the buffer
    ///   does not raise and is replaced.
    /// </summary>
    [Test]
    procedure TruncatedSequenceDoesNotRaise;

    /// <summary>
    ///   Proves only the first <c>iCount</c> bytes are decoded, that a count
    ///   past the end is clamped, and that nothing gives an empty string.
    /// </summary>
    [Test]
    procedure CountLimitsWhatIsDecoded;
  end;

  /// <summary>
  ///   <c>RunProcessCaptureOutput</c>: exit code, the two streams, a command
  ///   that cannot start, and the timeout.
  /// </summary>
  [TestFixture]
  TTestRunProcess = class
  private
    /// <summary>
    ///   The temporary folder of the running test.
    /// </summary>
    FSandbox: TGitSandbox;
  public
    /// <summary>
    ///   Creates the test's temporary folder.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the test's temporary folder.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves exit code 0 is the only success: 0 gives True, anything else
    ///   False.
    /// </summary>
    [Test]
    procedure ExitCodeDecidesTheResult;

    /// <summary>
    ///   Proves both streams are captured by default, standard output first.
    /// </summary>
    [Test]
    procedure BothStreamsAreCapturedByDefault;

    /// <summary>
    ///   Proves <c>bStdOutOnly</c> leaves standard error out of a SUCCESSFUL
    ///   result, so a warning cannot land in text a caller parses.
    /// </summary>
    [Test]
    procedure StdOutOnlyLeavesOutStandardError;

    /// <summary>
    ///   Proves <c>bStdOutOnly</c> still returns standard error when the
    ///   command FAILED, because then it is the diagnostic.
    /// </summary>
    [Test]
    procedure StdOutOnlyKeepsStandardErrorOnFailure;

    /// <summary>
    ///   Proves a missing executable gives False and the reason, not False
    ///   with empty output.
    /// </summary>
    [Test]
    procedure MissingExecutableReportsWhy;

    /// <summary>
    ///   Proves a missing working directory gives False and the reason.
    /// </summary>
    [Test]
    procedure MissingWorkingFolderReportsWhy;

    /// <summary>
    ///   Proves a command that outlives the timeout gives False, says it timed
    ///   out, and is KILLED rather than waited for.
    /// </summary>
    [Test]
    procedure TimeoutKillsAndReports;

    /// <summary>
    ///   Proves the command runs in the working directory it was given.
    /// </summary>
    [Test]
    procedure RunsInTheGivenWorkingFolder;

    /// <summary>
    ///   Proves output is decoded as UTF-8, non-ASCII characters intact.
    /// </summary>
    [Test]
    procedure OutputIsDecodedAsUtf8;

    /// <summary>
    ///   Proves the child gets a real, empty standard input: a command that
    ///   reads it sees end-of-file and carries on instead of stalling.
    /// </summary>
    [Test]
    procedure ChildReadsEndOfFileFromStandardInput;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Diagnostics;

const
  /// <summary>
  ///   Generous bound, in milliseconds, for a command that should end at once.
  /// </summary>
  QUICK_COMMAND_TIMEOUT = 30000;

{ TTestNamesAndPaths }

procedure TTestNamesAndPaths.Setup;
begin

  FSandbox := TGitSandbox.Create;

end;

procedure TTestNamesAndPaths.TearDown;
begin

  FreeAndNil( FSandbox );

end;

procedure TTestNamesAndPaths.SanitiseDropsWhitespace;
begin

  Assert.AreEqual( 'FrontDoorCamera', SanitiseRepoName( 'Front Door Camera' ), False );
  Assert.AreEqual( 'Tabbed', SanitiseRepoName( 'Tab' + #9 + 'bed' ), False );

end;

procedure TTestNamesAndPaths.SanitiseReplacesCollapsesAndTrims;
begin

  Assert.AreEqual( 'myrepo-v2', SanitiseRepoName( 'my repo (v2)!' ), False );
  Assert.AreEqual( 'a-b', SanitiseRepoName( 'a&&&b' ), False );
  Assert.AreEqual( 'x', SanitiseRepoName( '_x_' ), False );
  Assert.AreEqual( 'caf', SanitiseRepoName( 'café' ), False );
  Assert.AreEqual( 'Keep.These_Chars-1', SanitiseRepoName( 'Keep.These_Chars-1' ), False );

end;

procedure TTestNamesAndPaths.SanitiseFallsBackToRepo;
begin

  Assert.AreEqual( 'repo', SanitiseRepoName( '' ), False );
  Assert.AreEqual( 'repo', SanitiseRepoName( '   ' ), False );
  Assert.AreEqual( 'repo', SanitiseRepoName( '...' ), False );
  Assert.AreEqual( 'repo', SanitiseRepoName( '!!!' ), False );

end;

procedure TTestNamesAndPaths.SanitisedNamesAreValid;
begin

  for var sRaw in [ 'Front Door Camera', 'my repo (v2)!', '', '..', '.', 'ünïcödé', '$(evil)', 'a/b\c' ] do
    Assert.IsTrue( IsValidRepoName( SanitiseRepoName( sRaw ) ), Format( '"%s" sanitised to "%s"', [ sRaw, SanitiseRepoName( sRaw ) ] ) );

end;

procedure TTestNamesAndPaths.ValidNamesAreAccepted;
begin

  for var sName in [ 'a', 'A.b_c-1', '...', '-', 'GitBatchCommit', StringOfChar( 'a', 100 ) ] do
    Assert.IsTrue( IsValidRepoName( sName ), sName );

end;

procedure TTestNamesAndPaths.InvalidNamesAreRefused;
begin

  for var sName in [ '', '.', '..', 'has space', 'x/y', 'x\y', 'caf' + #$E9, 'a;b', StringOfChar( 'a', 101 ) ] do
    Assert.IsFalse( IsValidRepoName( sName ), sName );

end;

procedure TTestNamesAndPaths.NameEndingInLineFeedIsRefused;
begin

  Assert.IsFalse( IsValidRepoName( 'abc' + #10 ) );

end;

procedure TTestNamesAndPaths.GlobPatternsAreSafe;
begin

  for var sPattern in [ '', '   ', '*.pas', 'src/*.pas docs/*.md', '*.pas,*.dfm', 'src\Unit?.pas', '[a-c]*.txt', 'C:/x/*.pas' ] do
    Assert.IsTrue( TGitRepoManager.IsSafeFilePattern( sPattern ), sPattern );

end;

procedure TTestNamesAndPaths.ShellMetacharactersAreUnsafe;
begin

  for var cBad in TArray<Char>.Create( ';', '&', '|', '<', '>', '$', '`', '"', '''', '(', ')', '%', '!', '^', '{', '}', '~', '#', '=',
    '+', '@', #9, #10, #13 ) do
    Assert.IsFalse( TGitRepoManager.IsSafeFilePattern( '*.pas' + cBad + 'x' ), Format( 'character #%d', [ Ord( cBad ) ] ) );

end;

procedure TTestNamesAndPaths.PatternStartingWithDashIsAccepted;
begin

  Assert.IsTrue( TGitRepoManager.IsSafeFilePattern( '-dash.txt' ) );
  Assert.IsTrue( TGitRepoManager.IsSafeFilePattern( '--all' ) );

end;

procedure TTestNamesAndPaths.NormaliseTrimsAndDropsTrailingDelimiter;
begin

  Assert.AreEqual( 'D:\Repo', TGitRepoManager.NormaliseRepoPath( 'D:\Repo' ), False );
  Assert.AreEqual( 'D:\Repo', TGitRepoManager.NormaliseRepoPath( 'D:\Repo\' ), False );
  Assert.AreEqual( 'D:\My Repo', TGitRepoManager.NormaliseRepoPath( '  D:\My Repo\  ' ), False );
  Assert.AreEqual( '', TGitRepoManager.NormaliseRepoPath( '   ' ), False );

end;

procedure TTestNamesAndPaths.GitFolderIsAGitEntry;
begin

  var sFolder := FSandbox.MakeFolder( 'clone' );

  FSandbox.MakeFolder( 'clone\.git' );

  Assert.IsTrue( TGitRepoManager.HasGitEntry( sFolder ) );

end;

procedure TTestNamesAndPaths.GitFileIsAGitEntry;
begin

  var sFolder := FSandbox.MakeFolder( 'worktree' );

  FSandbox.WriteText( sFolder, '.git', 'gitdir: ../main/.git/worktrees/worktree' + #10 );

  Assert.IsTrue( TFile.Exists( TPath.Combine( sFolder, '.git' ) ), 'arrangement: .git must be a file' );
  Assert.IsTrue( TGitRepoManager.HasGitEntry( sFolder ) );

end;

procedure TTestNamesAndPaths.FolderWithoutGitIsNotAGitEntry;
begin

  var sFolder := FSandbox.MakeFolder( 'plain' );

  FSandbox.WriteText( sFolder, 'git.txt', 'not a repository' );

  Assert.IsFalse( TGitRepoManager.HasGitEntry( sFolder ) );
  Assert.IsFalse( TGitRepoManager.HasGitEntry( FSandbox.PathOf( 'does-not-exist' ) ) );

end;

{ TTestTextHelpers }

procedure TTestTextHelpers.Setup;
begin

  FSandbox := TGitSandbox.Create;
  FManager := FSandbox.NewManager;

end;

procedure TTestTextHelpers.TearDown;
begin

  // The registered token is process-wide; it must not leak into another test.
  if Assigned( FManager ) then
    FManager.GitHubToken := '';

  FreeAndNil( FManager );
  FreeAndNil( FSandbox );

end;

procedure TTestTextHelpers.UserAndTokenInUrlAreMasked;
begin

  Assert.AreEqual( 'fatal: unable to access ''https://***:***@github.com/owner/repo.git/'': 403',
    RedactSecrets( 'fatal: unable to access ''https://ian:s3cretTok@github.com/owner/repo.git/'': 403' ), False );

end;

procedure TTestTextHelpers.EveryUrlIsMaskedWhateverTheSchemeCase;
begin

  Assert.AreEqual( 'HTTP://***:***@one.example/x then https://***:***@two.example/y',
    RedactSecrets( 'HTTP://User:Pw@one.example/x then https://other:pw2@two.example/y' ), False );

end;

procedure TTestTextHelpers.LongUserInfoIsMaskedShortOwnerIsKept;
begin

  Assert.AreEqual( 'https://***@codeberg.org/x.git',
    RedactSecrets( 'https://0123456789abcdef0123456789abcdef01234567@codeberg.org/x.git' ), False );
  Assert.AreEqual( 'https://GITLAK@codeberg.org/GITLAK/x.git', RedactSecrets( 'https://GITLAK@codeberg.org/GITLAK/x.git' ), False );

end;

procedure TTestTextHelpers.TokenLiteralsAndHeadersAreMasked;
begin

  Assert.AreEqual( 'token ghp_*** end', RedactSecrets( 'token ghp_ABCDEFGHIJKLMNOP1234 end' ), False );
  Assert.AreEqual( 'pat github_pat_*** end', RedactSecrets( 'pat github_pat_11ABCDEFG0abcdefghij_klmnop end' ), False );
  Assert.AreEqual( 'Authorization: Bearer ***', RedactSecrets( 'Authorization: Bearer abc.def.ghi' ), False );
  Assert.AreEqual( 'authorization: token ***', RedactSecrets( 'authorization: token abc123' ), False );

end;

procedure TTestTextHelpers.TextWithoutSecretsIsUnchanged;
begin

  Assert.AreEqual( '', RedactSecrets( '' ), False );
  Assert.AreEqual( 'To https://github.com/owner/repo.git' + sLineBreak + '   1a2b3c4..5d6e7f8  main -> main',
    RedactSecrets( 'To https://github.com/owner/repo.git' + sLineBreak + '   1a2b3c4..5d6e7f8  main -> main' ), False );
  Assert.AreEqual( 'git@github.com:owner/repo.git', RedactSecrets( 'git@github.com:owner/repo.git' ), False );

end;

procedure TTestTextHelpers.TheLiveTokenIsMaskedByValue;
begin

  Assert.AreEqual( 'sent LiveTokenValue-0042 ok', RedactSecrets( 'sent LiveTokenValue-0042 ok' ), False, 'before it is registered' );

  FManager.GitHubToken := 'LiveTokenValue-0042';

  Assert.AreEqual( 'sent *** ok, again ***', RedactSecrets( 'sent LiveTokenValue-0042 ok, again LiveTokenValue-0042' ), False );

  FManager.GitHubToken := '';

  Assert.AreEqual( 'sent LiveTokenValue-0042 ok', RedactSecrets( 'sent LiveTokenValue-0042 ok' ), False, 'after it is cleared' );

end;

procedure TTestTextHelpers.EveryStatusHasItsLabel;
begin

  Assert.AreEqual( 'Clean', RepoStatusToString( rsClean ), False );
  Assert.AreEqual( 'Modified', RepoStatusToString( rsModified ), False );
  Assert.AreEqual( 'Conflicted', RepoStatusToString( rsConflicted ), False );
  Assert.AreEqual( 'Pull Required', RepoStatusToString( rsPullRequired ), False );
  Assert.AreEqual( 'Push Required', RepoStatusToString( rsPushRequired ), False );
  Assert.AreEqual( 'Diverged', RepoStatusToString( rsDiverged ), False );
  Assert.AreEqual( 'Error', RepoStatusToString( rsError ), False );
  Assert.AreEqual( 'Unknown', RepoStatusToString( rsUnknown ), False );
  Assert.AreEqual( 7, Ord( High( TRepoStatus ) ), 'a status was added: give it a label and a line here' );

end;

procedure TTestTextHelpers.EveryProviderHasItsLabel;
begin

  Assert.AreEqual( 'None', RemoteProviderToString( rpNone ), False );
  Assert.AreEqual( 'GitHub', RemoteProviderToString( rpGitHub ), False );
  Assert.AreEqual( 'Other', RemoteProviderToString( rpOther ), False );
  Assert.AreEqual( 2, Ord( High( TRemoteProvider ) ), 'a provider was added: give it a label and a line here' );

end;

procedure TTestTextHelpers.ValidUtf8Decodes;
begin

  // 'Z', u-umlaut ( C3 BC ), euro sign ( E2 82 AC ).
  var naBytes := TBytes.Create( $5A, $C3, $BC, $E2, $82, $AC );

  Assert.AreEqual( 'Z' + #$00FC + #$20AC, DecodeUtf8Lenient( naBytes, Length( naBytes ) ), False );

end;

procedure TTestTextHelpers.InvalidByteBecomesReplacementCharacter;
begin

  var naBytes := TBytes.Create( $41, $FF, $42 );
  var sText   := '';

  Assert.WillNotRaiseAny(
    procedure
    begin
      sText := DecodeUtf8Lenient( naBytes, Length( naBytes ) );
    end );

  Assert.AreEqual( 'A' + #$FFFD + 'B', sText, False );

end;

procedure TTestTextHelpers.TruncatedSequenceDoesNotRaise;
begin

  // 'A' then the first two of the euro sign's three bytes.
  var naBytes := TBytes.Create( $41, $E2, $82 );
  var sText   := '';

  Assert.WillNotRaiseAny(
    procedure
    begin
      sText := DecodeUtf8Lenient( naBytes, Length( naBytes ) );
    end );

  Assert.IsTrue( sText.StartsWith( 'A' ), 'the intact character survives' );
  Assert.IsTrue( sText.Contains( #$FFFD ), 'the cut sequence is replaced' );

end;

procedure TTestTextHelpers.CountLimitsWhatIsDecoded;
begin

  var naBytes := TBytes.Create( $41, $42, $43 );

  Assert.AreEqual( 'AB', DecodeUtf8Lenient( naBytes, 2 ), False );
  Assert.AreEqual( 'ABC', DecodeUtf8Lenient( naBytes, 99 ), False );
  Assert.AreEqual( '', DecodeUtf8Lenient( naBytes, 0 ), False );
  Assert.AreEqual( '', DecodeUtf8Lenient( nil, 5 ), False );

end;

{ TTestRunProcess }

procedure TTestRunProcess.Setup;
begin

  FSandbox := TGitSandbox.Create;

end;

procedure TTestRunProcess.TearDown;
begin

  FreeAndNil( FSandbox );

end;

procedure TTestRunProcess.ExitCodeDecidesTheResult;
var
  sOutput: string;
begin

  Assert.IsTrue( RunProcessCaptureOutput( 'cmd /c exit 0', '', sOutput, QUICK_COMMAND_TIMEOUT ), 'exit 0' );
  Assert.IsFalse( RunProcessCaptureOutput( 'cmd /c exit 1', '', sOutput, QUICK_COMMAND_TIMEOUT ), 'exit 1' );
  Assert.IsFalse( RunProcessCaptureOutput( 'cmd /c exit 7', '', sOutput, QUICK_COMMAND_TIMEOUT ), 'exit 7' );

end;

procedure TTestRunProcess.BothStreamsAreCapturedByDefault;
var
  sOutput: string;
begin

  Assert.IsTrue( RunProcessCaptureOutput( 'cmd /c "echo out& echo err 1>&2"', '', sOutput, QUICK_COMMAND_TIMEOUT ) );

  var saLines := sOutput.Split( [ #13, #10 ], TStringSplitOptions.ExcludeEmpty );

  Assert.AreEqual( 2, Integer( Length( saLines ) ), sOutput );
  Assert.AreEqual( 'out', saLines[ 0 ].Trim, False );
  Assert.AreEqual( 'err', saLines[ 1 ].Trim, False );

end;

procedure TTestRunProcess.StdOutOnlyLeavesOutStandardError;
var
  sOutput: string;
begin

  Assert.IsTrue( RunProcessCaptureOutput( 'cmd /c "echo out& echo err 1>&2"', '', sOutput, QUICK_COMMAND_TIMEOUT, True ) );
  Assert.AreEqual( 'out', sOutput.Trim, False );

end;

procedure TTestRunProcess.StdOutOnlyKeepsStandardErrorOnFailure;
var
  sOutput: string;
begin

  Assert.IsFalse( RunProcessCaptureOutput( 'cmd /c "echo out& echo err 1>&2& exit 1"', '', sOutput, QUICK_COMMAND_TIMEOUT, True ) );
  Assert.IsTrue( sOutput.Contains( 'out' ), sOutput );
  Assert.IsTrue( sOutput.Contains( 'err' ), sOutput );

end;

procedure TTestRunProcess.MissingExecutableReportsWhy;
var
  sOutput: string;
begin

  var sMissing := FSandbox.PathOf( 'no-such-program.exe' );

  Assert.IsFalse( RunProcessCaptureOutput( Format( '"%s" /x', [ sMissing ] ), '', sOutput, QUICK_COMMAND_TIMEOUT ) );
  Assert.StartsWith( 'Could not start the command: ', sOutput, False );
  Assert.IsTrue( Length( sOutput ) > Length( 'Could not start the command: ' ), 'the system''s reason follows' );

end;

procedure TTestRunProcess.MissingWorkingFolderReportsWhy;
var
  sOutput: string;
begin

  Assert.IsFalse( RunProcessCaptureOutput( 'cmd /c exit 0', FSandbox.PathOf( 'no-such-folder' ), sOutput, QUICK_COMMAND_TIMEOUT ) );
  Assert.StartsWith( 'Could not start the command: ', sOutput, False );

end;

procedure TTestRunProcess.TimeoutKillsAndReports;
var
  sOutput: string;
begin

  // Thirty one-second pings of the loopback address: about 29 seconds, local.
  var rWatch := TStopwatch.StartNew;

  Assert.IsFalse( RunProcessCaptureOutput( 'ping -n 30 127.0.0.1', '', sOutput, 500 ) );

  rWatch.Stop;

  Assert.EndsWith( 'Operation timed out', sOutput, False );
  Assert.IsTrue( rWatch.ElapsedMilliseconds < 15000, Format( 'returned after %d ms: the child was waited for', [ rWatch.ElapsedMilliseconds ] ) );

end;

procedure TTestRunProcess.RunsInTheGivenWorkingFolder;
var
  sOutput: string;
begin

  var sFolder := FSandbox.MakeFolder( 'work here' );

  FSandbox.WriteText( sFolder, 'marker-file.txt', 'x' );

  Assert.IsTrue( RunProcessCaptureOutput( 'cmd /c dir /b', sFolder, sOutput, QUICK_COMMAND_TIMEOUT, True ) );
  Assert.AreEqual( 'marker-file.txt', sOutput.Trim, False );

end;

procedure TTestRunProcess.OutputIsDecodedAsUtf8;
var
  sOutput: string;
begin

  var sText := 'Z' + #$00FC + 'rich ' + #$20AC + '5';

  FSandbox.WriteText( FSandbox.Root, 'utf8.txt', sText );

  Assert.IsTrue( RunProcessCaptureOutput( 'cmd /c type utf8.txt', FSandbox.Root, sOutput, QUICK_COMMAND_TIMEOUT, True ) );
  Assert.AreEqual( sText, sOutput, False );

end;

procedure TTestRunProcess.ChildReadsEndOfFileFromStandardInput;
var
  sOutput: string;
begin

  // SET /P reads standard input.  With no usable handle it would stall until
  // the timeout; with the empty one it sees end-of-file at once.
  Assert.IsTrue( RunProcessCaptureOutput( 'cmd /c "set /p x=& echo done"', '', sOutput, QUICK_COMMAND_TIMEOUT, True ), sOutput );
  Assert.AreEqual( 'done', sOutput.Trim, False );

end;

initialization

  TDUnitX.RegisterTestFixture( TTestNamesAndPaths );
  TDUnitX.RegisterTestFixture( TTestTextHelpers );
  TDUnitX.RegisterTestFixture( TTestRunProcess );

end.
