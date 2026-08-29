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
  System.Net.URLClient, System.NetEncoding, System.Threading, System.SyncObjs, System.Math,
  System.DateUtils, System.RegularExpressions;

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
  /// <summary>
  ///   Working-state of a repository, in the order the UI ranks them.
  /// </summary>
  /// <remarks>
  ///   <c>rsConflicted</c> and <c>rsPushRequired</c>/<c>rsDiverged</c> close two
  ///   real gaps. A repository with unmerged paths used to report as ordinary
  ///   <c>rsModified</c>, so Commit &amp; Push would `git add -A` the conflict
  ///   markers and push them; and a repository whose work was committed but not
  ///   pushed reported as <c>rsClean</c>, so nothing in the UI said the remote
  ///   was out of date.
  /// </remarks>
  TRepoStatus = ( rsClean, rsModified, rsConflicted, rsPullRequired, rsPushRequired,
    rsDiverged, rsError, rsUnknown );

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
    FVersionScanStamp: TDictionary<string, TDateTime>;
    /// <summary>
    ///   Set once <see cref="LoadConfig"/> has completed without error. Until
    ///   then <see cref="SaveConfig"/> refuses to persist an empty repository
    ///   list, so a failed load can never silently erase the user's repos.
    /// </summary>
    FConfigLoaded: Boolean;
    const
      MAX_HISTORY_ITEMS = 20;

      /// <summary>
      ///   How long a repository's .dproj tree scan is reused before the
      ///   directory is walked again. The modification-time check remains the
      ///   authority once this elapses; this only suppresses repeated full
      ///   recursive walks within a single refresh burst.
      /// </summary>
      VERSION_SCAN_TTL_SECONDS = 30;

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
    ///   Gets the current branch name for a repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>The branch name, or '(unknown)' when it cannot be determined.</returns>
    function GetRepoBranch( const sRepoPath: string ): string;

    /// <summary>
    ///   Fetches from the remote and reports how far the current branch is
    ///   ahead of, and behind, its upstream.
    /// </summary>
    /// <remarks>
    ///   One `rev-list --left-right --count` answers both questions, and does
    ///   so without parsing human-readable, localisable text. Both counts come
    ///   back zero when the branch has no upstream, which is the correct
    ///   "nothing to say" answer rather than an error.
    /// </remarks>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <param name="iAhead">Commits on the local branch that the upstream lacks.</param>
    /// <param name="iBehind">Commits on the upstream that the local branch lacks.</param>
    procedure GetAheadBehind( const sRepoPath: string; out iAhead, iBehind: Integer );

    /// <summary>
    ///   Returns True if `git status --porcelain` output contains an unmerged
    ///   ( conflicted ) path.
    /// </summary>
    /// <remarks>
    ///   Porcelain v1 marks these with the XY pairs DD, AU, UD, UA, DU, AA and
    ///   UU. Treating them as ordinary modifications is dangerous: staging with
    ///   `add -A` and committing writes the conflict markers into history.
    /// </remarks>
    /// <param name="sPorcelainOutput">Output from 'git status --porcelain'.</param>
    /// <returns>True if any line marks an unmerged path.</returns>
    function HasUnmergedPaths( const sPorcelainOutput: string ): Boolean;

    /// <summary>
    ///   Returns True if the repository has a merge, rebase, cherry-pick,
    ///   revert or bisect part-way through.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>True if a merge, rebase, cherry-pick, revert or bisect is unfinished.</returns>
    function HasOperationInProgress( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Gets the number of files tracked by Git in the repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>Number of files tracked by Git, or 0 on failure.</returns>
    function GetTrackedFileCount( const sRepoPath: string ): Integer;

    /// <summary>
    ///   Returns the path to the configuration file.
    /// </summary>
    /// <returns>Full path to repositories.json, falling back to the application
    /// directory when the home folder cannot be created.</returns>
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
    /// <returns>True when the response status is in the 2xx range.</returns>
    function ExecuteApiRequest( const sVerb, sBaseURL, sEndpoint, sBody: string;
      const aHeaders: TArray<TNameValuePair>; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP POST request to the Codeberg API.
    /// </summary>
    /// <returns>True when the response status is in the 2xx range.</returns>
    function ExecuteCodebergApiPost( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP POST request to the GitHub API.
    /// </summary>
    /// <returns>True when the response status is in the 2xx range.</returns>
    function ExecuteGitHubApiPost( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP PATCH request to the Codeberg API.
    /// </summary>
    /// <returns>True when the response status is in the 2xx range.</returns>
    function ExecuteCodebergApiPatch( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP PATCH request to the GitHub API.
    /// </summary>
    /// <returns>True when the response status is in the 2xx range.</returns>
    function ExecuteGitHubApiPatch( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Gets the remote origin URL for a repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>The origin URL, or an empty string when there is no origin.</returns>
    function GetRemoteOriginURL( const sRepoPath: string ): string;

    /// <summary>
    ///   Detects the remote provider from an origin URL.
    /// </summary>
    /// <param name="sOriginURL">The remote origin URL.</param>
    /// <returns>The provider the URL points at, or rpNone when it is empty.</returns>
    function DetectRemoteProvider( const sOriginURL: string ): TRemoteProvider;

    /// <summary>
    ///   Parses owner and repository name from an origin URL.
    /// </summary>
    /// <param name="sOriginURL">The remote origin URL, HTTPS or SSH form.</param>
    /// <param name="sOwner">Receives the owner (user or organisation) segment.</param>
    /// <param name="sRepo">Receives the repository name, without any .git suffix.</param>
    /// <returns>True when both parts were parsed.</returns>
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
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>The branch name, or an empty string when detached or unborn.</returns>
    function GetCurrentBranch( const sRepoPath: string ): string;

    /// <summary>
    ///   Returns True if the repository has at least one commit ( HEAD resolves ).
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>True if HEAD resolves to a commit.</returns>
    function HasAnyCommit( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Returns True if the working tree is clean ( git status --porcelain is empty ).
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>True if git status --porcelain produced no output.</returns>
    function IsWorkingTreeClean( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Configures a TNetHTTPClient with User-Agent and timeouts.
    /// </summary>
    /// <param name="AClient">The client to configure.</param>
    procedure ConfigureHttpClient( const AClient: TNetHTTPClient );

    /// <summary>
    ///   Creates a repository on the given provider ( rpCodeberg or rpGitHub ).
    ///   Body is built with TJSONObject so name/description are safely escaped.
    /// </summary>
    /// <returns>True if the repository was created on the provider.</returns>
    function CreateRemoteRepository( const Provider: TRemoteProvider;
      const sName, sDescription: string; const lPrivate: Boolean;
      out sRemoteURL, sError: string ): Boolean;
  public
    /// <summary>
    ///   Creates the manager, resolves the configuration file path and prepares the
    ///   repository lock and version caches.
    /// </summary>
    constructor Create;
    /// <summary>
    ///   Releases the repository lock and version caches.
    /// </summary>
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
    /// <returns>True if both a Codeberg username and token are set.</returns>
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
    /// <returns>True if both a GitHub username and token are set.</returns>
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
    /// <param name="sMessage">Message to promote to the head of the history.</param>
    procedure AddToCommitHistory( const sMessage: string );

    /// <summary>
    ///   Adds a commit message template.
    /// </summary>
    /// <param name="sTemplate">Template text to append; blank text is ignored.</param>
    procedure AddTemplate( const sTemplate: string );

    /// <summary>
    ///   Removes a commit message template by index.
    /// </summary>
    /// <param name="iIndex">Index of the template to remove.</param>
    procedure RemoveTemplate( const iIndex: Integer );

    /// <summary>
    ///   Updates a commit message template.
    /// </summary>
    /// <param name="iIndex">Index of the template to replace.</param>
    /// <param name="sTemplate">Replacement template text.</param>
    procedure UpdateTemplate( const iIndex: Integer; const sTemplate: string );

    /// <summary>
    ///   Returns all unique group names from repositories.
    /// </summary>
    /// <returns>Every distinct non-empty group name, sorted.</returns>
    function GetAllGroups: TArray<string>;

    /// <summary>
    ///   Sets the group for a repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sGroup">Group name, or an empty string to clear it.</param>
    procedure SetRepoGroup( const iIndex: Integer; const sGroup: string );

    /// <summary>
    ///   Refreshes all repository statuses in parallel, safely against
    ///   concurrent add/remove: the paths are snapshotted under the lock and
    ///   each result is written back by matching on path, never by index.
    /// </summary>
    /// <param name="AOnRepoDone">
    ///   Optional progress callback, invoked on a WORKER thread with the name
    ///   of each repository as it completes. Marshal to the UI thread yourself.
    /// </param>
    /// <param name="AIsCancelled">
    ///   Optional cancellation probe, polled before and after each repository's
    ///   Git work. Returning True abandons the remaining work for that item.
    /// </param>
    procedure RefreshAllStatusParallel( const AOnRepoDone: TProc<string> = nil;
      const AIsCancelled: TFunc<Boolean> = nil );

    /// <summary>
    ///   Returns True if sPattern is a safe file-add pattern ( no shell metacharacters ).
    ///   Accepts comma- or space-separated globs like "*.pas" or "src/*.pas docs/*.md".
    /// </summary>
    /// <param name="sPattern">The pattern to validate.</param>
    /// <returns>True if the pattern contains only glob and path characters.</returns>
    class function IsSafeFilePattern( const sPattern: string ): Boolean; static;

    /// <summary>
    ///   Returns a snapshot count of the repos array under the repos lock.
    /// </summary>
    /// <returns>The number of managed repositories.</returns>
    function ReposCount: Integer;

    /// <summary>
    ///   Returns a snapshot copy of a repo by index, or a default TRepoInfo if out of range.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="ARepo">Receives a copy of the repository record.</param>
    /// <returns>True if the index was in range and ARepo was filled.</returns>
    function GetRepoSnapshot( const iIndex: Integer; out ARepo: TRepoInfo ): Boolean;

    /// <summary>
    ///   Live repository array.
    /// </summary>
    /// <remarks>
    /// Read-only by convention and intended for main-thread UI reads. It is NOT
    /// synchronised - use <see cref="GetRepoSnapshot"/> and
    /// <see cref="ReposCount"/> from any other thread.
    /// </remarks>
    property Repos: TRepoInfoArray read FRepos;
    /// <summary>
    ///   Full path to the JSON configuration file backing this manager.
    /// </summary>
    property ConfigPath: string read FConfigPath;
    /// <summary>
    ///   Codeberg account name used for repository creation and visibility changes.
    /// </summary>
    property CodebergUsername: string read FCodebergUsername write FCodebergUsername;
    /// <summary>
    ///   Codeberg personal access token, in clear text in memory and DPAPI-encrypted
    ///   at rest.
    /// </summary>
    property CodebergToken: string read FCodebergToken write FCodebergToken;
    /// <summary>
    ///   GitHub account name used for repository creation and visibility changes.
    /// </summary>
    property GitHubUsername: string read FGitHubUsername write FGitHubUsername;
    /// <summary>
    ///   GitHub personal access token, in clear text in memory and DPAPI-encrypted
    ///   at rest.
    /// </summary>
    property GitHubToken: string read FGitHubToken write FGitHubToken;
    /// <summary>
    ///   Path to an external Git client. Used to open a repository externally, and,
    ///   when it points at git.exe itself, to run this application's own Git calls.
    /// </summary>
    property GitClientPath: string read FGitClientPath write FGitClientPath;
    /// <summary>
    ///   Optional glob restricting what Commit & Push stages; empty means stage all.
    ///   Validated by <see cref="IsSafeFilePattern"/> on both entry and load.
    /// </summary>
    property FilePattern: string read FFilePattern write FFilePattern;
    /// <summary>
    ///   Path to delphi-indexer.exe, used to reindex a repository after a successful
    ///   push. Empty means fall back to PATH and then the default location.
    /// </summary>
    property DelphiIndexerPath: string read FDelphiIndexerPath write FDelphiIndexerPath;
    /// <summary>
    ///   Most-recently-used commit messages, newest first.
    /// </summary>
    property CommitHistory: TArray<string> read FCommitHistory;
    /// <summary>
    ///   User-defined reusable commit messages.
    /// </summary>
    property CommitTemplates: TArray<string> read FCommitTemplates write FCommitTemplates;
  end;

/// <summary>
///   Converts a repository status to a human-readable string.
/// </summary>
/// <param name="Status">The status to describe.</param>
/// <returns>A short human-readable label.</returns>
function RepoStatusToString( const Status: TRepoStatus ): string;

/// <summary>
///   Converts a remote provider to a human-readable string.
/// </summary>
/// <param name="Provider">The provider to describe.</param>
/// <returns>A short human-readable label.</returns>
function RemoteProviderToString( const Provider: TRemoteProvider ): string;

/// <summary>
///   Sanitises a string into a repository name accepted by Codeberg/GitHub:
///   drops whitespace (so a "Title Case" folder becomes "TitleCase"), replaces
///   any other character outside [A-Za-z0-9._-] with '-', collapses runs of
///   '-', and trims leading/trailing separators. Applied to the folder-derived
///   default so a folder name with spaces no longer produces a rejected name.
/// </summary>
/// <param name="AName">The raw name, typically a folder name.</param>
/// <returns>A host-safe repo name; 'repo' when nothing usable remains.</returns>
function SanitizeRepoName( const AName: string ): string;

/// <summary>
///   Launches a child process with its stdout and stderr captured, waits for it
///   to exit ( or for the timeout to elapse ) and returns the captured output.
/// </summary>
/// <remarks>
///   The command line is passed to <c>CreateProcess</c> with a nil
///   <c>lpApplicationName</c>, so <c>cmd.exe</c> is never involved and shell
///   metacharacters in the command line cannot be interpreted.
///   Output is accumulated as RAW BYTES and decoded ONCE on completion — a
///   multi-byte UTF-8 character split across two pipe reads would otherwise be
///   an invalid sequence, and <c>TEncoding.UTF8</c> is built with
///   <c>MB_ERR_INVALID_CHARS</c>, so decoding a partial sequence RAISES
///   <c>EEncodingError</c> rather than substituting a replacement character.
///   Decoding uses a lenient UTF-8 encoding so that output which is not valid
///   UTF-8 at all ( a child writing in the console code page ) degrades to
///   replacement characters instead of throwing.
/// </remarks>
/// <param name="sCommandLine">Full command line, including the executable.</param>
/// <param name="sWorkingDir">Working directory; pass '' to inherit the parent's.</param>
/// <param name="sOutput">Receives the combined stdout/stderr text.</param>
/// <param name="iTimeout">Timeout in milliseconds.</param>
/// <returns>True if the process ran to completion and exited with code 0.</returns>
function RunProcessCaptureOutput( const sCommandLine, sWorkingDir: string; out sOutput: string;
  const iTimeout: Cardinal ): Boolean;

/// <summary>
///   Decodes a byte buffer as UTF-8 without raising on malformed input.
///   Invalid sequences become U+FFFD rather than an <c>EEncodingError</c>.
/// </summary>
/// <param name="ABytes">Buffer holding the bytes to decode.</param>
/// <param name="iCount">Number of bytes in the buffer to decode.</param>
/// <returns>The decoded text; invalid sequences become U+FFFD.</returns>
function DecodeUtf8Lenient( const ABytes: TBytes; const iCount: Integer ): string;

/// <summary>
///   Masks anything that looks like a credential in text destined for the log:
///   the userinfo section of a URL ( <c>https://user:token@host</c> ) and bare
///   provider access-token literals. Applied to every line the application logs,
///   because Git echoes the remote URL verbatim in most push/fetch errors.
/// </summary>
/// <param name="AText">The text about to be logged.</param>
/// <returns>The same text with any credential-looking run masked.</returns>
function RedactSecrets( const AText: string ): string;

implementation

type
  /// <summary>
  ///   DPAPI buffer descriptor ( <c>crypt32.dll</c> ). Declared locally because
  ///   the RTL does not surface the Data Protection API.
  /// </summary>
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDataBlob = ^TDataBlob;

function CryptProtectData( pDataIn: PDataBlob; szDataDescr: PWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: DWORD; pDataOut: PDataBlob ): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';

function CryptUnprotectData( pDataIn: PDataBlob; ppszDataDescr: PPWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: DWORD; pDataOut: PDataBlob ): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';

const
  /// <summary>
  ///   Marker prefixed to a DPAPI-protected value in the config file, so a
  ///   plain-text token written by an older build is still recognised and can
  ///   be migrated transparently on first load.
  /// </summary>
  SECRET_PREFIX     = 'dpapi:';

  /// <summary>
  ///   Pipe read-buffer size. Output is accumulated as raw bytes, so this is a
  ///   throughput knob only — it has no bearing on character decoding.
  /// </summary>
  PIPE_BUFFER_SIZE  = 16384;

function DecodeUtf8Lenient( const ABytes: TBytes; const iCount: Integer ): string;
var
  Encoding          : TEncoding;
begin

  Result := '';

  if ( iCount <= 0 ) or ( Length( ABytes ) = 0 ) then
    Exit;

  // TEncoding.UTF8 is constructed with MB_ERR_INVALID_CHARS and therefore
  // RAISES on malformed input. TMBCSEncoding.Create( CP_UTF8 ) passes flag 0,
  // so MultiByteToWideChar substitutes U+FFFD instead of failing.
  Encoding := TMBCSEncoding.Create( CP_UTF8 );

  try
    Result := Encoding.GetString( ABytes, 0, Min( iCount, Length( ABytes ) ) );
  except
    on E: Exception do
      Result := '';                     // Never let log decoding abort an operation
  end;

  Encoding.Free;

end;

/// <summary>
///   Returns a Unicode environment block: everything this process inherited,
///   with the supplied <c>NAME=VALUE</c> entries replacing any same-named
///   entry. Entries are sorted case-insensitively, as CreateProcess expects,
///   and the result is double-null terminated.
/// </summary>
function BuildChildEnvironment( const AOverrides: TArray<string> ): string;
var
  pEnv              : PChar;
  pCursor           : PChar;
  Entries           : TStringList;
  sEntry            : string;
  sName             : string;
begin

  Entries := TStringList.Create;

  try
    Entries.CaseSensitive := False;

    pEnv := GetEnvironmentStrings;

    if pEnv <> nil then
    begin
      try
        pCursor := pEnv;

        while pCursor^ <> #0 do
        begin
          sEntry := string( pCursor );

          // Skip the "=C:=C:\..." per-drive current-directory pseudo-entries:
          // they start with '=' and have no ordinary name.
          if ( not sEntry.StartsWith( '=' ) ) and sEntry.Contains( '=' ) then
            Entries.Add( sEntry );

          Inc( pCursor, Length( sEntry ) + 1 );
        end;
      finally
        FreeEnvironmentStrings( pEnv );
      end;
    end;

    // Apply the overrides, replacing any existing entry of the same name.
    for var sOverride in AOverrides do
    begin
      sName := sOverride.Substring( 0, sOverride.IndexOf( '=' ) );

      for var i := Entries.Count - 1 downto 0 do
      begin
        if SameText( Entries[ i ].Substring( 0, Entries[ i ].IndexOf( '=' ) ), sName ) then
          Entries.Delete( i );
      end;

      Entries.Add( sOverride );
    end;

    Entries.Sort;

    Result := '';

    for var i := 0 to Entries.Count - 1 do
      Result := Result + Entries[ i ] + #0;

    Result := Result + #0;
  finally
    Entries.Free;
  end;

end;

function RunProcessCaptureOutput( const sCommandLine, sWorkingDir: string; out sOutput: string;
  const iTimeout: Cardinal ): Boolean;
var
  StartupInfo       : TStartupInfo;
  ProcessInfo       : TProcessInformation;
  SecurityAttr      : TSecurityAttributes;
  hReadPipe         : THandle;
  hWritePipe        : THandle;
  hNulIn            : THandle;
  Buffer            : TBytes;
  Accumulated       : TBytes;
  iAccumulated      : Integer;
  dwBytesRead       : DWORD;
  dwBytesAvail      : DWORD;
  dwWaitResult      : DWORD;
  dwExitCode        : DWORD;
  lProcessStarted   : Boolean;
  lTimedOut         : Boolean;
  iRemainingTimeout : Int64;
  MutableCommand    : TArray<Char>;
  pWorkingDir       : PChar;
  sEnvironment      : string;
  EnvBlock          : TArray<Char>;

  /// <summary>
  ///   Drains everything currently queued in the pipe into the accumulator.
  /// </summary>
  procedure DrainPipe;
  begin

    while PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
    begin
      if ( not ReadFile( hReadPipe, Buffer[ 0 ], Length( Buffer ), dwBytesRead, nil ) ) or ( dwBytesRead = 0 ) then
        Break;

      if ( iAccumulated + Integer( dwBytesRead ) ) > Length( Accumulated ) then
        SetLength( Accumulated, Max( Length( Accumulated ) * 2, iAccumulated + Integer( dwBytesRead ) ) );

      Move( Buffer[ 0 ], Accumulated[ iAccumulated ], dwBytesRead );
      Inc( iAccumulated, Integer( dwBytesRead ) );
    end;

  end;

begin

  Result := False;
  sOutput := '';

  hReadPipe := 0;
  hWritePipe := 0;
  hNulIn := INVALID_HANDLE_VALUE;
  lProcessStarted := False;
  lTimedOut := False;
  iAccumulated := 0;

  ZeroMemory( @ProcessInfo, SizeOf( TProcessInformation ) );

  SecurityAttr.nLength := SizeOf( TSecurityAttributes );
  SecurityAttr.bInheritHandle := True;
  SecurityAttr.lpSecurityDescriptor := nil;

  if ( not CreatePipe( hReadPipe, hWritePipe, @SecurityAttr, 0 ) ) then
    Exit;

  try
    // The read end must NOT be inherited: the child has no business holding it,
    // and an inherited copy keeps the pipe alive past the child's exit.
    SetHandleInformation( hReadPipe, HANDLE_FLAG_INHERIT, 0 );

    // Give the child a real (empty) stdin. With STARTF_USESTDHANDLES set and
    // hStdInput left at 0, a child that tries to read stdin — Git asking for
    // credentials, for one — gets an invalid handle and can stall.
    hNulIn := CreateFile( 'NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,
      @SecurityAttr, OPEN_EXISTING, 0, 0 );

    ZeroMemory( @StartupInfo, SizeOf( TStartupInfo ) );
    StartupInfo.cb := SizeOf( TStartupInfo );
    StartupInfo.hStdInput := hNulIn;
    StartupInfo.hStdOutput := hWritePipe;
    StartupInfo.hStdError := hWritePipe;
    StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow := SW_HIDE;

    // CreateProcessW is documented to modify lpCommandLine in place, so it must
    // never be handed a pointer into a shared or literal string.
    MutableCommand := ( sCommandLine + #0 ).ToCharArray;

    if sWorkingDir.Trim.IsEmpty then
      pWorkingDir := nil
    else
      pWorkingDir := PChar( sWorkingDir );

    // Suppress every interactive credential path: a Windows-session GUI prompt
    // from Git Credential Manager would block a headless batch indefinitely.
    //
    // This INHERITS the parent environment and overrides only these names.
    // Handing the child a hand-built minimal block instead would silently drop
    // TEMP, PATHEXT, COMSPEC, ProgramData and any HTTP_PROXY/HTTPS_PROXY the
    // user relies on — none of which announce themselves when missing.
    sEnvironment := BuildChildEnvironment(
      [ 'GIT_TERMINAL_PROMPT=0',
        'GCM_INTERACTIVE=Never',
        'GIT_ASKPASS=',
        'SSH_ASKPASS=' ] );
    EnvBlock := sEnvironment.ToCharArray;

    lProcessStarted := CreateProcess(
      nil,
      PChar( @MutableCommand[ 0 ] ),
      nil,
      nil,
      True,
      CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT,
      @EnvBlock[ 0 ],
      pWorkingDir,
      StartupInfo,
      ProcessInfo
      );

    if ( not lProcessStarted ) then
      Exit;

    // Release the parent's copy of the write end, or the read end never sees EOF.
    CloseHandle( hWritePipe );
    hWritePipe := 0;

    SetLength( Buffer, PIPE_BUFFER_SIZE );
    SetLength( Accumulated, PIPE_BUFFER_SIZE );
    iRemainingTimeout := iTimeout;

    repeat
      dwWaitResult := WaitForSingleObject( ProcessInfo.hProcess, 100 );
      DrainPipe;

      if dwWaitResult = WAIT_OBJECT_0 then
        Break;

      // WAIT_FAILED and WAIT_ABANDONED satisfy neither the old loop's exit test
      // nor its timeout decrement, which made this an unbounded spin. Every
      // non-signalled result now counts against the timeout.
      Dec( iRemainingTimeout, 100 );

      if iRemainingTimeout <= 0 then
      begin
        TerminateProcess( ProcessInfo.hProcess, 1 );
        WaitForSingleObject( ProcessInfo.hProcess, 5000 );
        DrainPipe;
        lTimedOut := True;
        Exit;
      end;
    until False;

    DrainPipe;                          // Anything written between the last poll and exit

    if GetExitCodeProcess( ProcessInfo.hProcess, dwExitCode ) then
      Result := ( dwExitCode = 0 );
  finally
    sOutput := DecodeUtf8Lenient( Accumulated, iAccumulated );

    if lTimedOut then
      sOutput := sOutput.TrimRight + sLineBreak + 'Operation timed out';

    if lProcessStarted then
    begin
      CloseHandle( ProcessInfo.hProcess );
      CloseHandle( ProcessInfo.hThread );
    end;

    if hNulIn <> INVALID_HANDLE_VALUE then
      CloseHandle( hNulIn );

    if hWritePipe <> 0 then
      CloseHandle( hWritePipe );

    if hReadPipe <> 0 then
      CloseHandle( hReadPipe );
  end;

end;

function RedactSecrets( const AText: string ): string;
begin

  Result := AText;

  if Result.IsEmpty then
    Exit;

  try
    // https://user:token@host  ->  https://***:***@host
    Result := TRegEx.Replace( Result, '(?i)(https?://)[^/\s:@]+:[^/\s@]+@', '$1***:***@' );

    // https://<long opaque userinfo>@host  ->  https://***@host
    //
    // The threshold is deliberately high: a Codeberg PAT is 40 characters and
    // a GitHub one longer still, whereas 'https://GITLAK@codeberg.org/...'
    // carries no secret and the owner name is worth keeping in the log.
    Result := TRegEx.Replace( Result, '(?i)(https?://)[A-Za-z0-9_-]{24,}@', '$1***@' );

    // Bare provider token literals (GitHub classic/fine-grained, Gitea/Forgejo).
    Result := TRegEx.Replace( Result, '(gh[pousr]_)[A-Za-z0-9]{16,}', '$1***' );
    Result := TRegEx.Replace( Result, '(github_pat_)[A-Za-z0-9_]{16,}', '$1***' );
  except
    on E: Exception do
      ;                                 // Redaction must never break logging
  end;

end;

/// <summary>
///   Encrypts a secret with DPAPI ( current user scope ) and returns it as a
///   prefixed Base64 string. Returns the input unchanged if DPAPI is unavailable.
/// </summary>
function ProtectSecret( const ASecret: string ): string;
var
  InBlob            : TDataBlob;
  OutBlob           : TDataBlob;
  Plain             : TBytes;
  Cipher            : TBytes;
begin

  Result := ASecret;

  if ASecret.IsEmpty or ASecret.StartsWith( SECRET_PREFIX ) then
    Exit;

  Plain := TEncoding.UTF8.GetBytes( ASecret );

  if Length( Plain ) = 0 then
    Exit;

  InBlob.cbData := Length( Plain );
  InBlob.pbData := @Plain[ 0 ];
  OutBlob.cbData := 0;
  OutBlob.pbData := nil;

  if CryptProtectData( @InBlob, 'GitBatchCommit', nil, nil, nil, 0, @OutBlob ) then
  begin
    try
      SetLength( Cipher, OutBlob.cbData );

      if OutBlob.cbData > 0 then
        Move( OutBlob.pbData^, Cipher[ 0 ], OutBlob.cbData );

      Result := SECRET_PREFIX + TNetEncoding.Base64.EncodeBytesToString( Cipher );
    finally
      LocalFree( HLOCAL( OutBlob.pbData ) );
    end;
  end;

end;

/// <summary>
///   Reverses <c>ProtectSecret</c>. A value without the marker is returned
///   as-is, so a plain-text token written by an earlier build still loads and
///   is re-written protected on the next save.
/// </summary>
function UnprotectSecret( const AStored: string ): string;
var
  InBlob            : TDataBlob;
  OutBlob           : TDataBlob;
  Cipher            : TBytes;
  Plain             : TBytes;
begin

  Result := AStored;

  if ( not AStored.StartsWith( SECRET_PREFIX ) ) then
    Exit;

  Result := '';

  try
    Cipher := TNetEncoding.Base64.DecodeStringToBytes( AStored.Substring( Length( SECRET_PREFIX ) ) );
  except
    on E: Exception do
      Exit;
  end;

  if Length( Cipher ) = 0 then
    Exit;

  InBlob.cbData := Length( Cipher );
  InBlob.pbData := @Cipher[ 0 ];
  OutBlob.cbData := 0;
  OutBlob.pbData := nil;

  if CryptUnprotectData( @InBlob, nil, nil, nil, nil, 0, @OutBlob ) then
  begin
    try
      SetLength( Plain, OutBlob.cbData );

      if OutBlob.cbData > 0 then
        Move( OutBlob.pbData^, Plain[ 0 ], OutBlob.cbData );

      Result := TEncoding.UTF8.GetString( Plain );
    finally
      LocalFree( HLOCAL( OutBlob.pbData ) );
    end;
  end;

end;

function RepoStatusToString( const Status: TRepoStatus ): string;
begin

  case Status of
    rsClean: Result := 'Clean';
    rsModified: Result := 'Modified';
    rsConflicted: Result := 'Conflicted';
    rsPullRequired: Result := 'Pull Required';
    rsPushRequired: Result := 'Push Required';
    rsDiverged: Result := 'Diverged';
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

function SanitizeRepoName( const AName: string ): string;
begin

  Result := '';

  for var c in AName do
    case c of
      'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.':
        Result := Result + c;
      ' ', #9:
        ; // drop whitespace: "Front Door Camera" -> "FrontDoorCamera"
    else
      Result := Result + '-';
    end;

  // Collapse runs of '-' left by stripped punctuation, then trim separators
  while Pos( '--', Result ) > 0 do
    Result := StringReplace( Result, '--', '-', [ rfReplaceAll ] );

  Result := Result.Trim( [ '-', '.', '_' ] );

  if Result = '' then
    Result := 'repo';

end;

{ TGitRepoManager }

constructor TGitRepoManager.Create;
begin

  inherited Create;
  FConfigPath := GetConfigFilePath;
  FReposLock := TCriticalSection.Create;
  FVersionCache := TDictionary<string, string>.Create;
  FVersionCacheStamp := TDictionary<string, TDateTime>.Create;
  FVersionScanStamp := TDictionary<string, TDateTime>.Create;
  FConfigLoaded := False;
  SetLength( FRepos, 0 );

end;

destructor TGitRepoManager.Destroy;
begin

  SetLength( FRepos, 0 );
  FVersionScanStamp.Free;
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
  sGitExe           : string;
  sFullCommand      : string;
begin

  // Honour the configured Git client when one is set and still present, and
  // fall back to PATH resolution otherwise. Quote the path: the configured
  // value routinely lives under "C:\Program Files\Git\...".
  sGitExe := FGitClientPath.Trim;

  if ( not sGitExe.IsEmpty ) and TFile.Exists( sGitExe ) then
    sGitExe := '"' + sGitExe + '"'
  else
    sGitExe := 'git';

  // -c core.quotepath=false keeps non-ASCII paths readable in porcelain output
  // instead of Git's default octal-escaped, double-quoted form.
  sFullCommand := sGitExe + ' -c core.quotepath=false ' + sCommand;

  Result := RunProcessCaptureOutput( sFullCommand, sRepoPath, sOutput, iTimeout );

end;

function TGitRepoManager.CreateCommitMessageFile( const sMessage: string; out sTempFile: string ): Boolean;
begin

  Result := False;

  try
    sTempFile := TPath.Combine( TPath.GetTempPath, Format( 'gitcommit_%s.txt', [ TPath.GetGUIDFileName( False ) ] ) );

    // The single-argument overload writes UTF-8 WITHOUT a byte-order mark.
    // The explicit-encoding overload passes WriteBOM = True, and Git does not
    // strip a BOM from a -F message file — it becomes an invisible U+FEFF at
    // the head of every commit subject line.
    TFile.WriteAllText( sTempFile, sMessage );
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

procedure TGitRepoManager.GetAheadBehind( const sRepoPath: string; out iAhead, iBehind: Integer );
var
  sOutput           : string;
  Parts             : TArray<string>;
begin

  iAhead := 0;
  iBehind := 0;

  // Refresh remote-tracking refs first; without this the comparison below
  // reports against whatever was last fetched.
  ExecuteGitCommand( sRepoPath, 'fetch', sOutput );

  // Left side is the upstream (commits we lack = behind), right side is HEAD
  // (commits the upstream lacks = ahead). Fails cleanly when there is no
  // upstream, leaving both counts at zero.
  if ( not ExecuteGitCommand( sRepoPath, 'rev-list --left-right --count @{upstream}...HEAD', sOutput ) ) then
    Exit;

  Parts := Trim( sOutput ).Split( [ #9, ' ' ], TStringSplitOptions.ExcludeEmpty );

  if Length( Parts ) >= 2 then
  begin
    iBehind := StrToIntDef( Parts[ 0 ], 0 );
    iAhead := StrToIntDef( Parts[ 1 ], 0 );
  end;

end;

function TGitRepoManager.HasUnmergedPaths( const sPorcelainOutput: string ): Boolean;
const
  UNMERGED_CODES: array[ 0..6 ] of string = ( 'DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU' );
var
  Lines             : TArray<string>;
  sCode             : string;
begin

  Result := False;

  if Trim( sPorcelainOutput ).IsEmpty then
    Exit;

  Lines := sPorcelainOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );

  for var sLine in Lines do
  begin
    if Length( sLine ) < 2 then
      Continue;

    sCode := Copy( sLine, 1, 2 );

    for var sUnmerged in UNMERGED_CODES do
    begin
      if sCode = sUnmerged then
        Exit( True );
    end;
  end;

end;

function TGitRepoManager.HasOperationInProgress( const sRepoPath: string ): Boolean;
var
  sGitDir           : string;
begin

  sGitDir := TPath.Combine( sRepoPath, '.git' );

  Result := TFile.Exists( TPath.Combine( sGitDir, 'MERGE_HEAD' ) ) or
    TFile.Exists( TPath.Combine( sGitDir, 'CHERRY_PICK_HEAD' ) ) or
    TFile.Exists( TPath.Combine( sGitDir, 'REVERT_HEAD' ) ) or
    TFile.Exists( TPath.Combine( sGitDir, 'BISECT_LOG' ) ) or
    TDirectory.Exists( TPath.Combine( sGitDir, 'rebase-merge' ) ) or
    TDirectory.Exists( TPath.Combine( sGitDir, 'rebase-apply' ) );

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
  FDelphiIndexerPath := '';

  if ( not TFile.Exists( FConfigPath ) ) then
  begin
    Result := True;                     // No config file is not an error
    FConfigLoaded := True;
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
    FConfigLoaded := True;
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

      // Load Codeberg credentials. Tokens are stored DPAPI-protected; a value
      // without the marker is a plain-text token from an older build and is
      // read as-is, then re-written protected by the next SaveConfig.
      FCodebergUsername := JSONRoot.GetValue<string>( 'codeberg_username', '' );
      FCodebergToken := UnprotectSecret( JSONRoot.GetValue<string>( 'codeberg_token', '' ) );

      // Load GitHub credentials
      FGitHubUsername := JSONRoot.GetValue<string>( 'github_username', '' );
      FGitHubToken := UnprotectSecret( JSONRoot.GetValue<string>( 'github_token', '' ) );

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
        FConfigLoaded := True;
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
    FConfigLoaded := True;
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

  // Guard: never overwrite a populated config with an empty repo list because
  // a LOAD failed. Once LoadConfig has succeeded, an empty list is a genuine
  // user action ( they removed the last repository ) and must be persisted —
  // otherwise the removal silently reappears on the next start.
  if ( Length( FRepos ) = 0 ) and ( not FConfigLoaded ) and TFile.Exists( FConfigPath ) then
  begin
    Result := True;
    Exit;
  end;

  JSONRoot := TJSONObject.Create;

  try
    // Save Codeberg credentials. Tokens are encrypted with DPAPI under the
    // current user account, so the config file no longer holds a usable
    // credential if it is copied, backed up or roamed off this machine.
    JSONRoot.AddPair( 'codeberg_username', FCodebergUsername );
    JSONRoot.AddPair( 'codeberg_token', ProtectSecret( FCodebergToken ) );

    // Save GitHub credentials
    JSONRoot.AddPair( 'github_username', FGitHubUsername );
    JSONRoot.AddPair( 'github_token', ProtectSecret( FGitHubToken ) );

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
  sRepoPath         : string;
  sStatusOutput     : string;
  sBranch           : string;
  sVersion          : string;
  sStatusText       : string;
  Status            : TRepoStatus;
  Provider          : TRemoteProvider;
  iTracked          : Integer;
  iModified         : Integer;
  iAhead            : Integer;
  iBehind           : Integer;
  Lines             : TArray<string>;
begin

  // Snapshot the path under the lock, do all the (slow, blocking) Git work
  // OUTSIDE it, then publish the results under the lock again. Holding the
  // lock across a git invocation would serialise the whole parallel refresh;
  // touching FRepos without it races with Add/Remove, which call SetLength and
  // can therefore move the array body out from under a worker thread.
  FReposLock.Enter;

  try
    if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
      Exit;

    sRepoPath := FRepos[ iIndex ].Path;
  finally
    FReposLock.Leave;
  end;

  sBranch := GetRepoBranch( sRepoPath );
  iModified := 0;
  iAhead := 0;
  iBehind := 0;

  if ( not TDirectory.Exists( TPath.Combine( sRepoPath, '.git' ) ) ) then
    Status := rsError
  else if ExecuteGitCommand( sRepoPath, 'status --porcelain', sStatusOutput ) then
  begin
    sStatusOutput := Trim( sStatusOutput );

    if ( not sStatusOutput.IsEmpty ) then
    begin
      Lines := sStatusOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );
      iModified := Length( Lines );
    end;

    // Order matters. An unmerged path outranks everything: staging it with
    // `add -A` and committing would write conflict markers into history, so it
    // must never be presented as an ordinary modification ready to commit.
    if HasUnmergedPaths( sStatusOutput ) or HasOperationInProgress( sRepoPath ) then
      Status := rsConflicted
    else if ( not sStatusOutput.IsEmpty ) and ( not AllChangesAreBuildArtifacts( sStatusOutput ) ) then
      Status := rsModified
    else
    begin
      // Working tree is clean (or only build output changed). The branch may
      // still differ from its upstream in either direction — a repository whose
      // work is committed but not pushed used to report as Clean, with nothing
      // anywhere in the UI saying the remote was behind.
      GetAheadBehind( sRepoPath, iAhead, iBehind );

      if ( iAhead > 0 ) and ( iBehind > 0 ) then
        Status := rsDiverged
      else if iBehind > 0 then
        Status := rsPullRequired
      else if iAhead > 0 then
        Status := rsPushRequired
      else
        Status := rsClean;
    end;
  end
  else
    Status := rsError;

  iTracked := GetTrackedFileCount( sRepoPath );
  Provider := DetectRemoteProvider( GetRemoteOriginURL( sRepoPath ) );
  sVersion := GetProjectVersion( sRepoPath );

  // Carry the commit counts in the display text - the columns are fixed, and
  // "Push Required (3)" is far more useful than "Push Required" alone.
  sStatusText := RepoStatusToString( Status );

  case Status of
    rsPullRequired: sStatusText := Format( '%s (%d)', [ sStatusText, iBehind ] );
    rsPushRequired: sStatusText := Format( '%s (%d)', [ sStatusText, iAhead ] );
    rsDiverged: sStatusText := Format( '%s (+%d/-%d)', [ sStatusText, iAhead, iBehind ] );
  end;

  // Publish. Re-locate by path rather than trusting the index: the array may
  // have been reordered or shortened while the Git calls above were running.
  FReposLock.Enter;

  try
    for var j := 0 to High( FRepos ) do
    begin
      if SameText( FRepos[ j ].Path, sRepoPath ) then
      begin
        FRepos[ j ].Branch := sBranch;
        FRepos[ j ].Status := Status;
        FRepos[ j ].StatusText := sStatusText;
        FRepos[ j ].ModifiedFileCount := iModified;
        FRepos[ j ].TrackedFileCount := iTracked;
        FRepos[ j ].Provider := Provider;
        FRepos[ j ].Version := sVersion;
        Break;
      end;
    end;
  finally
    FReposLock.Leave;
  end;

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
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  sLog := Format( '=== %s ===%s', [ Repo.Name, sLineBreak ] );

  // Refuse outright while a merge/rebase/cherry-pick is unfinished or any path
  // is unmerged. `add -A` would stage files still containing conflict markers,
  // and the commit that followed would push them to the remote.
  if ExecuteGitCommand( Repo.Path, 'status --porcelain', sOutput ) and
     ( HasUnmergedPaths( sOutput ) or HasOperationInProgress( Repo.Path ) ) then
  begin
    sLog := sLog + 'Refused to commit - the repository has unresolved conflicts or an ' +
      'unfinished merge/rebase. Resolve them first (Resolve Conflicts, or finish the ' +
      'operation in a Git client).' + sLineBreak;
    Exit;
  end;

  // Stage changes (use file pattern if specified)
  if FFilePattern.Trim.IsEmpty then
  begin
    if ( not ExecuteGitCommand( Repo.Path, 'add -A', sOutput ) ) then
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

    if ( not ExecuteGitCommand( Repo.Path, 'add ' + FFilePattern, sOutput ) ) then
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
    if ( not ExecuteGitCommand( Repo.Path, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput ) ) then
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
  if ( not ExecuteGitCommand( Repo.Path, 'push', sOutput ) ) then
  begin
    sLog := sLog + 'Push failed: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Pushed successfully' + sLineBreak;

  // Create and push version tag if .dproj version exists
  sVersion := GetProjectVersion( Repo.Path );

  if ( not sVersion.IsEmpty ) then
  begin
    sTagName := 'v' + sVersion;

    // Check if tag already exists
    if ExecuteGitCommand( Repo.Path, Format( 'tag -l "%s"', [ sTagName ] ), sOutput ) then
    begin
      if Trim( sOutput ).IsEmpty then
      begin
        // Tag doesn't exist - create it
        if ExecuteGitCommand( Repo.Path, Format( 'tag -a "%s" -m "Version %s"', [ sTagName, sVersion ] ), sOutput ) then
        begin
          sLog := sLog + Format( 'Created tag: %s', [ sTagName ] ) + sLineBreak;

          // Push the tag
          if ExecuteGitCommand( Repo.Path, Format( 'push origin "%s"', [ sTagName ] ), sOutput ) then
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
  RootDprojFiles    : TArray<string>;
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
  ScanStamp         : TDateTime;
  NewestDprojWrite  : TDateTime;
  dt                : TDateTime;
begin

  Result := '';
  sBestVersion := '';
  sKey := sRepoPath.ToLower;

  // A full recursive walk of every repository on every refresh is the single
  // most expensive thing this class does. Suppress repeat walks of the same
  // tree within a short window; the modification-time check below is still the
  // authority once the window has elapsed.
  FReposLock.Enter;

  try
    if FVersionScanStamp.TryGetValue( sKey, ScanStamp ) and
       ( SecondsBetween( Now, ScanStamp ) < VERSION_SCAN_TTL_SECONDS ) and
       FVersionCache.TryGetValue( sKey, CachedVersion ) then
      Exit( CachedVersion );
  finally
    FReposLock.Leave;
  end;

  // Prefer a project in the repository ROOT. Scanning the whole tree and taking
  // the highest version anywhere lets a VENDORED third-party .dproj decide the
  // repository's version — and CommitAndPush turns that number into a pushed
  // Git tag. Only fall back to the deep scan when the root has no project.
  try
    RootDprojFiles := TDirectory.GetFiles( sRepoPath, '*.dproj', TSearchOption.soTopDirectoryOnly );
  except
    RootDprojFiles := nil;
  end;

  if Length( RootDprojFiles ) > 0 then
    DprojFiles := RootDprojFiles
  else
  begin
    try
      DprojFiles := TDirectory.GetFiles( sRepoPath, '*.dproj', TSearchOption.soAllDirectories );
    except
      Exit;
    end;
  end;

  if Length( DprojFiles ) = 0 then
  begin
    // Remember the empty result too, or a repository with no Delphi project is
    // re-walked in full on every single refresh.
    FReposLock.Enter;

    try
      FVersionCache.AddOrSetValue( sKey, '' );
      FVersionCacheStamp.AddOrSetValue( sKey, 0 );
      FVersionScanStamp.AddOrSetValue( sKey, Now );
    finally
      FReposLock.Leave;
    end;

    Exit;
  end;

  // Cache hit: if every .dproj mtime is at or below the stamp recorded last
  // time, nothing has changed, so return the cached version. Touching any
  // .dproj invalidates the cache for that path.
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
    begin
      FVersionScanStamp.AddOrSetValue( sKey, Now );
      Exit( CachedVersion );
    end;
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
    FVersionScanStamp.AddOrSetValue( sKey, Now );
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

  // Check by directory path.
  //
  // Bare '/debug/' and '/release/' are deliberately NOT matched here. Delphi
  // build output always lives under a PLATFORM folder ( Win32\Debug,
  // Win64\Release ), which the platform tests below already cover, whereas
  // 'debug' and 'release' are perfectly ordinary source/doc folder names —
  // matching them made a repository whose only change was, say,
  // 'docs/release/notes.md' display as Clean, so the change was never
  // committed and the user was never told.
  if sLower.Contains( '/win32/' ) or sLower.Contains( '/win64/' ) or
     sLower.Contains( '/__history/' ) or sLower.Contains( '/__recovery/' ) or
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
  Repo              : TRepoInfo;
begin

  Result := rpNone;

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
    Exit;

  sOriginURL := GetRemoteOriginURL( Repo.Path );
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
  Repo              : TRepoInfo;
begin

  Result := False;
  sError := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sError := 'Invalid repository index';
    Exit;
  end;

  sOriginURL := GetRemoteOriginURL( Repo.Path );
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
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  // Fast-forward only — refuse to create surprise merge commits when local
  // history has diverged. If it fails, the user should explicitly reconcile.
  if ( not ExecuteGitCommand( Repo.Path, 'pull --ff-only', sOutput ) ) then
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
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  sRepoPath := Repo.Path;
  sLog := Format( '=== %s ===%s', [ Repo.Name, sLineBreak ] );

  // `checkout --ours` only means anything while a merge is actually in
  // progress; outside one it either errors or silently matches nothing, and
  // the add/commit/push that follows would then push unrelated working-tree
  // state. MERGE_HEAD exists for exactly the life of a conflicted merge.
  if ( not TFile.Exists( TPath.Combine( TPath.Combine( sRepoPath, '.git' ), 'MERGE_HEAD' ) ) ) then
  begin
    sLog := sLog + 'No merge in progress - nothing to resolve' + sLineBreak;
    Result := True;
    Exit;
  end;

  // Take OUR side of every conflicted file. This DISCARDS the remote side of
  // those files; the caller is responsible for having said so plainly.
  if ( not ExecuteGitCommand( sRepoPath, 'checkout --ours .', sOutput ) ) then
  begin
    sLog := sLog + 'Failed to checkout local versions: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Checked out local versions (remote side of conflicted files discarded)' + sLineBreak;

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
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  if ( not ExecuteGitCommand( Repo.Path, 'push', sOutput ) ) then
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
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  // --force-with-lease, never a bare --force. The lease makes Git verify that
  // the remote ref is still where we last saw it, so a colleague's push made
  // since our last fetch aborts the operation instead of being destroyed.
  if ( not ExecuteGitCommand( Repo.Path, 'push --force-with-lease', sOutput ) ) then
  begin
    sLog := 'Force push failed: ' + Trim( sOutput );

    if sOutput.Contains( 'stale info' ) or sOutput.Contains( 'rejected' ) then
      sLog := sLog + sLineBreak +
        'The remote has commits that this clone has not fetched. Fetch and review them ' +
        'before force pushing — pushing now would destroy them.';

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
  Repo              : TRepoInfo;
begin

  Result := False;
  sBranchName := '';
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  // Create a timestamped backup branch name — millisecond precision so two
  // backups within the same second don't collide ( "branch already exists" ).
  sBranchName := 'backup-' + FormatDateTime( 'yyyy-mm-dd-hhnnss-zzz', Now );

  if ( not ExecuteGitCommand( Repo.Path, 'branch ' + sBranchName, sOutput ) ) then
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
  Repo              : TRepoInfo;
begin

  Result := False;
  sChanges := '';
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  sRepoPath := Repo.Path;

  // Resolve the branch afresh. The cached Branch field carries the DISPLAY
  // string '(unknown)' when detection failed, and feeding that to Git produced
  // `diff --stat HEAD..origin/(unknown)`, which fails and was then reported to
  // the user as "no incoming changes" - the opposite of the truth.
  sBranch := GetCurrentBranch( sRepoPath );

  if sBranch.IsEmpty then
  begin
    sChanges := '';
    sLog := 'Could not determine the current branch (detached HEAD or no commits) - preview unavailable';
    Exit;
  end;

  // Fetch from remote first
  if ( not ExecuteGitCommand( sRepoPath, 'fetch', sOutput ) ) then
  begin
    sLog := 'Fetch failed: ' + Trim( sOutput );
    Exit;
  end;

  // Get diff stat between current HEAD and remote branch
  if ( not ExecuteGitCommand( sRepoPath, 'diff --stat HEAD..origin/' + sBranch, sOutput ) ) then
  begin
    // No upstream for this branch. Not an error, but say WHICH case it was
    // rather than letting the caller imply "already up to date".
    sChanges := '';
    sLog := Format( 'No upstream branch origin/%s - nothing to preview', [ sBranch ] );
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
  Repo              : TRepoInfo;
begin

  Result := False;
  sNewRemoteURL := '';
  sError := '';
  sLog := '';

  if ( not GetRepoSnapshot( iIndex, Repo ) ) then
  begin
    sError := 'Invalid repository index';
    Exit;
  end;

  if ( not ( TargetProvider in [ rpCodeberg, rpGitHub ] ) ) then
  begin
    sError := 'Target provider must be Codeberg or GitHub';
    Exit;
  end;

  sRepoPath := Repo.Path;

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

  // Update cached provider on the repo record, under the lock
  FReposLock.Enter;

  try
    if ( iIndex >= 0 ) and ( iIndex <= High( FRepos ) ) then
      FRepos[ iIndex ].Provider := TargetProvider;
  finally
    FReposLock.Leave;
  end;

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
    FReposLock.Enter;

    try
      for var i := 0 to High( FRepos ) do
      begin
        sGroup := Trim( FRepos[ i ].Group );

        if ( not sGroup.IsEmpty ) and ( not Groups.Contains( sGroup ) ) then
          Groups.Add( sGroup );
      end;
    finally
      FReposLock.Leave;
    end;

    Groups.Sort;
    Result := Groups.ToArray;
  finally
    Groups.Free;
  end;

end;

procedure TGitRepoManager.SetRepoGroup( const iIndex: Integer; const sGroup: string );
begin

  FReposLock.Enter;

  try
    if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
      Exit;

    FRepos[ iIndex ].Group := Trim( sGroup );
  finally
    FReposLock.Leave;
  end;

  SaveConfig;

end;

procedure TGitRepoManager.RefreshAllStatusParallel( const AOnRepoDone: TProc<string>;
  const AIsCancelled: TFunc<Boolean> );
var
  iCount            : Integer;
  Paths             : TArray<string>;
  Names             : TArray<string>;
begin

  // Snapshot the repo paths under the lock so the parallel loop works against
  // a stable array even if the live FRepos is mutated by add/remove calls.
  FReposLock.Enter;

  try
    iCount := Length( FRepos );

    if iCount = 0 then
      Exit;

    SetLength( Paths, iCount );
    SetLength( Names, iCount );

    for var i := 0 to iCount - 1 do
    begin
      Paths[ i ] := FRepos[ i ].Path;
      Names[ i ] := FRepos[ i ].Name;
    end;
  finally
    FReposLock.Leave;
  end;

  TParallel.For( 0, iCount - 1,
    procedure( AIndex: Integer )
    begin

      if Assigned( AIsCancelled ) and AIsCancelled then
        Exit;

      // RefreshStatus now snapshots the path, runs Git outside the lock and
      // publishes by path match, so it is safe to call from several threads.
      RefreshStatus( AIndex );

      if Assigned( AIsCancelled ) and AIsCancelled then
        Exit;

      if Assigned( AOnRepoDone ) then
        AOnRepoDone( Names[ AIndex ] );

    end );

end;

end.

