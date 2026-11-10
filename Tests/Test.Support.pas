(* GITLAK Software
  ***************************************************************************

    © 2026 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit test suite.

  Test.Support.pas - the sandbox every test works in: one unique temporary
  folder holding the configuration file and every Git repository the test
  needs, removed when the test ends.

  ***************************************************************************
*)

unit Test.Support;

interface

uses
  System.SysUtils,
  uGitRepoManager;

const
  /// <summary>
  ///   Longest a Git command run for a test's ARRANGEMENT may take, in
  ///   milliseconds.  Everything is local, so this is only a bound on a hang.
  /// </summary>
  SANDBOX_GIT_TIMEOUT = 60000;

  /// <summary>
  ///   Content of the one file every repository made by
  ///   <see cref="TGitSandbox.InitRepo"/> starts with.
  /// </summary>
  SEED_FILE_TEXT = 'seed' + #10;

  /// <summary>
  ///   Name of the file every repository made by
  ///   <see cref="TGitSandbox.InitRepo"/> starts with.
  /// </summary>
  SEED_FILE_NAME = 'README.txt';

type
  /// <summary>
  ///   Raised when a Git command a test needs for its arrangement fails, so
  ///   that a broken arrangement is an ERROR and never a misleading failure
  ///   or pass of the assertion that follows.
  /// </summary>
  EGitSandbox = class( Exception );

  /// <summary>
  ///   A unique folder under the system temporary folder, with helpers that
  ///   build Git repositories inside it.  Freed, it deletes the folder and
  ///   everything in it.
  /// </summary>
  /// <remarks>
  ///   Nothing here reaches outside the folder: no repository of the user's,
  ///   no remote on the network ( every "origin" is a bare repository in the
  ///   same folder ) and, through <c>GIT_CONFIG_GLOBAL</c> set at unit
  ///   initialisation, not the user's Git configuration either.
  /// </remarks>
  TGitSandbox = class
  private
    /// <summary>
    ///   Absolute path of the sandbox folder.
    /// </summary>
    FRoot: string;
  public
    /// <summary>
    ///   Creates the sandbox folder.
    /// </summary>
    constructor Create;

    /// <summary>
    ///   Deletes the sandbox folder and its content, read-only Git objects
    ///   included.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Returns the absolute path of something inside the sandbox.
    /// </summary>
    /// <param name="sRelative">Path relative to the sandbox folder.</param>
    /// <returns>The combined path.</returns>
    function PathOf( const sRelative: string ): string;

    /// <summary>
    ///   Creates a folder ( and its parents ) inside the sandbox.
    /// </summary>
    /// <param name="sRelative">Path relative to the sandbox folder.</param>
    /// <returns>The folder's absolute path.</returns>
    function MakeFolder( const sRelative: string ): string;

    /// <summary>
    ///   Writes a file as UTF-8 without a BOM, exactly as given, creating its
    ///   parent folders.
    /// </summary>
    /// <param name="sFolder">Absolute folder the name is relative to.</param>
    /// <param name="sName">File name, optionally with sub-folders.</param>
    /// <param name="sText">The exact content.</param>
    procedure WriteText( const sFolder, sName, sText: string );

    /// <summary>
    ///   Reads a file as UTF-8, a BOM removed, line breaks kept.
    /// </summary>
    /// <param name="sFolder">Absolute folder the name is relative to.</param>
    /// <param name="sName">File name, optionally with sub-folders.</param>
    /// <returns>The file's text.</returns>
    function ReadText( const sFolder, sName: string ): string;

    /// <summary>
    ///   Runs Git in a folder and reports whether it succeeded.  For the
    ///   arrangement steps that are EXPECTED to fail, such as a merge that
    ///   must stop on a conflict.
    /// </summary>
    /// <remarks>
    ///   Deliberately NOT run through the unit under test: the arrangement
    ///   and the checks made with it must not depend on the process runner
    ///   they sit beside, nor on the environment it gives its children.
    /// </remarks>
    /// <param name="sFolder">Working directory for the command.</param>
    /// <param name="sArguments">Everything after <c>git</c>.</param>
    /// <param name="sOutput">
    ///   Receives the command's standard output, trimmed; when it failed, its
    ///   standard error as well.
    /// </param>
    /// <returns>True when Git exited with code 0.</returns>
    /// <exception cref="EGitSandbox">Git could not be started, or did not end in time.</exception>
    function TryGit( const sFolder, sArguments: string; out sOutput: string ): Boolean;

    /// <summary>
    ///   Runs Git in a folder and returns its output.
    /// </summary>
    /// <param name="sFolder">Working directory for the command.</param>
    /// <param name="sArguments">Everything after <c>git</c>.</param>
    /// <returns>The command's standard output, trimmed.</returns>
    /// <exception cref="EGitSandbox">Git could not be run or exited non-zero.</exception>
    function Git( const sFolder, sArguments: string ): string;

    /// <summary>
    ///   Sets <c>user.name</c>, <c>user.email</c> and <c>commit.gpgsign</c>
    ///   in a repository's own configuration, so commits work whatever the
    ///   machine's configuration says.
    /// </summary>
    /// <param name="sRepo">The repository.</param>
    /// <exception cref="EGitSandbox">Git refused a setting.</exception>
    procedure SetIdentity( const sRepo: string );

    /// <summary>
    ///   Creates a repository on branch <c>main</c> holding one commit of
    ///   <c>README.txt</c>.
    /// </summary>
    /// <param name="sName">Folder name inside the sandbox.</param>
    /// <returns>The repository's absolute path.</returns>
    /// <exception cref="EGitSandbox">A Git step failed.</exception>
    function InitRepo( const sName: string ): string;

    /// <summary>
    ///   Creates an EMPTY bare repository whose HEAD names <c>main</c>.
    /// </summary>
    /// <param name="sName">Folder name inside the sandbox.</param>
    /// <returns>The bare repository's absolute path.</returns>
    /// <exception cref="EGitSandbox">A Git step failed.</exception>
    function InitBare( const sName: string ): string;

    /// <summary>
    ///   Creates a bare repository that already holds one commit on
    ///   <c>main</c>, ready to be cloned as an "origin".
    /// </summary>
    /// <param name="sName">Folder name inside the sandbox.</param>
    /// <returns>The bare repository's absolute path.</returns>
    /// <exception cref="EGitSandbox">A Git step failed.</exception>
    function InitSeededBare( const sName: string ): string;

    /// <summary>
    ///   Clones a bare repository of this sandbox, so the clone's <c>main</c>
    ///   tracks <c>origin/main</c>.
    /// </summary>
    /// <param name="sBare">Absolute path of the bare repository.</param>
    /// <param name="sName">Folder name of the clone inside the sandbox.</param>
    /// <returns>The clone's absolute path.</returns>
    /// <exception cref="EGitSandbox">A Git step failed.</exception>
    function CloneRepo( const sBare, sName: string ): string;

    /// <summary>
    ///   Writes one file and commits exactly that file.
    /// </summary>
    /// <param name="sRepo">The repository.</param>
    /// <param name="sName">File name, optionally with sub-folders.</param>
    /// <param name="sText">The file's exact content.</param>
    /// <param name="sMessage">Commit message; must not contain a double quote.</param>
    /// <exception cref="EGitSandbox">A Git step failed.</exception>
    procedure CommitFile( const sRepo, sName, sText, sMessage: string );

    /// <summary>
    ///   Resolves a revision to its full commit hash.
    /// </summary>
    /// <param name="sRepo">The repository, bare or not.</param>
    /// <param name="sRevision">The revision, e.g. <c>HEAD</c> or <c>main</c>.</param>
    /// <returns>The 40-character hash.</returns>
    /// <exception cref="EGitSandbox">The revision does not exist.</exception>
    function RevParse( const sRepo, sRevision: string ): string;

    /// <summary>
    ///   Path of the configuration file a test's manager uses: inside the
    ///   sandbox, never the user's own.
    /// </summary>
    /// <returns>The absolute path; the file is not created.</returns>
    function ConfigFile: string;

    /// <summary>
    ///   Creates a manager on this sandbox's configuration file and loads it,
    ///   as the application does at start-up.
    /// </summary>
    /// <remarks>
    ///   The load matters: a manager that never loaded refuses to save over a
    ///   file that exists, which is every save after the first.
    /// </remarks>
    /// <returns>The manager; the caller frees it.</returns>
    /// <exception cref="EGitSandbox">The arrangement failed, so the test cannot mean anything.</exception>
    function NewManager: TGitRepoManager;

    /// <summary>
    ///   Absolute path of the sandbox folder.
    /// </summary>
    property Root: string read FRoot;
  end;

