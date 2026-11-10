(* GITLAK Software
  ***************************************************************************

    © 2026 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit test suite.

  Test.GitRepoManager.Config.pas - configuration safety ( load, save, the
  unreadable file, the access token at rest ) and the in-memory lists: the
  repositories, groups, commit history and templates.

  ***************************************************************************
*)

unit Test.GitRepoManager.Config;

interface

uses
  DUnitX.TestFramework,
  uGitRepoManager,
  Test.Support;

{$M+}

type
  /// <summary>
  ///   Loading and saving the configuration file.  Every test uses a file in
  ///   its own temporary folder.
  /// </summary>
  [TestFixture]
  TTestConfigSafety = class
  private
    /// <summary>
    ///   The temporary folder of the running test.
    /// </summary>
    FSandbox: TGitSandbox;

    /// <summary>
    ///   Writes the sandbox's configuration file with exactly this text.
    /// </summary>
    /// <param name="sText">The file's content, written as UTF-8 without a BOM.</param>
    procedure WriteConfig( const sText: string );

    /// <summary>
    ///   Lists the copies LoadConfig set aside.
    /// </summary>
    /// <returns>Every <c>repositories.json.unreadable-*</c> file beside the configuration file.</returns>
    function UnreadableCopies: TArray<string>;
  public
    /// <summary>
    ///   Creates the test's temporary folder.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Clears the process-wide registered token and removes the folder.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves a missing file is a clean first run: True, no error, nothing
    ///   loaded, and the first save creates the file.
    /// </summary>
    [Test]
    procedure MissingFileIsACleanFirstRun;

    /// <summary>
    ///   Proves an empty file loads as an empty configuration, as documented,
    ///   and is not set aside as unreadable.
    /// </summary>
    [Test]
    procedure EmptyFileLoadsAsEmpty;

    /// <summary>
    ///   Proves everything saved comes back in a second manager: repositories
    ///   in order with their groups, the history, the templates and all six
    ///   settings.
    /// </summary>
    [Test]
    procedure SaveThenLoadRoundTripsEverything;

    /// <summary>
    ///   Proves the access token is not in the saved file in clear, yet IS
    ///   stored ( protected ), so it is neither leaked nor lost.
    /// </summary>
    [Test]
    procedure TokenIsNotSavedInClear;

    /// <summary>
    ///   Proves a plain-text token from an older build is read as it stands
    ///   and re-written protected by the next save.
    /// </summary>
    [Test]
    procedure LegacyPlainTokenIsReadThenProtected;

    /// <summary>
    ///   Proves a stored token that cannot be decrypted loads as "no token"
    ///   but is written back unchanged by a save, so the only copy survives.
    /// </summary>
    [Test]
    procedure UndecryptableTokenSurvivesASave;

    /// <summary>
    ///   Proves unparseable text makes LoadConfig return False, set
    ///   LastLoadError, start empty, and keep a byte-identical copy named
    ///   <c>&lt;config&gt;.unreadable-&lt;timestamp&gt;</c>.
    /// </summary>
    [Test]
    procedure CorruptFileIsCopiedAsideAndReported;

    /// <summary>
    ///   Proves the corrupt content still exists after a later save: the save
    ///   is allowed because the copy holds it, and the copy is not touched.
    /// </summary>
    [Test]
    procedure CorruptContentSurvivesALaterSave;

    /// <summary>
    ///   Proves valid JSON that is not a configuration ( a bare number ) is
    ///   treated as unreadable, not as an empty configuration.
    /// </summary>
    [Test]
    procedure JsonThatIsNotAConfigurationIsUnreadable;

    /// <summary>
    ///   Proves that when the file can be neither read nor copied aside, every
    ///   later save is refused with LastSaveError set and the file is left
    ///   byte-for-byte as it was.
    /// </summary>
    [Test]
    procedure UnreadableAndUncopyableFileIsNeverOverwritten;

    /// <summary>
    ///   Proves a manager that never loaded refuses to save over a file that
    ///   exists, instead of replacing it with its own empty state.
    /// </summary>
    [Test]
    procedure SaveWithoutLoadDoesNotReplaceAnExistingFile;

    /// <summary>
    ///   Proves the old array-only format still loads its repositories.
    /// </summary>
    [Test]
    procedure LegacyArrayFormatLoads;

    /// <summary>
    ///   Proves a load drops entries that are not objects, have no path, or
    ///   repeat a path in another spelling, and normalises the rest.
    /// </summary>
    [Test]
    procedure LoadDropsBlankAndDuplicateEntries;

    /// <summary>
    ///   Proves a hand-edited file pattern holding a shell metacharacter is
    ///   dropped at load rather than trusted.
    /// </summary>
    [Test]
    procedure UnsafeFilePatternIsDroppedOnLoad;
  end;

  /// <summary>
  ///   The managed lists: repositories, tick state, groups, commit history and
  ///   templates.  The "repositories" are plain folders; no Git state matters
  ///   here.
  /// </summary>
  [TestFixture]
  TTestManagedLists = class
  private
    /// <summary>
    ///   The temporary folder of the running test.
    /// </summary>
    FSandbox: TGitSandbox;
    /// <summary>
    ///   The manager under test, on the sandbox's configuration file.
    /// </summary>
    FManager: TGitRepoManager;
  public
    /// <summary>
    ///   Creates the temporary folder and a loaded manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Frees the manager and removes the folder.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves a repository is added once, with its name taken from the last
    ///   path segment, and saved.
    /// </summary>
    [Test]
    procedure AddRepositoryAddsAndSaves;

    /// <summary>
    ///   Proves the same folder spelt in another case or with a trailing
    ///   backslash is refused as a duplicate, and so is a blank path.
    /// </summary>
    [Test]
    procedure AddRepositoryRefusesDuplicatesAndBlank;

    /// <summary>
    ///   Proves a repository is removed by path, whatever the case, leaving
    ///   its neighbours, and that the removal is saved.
    /// </summary>
    [Test]
    procedure RemoveRepositoryRemovesByPath;

    /// <summary>
    ///   Proves the tick state is set on the named repository only, and that
    ///   an unknown path changes nothing.
    /// </summary>
    [Test]
    procedure SetRepoSelectedTicksOneRepository;

    /// <summary>
    ///   Proves groups are trimmed, and listed distinct, non-empty and sorted.
    /// </summary>
    [Test]
    procedure GroupsAreDistinctSortedAndTrimmed;

    /// <summary>
    ///   Proves the snapshot functions answer by index and by path and refuse
    ///   what is not there.
    /// </summary>
    [Test]
    procedure SnapshotsFindByIndexAndPath;

    /// <summary>
    ///   Proves the history is newest first and ignores blank messages.
    /// </summary>
    [Test]
    procedure HistoryIsNewestFirst;

    /// <summary>
    ///   Proves a repeated message moves to the head instead of appearing
    ///   twice, compared without regard to case or surrounding blanks.
    /// </summary>
    [Test]
    procedure HistoryPromotesARepeatedMessage;

    /// <summary>
    ///   Proves the history keeps the 20 newest messages and drops the oldest.
    /// </summary>
    [Test]
    procedure HistoryKeepsTwentyMessages;

    /// <summary>
    ///   Proves the history handed out is a private copy: changing it does not
    ///   change the manager's.
    /// </summary>
    [Test]
    procedure HistoryIsHandedOutAsACopy;

    /// <summary>
    ///   Proves writing CommitTemplates stores a copy and reading it returns a
    ///   copy: neither the caller's array nor the returned one is the live
    ///   list.
    /// </summary>
    [Test]
    procedure TemplatesAreCopiedInAndOut;

    /// <summary>
    ///   Proves templates are appended trimmed, replaced and removed by index,
    ///   and that a blank template or an index out of range changes nothing.
    /// </summary>
    [Test]
    procedure TemplatesAddUpdateRemove;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON;

