(* GITLAK Software
  ***************************************************************************

    © 2025 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use. only.

    THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED.
    IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DAMAGES ARISING IN
  CONNECTION WITH THE USE OF THIS SOFTWARE.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit Application/project.
  This project was developed jointly by the Author and Claude Code.

  ***************************************************************************

  Author(s) :
  Ian Branch - GITLAK Software.    Claude Code.

  ***************************************************************************
  File last update : 2026-01-04T05:22:04.290+11:00
  Signature : 17d59e5e022d5fcf42c95c0b62c4f8b407acd10d
  ***************************************************************************
*)

(*
  uGitRepoManager.pas - Git Repository Manager Class

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.5.0

  Part of GitBatchCommit Application

  Description:
    Provides the TGitRepoManager class for managing multiple Git repositories,
    including status detection, configuration persistence, batch commit/push
    operations, and Codeberg repository creation.
*)

unit uGitRepoManager;

interface

uses
  Winapi.Windows,

  System.SysUtils, System.StrUtils, System.Classes, System.IOUtils, System.JSON,
  System.Generics.Collections, System.Net.HttpClient, System.Net.HttpClientComponent,
  System.Net.URLClient, System.NetEncoding, System.Threading, System.SyncObjs, System.Math;

const
  /// <summary>
  ///   Canonical application version. Update here and only here; surface
  ///   everywhere else ( About dialog, User-Agent header, docs ) by referencing.
  /// </summary>
  APP_VERSION         = '1.6.0';

  /// <summary>
  ///   Default timeout for Git operations in milliseconds (60 seconds).
  /// </summary>
  GIT_COMMAND_TIMEOUT = 60000;

  /// <summary>
  ///   Codeberg API base URL.
  /// </summary>
  CODEBERG_API_URL  = 'https://codeberg.org/api/v1';

  /// <summary>
  ///   GitHub API base URL.
  /// </summary>
  GITHUB_API_URL    = 'https://api.github.com';