/// <summary>
///   Compares two byte arrays by content.
/// </summary>
/// <param name="naLeft">One array.</param>
/// <param name="naRight">The other.</param>
/// <returns>True when both have the same length and the same bytes.</returns>
function SameBytes( const naLeft, naRight: TBytes ): Boolean;

implementation

uses
  Winapi.Windows,
  System.Classes, System.IOUtils;

var
  /// <summary>
  ///   Folder holding the Git "global" configuration file this process uses
  ///   instead of the user's.
  /// </summary>
  GGlobalConfigFolder: string;

/// <summary>
///   Points every Git child process of this run at a private, near-empty
///   global configuration and away from the system one.
/// </summary>
/// <remarks>
///   The unit under test builds each child's environment from this process's,
///   so setting the variables here covers the product's Git calls as well as
///   the sandbox's.  Without it a user-level <c>core.excludesFile</c>,
///   <c>core.hooksPath</c>, <c>core.autocrlf</c> or <c>pull.rebase</c> would
///   change what the tests see.
/// </remarks>
procedure IsolateGitConfiguration;
begin

  GGlobalConfigFolder := TPath.Combine( TPath.GetTempPath, Format( 'GBCTests-gitconfig-%d', [ GetCurrentProcessId ] ) );
  TDirectory.CreateDirectory( GGlobalConfigFolder );

  var sFile := TPath.Combine( GGlobalConfigFolder, 'gitconfig' );
  var sText := '[init]' + #10 + #9 + 'defaultBranch = main' + #10 +
    '[core]' + #10 + #9 + 'autocrlf = false' + #10 +
    '[gc]' + #10 + #9 + 'auto = 0' + #10 +
    '[commit]' + #10 + #9 + 'gpgsign = false' + #10;

  TFile.WriteAllBytes( sFile, TEncoding.UTF8.GetBytes( sText ) );

  SetEnvironmentVariable( 'GIT_CONFIG_GLOBAL', PChar( sFile ) );
  SetEnvironmentVariable( 'GIT_CONFIG_NOSYSTEM', '1' );

  // Inherited from a shell that launched the suite, these would aim every
  // sandbox command at one repository.
  SetEnvironmentVariable( 'GIT_DIR', nil );
  SetEnvironmentVariable( 'GIT_WORK_TREE', nil );
  SetEnvironmentVariable( 'GIT_INDEX_FILE', nil );

  // A sandbox folder that is not a repository must not be taken for part of
  // one further up the tree.
  SetEnvironmentVariable( 'GIT_CEILING_DIRECTORIES', PChar( ExcludeTrailingPathDelimiter( TPath.GetTempPath ) ) );