const
  /// <summary>
  ///   A stand-in access token.  Not a real credential, and not shaped like
  ///   one a provider issues.
  /// </summary>
  FAKE_TOKEN = 'NotARealToken-0123456789-abcdef';

/// <summary>
///   Reads a saved configuration file as its JSON object.
/// </summary>
/// <param name="sFile">The configuration file.</param>
/// <returns>The root object; the caller frees it.</returns>
function LoadJson( const sFile: string ): TJSONObject;
begin

  var oValue := TJSONObject.ParseJSONValue( TFile.ReadAllText( sFile, TEncoding.UTF8 ) );

  if ( not ( oValue is TJSONObject ) ) then
  begin
    oValue.Free;
    raise EGitSandbox.CreateFmt( '"%s" does not hold a JSON object', [ sFile ] );
  end;

  Result := TJSONObject( oValue );

end;

/// <summary>
///   Escapes a Windows path for use inside a JSON string literal.
/// </summary>
/// <param name="sPath">The path.</param>
/// <returns>The path with each backslash doubled.</returns>
function JsonPath( const sPath: string ): string;
begin

  Result := sPath.Replace( '\', '\\' );

end;

{ TTestConfigSafety }

procedure TTestConfigSafety.Setup;
begin

  FSandbox := TGitSandbox.Create;
  FSandbox.MakeFolder( 'config' );

end;

procedure TTestConfigSafety.TearDown;
begin

  // A manager registers its token for redaction process-wide; loading an
  // empty configuration through a throwaway manager clears that.
  if Assigned( FSandbox ) then
  begin
    var oCleaner := TGitRepoManager.Create( FSandbox.PathOf( 'no-such-config.json' ) );

    try
      oCleaner.GitHubToken := '';
    finally
      oCleaner.Free;
    end;
  end;

  FreeAndNil( FSandbox );

end;

procedure TTestConfigSafety.WriteConfig( const sText: string );
begin

  FSandbox.WriteText( FSandbox.PathOf( 'config' ), 'repositories.json', sText );

end;

function TTestConfigSafety.UnreadableCopies: TArray<string>;
begin

  Result := TDirectory.GetFiles( FSandbox.PathOf( 'config' ), 'repositories.json.unreadable-*' );

end;

procedure TTestConfigSafety.MissingFileIsACleanFirstRun;
begin

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.AreEqual( FSandbox.ConfigFile, oManager.ConfigPath, False, 'the manager uses the file it was given' );
    Assert.IsTrue( oManager.LoadConfig, 'a missing file is not an error' );
    Assert.AreEqual( '', oManager.LastLoadError, False );
    Assert.AreEqual( 0, oManager.ReposCount );
    Assert.IsFalse( TFile.Exists( FSandbox.ConfigFile ), 'loading creates nothing' );

    Assert.IsTrue( oManager.SaveConfig, oManager.LastSaveError );
    Assert.AreEqual( '', oManager.LastSaveError, False );
    Assert.IsTrue( TFile.Exists( FSandbox.ConfigFile ), 'the first save creates the file' );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.EmptyFileLoadsAsEmpty;
begin

  WriteConfig( '   ' + #13#10 );

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oManager.LoadConfig );
    Assert.AreEqual( '', oManager.LastLoadError, False );
    Assert.AreEqual( 0, Integer( Length( UnreadableCopies ) ), 'an empty file is not set aside' );
    Assert.IsTrue( oManager.SaveConfig, 'and may be saved over' );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.SaveThenLoadRoundTripsEverything;
begin

  var sAlpha := FSandbox.MakeFolder( 'Alpha' );
  var sBeta  := FSandbox.MakeFolder( 'Beta' );
  var sGamma := FSandbox.MakeFolder( 'Gamma' );

  var oWriter := FSandbox.NewManager;

  try
    Assert.IsTrue( oWriter.AddRepository( sAlpha ) );
    Assert.IsTrue( oWriter.AddRepository( sBeta ) );
    Assert.IsTrue( oWriter.AddRepository( sGamma ) );
    oWriter.SetRepoGroup( sAlpha, 'Libraries' );
    oWriter.SetRepoGroup( sGamma, 'Apps' );
    oWriter.AddToCommitHistory( 'older message' );
    oWriter.AddToCommitHistory( 'newer message with "quotes" and \ backslash' );
    oWriter.CommitTemplates   := [ 'Template one', 'Second: {what}' ];
    oWriter.GitHubUsername    := 'some-user';
    oWriter.GitHubToken       := FAKE_TOKEN;
    oWriter.GitClientPath     := 'C:\Tools\Fork\Fork.exe';
    oWriter.FilePattern       := '*.pas,*.dfm';
    oWriter.DelphiIndexerPath := 'D:\Tools\delphi-indexer.exe';
    oWriter.StyleName         := 'Aqua Light Slate';

    Assert.IsTrue( oWriter.SaveConfig, oWriter.LastSaveError );
    Assert.AreEqual( '', oWriter.LastSaveError, False );
  finally
    oWriter.Free;
  end;

  var oReader := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oReader.LoadConfig, oReader.LastLoadError );
    Assert.AreEqual( '', oReader.LastLoadError, False );

    var rRepos := oReader.SnapshotAll;

    Assert.AreEqual( 3, Integer( Length( rRepos ) ) );
    Assert.AreEqual( sAlpha, rRepos[ 0 ].Path, False );
    Assert.AreEqual( 'Alpha', rRepos[ 0 ].Name, False );
    Assert.AreEqual( 'Libraries', rRepos[ 0 ].Group, False );
    Assert.AreEqual( sBeta, rRepos[ 1 ].Path, False );
    Assert.AreEqual( '', rRepos[ 1 ].Group, False );
    Assert.AreEqual( sGamma, rRepos[ 2 ].Path, False );
    Assert.AreEqual( 'Apps', rRepos[ 2 ].Group, False );
    Assert.AreEqual<TRepoStatus>( rsUnknown, rRepos[ 0 ].Status, 'status is not persisted' );

    var saHistory := oReader.CommitHistory;

    Assert.AreEqual( 2, Integer( Length( saHistory ) ) );
    Assert.AreEqual( 'newer message with "quotes" and \ backslash', saHistory[ 0 ], False );
    Assert.AreEqual( 'older message', saHistory[ 1 ], False );

    var saTemplates := oReader.CommitTemplates;

    Assert.AreEqual( 2, Integer( Length( saTemplates ) ) );
    Assert.AreEqual( 'Template one', saTemplates[ 0 ], False );
    Assert.AreEqual( 'Second: {what}', saTemplates[ 1 ], False );

    Assert.AreEqual( 'some-user', oReader.GitHubUsername, False );
    Assert.AreEqual( FAKE_TOKEN, oReader.GitHubToken, False );
    Assert.AreEqual( 'C:\Tools\Fork\Fork.exe', oReader.GitClientPath, False );
    Assert.AreEqual( '*.pas,*.dfm', oReader.FilePattern, False );
    Assert.AreEqual( 'D:\Tools\delphi-indexer.exe', oReader.DelphiIndexerPath, False );
    Assert.AreEqual( 'Aqua Light Slate', oReader.StyleName, False );
    Assert.IsTrue( oReader.HasGitHubCredentials );
  finally
    oReader.Free;
  end;

