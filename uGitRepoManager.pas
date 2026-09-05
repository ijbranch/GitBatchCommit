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
  Version: 1.6.0

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
    /// <summary>
    ///   Commit the upstream branch pointed at when this record's status was
    ///   last determined. Used as the explicit lease for a force push, so the
    ///   push is refused when the remote has moved since the user was shown
    ///   this row. Empty when there is no upstream.
    /// </summary>
    RemoteSHA: string;
    /// <summary>
    ///   True when the working tree has changes but every one of them is a
    ///   build artifact, so the repository scores as clean. Surfaced so the UI
    ///   can say the repository was skipped rather than silently omitting it.
    /// </summary>
    ArtifactOnlyChanges: Boolean;
    /// <summary>
    ///   Commits the upstream has that this branch lacks, as counted when the
    ///   status was last determined. Carried on the record because a repository
    ///   can be BOTH modified and behind, and the single Status slot can only
    ///   report one of the two.
    /// </summary>
    BehindCount: Integer;
    /// <summary>
    ///   Commits this branch has that the upstream lacks, counted alongside
    ///   <c>BehindCount</c>.
    /// </summary>
    AheadCount: Integer;
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
    /// <summary>
    ///   The exact strings read from the config file for each token, kept only
    ///   when they were present but could NOT be decrypted.
    /// </summary>
    /// <remarks>
    ///   A save must never replace an unreadable secret with an empty string.
    ///   That is how a credential gets destroyed by an upgrade: the load
    ///   silently yields nothing, and the next save - which happens on exit -
    ///   writes that nothing over the only copy. The original ciphertext is
    ///   written back untouched instead, so the value survives for whatever
    ///   can still read it.
    /// </remarks>
    FCodebergTokenStored: string;
    FGitHubTokenStored: string;
    /// <summary>
    ///   Guards <see cref="FCommitHistory"/> and <see cref="FCommitTemplates"/>,
    ///   which are mutated from the commit worker thread ( via
    ///   <see cref="AddToCommitHistory"/> ) and read from the UI thread.
    /// </summary>
    FListsLock: TCriticalSection;
    /// <summary>
    ///   Serialises the config file write, so two threads calling
    ///   <see cref="SaveConfig"/> cannot truncate each other's output.
    /// </summary>
    FConfigLock: TCriticalSection;
    /// <summary>
    ///   Description of why the last <see cref="SaveConfig"/> could not fully
    ///   persist, or empty when it succeeded. Surfaced so the settings dialogs
    ///   stop reporting "credentials updated" after a save that dropped them.
    /// </summary>
    FLastSaveError: string;

    /// <summary>
    ///   Returns a locked copy of the commit-message history.
    /// </summary>
    /// <returns>A private copy of the history, newest first.</returns>
    function GetCommitHistorySnapshot: TArray<string>;

    /// <summary>
    ///   Returns a locked copy of the saved commit templates.
    /// </summary>
    /// <returns>A private copy of the template list.</returns>
    function GetCommitTemplatesSnapshot: TArray<string>;

    /// <summary>
    ///   Stores the Codeberg access token, stripping control characters and
    ///   re-registering it for log redaction.
    /// </summary>
    /// <param name="AValue">The token as entered.</param>
    procedure SetCodebergToken( const AValue: string );

    /// <summary>
    ///   Stores the GitHub access token, stripping control characters and
    ///   re-registering it for log redaction.
    /// </summary>
    /// <param name="AValue">The token as entered.</param>
    procedure SetGitHubToken( const AValue: string );
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
    ///   Resolves the repository's real Git directory.
    /// </summary>
    /// <remarks>
    ///   <c>.git</c> is only a folder in an ordinary clone. In a linked worktree
    ///   or a submodule it is a FILE pointing elsewhere, so probing
    ///   <c>&lt;path&gt;\.git\MERGE_HEAD</c> directly can never succeed there —
    ///   which silently disabled every in-progress and conflict check for those
    ///   repositories. Asking Git is the only reliable answer.
    /// </remarks>
    /// <param name="sRepoPath">Path to the repository working tree.</param>
    /// <returns>Absolute path of the Git directory, or empty if this is not a repository.</returns>
    function ResolveGitDir( const sRepoPath: string ): string;

    /// <summary>
    ///   Returns True if the path is inside a Git working tree.
    /// </summary>
    /// <remarks>
    ///   Replaces a <c>TDirectory.Exists( path\.git )</c> test, which reports
    ///   False for a perfectly valid worktree or submodule and left those
    ///   repositories permanently stuck in the Error state.
    /// </remarks>
    /// <param name="sRepoPath">Path to test.</param>
    /// <returns>True if Git considers this a working tree.</returns>
    function IsGitWorkTree( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Returns the commit the current branch's upstream points at.
    /// </summary>
    /// <remarks>
    ///   Captured at status-refresh time and stored in
    ///   <see cref="TRepoInfo.RemoteSHA"/>, so a later force push can name it as
    ///   an explicit lease rather than trusting whatever the remote-tracking ref
    ///   happens to hold by then.
    /// </remarks>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>The upstream commit hash, or empty when there is no upstream.</returns>
    function GetUpstreamSHA( const sRepoPath: string ): string;

    /// <summary>
    ///   Finds a repository by working-tree path. The caller MUST already hold
    ///   <c>FReposLock</c>.
    /// </summary>
    /// <param name="sPath">Working-tree path to find.</param>
    /// <returns>Index into <c>FRepos</c>, or -1 when not present.</returns>
    function IndexOfPathLocked( const sPath: string ): Integer;

    /// <summary>
    ///   Returns True when the repository already has a remote of that name.
    /// </summary>
    /// <remarks>
    ///   Migration used to <c>remote remove</c> its chosen alias unconditionally
    ///   before renaming <c>origin</c> onto it, which silently destroyed a
    ///   pre-existing remote called <c>github</c> or <c>codeberg</c> — an
    ///   entirely ordinary mirror arrangement — along with its refspecs.
    /// </remarks>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <param name="sRemoteName">Remote name to look for.</param>
    /// <returns>True if that remote is already configured.</returns>
    function RemoteExists( const sRepoPath, sRemoteName: string ): Boolean;

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
    /// <param name="bForceRescan">
    ///   True to ignore the scan TTL and re-read the project file. Commit &amp; Push
    ///   passes True: the cached value decides the Git tag that gets pushed, and
    ///   a version bumped seconds before the commit would otherwise be tagged
    ///   with the previous release number — or not tagged at all, because the
    ///   old tag already exists.
    /// </param>
    /// <returns>Version string (e.g., "1.0.1.25") or empty if not found.</returns>
    function GetProjectVersion( const sRepoPath: string; const bForceRescan: Boolean = False ): string;

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
    /// <remarks>
    ///   Addressed by path, not index. An index is only ever a position in a
    ///   snapshot the caller took earlier, and the array shifts under it the
    ///   moment anything is added or removed — which used to make a batch
    ///   operate on the repository next door.
    /// </remarks>
    /// <param name="sPath">Working-tree path of the repository to remove.</param>
    procedure RemoveRepository( const sPath: string );

    /// <summary>
    ///   Refreshes the status of all repositories.
    /// </summary>
    procedure RefreshAllStatus;

    /// <summary>
    ///   Refreshes the status of a single repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository to refresh.</param>
    procedure RefreshStatus( const sRepoPath: string );

    /// <summary>
    ///   Commits and pushes changes for a repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sMessage">Commit message.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function CommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;

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
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <returns>The detected remote provider.</returns>
    function GetRepoProvider( const sRepoPath: string ): TRemoteProvider;

    /// <summary>
    ///   Changes the visibility of a remote repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="lPrivate">True to make private, False to make public.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if the operation succeeded.</returns>
    function SetRepositoryVisibility( const sRepoPath: string; const lPrivate: Boolean;
      out sError: string ): Boolean;

    /// <summary>
    ///   Pulls changes from remote for a repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function PullRepository( const sRepoPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Resolves merge conflicts by keeping local versions of all files.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded or there was nothing to resolve.</returns>
    function ResolveConflictsKeepLocal( const sRepoPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Pushes a repository to remote without committing.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function PushRepository( const sRepoPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Force pushes a repository to remote, overwriting remote history.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function ForcePushRepository( const sRepoPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Creates a backup branch before a potentially destructive operation.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sBranchName">Output: name of the created backup branch.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the backup branch was created successfully.</returns>
    function CreateBackupBranch( const sRepoPath: string; out sBranchName: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Fetches from remote and returns a preview of incoming changes.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sChanges">Output: description of files that will change.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if fetch succeeded (sChanges may be empty if no changes).</returns>
    function GetIncomingChanges( const sRepoPath: string; out sChanges: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Migrates a repository's remote from its current host (Codeberg or GitHub)
    ///   to the specified target provider. Creates the new repository on the target,
    ///   re-points <c>origin</c> to the new URL (the previous origin is kept under
    ///   a provider-named alias for safety) and pushes all branches and tags.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository to migrate.</param>
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
    function MigrateRepository( const sRepoPath: string; const TargetProvider: TRemoteProvider;
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
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sGroup">Group name, or an empty string to clear it.</param>
    procedure SetRepoGroup( const sRepoPath: string; const sGroup: string );

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
    ///   Returns a snapshot copy of a repository located by its working-tree path.
    /// </summary>
    /// <remarks>
    ///   This is the safe way for a long-running operation to re-find its
    ///   repository: the path is stable, whereas the index it was found at is
    ///   invalidated by any add or remove.
    /// </remarks>
    /// <param name="sPath">Working-tree path of the repository.</param>
    /// <param name="ARepo">Receives a copy of the repository record.</param>
    /// <returns>True if a repository with that path is still managed.</returns>
    function GetRepoSnapshotByPath( const sPath: string; out ARepo: TRepoInfo ): Boolean;

    /// <summary>
    ///   Returns a locked deep copy of the whole repository array.
    /// </summary>
    /// <remarks>
    ///   The UI must build its list from one of these rather than reading the
    ///   manager's array directly. <c>TRepoInfo</c> carries managed strings, and
    ///   a worker thread publishing a new <c>StatusText</c> while the UI copies
    ///   the old one is a use-after-free on the string heap, not merely a torn
    ///   read.
    /// </remarks>
    /// <returns>A copy of every managed repository, in list order.</returns>
    function SnapshotAll: TRepoInfoArray;

    /// <summary>
    ///   Sets a repository's tick state, located by path and written under the
    ///   lock.
    /// </summary>
    /// <param name="sPath">Working-tree path of the repository.</param>
    /// <param name="bSelected">True if the row is ticked.</param>
    procedure SetRepoSelected( const sPath: string; const bSelected: Boolean );

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
    property CodebergToken: string read FCodebergToken write SetCodebergToken;
    /// <summary>
    ///   GitHub account name used for repository creation and visibility changes.
    /// </summary>
    property GitHubUsername: string read FGitHubUsername write FGitHubUsername;
    /// <summary>
    ///   GitHub personal access token, in clear text in memory and DPAPI-encrypted
    ///   at rest.
    /// </summary>
    property GitHubToken: string read FGitHubToken write SetGitHubToken;
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
    ///   Most-recently-used commit messages, newest first. Reading this yields a
    ///   private copy taken under the lock: the array is re-sized from the
    ///   commit worker thread, so handing out the live one was a use-after-free
    ///   waiting to happen.
    /// </summary>
    property CommitHistory: TArray<string> read GetCommitHistorySnapshot;
    /// <summary>
    ///   User-defined reusable commit messages. Reading yields a locked copy,
    ///   for the same reason as <see cref="CommitHistory"/>.
    /// </summary>
    property CommitTemplates: TArray<string> read GetCommitTemplatesSnapshot write FCommitTemplates;
    /// <summary>
    ///   Why the last <see cref="SaveConfig"/> could not fully persist, or empty
    ///   when it succeeded. Check this after saving credentials.
    /// </summary>
    property LastSaveError: string read FLastSaveError;
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
///   Re-raises an exception that indicates a defect in this application rather
///   than an environment failure.
/// </summary>
/// <remarks>
///   A worker thread must not let an exception escape, so its outermost handler
///   has to be a catch-all. But swallowing everything meant an access violation
///   caused by our own code was logged as "Error during commit", the user was
///   still told "n of m successful", and EurekaLog never saw the crash at all.
///   Environment failures — a locked file, a dropped connection, a full disk —
///   are absorbed as before; a defect is re-raised so the report is produced.
/// </remarks>
/// <param name="AException">The exception caught by the handler.</param>
procedure ReRaiseIfDefect( const AException: Exception );

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

  /// <summary>
  ///   Ceiling on captured child output. A runaway or misconfigured child could
  ///   otherwise grow the accumulator without bound while the timeout check
  ///   never came round.
  /// </summary>
  MAX_CAPTURED_BYTES = 8 * 1024 * 1024;

  /// <summary>
  ///   Reads performed per drain pass before returning to the wait loop, so the
  ///   timeout is always re-evaluated no matter how chatty the child is.
  /// </summary>
  MAX_READS_PER_DRAIN = 64;

  /// <summary>
  ///   The only executable name this application will accept as Git. The Git
  ///   Client Path setting is also used to open a repository in a GUI client,
  ///   so it cannot be trusted to be Git itself.
  /// </summary>
  GIT_EXE_NAME      = 'git.exe';

  /// <summary>
  ///   Timeout for the short, purely local Git queries ( rev-parse and friends ).
  ///   These never touch the network, so the full 60-second budget only delays
  ///   the report of a genuinely wedged repository.
  /// </summary>
  GIT_QUICK_TIMEOUT = 15000;

  /// <summary>
  ///   Application-specific DPAPI entropy. Without it, the protected token is
  ///   decryptable by ANY process running as the same user with a three-line
  ///   call — which is exactly what a commodity credential sweep of %APPDATA%
  ///   does. Changing this value invalidates previously stored secrets, which
  ///   surface as an absent credential and are simply re-entered.
  /// </summary>
  SECRET_ENTROPY    = 'GitBatchCommit/v1/token';

  /// <summary>
  ///   Suppresses any DPAPI user-interface prompt, failing the call instead.
  ///   Declared here because the RTL does not surface <c>wincrypt.h</c>.
  /// </summary>
  CRYPTPROTECT_UI_FORBIDDEN = DWORD( $1 );

var
  /// <summary>
  ///   Cached absolute path of git.exe, and the lock guarding it. Resolved once
  ///   with SearchPath so that CreateProcess is given an explicit executable:
  ///   passing a bare 'git' lets Windows resolve it from the image directory
  ///   and the process CURRENT DIRECTORY before ever consulting PATH.
  /// </summary>
  GGitExePath       : string = '';
  GGitExeLock       : TCriticalSection = nil;

  /// <summary>
  ///   Serialises the CreatePipe-to-CreateProcess window. CreateProcess is
  ///   called with bInheritHandles, which duplicates EVERY inheritable handle
  ///   in the process into the child — including another thread's pipe, when
  ///   two refresh workers are in this window at once.
  /// </summary>
  GProcessSpawnLock : TCriticalSection = nil;

  /// <summary>
  ///   The live access tokens, registered so <see cref="RedactSecrets"/> can
  ///   mask them by exact match, and the lock guarding them. They are written
  ///   from the settings dialogs on the UI thread and read from every worker
  ///   that logs, so an unguarded string field here would be the very
  ///   cross-thread hazard the redaction exists to report on.
  /// </summary>
  GKnownSecrets     : TArray<string>;
  GSecretsLock      : TCriticalSection = nil;

const
  /// <summary>
  ///   Shortest value worth masking by literal comparison. Guards against a
  ///   blank or one-character token turning every log line into asterisks.
  /// </summary>
  MIN_REDACTABLE_SECRET_LENGTH = 8;

/// <summary>
///   Extracts the host component of a Git remote URL, handling the scp-style
///   SSH form as well as ordinary URLs.
/// </summary>
/// <remarks>
///   Recognises <c>https://host/owner/repo</c>, <c>https://user@host:443/...</c>,
///   <c>ssh://git@host:22/owner/repo</c> and <c>git@host:owner/repo.git</c>.
/// </remarks>
/// <param name="AURL">The remote URL to inspect.</param>
/// <returns>The lower-case host, or an empty string when none can be found.</returns>
function ExtractURLHost( const AURL: string ): string;
begin

  Result := Trim( AURL );

  if Result.IsEmpty then
    Exit;

  // Strip the scheme.
  var iPos := Pos( '://', Result );

  if iPos > 0 then
    Result := Copy( Result, iPos + 3, MaxInt );

  // Strip any userinfo.
  iPos := Pos( '@', Result );

  if iPos > 0 then
    Result := Copy( Result, iPos + 1, MaxInt );

  // The host ends at the first '/' ( URL form ) or ':' ( port, or the scp-style
  // path separator ).
  for var iI := 1 to Length( Result ) do
  begin
    if CharInSet( Result[ iI ], [ '/', ':' ] ) then
      Exit( LowerCase( Copy( Result, 1, iI - 1 ) ) );
  end;

  Result := LowerCase( Result );

end;

procedure ReRaiseIfDefect( const AException: Exception );
begin

  if ( AException is EAccessViolation ) or ( AException is EInvalidPointer ) or
     ( AException is EInvalidCast ) or ( AException is EArgumentException ) or
     ( AException is EListError ) or ( AException is ERangeError ) or
     ( AException is EIntOverflow ) or ( AException is EOutOfMemory ) then
    raise AException at ReturnAddress;

end;

/// <summary>
///   Trims an access token and strips any control character from it.
/// </summary>
/// <remarks>
///   The token is concatenated into an <c>Authorization</c> header value. The
///   settings dialogs use single-line edits so the UI cannot introduce a
///   newline, but <c>repositories.json</c> is hand-editable — this is the
///   defence-in-depth against header injection from a hand-edited file.
/// </remarks>
/// <param name="AValue">The token as supplied.</param>
/// <returns>The token with surrounding whitespace and control characters removed.</returns>
function SanitiseTokenValue( const AValue: string ): string;
begin

  Result := '';

  for var cChar in AValue.Trim do
  begin
    if cChar >= ' ' then
      Result := Result + cChar;
  end;

end;

/// <summary>
///   Normalises one path as it appears in <c>git status --porcelain</c> output.
/// </summary>
/// <remarks>
///   Git quotes a path whenever it contains a space or a non-ASCII byte, and
///   inside those quotes it uses C escapes. Stripping the surrounding quotes
///   without unescaping left literal backslash sequences in the name, which
///   then failed the extension test. <c>core.quotepath=false</c> ( already
///   forced in <c>ExecuteGitCommand</c> ) removes the octal form, so only the
///   handful of C escapes below remain.
/// </remarks>
/// <param name="APath">One raw path from porcelain output.</param>
/// <returns>The unquoted, unescaped path.</returns>
function UnquotePorcelainPath( const APath: string ): string;
begin

  Result := Trim( APath );

  if ( Length( Result ) < 2 ) or ( not Result.StartsWith( '"' ) ) or
     ( not Result.EndsWith( '"' ) ) then
    Exit;

  Result := Copy( Result, 2, Length( Result ) - 2 );
  Result := Result
    .Replace( '\t', #9, [ rfReplaceAll ] )
    .Replace( '\n', #10, [ rfReplaceAll ] )
    .Replace( '\r', #13, [ rfReplaceAll ] )
    .Replace( '\"', '"', [ rfReplaceAll ] )
    .Replace( '\\', '\', [ rfReplaceAll ] );

end;

/// <summary>
///   Returns True when the text is a plain dotted numeric version.
/// </summary>
/// <remarks>
///   This is a security boundary, not a tidiness check. The value is read
///   verbatim out of a <c>.dproj</c> belonging to the repository being
///   committed, and it is then interpolated into <c>git tag</c> and
///   <c>git push</c> command lines. An embedded quote closes the quoting and
///   everything after it becomes further arguments to Git — enough to redirect
///   a push to another host.
/// </remarks>
/// <param name="AVersion">The candidate version string.</param>
/// <returns>True if the string is one to four dot-separated groups of digits.</returns>
function IsValidVersionString( const AVersion: string ): Boolean;
begin

  Result := ( not AVersion.IsEmpty ) and ( Length( AVersion ) <= 32 ) and
    TRegEx.IsMatch( AVersion, '^\d+(\.\d+){0,3}$' );

end;

/// <summary>
///   Returns a private copy of the registered secrets, taken under the lock.
/// </summary>
/// <returns>A copy of the currently registered access tokens.</returns>
function GetKnownSecrets: TArray<string>;
begin

  GSecretsLock.Enter;

  try
    SetLength( Result, Length( GKnownSecrets ) );

    for var iI := 0 to High( GKnownSecrets ) do
      Result[ iI ] := GKnownSecrets[ iI ];
  finally
    GSecretsLock.Leave;
  end;

end;

/// <summary>
///   Records the access tokens currently in use so that log and error text can
///   be masked by exact match.
/// </summary>
/// <param name="ACodebergToken">The Codeberg access token, or empty.</param>
/// <param name="AGitHubToken">The GitHub access token, or empty.</param>
procedure RegisterKnownSecrets( const ACodebergToken, AGitHubToken: string );
begin

  GSecretsLock.Enter;

  try
    SetLength( GKnownSecrets, 0 );

    if ( not ACodebergToken.Trim.IsEmpty ) then
      GKnownSecrets := GKnownSecrets + [ ACodebergToken.Trim ];

    if ( not AGitHubToken.Trim.IsEmpty ) then
      GKnownSecrets := GKnownSecrets + [ AGitHubToken.Trim ];
  finally
    GSecretsLock.Leave;
  end;

end;

/// <summary>
///   Returns a quoted absolute path to git.exe, or the bare name if it cannot
///   be found on PATH ( in which case Git is almost certainly not installed and
///   the resulting failure is the correct outcome ).
/// </summary>
function ResolveGitExecutable: string;
var
  SearchBuffer      : array [ 0 .. MAX_PATH ] of Char;
  pFilePart         : PChar;
  iFound            : Cardinal;
begin

  GGitExeLock.Enter;

  try
    if ( not GGitExePath.IsEmpty ) then
      Exit( GGitExePath );

    pFilePart := nil;
    FillChar( SearchBuffer, SizeOf( SearchBuffer ), 0 );

    // SearchPath returns the REQUIRED buffer size when the result does not fit,
    // without writing the buffer, so a non-zero return is not on its own proof
    // that SearchBuffer holds anything.
    iFound := SearchPath( nil, GIT_EXE_NAME, nil, Length( SearchBuffer ), SearchBuffer, pFilePart );

    if ( iFound > 0 ) and ( iFound < Cardinal( Length( SearchBuffer ) ) ) then
      GGitExePath := '"' + string( SearchBuffer ) + '"'
    else
      GGitExePath := GIT_EXE_NAME;

    Result := GGitExePath;
  finally
    GGitExeLock.Leave;
  end;

end;

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
  hJob              : THandle;
  JobLimits         : JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
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

    // Bounded on both axes. Without the read cap a child producing output
    // continuously keeps this loop resident, so the caller's timeout is never
    // re-evaluated; without the byte cap the accumulator doubles indefinitely.
    var iReads := 0;

    while ( iReads < MAX_READS_PER_DRAIN ) and ( iAccumulated < MAX_CAPTURED_BYTES ) and
          PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
    begin
      Inc( iReads );

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
  hJob := 0;
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
    //
    // LC_ALL/LANG are pinned to C because several decisions here are made by
    // matching Git's human-readable output ( "nothing to commit", "stale info" ).
    // On a localised Git those matches silently stop working, turning a benign
    // no-op into a reported failure and suppressing the force-push warning.
    sEnvironment := BuildChildEnvironment(
      [ 'GIT_TERMINAL_PROMPT=0',
        'GCM_INTERACTIVE=Never',
        'GIT_ASKPASS=',
        'SSH_ASKPASS=',
        'GIT_OPTIONAL_LOCKS=0',
        'LC_ALL=C',
        'LANG=C' ] );
    EnvBlock := sEnvironment.ToCharArray;

    // A Job Object with KILL_ON_JOB_CLOSE makes the timeout path able to take
    // the whole process tree down. git.exe routinely spawns git-remote-https,
    // ssh or a credential helper, and terminating only the direct child leaves
    // those running — one orphan per repository per refresh against an
    // unreachable remote, each still holding the inherited pipe.
    hJob := CreateJobObject( nil, nil );

    if hJob <> 0 then
    begin
      FillChar( JobLimits, SizeOf( JobLimits ), 0 );
      JobLimits.BasicLimitInformation.LimitFlags := JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
      SetInformationJobObject( hJob, JobObjectExtendedLimitInformation, @JobLimits, SizeOf( JobLimits ) );
    end;

    // Serialise the spawn. bInheritHandles duplicates every inheritable handle
    // this process holds into the child, so two workers in this window at once
    // cross-inherit each other's pipes.
    GProcessSpawnLock.Enter;

    try
      lProcessStarted := CreateProcess(
        nil,
        PChar( @MutableCommand[ 0 ] ),
        nil,
        nil,
        True,
        CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT or CREATE_SUSPENDED,
        @EnvBlock[ 0 ],
        pWorkingDir,
        StartupInfo,
        ProcessInfo
        );
    finally
      GProcessSpawnLock.Leave;
    end;

    if ( not lProcessStarted ) then
      Exit;

    // Assign before the first instruction runs, so nothing can escape the job.
    if hJob <> 0 then
      AssignProcessToJobObject( hJob, ProcessInfo.hProcess );

    ResumeThread( ProcessInfo.hThread );

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
        // Closing the job terminates the child AND every descendant it
        // started; TerminateProcess alone would orphan them.
        if hJob <> 0 then
        begin
          CloseHandle( hJob );
          hJob := 0;
        end;
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

    if hJob <> 0 then
      CloseHandle( hJob );
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

    // Authorization headers, in either the Gitea 'token' or the OAuth 'Bearer'
    // form. These reach the log through API error text.
    Result := TRegEx.Replace( Result, '(?i)(authorization\s*:\s*(?:token|bearer)\s+)\S+', '$1***' );

    // A Codeberg/Gitea/Forgejo token is 40 lowercase hex with NO prefix, which
    // is indistinguishable from the commit hashes Git prints constantly — so it
    // cannot be matched by shape. Masking the live values by literal comparison
    // is exact, and covers whatever format a future provider uses.
    for var sSecret in GetKnownSecrets do
    begin
      if Length( sSecret ) >= MIN_REDACTABLE_SECRET_LENGTH then
        Result := StringReplace( Result, sSecret, '***', [ rfReplaceAll, rfIgnoreCase ] );
    end;
  except
    on E: Exception do
      ;                                 // Redaction must never break logging
  end;

end;

/// <summary>
///   Encrypts a secret with DPAPI ( current user scope, application entropy )
///   and returns it as a prefixed Base64 string.
/// </summary>
/// <remarks>
///   There is deliberately NO plain-text fallback. The previous version
///   returned the secret unchanged when DPAPI failed, so a failure — an
///   unloaded profile under RunAs /netonly, a scheduled task, a damaged
///   protect store — wrote a live access token into the roaming config in
///   clear, unmarked, and every later load accepted it as a legacy value. The
///   degraded state was permanent and completely silent. The caller must now
///   check <paramref name="bProtected"/> and refuse to persist on False.
/// </remarks>
/// <param name="ASecret">The secret to protect.</param>
/// <param name="bProtected">
///   Receives True when the returned value is genuinely encrypted. False means
///   nothing usable was produced and the secret must NOT be written anywhere.
/// </param>
/// <returns>The protected value, or an empty string when protection failed.</returns>
function ProtectSecret( const ASecret: string; out bProtected: Boolean ): string;
var
  InBlob            : TDataBlob;
  OutBlob           : TDataBlob;
  EntropyBlob       : TDataBlob;
  Plain             : TBytes;
  Cipher            : TBytes;
  Entropy           : TBytes;
begin

  Result     := '';
  bProtected := False;

  if ASecret.IsEmpty then
  begin
    bProtected := True;                 // Nothing to protect is not a failure
    Exit;
  end;

  if ASecret.StartsWith( SECRET_PREFIX ) then
  begin
    bProtected := True;                 // Already protected — pass it through
    Exit( ASecret );
  end;

  Plain   := TEncoding.UTF8.GetBytes( ASecret );
  Entropy := TEncoding.UTF8.GetBytes( SECRET_ENTROPY );

  if Length( Plain ) = 0 then
    Exit;

  try
    InBlob.cbData       := Length( Plain );
    InBlob.pbData       := @Plain[ 0 ];
    EntropyBlob.cbData  := Length( Entropy );
    EntropyBlob.pbData  := @Entropy[ 0 ];
    OutBlob.cbData      := 0;
    OutBlob.pbData      := nil;

    // CRYPTPROTECT_UI_FORBIDDEN: SaveConfig can be reached from a worker
    // thread, where a DPAPI prompt would hang rather than fail.
    if CryptProtectData( @InBlob, 'GitBatchCommit', @EntropyBlob, nil, nil,
      CRYPTPROTECT_UI_FORBIDDEN, @OutBlob ) then
    begin
      try
        SetLength( Cipher, OutBlob.cbData );

        if OutBlob.cbData > 0 then
          Move( OutBlob.pbData^, Cipher[ 0 ], OutBlob.cbData );

        Result     := SECRET_PREFIX + TNetEncoding.Base64.EncodeBytesToString( Cipher );
        bProtected := True;
      finally
        if OutBlob.cbData > 0 then
          ZeroMemory( OutBlob.pbData, OutBlob.cbData );

        LocalFree( HLOCAL( OutBlob.pbData ) );
      end;
    end;
  finally
    // Do not leave the clear-text token lying in a buffer for a crash dump or
    // an EurekaLog minidump to pick up.
    if Length( Plain ) > 0 then
      FillChar( Plain[ 0 ], Length( Plain ), 0 );
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
  EntropyBlob       : TDataBlob;
  Cipher            : TBytes;
  Plain             : TBytes;
  Entropy           : TBytes;
  bDecrypted        : Boolean;
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

  Entropy            := TEncoding.UTF8.GetBytes( SECRET_ENTROPY );
  InBlob.cbData      := Length( Cipher );
  InBlob.pbData      := @Cipher[ 0 ];
  EntropyBlob.cbData := Length( Entropy );
  EntropyBlob.pbData := @Entropy[ 0 ];
  OutBlob.cbData     := 0;
  OutBlob.pbData     := nil;

  // Try the current scheme first, then fall back to a blob written BEFORE
  // application entropy was introduced. Without this fallback, upgrading
  // silently fails to decrypt every stored token and loads them as empty -
  // and the next save then overwrites the stored ciphertext with nothing,
  // losing the credential outright. A value recovered here is re-written with
  // entropy by the next SaveConfig.
  bDecrypted := CryptUnprotectData( @InBlob, nil, @EntropyBlob, nil, nil,
    CRYPTPROTECT_UI_FORBIDDEN, @OutBlob );

  if ( not bDecrypted ) then
  begin
    OutBlob.cbData := 0;
    OutBlob.pbData := nil;
    bDecrypted := CryptUnprotectData( @InBlob, nil, nil, nil, nil,
      CRYPTPROTECT_UI_FORBIDDEN, @OutBlob );
  end;

  if bDecrypted then
  begin
    try
      SetLength( Plain, OutBlob.cbData );

      if OutBlob.cbData > 0 then
        Move( OutBlob.pbData^, Plain[ 0 ], OutBlob.cbData );

      Result := TEncoding.UTF8.GetString( Plain );
    finally
      if OutBlob.cbData > 0 then
        ZeroMemory( OutBlob.pbData, OutBlob.cbData );

      LocalFree( HLOCAL( OutBlob.pbData ) );

      if Length( Plain ) > 0 then
        FillChar( Plain[ 0 ], Length( Plain ), 0 );
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
  FConfigPath        := GetConfigFilePath;
  FReposLock         := TCriticalSection.Create;
  FListsLock         := TCriticalSection.Create;
  FConfigLock        := TCriticalSection.Create;
  FVersionCache      := TDictionary<string, string>.Create;
  FVersionCacheStamp := TDictionary<string, TDateTime>.Create;
  FVersionScanStamp  := TDictionary<string, TDateTime>.Create;
  FConfigLoaded      := False;
  SetLength( FRepos, 0 );

end;

destructor TGitRepoManager.Destroy;
begin

  SetLength( FRepos, 0 );
  FVersionScanStamp.Free;
  FVersionCacheStamp.Free;
  FVersionCache.Free;
  FConfigLock.Free;
  FListsLock.Free;
  FReposLock.Free;
  inherited;

end;

function TGitRepoManager.IndexOfPathLocked( const sPath: string ): Integer;
begin

  Result := -1;

  for var iI := 0 to High( FRepos ) do
  begin
    if SameText( FRepos[ iI ].Path, sPath ) then
      Exit( iI );
  end;

end;

function TGitRepoManager.RemoteExists( const sRepoPath, sRemoteName: string ): Boolean;
var
  sOutput           : string;
begin

  Result := False;

  if ( not ExecuteGitCommand( sRepoPath, 'remote', sOutput, GIT_QUICK_TIMEOUT ) ) then
    Exit;

  for var sLine in Trim( sOutput ).Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty ) do
  begin
    if SameText( Trim( sLine ), sRemoteName ) then
      Exit( True );
  end;

end;

function TGitRepoManager.GetRepoSnapshotByPath( const sPath: string; out ARepo: TRepoInfo ): Boolean;
begin

  Result := False;
  FReposLock.Enter;

  try
    var iIndex := IndexOfPathLocked( sPath );

    if iIndex < 0 then
      Exit;

    ARepo  := FRepos[ iIndex ];
    Result := True;
  finally
    FReposLock.Leave;
  end;

end;

function TGitRepoManager.SnapshotAll: TRepoInfoArray;
begin

  FReposLock.Enter;

  try
    SetLength( Result, Length( FRepos ) );

    for var iI := 0 to High( FRepos ) do
      Result[ iI ] := FRepos[ iI ];
  finally
    FReposLock.Leave;
  end;

end;

procedure TGitRepoManager.SetRepoSelected( const sPath: string; const bSelected: Boolean );
begin

  FReposLock.Enter;

  try
    var iIndex := IndexOfPathLocked( sPath );

    if iIndex >= 0 then
      FRepos[ iIndex ].Selected := bSelected;
  finally
    FReposLock.Leave;
  end;

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
  AClient.UserAgent := Format( 'GitBatchCommit/%s', [ APP_VERSION ] );
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

  // Honour the configured Git client ONLY when it actually is git.exe. The
  // setting is documented and prompted for as a GUI client ( Fork, TortoiseGit ),
  // and running one of those with Git's arguments never returns: CREATE_NO_WINDOW
  // suppresses a console, not a GUI, so every call burnt the full timeout and
  // every repository reported as an error.
  sGitExe := FGitClientPath.Trim;

  if ( not sGitExe.IsEmpty ) and SameText( ExtractFileName( sGitExe ), GIT_EXE_NAME ) and
     TFile.Exists( sGitExe ) then
    sGitExe := '"' + sGitExe + '"'
  else
    sGitExe := ResolveGitExecutable;

  // -c core.quotepath=false keeps non-ASCII paths readable in porcelain output
  // instead of Git's default octal-escaped, double-quoted form.
  //
  // The rest close holes that are not cosmetic:
  //   status.showUntrackedFiles - a user who sets this to 'no' globally ( a
  //     standard large-tree performance setting ) made a repository holding
  //     nothing but brand-new files report Clean, so it was dropped from the
  //     batch and never committed, silently.
  //   core.fsmonitor / core.sshCommand / core.hooksPath / *.textconv - each of
  //     these names a program Git EXECUTES, and each is read from the scanned
  //     repository's own .git/config. Adding a folder someone sent you is
  //     otherwise arbitrary code execution on the next status refresh, and
  //     Git's safe.directory guard does not fire because the extracted files
  //     are owned by the user running us.
  sFullCommand := sGitExe +
    ' -c core.quotepath=false' +
    ' -c status.showUntrackedFiles=normal' +
    ' -c color.ui=false' +
    ' -c core.fsmonitor=false' +
    ' -c core.sshCommand=' +
    ' -c core.hooksPath=' +
    ' ' + sCommand;

  Result := RunProcessCaptureOutput( sFullCommand, sRepoPath, sOutput, iTimeout );

end;

function TGitRepoManager.ResolveGitDir( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result := '';

  if ExecuteGitCommand( sRepoPath, 'rev-parse --absolute-git-dir', sOutput, GIT_QUICK_TIMEOUT ) then
    Result := Trim( sOutput );

end;

function TGitRepoManager.IsGitWorkTree( const sRepoPath: string ): Boolean;
var
  sOutput           : string;
begin

  Result := ExecuteGitCommand( sRepoPath, 'rev-parse --is-inside-work-tree', sOutput, GIT_QUICK_TIMEOUT ) and
    SameText( Trim( sOutput ), 'true' );

end;

function TGitRepoManager.GetUpstreamSHA( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result := '';

  if ExecuteGitCommand( sRepoPath, 'rev-parse --verify --quiet @{upstream}', sOutput, GIT_QUICK_TIMEOUT ) then
    Result := Trim( sOutput );

  // Anything that is not a plain hex object name is not a lease we can use.
  if ( not TRegEx.IsMatch( Result, '^[0-9a-fA-F]{7,64}$' ) ) then
    Result := '';

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

  // Both fields must be all-digits before either is trusted. stderr is merged
  // into stdout, so a single warning line ahead of the counts would otherwise
  // give Parts[ 0 ] = 'warning:', StrToIntDef would quietly yield 0, and the
  // repository would report Clean while the remote was in fact ahead.
  if ( Length( Parts ) >= 2 ) and TRegEx.IsMatch( Parts[ 0 ], '^\d+$' ) and
     TRegEx.IsMatch( Parts[ 1 ], '^\d+$' ) then
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

  Result := False;

  // Resolve the REAL git directory. Combining the working tree with '.git'
  // only works for an ordinary clone; in a linked worktree or a submodule
  // .git is a file pointing elsewhere, so every probe below silently returned
  // False and the whole conflict guard was blind for those repositories.
  sGitDir := ResolveGitDir( sRepoPath );

  if sGitDir.IsEmpty then
    Exit;

  Result := TFile.Exists( TPath.Combine( sGitDir, 'MERGE_HEAD' ) ) or
    TFile.Exists( TPath.Combine( sGitDir, 'CHERRY_PICK_HEAD' ) ) or
    TFile.Exists( TPath.Combine( sGitDir, 'REVERT_HEAD' ) ) or
    TFile.Exists( TPath.Combine( sGitDir, 'BISECT_LOG' ) ) or
    TFile.Exists( TPath.Combine( sGitDir, 'sequencer' + PathDelim + 'todo' ) ) or
    TDirectory.Exists( TPath.Combine( sGitDir, 'rebase-merge' ) ) or
    TDirectory.Exists( TPath.Combine( sGitDir, 'rebase-apply' ) );

end;

function TGitRepoManager.GetTrackedFileCount( const sRepoPath: string ): Integer;
var
  sOutput           : string;
  Lines             : TArray<string>;
begin

  Result := 0;

  // --deduplicate matters: during a content conflict `ls-files` prints the
  // same path once per index stage, so a conflicted repository reported three
  // times its real tracked-file count.
  if ExecuteGitCommand( sRepoPath, 'ls-files --deduplicate', sOutput ) then
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
      var sStoredCodeberg := JSONRoot.GetValue<string>( 'codeberg_token', '' );
      FCodebergToken := UnprotectSecret( sStoredCodeberg );

      // Load GitHub credentials
      FGitHubUsername := JSONRoot.GetValue<string>( 'github_username', '' );
      var sStoredGitHub := JSONRoot.GetValue<string>( 'github_token', '' );
      FGitHubToken := UnprotectSecret( sStoredGitHub );

      // Remember the raw value ONLY when it was present and unreadable, so the
      // next save preserves it rather than erasing it.
      if ( not sStoredCodeberg.IsEmpty ) and FCodebergToken.IsEmpty then
        FCodebergTokenStored := sStoredCodeberg
      else
        FCodebergTokenStored := '';

      if ( not sStoredGitHub.IsEmpty ) and FGitHubToken.IsEmpty then
        FGitHubTokenStored := sStoredGitHub
      else
        FGitHubTokenStored := '';

      // Register both for redaction. A Codeberg/Gitea token is 40 lowercase hex
      // with no prefix, which is indistinguishable by shape from the commit
      // hashes Git prints constantly, so it can only be masked by exact match.
      RegisterKnownSecrets( FCodebergToken, FGitHubToken );

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
  Repos             : TRepoInfoArray;
  History           : TArray<string>;
  Templates         : TArray<string>;
  sCodebergToken    : string;
  sGitHubToken      : string;
  sTempPath         : string;
  bCodebergOK       : Boolean;
  bGitHubOK         : Boolean;
begin

  Result := False;

  // Everything shared is copied under its lock FIRST, so the JSON is built
  // from private data. This used to walk FRepos with no lock at all while
  // running on the commit worker thread, racing an Add or Remove on the UI
  // thread that reallocates the array body.
  Repos     := SnapshotAll;
  History   := GetCommitHistorySnapshot;
  Templates := GetCommitTemplatesSnapshot;

  // Guard: never overwrite a populated config with an empty repo list because
  // a LOAD failed. Once LoadConfig has succeeded, an empty list is a genuine
  // user action ( they removed the last repository ) and must be persisted —
  // otherwise the removal silently reappears on the next start.
  if ( Length( Repos ) = 0 ) and ( not FConfigLoaded ) and TFile.Exists( FConfigPath ) then
  begin
    Result := True;
    Exit;
  end;

  // Protect the tokens BEFORE anything is written. There is no plain-text
  // fallback: if DPAPI fails, the token is omitted from the file entirely and
  // the caller is told, rather than a live credential being written in clear
  // and every later load quietly accepting it as a legacy value.
  sCodebergToken := ProtectSecret( FCodebergToken, bCodebergOK );
  sGitHubToken   := ProtectSecret( FGitHubToken, bGitHubOK );

  // Preserve a stored secret we were unable to decrypt. Writing '' over it
  // would destroy the only copy, which is exactly what an entropy or account
  // change would otherwise do on the next exit.
  if sCodebergToken.IsEmpty and ( not FCodebergTokenStored.IsEmpty ) then
    sCodebergToken := FCodebergTokenStored;

  if sGitHubToken.IsEmpty and ( not FGitHubTokenStored.IsEmpty ) then
    sGitHubToken := FGitHubTokenStored;

  if ( not bCodebergOK ) or ( not bGitHubOK ) then
  begin
    FLastSaveError := 'Windows could not encrypt the stored access token, so it has NOT ' +
      'been saved. Every other setting was saved normally. Re-enter the token once the ' +
      'problem is resolved; it is never written in plain text.';
    OutputDebugString( PChar( 'GitBatchCommit: ' + FLastSaveError ) );
  end
  else
    FLastSaveError := '';

  JSONRoot := TJSONObject.Create;

  try
    // Save Codeberg credentials. Tokens are encrypted with DPAPI under the
    // current user account, so the config file no longer holds a usable
    // credential if it is copied, backed up or roamed off this machine.
    JSONRoot.AddPair( 'codeberg_username', FCodebergUsername );
    JSONRoot.AddPair( 'codeberg_token', sCodebergToken );

    // Save GitHub credentials
    JSONRoot.AddPair( 'github_username', FGitHubUsername );
    JSONRoot.AddPair( 'github_token', sGitHubToken );

    // Save settings
    JSONRoot.AddPair( 'git_client_path', FGitClientPath );
    JSONRoot.AddPair( 'file_pattern', FFilePattern );
    JSONRoot.AddPair( 'delphi_indexer_path', FDelphiIndexerPath );

    // Save commit history
    JSONHistoryArray := TJSONArray.Create;

    for var iI := 0 to High( History ) do
      JSONHistoryArray.Add( History[ iI ] );

    JSONRoot.AddPair( 'commit_history', JSONHistoryArray );

    // Save commit templates
    JSONHistoryArray := TJSONArray.Create;

    for var iI := 0 to High( Templates ) do
      JSONHistoryArray.Add( Templates[ iI ] );

    JSONRoot.AddPair( 'commit_templates', JSONHistoryArray );

    // Save repositories
    JSONArray := TJSONArray.Create;

    for var iI := 0 to High( Repos ) do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair( 'path', Repos[ iI ].Path );
      JSONObj.AddPair( 'group', Repos[ iI ].Group );
      JSONArray.AddElement( JSONObj );
    end;

    JSONRoot.AddPair( 'repositories', JSONArray );

    // One writer at a time, and write-then-replace rather than truncate in
    // place. Two threads could previously collide on the file, and an
    // interrupted write left a truncated config - taking the repository list
    // and both stored tokens with it.
    FConfigLock.Enter;

    try
      sTempPath := FConfigPath + '.tmp';

      try
        TFile.WriteAllText( sTempPath, JSONRoot.Format, TEncoding.UTF8 );

        if TFile.Exists( FConfigPath ) then
          TFile.Delete( FConfigPath );

        TFile.Move( sTempPath, FConfigPath );
        Result := True;
      except
        on E: Exception do
        begin
          // A read-only filesystem, locked file, or missing directory makes config
          // unsaveable — surface that to the debugger so the user can find out why.
          FLastSaveError := Format( 'Could not save the configuration to "%s": %s',
            [ FConfigPath, E.Message ] );
          OutputDebugString( PChar( 'GitBatchCommit: ' + FLastSaveError ) );

          if TFile.Exists( sTempPath ) then
          begin
            try
              TFile.Delete( sTempPath );
            except
              on EInner: EInOutError do
                ;                       // Nothing more to do about a stale temp file
            end;
          end;
        end;
      end;
    finally
      FConfigLock.Leave;
    end;
  finally
    JSONRoot.Free;
  end;

end;

procedure TGitRepoManager.SetCodebergToken( const AValue: string );
begin

  FCodebergToken := SanitiseTokenValue( AValue );

  // An explicit assignment supersedes anything preserved from the file,
  // including an explicit clear.
  FCodebergTokenStored := '';
  RegisterKnownSecrets( FCodebergToken, FGitHubToken );

end;

procedure TGitRepoManager.SetGitHubToken( const AValue: string );
begin

  FGitHubToken := SanitiseTokenValue( AValue );
  FGitHubTokenStored := '';
  RegisterKnownSecrets( FCodebergToken, FGitHubToken );

end;

function TGitRepoManager.GetCommitHistorySnapshot: TArray<string>;
begin

  FListsLock.Enter;

  try
    SetLength( Result, Length( FCommitHistory ) );

    for var iI := 0 to High( FCommitHistory ) do
      Result[ iI ] := FCommitHistory[ iI ];
  finally
    FListsLock.Leave;
  end;

end;

function TGitRepoManager.GetCommitTemplatesSnapshot: TArray<string>;
begin

  FListsLock.Enter;

  try
    SetLength( Result, Length( FCommitTemplates ) );

    for var iI := 0 to High( FCommitTemplates ) do
      Result[ iI ] := FCommitTemplates[ iI ];
  finally
    FListsLock.Leave;
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

  RefreshStatus( sPath );
  SaveConfig;

end;

procedure TGitRepoManager.RemoveRepository( const sPath: string );
begin

  FReposLock.Enter;

  try
    var iIndex := IndexOfPathLocked( sPath );

    if iIndex < 0 then
      Exit;

    for var iI := iIndex to High( FRepos ) - 1 do
      FRepos[ iI ] := FRepos[ iI + 1 ];

    SetLength( FRepos, Length( FRepos ) - 1 );

    // Drop the cached version data too. Without this the three dictionaries
    // only ever grow, and a repository re-added later would be handed the
    // version it had when it was removed.
    FVersionCache.Remove( sPath );
    FVersionCacheStamp.Remove( sPath );
    FVersionScanStamp.Remove( sPath );
  finally
    FReposLock.Leave;
  end;

  SaveConfig;

end;

procedure TGitRepoManager.RefreshStatus( const sRepoPath: string );
var
  sStatusOutput     : string;
  sBranch           : string;
  sVersion          : string;
  sStatusText       : string;
  sRemoteSHA        : string;
  Status            : TRepoStatus;
  Provider          : TRemoteProvider;
  iTracked          : Integer;
  iModified         : Integer;
  iAhead            : Integer;
  iBehind           : Integer;
  bArtifactOnly     : Boolean;
  Lines             : TArray<string>;
begin

  // All the (slow, blocking) Git work happens outside the lock; results are
  // published under it by path match. Holding the lock across a git invocation
  // would serialise the whole parallel refresh, and touching FRepos without it
  // races with Add/Remove, which call SetLength and can move the array body
  // out from under a worker thread.
  if sRepoPath.Trim.IsEmpty then
    Exit;

  sBranch       := GetRepoBranch( sRepoPath );
  iModified     := 0;
  iAhead        := 0;
  iBehind       := 0;
  bArtifactOnly := False;

  // Ask Git whether this is a working tree rather than looking for a .git
  // FOLDER. In a linked worktree or a submodule .git is a file, and the folder
  // test reported every one of them as an error, permanently.
  if ( not IsGitWorkTree( sRepoPath ) ) then
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
    // Ask how the branch stands against its upstream BEFORE deciding the
    // status. This used to live inside the clean-tree branch below, so a
    // repository that was both modified and behind could only ever report
    // "Modified" - Commit & Push then committed and drove straight into a
    // non-fast-forward rejection, with nothing in the list having warned that
    // a pull was owed.
    GetAheadBehind( sRepoPath, iAhead, iBehind );

    if HasUnmergedPaths( sStatusOutput ) or HasOperationInProgress( sRepoPath ) then
      Status := rsConflicted
    else if ( not sStatusOutput.IsEmpty ) and ( not AllChangesAreBuildArtifacts( sStatusOutput ) ) then
      Status := rsModified
    else
    begin
      // Remember that changes existed but were all build output, so the UI can
      // say the repository was SKIPPED. Scoring it Clean and saying nothing let
      // a ticked repository drop out of a batch while the summary still
      // reported "n of n successful".
      bArtifactOnly := ( not sStatusOutput.IsEmpty );
      // Working tree is clean (or only build output changed). The branch may
      // still differ from its upstream in either direction — a repository whose
      // work is committed but not pushed used to report as Clean, with nothing
      // anywhere in the UI saying the remote was behind. The counts are taken
      // above now, for every repository rather than only the clean ones.
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

  iTracked   := GetTrackedFileCount( sRepoPath );
  Provider   := DetectRemoteProvider( GetRemoteOriginURL( sRepoPath ) );
  sVersion   := GetProjectVersion( sRepoPath );

  // Capture where the upstream stands as the user is being shown this row.
  // ForcePushRepository names it as an explicit lease, so a force push is
  // refused when the remote has moved on since — which a bare
  // --force-with-lease does NOT do here, because the fetch above has already
  // advanced the remote-tracking ref past anything the user ever saw.
  sRemoteSHA := GetUpstreamSHA( sRepoPath );

  // Carry the commit counts in the display text - the columns are fixed, and
  // "Push Required (3)" is far more useful than "Push Required" alone.
  sStatusText := RepoStatusToString( Status );

  case Status of
    rsPullRequired: sStatusText := Format( '%s (%d)', [ sStatusText, iBehind ] );
    rsPushRequired: sStatusText := Format( '%s (%d)', [ sStatusText, iAhead ] );
    rsDiverged: sStatusText := Format( '%s (+%d/-%d)', [ sStatusText, iAhead, iBehind ] );
  end;

  // Say so when the working tree DOES have changes but every one of them is
  // build output. The repository scores as clean and is therefore skipped by
  // Commit & Push, which filters to Modified - and a silent skip while the
  // summary still reports "n of n successful" is how work goes missing.
  if bArtifactOnly then
    sStatusText := sStatusText + ' - build output only';

  // A modified or conflicted repository still carries the Status slot for its
  // working tree, so the pull it owes has nowhere else to appear. Say it in the
  // text, or the row looks ready to commit when it is not.
  if ( Status in [ rsModified, rsConflicted ] ) and ( iBehind > 0 ) then
    sStatusText := Format( '%s - %d to pull', [ sStatusText, iBehind ] );

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
        FRepos[ j ].RemoteSHA := sRemoteSHA;
        FRepos[ j ].ArtifactOnlyChanges := bArtifactOnly;
        FRepos[ j ].BehindCount := iBehind;
        FRepos[ j ].AheadCount := iAhead;
        Break;
      end;
    end;
  finally
    FReposLock.Leave;
  end;

end;

procedure TGitRepoManager.RefreshAllStatus;
begin

  for var rRepo in SnapshotAll do
    RefreshStatus( rRepo.Path );

end;

function TGitRepoManager.CommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sTempFile         : string;
  sVersion          : string;
  sTagName          : string;
  sBranch           : string;
  Repo              : TRepoInfo;
  iAhead            : Integer;
  iBehind           : Integer;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sLog := 'Repository is no longer in the list';
    Exit;
  end;

  sLog := Format( '=== %s ===%s', [ Repo.Name, sLineBreak ] );

  // Refuse outright while a merge/rebase/cherry-pick is unfinished or any path
  // is unmerged. `add -A` would stage files still containing conflict markers,
  // and the commit that followed would push them to the remote.
  //
  // These are SEPARATE refusals on purpose. Written as one `and` chain, a
  // `git status` that failed or timed out made the whole condition False and
  // execution fell straight through to `add -A` - so the guard was skipped in
  // exactly the situation it exists for. An indeterminate state must refuse,
  // never proceed.
  if HasOperationInProgress( Repo.Path ) then
  begin
    sLog := sLog + 'Refused to commit - the repository has an unfinished merge, rebase, ' +
      'cherry-pick, revert or bisect. Finish or abort it first.' + sLineBreak;
    Exit;
  end;

  if ( not ExecuteGitCommand( Repo.Path, 'status --porcelain', sOutput ) ) then
  begin
    sLog := sLog + 'Refused to commit - could not determine the repository state: ' +
      Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  if HasUnmergedPaths( sOutput ) then
  begin
    sLog := sLog + 'Refused to commit - the repository has unresolved conflicts. Resolve ' +
      'them first (Resolve Conflicts, or finish the operation in a Git client).' + sLineBreak;
    Exit;
  end;

  // A detached HEAD accepts `add` and `commit` perfectly happily and then fails
  // at the push, leaving the work in a commit reachable only from the reflog.
  // GetIncomingChanges already refused this case; this did not.
  sBranch := GetCurrentBranch( Repo.Path );

  if sBranch.IsEmpty then
  begin
    sLog := sLog + 'Refused to commit - HEAD is detached or the branch is unborn. ' +
      'Check out a branch first.' + sLineBreak;
    Exit;
  end;

  // Refuse while the branch is behind its upstream. Committing first and
  // discovering it at the push is far worse than refusing: the push is rejected
  // non-fast-forward, the work is already committed, and the repository is left
  // DIVERGED - which then has to be rebased or merged by hand, once per
  // repository. Refusing here leaves the changes uncommitted and the repository
  // exactly as it was, so Pull Selected is enough to make it pushable.
  GetAheadBehind( Repo.Path, iAhead, iBehind );

  if iBehind > 0 then
  begin
    sLog := sLog + Format( 'Refused to commit - the branch is %d commit(s) behind %s. ' +
      'Pull first (Pull Selected), then commit.%s', [ iBehind, sBranch, sLineBreak ] );
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

    if ( not ExecuteGitCommand( Repo.Path, 'add -- ' + FFilePattern, sOutput ) ) then
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
    // Nothing staged is not a failure. `git commit` exits 1 in that case, and
    // treating that as fatal meant a repository whose work was already
    // committed but never pushed could not be pushed by Commit & Push at all.
    if ExecuteGitCommand( Repo.Path, 'diff --cached --quiet', sOutput ) then
      sLog := sLog + 'Nothing staged - skipping the commit' + sLineBreak
    else if ( not ExecuteGitCommand( Repo.Path, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput ) ) then
    begin
      sLog := sLog + 'Commit failed: ' + Trim( sOutput ) + sLineBreak;
      Exit;
    end
    else
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

  // Create and push version tag if .dproj version exists. The scan TTL is
  // bypassed here: this value decides the tag that gets PUSHED, and a version
  // bumped seconds before the commit would otherwise be tagged with the
  // previous number, or skipped entirely because that tag already exists.
  sVersion := GetProjectVersion( Repo.Path, True );

  if ( not sVersion.IsEmpty ) then
  begin
    sTagName := 'v' + sVersion;

    // `--` terminates option parsing. The version is read verbatim out of a
    // .dproj in the repository being committed, so without it a crafted
    // FileVersion could append arguments of its own to the push below.
    // IsValidVersionString is the primary guard; this is the second one.
    if ExecuteGitCommand( Repo.Path, Format( 'tag -l -- "%s"', [ sTagName ] ), sOutput ) then
    begin
      if Trim( sOutput ).IsEmpty then
      begin
        // Tag doesn't exist - create it
        if ExecuteGitCommand( Repo.Path, Format( 'tag -a "%s" -m "Version %s"', [ sTagName, sVersion ] ), sOutput ) then
        begin
          sLog := sLog + Format( 'Created tag: %s', [ sTagName ] ) + sLineBreak;

          // Push the tag
          if ExecuteGitCommand( Repo.Path, Format( 'push origin -- "%s"', [ sTagName ] ), sOutput ) then
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
  RefreshStatus( Repo.Path );

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

  // Compare the HOST, not the whole string. A substring test classified
  // https://gitea.internal/mirrors/github.com-backup.git as GitHub, which then
  // aimed a visibility change at api.github.com for a repository that does not
  // live there.
  sLower := ExtractURLHost( sOriginURL );

  if SameText( sLower, 'codeberg.org' ) then
    Result := rpCodeberg
  else if SameText( sLower, 'github.com' ) or SameText( sLower, 'www.github.com' ) then
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

  // Order matters, and it was wrong. Testing for '.git' first fails on
  // '.../repo.git/' because that ends with a slash, and the suffix was then
  // never re-tested - so sRepo came back as 'repo.git' and every API call 404'd
  // with "not found or no permission".
  while sURL.EndsWith( '/' ) do
    sURL := Copy( sURL, 1, Length( sURL ) - 1 );

  if sURL.EndsWith( '.git', True ) then
    sURL := Copy( sURL, 1, Length( sURL ) - 4 );

  while sURL.EndsWith( '/' ) do
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

function TGitRepoManager.GetProjectVersion( const sRepoPath: string; const bForceRescan: Boolean ): string;
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
  if ( not bForceRescan ) then
  begin
    FReposLock.Enter;

    try
      if FVersionScanStamp.TryGetValue( sKey, ScanStamp ) and
         ( SecondsBetween( Now, ScanStamp ) < VERSION_SCAN_TTL_SECONDS ) and
         FVersionCache.TryGetValue( sKey, CachedVersion ) then
        Exit( CachedVersion );
    finally
      FReposLock.Leave;
    end;
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

  // The stamp must match EXACTLY, not merely be at or above the newest write.
  // A '>=' test can never go backwards, so deleting the newest .dproj - or
  // checking out a branch that lacks it - pinned the cached version forever
  // and CommitAndPush went on tagging with it.
  if ( not bForceRescan ) then
  begin
    FReposLock.Enter;

    try
      if FVersionCacheStamp.TryGetValue( sKey, CachedStamp ) and
         SameValue( CachedStamp, NewestDprojWrite ) and
         FVersionCache.TryGetValue( sKey, CachedVersion ) then
      begin
        FVersionScanStamp.AddOrSetValue( sKey, Now );
        Exit( CachedVersion );
      end;
    finally
      FReposLock.Leave;
    end;
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
            sVersion := Trim( sLine.Substring( iPos, iEndPos - iPos ) );

            // Reject anything that is not a plain dotted number. This value
            // comes verbatim out of a .dproj belonging to the repository being
            // committed, and CommitAndPush interpolates it into `git tag` and
            // `git push` command lines — where an embedded quote closes the
            // quoting and the remainder becomes extra arguments to Git.
            if ( not IsValidVersionString( sVersion ) ) then
              Continue;

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

  // '.exe' and '.hpp' are deliberately absent. Plenty of repositories track
  // tooling executables on purpose ( this one has a tools folder ), and a .hpp
  // is a source header in any C or C++ project. Treating either as build
  // output made a repository whose ONLY change was such a file score as clean,
  // which silently dropped it from the batch.
  if ( sExt = '.dcu' ) or ( sExt = '.dll' ) or
     ( sExt = '.bpl' ) or ( sExt = '.dcp' ) or ( sExt = '.dres' ) or
     ( sExt = '.local' ) or ( sExt = '.identcache' ) or
     ( sExt = '.dsk' ) or ( sExt = '.tds' ) or ( sExt = '.map' ) or
     ( sExt = '.drc' ) or ( sExt = '.rsm' ) or ( sExt = '.obj' ) or
     ( sExt = '.o' ) or ( sExt = '.projdata' ) or
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
  // 'android' and 'linux64' are ALSO ordinary source folder names in a
  // cross-platform project, so they only count as build output when a build
  // configuration folder sits directly beneath them ( Android/Debug,
  // Linux64/Release ). The Delphi-only platform folders keep the plain test.
  for var sDir in [ 'win32/', 'win64/', '__history/', '__recovery/',
                    'osx32/', 'osx64/', 'iosdevice' ] do
  begin
    if sLower.StartsWith( sDir ) or sLower.Contains( '/' + sDir ) then
      Exit( True );
  end;

  for var sDir in [ 'android/', 'android64/', 'linux64/' ] do
  begin
    for var sCfg in [ 'debug/', 'release/' ] do
    begin
      if sLower.StartsWith( sDir + sCfg ) or sLower.Contains( '/' + sDir + sCfg ) then
        Exit( True );
    end;
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

  for sLine in Lines do
  begin
    // Porcelain v1 is 'XY <path>', and for a rename 'XY <old> -> <new>'.
    // Anything shorter than that is not a line we understand, and an
    // unparseable line must count AGAINST the all-artifacts conclusion rather
    // than be skipped - scoring a repository clean is what removes it from the
    // batch.
    if Length( sLine ) < 4 then
      Exit;

    sFileName := Copy( sLine, 4, MaxInt );

    // A rename has to be judged on BOTH sides. Testing only the destination
    // meant 'R  src/Foo.pas -> Win64/Foo.pas' looked like an artifact, so the
    // deletion of src/Foo.pas was never committed.
    if sFileName.Contains( ' -> ' ) then
    begin
      var iArrow := Pos( ' -> ', sFileName );

      if ( not IsBuildArtifact( UnquotePorcelainPath( Copy( sFileName, 1, iArrow - 1 ) ) ) ) then
        Exit;

      sFileName := Copy( sFileName, iArrow + 4, MaxInt );
    end;

    if ( not IsBuildArtifact( UnquotePorcelainPath( sFileName ) ) ) then
      Exit;                             // Found a real change
  end;

  // All changes are build artifacts
  Result := True;

end;

function TGitRepoManager.GetRepoProvider( const sRepoPath: string ): TRemoteProvider;
var
  sOriginURL        : string;
  Repo              : TRepoInfo;
begin

  Result := rpNone;

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
    Exit;

  sOriginURL := GetRemoteOriginURL( Repo.Path );
  Result := DetectRemoteProvider( sOriginURL );

end;

function TGitRepoManager.SetRepositoryVisibility( const sRepoPath: string; const lPrivate: Boolean;
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

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sError := 'Repository is no longer in the list';
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

function TGitRepoManager.PullRepository( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sLog := 'Repository is no longer in the list';
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

function TGitRepoManager.ResolveConflictsKeepLocal( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sLog := 'Repository is no longer in the list';
    Exit;
  end;

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

function TGitRepoManager.PushRepository( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sLog := 'Repository is no longer in the list';
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

function TGitRepoManager.ForcePushRepository( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sBranch           : string;
  sCommand          : string;
  Repo              : TRepoInfo;
begin

  Result := False;
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sLog := 'Repository is no longer in the list';
    Exit;
  end;

  sBranch := GetCurrentBranch( Repo.Path );

  if sBranch.IsEmpty then
  begin
    sLog := 'Force push refused - HEAD is detached or the branch is unborn.';
    Exit;
  end;

  // A bare --force-with-lease is NOT sufficient here, and the comment that
  // used to sit in its place was wrong. The lease compares against the
  // remote-tracking ref, and this application runs `git fetch` on every status
  // refresh - so by the time the user clicks Force Push, the ref has already
  // been advanced to include the very commits the lease is supposed to
  // protect. The lease passes and those commits are destroyed.
  //
  // RemoteSHA is the upstream commit captured when this row's status was last
  // determined, i.e. what the user was actually shown. Naming it explicitly
  // makes Git refuse if the remote has moved since.
  if Repo.RemoteSHA.IsEmpty then
    sCommand := Format( 'push --force-with-lease origin -- %s', [ sBranch ] )
  else
    sCommand := Format( 'push --force-with-lease=%s:%s origin -- %s',
      [ sBranch, Repo.RemoteSHA, sBranch ] );

  if ( not ExecuteGitCommand( Repo.Path, sCommand, sOutput ) ) then
  begin
    sLog := 'Force push failed: ' + Trim( sOutput );

    if sOutput.Contains( 'stale info' ) or sOutput.Contains( 'rejected' ) then
      sLog := sLog + sLineBreak +
        'The remote has moved since this repository''s status was last refreshed. ' +
        'Refresh and review the incoming commits before force pushing - pushing now ' +
        'would destroy them.';

    Exit;
  end;

  sLog := Trim( sOutput );

  if sLog.IsEmpty then
    sLog := 'Force pushed successfully';

  Result := True;

end;

function TGitRepoManager.CreateBackupBranch( const sRepoPath: string; out sBranchName: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  Repo              : TRepoInfo;
begin

  Result := False;
  sBranchName := '';
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sLog := 'Repository is no longer in the list';
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

function TGitRepoManager.GetIncomingChanges( const sRepoPath: string; out sChanges: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sBranch           : string;
  Repo              : TRepoInfo;
begin

  Result := False;
  sChanges := '';
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sLog := 'Repository is no longer in the list';
    Exit;
  end;

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

  // Compare against the branch's CONFIGURED upstream, not a hard-coded
  // origin/<same name>. A branch tracking upstream/main, or a local 'feature'
  // tracking origin/dev, produced a wrong diff or an outright failure that was
  // then reported as "no incoming changes" - the opposite of the truth.
  // GetAheadBehind already used @{upstream}; this did not.
  if ( not ExecuteGitCommand( sRepoPath, 'diff --stat HEAD..@{upstream}', sOutput ) ) then
  begin
    // No upstream for this branch. Not an error, but say WHICH case it was
    // rather than letting the caller imply "already up to date".
    sChanges := '';
    sLog := Format( 'Branch "%s" has no upstream configured - nothing to preview', [ sBranch ] );
    Result := True;
    Exit;
  end;

  sChanges := Trim( sOutput );
  sLog := 'Fetched successfully';
  Result := True;

end;

function TGitRepoManager.MigrateRepository( const sRepoPath: string; const TargetProvider: TRemoteProvider;
  const sNewRepoName, sDescription: string; const lPrivate: Boolean;
  out sNewRemoteURL, sError, sLog: string ): Boolean;
var
  sCurrentOrigin    : string;
  CurrentProvider   : TRemoteProvider;
  sOutput           : string;
  sTargetName       : string;
  sOldRemoteName    : string;
  bRenamed          : Boolean;
  bOriginAdded      : Boolean;
  lOriginExisted    : Boolean;
  Repo              : TRepoInfo;
begin

  Result := False;
  sNewRemoteURL := '';
  sError := '';
  sLog := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
  begin
    sError := 'Repository is no longer in the list';
    Exit;
  end;

  if ( not ( TargetProvider in [ rpCodeberg, rpGitHub ] ) ) then
  begin
    sError := 'Target provider must be Codeberg or GitHub';
    Exit;
  end;

  bRenamed     := False;
  bOriginAdded := False;

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

  // Step 3: Preserve the old origin under a provider-named alias, then swap.
  //
  // Everything from here to the end is reversible: if any step fails, the
  // remotes are put back exactly as they were. Without that, a failure between
  // the rename and the push left the repository with origin pointing at an
  // empty new remote while the real one hid under an alias - and every
  // subsequent Commit & Push then pushed to the wrong place.
  if lOriginExisted then
  begin
    case CurrentProvider of
      rpCodeberg: sOldRemoteName := 'codeberg';
      rpGitHub:   sOldRemoteName := 'github';
    else
      sOldRemoteName := 'old-origin';
    end;

    // Never silently destroy an existing remote of that name - a mirror setup
    // with a remote literally called 'github' or 'codeberg' is completely
    // ordinary, and removing it took its refspecs and pushURL with it. Pick an
    // unused suffix instead.
    if RemoteExists( sRepoPath, sOldRemoteName ) then
    begin
      var iSuffix := 2;

      while RemoteExists( sRepoPath, Format( '%s-%d', [ sOldRemoteName, iSuffix ] ) ) and ( iSuffix < 100 ) do
        Inc( iSuffix );

      sLog := sLog + Format( 'A remote named "%s" already exists and has been left alone.',
        [ sOldRemoteName ] ) + sLineBreak;
      sOldRemoteName := Format( '%s-%d', [ sOldRemoteName, iSuffix ] );
    end;

    if ( not ExecuteGitCommand( sRepoPath, Format( 'remote rename origin %s', [ sOldRemoteName ] ), sOutput ) ) then
    begin
      sError := 'Failed to rename existing origin: ' + Trim( sOutput );
      sLog := sLog + sError + sLineBreak;
      Exit;
    end;

    bRenamed := True;
    sLog := sLog + Format( 'Preserved previous origin as "%s": %s', [ sOldRemoteName, sCurrentOrigin ] ) + sLineBreak;
  end;

  try
    // Step 4: Point origin at the new remote
    if ( not ExecuteGitCommand( sRepoPath, Format( 'remote add origin "%s"', [ sNewRemoteURL ] ), sOutput ) ) then
    begin
      sError := 'Failed to add new origin: ' + Trim( sOutput );
      sLog := sLog + sError + sLineBreak;
      Exit;
    end;

    bOriginAdded := True;
    sLog := sLog + 'Added new origin: ' + sNewRemoteURL + sLineBreak;

    // Step 5: Create local branches for anything that only ever existed on the
    // old remote. `push --all` pushes LOCAL branches only, so without this a
    // branch nobody had checked out was quietly left behind and the migration
    // still reported success.
    if bRenamed then
    begin
      ExecuteGitCommand( sRepoPath, Format( 'fetch %s --prune', [ sOldRemoteName ] ), sOutput );

      if ExecuteGitCommand( sRepoPath, Format(
        'for-each-ref --format=%%(refname:strip=3) refs/remotes/%s', [ sOldRemoteName ] ), sOutput ) then
      begin
        for var sRemoteBranch in Trim( sOutput ).Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty ) do
        begin
          var sTrimmedBranch := Trim( sRemoteBranch );

          if sTrimmedBranch.IsEmpty or SameText( sTrimmedBranch, 'HEAD' ) then
            Continue;

          // Fails harmlessly when the branch already exists locally.
          if ExecuteGitCommand( sRepoPath, Format( 'branch -- %s %s/%s',
            [ sTrimmedBranch, sOldRemoteName, sTrimmedBranch ] ), sOutput ) then
            sLog := sLog + Format( 'Recovered remote-only branch: %s', [ sTrimmedBranch ] ) + sLineBreak;
        end;
      end;
    end;

    // Step 6: Push all branches (sets upstream tracking to the new origin)
    if ( not ExecuteGitCommand( sRepoPath, 'push -u origin --all', sOutput ) ) then
    begin
      sError := 'Failed to push branches: ' + Trim( sOutput );
      sLog := sLog + sError + sLineBreak;
      Exit;
    end;

    sLog := sLog + 'Pushed all branches to new origin' + sLineBreak;

    // Step 7: Push all tags — not fatal if it fails
    if ExecuteGitCommand( sRepoPath, 'push origin --tags', sOutput ) then
      sLog := sLog + 'Pushed all tags to new origin' + sLineBreak
    else
      sLog := sLog + 'Warning: tag push reported: ' + Trim( sOutput ) + sLineBreak;

    // Update the cached provider by PATH. Doing it by a stale index after a
    // long network operation could stamp the wrong repository's record.
    FReposLock.Enter;

    try
      var iCurrent := IndexOfPathLocked( sRepoPath );

      if iCurrent >= 0 then
        FRepos[ iCurrent ].Provider := TargetProvider;
    finally
      FReposLock.Leave;
    end;

    Result := True;
  finally
    if ( not Result ) then
    begin
      // Put the remotes back the way we found them.
      if bOriginAdded then
        ExecuteGitCommand( sRepoPath, 'remote remove origin', sOutput );

      if bRenamed then
        ExecuteGitCommand( sRepoPath, Format( 'remote rename %s origin', [ sOldRemoteName ] ), sOutput );

      sLog := sLog + 'Rolled back: the original remotes have been restored. The repository ' +
        Format( '"%s" created on %s was NOT deleted - remove it manually if it is not wanted.',
        [ sNewRepoName, sTargetName ] ) + sLineBreak;
    end;
  end;

end;

procedure TGitRepoManager.AddToCommitHistory( const sMessage: string );
var
  sTrimmed          : string;
  iNewLen           : Integer;
  bChanged          : Boolean;
begin

  sTrimmed := Trim( sMessage );

  if sTrimmed.IsEmpty then
    Exit;

  // This runs on the COMMIT WORKER thread, via CommitAndPush, while the UI
  // thread reads the same array to build the history menu. Re-sizing a managed
  // array under an unsynchronised reader frees the block it is walking.
  FListsLock.Enter;

  try
    // Already at the top of the history - nothing to record.
    bChanged := ( Length( FCommitHistory ) = 0 ) or ( not SameText( FCommitHistory[ 0 ], sTrimmed ) );

    if ( not bChanged ) then
      Exit;

    // Remove if already exists elsewhere in history
    for var iI := High( FCommitHistory ) downto 0 do
    begin
      if SameText( FCommitHistory[ iI ], sTrimmed ) then
      begin
        for var iJ := iI to High( FCommitHistory ) - 1 do
          FCommitHistory[ iJ ] := FCommitHistory[ iJ + 1 ];

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
    for var iI := High( FCommitHistory ) downto 1 do
      FCommitHistory[ iI ] := FCommitHistory[ iI - 1 ];

    FCommitHistory[ 0 ] := sTrimmed;
  finally
    FListsLock.Leave;
  end;

  if bChanged then
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

  FListsLock.Enter;

  try
    iLen := Length( FCommitTemplates );
    SetLength( FCommitTemplates, iLen + 1 );
    FCommitTemplates[ iLen ] := sTrimmed;
  finally
    FListsLock.Leave;
  end;

  SaveConfig;

end;

procedure TGitRepoManager.RemoveTemplate( const iIndex: Integer );
begin

  FListsLock.Enter;

  try
    if ( iIndex < 0 ) or ( iIndex > High( FCommitTemplates ) ) then
      Exit;

    for var iI := iIndex to High( FCommitTemplates ) - 1 do
      FCommitTemplates[ iI ] := FCommitTemplates[ iI + 1 ];

    SetLength( FCommitTemplates, Length( FCommitTemplates ) - 1 );
  finally
    FListsLock.Leave;
  end;

  SaveConfig;

end;

procedure TGitRepoManager.UpdateTemplate( const iIndex: Integer; const sTemplate: string );
begin

  FListsLock.Enter;

  try
    if ( iIndex < 0 ) or ( iIndex > High( FCommitTemplates ) ) then
      Exit;

    FCommitTemplates[ iIndex ] := Trim( sTemplate );
  finally
    FListsLock.Leave;
  end;

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

procedure TGitRepoManager.SetRepoGroup( const sRepoPath: string; const sGroup: string );
begin

  FReposLock.Enter;

  try
    var iIndex := IndexOfPathLocked( sRepoPath );

    if iIndex < 0 then
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

      // RefreshStatus takes the path, runs Git outside the lock and publishes
      // by path match, so it is safe to call from several threads and is
      // unaffected by the array shifting under it.
      RefreshStatus( Paths[ AIndex ] );

      if Assigned( AIsCancelled ) and AIsCancelled then
        Exit;

      if Assigned( AOnRepoDone ) then
        AOnRepoDone( Names[ AIndex ] );

    end );

end;

initialization

GGitExeLock       := TCriticalSection.Create;
GProcessSpawnLock := TCriticalSection.Create;
GSecretsLock      := TCriticalSection.Create;

finalization

GSecretsLock.Free;
GProcessSpawnLock.Free;
GGitExeLock.Free;

end.