end;

function SameBytes( const naLeft, naRight: TBytes ): Boolean;
begin

  Result := ( Length( naLeft ) = Length( naRight ) ) and
    ( ( Length( naLeft ) = 0 ) or CompareMem( @naLeft[ 0 ], @naRight[ 0 ], Length( naLeft ) ) );

end;

{ TGitSandbox }

constructor TGitSandbox.Create;
begin

  inherited Create;
  FRoot := TPath.Combine( TPath.GetTempPath, 'GBCTests-' + TGUID.NewGuid.ToString.Replace( '{', '' ).Replace( '}', '' ) );
  TDirectory.CreateDirectory( FRoot );

end;

destructor TGitSandbox.Destroy;
begin

  if TDirectory.Exists( FRoot ) then
  begin
    // Git writes its objects read-only, and a read-only file cannot be deleted.
    for var sFile in TDirectory.GetFiles( FRoot, '*', TSearchOption.soAllDirectories ) do
      SetFileAttributes( PChar( sFile ), FILE_ATTRIBUTE_NORMAL );

    TDirectory.Delete( FRoot, True );
  end;

  inherited;

end;

function TGitSandbox.PathOf( const sRelative: string ): string;
begin

  Result := TPath.Combine( FRoot, sRelative );

end;

function TGitSandbox.MakeFolder( const sRelative: string ): string;
begin

  Result := PathOf( sRelative );
  TDirectory.CreateDirectory( Result );