end;

procedure TTestConfigSafety.TokenIsNotSavedInClear;
begin

  var oManager := FSandbox.NewManager;

  try
    oManager.GitHubUsername := 'some-user';
    oManager.GitHubToken    := FAKE_TOKEN;

    Assert.IsTrue( oManager.SaveConfig, oManager.LastSaveError );
    Assert.AreEqual( '', oManager.LastSaveError, False, 'the token was protected' );
  finally
    oManager.Free;
  end;

  var sRaw := TFile.ReadAllText( FSandbox.ConfigFile, TEncoding.UTF8 );

  Assert.IsFalse( sRaw.Contains( FAKE_TOKEN ), 'the token is in the file in clear' );
  Assert.IsTrue( sRaw.Contains( 'some-user' ), 'arrangement: the file is the one just saved' );

  var oJson := LoadJson( FSandbox.ConfigFile );

  try
    var sStored := oJson.GetValue<string>( 'github_token', '' );

    Assert.IsTrue( sStored.Length > Length( FAKE_TOKEN ), 'a protected value is stored, not an empty one' );
    Assert.AreNotEqual( FAKE_TOKEN, sStored, False );
  finally
    oJson.Free;
  end;

end;

procedure TTestConfigSafety.LegacyPlainTokenIsReadThenProtected;
begin

  WriteConfig( Format( '{ "github_username": "u", "github_token": "%s", "repositories": [] }', [ FAKE_TOKEN ] ) );

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oManager.LoadConfig, oManager.LastLoadError );
    Assert.AreEqual( FAKE_TOKEN, oManager.GitHubToken, False, 'read as it stands' );
    Assert.IsTrue( oManager.SaveConfig, oManager.LastSaveError );
  finally
    oManager.Free;
  end;

  Assert.IsFalse( TFile.ReadAllText( FSandbox.ConfigFile, TEncoding.UTF8 ).Contains( FAKE_TOKEN ), 're-written protected' );

  var oReader := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oReader.LoadConfig );
    Assert.AreEqual( FAKE_TOKEN, oReader.GitHubToken, False, 'and still readable' );
  finally
    oReader.Free;
  end;