type
  /// <summary>
  ///   Represents the status of a Git repository.
  /// </summary>
  TRepoStatus = ( rsClean, rsModified, rsPullRequired, rsError, rsUnknown );

  /// <summary>
  ///   Represents a remote Git hosting provider.
  /// </summary>
  TRemoteProvider = ( rpNone, rpCodeberg, rpGitHub, rpOther );

  /// <summary>
  ///   Record containing information about a Git repository.
  /// </summary>
  TRepoInfo = record
    Name: string;
    Path: string;
    Branch: string;
    Status: TRepoStatus;
    StatusText: string;
    Selected: Boolean;
    TrackedFileCount: Integer;
    ModifiedFileCount: Integer;
    Provider: TRemoteProvider;
    Group: string;
    Version: string;
  end;

  TRepoInfoArray = TArray<TRepoInfo>;

  /// <summary>
  ///   Manages multiple Git repositories for batch operations.
  /// </summary>
  /// <remarks>
  ///   Handles repository configuration persistence, status detection,
  ///   commit/push operations via Git command-line interface, and
  ///   Codeberg repository creation.
  /// </remarks>
  TGitRepoManager = class
  private
    FRepos: TRepoInfoArray;
    FConfigPath: string;
    FCodebergUsername: string;
    FCodebergToken: string;
    FGitHubUsername: string;
    FGitHubToken: string;
    FGitClientPath: string;
    FFilePattern: string;
    FDelphiIndexerPath: string;
    FCommitHistory: TArray<string>;
    FCommitTemplates: TArray<string>;
    FReposLock: TCriticalSection;
    FVersionCache: TDictionary<string, string>;
    FVersionCacheStamp: TDictionary<string, TDateTime>;
    const
      MAX_HISTORY_ITEMS = 20;

      /// <summary>
      ///   Executes a Git command in the specified repository directory.
      /// </summary>
      /// <param name="sRepoPath">Path to the repository.</param>
      /// <param name="sCommand">Git command to execute (without 'git' prefix).</param>
      /// <param name="sOutput">Output from the command.</param>
      /// <param name="iTimeout">Timeout in milliseconds (default: GIT_COMMAND_TIMEOUT).</param>
      /// <returns>True if the command executed successfully with exit code 0.</returns>
    function ExecuteGitCommand( const sRepoPath, sCommand: string; out sOutput: string;
      const iTimeout: Cardinal = GIT_COMMAND_TIMEOUT ): Boolean;

    /// <summary>
    ///   Determines the status of a repository.
    /// </summary>
    function GetRepoStatus( const sRepoPath: string ): TRepoStatus;

    /// <summary>
    ///   Gets the current branch name for a repository.
    /// </summary>
    function GetRepoBranch( const sRepoPath: string ): string;

    /// <summary>
    ///   Checks if a repository needs to pull from remote.
    /// </summary>
    function NeedsPull( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Gets the number of files tracked by Git in the repository.
    /// </summary>
    function GetTrackedFileCount( const sRepoPath: string ): Integer;

    /// <summary>
    ///   Gets the number of modified/staged/untracked files in the repository.
    /// </summary>
    function GetModifiedFileCount( const sRepoPath: string ): Integer;

    /// <summary>
    ///   Returns the path to the configuration file.
    /// </summary>
    function GetConfigFilePath: string;

    /// <summary>
    ///   Escapes a string for safe use in Git commit messages via temp file.
    /// </summary>
    /// <param name="sMessage">The commit message to use.</param>
    /// <param name="sTempFile">Returns the path to the temp file created.</param>
    /// <returns>True if temp file was created successfully.</returns>
    function CreateCommitMessageFile( const sMessage: string; out sTempFile: string ): Boolean;

    /// <summary>
    ///   Makes an HTTP request to a remote API.
    /// </summary>
    /// <param name="sVerb">HTTP verb: 'POST' or 'PATCH'.</param>
    /// <param name="sBaseURL">API base URL (e.g. CODEBERG_API_URL or GITHUB_API_URL).</param>
    /// <param name="sEndpoint">API endpoint path.</param>
    /// <param name="sBody">JSON request body.</param>
    /// <param name="aHeaders">HTTP headers array.</param>
    /// <param name="sResponse">Response body.</param>
    /// <param name="iStatusCode">HTTP status code.</param>
    function ExecuteApiRequest( const sVerb, sBaseURL, sEndpoint, sBody: string;
      const aHeaders: TArray<TNameValuePair>; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP POST request to the Codeberg API.
    /// </summary>
    function ExecuteCodebergApiPost( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP POST request to the GitHub API.
    /// </summary>
    function ExecuteGitHubApiPost( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP PATCH request to the Codeberg API.
    /// </summary>
    function ExecuteCodebergApiPatch( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP PATCH request to the GitHub API.
    /// </summary>
    function ExecuteGitHubApiPatch( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Gets the remote origin URL for a repository.
    /// </summary>
    function GetRemoteOriginURL( const sRepoPath: string ): string;

    /// <summary>
    ///   Detects the remote provider from an origin URL.
    /// </summary>
    function DetectRemoteProvider( const sOriginURL: string ): TRemoteProvider;

    /// <summary>
    ///   Parses owner and repository name from an origin URL.
    /// </summary>
    function ParseOwnerRepo( const sOriginURL: string; out sOwner, sRepo: string ): Boolean;

    /// <summary>
    ///   Gets the project version from a .dproj file in the repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>Version string (e.g., "1.0.1.25") or empty if not found.</returns>
    function GetProjectVersion( const sRepoPath: string ): string;

    /// <summary>
    ///   Checks if a filename is a known build artifact (e.g., .dcu, .exe, Win32/).
    /// </summary>
    /// <param name="sFileName">The filename to check (may include path).</param>
    /// <returns>True if the file is a build artifact that should be ignored.</returns>
    function IsBuildArtifact( const sFileName: string ): Boolean;

    /// <summary>
    ///   Checks if all changes in git status output are build artifacts.
    /// </summary>
    /// <param name="sPorcelainOutput">Output from 'git status --porcelain'.</param>
    /// <returns>True if all changed files are build artifacts.</returns>
    function AllChangesAreBuildArtifacts( const sPorcelainOutput: string ): Boolean;

    /// <summary>
    ///   Returns the current branch of a repository ( e.g. "main", "master" ),
    ///   or empty string if the repo has no commits yet / is not a repo.
    /// </summary>
    function GetCurrentBranch( const sRepoPath: string ): string;

    /// <summary>
    ///   Returns True if the repository has at least one commit ( HEAD resolves ).
    /// </summary>
    function HasAnyCommit( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Returns True if the working tree is clean ( git status --porcelain is empty ).
    /// </summary>
    function IsWorkingTreeClean( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Configures a TNetHTTPClient with User-Agent and timeouts.
    /// </summary>
    procedure ConfigureHttpClient( const AClient: TNetHTTPClient );

    /// <summary>
    ///   Creates a repository on the given provider ( rpCodeberg or rpGitHub ).
    ///   Body is built with TJSONObject so name/description are safely escaped.
    /// </summary>
    function CreateRemoteRepository( const Provider: TRemoteProvider;
      const sName, sDescription: string; const lPrivate: Boolean;
      out sRemoteURL, sError: string ): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    ///   Loads repository list from the configuration file.
    /// </summary>
    /// <returns>True if configuration loaded successfully.</returns>
    function LoadConfig: Boolean;

    /// <summary>
    ///   Saves repository list to the configuration file.
    /// </summary>
    /// <returns>True if configuration saved successfully.</returns>
    function SaveConfig: Boolean;

    /// <summary>
    ///   Adds a new repository to the managed list.
    /// </summary>
    /// <param name="sPath">Path to the Git repository.</param>
    procedure AddRepository( const sPath: string );

    /// <summary>
    ///   Removes a repository from the managed list.
    /// </summary>
    /// <param name="iIndex">Index of the repository to remove.</param>
    procedure RemoveRepository( const iIndex: Integer );

    /// <summary>
    ///   Refreshes the status of all repositories.
    /// </summary>
    procedure RefreshAllStatus;

    /// <summary>
    ///   Refreshes the status of a single repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository to refresh.</param>
    procedure RefreshStatus( const iIndex: Integer );

    /// <summary>
    ///   Commits and pushes changes for a repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sMessage">Commit message.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function CommitAndPush( const iIndex: Integer; const sMessage: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Initializes a new Git repository in the specified folder.
    /// </summary>
    /// <param name="sPath">Path to the folder to initialize.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if initialization succeeded.</returns>
    function InitializeRepository( const sPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Creates a new repository on Codeberg.
    /// </summary>
    /// <param name="sName">Repository name.</param>
    /// <param name="sDescription">Repository description.</param>
    /// <param name="lPrivate">True to create a private repository.</param>
    /// <param name="sRemoteURL">Returns the clone URL of the created repository.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if creation succeeded.</returns>
    function CreateCodebergRepository( const sName, sDescription: string; const lPrivate: Boolean;
      out sRemoteURL, sError: string ): Boolean;

    /// <summary>
    ///   Adds a remote origin to a repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <param name="sRemoteURL">URL of the remote.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function AddRemoteOrigin( const sRepoPath, sRemoteURL: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Performs initial commit and push for a new repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <param name="sMessage">Commit message.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function InitialCommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Returns True if Codeberg credentials are configured.
    /// </summary>
    function HasCodebergCredentials: Boolean;

    /// <summary>
    ///   Creates a new repository on GitHub.
    /// </summary>
    /// <param name="sName">Repository name.</param>
    /// <param name="sDescription">Repository description.</param>
    /// <param name="lPrivate">True to create a private repository.</param>
    /// <param name="sRemoteURL">Returns the clone URL of the created repository.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if creation succeeded.</returns>
    function CreateGitHubRepository( const sName, sDescription: string; const lPrivate: Boolean;
      out sRemoteURL, sError: string ): Boolean;

    /// <summary>
    ///   Returns True if GitHub credentials are configured.
    /// </summary>
    function HasGitHubCredentials: Boolean;

    /// <summary>
    ///   Gets the remote provider for a repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <returns>The detected remote provider.</returns>
    function GetRepoProvider( const iIndex: Integer ): TRemoteProvider;

    /// <summary>
    ///   Changes the visibility of a remote repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="lPrivate">True to make private, False to make public.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if the operation succeeded.</returns>
    function SetRepositoryVisibility( const iIndex: Integer; const lPrivate: Boolean;
      out sError: string ): Boolean;

    /// <summary>
    ///   Pulls changes from remote for a repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function PullRepository( const iIndex: Integer; out sLog: string ): Boolean;

    /// <summary>
    ///   Resolves merge conflicts by keeping local versions of all files.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded or there was nothing to resolve.</returns>
    function ResolveConflictsKeepLocal( const iIndex: Integer; out sLog: string ): Boolean;

    /// <summary>
    ///   Pushes a repository to remote without committing.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function PushRepository( const iIndex: Integer; out sLog: string ): Boolean;

    /// <summary>
    ///   Force pushes a repository to remote, overwriting remote history.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function ForcePushRepository( const iIndex: Integer; out sLog: string ): Boolean;

    /// <summary>
    ///   Creates a backup branch before a potentially destructive operation.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sBranchName">Output: name of the created backup branch.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the backup branch was created successfully.</returns>
    function CreateBackupBranch( const iIndex: Integer; out sBranchName: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Fetches from remote and returns a preview of incoming changes.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sChanges">Output: description of files that will change.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if fetch succeeded (sChanges may be empty if no changes).</returns>
    function GetIncomingChanges( const iIndex: Integer; out sChanges: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Migrates a repository's remote from its current host (Codeberg or GitHub)
    ///   to the specified target provider. Creates the new repository on the target,
    ///   re-points <c>origin</c> to the new URL (the previous origin is kept under
    ///   a provider-named alias for safety) and pushes all branches and tags.
    /// </summary>
    /// <param name="iIndex">Index of the repository to migrate.</param>
    /// <param name="TargetProvider">Destination provider ( rpCodeberg or rpGitHub ).</param>
    /// <param name="sNewRepoName">Name of the repository to create on the target.</param>
    /// <param name="sDescription">Description for the new repository.</param>
    /// <param name="lPrivate">True to create the target repository as private.</param>
    /// <param name="sNewRemoteURL">Output: clone URL of the newly created remote.</param>
    /// <param name="sError">Output: error message if the operation failed.</param>
    /// <param name="sLog">Output: detailed log of each migration step.</param>
    /// <returns>True if the migration succeeded end-to-end.</returns>
    /// <remarks>
    ///   The old remote repository is NOT deleted — it must be removed manually via
    ///   the web interface once the migration has been verified. The previous origin
    ///   URL is preserved locally as a remote named after its provider (e.g. "codeberg"
    ///   or "github") so it can be restored if needed.
    /// </remarks>
    function MigrateRepository( const iIndex: Integer; const TargetProvider: TRemoteProvider;
      const sNewRepoName, sDescription: string; const lPrivate: Boolean;
      out sNewRemoteURL, sError, sLog: string ): Boolean;

    /// <summary>
    ///   Adds a commit message to the history.
    /// </summary>
    procedure AddToCommitHistory( const sMessage: string );

    /// <summary>
    ///   Adds a commit message template.
    /// </summary>
    procedure AddTemplate( const sTemplate: string );

    /// <summary>
    ///   Removes a commit message template by index.
    /// </summary>
    procedure RemoveTemplate( const iIndex: Integer );

    /// <summary>
    ///   Updates a commit message template.
    /// </summary>
    procedure UpdateTemplate( const iIndex: Integer; const sTemplate: string );

    /// <summary>
    ///   Returns all unique group names from repositories.
    /// </summary>
    function GetAllGroups: TArray<string>;

    /// <summary>
    ///   Sets the group for a repository.
    /// </summary>
    procedure SetRepoGroup( const iIndex: Integer; const sGroup: string );

    /// <summary>
    ///   Refreshes all repository statuses in parallel.
    /// </summary>
    procedure RefreshAllStatusParallel;

    /// <summary>
    ///   Returns True if sPattern is a safe file-add pattern ( no shell metacharacters ).
    ///   Accepts comma- or space-separated globs like "*.pas" or "src/*.pas docs/*.md".
    /// </summary>
    class function IsSafeFilePattern( const sPattern: string ): Boolean; static;

    /// <summary>
    ///   Returns a snapshot count of the repos array under the repos lock.
    /// </summary>
    function ReposCount: Integer;

    /// <summary>
    ///   Returns a snapshot copy of a repo by index, or a default TRepoInfo if out of range.
    /// </summary>
    function GetRepoSnapshot( const iIndex: Integer; out ARepo: TRepoInfo ): Boolean;

    property Repos: TRepoInfoArray read FRepos;
    property ConfigPath: string read FConfigPath;
    property CodebergUsername: string read FCodebergUsername write FCodebergUsername;
    property CodebergToken: string read FCodebergToken write FCodebergToken;
    property GitHubUsername: string read FGitHubUsername write FGitHubUsername;
    property GitHubToken: string read FGitHubToken write FGitHubToken;
    property GitClientPath: string read FGitClientPath write FGitClientPath;
    property FilePattern: string read FFilePattern write FFilePattern;
    property DelphiIndexerPath: string read FDelphiIndexerPath write FDelphiIndexerPath;
    property CommitHistory: TArray<string> read FCommitHistory;
    property CommitTemplates: TArray<string> read FCommitTemplates write FCommitTemplates;
  end;

/// <summary>
///   Converts a repository status to a human-readable string.
/// </summary>
function RepoStatusToString( const Status: TRepoStatus ): string;

/// <summary>
///   Converts a remote provider to a human-readable string.
/// </summary>
function RemoteProviderToString( const Provider: TRemoteProvider ): string;

implementation

function RepoStatusToString( const Status: TRepoStatus ): string;
begin

  case Status of
    rsClean: Result := 'Clean';
    rsModified: Result := 'Modified';
    rsPullRequired: Result := 'Pull Required';
    rsError: Result := 'Error';
  else
    Result := 'Unknown';
  end;

end;

function RemoteProviderToString( const Provider: TRemoteProvider ): string;
begin

  case Provider of
    rpCodeberg: Result := 'Codeberg';
    rpGitHub: Result := 'GitHub';
    rpOther: Result := 'Other';
  else
    Result := 'None';
  end;

end;

{ TGitRepoManager }

constructor TGitRepoManager.Create;
begin

  inherited Create;
  FConfigPath := GetConfigFilePath;
  FReposLock := TCriticalSection.Create;
  FVersionCache := TDictionary<string, string>.Create;
  FVersionCacheStamp := TDictionary<string, TDateTime>.Create;
  SetLength( FRepos, 0 );

end;

destructor TGitRepoManager.Destroy;
begin

  SetLength( FRepos, 0 );
  FVersionCacheStamp.Free;
  FVersionCache.Free;
  FReposLock.Free;
  inherited;

end;

class function TGitRepoManager.IsSafeFilePattern( const sPattern: string ): Boolean;
var
  sTrim             : string;
  Ch                : Char;
begin

  sTrim := Trim( sPattern );

  if sTrim.IsEmpty then
    Exit( True );

  // Disallow any shell metacharacter or control character. Globs (* ? [ ] . _ - / \),
  // digits, letters, and separators (space, comma, semicolon-as-separator) are fine.
  for Ch in sTrim do
  begin
    case Ch of
      'A'..'Z', 'a'..'z', '0'..'9',
      '*', '?', '[', ']', '.', '-', '_', '/', '\', ' ', ',', ':':
        ; // allowed
    else
      Exit( False );
    end;
  end;

  Result := True;

end;

function TGitRepoManager.ReposCount: Integer;
begin

  FReposLock.Enter;

  try
    Result := Length( FRepos );
  finally
    FReposLock.Leave;
  end;

end;

function TGitRepoManager.GetRepoSnapshot( const iIndex: Integer; out ARepo: TRepoInfo ): Boolean;
begin

  FReposLock.Enter;

  try
    if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
      Exit( False );

    ARepo := FRepos[ iIndex ];
    Result := True;
  finally
    FReposLock.Leave;
  end;

end;

function TGitRepoManager.GetCurrentBranch( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result := '';

  if ExecuteGitCommand( sRepoPath, 'rev-parse --abbrev-ref HEAD', sOutput ) then
  begin
    Result := Trim( sOutput );

    // "HEAD" means detached — no usable branch
    if SameText( Result, 'HEAD' ) then
      Result := '';
  end;

  // Fall back to symbolic-ref for a fresh repo (no commits yet)
  if Result.IsEmpty then
  begin
    if ExecuteGitCommand( sRepoPath, 'symbolic-ref --short HEAD', sOutput ) then
      Result := Trim( sOutput );
  end;

end;

function TGitRepoManager.HasAnyCommit( const sRepoPath: string ): Boolean;
var
  sOutput           : string;
begin

  Result := ExecuteGitCommand( sRepoPath, 'rev-parse --verify HEAD', sOutput );

end;

function TGitRepoManager.IsWorkingTreeClean( const sRepoPath: string ): Boolean;
var
  sOutput           : string;
begin

  Result := ExecuteGitCommand( sRepoPath, 'status --porcelain', sOutput ) and
    Trim( sOutput ).IsEmpty;

end;

procedure TGitRepoManager.ConfigureHttpClient( const AClient: TNetHTTPClient );
begin

  AClient.ContentType := 'application/json';
  AClient.UserAgent := Format( 'GitBatchCommit/%s (+https://codeberg.org/GITLAK/GitBatchCommit)', [ APP_VERSION ] );
  AClient.ConnectionTimeout := 15000;
  AClient.ResponseTimeout := 30000;

end;

function TGitRepoManager.GetConfigFilePath: string;
var
  sDir              : string;
begin

  sDir := TPath.Combine( TPath.GetHomePath, 'GitBatchCommit' );

  if ( not TDirectory.Exists( sDir ) ) then
  begin
    try
      TDirectory.CreateDirectory( sDir );
    except
      on E: Exception do
      begin
        // Fall back to application directory if home directory fails
        sDir := ExtractFilePath( ParamStr( 0 ) );
      end;
    end;
  end;

  Result := TPath.Combine( sDir, 'repositories.json' );

end;

function TGitRepoManager.ExecuteGitCommand( const sRepoPath, sCommand: string; out sOutput: string;
  const iTimeout: Cardinal ): Boolean;
var
  StartupInfo       : TStartupInfo;
  ProcessInfo       : TProcessInformation;
  SecurityAttr      : TSecurityAttributes;
  hReadPipe, hWritePipe: THandle;
  Buffer            : TBytes;
  dwBytesRead       : DWORD;
  dwBytesAvail      : DWORD;
  lSuccess          : Boolean;
  dwWaitResult      : DWORD;
  dwExitCode        : DWORD;
  sFullCommand      : string;
  iRemainingTimeout : Integer;
begin

  Result := False;
  sOutput := '';

  SecurityAttr.nLength := SizeOf( TSecurityAttributes );
  SecurityAttr.bInheritHandle := True;
  SecurityAttr.lpSecurityDescriptor := nil;

  if ( not CreatePipe( hReadPipe, hWritePipe, @SecurityAttr, 0 ) ) then
    Exit;

  try
    ZeroMemory( @StartupInfo, SizeOf( TStartupInfo ) );
    StartupInfo.cb := SizeOf( TStartupInfo );
    StartupInfo.hStdOutput := hWritePipe;
    StartupInfo.hStdError := hWritePipe;
    StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow := SW_HIDE;

    ZeroMemory( @ProcessInfo, SizeOf( TProcessInformation ) );

    // Invoke git.exe directly via lpCommandLine, and set the working directory
    // via lpCurrentDirectory — avoids routing through cmd.exe, which means
    // shell metacharacters in sCommand or sRepoPath cannot be interpreted.
    sFullCommand := 'git ' + sCommand;

    lSuccess := CreateProcess(
      nil,
      PChar( sFullCommand ),
      nil,
      nil,
      True,
      CREATE_NO_WINDOW,
      nil,
      PChar( sRepoPath ),               // lpCurrentDirectory — no cmd.exe needed
      StartupInfo,
      ProcessInfo
      );

    if lSuccess then
    begin
      CloseHandle( hWritePipe );
      hWritePipe := 0;

      SetLength( Buffer, 4096 );
      iRemainingTimeout := iTimeout;

      // Read output while process is running
      repeat
        dwWaitResult := WaitForSingleObject( ProcessInfo.hProcess, 100 );

        // Check for available data
        while PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
        begin
          if ReadFile( hReadPipe, Buffer[ 0 ], Length( Buffer ), dwBytesRead, nil ) and ( dwBytesRead > 0 ) then
            sOutput := sOutput + TEncoding.UTF8.GetString( Buffer, 0, dwBytesRead );
        end;

        // Check for timeout
        if dwWaitResult = WAIT_TIMEOUT then
        begin
          Dec( iRemainingTimeout, 100 );

          if iRemainingTimeout <= 0 then
          begin
            TerminateProcess( ProcessInfo.hProcess, 1 );
            sOutput := sOutput + sLineBreak + 'Operation timed out';
            Break;
          end;
        end;
      until dwWaitResult = WAIT_OBJECT_0;

      // Read any remaining output
      while PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
      begin
        if ReadFile( hReadPipe, Buffer[ 0 ], Length( Buffer ), dwBytesRead, nil ) and ( dwBytesRead > 0 ) then
          sOutput := sOutput + TEncoding.UTF8.GetString( Buffer, 0, dwBytesRead );
      end;

      // Check exit code to determine success
      if GetExitCodeProcess( ProcessInfo.hProcess, dwExitCode ) then
        Result := ( dwExitCode = 0 );

      CloseHandle( ProcessInfo.hProcess );
      CloseHandle( ProcessInfo.hThread );
    end;
  finally
    if hWritePipe <> 0 then
      CloseHandle( hWritePipe );

    CloseHandle( hReadPipe );
  end;

end;

function TGitRepoManager.CreateCommitMessageFile( const sMessage: string; out sTempFile: string ): Boolean;
begin

  Result := False;

  try
    sTempFile := TPath.Combine( TPath.GetTempPath, Format( 'gitcommit_%s.txt', [ TPath.GetGUIDFileName( False ) ] ) );
    TFile.WriteAllText( sTempFile, sMessage, TEncoding.UTF8 );
    Result := True;
  except
    on E: Exception do
      sTempFile := '';
  end;

end;

function TGitRepoManager.GetRepoBranch( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result := '';

  if ExecuteGitCommand( sRepoPath, 'branch --show-current', sOutput ) then
    Result := Trim( sOutput );

  if Result.IsEmpty then
    Result := '(unknown)';

end;

function TGitRepoManager.NeedsPull( const sRepoPath: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;

  // Fetch latest from remote (without merging)
  ExecuteGitCommand( sRepoPath, 'fetch', sOutput );

  // Check if we're behind the remote
  if ExecuteGitCommand( sRepoPath, 'status -uno', sOutput ) then
    Result := sOutput.Contains( 'Your branch is behind' );

end;

function TGitRepoManager.GetTrackedFileCount( const sRepoPath: string ): Integer;
var
  sOutput           : string;
  Lines             : TArray<string>;
begin

  Result := 0;

  // Use git ls-files to get list of tracked files
  if ExecuteGitCommand( sRepoPath, 'ls-files', sOutput ) then
  begin
    sOutput := Trim( sOutput );

    if ( not sOutput.IsEmpty ) then
    begin
      Lines := sOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );
      Result := Length( Lines );
    end;
  end;

end;

function TGitRepoManager.GetModifiedFileCount( const sRepoPath: string ): Integer;
var
  sOutput           : string;
  Lines             : TArray<string>;
begin

  Result := 0;

  // Use git status --porcelain to get modified/staged/untracked files
  if ExecuteGitCommand( sRepoPath, 'status --porcelain', sOutput ) then
  begin
    sOutput := Trim( sOutput );

    if ( not sOutput.IsEmpty ) then
    begin
      Lines := sOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );
      Result := Length( Lines );
    end;
  end;

end;

function TGitRepoManager.GetRepoStatus( const sRepoPath: string ): TRepoStatus;
var
  sOutput           : string;
begin

  if ( not TDirectory.Exists( TPath.Combine( sRepoPath, '.git' ) ) ) then
  begin
    Result := rsError;
    Exit;
  end;

  // Check for local modifications first
  if ExecuteGitCommand( sRepoPath, 'status --porcelain', sOutput ) then
  begin
    if Trim( sOutput ).IsEmpty then
    begin
      // No local changes - check if we need to pull
      if NeedsPull( sRepoPath ) then
        Result := rsPullRequired
      else
        Result := rsClean;
    end
    else if AllChangesAreBuildArtifacts( sOutput ) then
    begin
      // All changes are build artifacts - treat as clean
      if NeedsPull( sRepoPath ) then
        Result := rsPullRequired
      else
        Result := rsClean;
    end
    else
      Result := rsModified;
  end
  else
    Result := rsError;

end;

function TGitRepoManager.LoadConfig: Boolean;
var
  sJSON             : string;
  JSONValue         : TJSONValue;
  JSONRoot          : TJSONObject;
  JSONArray         : TJSONArray;
  JSONHistoryArray  : TJSONArray;
  JSONObj           : TJSONObject;
begin

  Result := False;
  SetLength( FRepos, 0 );
  SetLength( FCommitHistory, 0 );
  SetLength( FCommitTemplates, 0 );
  FCodebergUsername := '';
  FCodebergToken := '';
  FGitHubUsername := '';
  FGitHubToken := '';
  FGitClientPath := '';
  FFilePattern := '';

  if ( not TFile.Exists( FConfigPath ) ) then
  begin
    Result := True;                     // No config file is not an error
    Exit;
  end;

  try
    sJSON := TFile.ReadAllText( FConfigPath, TEncoding.UTF8 );
  except
    on E: Exception do
      Exit;
  end;

  if sJSON.Trim.IsEmpty then
  begin
    Result := True;
    Exit;
  end;

  try
    JSONValue := TJSONObject.ParseJSONValue( sJSON );
  except
    on E: Exception do
      Exit;
  end;

  if JSONValue = nil then
    Exit;

  try
    // Support both old format (array) and new format (object with repos and credentials)
    if ( JSONValue is TJSONArray ) then
    begin
      JSONArray := JSONValue as TJSONArray;
    end
    else if ( JSONValue is TJSONObject ) then
    begin
      JSONRoot := JSONValue as TJSONObject;

      // Load Codeberg credentials
      FCodebergUsername := JSONRoot.GetValue<string>( 'codeberg_username', '' );
      FCodebergToken := JSONRoot.GetValue<string>( 'codeberg_token', '' );

      // Load GitHub credentials
      FGitHubUsername := JSONRoot.GetValue<string>( 'github_username', '' );
      FGitHubToken := JSONRoot.GetValue<string>( 'github_token', '' );

      // Load settings
      FGitClientPath := JSONRoot.GetValue<string>( 'git_client_path', '' );
      FFilePattern := JSONRoot.GetValue<string>( 'file_pattern', '' );
      FDelphiIndexerPath := JSONRoot.GetValue<string>( 'delphi_indexer_path', '' );

      // Drop any file pattern that contains shell metacharacters — config
      // files can be hand-edited, so never trust them blindly.
      if ( not IsSafeFilePattern( FFilePattern ) ) then
        FFilePattern := '';

      // Load commit history
      if JSONRoot.GetValue( 'commit_history' ) is TJSONArray then
      begin
        JSONHistoryArray := JSONRoot.GetValue( 'commit_history' ) as TJSONArray;
        SetLength( FCommitHistory, JSONHistoryArray.Count );

        for var i := 0 to JSONHistoryArray.Count - 1 do
          FCommitHistory[ i ] := JSONHistoryArray.Items[ i ].Value;
      end;

      // Load commit templates
      if JSONRoot.GetValue( 'commit_templates' ) is TJSONArray then
      begin
        JSONHistoryArray := JSONRoot.GetValue( 'commit_templates' ) as TJSONArray;
        SetLength( FCommitTemplates, JSONHistoryArray.Count );

        for var i := 0 to JSONHistoryArray.Count - 1 do
          FCommitTemplates[ i ] := JSONHistoryArray.Items[ i ].Value;
      end;

      // Get repositories array
      if JSONRoot.GetValue( 'repositories' ) is TJSONArray then
        JSONArray := JSONRoot.GetValue( 'repositories' ) as TJSONArray
      else
      begin
        Result := True;
        Exit;
      end;
    end
    else
      Exit;

    SetLength( FRepos, JSONArray.Count );

    for var i := 0 to JSONArray.Count - 1 do
    begin
      if ( not ( JSONArray.Items[ i ] is TJSONObject ) ) then
      begin
        // Skip invalid items but continue processing
        FRepos[ i ].Path := '';
        FRepos[ i ].Status := rsError;
        Continue;
      end;

      JSONObj := JSONArray.Items[ i ] as TJSONObject;

      FRepos[ i ].Path := JSONObj.GetValue<string>( 'path', '' );
      FRepos[ i ].Name := ExtractFileName( ExcludeTrailingPathDelimiter( FRepos[ i ].Path ) );

      FRepos[ i ].Branch := '';
      FRepos[ i ].Status := rsUnknown;
      FRepos[ i ].StatusText := '';
      FRepos[ i ].Selected := False;
      FRepos[ i ].TrackedFileCount := 0;
      FRepos[ i ].ModifiedFileCount := 0;
      FRepos[ i ].Provider := rpNone;
      FRepos[ i ].Group := JSONObj.GetValue<string>( 'group', '' );
      FRepos[ i ].Version := '';
    end;

    Result := True;
  finally
    JSONValue.Free;
  end;

end;

function TGitRepoManager.SaveConfig: Boolean;
var
  JSONRoot          : TJSONObject;
  JSONArray         : TJSONArray;
  JSONHistoryArray  : TJSONArray;
  JSONObj           : TJSONObject;
begin

  Result := False;

  // Guard: never overwrite a config file with an empty repo list
  // unless the file doesn't exist yet (fresh install)
  if ( Length( FRepos ) = 0 ) and TFile.Exists( FConfigPath ) then
  begin
    Result := True;
    Exit;
  end;

  JSONRoot := TJSONObject.Create;

  try
    // Save Codeberg credentials
    JSONRoot.AddPair( 'codeberg_username', FCodebergUsername );
    JSONRoot.AddPair( 'codeberg_token', FCodebergToken );

    // Save GitHub credentials
    JSONRoot.AddPair( 'github_username', FGitHubUsername );
    JSONRoot.AddPair( 'github_token', FGitHubToken );

    // Save settings
    JSONRoot.AddPair( 'git_client_path', FGitClientPath );
    JSONRoot.AddPair( 'file_pattern', FFilePattern );
    JSONRoot.AddPair( 'delphi_indexer_path', FDelphiIndexerPath );

    // Save commit history
    JSONHistoryArray := TJSONArray.Create;

    for var i := 0 to High( FCommitHistory ) do
      JSONHistoryArray.Add( FCommitHistory[ i ] );

    JSONRoot.AddPair( 'commit_history', JSONHistoryArray );

    // Save commit templates
    JSONHistoryArray := TJSONArray.Create;

    for var i := 0 to High( FCommitTemplates ) do
      JSONHistoryArray.Add( FCommitTemplates[ i ] );

    JSONRoot.AddPair( 'commit_templates', JSONHistoryArray );

    // Save repositories
    JSONArray := TJSONArray.Create;

    for var i := 0 to High( FRepos ) do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair( 'path', FRepos[ i ].Path );
      JSONObj.AddPair( 'group', FRepos[ i ].Group );
      JSONArray.AddElement( JSONObj );
    end;

    JSONRoot.AddPair( 'repositories', JSONArray );

    try
      TFile.WriteAllText( FConfigPath, JSONRoot.Format, TEncoding.UTF8 );
      Result := True;
    except
      on E: Exception do
      begin
        // A read-only filesystem, locked file, or missing directory makes config
        // unsaveable — surface that to the debugger so the user can find out why.
        OutputDebugString( PChar( Format( 'GitBatchCommit: SaveConfig failed for "%s": %s',
          [ FConfigPath, E.Message ] ) ) );
      end;
    end;
  finally
    JSONRoot.Free;
  end;

end;

procedure TGitRepoManager.AddRepository( const sPath: string );
var
  iLen              : Integer;
begin

  FReposLock.Enter;

  try
    // Check if already exists
    for var i := 0 to High( FRepos ) do
    begin
      if SameText( FRepos[ i ].Path, sPath ) then
        Exit;
    end;

    iLen := Length( FRepos );
    SetLength( FRepos, iLen + 1 );

    FRepos[ iLen ].Path := sPath;
    FRepos[ iLen ].Name := ExtractFileName( ExcludeTrailingPathDelimiter( sPath ) );
    FRepos[ iLen ].Branch := '';
    FRepos[ iLen ].Status := rsUnknown;
    FRepos[ iLen ].StatusText := '';
    FRepos[ iLen ].Selected := False;
    FRepos[ iLen ].TrackedFileCount := 0;
    FRepos[ iLen ].ModifiedFileCount := 0;
    FRepos[ iLen ].Provider := rpNone;
    FRepos[ iLen ].Group := '';
    FRepos[ iLen ].Version := '';
  finally
    FReposLock.Leave;
  end;

  RefreshStatus( iLen );
  SaveConfig;

end;

procedure TGitRepoManager.RemoveRepository( const iIndex: Integer );
begin

  FReposLock.Enter;

  try
    if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
      Exit;

    for var i := iIndex to High( FRepos ) - 1 do
      FRepos[ i ] := FRepos[ i + 1 ];

    SetLength( FRepos, Length( FRepos ) - 1 );
  finally
    FReposLock.Leave;
  end;

  SaveConfig;

end;

procedure TGitRepoManager.RefreshStatus( const iIndex: Integer );
var
  sOriginURL        : string;
  sStatusOutput     : string;
  sRepoPath         : string;
  Lines             : TArray<string>;
begin

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
    Exit;

  sRepoPath := FRepos[ iIndex ].Path;

  // Get branch
  FRepos[ iIndex ].Branch := GetRepoBranch( sRepoPath );

  // Get status and modified count from single git status call
  if ( not TDirectory.Exists( TPath.Combine( sRepoPath, '.git' ) ) ) then
  begin
    FRepos[ iIndex ].Status := rsError;
    FRepos[ iIndex ].ModifiedFileCount := 0;
  end
  else if ExecuteGitCommand( sRepoPath, 'status --porcelain', sStatusOutput ) then
  begin
    sStatusOutput := Trim( sStatusOutput );

    if sStatusOutput.IsEmpty then
    begin
      FRepos[ iIndex ].ModifiedFileCount := 0;
      if NeedsPull( sRepoPath ) then
        FRepos[ iIndex ].Status := rsPullRequired
      else
        FRepos[ iIndex ].Status := rsClean;
    end
    else if AllChangesAreBuildArtifacts( sStatusOutput ) then
    begin
      // All changes are build artifacts - treat as clean
      Lines := sStatusOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );
      FRepos[ iIndex ].ModifiedFileCount := Length( Lines );
      if NeedsPull( sRepoPath ) then
        FRepos[ iIndex ].Status := rsPullRequired
      else
        FRepos[ iIndex ].Status := rsClean;
    end
    else
    begin
      Lines := sStatusOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );
      FRepos[ iIndex ].ModifiedFileCount := Length( Lines );
      FRepos[ iIndex ].Status := rsModified;
    end;
  end
  else
  begin
    FRepos[ iIndex ].Status := rsError;
    FRepos[ iIndex ].ModifiedFileCount := 0;
  end;

  FRepos[ iIndex ].StatusText := RepoStatusToString( FRepos[ iIndex ].Status );
  FRepos[ iIndex ].TrackedFileCount := GetTrackedFileCount( sRepoPath );

  sOriginURL := GetRemoteOriginURL( sRepoPath );
  FRepos[ iIndex ].Provider := DetectRemoteProvider( sOriginURL );

  // Get project version from .dproj file if present
  FRepos[ iIndex ].Version := GetProjectVersion( sRepoPath );

end;

procedure TGitRepoManager.RefreshAllStatus;
begin

  for var i := 0 to High( FRepos ) do
    RefreshStatus( i );

end;

function TGitRepoManager.CommitAndPush( const iIndex: Integer; const sMessage: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sTempFile         : string;
  sVersion          : string;
  sTagName          : string;
begin

  Result := False;
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  sLog := Format( '=== %s ===%s', [ FRepos[ iIndex ].Name, sLineBreak ] );

  // Stage changes (use file pattern if specified)
  if FFilePattern.Trim.IsEmpty then
  begin
    if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'add -A', sOutput ) ) then
    begin
      sLog := sLog + 'Failed to stage changes: ' + Trim( sOutput ) + sLineBreak;
      Exit;
    end;

    sLog := sLog + 'Staged all changes' + sLineBreak;
  end
  else
  begin
    // Refuse to execute a file pattern that contains shell metacharacters.
    // Belt-and-braces: the settings dialog already validates, but config files
    // can be hand-edited, so we re-check here.
    if ( not IsSafeFilePattern( FFilePattern ) ) then
    begin
      sLog := sLog + 'Refused to stage — file pattern contains unsafe characters: ' + FFilePattern + sLineBreak;
      Exit;
    end;

    if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'add ' + FFilePattern, sOutput ) ) then
    begin
      sLog := sLog + 'Failed to stage changes: ' + Trim( sOutput ) + sLineBreak;
      Exit;
    end;

    sLog := sLog + 'Staged changes matching: ' + FFilePattern + sLineBreak;
  end;

  // Create temp file for commit message (avoids command injection)
  if ( not CreateCommitMessageFile( sMessage, sTempFile ) ) then
  begin
    sLog := sLog + 'Failed to create commit message file' + sLineBreak;
    Exit;
  end;

  try
    // Commit using file-based message
    if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput ) ) then
    begin
      sLog := sLog + 'Commit failed: ' + Trim( sOutput ) + sLineBreak;
      Exit;
    end;

    sLog := sLog + 'Committed: ' + Trim( sOutput ) + sLineBreak;
  finally
    // Clean up temp file
    if TFile.Exists( sTempFile ) then
    begin
      try
        TFile.Delete( sTempFile );
      except
        ;                               // Ignore cleanup errors
      end;
    end;
  end;

  // Push
  if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'push', sOutput ) ) then
  begin
    sLog := sLog + 'Push failed: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Pushed successfully' + sLineBreak;

  // Create and push version tag if .dproj version exists
  sVersion := GetProjectVersion( FRepos[ iIndex ].Path );

  if ( not sVersion.IsEmpty ) then
  begin
    sTagName := 'v' + sVersion;

    // Check if tag already exists
    if ExecuteGitCommand( FRepos[ iIndex ].Path, Format( 'tag -l "%s"', [ sTagName ] ), sOutput ) then
    begin
      if Trim( sOutput ).IsEmpty then
      begin
        // Tag doesn't exist - create it
        if ExecuteGitCommand( FRepos[ iIndex ].Path, Format( 'tag -a "%s" -m "Version %s"', [ sTagName, sVersion ] ), sOutput ) then
        begin
          sLog := sLog + Format( 'Created tag: %s', [ sTagName ] ) + sLineBreak;

          // Push the tag
          if ExecuteGitCommand( FRepos[ iIndex ].Path, Format( 'push origin "%s"', [ sTagName ] ), sOutput ) then
            sLog := sLog + Format( 'Pushed tag: %s', [ sTagName ] ) + sLineBreak
          else
            sLog := sLog + 'Warning: Failed to push tag: ' + Trim( sOutput ) + sLineBreak;
        end
        else
          sLog := sLog + 'Warning: Failed to create tag: ' + Trim( sOutput ) + sLineBreak;
      end
      else
        sLog := sLog + Format( 'Tag %s already exists', [ sTagName ] ) + sLineBreak;
    end;
  end;

  // Add to commit history
  AddToCommitHistory( sMessage );

  Result := True;
  RefreshStatus( iIndex );

end;

function TGitRepoManager.HasCodebergCredentials: Boolean;
begin

  Result := ( not FCodebergUsername.Trim.IsEmpty ) and ( not FCodebergToken.Trim.IsEmpty );

end;

function TGitRepoManager.ExecuteApiRequest( const sVerb, sBaseURL, sEndpoint, sBody: string;
  const aHeaders: TArray<TNameValuePair>; out sResponse: string; out iStatusCode: Integer ): Boolean;
var
  HttpClient        : TNetHTTPClient;
  Response          : IHTTPResponse;
  RequestStream     : TStringStream;
begin

  Result := False;
  sResponse := '';
  iStatusCode := 0;

  HttpClient := TNetHTTPClient.Create( nil );
  RequestStream := TStringStream.Create( sBody, TEncoding.UTF8 );

  try
    ConfigureHttpClient( HttpClient );

    try
      if SameText( sVerb, 'POST' ) then
        Response := HttpClient.Post( sBaseURL + sEndpoint, RequestStream, nil, aHeaders )
      else if SameText( sVerb, 'PATCH' ) then
        Response := HttpClient.Patch( sBaseURL + sEndpoint, RequestStream, nil, aHeaders )
      else
      begin
        sResponse := 'Unsupported HTTP verb: ' + sVerb;
        Exit;
      end;

      iStatusCode := Response.StatusCode;
      sResponse := Response.ContentAsString;
      Result := ( iStatusCode >= 200 ) and ( iStatusCode < 300 );
    except
      on E: Exception do
        sResponse := 'HTTP Error: ' + E.Message;
    end;
  finally
    RequestStream.Free;
    HttpClient.Free;
  end;

end;

function TGitRepoManager.ExecuteCodebergApiPost( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
begin

  Result := ExecuteApiRequest( 'POST', CODEBERG_API_URL, sEndpoint, sBody,
    [ TNameValuePair.Create( 'Authorization', 'token ' + FCodebergToken ),
      TNameValuePair.Create( 'Content-Type', 'application/json' ) ],
    sResponse, iStatusCode );

end;

function TGitRepoManager.ExecuteGitHubApiPost( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
begin

  Result := ExecuteApiRequest( 'POST', GITHUB_API_URL, sEndpoint, sBody,
    [ TNameValuePair.Create( 'Authorization', 'Bearer ' + FGitHubToken ),
      TNameValuePair.Create( 'Content-Type', 'application/json' ),
      TNameValuePair.Create( 'Accept', 'application/vnd.github+json' ) ],
    sResponse, iStatusCode );

end;

function TGitRepoManager.ExecuteCodebergApiPatch( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
begin

  Result := ExecuteApiRequest( 'PATCH', CODEBERG_API_URL, sEndpoint, sBody,
    [ TNameValuePair.Create( 'Authorization', 'token ' + FCodebergToken ),
      TNameValuePair.Create( 'Content-Type', 'application/json' ) ],
    sResponse, iStatusCode );

end;

function TGitRepoManager.ExecuteGitHubApiPatch( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
begin

  Result := ExecuteApiRequest( 'PATCH', GITHUB_API_URL, sEndpoint, sBody,
    [ TNameValuePair.Create( 'Authorization', 'Bearer ' + FGitHubToken ),
      TNameValuePair.Create( 'Content-Type', 'application/json' ),
      TNameValuePair.Create( 'Accept', 'application/vnd.github+json' ) ],
    sResponse, iStatusCode );

end;

function TGitRepoManager.GetRemoteOriginURL( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result := '';

  if ExecuteGitCommand( sRepoPath, 'remote get-url origin', sOutput ) then
    Result := Trim( sOutput );

end;

function TGitRepoManager.DetectRemoteProvider( const sOriginURL: string ): TRemoteProvider;
var
  sLower            : string;
begin

  Result := rpNone;

  if sOriginURL.IsEmpty then
    Exit;

  sLower := sOriginURL.ToLower;

  if sLower.Contains( 'codeberg.org' ) then
    Result := rpCodeberg
  else if sLower.Contains( 'github.com' ) then
    Result := rpGitHub
  else if ( not sOriginURL.IsEmpty ) then
    Result := rpOther;

end;

function TGitRepoManager.ParseOwnerRepo( const sOriginURL: string; out sOwner, sRepo: string ): Boolean;
var
  sURL              : string;
  iPosLastSlash     : Integer;
  iPosSecondLastSlash: Integer;
  sRepoWithExt      : string;
begin

  Result := False;
  sOwner := '';
  sRepo := '';

  sURL := Trim( sOriginURL );

  if sURL.IsEmpty then
    Exit;

  // Remove trailing .git if present
  if sURL.EndsWith( '.git', True ) then
    sURL := Copy( sURL, 1, Length( sURL ) - 4 );

  // Remove trailing slash if present
  if sURL.EndsWith( '/' ) then
    sURL := Copy( sURL, 1, Length( sURL ) - 1 );

  // Find the last slash (repo name is after it)
  iPosLastSlash := sURL.LastIndexOf( '/' );

  if iPosLastSlash < 0 then
    Exit;

  sRepoWithExt := Copy( sURL, iPosLastSlash + 2, MaxInt );

  // Find the second-to-last slash (owner is after it)
  iPosSecondLastSlash := Copy( sURL, 1, iPosLastSlash ).LastIndexOf( '/' );

  if iPosSecondLastSlash < 0 then
  begin
    // Handle SSH format: git@github.com:owner/repo
    iPosSecondLastSlash := sURL.LastIndexOf( ':' );
  end;

  if iPosSecondLastSlash < 0 then
    Exit;

  sOwner := Copy( sURL, iPosSecondLastSlash + 2, iPosLastSlash - iPosSecondLastSlash - 1 );
  sRepo := sRepoWithExt;

  Result := ( not sOwner.IsEmpty ) and ( not sRepo.IsEmpty );

end;

function TGitRepoManager.GetProjectVersion( const sRepoPath: string ): string;
var
  DprojFiles        : TArray<string>;
  sDprojPath        : string;
  sContent          : string;
  sLine             : string;
  Lines             : TArray<string>;
  iPos              : Integer;
  iEndPos           : Integer;
  sVersion          : string;
  sBestVersion      : string;
  VersionParts      : TArray<string>;
  BestParts         : TArray<string>;
  lIsBetter         : Boolean;
  sKey              : string;
  CachedStamp       : TDateTime;
  CachedVersion     : string;
  NewestDprojWrite  : TDateTime;
  dt                : TDateTime;
begin

  Result := '';
  sBestVersion := '';
  sKey := sRepoPath.ToLower;

  // Find .dproj files in repository and subdirectories
  try
    DprojFiles := TDirectory.GetFiles( sRepoPath, '*.dproj', TSearchOption.soAllDirectories );
  except
    Exit;
  end;

  if Length( DprojFiles ) = 0 then
    Exit;

  // Cache hit: if every .dproj's mtime is <= the stamp we recorded last time,
  // nothing has changed, so return the cached version. Touching any .dproj
  // invalidates the cache for that path.
  NewestDprojWrite := 0;

  for sDprojPath in DprojFiles do
  begin
    try
      dt := TFile.GetLastWriteTime( sDprojPath );
    except
      dt := 0;
    end;

    if dt > NewestDprojWrite then
      NewestDprojWrite := dt;
  end;

  FReposLock.Enter;

  try
    if FVersionCacheStamp.TryGetValue( sKey, CachedStamp ) and
       ( CachedStamp >= NewestDprojWrite ) and
       FVersionCache.TryGetValue( sKey, CachedVersion ) then
      Exit( CachedVersion );
  finally
    FReposLock.Leave;
  end;

  // Process each .dproj file found
  for sDprojPath in DprojFiles do
  begin
    // Read and parse the .dproj file
    try
      sContent := TFile.ReadAllText( sDprojPath, TEncoding.UTF8 );
    except
      Continue;
    end;

    // Search for FileVersion= in VerInfo_Keys
    Lines := sContent.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );

    for sLine in Lines do
    begin
      if sLine.Contains( 'VerInfo_Keys' ) and sLine.Contains( 'FileVersion=' ) then
      begin
        // Extract FileVersion value
        iPos := sLine.IndexOf( 'FileVersion=' );

        if iPos >= 0 then
        begin
          iPos := iPos + Length( 'FileVersion=' );
          iEndPos := sLine.IndexOf( ';', iPos );

          if iEndPos < 0 then
            iEndPos := sLine.IndexOf( '<', iPos );

          if iEndPos > iPos then
          begin
            sVersion := sLine.Substring( iPos, iEndPos - iPos );

            // Compare versions to find the highest
            if sBestVersion.IsEmpty then
              sBestVersion := sVersion
            else
            begin
              // Compare version numbers (handle different-length strings e.g. "1.5.0" vs "1.5.0.38")
              VersionParts := sVersion.Split( [ '.' ] );
              BestParts := sBestVersion.Split( [ '.' ] );
              lIsBetter := False;

              for var i := 0 to Max( High( VersionParts ), High( BestParts ) ) do
              begin
                var iNew := 0;
                var iOld := 0;

                if i <= High( VersionParts ) then
                  iNew := StrToIntDef( VersionParts[ i ], 0 );

                if i <= High( BestParts ) then
                  iOld := StrToIntDef( BestParts[ i ], 0 );

                if iNew > iOld then
                begin
                  lIsBetter := True;
                  Break;
                end
                else if iNew < iOld then
                  Break;
              end;

              if lIsBetter then
                sBestVersion := sVersion;
            end;
          end;
        end;
      end;
    end;
  end;

  Result := sBestVersion;

  // Remember this result, keyed by path, stamped with the newest .dproj mtime
  // we just saw. Next call can skip the scan unless a .dproj gets touched.
  FReposLock.Enter;

  try
    FVersionCache.AddOrSetValue( sKey, sBestVersion );
    FVersionCacheStamp.AddOrSetValue( sKey, NewestDprojWrite );
  finally
    FReposLock.Leave;
  end;

end;

function TGitRepoManager.IsBuildArtifact( const sFileName: string ): Boolean;
var
  sLower            : string;
  sExt              : string;
begin

  Result := False;
  sLower := sFileName.ToLower.Replace( '\', '/' );

  // Check by extension
  sExt := ExtractFileExt( sLower );

  if ( sExt = '.dcu' ) or ( sExt = '.exe' ) or ( sExt = '.dll' ) or
     ( sExt = '.bpl' ) or ( sExt = '.dcp' ) or ( sExt = '.dres' ) or
     ( sExt = '.local' ) or ( sExt = '.identcache' ) or
     ( sExt = '.dsk' ) or ( sExt = '.tds' ) or ( sExt = '.map' ) or
     ( sExt = '.drc' ) or ( sExt = '.rsm' ) or ( sExt = '.obj' ) or
     ( sExt = '.o' ) or ( sExt = '.hpp' ) or ( sExt = '.projdata' ) or
     ( sExt = '.tvsconfig' ) then
  begin
    Result := True;
    Exit;
  end;

  // Check by directory path
  if sLower.Contains( '/win32/' ) or sLower.Contains( '/win64/' ) or
     sLower.Contains( '/__history/' ) or sLower.Contains( '/__recovery/' ) or
     sLower.Contains( '/debug/' ) or sLower.Contains( '/release/' ) or
     sLower.Contains( '/osx32/' ) or sLower.Contains( '/osx64/' ) or
     sLower.Contains( '/linux64/' ) or sLower.Contains( '/android/' ) or
     sLower.Contains( '/iosdevice' ) then
  begin
    Result := True;
    Exit;
  end;

  // Check for files starting with these directories
  if sLower.StartsWith( 'win32/' ) or sLower.StartsWith( 'win64/' ) or
     sLower.StartsWith( '__history/' ) or sLower.StartsWith( '__recovery/' ) or
     sLower.StartsWith( 'debug/' ) or sLower.StartsWith( 'release/' ) or
     sLower.StartsWith( 'osx32/' ) or sLower.StartsWith( 'osx64/' ) or
     sLower.StartsWith( 'linux64/' ) or sLower.StartsWith( 'android/' ) or
     sLower.StartsWith( 'iosdevice' ) then
  begin
    Result := True;
    Exit;
  end;

end;

function TGitRepoManager.AllChangesAreBuildArtifacts( const sPorcelainOutput: string ): Boolean;
var
  Lines             : TArray<string>;
  sLine             : string;
  sFileName         : string;
begin

  Result := False;

  if Trim( sPorcelainOutput ).IsEmpty then
    Exit;

  Lines := sPorcelainOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );

  if Length( Lines ) = 0 then
    Exit;

  // Check each changed file
  for sLine in Lines do
  begin
    // Git porcelain format: XY filename (status code is first 2 chars, then space, then filename)
    if Length( sLine ) > 3 then
    begin
      sFileName := Copy( sLine, 4, MaxInt );

      // Handle renamed files (format: "R  old -> new")
      if sFileName.Contains( ' -> ' ) then
        sFileName := Copy( sFileName, Pos( ' -> ', sFileName ) + 4, MaxInt );

      sFileName := Trim( sFileName );

      // Remove quotes if present
      if sFileName.StartsWith( '"' ) and sFileName.EndsWith( '"' ) then
        sFileName := Copy( sFileName, 2, Length( sFileName ) - 2 );

      if ( not IsBuildArtifact( sFileName ) ) then
        Exit; // Found a non-build-artifact change
    end;
  end;

  // All changes are build artifacts
  Result := True;

end;

function TGitRepoManager.GetRepoProvider( const iIndex: Integer ): TRemoteProvider;
var
  sOriginURL        : string;
begin

  Result := rpNone;

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
    Exit;

  sOriginURL := GetRemoteOriginURL( FRepos[ iIndex ].Path );
  Result := DetectRemoteProvider( sOriginURL );

end;

function TGitRepoManager.SetRepositoryVisibility( const iIndex: Integer; const lPrivate: Boolean;
  out sError: string ): Boolean;
var
  sOriginURL        : string;
  Provider          : TRemoteProvider;
  sOwner, sRepo     : string;
  sRequestBody      : string;
  sResponse         : string;
  iStatusCode       : Integer;
begin

  Result := False;
  sError := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sError := 'Invalid repository index';
    Exit;
  end;

  sOriginURL := GetRemoteOriginURL( FRepos[ iIndex ].Path );
  Provider := DetectRemoteProvider( sOriginURL );

  if Provider = rpNone then
  begin
    sError := 'No remote origin configured';
    Exit;
  end;

  if Provider = rpOther then
  begin
    sError := 'Visibility change only supported for GitHub and Codeberg';
    Exit;
  end;

  if ( not ParseOwnerRepo( sOriginURL, sOwner, sRepo ) ) then
  begin
    sError := 'Could not parse owner/repository from origin URL';
    Exit;
  end;

  // Build JSON via TJSONObject so values are safely escaped.
  var JSONBody: TJSONObject := TJSONObject.Create;

  try
    JSONBody.AddPair( 'private', TJSONBool.Create( lPrivate ) );
    sRequestBody := JSONBody.ToJSON;
  finally
    JSONBody.Free;
  end;

  case Provider of
    rpCodeberg:
      begin
        if ( not HasCodebergCredentials ) then
        begin
          sError := 'Codeberg credentials not configured';
          Exit;
        end;

        if ( not ExecuteCodebergApiPatch( Format( '/repos/%s/%s', [ sOwner, sRepo ] ), sRequestBody, sResponse, iStatusCode ) ) then
        begin
          if iStatusCode = 404 then
            sError := 'Repository not found or no permission'
          else if iStatusCode = 401 then
            sError := 'Invalid Codeberg credentials'
          else
            sError := Format( 'Codeberg API error (%d): %s', [ iStatusCode, sResponse ] );

          Exit;
        end;

        Result := True;
      end;

    rpGitHub:
      begin
        if ( not HasGitHubCredentials ) then
        begin
          sError := 'GitHub credentials not configured';
          Exit;
        end;

        if ( not ExecuteGitHubApiPatch( Format( '/repos/%s/%s', [ sOwner, sRepo ] ), sRequestBody, sResponse, iStatusCode ) ) then
        begin
          if iStatusCode = 404 then
            sError := 'Repository not found or no permission'
          else if iStatusCode = 401 then
            sError := 'Invalid GitHub credentials'
          else
            sError := Format( 'GitHub API error (%d): %s', [ iStatusCode, sResponse ] );

          Exit;
        end;

        Result := True;
      end;
  end;

end;

function TGitRepoManager.HasGitHubCredentials: Boolean;
begin

  Result := ( not FGitHubUsername.Trim.IsEmpty ) and ( not FGitHubToken.Trim.IsEmpty );

end;

function TGitRepoManager.CreateGitHubRepository( const sName, sDescription: string; const lPrivate: Boolean;
  out sRemoteURL, sError: string ): Boolean;
begin

  Result := CreateRemoteRepository( rpGitHub, sName, sDescription, lPrivate, sRemoteURL, sError );

end;

function TGitRepoManager.CreateRemoteRepository( const Provider: TRemoteProvider;
  const sName, sDescription: string; const lPrivate: Boolean;
  out sRemoteURL, sError: string ): Boolean;
var
  JSONBody          : TJSONObject;
  sRequestBody      : string;
  sResponse         : string;
  iStatusCode       : Integer;
  JSONResponse      : TJSONObject;
  sHost             : string;
  sUser             : string;
  sProviderName     : string;
  lOK               : Boolean;
  iConflictCode     : Integer;
begin

  Result := False;
  sRemoteURL := '';
  sError := '';

  case Provider of
    rpCodeberg:
      begin
        sProviderName := 'Codeberg';
        sHost := 'codeberg.org';
        sUser := FCodebergUsername;
        iConflictCode := 409;

        if ( not HasCodebergCredentials ) then
        begin
          sError := 'Codeberg credentials not configured';
          Exit;
        end;
      end;

    rpGitHub:
      begin
        sProviderName := 'GitHub';
        sHost := 'github.com';
        sUser := FGitHubUsername;
        iConflictCode := 422;

        if ( not HasGitHubCredentials ) then
        begin
          sError := 'GitHub credentials not configured';
          Exit;
        end;
      end;
  else
    sError := 'Unsupported provider';
    Exit;
  end;

  // Build request JSON via TJSONObject — safely escapes quotes/newlines in name/description.
  JSONBody := TJSONObject.Create;

  try
    JSONBody.AddPair( 'name', sName );
    JSONBody.AddPair( 'description', sDescription );
    JSONBody.AddPair( 'private', TJSONBool.Create( lPrivate ) );
    JSONBody.AddPair( 'auto_init', TJSONBool.Create( False ) );
    sRequestBody := JSONBody.ToJSON;
  finally
    JSONBody.Free;
  end;

  if Provider = rpCodeberg then
    lOK := ExecuteCodebergApiPost( '/user/repos', sRequestBody, sResponse, iStatusCode )
  else
    lOK := ExecuteGitHubApiPost( '/user/repos', sRequestBody, sResponse, iStatusCode );

  if ( not lOK ) then
  begin
    if iStatusCode = iConflictCode then
      sError := Format( 'Repository already exists on %s', [ sProviderName ] )
    else if iStatusCode = 401 then
      sError := Format( 'Invalid %s credentials', [ sProviderName ] )
    else
      sError := Format( '%s API error (%d): %s', [ sProviderName, iStatusCode, sResponse ] );

    Exit;
  end;

  // Parse clone_url from the response. If anything goes wrong, fall back to a
  // constructed URL so that the caller has *something* — the actual repo was
  // created successfully on the server side.
  try
    JSONResponse := TJSONObject.ParseJSONValue( sResponse ) as TJSONObject;
  except
    JSONResponse := nil;
  end;

  if JSONResponse <> nil then
  begin
    try
      sRemoteURL := JSONResponse.GetValue<string>( 'clone_url', '' );
    finally
      JSONResponse.Free;
    end;
  end;

  if sRemoteURL.IsEmpty then
    sRemoteURL := Format( 'https://%s/%s/%s.git', [ sHost, sUser, sName ] );

  Result := True;

end;

function TGitRepoManager.InitializeRepository( const sPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;
  sLog := '';

  // Check if folder exists
  if ( not TDirectory.Exists( sPath ) ) then
  begin
    sLog := 'Folder does not exist: ' + sPath;
    Exit;
  end;

  // Check if already a git repository
  if TDirectory.Exists( TPath.Combine( sPath, '.git' ) ) then
  begin
    sLog := 'Folder is already a Git repository';
    Exit;
  end;

  // Initialize repository
  if ( not ExecuteGitCommand( sPath, 'init', sOutput ) ) then
  begin
    sLog := 'Failed to initialize repository: ' + Trim( sOutput );
    Exit;
  end;

  sLog := 'Initialized Git repository' + sLineBreak;

  // Rename default branch to main for consistency with modern Git defaults.
  // Older Git initialises to master — if the rename succeeds we log it, if it
  // fails we leave the branch name as-is (git 2.28+ already defaults to main
  // when init.defaultBranch is set).
  if ExecuteGitCommand( sPath, 'branch -M main', sOutput ) then
    sLog := sLog + 'Set default branch to main' + sLineBreak;

  Result := True;

end;

function TGitRepoManager.CreateCodebergRepository( const sName, sDescription: string; const lPrivate: Boolean;
  out sRemoteURL, sError: string ): Boolean;
begin

  Result := CreateRemoteRepository( rpCodeberg, sName, sDescription, lPrivate, sRemoteURL, sError );

end;

function TGitRepoManager.AddRemoteOrigin( const sRepoPath, sRemoteURL: string; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;
  sLog := '';

  if ( not ExecuteGitCommand( sRepoPath, Format( 'remote add origin "%s"', [ sRemoteURL ] ), sOutput ) ) then
  begin
    sLog := 'Failed to add remote origin: ' + Trim( sOutput );
    Exit;
  end;

  sLog := 'Added remote origin: ' + sRemoteURL + sLineBreak;
  Result := True;

end;

function TGitRepoManager.InitialCommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sTempFile         : string;
  sBranch           : string;
begin

  Result := False;
  sLog := '';

  // Stage all files
  if ( not ExecuteGitCommand( sRepoPath, 'add -A', sOutput ) ) then
  begin
    sLog := 'Failed to stage files: ' + Trim( sOutput );
    Exit;
  end;

  sLog := 'Staged all files' + sLineBreak;

  // Create temp file for commit message
  if ( not CreateCommitMessageFile( sMessage, sTempFile ) ) then
  begin
    sLog := sLog + 'Failed to create commit message file';
    Exit;
  end;

  try
    // Commit
    if ( not ExecuteGitCommand( sRepoPath, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput ) ) then
    begin
      sLog := sLog + 'Commit failed: ' + Trim( sOutput );
      Exit;
    end;

    sLog := sLog + 'Created initial commit' + sLineBreak;
  finally
    if TFile.Exists( sTempFile ) then
    begin
      try
        TFile.Delete( sTempFile );
      except
        ;                               // Ignore cleanup errors
      end;
    end;
  end;

  // Detect the current branch name rather than assuming `main` — respects
  // init.defaultBranch settings and any prior rename.
  sBranch := GetCurrentBranch( sRepoPath );

  if sBranch.IsEmpty then
    sBranch := 'main';

  // Push with upstream tracking
  if ( not ExecuteGitCommand( sRepoPath, Format( 'push -u origin %s', [ sBranch ] ), sOutput ) ) then
  begin
    sLog := sLog + 'Push failed: ' + Trim( sOutput );
    Exit;
  end;

  sLog := sLog + Format( 'Pushed to origin/%s', [ sBranch ] ) + sLineBreak;
  Result := True;

end;

function TGitRepoManager.PullRepository( const iIndex: Integer; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  // Fast-forward only — refuse to create surprise merge commits when local
  // history has diverged. If it fails, the user should explicitly reconcile.
  if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'pull --ff-only', sOutput ) ) then
  begin
    sLog := 'Pull failed: ' + Trim( sOutput );
    Exit;
  end;

  sLog := Trim( sOutput );
  Result := True;

end;

function TGitRepoManager.ResolveConflictsKeepLocal( const iIndex: Integer; out sLog: string ): Boolean;
var
  sOutput           : string;
  sRepoPath         : string;
begin

  Result := False;
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  sRepoPath := FRepos[ iIndex ].Path;
  sLog := Format( '=== %s ===%s', [ FRepos[ iIndex ].Name, sLineBreak ] );

  // Checkout all conflicted files using our (local) version
  if ( not ExecuteGitCommand( sRepoPath, 'checkout --ours .', sOutput ) ) then
  begin
    sLog := sLog + 'Failed to checkout local versions: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Checked out local versions' + sLineBreak;

  // Stage all files
  if ( not ExecuteGitCommand( sRepoPath, 'add .', sOutput ) ) then
  begin
    sLog := sLog + 'Failed to stage files: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Staged all files' + sLineBreak;

  // Commit the merge resolution - may fail if nothing to commit (which is OK)
  if ( not ExecuteGitCommand( sRepoPath, 'commit -m "Resolved merge conflicts - kept local version"', sOutput ) ) then
  begin
    // Check if it's just "nothing to commit" - that's actually success
    if sOutput.Contains( 'nothing to commit' ) then
    begin
      sLog := sLog + 'Already clean - no conflicts to resolve' + sLineBreak;
      Result := True;
      Exit;
    end;

    sLog := sLog + 'Failed to commit: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Committed merge resolution' + sLineBreak;

  // Push
  if ( not ExecuteGitCommand( sRepoPath, 'push', sOutput ) ) then
  begin
    sLog := sLog + 'Push failed: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Pushed successfully' + sLineBreak;
  Result := True;

end;

function TGitRepoManager.PushRepository( const iIndex: Integer; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'push', sOutput ) ) then
  begin
    sLog := 'Push failed: ' + Trim( sOutput );
    Exit;
  end;

  sLog := Trim( sOutput );

  if sLog.IsEmpty then
    sLog := 'Pushed successfully';

  Result := True;

end;

function TGitRepoManager.ForcePushRepository( const iIndex: Integer; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'push --force', sOutput ) ) then
  begin
    sLog := 'Force push failed: ' + Trim( sOutput );
    Exit;
  end;

  sLog := Trim( sOutput );

  if sLog.IsEmpty then
    sLog := 'Force pushed successfully';

  Result := True;

end;

function TGitRepoManager.CreateBackupBranch( const iIndex: Integer; out sBranchName: string; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;
  sBranchName := '';
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  // Create a timestamped backup branch name — millisecond precision so two
  // backups within the same second don't collide ( "branch already exists" ).
  sBranchName := 'backup-' + FormatDateTime( 'yyyy-mm-dd-hhnnss-zzz', Now );

  if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'branch ' + sBranchName, sOutput ) ) then
  begin
    sLog := 'Failed to create backup branch: ' + Trim( sOutput );
    sBranchName := '';
    Exit;
  end;

  sLog := 'Created backup branch: ' + sBranchName;
  Result := True;

end;

function TGitRepoManager.GetIncomingChanges( const iIndex: Integer; out sChanges: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sRepoPath         : string;
  sBranch           : string;
begin

  Result := False;
  sChanges := '';
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  sRepoPath := FRepos[ iIndex ].Path;
  sBranch := FRepos[ iIndex ].Branch;

  // Fetch from remote first
  if ( not ExecuteGitCommand( sRepoPath, 'fetch', sOutput ) ) then
  begin
    sLog := 'Fetch failed: ' + Trim( sOutput );
    Exit;
  end;

  // Get diff stat between current HEAD and remote branch
  if ( not ExecuteGitCommand( sRepoPath, 'diff --stat HEAD..origin/' + sBranch, sOutput ) ) then
  begin
    // May fail if no remote tracking branch - that's OK, no incoming changes
    sChanges := '';
    sLog := 'No remote tracking branch or no changes';
    Result := True;
    Exit;
  end;

  sChanges := Trim( sOutput );
  sLog := 'Fetched successfully';
  Result := True;

end;

function TGitRepoManager.MigrateRepository( const iIndex: Integer; const TargetProvider: TRemoteProvider;
  const sNewRepoName, sDescription: string; const lPrivate: Boolean;
  out sNewRemoteURL, sError, sLog: string ): Boolean;
var
  sRepoPath         : string;
  sCurrentOrigin    : string;
  CurrentProvider   : TRemoteProvider;
  sOutput           : string;
  sTargetName       : string;
  sOldRemoteName    : string;
  lOriginExisted    : Boolean;
begin

  Result := False;
  sNewRemoteURL := '';
  sError := '';
  sLog := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sError := 'Invalid repository index';
    Exit;
  end;

  if ( not ( TargetProvider in [ rpCodeberg, rpGitHub ] ) ) then
  begin
    sError := 'Target provider must be Codeberg or GitHub';
    Exit;
  end;

  sRepoPath := FRepos[ iIndex ].Path;

  // Preconditions: repo must have at least one commit, and working tree must
  // be clean — we're about to push --all, and a partial/dirty repo leaves us
  // with a newly-created target remote and a half-migrated local state.
  if ( not HasAnyCommit( sRepoPath ) ) then
  begin
    sError := 'Repository has no commits yet — create at least one commit before migrating';
    Exit;
  end;

  if ( not IsWorkingTreeClean( sRepoPath ) ) then
  begin
    sError := 'Working tree has uncommitted changes — commit or stash before migrating';
    Exit;
  end;

  // Step 1: Detect current remote
  sCurrentOrigin := GetRemoteOriginURL( sRepoPath );
  CurrentProvider := DetectRemoteProvider( sCurrentOrigin );
  lOriginExisted := ( not sCurrentOrigin.IsEmpty );

  if CurrentProvider = TargetProvider then
  begin
    sError := 'Repository is already hosted on the target provider';
    Exit;
  end;

  // Verify target-provider credentials
  case TargetProvider of
    rpCodeberg:
      begin
        sTargetName := 'Codeberg';

        if ( not HasCodebergCredentials ) then
        begin
          sError := 'Codeberg credentials not configured';
          Exit;
        end;
      end;

    rpGitHub:
      begin
        sTargetName := 'GitHub';

        if ( not HasGitHubCredentials ) then
        begin
          sError := 'GitHub credentials not configured';
          Exit;
        end;
      end;
  end;

  // Step 2: Create the repository on the target provider
  sLog := sLog + Format( 'Creating %s repository "%s"...', [ sTargetName, sNewRepoName ] ) + sLineBreak;

  case TargetProvider of
    rpCodeberg:
      if ( not CreateCodebergRepository( sNewRepoName, sDescription, lPrivate, sNewRemoteURL, sError ) ) then
      begin
        sLog := sLog + 'Failed: ' + sError + sLineBreak;
        Exit;
      end;

    rpGitHub:
      if ( not CreateGitHubRepository( sNewRepoName, sDescription, lPrivate, sNewRemoteURL, sError ) ) then
      begin
        sLog := sLog + 'Failed: ' + sError + sLineBreak;
        Exit;
      end;
  end;

  sLog := sLog + 'Created target repository: ' + sNewRemoteURL + sLineBreak;

  // Step 3: Preserve the old origin under a provider-named alias, then swap
  if lOriginExisted then
  begin
    case CurrentProvider of
      rpCodeberg: sOldRemoteName := 'codeberg';
      rpGitHub:   sOldRemoteName := 'github';
    else
      sOldRemoteName := 'old-origin';
    end;

    // Drop any stale remote using that alias (ignore failure — remote may not exist)
    ExecuteGitCommand( sRepoPath, Format( 'remote remove %s', [ sOldRemoteName ] ), sOutput );

    if ( not ExecuteGitCommand( sRepoPath, Format( 'remote rename origin %s', [ sOldRemoteName ] ), sOutput ) ) then
    begin
      sError := 'Failed to rename existing origin: ' + Trim( sOutput );
      sLog := sLog + sError + sLineBreak;
      Exit;
    end;

    sLog := sLog + Format( 'Preserved previous origin as "%s": %s', [ sOldRemoteName, sCurrentOrigin ] ) + sLineBreak;
  end;

  // Step 4: Point origin at the new remote
  if ( not ExecuteGitCommand( sRepoPath, Format( 'remote add origin "%s"', [ sNewRemoteURL ] ), sOutput ) ) then
  begin
    sError := 'Failed to add new origin: ' + Trim( sOutput );
    sLog := sLog + sError + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Added new origin: ' + sNewRemoteURL + sLineBreak;

  // Step 5: Push all branches (sets upstream tracking to the new origin)
  if ( not ExecuteGitCommand( sRepoPath, 'push -u origin --all', sOutput ) ) then
  begin
    sError := 'Failed to push branches: ' + Trim( sOutput );
    sLog := sLog + sError + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Pushed all branches to new origin' + sLineBreak;

  // Step 6: Push all tags — not fatal if it fails
  if ExecuteGitCommand( sRepoPath, 'push origin --tags', sOutput ) then
    sLog := sLog + 'Pushed all tags to new origin' + sLineBreak
  else
    sLog := sLog + 'Warning: tag push reported: ' + Trim( sOutput ) + sLineBreak;

  // Update cached provider on the repo record
  FRepos[ iIndex ].Provider := TargetProvider;

  Result := True;

end;

procedure TGitRepoManager.AddToCommitHistory( const sMessage: string );
var
  sTrimmed          : string;
  iNewLen           : Integer;
begin

  sTrimmed := Trim( sMessage );

  if sTrimmed.IsEmpty then
    Exit;

  // Check if already at top of history
  if ( Length( FCommitHistory ) > 0 ) and SameText( FCommitHistory[ 0 ], sTrimmed ) then
    Exit;

  // Remove if already exists elsewhere in history
  for var i := High( FCommitHistory ) downto 0 do
  begin
    if SameText( FCommitHistory[ i ], sTrimmed ) then
    begin
      for var j := i to High( FCommitHistory ) - 1 do
        FCommitHistory[ j ] := FCommitHistory[ j + 1 ];

      SetLength( FCommitHistory, Length( FCommitHistory ) - 1 );
      Break;
    end;
  end;

  // Add to front
  iNewLen := Length( FCommitHistory ) + 1;

  if iNewLen > MAX_HISTORY_ITEMS then
    iNewLen := MAX_HISTORY_ITEMS;

  SetLength( FCommitHistory, iNewLen );

  // Shift existing items
  for var i := High( FCommitHistory ) downto 1 do
    FCommitHistory[ i ] := FCommitHistory[ i - 1 ];

  FCommitHistory[ 0 ] := sTrimmed;

  SaveConfig;

end;

procedure TGitRepoManager.AddTemplate( const sTemplate: string );
var
  sTrimmed          : string;
  iLen              : Integer;
begin

  sTrimmed := Trim( sTemplate );

  if sTrimmed.IsEmpty then
    Exit;

  iLen := Length( FCommitTemplates );
  SetLength( FCommitTemplates, iLen + 1 );
  FCommitTemplates[ iLen ] := sTrimmed;

  SaveConfig;

end;

procedure TGitRepoManager.RemoveTemplate( const iIndex: Integer );
begin

  if ( iIndex < 0 ) or ( iIndex > High( FCommitTemplates ) ) then
    Exit;

  for var i := iIndex to High( FCommitTemplates ) - 1 do
    FCommitTemplates[ i ] := FCommitTemplates[ i + 1 ];

  SetLength( FCommitTemplates, Length( FCommitTemplates ) - 1 );

  SaveConfig;

end;

procedure TGitRepoManager.UpdateTemplate( const iIndex: Integer; const sTemplate: string );
begin

  if ( iIndex < 0 ) or ( iIndex > High( FCommitTemplates ) ) then
    Exit;

  FCommitTemplates[ iIndex ] := Trim( sTemplate );

  SaveConfig;

end;

function TGitRepoManager.GetAllGroups: TArray<string>;
var
  Groups            : TList<string>;
  sGroup            : string;
begin

  Groups := TList<string>.Create;

  try
    for var i := 0 to High( FRepos ) do
    begin
      sGroup := Trim( FRepos[ i ].Group );

      if ( not sGroup.IsEmpty ) and ( not Groups.Contains( sGroup ) ) then
        Groups.Add( sGroup );
    end;

    Groups.Sort;
    Result := Groups.ToArray;
  finally
    Groups.Free;
  end;

end;

procedure TGitRepoManager.SetRepoGroup( const iIndex: Integer; const sGroup: string );
begin

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
    Exit;

  FRepos[ iIndex ].Group := Trim( sGroup );

  SaveConfig;

end;

procedure TGitRepoManager.RefreshAllStatusParallel;
var
  iCount            : Integer;
  Paths             : TArray<string>;
begin

  // Snapshot the repo paths under the lock so the parallel loop works against
  // a stable array even if the live FRepos is mutated by add/remove calls.
  FReposLock.Enter;

  try
    iCount := Length( FRepos );

    if iCount = 0 then
      Exit;

    SetLength( Paths, iCount );

    for var i := 0 to iCount - 1 do
      Paths[ i ] := FRepos[ i ].Path;
  finally
    FReposLock.Leave;
  end;

  TParallel.For( 0, iCount - 1,
    procedure( AIndex: Integer )
    var
      sPath             : string;
      sBranch           : string;
      Status            : TRepoStatus;
      iTracked          : Integer;
      iModified         : Integer;
      Provider          : TRemoteProvider;
      sVersion          : string;
    begin
      sPath := Paths[ AIndex ];

      sBranch := GetRepoBranch( sPath );
      Status := GetRepoStatus( sPath );
      iTracked := GetTrackedFileCount( sPath );
      iModified := GetModifiedFileCount( sPath );
      Provider := DetectRemoteProvider( GetRemoteOriginURL( sPath ) );
      sVersion := GetProjectVersion( sPath );

      // Write back under the lock — and re-locate by path, since the array may
      // have shifted (remove / reorder) while we worked.
      FReposLock.Enter;

      try
        for var j := 0 to High( FRepos ) do
        begin
          if SameText( FRepos[ j ].Path, sPath ) then
          begin
            FRepos[ j ].Branch := sBranch;
            FRepos[ j ].Status := Status;
            FRepos[ j ].StatusText := RepoStatusToString( Status );
            FRepos[ j ].TrackedFileCount := iTracked;
            FRepos[ j ].ModifiedFileCount := iModified;
            FRepos[ j ].Provider := Provider;
            FRepos[ j ].Version := sVersion;
            Break;
          end;
        end;
      finally
        FReposLock.Leave;
      end;
    end );

end;

end.