end;

procedure TGitSandbox.WriteText( const sFolder, sName, sText: string );
begin

  var sFile := TPath.Combine( sFolder, sName );

  TDirectory.CreateDirectory( TPath.GetDirectoryName( sFile ) );
  TFile.WriteAllBytes( sFile, TEncoding.UTF8.GetBytes( sText ) );

end;

function TGitSandbox.ReadText( const sFolder, sName: string ): string;
begin

  Result := TFile.ReadAllText( TPath.Combine( sFolder, sName ), TEncoding.UTF8 );

end;

function TGitSandbox.TryGit( const sFolder, sArguments: string; out sOutput: string ): Boolean;
var
  rSecurity: TSecurityAttributes;
  rStartup: TStartupInfo;
  rProcess: TProcessInformation;
  hRead: THandle;
  hWrite: THandle;
  hError: THandle;
  hInput: THandle;
  naChunk: array[ 0..4095 ] of Byte;
  iRead: DWORD;
  iExitCode: DWORD;
begin

  sOutput := '';

  rSecurity.nLength             := SizeOf( rSecurity );
  rSecurity.bInheritHandle       := True;
  rSecurity.lpSecurityDescriptor := nil;

  // Standard output through a pipe, read to its end; standard error into a
  // file, so that two pipes never have to be drained at once.
  var sErrorFile := PathOf( 'sandbox-git-stderr.txt' );
  var sCommand   := 'git ' + sArguments;
  var oCaptured  := TBytesStream.Create;

  hRead  := 0;
  hWrite := 0;
  hError := INVALID_HANDLE_VALUE;
  hInput := INVALID_HANDLE_VALUE;

  try
    if ( not CreatePipe( hRead, hWrite, @rSecurity, 0 ) ) then
      RaiseLastOSError;

    SetHandleInformation( hRead, HANDLE_FLAG_INHERIT, 0 );

    hError := CreateFile( PChar( sErrorFile ), GENERIC_WRITE, FILE_SHARE_READ, @rSecurity, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0 );
    hInput := CreateFile( 'NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, @rSecurity, OPEN_EXISTING, 0, 0 );

    if ( hError = INVALID_HANDLE_VALUE ) or ( hInput = INVALID_HANDLE_VALUE ) then
      RaiseLastOSError;

    ZeroMemory( @rStartup, SizeOf( rStartup ) );
    rStartup.cb         := SizeOf( rStartup );
    rStartup.dwFlags    := STARTF_USESTDHANDLES;
    rStartup.hStdInput  := hInput;
    rStartup.hStdOutput := hWrite;
    rStartup.hStdError  := hError;

    // CreateProcess may write to the command line it is given.
    UniqueString( sCommand );

    if ( not CreateProcess( nil, PChar( sCommand ), nil, nil, True, CREATE_NO_WINDOW, nil, PChar( sFolder ), rStartup, rProcess ) ) then
      raise EGitSandbox.CreateFmt( 'Arrangement failed: could not start "%s" in "%s": %s',
        [ sCommand, sFolder, SysErrorMessage( Winapi.Windows.GetLastError ) ] );

    try
      // The read ends only when every copy of the write end is closed, so
      // this process's copy goes first.
      CloseHandle( hWrite );
      hWrite := 0;

      while ReadFile( hRead, naChunk, SizeOf( naChunk ), iRead, nil ) and ( iRead > 0 ) do
        oCaptured.WriteBuffer( naChunk, iRead );

      if WaitForSingleObject( rProcess.hProcess, SANDBOX_GIT_TIMEOUT ) <> WAIT_OBJECT_0 then
      begin
        TerminateProcess( rProcess.hProcess, 1 );
        raise EGitSandbox.CreateFmt( 'Arrangement failed: "%s" did not end within %d ms', [ sCommand, SANDBOX_GIT_TIMEOUT ] );
      end;

      Result := GetExitCodeProcess( rProcess.hProcess, iExitCode ) and ( iExitCode = 0 );
    finally
      CloseHandle( rProcess.hThread );
      CloseHandle( rProcess.hProcess );
    end;

    CloseHandle( hError );
    hError := INVALID_HANDLE_VALUE;

    sOutput := TEncoding.UTF8.GetString( oCaptured.Bytes, 0, oCaptured.Size ).Trim;

    if ( not Result ) then
      sOutput := ( sOutput + sLineBreak + TFile.ReadAllText( sErrorFile, TEncoding.UTF8 ) ).Trim;
  finally
    if hWrite <> 0 then
      CloseHandle( hWrite );

    if hRead <> 0 then
      CloseHandle( hRead );

    if hError <> INVALID_HANDLE_VALUE then
      CloseHandle( hError );

    if hInput <> INVALID_HANDLE_VALUE then
      CloseHandle( hInput );

    oCaptured.Free;
  end;

end;

function TGitSandbox.Git( const sFolder, sArguments: string ): string;
begin

  if ( not TryGit( sFolder, sArguments, Result ) ) then
    raise EGitSandbox.CreateFmt( 'Arrangement failed: git %s (in %s): %s', [ sArguments, sFolder, Result ] );

end;

procedure TGitSandbox.SetIdentity( const sRepo: string );
begin

  Git( sRepo, 'config user.name "GBC Tests"' );
  Git( sRepo, 'config user.email "gbc-tests@example.invalid"' );
  Git( sRepo, 'config commit.gpgsign false' );

end;

function TGitSandbox.InitRepo( const sName: string ): string;
begin

  Result := MakeFolder( sName );
  Git( Result, 'init -b main' );
  SetIdentity( Result );
  CommitFile( Result, SEED_FILE_NAME, SEED_FILE_TEXT, 'Seed' );

end;

function TGitSandbox.InitBare( const sName: string ): string;
begin

  Result := MakeFolder( sName );
  Git( Result, 'init --bare -b main' );

end;

function TGitSandbox.InitSeededBare( const sName: string ): string;
begin

  Result := InitBare( sName );

  var sSeed := InitRepo( sName + '-seed' );

  Git( sSeed, Format( 'remote add origin "%s"', [ Result ] ) );
  Git( sSeed, 'push -u origin main' );

end;

function TGitSandbox.CloneRepo( const sBare, sName: string ): string;
begin

  Result := PathOf( sName );
  Git( FRoot, Format( 'clone "%s" "%s"', [ sBare, Result ] ) );
  SetIdentity( Result );

end;

procedure TGitSandbox.CommitFile( const sRepo, sName, sText, sMessage: string );
begin

  WriteText( sRepo, sName, sText );
  Git( sRepo, Format( 'add -- "%s"', [ sName.Replace( '\', '/' ) ] ) );
  Git( sRepo, Format( 'commit -m "%s"', [ sMessage ] ) );

end;

function TGitSandbox.RevParse( const sRepo, sRevision: string ): string;
begin

  Result := Git( sRepo, Format( 'rev-parse --verify "%s^{commit}"', [ sRevision ] ) );

end;

function TGitSandbox.ConfigFile: string;
begin

  Result := TPath.Combine( PathOf( 'config' ), 'repositories.json' );

end;

function TGitSandbox.NewManager: TGitRepoManager;
begin

  TDirectory.CreateDirectory( PathOf( 'config' ) );
  Result := TGitRepoManager.Create( ConfigFile );

  try
    if ( not Result.LoadConfig ) then
      raise EGitSandbox.CreateFmt( 'Arrangement failed: LoadConfig: %s', [ Result.LastLoadError ] );
  except
    Result.Free;
    raise;
  end;

end;

initialization

  IsolateGitConfiguration;

finalization

  if TDirectory.Exists( GGlobalConfigFolder ) then
    TDirectory.Delete( GGlobalConfigFolder, True );

end.