end;

procedure TTestConfigSafety.UndecryptableTokenSurvivesASave;
const
  // The marker of a protected value, followed by Base64 that is not a DPAPI blob.
  STORED = 'dpapi:AAECAwQFBgcICQoLDA0ODw==';
begin

  WriteConfig( Format( '{ "github_username": "u", "github_token": "%s", "repositories": [] }', [ STORED ] ) );

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oManager.LoadConfig, oManager.LastLoadError );
    Assert.AreEqual( '', oManager.GitHubToken, False, 'it cannot be decrypted, so there is no token in memory' );

    oManager.StyleName := 'Changed';

    Assert.IsTrue( oManager.SaveConfig, oManager.LastSaveError );
  finally
    oManager.Free;
  end;

  var oJson := LoadJson( FSandbox.ConfigFile );

  try
    Assert.AreEqual( 'Changed', oJson.GetValue<string>( 'vcl_style', '' ), False, 'arrangement: the save happened' );
    Assert.AreEqual( STORED, oJson.GetValue<string>( 'github_token', '' ), False, 'the stored value was kept' );
  finally
    oJson.Free;
  end;

end;

procedure TTestConfigSafety.CorruptFileIsCopiedAsideAndReported;
const
  CORRUPT = '{ "repositories": [ { "path": "D:\\Precious" }, this is where the disk filled up';
begin

  WriteConfig( CORRUPT );

  var naOriginal := TFile.ReadAllBytes( FSandbox.ConfigFile );
  var oManager   := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsFalse( oManager.LoadConfig, 'unparseable text is not a successful load' );
    Assert.AreNotEqual( '', oManager.LastLoadError, False, 'LastLoadError says what happened' );
    Assert.AreEqual( 0, oManager.ReposCount, 'an empty configuration is started' );

    var saCopies := UnreadableCopies;

    Assert.AreEqual( 1, Integer( Length( saCopies ) ), 'one copy is set aside' );
    Assert.IsTrue( oManager.LastLoadError.Contains( saCopies[ 0 ] ), 'the message names the copy' );
    Assert.IsTrue( SameBytes( naOriginal, TFile.ReadAllBytes( saCopies[ 0 ] ) ), 'the copy is byte-identical' );
    Assert.IsTrue( SameBytes( naOriginal, TFile.ReadAllBytes( FSandbox.ConfigFile ) ), 'loading does not change the original' );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.CorruptContentSurvivesALaterSave;
const
  CORRUPT = '[ { "path": "D:\\Precious" }, ';
begin

  WriteConfig( CORRUPT );

  var naOriginal := TFile.ReadAllBytes( FSandbox.ConfigFile );
  var oManager   := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsFalse( oManager.LoadConfig );

    oManager.StyleName := 'After the failed load';

    // Documented: once the copy exists the session may save.
    Assert.IsTrue( oManager.SaveConfig, oManager.LastSaveError );
  finally
    oManager.Free;
  end;

  var saCopies := UnreadableCopies;

  Assert.AreEqual( 1, Integer( Length( saCopies ) ) );
  Assert.IsTrue( SameBytes( naOriginal, TFile.ReadAllBytes( saCopies[ 0 ] ) ), 'the unreadable content is still on disk, untouched by the save' );

  var oJson := LoadJson( FSandbox.ConfigFile );

  try
    Assert.AreEqual( 'After the failed load', oJson.GetValue<string>( 'vcl_style', '' ), False, 'and the new file is a valid configuration' );
  finally
    oJson.Free;
  end;

end;

procedure TTestConfigSafety.JsonThatIsNotAConfigurationIsUnreadable;
begin

  WriteConfig( '42' );

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsFalse( oManager.LoadConfig );
    Assert.AreNotEqual( '', oManager.LastLoadError, False );
    Assert.AreEqual( 1, Integer( Length( UnreadableCopies ) ) );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.UnreadableAndUncopyableFileIsNeverOverwritten;
const
  PRECIOUS = '{ "github_username": "keep-me", "repositories": [ { "path": "D:\\Precious", "group": "G" } ] }';
begin

  WriteConfig( PRECIOUS );

  var naOriginal := TFile.ReadAllBytes( FSandbox.ConfigFile );
  var oManager   := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    // Held with no sharing, the file can be neither read nor copied: the case
    // of another program holding it at start-up.
    var oHolder := TFileStream.Create( FSandbox.ConfigFile, fmOpenRead or fmShareExclusive );

    try
      Assert.IsFalse( oManager.LoadConfig, 'a file that cannot be read is not a successful load' );
    finally
      oHolder.Free;
    end;

    Assert.AreNotEqual( '', oManager.LastLoadError, False );
    Assert.AreEqual( 0, Integer( Length( UnreadableCopies ) ), 'arrangement: no copy could be made' );

    // The holder has gone, so nothing but the manager's own refusal protects the file now.
    oManager.StyleName := 'Must not be written';

    Assert.IsFalse( oManager.SaveConfig, 'the save must be refused' );
    Assert.AreNotEqual( '', oManager.LastSaveError, False, 'and say so' );

    // Every route to a save is refused, not only the direct call.
    Assert.IsTrue( oManager.AddRepository( FSandbox.MakeFolder( 'Added' ) ) );
    oManager.AddToCommitHistory( 'a message' );

    Assert.IsTrue( SameBytes( naOriginal, TFile.ReadAllBytes( FSandbox.ConfigFile ) ), 'the file is exactly as it was' );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.SaveWithoutLoadDoesNotReplaceAnExistingFile;
const
  EXISTING = '{ "github_username": "keep-me", "repositories": [] }';
begin

  WriteConfig( EXISTING );

  var naOriginal := TFile.ReadAllBytes( FSandbox.ConfigFile );
  var oManager   := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsFalse( oManager.SaveConfig );
    Assert.AreNotEqual( '', oManager.LastSaveError, False );
    Assert.IsTrue( SameBytes( naOriginal, TFile.ReadAllBytes( FSandbox.ConfigFile ) ) );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.LegacyArrayFormatLoads;
begin

  WriteConfig( '[ { "path": "D:\\One", "group": "G1" }, { "path": "D:\\Two" } ]' );

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oManager.LoadConfig, oManager.LastLoadError );

    var rRepos := oManager.SnapshotAll;

    Assert.AreEqual( 2, Integer( Length( rRepos ) ) );
    Assert.AreEqual( 'D:\One', rRepos[ 0 ].Path, False );
    Assert.AreEqual( 'G1', rRepos[ 0 ].Group, False );
    Assert.AreEqual( 'D:\Two', rRepos[ 1 ].Path, False );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.LoadDropsBlankAndDuplicateEntries;
begin

  WriteConfig( '{ "repositories": [ { "path": "D:\\Repo\\" }, "not an object", { "group": "no path" }, { "path": "  " }, ' +
    '{ "path": "d:\\REPO" }, { "path": "D:\\Other" } ] }' );

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oManager.LoadConfig, oManager.LastLoadError );

    var rRepos := oManager.SnapshotAll;

    Assert.AreEqual( 2, Integer( Length( rRepos ) ) );
    Assert.AreEqual( 'D:\Repo', rRepos[ 0 ].Path, False, 'first spelling kept, trailing delimiter dropped' );
    Assert.AreEqual( 'Repo', rRepos[ 0 ].Name, False );
    Assert.AreEqual( 'D:\Other', rRepos[ 1 ].Path, False );
  finally
    oManager.Free;
  end;

end;

procedure TTestConfigSafety.UnsafeFilePatternIsDroppedOnLoad;
begin

  WriteConfig( '{ "file_pattern": "*.pas; del", "vcl_style": "Kept", "repositories": [] }' );

  var oManager := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oManager.LoadConfig, oManager.LastLoadError );
    Assert.AreEqual( 'Kept', oManager.StyleName, False, 'arrangement: the file was read' );
    Assert.AreEqual( '', oManager.FilePattern, False );
  finally
    oManager.Free;
  end;

end;

{ TTestManagedLists }

procedure TTestManagedLists.Setup;
begin

  FSandbox := TGitSandbox.Create;
  FManager := FSandbox.NewManager;

end;

procedure TTestManagedLists.TearDown;
begin

  FreeAndNil( FManager );
  FreeAndNil( FSandbox );

end;

procedure TTestManagedLists.AddRepositoryAddsAndSaves;
var
  rRepo: TRepoInfo;
begin

  var sFolder := FSandbox.MakeFolder( 'My Project' );

  Assert.IsTrue( FManager.AddRepository( sFolder + '\' ) );
  Assert.AreEqual( 1, FManager.ReposCount );
  Assert.IsTrue( FManager.GetRepoSnapshot( 0, rRepo ) );
  Assert.AreEqual( sFolder, rRepo.Path, False, 'stored without the trailing delimiter' );
  Assert.AreEqual( 'My Project', rRepo.Name, False );
  Assert.IsFalse( rRepo.Selected );
  Assert.AreEqual<TRepoStatus>( rsError, rRepo.Status, 'a folder that is no repository is refreshed to Error at once' );

  Assert.IsTrue( TFile.ReadAllText( FSandbox.ConfigFile, TEncoding.UTF8 ).Contains( JsonPath( sFolder ) ), 'adding saves' );

end;

procedure TTestManagedLists.AddRepositoryRefusesDuplicatesAndBlank;
begin

  var sFolder := FSandbox.MakeFolder( 'Repo' );

  Assert.IsTrue( FManager.AddRepository( sFolder ), 'first time' );
  Assert.IsFalse( FManager.AddRepository( sFolder ), 'identical' );
  Assert.IsFalse( FManager.AddRepository( sFolder.ToUpper ), 'upper case' );
  Assert.IsFalse( FManager.AddRepository( sFolder.ToLower + '\' ), 'lower case with a trailing backslash' );
  Assert.IsFalse( FManager.AddRepository( '  ' + sFolder + '  ' ), 'surrounding blanks' );
  Assert.IsFalse( FManager.AddRepository( '' ), 'empty' );
  Assert.IsFalse( FManager.AddRepository( '   ' ), 'blank' );
  Assert.AreEqual( 1, FManager.ReposCount );

end;

procedure TTestManagedLists.RemoveRepositoryRemovesByPath;
begin

  var sOne   := FSandbox.MakeFolder( 'One' );
  var sTwo   := FSandbox.MakeFolder( 'Two' );
  var sThree := FSandbox.MakeFolder( 'Three' );

  FManager.AddRepository( sOne );
  FManager.AddRepository( sTwo );
  FManager.AddRepository( sThree );

  FManager.RemoveRepository( sTwo.ToUpper + '\' );

  var rRepos := FManager.SnapshotAll;

  Assert.AreEqual( 2, Integer( Length( rRepos ) ) );
  Assert.AreEqual( sOne, rRepos[ 0 ].Path, False );
  Assert.AreEqual( sThree, rRepos[ 1 ].Path, False );

  FManager.RemoveRepository( FSandbox.PathOf( 'Never Added' ) );
  Assert.AreEqual( 2, FManager.ReposCount, 'an unknown path removes nothing' );

  var oReader := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oReader.LoadConfig );
    Assert.AreEqual( 2, oReader.ReposCount, 'the removal was saved' );
  finally
    oReader.Free;
  end;

end;

procedure TTestManagedLists.SetRepoSelectedTicksOneRepository;
var
  rOne: TRepoInfo;
  rTwo: TRepoInfo;
begin

  var sOne := FSandbox.MakeFolder( 'One' );
  var sTwo := FSandbox.MakeFolder( 'Two' );

  FManager.AddRepository( sOne );
  FManager.AddRepository( sTwo );

  FManager.SetRepoSelected( sTwo.ToLower, True );
  FManager.SetRepoSelected( FSandbox.PathOf( 'Never Added' ), True );

  Assert.IsTrue( FManager.GetRepoSnapshotByPath( sOne, rOne ) );
  Assert.IsTrue( FManager.GetRepoSnapshotByPath( sTwo, rTwo ) );
  Assert.IsFalse( rOne.Selected );
  Assert.IsTrue( rTwo.Selected );

  FManager.SetRepoSelected( sTwo, False );

  Assert.IsTrue( FManager.GetRepoSnapshotByPath( sTwo, rTwo ) );
  Assert.IsFalse( rTwo.Selected, 'and it can be cleared again' );

end;

procedure TTestManagedLists.GroupsAreDistinctSortedAndTrimmed;
var
  rRepo: TRepoInfo;
begin

  var saFolders: TArray<string> := [ FSandbox.MakeFolder( 'A' ), FSandbox.MakeFolder( 'B' ), FSandbox.MakeFolder( 'C' ),
    FSandbox.MakeFolder( 'D' ) ];

  for var sFolder in saFolders do
    FManager.AddRepository( sFolder );

  Assert.AreEqual( 0, Integer( Length( FManager.GetAllGroups ) ), 'no groups yet' );

  FManager.SetRepoGroup( saFolders[ 0 ], 'Zeta' );
  FManager.SetRepoGroup( saFolders[ 1 ], '  Alpha  ' );
  FManager.SetRepoGroup( saFolders[ 2 ], 'Alpha' );
  FManager.SetRepoGroup( FSandbox.PathOf( 'Never Added' ), 'Ghost' );

  var saGroups := FManager.GetAllGroups;

  Assert.AreEqual( 2, Integer( Length( saGroups ) ) );
  Assert.AreEqual( 'Alpha', saGroups[ 0 ], False );
  Assert.AreEqual( 'Zeta', saGroups[ 1 ], False );

  Assert.IsTrue( FManager.GetRepoSnapshotByPath( saFolders[ 1 ], rRepo ) );
  Assert.AreEqual( 'Alpha', rRepo.Group, False, 'stored trimmed' );

  FManager.SetRepoGroup( saFolders[ 0 ], '' );
  saGroups := FManager.GetAllGroups;

  Assert.AreEqual( 1, Integer( Length( saGroups ) ), 'clearing a group removes it from the list' );
  Assert.AreEqual( 'Alpha', saGroups[ 0 ], False );

end;

procedure TTestManagedLists.SnapshotsFindByIndexAndPath;
var
  rRepo: TRepoInfo;
begin

  var sOne := FSandbox.MakeFolder( 'One' );
  var sTwo := FSandbox.MakeFolder( 'Two' );

  FManager.AddRepository( sOne );
  FManager.AddRepository( sTwo );

  Assert.IsTrue( FManager.GetRepoSnapshot( 1, rRepo ) );
  Assert.AreEqual( sTwo, rRepo.Path, False );
  Assert.IsFalse( FManager.GetRepoSnapshot( 2, rRepo ), 'past the end' );
  Assert.IsFalse( FManager.GetRepoSnapshot( -1, rRepo ), 'negative' );

  Assert.IsTrue( FManager.GetRepoSnapshotByPath( sOne.ToUpper + '\', rRepo ) );
  Assert.AreEqual( sOne, rRepo.Path, False );
  Assert.IsFalse( FManager.GetRepoSnapshotByPath( FSandbox.PathOf( 'Never Added' ), rRepo ) );

end;

procedure TTestManagedLists.HistoryIsNewestFirst;
begin

  FManager.AddToCommitHistory( 'first' );
  FManager.AddToCommitHistory( '' );
  FManager.AddToCommitHistory( '   ' );
  FManager.AddToCommitHistory( '  second  ' );
  FManager.AddToCommitHistory( 'third' );

  var saHistory := FManager.CommitHistory;

  Assert.AreEqual( 3, Integer( Length( saHistory ) ) );
  Assert.AreEqual( 'third', saHistory[ 0 ], False );
  Assert.AreEqual( 'second', saHistory[ 1 ], False, 'stored trimmed' );
  Assert.AreEqual( 'first', saHistory[ 2 ], False );

end;

procedure TTestManagedLists.HistoryPromotesARepeatedMessage;
begin

  FManager.AddToCommitHistory( 'alpha' );
  FManager.AddToCommitHistory( 'beta' );
  FManager.AddToCommitHistory( 'gamma' );
  FManager.AddToCommitHistory( '  ALPHA ' );

  var saHistory := FManager.CommitHistory;

  Assert.AreEqual( 3, Integer( Length( saHistory ) ), 'no duplicate entry' );
  Assert.IsTrue( SameText( 'alpha', saHistory[ 0 ] ), 'the repeated message is at the head: ' + saHistory[ 0 ] );
  Assert.AreEqual( 'gamma', saHistory[ 1 ], False );
  Assert.AreEqual( 'beta', saHistory[ 2 ], False );

  FManager.AddToCommitHistory( 'alpha' );

  Assert.AreEqual( 3, Integer( Length( FManager.CommitHistory ) ), 'repeating the head changes nothing' );

end;

procedure TTestManagedLists.HistoryKeepsTwentyMessages;
begin

  for var iI := 1 to 25 do
    FManager.AddToCommitHistory( Format( 'message %d', [ iI ] ) );

  var saHistory := FManager.CommitHistory;

  Assert.AreEqual( 20, Integer( Length( saHistory ) ) );
  Assert.AreEqual( 'message 25', saHistory[ 0 ], False );
  Assert.AreEqual( 'message 6', saHistory[ 19 ], False, 'the five oldest were dropped' );

end;

procedure TTestManagedLists.HistoryIsHandedOutAsACopy;
begin

  FManager.AddToCommitHistory( 'kept' );

  var saHistory := FManager.CommitHistory;

  saHistory[ 0 ] := 'scribbled on';

  Assert.AreEqual( 'kept', FManager.CommitHistory[ 0 ], False );

end;

procedure TTestManagedLists.TemplatesAreCopiedInAndOut;
begin

  var saMine: TArray<string> := [ 'one', 'two' ];

  FManager.CommitTemplates := saMine;

  saMine[ 0 ] := 'changed by the caller';

  Assert.AreEqual( 'one', FManager.CommitTemplates[ 0 ], False, 'the caller''s array did not become the live one' );

  var saRead := FManager.CommitTemplates;

  saRead[ 1 ] := 'changed through the result';

  Assert.AreEqual( 'two', FManager.CommitTemplates[ 1 ], False, 'the result is not the live one either' );
  Assert.AreEqual( 2, Integer( Length( FManager.CommitTemplates ) ) );

end;

procedure TTestManagedLists.TemplatesAddUpdateRemove;
begin

  FManager.AddTemplate( '  first  ' );
  FManager.AddTemplate( '   ' );
  FManager.AddTemplate( 'second' );
  FManager.AddTemplate( 'third' );

  var saTemplates := FManager.CommitTemplates;

  Assert.AreEqual( 3, Integer( Length( saTemplates ) ), 'the blank one was ignored' );
  Assert.AreEqual( 'first', saTemplates[ 0 ], False, 'stored trimmed' );

  FManager.UpdateTemplate( 1, ' second, revised ' );
  FManager.UpdateTemplate( 3, 'out of range' );
  FManager.UpdateTemplate( -1, 'out of range' );
  FManager.RemoveTemplate( 0 );
  FManager.RemoveTemplate( 7 );
  FManager.RemoveTemplate( -1 );

  saTemplates := FManager.CommitTemplates;

  Assert.AreEqual( 2, Integer( Length( saTemplates ) ) );
  Assert.AreEqual( 'second, revised', saTemplates[ 0 ], False );
  Assert.AreEqual( 'third', saTemplates[ 1 ], False );

  var oReader := TGitRepoManager.Create( FSandbox.ConfigFile );

  try
    Assert.IsTrue( oReader.LoadConfig );
    Assert.AreEqual( 2, Integer( Length( oReader.CommitTemplates ) ), 'template changes are saved' );
  finally
    oReader.Free;
  end;

end;

initialization

  TDUnitX.RegisterTestFixture( TTestConfigSafety );
  TDUnitX.RegisterTestFixture( TTestManagedLists );

end.
