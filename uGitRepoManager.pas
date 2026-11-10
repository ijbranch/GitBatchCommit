(* GITLAK Software
  ***************************************************************************

    © 2025 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

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

  Copyright (c) 2026 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.9.0

  Part of GitBatchCommit Application

  Description:
    Provides the TGitRepoManager class for managing multiple Git repositories,
    including status detection, configuration persistence, batch commit/push
    operations, and GitHub repository creation.
*)

unit uGitRepoManager;

interface

uses
  Winapi.Windows, Winapi.ShellAPI,

  System.SysUtils, System.StrUtils, System.Classes, System.IOUtils, System.JSON,
  System.Generics.Collections, System.Net.HttpClient, System.Net.HttpClientComponent,
  System.Net.URLClient, System.NetEncoding, System.SyncObjs, System.Math,
  System.DateUtils, System.RegularExpressions;

const
  /// <summary>
  ///   Canonical application version. Update here and only here; surface
  ///   everywhere else ( About dialog, User-Agent header, docs ) by referencing.
  /// </summary>
  APP_VERSION = '1.9.0';

  /// <summary>
  ///   Timeout, in milliseconds, for a Git command that works on the local
  ///   repository only ( 60 seconds ).
  /// </summary>
  GIT_COMMAND_TIMEOUT = 60000;

  /// <summary>
  ///   Timeout, in milliseconds, for a Git command that transfers data or can
  ///   run for as long as the repository is large: push, pull, an operation's
  ///   own fetch, <c>add</c> and <c>commit</c> ( 10 minutes ).
  /// </summary>
  /// <remarks>
  ///   One 60-second limit for everything killed a healthy push of a large
  ///   repository part-way, and reported it as "Operation timed out".
  /// </remarks>
  GIT_NETWORK_TIMEOUT = 600000;

  /// <summary>
  ///   GitHub API base URL.
  /// </summary>
  GITHUB_API_URL    = 'https://api.github.com';

type
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
  ///   Where a repository's remote is hosted.
  /// </summary>
  /// <remarks>
  ///   GitHub is the only host this application can create, delete, migrate to
  ///   or change the visibility of.  Every other host is <c>rpOther</c>: it is
  ///   still committed, pushed and pulled like any remote.
  /// </remarks>
  TRemoteProvider = ( rpNone, rpGitHub, rpOther );

  /// <summary>
  ///   Record containing information about a Git repository.
  /// </summary>
  TRepoInfo = record
    /// <summary>
    ///   Display name: the last segment of the working-tree path.
    /// </summary>
    Name: string;
    /// <summary>
    ///   Working-tree path, without a trailing delimiter.  The identity of the
    ///   repository everywhere in this application.
    /// </summary>
    Path: string;
    /// <summary>
    ///   Current branch for display, or '(unknown)' when it cannot be read.
    /// </summary>
    Branch: string;
    /// <summary>
    ///   Working state as last determined.
    /// </summary>
    Status: TRepoStatus;
    /// <summary>
    ///   The status as shown in the list, with counts and qualifiers.
    /// </summary>
    StatusText: string;
    /// <summary>
    ///   True when the row is ticked in the list.
    /// </summary>
    Selected: Boolean;
    /// <summary>
    ///   Number of files Git tracks in the repository.
    /// </summary>
    TrackedFileCount: Integer;
    /// <summary>
    ///   Number of entries <c>git status --porcelain</c> reported.
    /// </summary>
    ModifiedFileCount: Integer;
    /// <summary>
    ///   Host of the remote that push and pull use.
    /// </summary>
    Provider: TRemoteProvider;
    /// <summary>
    ///   User-assigned group name, or empty.
    /// </summary>
    Group: string;
    /// <summary>
    ///   FileVersion the repository's project builds, or empty.
    /// </summary>
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
    ///   build artefact, so the repository scores as clean. Surfaced so the UI
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
    /// <summary>
    ///   True when the fetch made for the last status refresh failed, so the
    ///   counts and the status describe the remote as it was last fetched.
    /// </summary>
    FetchFailed: Boolean;
    /// <summary>
    ///   True when the current branch has an upstream configured.
    /// </summary>
    HasUpstream: Boolean;
  end;

  /// <summary>
  ///   A list of repository records.
  /// </summary>
  TRepoInfoArray = TArray<TRepoInfo>;

  /// <summary>
  ///   Manages multiple Git repositories for batch operations.
  /// </summary>
  /// <remarks>
  ///   Handles repository configuration persistence, status detection,
  ///   commit/push operations via Git command-line interface, and
  ///   GitHub repository creation.
  ///   <para>
  ///   TRUST MODEL: a repository in the list is trusted.  Git runs its hooks
  ///   and honours its configuration, exactly as it would from a command prompt
  ///   in that folder.
  ///   </para>
  /// </remarks>
  TGitRepoManager = class
  private
    /// <summary>
    ///   The managed repositories.  Guarded by <c>FReposLock</c>.
    /// </summary>
    FRepos: TRepoInfoArray;
    /// <summary>
    ///   Full path of the configuration file.  Set once in the constructor.
    /// </summary>
    FConfigPath: string;
    /// <summary>
    ///   GitHub account name.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FGitHubUsername: string;
    /// <summary>
    ///   GitHub access token, in clear.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FGitHubToken: string;
    /// <summary>
    ///   Path of the external Git client.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FGitClientPath: string;
    /// <summary>
    ///   Glob restricting what is staged.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FFilePattern: string;
    /// <summary>
    ///   Path of delphi-indexer.exe.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FDelphiIndexerPath: string;
    /// <summary>
    ///   Name of the VCL style the user chose; empty means the default style.
    ///   Guarded by <c>FListsLock</c>.
    /// </summary>
    FStyleName: string;
    /// <summary>
    ///   Recent commit messages, newest first.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FCommitHistory: TArray<string>;
    /// <summary>
    ///   Saved commit-message templates.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FCommitTemplates: TArray<string>;
    /// <summary>
    ///   Guards <c>FRepos</c> and the three version caches.
    /// </summary>
    FReposLock: TCriticalSection;
    /// <summary>
    ///   Project version per repository, keyed on the lower-cased path.
    /// </summary>
    FVersionCache: TDictionary<string, string>;
    /// <summary>
    ///   Modification time of the project file each cached version came from.
    /// </summary>
    FVersionCacheStamp: TDictionary<string, TDateTime>;
    /// <summary>
    ///   When each repository's folder tree was last scanned for a project file.
    /// </summary>
    FVersionScanStamp: TDictionary<string, TDateTime>;
    /// <summary>
    ///   Set once <see cref="LoadConfig"/> has produced a state that may be
    ///   saved: the file was read, was absent, or was copied aside.
    /// </summary>
    FConfigLoaded: Boolean;
    /// <summary>
    ///   Set when the configuration file exists, could not be read AND could
    ///   not be copied aside.  <see cref="SaveConfig"/> then writes nothing.
    /// </summary>
    FConfigUnreadable: Boolean;
    /// <summary>
    ///   The <c>github_token</c> value as it stands in the configuration file.
    ///   Guarded by <c>FListsLock</c>.
    /// </summary>
    /// <remarks>
    ///   A save must never replace a stored secret with an empty string because
    ///   it could not be decrypted at load, or could not be re-encrypted now.
    ///   This text is written back in both cases.  Assigning a different token
    ///   clears it, so that clearing the token really does clear it.
    /// </remarks>
    FGitHubTokenCipher: string;
    /// <summary>
    ///   Guards the commit history, the templates, and every string setting,
    ///   all of which are read by worker threads and written by the UI thread.
    /// </summary>
    FListsLock: TCriticalSection;
    /// <summary>
    ///   Serialises <see cref="SaveConfig"/> from snapshot to file replacement.
    /// </summary>
    FConfigLock: TCriticalSection;
    /// <summary>
    ///   Why the last <see cref="SaveConfig"/> could not fully persist, or
    ///   empty.  Guarded by <c>FListsLock</c>.
    /// </summary>
    FLastSaveError: string;
    /// <summary>
    ///   Why <see cref="LoadConfig"/> could not use the file, or empty.
    ///   Guarded by <c>FListsLock</c>.
    /// </summary>
    FLastLoadError: string;

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
    ///   Stores the GitHub access token, stripping control characters and
    ///   re-registering it for log redaction.
    /// </summary>
    /// <param name="AValue">The token as entered.</param>
    procedure SetGitHubToken( const AValue: string );

    /// <summary>
    ///   Reads one of the shared string settings under <c>FListsLock</c>.
    /// </summary>
    /// <param name="sField">The field to read.</param>
    /// <returns>A private copy of the field's value.</returns>
    function ReadShared( var sField: string ): string;

    /// <summary>
    ///   Writes one of the shared string settings under <c>FListsLock</c>.
    /// </summary>
    /// <param name="sField">The field to write.</param>
    /// <param name="sValue">The new value.</param>
    procedure WriteShared( var sField: string; const sValue: string );

    /// <summary>
    ///   Property reader for <see cref="GitHubUsername"/>.
    /// </summary>
    /// <returns>The GitHub account name.</returns>
    function GetGitHubUsername: string;

    /// <summary>
    ///   Property writer for <see cref="GitHubUsername"/>.
    /// </summary>
    /// <param name="AValue">The account name; surrounding blanks are removed.</param>
    procedure SetGitHubUsername( const AValue: string );

    /// <summary>
    ///   Property reader for <see cref="GitHubToken"/>.
    /// </summary>
    /// <returns>The GitHub access token, in clear.</returns>
    function GetGitHubToken: string;

    /// <summary>
    ///   Property reader for <see cref="GitClientPath"/>.
    /// </summary>
    /// <returns>The configured Git client path.</returns>
    function GetGitClientPath: string;

    /// <summary>
    ///   Property writer for <see cref="GitClientPath"/>.
    /// </summary>
    /// <param name="AValue">The Git client path.</param>
    procedure SetGitClientPath( const AValue: string );

    /// <summary>
    ///   Property reader for <see cref="FilePattern"/>.
    /// </summary>
    /// <returns>The staging pattern, or empty.</returns>
    function GetFilePattern: string;

    /// <summary>
    ///   Property writer for <see cref="FilePattern"/>.
    /// </summary>
    /// <param name="AValue">The staging pattern.</param>
    procedure SetFilePattern( const AValue: string );

    /// <summary>
    ///   Property reader for <see cref="DelphiIndexerPath"/>.
    /// </summary>
    /// <returns>The configured indexer path.</returns>
    function GetDelphiIndexerPath: string;

    /// <summary>
    ///   Property writer for <see cref="DelphiIndexerPath"/>.
    /// </summary>
    /// <param name="AValue">The indexer path.</param>
    procedure SetDelphiIndexerPath( const AValue: string );

    /// <summary>
    ///   Property reader for <see cref="StyleName"/>.
    /// </summary>
    /// <returns>The chosen VCL style name, or empty.</returns>
    function GetStyleName: string;

    /// <summary>
    ///   Property writer for <see cref="StyleName"/>.
    /// </summary>
    /// <param name="AValue">The VCL style name.</param>
    procedure SetStyleName( const AValue: string );

    /// <summary>
    ///   Property reader for <see cref="LastSaveError"/>.
    /// </summary>
    /// <returns>The last save failure, or empty.</returns>
    function GetLastSaveError: string;

    /// <summary>
    ///   Property reader for <see cref="LastLoadError"/>.
    /// </summary>
    /// <returns>The last load failure, or empty.</returns>
    function GetLastLoadError: string;

    /// <summary>
    ///   Property writer for <see cref="CommitTemplates"/>.
    /// </summary>
    /// <param name="AValue">The templates; a private copy is kept.</param>
    procedure SetCommitTemplates( const AValue: TArray<string> );

  private const
    /// <summary>
    ///   Most commit messages kept in the history.
    /// </summary>
    MAX_HISTORY_ITEMS = 20;

    /// <summary>
    ///   How long a repository's .dproj tree scan is reused before the
    ///   directory is walked again. The modification-time check remains the
    ///   authority once this elapses; this only suppresses repeated full
    ///   recursive walks within a single refresh burst.
    /// </summary>
    VERSION_SCAN_TTL_SECONDS = 30;

  private
    /// <summary>
    ///   Executes a Git command in the specified repository directory.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <param name="sCommand">Git command to execute (without 'git' prefix).</param>
    /// <param name="sOutput">Output from the command.</param>
    /// <param name="iTimeout">Timeout in milliseconds (default: GIT_COMMAND_TIMEOUT).</param>
    /// <param name="bStdOutOnly">
    ///   True when the caller PARSES the output: a successful command then
    ///   returns its standard output alone, so a warning Git wrote to standard
    ///   error cannot land in the middle of it.  A failed command returns both.
    /// </param>
    /// <returns>True if the command executed successfully with exit code 0.</returns>
    function ExecuteGitCommand( const sRepoPath, sCommand: string; out sOutput: string;
      const iTimeout: Cardinal = GIT_COMMAND_TIMEOUT; const bStdOutOnly: Boolean = False ): Boolean;

    /// <summary>
    ///   Gets the current branch name for a repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>The branch name, or '(unknown)' when it cannot be determined.</returns>
    function GetRepoBranch( const sRepoPath: string ): string;

    /// <summary>
    ///   Reports how far the current branch is ahead of, and behind, its
    ///   upstream, optionally fetching first.
    /// </summary>
    /// <remarks>
    ///   One `rev-list --left-right --count` answers both questions without
    ///   parsing localisable text.  With no upstream configured the comparison
    ///   falls back to <c>origin/&lt;branch&gt;</c>; when that does not exist
    ///   either the result is False and the counts are UNKNOWN, which the
    ///   caller must not read as "nothing to push".
    /// </remarks>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <param name="bFetch">True to fetch first; skipped when there is no remote.</param>
    /// <param name="iAhead">Commits on the local branch that the upstream lacks.</param>
    /// <param name="iBehind">Commits on the upstream that the local branch lacks.</param>
    /// <param name="bFetchOK">False when a fetch was attempted and failed.</param>
    /// <param name="bHasUpstream">True when the branch has an upstream configured.</param>
    /// <returns>True when the counts are known.</returns>
    function GetAheadBehind( const sRepoPath: string; const bFetch: Boolean; out iAhead, iBehind: Integer;
      out bFetchOK, bHasUpstream: Boolean ): Boolean;

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
    ///   Names the remote the current branch pushes to.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>
    ///   The value of <c>branch.&lt;name&gt;.remote</c> when it is a remote name;
    ///   otherwise <c>origin</c>.
    /// </returns>
    function GetUpstreamRemoteName( const sRepoPath: string ): string;

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
    ///   pre-existing remote of that name — an entirely ordinary mirror
    ///   arrangement — along with its refspecs.
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
    ///   Writes a commit message to a temporary file for <c>git commit -F</c>,
    ///   so the message never appears on a command line.
    /// </summary>
    /// <param name="sMessage">The commit message to use.</param>
    /// <param name="sTempFile">Returns the path to the temp file created.</param>
    /// <returns>True if temp file was created successfully.</returns>
    function CreateCommitMessageFile( const sMessage: string; out sTempFile: string ): Boolean;

    /// <summary>
    ///   Deletes a file made by <see cref="CreateCommitMessageFile"/>.  A
    ///   refusal is noted on the debug channel and otherwise ignored.
    /// </summary>
    /// <param name="sTempFile">The file to delete; may be empty.</param>
    procedure DeleteCommitMessageFile( const sTempFile: string );

    /// <summary>
    ///   Makes an HTTP request to a remote API.
    /// </summary>
    /// <param name="sVerb">HTTP verb: 'POST', 'PATCH' or 'DELETE'.</param>
    /// <param name="sBaseURL">API base URL ( GITHUB_API_URL ).</param>
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
    ///   Makes an authenticated request to the GitHub API.
    /// </summary>
    /// <param name="sVerb">HTTP verb: 'POST', 'PATCH' or 'DELETE'.</param>
    /// <param name="sEndpoint">Endpoint path, appended to the API base URL.</param>
    /// <param name="sBody">JSON request body; empty for a DELETE.</param>
    /// <param name="sResponse">Receives the response body, or the error text.</param>
    /// <param name="iStatusCode">Receives the HTTP status code, or 0 when the request never completed.</param>
    /// <returns>True when the response status is in the 2xx range.</returns>
    function ExecuteGitHubApi( const sVerb, sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Resolves the remote repository that a deletion would act on.
    /// </summary>
    /// <remarks>
    ///   Resolved from the UPSTREAM remote, not from origin — the same remote
    ///   the Remote column reports and that push and pull actually contact. A
    ///   branch can track any remote, and deleting whatever happens to be
    ///   called origin would delete a repository the user was never shown.
    /// </remarks>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sOwner">Receives the owner (user or organisation) segment.</param>
    /// <param name="sRepo">Receives the repository name.</param>
    /// <param name="sReason">Receives why the remote cannot be deleted, when the result is False.</param>
    /// <returns>True when the remote is on GitHub and can be deleted through its API.</returns>
    function ResolveRemoteDeleteTarget( const sRepoPath: string; out sOwner, sRepo, sReason: string ): Boolean;

    /// <summary>
    ///   Gets the remote origin URL for a repository.
    /// </summary>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>The origin URL, or an empty string when there is no origin.</returns>
    function GetRemoteOriginURL( const sRepoPath: string ): string;

    /// <summary>
    ///   Gets the URL of the remote that the CURRENT BRANCH tracks, falling
    ///   back to origin when the branch has no upstream.
    /// </summary>
    /// <remarks>
    ///   This is the remote a plain <c>git push</c> or <c>git pull</c> will
    ///   actually contact, and the one <c>GetAheadBehind</c> compares against
    ///   via <c>@{upstream}</c>. It is NOT always origin: a branch can track
    ///   any remote. Displaying origin's provider while pushing to a different
    ///   remote is how a repository came to be shown as GitHub while its
    ///   pushes went to a dead URL on another host.
    /// </remarks>
    /// <param name="sRepoPath">Path to the repository.</param>
    /// <returns>
    ///   The upstream remote's URL; origin's URL when there is no upstream;
    ///   an empty string when there is no remote at all.
    /// </returns>
    function GetUpstreamRemoteURL( const sRepoPath: string ): string;

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
    ///   Resolves the <c>FileVersion</c> that a project's ACTIVE configuration
    ///   will actually build, by layering its property groups the way MSBuild
    ///   does.
    /// </summary>
    /// <remarks>
    ///   This replaces taking the HIGHEST <c>FileVersion</c> found anywhere in
    ///   the file, which is not the same question and was measurably wrong.
    ///   GITLAKMCP carried <c>FileVersion=2.0.0.0</c> on its <c>Base_Win64</c>
    ///   group and <c>1.0.0.347</c> on <c>Cfg_1_Win64</c>; the latter is
    ///   evaluated last and so wins, and every binary ever built reported
    ///   1.0.0.x - but "highest" picked <c>2.0.0.0</c>, a version nothing had
    ///   ever produced, and that is what would have been tagged and pushed.
    ///   <para>
    ///   MSBuild layers the groups <c>Base</c>, <c>Base_&lt;Platform&gt;</c>,
    ///   <c>Cfg_N</c>, <c>Cfg_N_&lt;Platform&gt;</c>, each overriding the last,
    ///   so the ACTIVE value is the final one in that order that defines a
    ///   <c>FileVersion</c> - not the largest.
    ///   </para>
    /// </remarks>
    /// <param name="sContent">Full text of the .dproj file.</param>
    /// <returns>
    ///   The active configuration's FileVersion, or an empty string when the
    ///   file does not say enough to resolve one - in which case the caller
    ///   falls back to the old scan rather than reporting no version at all.
    /// </returns>
    function ResolveActiveFileVersion( const sContent: string ): string;

    /// <summary>
    ///   Returns True when <paramref name="sCandidate"/> is a higher version
    ///   than <paramref name="sCurrent"/>, comparing part by part.
    /// </summary>
    /// <remarks>
    ///   Handles differing lengths ( "1.5.0" against "1.5.0.38" ) by treating
    ///   a missing part as zero, and an empty current as always beaten.
    /// </remarks>
    /// <param name="sCandidate">Version being considered.</param>
    /// <param name="sCurrent">Version currently held; may be empty.</param>
    /// <returns>True if the candidate should replace the current value.</returns>
    function IsHigherVersion( const sCandidate, sCurrent: string ): Boolean;

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
  public
    /// <summary>
    ///   Creates the manager, resolves the configuration file path and prepares the
    ///   repository lock and version caches.
    /// </summary>
    /// <param name="sConfigPath">
    ///   Configuration file to use.  Empty, the default, means the user's own
    ///   file; the test suite passes a file in a temporary folder so that it
    ///   never reads or writes the real one.
    /// </param>
    constructor Create( const sConfigPath: string = '' );
    /// <summary>
    ///   Releases the repository lock and version caches.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Loads the repository list and settings from the configuration file.
    /// </summary>
    /// <remarks>
    ///   A file that cannot be read, or does not hold a configuration, is
    ///   copied to <c>&lt;file&gt;.unreadable-&lt;timestamp&gt;</c> and an empty
    ///   configuration is started.  When even the copy fails, every later
    ///   <see cref="SaveConfig"/> is refused so the file cannot be overwritten.
    ///   Either way the result is False and <see cref="LastLoadError"/> says
    ///   what happened.
    /// </remarks>
    /// <returns>True if the file was read, was empty, or does not exist.</returns>
    function LoadConfig: Boolean;

    /// <summary>
    ///   Saves the repository list and settings to the configuration file,
    ///   replacing it in one step.
    /// </summary>
    /// <returns>
    ///   True if the file was written.  False, with <see cref="LastSaveError"/>
    ///   set, when it was not.  True with <see cref="LastSaveError"/> set means
    ///   everything was saved except a new access token.
    /// </returns>
    function SaveConfig: Boolean;

    /// <summary>
    ///   Adds a new repository to the managed list and saves the configuration.
    /// </summary>
    /// <remarks>
    ///   Determines the LOCAL state only; nothing is fetched, so this is safe
    ///   on the UI thread.  The next refresh compares with the remote.
    /// </remarks>
    /// <param name="sPath">Path to the Git repository.</param>
    /// <returns>True if it was added; False if blank or already listed.</returns>
    function AddRepository( const sPath: string ): Boolean;

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
    ///   Refreshes the status of a single repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository to refresh.</param>
    /// <param name="bFetch">
    ///   True to fetch from the remote first.  Pass False on the UI thread: a
    ///   fetch can block for as long as the network does.
    /// </param>
    procedure RefreshStatus( const sRepoPath: string; const bFetch: Boolean = True );

    /// <summary>
    ///   Commits and pushes changes for a repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sMessage">Commit message.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function CommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Initialises a new Git repository in the specified folder.
    /// </summary>
    /// <param name="sPath">Path to the folder to initialise.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if initialisation succeeded.</returns>
    function InitialiseRepository( const sPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Turns a folder into a repository on GitHub: initialise, create the
    ///   remote, connect it, commit and push.
    /// </summary>
    /// <remarks>
    ///   The name and the credentials are checked before anything is changed.
    ///   Each step is skipped when it is already done, so after a failure the
    ///   same call on the same folder resumes instead of dead-ending on
    ///   "already a Git repository" or "name already exists".
    /// </remarks>
    /// <param name="sFolder">The folder to publish.</param>
    /// <param name="sName">Repository name; must satisfy <c>IsValidRepoName</c>.</param>
    /// <param name="sDescription">Repository description.</param>
    /// <param name="bPrivate">True to create a private repository.</param>
    /// <param name="sMessage">Message for the first commit.</param>
    /// <param name="sRemoteURL">Receives the remote's URL once it is known.</param>
    /// <param name="sLog">Receives a line for every step taken or skipped.</param>
    /// <returns>True when the folder's branch is on GitHub.</returns>
    function CreateAndPushRepository( const sFolder, sName, sDescription: string; const bPrivate: Boolean;
      const sMessage: string; out sRemoteURL, sLog: string ): Boolean;

    /// <summary>
    ///   Returns True when the folder holds a <c>.git</c> entry: a folder in an
    ///   ordinary clone, a file in a linked worktree or a submodule.
    /// </summary>
    /// <param name="sPath">The folder to test.</param>
    /// <returns>True if <c>.git</c> exists there.</returns>
    class function HasGitEntry( const sPath: string ): Boolean; static;

    /// <summary>
    ///   Returns the one spelling of a repository path this application uses:
    ///   trimmed, with no trailing path delimiter.
    /// </summary>
    /// <param name="sPath">The path as typed, dropped or loaded.</param>
    /// <returns>The normalised path.</returns>
    class function NormaliseRepoPath( const sPath: string ): string; static;

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
    ///   Creates a new repository on GitHub.
    /// </summary>
    /// <param name="sName">Repository name; refused unless <c>IsValidRepoName</c>.</param>
    /// <param name="sDescription">Repository description.</param>
    /// <param name="bPrivate">True to create a private repository.</param>
    /// <param name="sRemoteURL">Returns the clone URL of the created repository.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if creation succeeded.</returns>
    function CreateGitHubRepository( const sName, sDescription: string; const bPrivate: Boolean;
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
    ///   Gets the version the repository's ACTIVE project configuration builds,
    ///   read from its .dproj.
    /// </summary>
    /// <remarks>
    ///   Public because it is a read-only query about a repository, exactly
    ///   like <see cref="GetRepoProvider"/> beside it, and the Version column
    ///   displays what it returns. It resolves the value MSBuild would use for
    ///   the project's default configuration and platform - NOT the highest
    ///   number in the file; see <c>ResolveActiveFileVersion</c> for why that
    ///   distinction cost a wrong tag.
    /// </remarks>
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
    ///   Changes the visibility of a remote repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="bPrivate">True to make private, False to make public.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if the operation succeeded.</returns>
    function SetRepositoryVisibility( const sRepoPath: string; const bPrivate: Boolean;
      out sError: string ): Boolean;

    /// <summary>
    ///   Describes the remote repository that <see cref="DeleteRemoteRepository"/>
    ///   would delete, so the confirmation dialog can name it.
    /// </summary>
    /// <remarks>
    ///   The user is being asked to authorise an irreversible deletion, so the
    ///   dialog must state the exact <c>owner/name</c> on the exact host rather
    ///   than "the remote" — the list's own Remote column shows only a provider
    ///   name, and two entries can point at repositories of the same name under
    ///   different owners.
    /// </remarks>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sDescription">
    ///   Receives <c>Host: owner/name</c> when deletable, or the reason it is
    ///   not when the result is False.
    /// </param>
    /// <returns>True when the remote can be deleted through the provider's API.</returns>
    function DescribeRemoteDeleteTarget( const sRepoPath: string; out sDescription: string ): Boolean;

    /// <summary>
    ///   Deletes the repository's remote counterpart on its hosting provider.
    /// </summary>
    /// <remarks>
    ///   Irreversible: GitHub does not keep a deleted repository recoverable
    ///   from the API, and the issues, releases
    ///   and pull requests go with it. Nothing here asks for confirmation —
    ///   that is the caller's job, and the caller must have named the exact
    ///   target from <see cref="DescribeRemoteDeleteTarget"/>.
    /// </remarks>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sError">Receives the failure reason when the result is False.</param>
    /// <returns>True when the provider reported the repository deleted.</returns>
    function DeleteRemoteRepository( const sRepoPath: string; out sError: string ): Boolean;

    /// <summary>
    ///   Sends the repository's working-tree folder to the Recycle Bin.
    /// </summary>
    /// <remarks>
    ///   The Recycle Bin rather than an outright delete, so that the wrong
    ///   repository is recoverable. Windows silently deletes permanently when
    ///   the tree will not fit in the bin or the bin is disabled for the drive,
    ///   so <c>FOF_WANTNUKEWARNING</c> is set: the user is asked in that case
    ///   instead of losing the folder without being told.
    ///   <para>
    ///   Refuses anything that is not the ROOT of a Git working tree, a drive
    ///   root, or a folder containing this application — the guard exists
    ///   because the path comes from a saved configuration file and the
    ///   operation is recursive.
    ///   </para>
    /// </remarks>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="AOwnerHandle">
    ///   Window to own the shell's progress and confirmation dialogs; pass 0
    ///   for none.
    /// </param>
    /// <param name="sError">Receives the failure reason when the result is False.</param>
    /// <returns>True when the folder is gone from disk.</returns>
    function DeleteLocalRepository( const sRepoPath: string; const AOwnerHandle: HWND;
      out sError: string ): Boolean;

    /// <summary>
    ///   Pulls changes from remote for a repository.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function PullRepository( const sRepoPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Concludes a MERGE by keeping the local version of each conflicted
    ///   file, then commits and pushes.
    /// </summary>
    /// <remarks>
    ///   Only the conflicted paths are touched: files that merged cleanly, and
    ///   uncommitted or untracked files, are left exactly as they are.  Refused
    ///   during a rebase, cherry-pick, revert or bisect, where "ours" does not
    ///   mean the local work.
    /// </remarks>
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
    /// <remarks>
    ///   Leased against <see cref="TRepoInfo.RemoteSHA"/>, the upstream commit
    ///   the user was last shown.  Refused when there is no such commit, and
    ///   when the last refresh that tried to fetch failed
    ///   ( <see cref="TRepoInfo.FetchFailed"/> ), since the remote's state is
    ///   then not known.
    /// </remarks>
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
    /// <returns>
    ///   True if the fetch and the comparison both worked ( sChanges is empty
    ///   when nothing is incoming, or when the branch has no upstream ).
    /// </returns>
    function GetIncomingChanges( const sRepoPath: string; out sChanges: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Migrates a repository from its current host to GitHub: creates the
    ///   new repository, re-points <c>origin</c> at it and pushes all branches
    ///   and tags.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository to migrate.</param>
    /// <param name="sNewRepoName">Name of the repository to create on GitHub.</param>
    /// <param name="sDescription">Description for the new repository.</param>
    /// <param name="bPrivate">True to create the target repository as private.</param>
    /// <param name="sNewRemoteURL">Output: clone URL of the newly created remote.</param>
    /// <param name="sError">Output: error message if the operation failed.</param>
    /// <param name="sLog">Output: detailed log of each migration step.</param>
    /// <returns>True if the migration succeeded end-to-end.</returns>
    /// <remarks>
    ///   The old remote repository is NOT deleted.  The previous origin is kept
    ///   locally as a remote named <c>old-origin</c> ( or <c>old-origin-N</c> ).
    ///   On failure the remotes, the branch upstreams and the branch list are
    ///   put back, and the log says whether that worked; the repository created
    ///   on GitHub is left for the user to remove.
    /// </remarks>
    function MigrateRepository( const sRepoPath, sNewRepoName, sDescription: string; const bPrivate: Boolean;
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
    ///   GitHub account name used for repository creation and visibility changes.
    /// </summary>
    property GitHubUsername: string read GetGitHubUsername write SetGitHubUsername;
    /// <summary>
    ///   GitHub personal access token, in clear text in memory and DPAPI-encrypted
    ///   at rest.
    /// </summary>
    property GitHubToken: string read GetGitHubToken write SetGitHubToken;
    /// <summary>
    ///   Path to an external Git client. Used to open a repository externally, and,
    ///   when it points at git.exe itself, to run this application's own Git calls.
    /// </summary>
    property GitClientPath: string read GetGitClientPath write SetGitClientPath;
    /// <summary>
    ///   Optional glob restricting what Commit &amp; Push stages; empty means stage all.
    ///   Validated by <see cref="IsSafeFilePattern"/> on both entry and load.
    /// </summary>
    property FilePattern: string read GetFilePattern write SetFilePattern;
    /// <summary>
    ///   Path to delphi-indexer.exe, used to reindex a repository after a successful
    ///   push. Empty means fall back to PATH and then the default location.
    /// </summary>
    property DelphiIndexerPath: string read GetDelphiIndexerPath write SetDelphiIndexerPath;
    /// <summary>
    ///   Name of the VCL style chosen from View &gt; Style, as registered with
    ///   TStyleManager. Empty means the application's default style.
    /// </summary>
    property StyleName: string read GetStyleName write SetStyleName;
    /// <summary>
    ///   Most-recently-used commit messages, newest first. Reading this yields a
    ///   private copy taken under the lock: the array is re-sized from the
    ///   commit worker thread, so handing out the live one was a use-after-free
    ///   waiting to happen.
    /// </summary>
    property CommitHistory: TArray<string> read GetCommitHistorySnapshot;
    /// <summary>
    ///   User-defined reusable commit messages. Reading yields a locked copy,
    ///   and writing stores a locked copy, for the same reason as
    ///   <see cref="CommitHistory"/>.
    /// </summary>
    property CommitTemplates: TArray<string> read GetCommitTemplatesSnapshot write SetCommitTemplates;
    /// <summary>
    ///   Why the last <see cref="SaveConfig"/> could not fully persist, or empty
    ///   when it succeeded. Check this after saving credentials.
    /// </summary>
    property LastSaveError: string read GetLastSaveError;
    /// <summary>
    ///   Why <see cref="LoadConfig"/> could not use the configuration file, or
    ///   empty.  Show it to the user at start-up when not empty.
    /// </summary>
    property LastLoadError: string read GetLastLoadError;
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
///   Sanitises a string into a repository name accepted by GitHub:
///   drops whitespace (so a "Title Case" folder becomes "TitleCase"), replaces
///   any other character outside [A-Za-z0-9._-] with '-', collapses runs of
///   '-', and trims leading/trailing separators. Applied to the folder-derived
///   default so a folder name with spaces no longer produces a rejected name.
/// </summary>
/// <param name="AName">The raw name, typically a folder name.</param>
/// <returns>A host-safe repo name; 'repo' when nothing usable remains.</returns>
function SanitiseRepoName( const AName: string ): string;

/// <summary>
///   Returns True when a name is acceptable to GitHub as a repository name:
///   1 to 100 characters from [A-Za-z0-9._-], and neither "." nor "..".
/// </summary>
/// <param name="AName">The name exactly as it would be sent.</param>
/// <returns>True if the name may be sent to GitHub.</returns>
function IsValidRepoName( const AName: string ): Boolean;

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
/// <param name="sOutput">
///   Receives standard output followed by standard error; standard output
///   alone when <paramref name="bStdOutOnly"/> is True and the process
///   succeeded.  When the process could not be started it holds the reason.
///   Output past 8 MB per stream is discarded and marked as truncated.
/// </param>
/// <param name="iTimeout">Timeout in milliseconds.</param>
/// <param name="bStdOutOnly">True to leave standard error out of a successful result.</param>
/// <returns>True if the process ran to completion and exited with code 0.</returns>
function RunProcessCaptureOutput( const sCommandLine, sWorkingDir: string; out sOutput: string;
  const iTimeout: Cardinal; const bStdOutOnly: Boolean = False ): Boolean;

/// <summary>
///   Decodes a byte buffer as UTF-8 without raising on malformed input.
///   Invalid sequences become U+FFFD rather than an <c>EEncodingError</c>.
/// </summary>
/// <param name="ABytes">Buffer holding the bytes to decode.</param>
/// <param name="iCount">Number of bytes in the buffer to decode.</param>
/// <returns>The decoded text; invalid sequences become U+FFFD.</returns>
function DecodeUtf8Lenient( const ABytes: TBytes; const iCount: Integer ): string;

/// <summary>
///   Returns True for an exception that indicates a defect in this application
///   rather than an environment failure.
/// </summary>
/// <remarks>
///   A handler that absorbs environment failures - a locked file, a dropped
///   connection, a full disk - asks this first and re-raises with a bare
///   <c>raise</c> when the answer is True, so that an access violation of our
///   own reaches EurekaLog instead of being logged as "Error during commit".
///   <para>
///   It is a QUESTION, not a re-raise: the earlier <c>ReRaiseIfDefect</c> used
///   <c>raise AException</c> from inside the handler, which raises the same
///   object a second time and frees it twice.
///   </para>
/// </remarks>
/// <param name="AException">The exception caught by the handler.</param>
/// <returns>True if the handler must re-raise it.</returns>
function IsDefectException( const AException: Exception ): Boolean;

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

uses
  OtlParallel;

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

  Result            := Trim( AURL );

  if Result.IsEmpty then
    Exit;

  // Strip the scheme.
  var iPos          := Pos( '://', Result );

  if iPos > 0 then
    Result          := Copy( Result, iPos + 3, MaxInt );

  // Keep the AUTHORITY only, before looking for userinfo.  Searching the whole
  // remainder for '@' let a path segment decide the host:
  // https://evil.example/a@github.com/owner/repo was classified as GitHub.
  iPos              := Pos( '/', Result );

  if iPos > 0 then
    Result          := Copy( Result, 1, iPos - 1 );

  // Strip any userinfo.  The LAST '@' ends it ( a password may contain one ).
  iPos              := Result.LastIndexOf( '@' ) + 1;

  if iPos > 0 then
    Result          := Copy( Result, iPos + 1, MaxInt );

  // What is left ends at a ':' ( a port, or the scp-style path separator ).
  iPos              := Pos( ':', Result );

  if iPos > 0 then
    Result          := Copy( Result, 1, iPos - 1 );

  Result            := LowerCase( Result );

end;

function IsDefectException( const AException: Exception ): Boolean;
begin

  Result            := ( AException is EAccessViolation ) or ( AException is EInvalidPointer ) or
    ( AException is EInvalidCast ) or ( AException is EListError ) or
    ( AException is ERangeError ) or ( AException is EIntOverflow ) or
    ( AException is EOutOfMemory ) or ( AException is EAbstractError );

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

  Result            := '';

  for var cChar in AValue.Trim do
  begin
    if cChar >= ' ' then
      Result        := Result + cChar;
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

  Result            := Trim( APath );

  if ( Length( Result ) < 2 ) or ( not Result.StartsWith( '"' ) ) or
    ( not Result.EndsWith( '"' ) ) then
    Exit;

  Result            := Copy( Result, 2, Length( Result ) - 2 );
  Result            := Result
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

  Result            := ( not AVersion.IsEmpty ) and ( Length( AVersion ) <= 32 ) and
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
      Result[ iI ]  := GKnownSecrets[ iI ];
  finally
    GSecretsLock.Leave;
  end;

end;

/// <summary>
///   Records the access token currently in use so that log and error text can
///   be masked by exact match.
/// </summary>
/// <param name="AGitHubToken">The GitHub access token, or empty.</param>
procedure RegisterKnownSecrets( const AGitHubToken: string );
begin

  GSecretsLock.Enter;

  try
    SetLength( GKnownSecrets, 0 );

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
  SearchBuffer      : array[ 0..MAX_PATH ] of Char;
  pFilePart         : PChar;
  iFound            : Cardinal;
begin

  GGitExeLock.Enter;

  try
    if ( not GGitExePath.IsEmpty ) then
      Exit( GGitExePath );

    pFilePart       := nil;
    FillChar( SearchBuffer, SizeOf( SearchBuffer ), 0 );

    // SearchPath returns the REQUIRED buffer size when the result does not fit,
    // without writing the buffer, so a non-zero return is not on its own proof
    // that SearchBuffer holds anything.
    iFound          := SearchPath( nil, GIT_EXE_NAME, nil, Length( SearchBuffer ), SearchBuffer, pFilePart );

    if ( iFound > 0 ) and ( iFound < Cardinal( Length( SearchBuffer ) ) ) then
      GGitExePath   := '"' + string( SearchBuffer ) + '"'
    else
      GGitExePath   := GIT_EXE_NAME;

    Result          := GGitExePath;
  finally
    GGitExeLock.Leave;
  end;

end;

function DecodeUtf8Lenient( const ABytes: TBytes; const iCount: Integer ): string;
var
  Encoding          : TEncoding;
begin

  Result            := '';

  if ( iCount <= 0 ) or ( Length( ABytes ) = 0 ) then
    Exit;

  // TEncoding.UTF8 is constructed with MB_ERR_INVALID_CHARS and therefore
  // RAISES on malformed input. TMBCSEncoding.Create( CP_UTF8 ) passes flag 0,
  // so MultiByteToWideChar substitutes U+FFFD instead of failing.
  Encoding          := TMBCSEncoding.Create( CP_UTF8 );

  try
    Result          := Encoding.GetString( ABytes, 0, Min( iCount, Length( ABytes ) ) );
  finally
    Encoding.Free;
  end;

end;

/// <summary>
///   Returns a Unicode environment block: everything this process inherited,
///   with the supplied <c>NAME=VALUE</c> entries replacing any same-named
///   entry. Entries are sorted case-insensitively, as CreateProcess expects,
///   and the result is double-null terminated.
/// </summary>
/// <remarks>
///   A name in <c>ARemove</c> is taken OUT of the block.  That is not the same
///   as giving it an empty value: Git reads <c>GIT_DIR=</c> as "the repository
///   is at ''" and fails every command with "not a git repository".
/// </remarks>
function BuildChildEnvironment( const AOverrides, ARemove: TArray<string> ): string;
var
  pEnv              : PChar;
  pCursor           : PChar;
  Entries           : TStringList;
  sEntry            : string;
  sName             : string;
begin

  Entries           := TStringList.Create;

  try
    Entries.CaseSensitive := False;

    pEnv            := GetEnvironmentStrings;

    if pEnv <> nil then
    begin
      try
        pCursor     := pEnv;

        while pCursor^ <> #0 do
        begin
          sEntry    := string( pCursor );

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

    for var sRemove in ARemove do
    begin
      for var i := Entries.Count - 1 downto 0 do
      begin
        if SameText( Entries[ i ].Substring( 0, Entries[ i ].IndexOf( '=' ) ), sRemove ) then
          Entries.Delete( i );
      end;
    end;

    Entries.Sort;

    Result          := '';

    for var i := 0 to Entries.Count - 1 do
      Result        := Result + Entries[ i ] + #0;

    Result          := Result + #0;
  finally
    Entries.Free;
  end;

end;

function RunProcessCaptureOutput( const sCommandLine, sWorkingDir: string; out sOutput: string;
  const iTimeout: Cardinal; const bStdOutOnly: Boolean ): Boolean;
type
  /// <summary>
  ///   One captured stream: the read end of its pipe and the bytes read so far.
  /// </summary>
  TCapture = record
    hRead           : THandle;
    hWrite          : THandle;
    naBytes         : TBytes;
    iCount          : Integer;
    bTruncated      : Boolean;
  end;
var
  StartupInfo       : TStartupInfo;
  ProcessInfo       : TProcessInformation;
  SecurityAttr      : TSecurityAttributes;
  rStdOut           : TCapture;
  rStdErr           : TCapture;
  hNulIn            : THandle;
  hJob              : THandle;
  JobLimits         : JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
  naBuffer          : TBytes;
  dwBytesRead       : DWORD;
  dwBytesAvail      : DWORD;
  dwWaitResult      : DWORD;
  dwExitCode        : DWORD;
  bProcessStarted   : Boolean;
  bTimedOut         : Boolean;
  iRemainingTimeout : Int64;
  MutableCommand    : TArray<Char>;
  pWorkingDir       : PChar;
  sEnvironment      : string;
  sSpawnError       : string;
  EnvBlock          : TArray<Char>;

  /// <summary>
  ///   Drains everything currently queued in one pipe into its accumulator.
  /// </summary>
  procedure DrainPipe( var ACapture: TCapture );
  begin

    // Bounded per pass, so the caller's timeout is always re-evaluated no
    // matter how chatty the child is.
    var iReads      := 0;

    while ( iReads < MAX_READS_PER_DRAIN ) and
      PeekNamedPipe( ACapture.hRead, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
    begin
      Inc( iReads );

      if ( not ReadFile( ACapture.hRead, naBuffer[ 0 ], Length( naBuffer ), dwBytesRead, nil ) ) or
        ( dwBytesRead = 0 ) then
        Break;

      // Past the ceiling the bytes are READ AND DISCARDED.  Stopping the read
      // instead left the pipe full, so the child blocked on its next write and
      // sat there until the timeout killed it - a large but perfectly healthy
      // command was reported as "Operation timed out".
      if ACapture.iCount >= MAX_CAPTURED_BYTES then
      begin
        ACapture.bTruncated := True;
        Continue;
      end;

      if ( ACapture.iCount + Integer( dwBytesRead ) ) > Length( ACapture.naBytes ) then
        SetLength( ACapture.naBytes, Max( Length( ACapture.naBytes ) * 2, ACapture.iCount + Integer( dwBytesRead ) ) );

      Move( naBuffer[ 0 ], ACapture.naBytes[ ACapture.iCount ], dwBytesRead );
      Inc( ACapture.iCount, Integer( dwBytesRead ) );
    end;

  end;

  /// <summary>
  ///   Decodes one captured stream, noting when it was cut at the ceiling.
  /// </summary>
  function CaptureText( const ACapture: TCapture ): string;
  begin

    Result          := DecodeUtf8Lenient( ACapture.naBytes, ACapture.iCount );

    if ACapture.bTruncated then
      Result        := Result.TrimRight + sLineBreak + '[output truncated]';

  end;

begin

  Result            := False;
  sOutput           := '';
  sSpawnError       := '';

  rStdOut           := Default( TCapture );
  rStdErr           := Default( TCapture );
  hNulIn            := INVALID_HANDLE_VALUE;
  hJob              := 0;
  bProcessStarted   := False;
  bTimedOut         := False;

  ZeroMemory( @ProcessInfo, SizeOf( TProcessInformation ) );

  SecurityAttr.nLength := SizeOf( TSecurityAttributes );
  SecurityAttr.bInheritHandle := True;
  SecurityAttr.lpSecurityDescriptor := nil;

  // Two pipes, not one.  With stderr merged into stdout, a single Git warning
  // line ( a deprecated config key, an unreachable alternate ) landed in the
  // middle of text that callers PARSE: a branch name, an ahead/behind count, a
  // porcelain status.
  if ( not CreatePipe( rStdOut.hRead, rStdOut.hWrite, @SecurityAttr, 0 ) ) then
    Exit;

  try
    if ( not CreatePipe( rStdErr.hRead, rStdErr.hWrite, @SecurityAttr, 0 ) ) then
      Exit;

    // The read ends must NOT be inherited: the child has no business holding
    // them, and an inherited copy keeps the pipe alive past the child's exit.
    SetHandleInformation( rStdOut.hRead, HANDLE_FLAG_INHERIT, 0 );
    SetHandleInformation( rStdErr.hRead, HANDLE_FLAG_INHERIT, 0 );

    // Give the child a real (empty) stdin. With STARTF_USESTDHANDLES set and
    // hStdInput left at 0, a child that tries to read stdin — Git asking for
    // credentials, for one — gets an invalid handle and can stall.
    hNulIn          := CreateFile( 'NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,
      @SecurityAttr, OPEN_EXISTING, 0, 0 );

    ZeroMemory( @StartupInfo, SizeOf( TStartupInfo ) );
    StartupInfo.cb  := SizeOf( TStartupInfo );
    StartupInfo.hStdInput := hNulIn;
    StartupInfo.hStdOutput := rStdOut.hWrite;
    StartupInfo.hStdError := rStdErr.hWrite;
    StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow := SW_HIDE;

    // CreateProcessW is documented to modify lpCommandLine in place, so it must
    // never be handed a pointer into a shared or literal string.
    MutableCommand  := ( sCommandLine + #0 ).ToCharArray;

    if sWorkingDir.Trim.IsEmpty then
      pWorkingDir   := nil
    else
      pWorkingDir   := PChar( sWorkingDir );

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
    //
    // GIT_DIR, GIT_WORK_TREE and GIT_INDEX_FILE are REMOVED: inherited from a
    // shell that launched us, they would point every command at one repository
    // regardless of the working directory given here.  Removed, not set empty:
    // an empty GIT_DIR makes every Git command fail.
    sEnvironment    := BuildChildEnvironment(
      [ 'GIT_TERMINAL_PROMPT=0',
        'GCM_INTERACTIVE=Never',
        'GIT_ASKPASS=',
        'SSH_ASKPASS=',
        'GIT_OPTIONAL_LOCKS=0',
        'LC_ALL=C',
        'LANG=C' ],
      [ 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE' ] );
    EnvBlock        := sEnvironment.ToCharArray;

    // A Job Object with KILL_ON_JOB_CLOSE makes the timeout path able to take
    // the whole process tree down. git.exe routinely spawns git-remote-https,
    // ssh or a credential helper, and terminating only the direct child leaves
    // those running — one orphan per repository per refresh against an
    // unreachable remote, each still holding the inherited pipe.
    hJob            := CreateJobObject( nil, nil );

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
      bProcessStarted := CreateProcess(
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

      // Read the error inside the lock, before another thread's API call can
      // replace it.  A missing folder or a missing git.exe used to come back
      // as False with EMPTY output, so the row said "Error" and nothing more.
      if ( not bProcessStarted ) then
        sSpawnError := Format( 'Could not start the command: %s',
          [ SysErrorMessage( Winapi.Windows.GetLastError ) ] );
    finally
      GProcessSpawnLock.Leave;
    end;

    if ( not bProcessStarted ) then
      Exit;

    // Assign before the first instruction runs, so nothing can escape the job.
    if hJob <> 0 then
      AssignProcessToJobObject( hJob, ProcessInfo.hProcess );

    ResumeThread( ProcessInfo.hThread );

    // Release the parent's copies of the write ends, or the read ends never
    // see EOF.
    CloseHandle( rStdOut.hWrite );
    rStdOut.hWrite  := 0;
    CloseHandle( rStdErr.hWrite );
    rStdErr.hWrite  := 0;

    SetLength( naBuffer, PIPE_BUFFER_SIZE );
    SetLength( rStdOut.naBytes, PIPE_BUFFER_SIZE );
    SetLength( rStdErr.naBytes, PIPE_BUFFER_SIZE );
    iRemainingTimeout := iTimeout;

    repeat
      dwWaitResult  := WaitForSingleObject( ProcessInfo.hProcess, 100 );
      DrainPipe( rStdOut );
      DrainPipe( rStdErr );

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
          hJob      := 0;
        end;
        TerminateProcess( ProcessInfo.hProcess, 1 );
        WaitForSingleObject( ProcessInfo.hProcess, 5000 );
        bTimedOut   := True;
        Break;
      end;
    until False;

    // Anything written between the last poll and exit.  Repeated until both
    // pipes are empty: one pass is capped at MAX_READS_PER_DRAIN reads.
    repeat
      var iBefore   := rStdOut.iCount + rStdErr.iCount;
      var bWasCut   := rStdOut.bTruncated or rStdErr.bTruncated;

      DrainPipe( rStdOut );
      DrainPipe( rStdErr );

      if ( ( rStdOut.iCount + rStdErr.iCount ) = iBefore ) and
        ( ( not PeekNamedPipe( rStdOut.hRead, nil, 0, nil, @dwBytesAvail, nil ) ) or ( dwBytesAvail = 0 ) ) and
        ( ( not PeekNamedPipe( rStdErr.hRead, nil, 0, nil, @dwBytesAvail, nil ) ) or ( dwBytesAvail = 0 ) ) then
        Break;

      if bWasCut and bTimedOut then
        Break;
    until False;

    if ( not bTimedOut ) and GetExitCodeProcess( ProcessInfo.hProcess, dwExitCode ) then
      Result        := ( dwExitCode = 0 );
  finally
    // A caller that PARSES the result asks for stdout alone.  It still gets
    // stderr when the command failed, because then the text is a diagnostic
    // for the log and not data.
    sOutput         := CaptureText( rStdOut );

    if ( ( not bStdOutOnly ) or ( not Result ) ) and ( rStdErr.iCount > 0 ) then
    begin
      if sOutput.IsEmpty then
        sOutput     := CaptureText( rStdErr )
      else
        sOutput     := sOutput.TrimRight + sLineBreak + CaptureText( rStdErr );
    end;

    if ( not sSpawnError.IsEmpty ) then
      sOutput       := sSpawnError;

    if bTimedOut then
      sOutput       := sOutput.TrimRight + sLineBreak + 'Operation timed out';

    if bProcessStarted then
    begin
      CloseHandle( ProcessInfo.hProcess );
      CloseHandle( ProcessInfo.hThread );
    end;

    if hNulIn <> INVALID_HANDLE_VALUE then
      CloseHandle( hNulIn );

    for var hPipe in [ rStdOut.hWrite, rStdOut.hRead, rStdErr.hWrite, rStdErr.hRead ] do
    begin
      if hPipe <> 0 then
        CloseHandle( hPipe );
    end;

    if hJob <> 0 then
      CloseHandle( hJob );
  end;

end;

function RedactSecrets( const AText: string ): string;
begin

  Result            := AText;

  if Result.IsEmpty then
    Exit;

  try
    // https://user:token@host  ->  https://***:***@host
    Result          := TRegEx.Replace( Result, '(?i)(https?://)[^/\s:@]+:[^/\s@]+@', '$1***:***@' );

    // https://<long opaque userinfo>@host  ->  https://***@host
    //
    // The threshold is deliberately high: a Codeberg PAT is 40 characters and
    // a GitHub one longer still, whereas 'https://GITLAK@codeberg.org/...'
    // carries no secret and the owner name is worth keeping in the log.
    Result          := TRegEx.Replace( Result, '(?i)(https?://)[A-Za-z0-9_-]{24,}@', '$1***@' );

    // Bare provider token literals (GitHub classic/fine-grained, Gitea/Forgejo).
    Result          := TRegEx.Replace( Result, '(gh[pousr]_)[A-Za-z0-9]{16,}', '$1***' );
    Result          := TRegEx.Replace( Result, '(github_pat_)[A-Za-z0-9_]{16,}', '$1***' );

    // Authorization headers, in either the Gitea 'token' or the OAuth 'Bearer'
    // form. These reach the log through API error text.
    Result          := TRegEx.Replace( Result, '(?i)(authorization\s*:\s*(?:token|bearer)\s+)\S+', '$1***' );

    // A Codeberg/Gitea/Forgejo token is 40 lowercase hex with NO prefix, which
    // is indistinguishable from the commit hashes Git prints constantly — so it
    // cannot be matched by shape. Masking the live values by literal comparison
    // is exact, and covers whatever format a future provider uses.
    for var sSecret in GetKnownSecrets do
    begin
      if Length( sSecret ) >= MIN_REDACTABLE_SECRET_LENGTH then
        Result      := StringReplace( Result, sSecret, '***', [ rfReplaceAll, rfIgnoreCase ] );
    end;
  except
    // A regular-expression failure must not break logging, and the text is
    // returned as far as it was masked.  A defect of ours still surfaces.
    on E: Exception do
    begin
      if IsDefectException( E ) then
        raise;
    end;
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

  Result            := '';
  bProtected        := False;

  if ASecret.IsEmpty then
  begin
    bProtected      := True; // Nothing to protect is not a failure
    Exit;
  end;

  if ASecret.StartsWith( SECRET_PREFIX ) then
  begin
    bProtected      := True; // Already protected — pass it through
    Exit( ASecret );
  end;

  Plain             := TEncoding.UTF8.GetBytes( ASecret );
  Entropy           := TEncoding.UTF8.GetBytes( SECRET_ENTROPY );

  if Length( Plain ) = 0 then
    Exit;

  try
    InBlob.cbData   := Length( Plain );
    InBlob.pbData   := @Plain[ 0 ];
    EntropyBlob.cbData := Length( Entropy );
    EntropyBlob.pbData := @Entropy[ 0 ];
    OutBlob.cbData  := 0;
    OutBlob.pbData  := nil;

    // CRYPTPROTECT_UI_FORBIDDEN: SaveConfig can be reached from a worker
    // thread, where a DPAPI prompt would hang rather than fail.
    if CryptProtectData( @InBlob, 'GitBatchCommit', @EntropyBlob, nil, nil,
      CRYPTPROTECT_UI_FORBIDDEN, @OutBlob ) then
    begin
      try
        SetLength( Cipher, OutBlob.cbData );

        if OutBlob.cbData > 0 then
          Move( OutBlob.pbData^, Cipher[ 0 ], OutBlob.cbData );

        Result      := SECRET_PREFIX + TNetEncoding.Base64.EncodeBytesToString( Cipher );
        bProtected  := True;
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

  Result            := AStored;

  if ( not AStored.StartsWith( SECRET_PREFIX ) ) then
    Exit;

  Result            := '';

  try
    Cipher          := TNetEncoding.Base64.DecodeStringToBytes( AStored.Substring( Length( SECRET_PREFIX ) ) );
  except
    // Stored text that is not Base64 ( a hand-edited file ) reads as "no
    // token"; the stored text itself is kept by LoadConfig.
    on E: Exception do
    begin
      if IsDefectException( E ) then
        raise;

      Exit;
    end;
  end;

  if Length( Cipher ) = 0 then
    Exit;

  Entropy           := TEncoding.UTF8.GetBytes( SECRET_ENTROPY );
  InBlob.cbData     := Length( Cipher );
  InBlob.pbData     := @Cipher[ 0 ];
  EntropyBlob.cbData := Length( Entropy );
  EntropyBlob.pbData := @Entropy[ 0 ];
  OutBlob.cbData    := 0;
  OutBlob.pbData    := nil;

  // Try the current scheme first, then fall back to a blob written BEFORE
  // application entropy was introduced. Without this fallback, upgrading
  // silently fails to decrypt every stored token and loads them as empty -
  // and the next save then overwrites the stored ciphertext with nothing,
  // losing the credential outright. A value recovered here is re-written with
  // entropy by the next SaveConfig.
  bDecrypted        := CryptUnprotectData( @InBlob, nil, @EntropyBlob, nil, nil,
    CRYPTPROTECT_UI_FORBIDDEN, @OutBlob );

  if ( not bDecrypted ) then
  begin
    OutBlob.cbData  := 0;
    OutBlob.pbData  := nil;
    bDecrypted      := CryptUnprotectData( @InBlob, nil, nil, nil, nil,
      CRYPTPROTECT_UI_FORBIDDEN, @OutBlob );
  end;

  if bDecrypted then
  begin
    try
      SetLength( Plain, OutBlob.cbData );

      if OutBlob.cbData > 0 then
        Move( OutBlob.pbData^, Plain[ 0 ], OutBlob.cbData );

      Result        := TEncoding.UTF8.GetString( Plain );
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
    Result          := 'Unknown';
  end;

end;

function RemoteProviderToString( const Provider: TRemoteProvider ): string;
begin

  case Provider of
    rpGitHub: Result := 'GitHub';
    rpOther: Result := 'Other';
  else
    Result          := 'None';
  end;

end;

function SanitiseRepoName( const AName: string ): string;
begin

  Result            := '';

  for var cChar in AName do
    case cChar of
      'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.':
        Result      := Result + cChar;
      ' ', #9:
        ; // drop whitespace: "Front Door Camera" -> "FrontDoorCamera"
    else
      Result        := Result + '-';
    end;

  // Collapse runs of '-' left by stripped punctuation, then trim separators
  while Pos( '--', Result ) > 0 do
    Result          := StringReplace( Result, '--', '-', [ rfReplaceAll ] );

  Result            := Result.Trim( [ '-', '.', '_' ] );

  if Result = '' then
    Result          := 'repo';

end;

function IsValidRepoName( const AName: string ): Boolean;
begin

  // GitHub's own rule: 1 to 100 characters from [A-Za-z0-9._-], and not one of
  // the two reserved directory names.
  Result            := TRegEx.IsMatch( AName, '\A[A-Za-z0-9._-]{1,100}\z' ) and
    ( AName <> '.' ) and ( AName <> '..' );

end;

{ TGitRepoManager }

constructor TGitRepoManager.Create( const sConfigPath: string );
begin

  inherited Create;
  FConfigPath       := if sConfigPath.IsEmpty then GetConfigFilePath else sConfigPath;
  FReposLock        := TCriticalSection.Create;
  FListsLock        := TCriticalSection.Create;
  FConfigLock       := TCriticalSection.Create;
  FVersionCache     := TDictionary<string, string>.Create;
  FVersionCacheStamp := TDictionary<string, TDateTime>.Create;
  FVersionScanStamp := TDictionary<string, TDateTime>.Create;
  FConfigLoaded     := False;
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

  Result            := -1;

  var sWanted       := NormaliseRepoPath( sPath );

  for var iI := 0 to High( FRepos ) do
  begin
    if SameText( FRepos[ iI ].Path, sWanted ) then
      Exit( iI );
  end;

end;

class function TGitRepoManager.NormaliseRepoPath( const sPath: string ): string;
begin

  // One spelling per folder.  'D:\Repo' and 'D:\Repo\' used to be two entries,
  // and a status refresh published to the first only.
  Result            := ExcludeTrailingPathDelimiter( Trim( sPath ) );

end;

function TGitRepoManager.ReadShared( var sField: string ): string;
begin

  FListsLock.Enter;

  try
    Result          := sField;
    UniqueString( Result );
  finally
    FListsLock.Leave;
  end;

end;

procedure TGitRepoManager.WriteShared( var sField: string; const sValue: string );
begin

  FListsLock.Enter;

  try
    sField          := sValue;
    UniqueString( sField );
  finally
    FListsLock.Leave;
  end;

end;

function TGitRepoManager.GetGitHubUsername: string;
begin

  Result            := ReadShared( FGitHubUsername );

end;

procedure TGitRepoManager.SetGitHubUsername( const AValue: string );
begin

  WriteShared( FGitHubUsername, AValue.Trim );

end;

function TGitRepoManager.GetGitHubToken: string;
begin

  Result            := ReadShared( FGitHubToken );

end;

function TGitRepoManager.GetGitClientPath: string;
begin

  Result            := ReadShared( FGitClientPath );

end;

procedure TGitRepoManager.SetGitClientPath( const AValue: string );
begin

  WriteShared( FGitClientPath, AValue );

end;

function TGitRepoManager.GetFilePattern: string;
begin

  Result            := ReadShared( FFilePattern );

end;

procedure TGitRepoManager.SetFilePattern( const AValue: string );
begin

  WriteShared( FFilePattern, AValue );

end;

function TGitRepoManager.GetDelphiIndexerPath: string;
begin

  Result            := ReadShared( FDelphiIndexerPath );

end;

procedure TGitRepoManager.SetDelphiIndexerPath( const AValue: string );
begin

  WriteShared( FDelphiIndexerPath, AValue );

end;

function TGitRepoManager.GetStyleName: string;
begin

  Result            := ReadShared( FStyleName );

end;

procedure TGitRepoManager.SetStyleName( const AValue: string );
begin

  WriteShared( FStyleName, AValue );

end;

function TGitRepoManager.GetLastSaveError: string;
begin

  Result            := ReadShared( FLastSaveError );

end;

function TGitRepoManager.GetLastLoadError: string;
begin

  Result            := ReadShared( FLastLoadError );

end;

procedure TGitRepoManager.SetCommitTemplates( const AValue: TArray<string> );
begin

  FListsLock.Enter;

  try
    // A private copy: the caller's array must not become the live one.
    SetLength( FCommitTemplates, Length( AValue ) );

    for var iI := 0 to High( AValue ) do
      FCommitTemplates[ iI ] := AValue[ iI ];
  finally
    FListsLock.Leave;
  end;

end;

function TGitRepoManager.RemoteExists( const sRepoPath, sRemoteName: string ): Boolean;
var
  sOutput           : string;
begin

  Result            := False;

  if ( not ExecuteGitCommand( sRepoPath, 'remote', sOutput, GIT_QUICK_TIMEOUT, True ) ) then
    Exit;

  for var sLine in Trim( sOutput ).Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty ) do
  begin
    if SameText( Trim( sLine ), sRemoteName ) then
      Exit( True );
  end;

end;

function TGitRepoManager.GetRepoSnapshotByPath( const sPath: string; out ARepo: TRepoInfo ): Boolean;
begin

  Result            := False;
  FReposLock.Enter;

  try
    var iIndex      := IndexOfPathLocked( sPath );

    if iIndex < 0 then
      Exit;

    ARepo           := FRepos[ iIndex ];
    Result          := True;
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
      Result[ iI ]  := FRepos[ iI ];
  finally
    FReposLock.Leave;
  end;

end;

procedure TGitRepoManager.SetRepoSelected( const sPath: string; const bSelected: Boolean );
begin

  FReposLock.Enter;

  try
    var iIndex      := IndexOfPathLocked( sPath );

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

  sTrim             := Trim( sPattern );

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

  Result            := True;

end;

function TGitRepoManager.ReposCount: Integer;
begin

  FReposLock.Enter;

  try
    Result          := Length( FRepos );
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

    ARepo           := FRepos[ iIndex ];
    Result          := True;
  finally
    FReposLock.Leave;
  end;

end;

function TGitRepoManager.GetCurrentBranch( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result            := '';

  if ExecuteGitCommand( sRepoPath, 'rev-parse --abbrev-ref HEAD', sOutput, GIT_QUICK_TIMEOUT, True ) then
  begin
    Result          := Trim( sOutput );

    // "HEAD" means detached — no usable branch
    if SameText( Result, 'HEAD' ) then
      Result        := '';
  end;

  // Fall back to symbolic-ref for a fresh repo (no commits yet)
  if Result.IsEmpty then
  begin
    if ExecuteGitCommand( sRepoPath, 'symbolic-ref --short HEAD', sOutput, GIT_QUICK_TIMEOUT, True ) then
      Result        := Trim( sOutput );
  end;

end;

function TGitRepoManager.HasAnyCommit( const sRepoPath: string ): Boolean;
var
  sOutput           : string;
begin

  Result            := ExecuteGitCommand( sRepoPath, 'rev-parse --verify HEAD', sOutput, GIT_QUICK_TIMEOUT, True );

end;

function TGitRepoManager.IsWorkingTreeClean( const sRepoPath: string ): Boolean;
var
  sOutput           : string;
begin

  Result            := ExecuteGitCommand( sRepoPath, 'status --porcelain', sOutput, GIT_COMMAND_TIMEOUT, True ) and
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

  sDir              := TPath.Combine( TPath.GetHomePath, 'GitBatchCommit' );

  if ( not TDirectory.Exists( sDir ) ) then
  begin
    try
      TDirectory.CreateDirectory( sDir );
    except
      on E: Exception do
      begin
        if IsDefectException( E ) then
          raise;

        // Fall back to application directory if home directory fails
        sDir        := ExtractFilePath( ParamStr( 0 ) );
      end;
    end;
  end;

  Result            := TPath.Combine( sDir, 'repositories.json' );

end;

function TGitRepoManager.ExecuteGitCommand( const sRepoPath, sCommand: string; out sOutput: string;
  const iTimeout: Cardinal; const bStdOutOnly: Boolean ): Boolean;
var
  sGitExe           : string;
  sFullCommand      : string;
begin

  // Honour the configured Git client ONLY when it actually is git.exe. The
  // setting is documented and prompted for as a GUI client ( Fork, TortoiseGit ),
  // and running one of those with Git's arguments never returns: CREATE_NO_WINDOW
  // suppresses a console, not a GUI, so every call burnt the full timeout and
  // every repository reported as an error.
  sGitExe           := GitClientPath.Trim;

  if ( not sGitExe.IsEmpty ) and SameText( ExtractFileName( sGitExe ), GIT_EXE_NAME ) and
    TFile.Exists( sGitExe ) then
    sGitExe         := Format( '"%s"', [ sGitExe ] )
  else
    sGitExe         := ResolveGitExecutable;

  // -c core.quotepath=false keeps non-ASCII paths readable in porcelain output
  // instead of Git's default octal-escaped, double-quoted form.
  //
  // status.showUntrackedFiles is forced because a user who sets it to 'no'
  // globally ( a standard large-tree performance setting ) made a repository
  // holding nothing but brand-new files report Clean, so it was dropped from
  // the batch and never committed, silently.
  //
  // TRUST MODEL ( Ian, 2026-11-10 ):  a repository in the list is TRUSTED.  Its
  // own hooks run, and its own configuration is honoured.  Earlier builds
  // passed '-c core.hooksPath=' and '-c core.sshCommand=' to stop a scanned
  // repository naming a program for Git to run; that also switched off every
  // repository's pre-commit hook for commits made here ( the estate's .dproj
  // and ProductVersion hooks never ran ) and made every SSH remote fail with
  // "cannot spawn".  It was never complete either: credential.helper, filter
  // drivers, core.askPass and gpg.program were still read from the repository.
  // Do not add a folder you do not trust.
  sFullCommand      := Format( '%s -c core.quotepath=false -c status.showUntrackedFiles=normal -c color.ui=false %s',
    [ sGitExe, sCommand ] );

  Result            := RunProcessCaptureOutput( sFullCommand, sRepoPath, sOutput, iTimeout, bStdOutOnly );

end;

function TGitRepoManager.ResolveGitDir( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result            := '';

  if ExecuteGitCommand( sRepoPath, 'rev-parse --absolute-git-dir', sOutput, GIT_QUICK_TIMEOUT, True ) then
    Result          := Trim( sOutput );

end;

function TGitRepoManager.IsGitWorkTree( const sRepoPath: string ): Boolean;
var
  sOutput           : string;
begin

  Result            := ExecuteGitCommand( sRepoPath, 'rev-parse --is-inside-work-tree', sOutput, GIT_QUICK_TIMEOUT, True ) and
    SameText( Trim( sOutput ), 'true' );

end;

function TGitRepoManager.GetUpstreamSHA( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result            := '';

  if ExecuteGitCommand( sRepoPath, 'rev-parse --verify --quiet @{upstream}', sOutput, GIT_QUICK_TIMEOUT, True ) then
    Result          := Trim( sOutput );

  // Anything that is not a plain hex object name is not a lease we can use.
  if ( not TRegEx.IsMatch( Result, '^[0-9a-fA-F]{7,64}$' ) ) then
    Result          := '';

end;

function TGitRepoManager.GetUpstreamRemoteName( const sRepoPath: string ): string;
var
  sOutput           : string;
  sBranch           : string;
begin

  Result            := 'origin';
  sBranch           := GetCurrentBranch( sRepoPath );

  if sBranch.IsEmpty then
    Exit;

  if ExecuteGitCommand( sRepoPath, Format( 'config --get branch.%s.remote', [ sBranch ] ), sOutput,
    GIT_QUICK_TIMEOUT, True ) then
  begin
    var sName       := Trim( sOutput );

    // branch.<name>.remote may legally hold a URL; only a plain remote NAME is
    // usable as the remote argument of the pushes built from this.
    if TRegEx.IsMatch( sName, '\A[A-Za-z0-9._-]+\z' ) then
      Result        := sName;
  end;

end;

function TGitRepoManager.CreateCommitMessageFile( const sMessage: string; out sTempFile: string ): Boolean;
begin

  Result            := False;

  try
    sTempFile       := TPath.Combine( TPath.GetTempPath, Format( 'gitcommit_%s.txt', [ TPath.GetGUIDFileName( False ) ] ) );

    // The single-argument overload writes UTF-8 WITHOUT a byte-order mark.
    // The explicit-encoding overload passes WriteBOM = True, and Git does not
    // strip a BOM from a -F message file — it becomes an invisible U+FEFF at
    // the head of every commit subject line.
    TFile.WriteAllText( sTempFile, sMessage );
    Result          := True;
  except
    // An unwritable TEMP folder is an environment failure the caller reports;
    // anything else is ours and goes to EurekaLog.
    on E: Exception do
    begin
      if IsDefectException( E ) then
        raise;

      sTempFile     := '';
    end;
  end;

end;

procedure TGitRepoManager.DeleteCommitMessageFile( const sTempFile: string );
begin

  if sTempFile.IsEmpty or ( not TFile.Exists( sTempFile ) ) then
    Exit;

  // A leftover message file in TEMP harms nothing, so a refusal to delete it
  // ( a scanner holding it open ) is not worth failing the commit over.
  if ( not System.SysUtils.DeleteFile( sTempFile ) ) then
    OutputDebugString( PChar( Format( 'GitBatchCommit: could not delete "%s"', [ sTempFile ] ) ) );

end;

function TGitRepoManager.GetRepoBranch( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result            := '';

  if ExecuteGitCommand( sRepoPath, 'branch --show-current', sOutput, GIT_QUICK_TIMEOUT, True ) then
    Result          := Trim( sOutput );

  if Result.IsEmpty then
    Result          := '(unknown)';

end;

function TGitRepoManager.GetAheadBehind( const sRepoPath: string; const bFetch: Boolean;
  out iAhead, iBehind: Integer; out bFetchOK, bHasUpstream: Boolean ): Boolean;
var
  sOutput           : string;
  sBranch           : string;
  iParsedAhead      : Integer;
  iParsedBehind     : Integer;

  /// <summary>
  ///   Reads the two counts `rev-list --left-right --count` prints.
  /// </summary>
  function ParseCounts( const sText: string ): Boolean;
  begin

    var saParts     := Trim( sText ).Split( [ #9, ' ' ], TStringSplitOptions.ExcludeEmpty );

    // Both fields must be all-digits before either is trusted.
    Result          := ( Length( saParts ) = 2 ) and TRegEx.IsMatch( saParts[ 0 ], '^\d+$' ) and
      TRegEx.IsMatch( saParts[ 1 ], '^\d+$' );

    if Result then
    begin
      iParsedBehind := StrToIntDef( saParts[ 0 ], 0 );
      iParsedAhead  := StrToIntDef( saParts[ 1 ], 0 );
    end;

  end;

begin

  Result            := False;
  iAhead            := 0;
  iBehind           := 0;
  iParsedAhead      := 0;
  iParsedBehind     := 0;
  bFetchOK          := True;
  bHasUpstream      := False;

  // Refresh remote-tracking refs first; without this the comparison below
  // reports against whatever was last fetched.  The RESULT is kept: offline,
  // or with an expired credential, the counts that follow describe stale refs,
  // and the caller has to be able to say so rather than show "Clean".
  if bFetch and ExecuteGitCommand( sRepoPath, 'remote', sOutput, GIT_QUICK_TIMEOUT, True ) and
    ( not Trim( sOutput ).IsEmpty ) then
    bFetchOK        := ExecuteGitCommand( sRepoPath, 'fetch', sOutput );

  // Left side is the upstream (commits we lack = behind), right side is HEAD
  // (commits the upstream lacks = ahead).
  if ExecuteGitCommand( sRepoPath, 'rev-list --left-right --count @{upstream}...HEAD', sOutput,
    GIT_QUICK_TIMEOUT, True ) then
  begin
    bHasUpstream    := True;
    Result          := ParseCounts( sOutput );
  end
  else
  begin
    // No upstream configured.  That is NOT the same as "nothing to push": a
    // branch pushed once without -u, or never pushed at all, landed here and
    // was shown as Clean indefinitely.  Compare with origin's branch of the
    // same name when there is one; when there is not, the counts are unknown
    // and the caller decides what that means.
    sBranch         := GetCurrentBranch( sRepoPath );

    if ( not sBranch.IsEmpty ) and ExecuteGitCommand( sRepoPath,
      Format( 'rev-list --left-right --count refs/remotes/origin/%s...HEAD', [ sBranch ] ), sOutput,
      GIT_QUICK_TIMEOUT, True ) then
      Result        := ParseCounts( sOutput );
  end;

  if Result then
  begin
    iAhead          := iParsedAhead;
    iBehind         := iParsedBehind;
  end;

end;

function TGitRepoManager.HasUnmergedPaths( const sPorcelainOutput: string ): Boolean;
const
  UNMERGED_CODES    : array[ 0..6 ] of string = ( 'DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU' );
var
  Lines             : TArray<string>;
  sCode             : string;
begin

  Result            := False;

  if Trim( sPorcelainOutput ).IsEmpty then
    Exit;

  Lines             := sPorcelainOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );

  for var sLine in Lines do
  begin
    if Length( sLine ) < 2 then
      Continue;

    sCode           := Copy( sLine, 1, 2 );

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

  Result            := False;

  // Resolve the REAL git directory. Combining the working tree with '.git'
  // only works for an ordinary clone; in a linked worktree or a submodule
  // .git is a file pointing elsewhere, so every probe below silently returned
  // False and the whole conflict guard was blind for those repositories.
  sGitDir           := ResolveGitDir( sRepoPath );

  if sGitDir.IsEmpty then
    Exit;

  Result            := TFile.Exists( TPath.Combine( sGitDir, 'MERGE_HEAD' ) ) or
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
begin

  Result            := 0;

  // --deduplicate matters: during a content conflict `ls-files` prints the
  // same path once per index stage, so a conflicted repository reported three
  // times its real tracked-file count.
  if ExecuteGitCommand( sRepoPath, 'ls-files --deduplicate', sOutput, GIT_COMMAND_TIMEOUT, True ) then
  begin
    sOutput         := Trim( sOutput );

    if ( not sOutput.IsEmpty ) then
      Result        := Length( sOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty ) );
  end;

end;

function TGitRepoManager.LoadConfig: Boolean;
var
  sJSON             : string;
  oValue            : TJSONValue;
  oRoot             : TJSONObject;
  oRepos            : TJSONArray;
  oList             : TJSONArray;

  /// <summary>
  ///   Records why the file could not be used and keeps a copy of it, so that
  ///   the next save cannot destroy the only record of the user's repositories.
  /// </summary>
  procedure ConfigUnreadable( const sReason: string );
  begin

    var sBackup     := Format( '%s.unreadable-%s', [ FConfigPath,
      FormatDateTime( 'yyyymmdd"-"hhnnss', Now, TFormatSettings.Invariant ) ] );

    if CopyFile( PChar( FConfigPath ), PChar( sBackup ), True ) then
    begin
      // The original is safe under another name, so this session may save.
      FConfigLoaded := True;
      WriteShared( FLastLoadError, Format( 'The configuration file "%s" could not be read (%s).' + sLineBreak +
        sLineBreak + 'It has been kept as "%s", and an empty configuration has been started.',
        [ FConfigPath, sReason, sBackup ] ) );
    end
    else
    begin
      // No copy could be made, so nothing may be written over it.
      FConfigUnreadable := True;
      WriteShared( FLastLoadError, Format( 'The configuration file "%s" could not be read (%s), and it could ' +
        'not be copied aside either.' + sLineBreak + sLineBreak +
        'Nothing will be saved in this session, so that the file is not overwritten.  Close whatever ' +
        'is holding it and restart.', [ FConfigPath, sReason ] ) );
    end;

  end;

begin

  Result            := False;
  FConfigLoaded     := False;
  FConfigUnreadable := False;
  WriteShared( FLastLoadError, '' );

  FReposLock.Enter;

  try
    SetLength( FRepos, 0 );
  finally
    FReposLock.Leave;
  end;

  FListsLock.Enter;

  try
    SetLength( FCommitHistory, 0 );
    SetLength( FCommitTemplates, 0 );
    FGitHubUsername := '';
    FGitHubToken    := '';
    FGitHubTokenCipher := '';
    FGitClientPath  := '';
    FFilePattern    := '';
    FDelphiIndexerPath := '';
    FStyleName      := '';
  finally
    FListsLock.Leave;
  end;

  if ( not TFile.Exists( FConfigPath ) ) then
  begin
    Result          := True; // No config file is not an error
    FConfigLoaded   := True;
    Exit;
  end;

  try
    sJSON           := TFile.ReadAllText( FConfigPath, TEncoding.UTF8 );
  except
    // A locked file, a bad byte sequence or a vanished share: reported to the
    // user through LastLoadError.  A defect of ours goes to EurekaLog.
    on E: Exception do
    begin
      if IsDefectException( E ) then
        raise;

      ConfigUnreadable( E.Message );
      Exit;
    end;
  end;

  if sJSON.Trim.IsEmpty then
  begin
    Result          := True;
    FConfigLoaded   := True;
    Exit;
  end;

  // ParseJSONValue returns nil for malformed text; it does not raise.
  oValue            := TJSONObject.ParseJSONValue( sJSON );

  if ( not Assigned( oValue ) ) then
  begin
    ConfigUnreadable( 'it is not valid JSON' );
    Exit;
  end;

  try
    oRepos          := nil;

    // Support both old format (array) and new format (object with repos and credentials)
    if ( oValue is TJSONArray ) then
      oRepos        := TJSONArray( oValue )
    else if ( oValue is TJSONObject ) then
    begin
      oRoot         := TJSONObject( oValue );

      // The token is stored DPAPI-protected; a value without the marker is a
      // plain-text token from an older build and is read as-is, then re-written
      // protected by the next SaveConfig.  The stored text itself is kept too:
      // it is what a save writes back when the token cannot be re-protected,
      // or could not be decrypted here.
      var sStoredToken := oRoot.GetValue<string>( 'github_token', '' );
      var sToken    := SanitiseTokenValue( UnprotectSecret( sStoredToken ) );

      FListsLock.Enter;

      try
        FGitHubUsername := oRoot.GetValue<string>( 'github_username', '' );
        FGitHubToken := sToken;
        FGitHubTokenCipher := sStoredToken;
        FGitClientPath := oRoot.GetValue<string>( 'git_client_path', '' );
        FFilePattern := oRoot.GetValue<string>( 'file_pattern', '' );
        FDelphiIndexerPath := oRoot.GetValue<string>( 'delphi_indexer_path', '' );
        FStyleName  := oRoot.GetValue<string>( 'vcl_style', '' );

        // Drop any file pattern that contains shell metacharacters — config
        // files can be hand-edited, so never trust them blindly.
        if ( not IsSafeFilePattern( FFilePattern ) ) then
          FFilePattern := '';

        if oRoot.GetValue( 'commit_history' ) is TJSONArray then
        begin
          oList     := TJSONArray( oRoot.GetValue( 'commit_history' ) );
          SetLength( FCommitHistory, oList.Count );

          for var iI := 0 to oList.Count - 1 do
            FCommitHistory[ iI ] := oList.Items[ iI ].Value;
        end;

        if oRoot.GetValue( 'commit_templates' ) is TJSONArray then
        begin
          oList     := TJSONArray( oRoot.GetValue( 'commit_templates' ) );
          SetLength( FCommitTemplates, oList.Count );

          for var iI := 0 to oList.Count - 1 do
            FCommitTemplates[ iI ] := oList.Items[ iI ].Value;
        end;
      finally
        FListsLock.Leave;
      end;

      // Registered for redaction by exact match.
      RegisterKnownSecrets( sToken );

      if oRoot.GetValue( 'repositories' ) is TJSONArray then
        oRepos      := TJSONArray( oRoot.GetValue( 'repositories' ) );
    end
    else
    begin
      ConfigUnreadable( 'it does not hold a configuration object' );
      Exit;
    end;

    if Assigned( oRepos ) then
    begin
      FReposLock.Enter;

      try
        for var iI := 0 to oRepos.Count - 1 do
        begin
          // An entry that is not an object, or has no path, is dropped.  It
          // used to be kept as a blank row and written back on every save.
          if oRepos.Items[ iI ] is not TJSONObject then
            Continue;

          var oEntry := TJSONObject( oRepos.Items[ iI ] );
          var sPath := NormaliseRepoPath( oEntry.GetValue<string>( 'path', '' ) );

          if sPath.IsEmpty or ( IndexOfPathLocked( sPath ) >= 0 ) then
            Continue;

          var rRepo := Default( TRepoInfo );

          rRepo.Path := sPath;
          rRepo.Name := ExtractFileName( sPath );
          rRepo.Status := rsUnknown;
          rRepo.Provider := rpNone;
          rRepo.Group := oEntry.GetValue<string>( 'group', '' );
          FRepos    := FRepos + [ rRepo ];
        end;
      finally
        FReposLock.Leave;
      end;
    end;

    Result          := True;
    FConfigLoaded   := True;
  finally
    oValue.Free;
  end;

end;

function TGitRepoManager.SaveConfig: Boolean;
var
  oRoot             : TJSONObject;
  oArray            : TJSONArray;
  sToken            : string;
  sTempPath         : string;
  bTokenOK          : Boolean;
begin

  Result            := False;

  // One writer at a time, and the lock is taken BEFORE the snapshots.  Taken
  // after them, two savers could each snapshot and then write in the opposite
  // order, leaving the OLDER state on disk.
  FConfigLock.Enter;

  try
    // Never write over a configuration that could not be read.  This used to
    // guard an EMPTY repository list only, so adding a single repository after
    // a failed load replaced the whole file - the list, the groups, the
    // history, the templates and the stored token.  It also used to return
    // True, so the caller reported a save that never happened.
    if FConfigUnreadable or ( ( not FConfigLoaded ) and TFile.Exists( FConfigPath ) ) then
    begin
      WriteShared( FLastSaveError, Format( 'Nothing was saved: the configuration file "%s" could not be ' +
        'read when the application started, and it has been left untouched.', [ FConfigPath ] ) );
      Exit;
    end;

    var rRepos      := SnapshotAll;
    var saHistory   := GetCommitHistorySnapshot;
    var saTemplates := GetCommitTemplatesSnapshot;

    // Protect the token BEFORE anything is written. There is no plain-text
    // fallback: if DPAPI fails, the caller is told, rather than a live
    // credential being written in clear.
    sToken          := ProtectSecret( GitHubToken, bTokenOK );

    // Keep what is already on disk whenever there is nothing better to write:
    // a stored value that could not be decrypted at load ( the token is then
    // empty in memory ), or one that could not be re-protected just now.
    // Writing '' in either case destroys the only copy.  An explicit change of
    // the token clears the kept text, so a cleared token really is cleared.
    var sKeptCipher := ReadShared( FGitHubTokenCipher );

    if sToken.IsEmpty and ( not sKeptCipher.IsEmpty ) then
      sToken        := sKeptCipher;

    if bTokenOK then
      WriteShared( FLastSaveError, '' )
    else
      WriteShared( FLastSaveError, 'Windows could not encrypt the access token, so the new value has NOT ' +
        'been saved; a token stored earlier is still in the file.  Every other setting was saved normally.  ' +
        'Re-enter the token once the problem is resolved; it is never written in plain text.' );

    oRoot           := TJSONObject.Create;

    try
      // The token is encrypted with DPAPI under the current user account, so
      // the config file holds no usable credential if it is copied, backed up
      // or roamed off this machine.
      oRoot.AddPair( 'github_username', GitHubUsername );
      oRoot.AddPair( 'github_token', sToken );
      oRoot.AddPair( 'git_client_path', GitClientPath );
      oRoot.AddPair( 'file_pattern', FilePattern );
      oRoot.AddPair( 'delphi_indexer_path', DelphiIndexerPath );
      oRoot.AddPair( 'vcl_style', StyleName );

      oArray        := TJSONArray.Create;
      oRoot.AddPair( 'commit_history', oArray );

      for var sItem in saHistory do
        oArray.Add( sItem );

      oArray        := TJSONArray.Create;
      oRoot.AddPair( 'commit_templates', oArray );

      for var sItem in saTemplates do
        oArray.Add( sItem );

      oArray        := TJSONArray.Create;
      oRoot.AddPair( 'repositories', oArray );

      for var rRepo in rRepos do
      begin
        var oEntry  := TJSONObject.Create;

        oArray.AddElement( oEntry );
        oEntry.AddPair( 'path', rRepo.Path );
        oEntry.AddPair( 'group', rRepo.Group );
      end;

      // Write a temporary file, then REPLACE the real one in a single call.
      // The earlier delete-then-move had a window with no configuration on disk
      // at all, and its error handler then deleted the temporary file too.  The
      // process id keeps two running instances off each other's temporary file.
      sTempPath     := Format( '%s.%d.tmp', [ FConfigPath, GetCurrentProcessId ] );

      try
        TFile.WriteAllText( sTempPath, oRoot.Format, TEncoding.UTF8 );

        if ( not MoveFileEx( PChar( sTempPath ), PChar( FConfigPath ),
          MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH ) ) then
          RaiseLastOSError;

        // What is on disk now is what a later save may fall back on.
        if bTokenOK then
          WriteShared( FGitHubTokenCipher, sToken );

        Result      := True;
      except
        // A read-only folder, a locked file or a full disk: reported through
        // LastSaveError.  The real file has not been touched.
        on E: Exception do
        begin
          if IsDefectException( E ) then
            raise;

          WriteShared( FLastSaveError, Format( 'Could not save the configuration to "%s": %s',
            [ FConfigPath, E.Message ] ) );
          System.SysUtils.DeleteFile( sTempPath );
        end;
      end;
    finally
      oRoot.Free;
    end;
  finally
    FConfigLock.Leave;
  end;

  if ( not Result ) or ( not bTokenOK ) then
    OutputDebugString( PChar( Format( 'GitBatchCommit: %s', [ LastSaveError ] ) ) );

end;

procedure TGitRepoManager.SetGitHubToken( const AValue: string );
begin

  var sToken        := SanitiseTokenValue( AValue );

  // An explicit assignment of a DIFFERENT value supersedes what is on disk,
  // including an explicit clear.  Re-assigning the same value ( the settings
  // dialog does that when only the user name was edited ) must not discard a
  // stored token that could not be decrypted.
  if sToken <> GitHubToken then
  begin
    WriteShared( FGitHubToken, sToken );

    // Only an explicit CLEAR discards the stored text.  For a new value it is
    // kept until the new one has been protected and written, so that a DPAPI
    // failure at save leaves the previous token on disk instead of nothing.
    if sToken.IsEmpty then
      WriteShared( FGitHubTokenCipher, '' );
  end;

  RegisterKnownSecrets( sToken );

end;

function TGitRepoManager.GetCommitHistorySnapshot: TArray<string>;
begin

  FListsLock.Enter;

  try
    SetLength( Result, Length( FCommitHistory ) );

    for var iI := 0 to High( FCommitHistory ) do
      Result[ iI ]  := FCommitHistory[ iI ];
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
      Result[ iI ]  := FCommitTemplates[ iI ];
  finally
    FListsLock.Leave;
  end;

end;

function TGitRepoManager.AddRepository( const sPath: string ): Boolean;
begin

  Result            := False;

  var sNormalised   := NormaliseRepoPath( sPath );

  if sNormalised.IsEmpty then
    Exit;

  FReposLock.Enter;

  try
    if IndexOfPathLocked( sNormalised ) >= 0 then
      Exit;

    var rRepo       := Default( TRepoInfo );

    rRepo.Path      := sNormalised;
    rRepo.Name      := ExtractFileName( sNormalised );
    rRepo.Status    := rsUnknown;
    rRepo.Provider  := rpNone;
    FRepos          := FRepos + [ rRepo ];
  finally
    FReposLock.Leave;
  end;

  // Local state only.  This runs on the UI thread, and the fetch a full
  // refresh makes can hold it for the whole command timeout against a slow or
  // dead remote.  The next refresh brings the remote comparison up to date.
  RefreshStatus( sNormalised, False );
  SaveConfig;
  Result            := True;

end;

procedure TGitRepoManager.RemoveRepository( const sPath: string );
begin

  FReposLock.Enter;

  try
    var iIndex      := IndexOfPathLocked( sPath );

    if iIndex < 0 then
      Exit;

    // The caches are keyed on the lower-cased path ( see GetProjectVersion ).
    // Removing by the path as stored never matched a mixed-case one, so the
    // three dictionaries only ever grew.
    var sKey        := FRepos[ iIndex ].Path.ToLower;

    Delete( FRepos, iIndex, 1 );

    FVersionCache.Remove( sKey );
    FVersionCacheStamp.Remove( sKey );
    FVersionScanStamp.Remove( sKey );
  finally
    FReposLock.Leave;
  end;

  SaveConfig;

end;

procedure TGitRepoManager.RefreshStatus( const sRepoPath: string; const bFetch: Boolean );
var
  sStatusOutput     : string;
  sBranch           : string;
  sVersion          : string;
  sStatusText       : string;
  sRemoteSHA        : string;
  eStatus           : TRepoStatus;
  eProvider         : TRemoteProvider;
  iTracked          : Integer;
  iModified         : Integer;
  iAhead            : Integer;
  iBehind           : Integer;
  bArtifactOnly     : Boolean;
  bFetchOK          : Boolean;
  bHasUpstream      : Boolean;
  bCountsKnown      : Boolean;
  bNotOnRemote      : Boolean;
begin

  // All the (slow, blocking) Git work happens outside the lock; results are
  // published under it by path match. Holding the lock across a git invocation
  // would serialise the whole parallel refresh, and touching FRepos without it
  // races with Add/Remove, which re-size the array and can move its body out
  // from under a worker thread.
  if sRepoPath.Trim.IsEmpty then
    Exit;

  sBranch           := GetRepoBranch( sRepoPath );
  iModified         := 0;
  iAhead            := 0;
  iBehind           := 0;
  bArtifactOnly     := False;
  bFetchOK          := True;
  bHasUpstream      := False;
  bNotOnRemote      := False;

  // Report the remote that push and pull will ACTUALLY use, not origin. These
  // differ whenever a branch tracks something else, and the ahead/behind
  // counts, which come from @{upstream}, would otherwise be measured against a
  // remote the user was never shown.
  eProvider         := DetectRemoteProvider( GetUpstreamRemoteURL( sRepoPath ) );

  // Ask Git whether this is a working tree rather than looking for a .git
  // FOLDER. In a linked worktree or a submodule .git is a file, and the folder
  // test reported every one of them as an error, permanently.
  if ( not IsGitWorkTree( sRepoPath ) ) then
    eStatus         := rsError
  else if ExecuteGitCommand( sRepoPath, 'status --porcelain --untracked-files=all', sStatusOutput, GIT_COMMAND_TIMEOUT, True ) then
  begin
    // TrimRight, never Trim.  Porcelain is 'XY <path>' and X is a SPACE for a
    // change that is not staged, so trimming the left of the text shifted the
    // first line by one column: ' M Win32/x.res' was read as path 'in32/x.res'.
    sStatusOutput   := sStatusOutput.TrimRight;

    if ( not sStatusOutput.IsEmpty ) then
      iModified     := Length( sStatusOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty ) );

    // Ask how the branch stands against its upstream BEFORE deciding the
    // status, so a repository that is both modified and behind can say so.
    bCountsKnown    := GetAheadBehind( sRepoPath, bFetch, iAhead, iBehind, bFetchOK, bHasUpstream );

    // Order matters. An unmerged path outranks everything: staging it with
    // `add -A` and committing would write conflict markers into history, so it
    // must never be presented as an ordinary modification ready to commit.
    if HasUnmergedPaths( sStatusOutput ) or HasOperationInProgress( sRepoPath ) then
      eStatus       := rsConflicted
    else if ( not sStatusOutput.IsEmpty ) and ( not AllChangesAreBuildArtifacts( sStatusOutput ) ) then
      eStatus       := rsModified
    else
    begin
      // Remember that changes existed but were all build output, so the UI can
      // say the repository was SKIPPED.
      bArtifactOnly := ( not sStatusOutput.IsEmpty );

      // A branch with commits, a remote, and nothing on that remote to compare
      // with has never been pushed.  It used to be shown as Clean.
      bNotOnRemote  := ( not bCountsKnown ) and ( eProvider <> rpNone ) and HasAnyCommit( sRepoPath ) and
        ( not GetCurrentBranch( sRepoPath ).IsEmpty );

      if ( iAhead > 0 ) and ( iBehind > 0 ) then
        eStatus     := rsDiverged
      else if iBehind > 0 then
        eStatus     := rsPullRequired
      else if ( iAhead > 0 ) or bNotOnRemote then
        eStatus     := rsPushRequired
      else
        eStatus     := rsClean;
    end;
  end
  else
    eStatus         := rsError;

  iTracked          := GetTrackedFileCount( sRepoPath );
  sVersion          := GetProjectVersion( sRepoPath );

  // Capture where the upstream stands as the user is being shown this row.
  // ForcePushRepository names it as an explicit lease, so a force push is
  // refused when the remote has moved on since.
  sRemoteSHA        := GetUpstreamSHA( sRepoPath );

  // Carry the commit counts in the display text - the columns are fixed, and
  // "Push Required (3)" is far more useful than "Push Required" alone.
  sStatusText       := RepoStatusToString( eStatus );

  if bNotOnRemote and ( eStatus = rsPushRequired ) then
    sStatusText     := Format( '%s (not on the remote)', [ sStatusText ] )
  else if eStatus = rsPullRequired then
    sStatusText     := Format( '%s (%d)', [ sStatusText, iBehind ] )
  else if eStatus = rsPushRequired then
    sStatusText     := Format( '%s (%d)', [ sStatusText, iAhead ] )
  else if eStatus = rsDiverged then
    sStatusText     := Format( '%s (+%d/-%d)', [ sStatusText, iAhead, iBehind ] );

  // Say so when the working tree DOES have changes but every one of them is
  // build output. The repository scores as clean and is therefore skipped by
  // Commit & Push, which filters to Modified.
  if bArtifactOnly then
    sStatusText     := Format( '%s - build output only', [ sStatusText ] );

  // A modified or conflicted repository still carries the Status slot for its
  // working tree, so the pull it owes has nowhere else to appear.
  if ( eStatus in [ rsModified, rsConflicted ] ) and ( iBehind > 0 ) then
    sStatusText     := Format( '%s - %d to pull', [ sStatusText, iBehind ] );

  // The comparison above was made against refs that could not be refreshed.
  // A local-only refresh keeps the verdict of the last refresh that fetched,
  // in the text as well as in the flag: the row must not read "Clean" while
  // Force Push is being refused for a failed fetch.
  if ( not bFetch ) then
  begin
    var rPrevious: TRepoInfo;

    if GetRepoSnapshotByPath( sRepoPath, rPrevious ) then
      bFetchOK      := not rPrevious.FetchFailed;
  end;

  if ( not bFetchOK ) then
    sStatusText     := Format( '%s - fetch failed', [ sStatusText ] );

  // Publish. Re-locate by path rather than trusting an index: the array may
  // have been reordered or shortened while the Git calls above were running.
  FReposLock.Enter;

  try
    var iIndex      := IndexOfPathLocked( sRepoPath );

    if iIndex >= 0 then
    begin
      FRepos[ iIndex ].Branch := sBranch;
      FRepos[ iIndex ].Status := eStatus;
      FRepos[ iIndex ].StatusText := sStatusText;
      FRepos[ iIndex ].ModifiedFileCount := iModified;
      FRepos[ iIndex ].TrackedFileCount := iTracked;
      FRepos[ iIndex ].Provider := eProvider;
      FRepos[ iIndex ].Version := sVersion;
      FRepos[ iIndex ].RemoteSHA := sRemoteSHA;
      FRepos[ iIndex ].ArtifactOnlyChanges := bArtifactOnly;
      FRepos[ iIndex ].BehindCount := iBehind;
      FRepos[ iIndex ].AheadCount := iAhead;

      // A local-only refresh says nothing about the remote, so it must not
      // clear a failure recorded by the last refresh that did try to fetch.
      if bFetch then
        FRepos[ iIndex ].FetchFailed := not bFetchOK;
      FRepos[ iIndex ].HasUpstream := bHasUpstream;
    end;
  finally
    FReposLock.Leave;
  end;

end;

function TGitRepoManager.CommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sTempFile         : string;
  sVersion          : string;
  sTagName          : string;
  sBranch           : string;
  sRemote           : string;
  sPattern          : string;
  rRepo             : TRepoInfo;
  iAhead            : Integer;
  iBehind           : Integer;
  bFetchOK          : Boolean;
  bHasUpstream      : Boolean;
  bCommitted        : Boolean;

  /// <summary>
  ///   Appends one line to the operation log.
  /// </summary>
  procedure AddLog( const sLine: string );
  begin
    sLog            := sLog + sLine + sLineBreak;
  end;

begin

  Result            := False;
  sLog              := '';
  bCommitted        := False;

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sLog            := 'Repository is no longer in the list';
    Exit;
  end;

  AddLog( Format( '=== %s ===', [ rRepo.Name ] ) );

  // Refuse outright while a merge/rebase/cherry-pick is unfinished or any path
  // is unmerged. `add -A` would stage files still containing conflict markers,
  // and the commit that followed would push them to the remote.
  //
  // These are SEPARATE refusals on purpose. Written as one `and` chain, a
  // `git status` that failed or timed out made the whole condition False and
  // execution fell straight through to `add -A`. An indeterminate state must
  // refuse, never proceed.
  if HasOperationInProgress( rRepo.Path ) then
  begin
    AddLog( 'Refused to commit - the repository has an unfinished merge, rebase, ' +
      'cherry-pick, revert or bisect. Finish or abort it first.' );
    Exit;
  end;

  if ( not ExecuteGitCommand( rRepo.Path, 'status --porcelain --untracked-files=all', sOutput, GIT_COMMAND_TIMEOUT, True ) ) then
  begin
    AddLog( Format( 'Refused to commit - could not determine the repository state: %s', [ Trim( sOutput ) ] ) );
    Exit;
  end;

  if HasUnmergedPaths( sOutput ) then
  begin
    AddLog( 'Refused to commit - the repository has unresolved conflicts. Resolve ' +
      'them first (Resolve Conflicts, or finish the operation in a Git client).' );
    Exit;
  end;

  // A detached HEAD accepts `add` and `commit` perfectly happily and then fails
  // at the push, leaving the work in a commit reachable only from the reflog.
  sBranch           := GetCurrentBranch( rRepo.Path );

  if sBranch.IsEmpty then
  begin
    AddLog( 'Refused to commit - HEAD is detached or the branch is unborn. Check out a branch first.' );
    Exit;
  end;

  // Refuse while the branch is behind its upstream. Committing first and
  // discovering it at the push is far worse than refusing: the push is rejected
  // non-fast-forward, the work is already committed, and the repository is left
  // DIVERGED. Refusing here leaves the repository exactly as it was, so Pull
  // Selected is enough to make it pushable.
  GetAheadBehind( rRepo.Path, True, iAhead, iBehind, bFetchOK, bHasUpstream );

  if ( not bFetchOK ) then
    AddLog( 'Warning: the fetch failed, so the "behind" check used the last fetched state.' );

  if iBehind > 0 then
  begin
    AddLog( Format( 'Refused to commit - the branch is %d commit(s) behind %s. ' +
      'Pull first (Pull Selected), then commit.', [ iBehind, sBranch ] ) );
    Exit;
  end;

  // Stage changes (use file pattern if specified)
  sPattern          := FilePattern.Trim;

  if sPattern.IsEmpty then
  begin
    if ( not ExecuteGitCommand( rRepo.Path, 'add -A', sOutput, GIT_NETWORK_TIMEOUT ) ) then
    begin
      AddLog( Format( 'Failed to stage changes: %s', [ Trim( sOutput ) ] ) );
      Exit;
    end;

    AddLog( 'Staged all changes' );
  end
  else
  begin
    // Refuse to execute a file pattern that contains shell metacharacters.
    // Belt-and-braces: the settings dialog already validates, but config files
    // can be hand-edited, so we re-check here.
    if ( not IsSafeFilePattern( sPattern ) ) then
    begin
      AddLog( Format( 'Refused to stage - file pattern contains unsafe characters: %s', [ sPattern ] ) );
      Exit;
    end;

    if ( not ExecuteGitCommand( rRepo.Path, Format( 'add -- %s', [ sPattern ] ), sOutput, GIT_NETWORK_TIMEOUT ) ) then
    begin
      AddLog( Format( 'Failed to stage changes: %s', [ Trim( sOutput ) ] ) );
      Exit;
    end;

    AddLog( Format( 'Staged changes matching: %s', [ sPattern ] ) );
  end;

  // Create temp file for commit message (avoids command injection)
  if ( not CreateCommitMessageFile( sMessage, sTempFile ) ) then
  begin
    AddLog( 'Failed to create commit message file' );
    Exit;
  end;

  try
    // Nothing staged is not a failure. `git commit` exits 1 in that case, and
    // treating that as fatal meant a repository whose work was already
    // committed but never pushed could not be pushed by Commit & Push at all.
    if ExecuteGitCommand( rRepo.Path, 'diff --cached --quiet', sOutput ) then
      AddLog( 'Nothing staged - skipping the commit' )
    else if ( not ExecuteGitCommand( rRepo.Path, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput,
      GIT_NETWORK_TIMEOUT ) ) then
    begin
      // The repository's own pre-commit hook runs here, and a refusal from it
      // arrives as this failure with the hook's text.
      AddLog( Format( 'Commit failed: %s', [ Trim( sOutput ) ] ) );
      Exit;
    end
    else
    begin
      bCommitted    := True;
      AddLog( Format( 'Committed: %s', [ Trim( sOutput ) ] ) );
    end;
  finally
    DeleteCommitMessageFile( sTempFile );
  end;

  // The message is worth keeping as soon as it is in a commit, whether or not
  // the push that follows succeeds.
  if bCommitted then
    AddToCommitHistory( sMessage );

  // Push.  A branch with no upstream is given one; a bare `push` would fail
  // with "no upstream branch" and leave the commit stranded.
  sRemote           := GetUpstreamRemoteName( rRepo.Path );

  // In a variable of its own.  Passing one string as both the command and the
  // OUT parameter empties the command before the call is made: an out string
  // is cleared by the caller, and git was then run with no sub-command at all.
  var sPushCommand  := if bHasUpstream then 'push' else Format( 'push -u %s -- %s', [ sRemote, sBranch ] );

  if ( not ExecuteGitCommand( rRepo.Path, sPushCommand, sOutput, GIT_NETWORK_TIMEOUT ) ) then
  begin
    AddLog( Format( 'Push failed: %s', [ Trim( sOutput ) ] ) );

    if bCommitted then
      AddLog( 'The commit was made locally and has NOT been pushed. Use Push Only once the problem is resolved.' );

    // The row must stop saying "Modified" now that the work is committed.
    RefreshStatus( rRepo.Path, False );
    Exit;
  end;

  AddLog( 'Pushed successfully' );

  // Create and push version tag if .dproj version exists. The scan TTL is
  // bypassed here: this value decides the tag that gets PUSHED, and a version
  // bumped seconds before the commit would otherwise be tagged with the
  // previous number, or skipped entirely because that tag already exists.
  sVersion          := GetProjectVersion( rRepo.Path, True );

  if ( not sVersion.IsEmpty ) then
  begin
    sTagName        := Format( 'v%s', [ sVersion ] );

    // `--` terminates option parsing. The version is read verbatim out of a
    // .dproj in the repository being committed, so without it a crafted
    // FileVersion could append arguments of its own to the push below.
    // IsValidVersionString is the primary guard; this is the second one.
    if ExecuteGitCommand( rRepo.Path, Format( 'tag -l -- "%s"', [ sTagName ] ), sOutput, GIT_QUICK_TIMEOUT, True ) then
    begin
      var bTagExists := not Trim( sOutput ).IsEmpty;

      if ( not bTagExists ) then
      begin
        bTagExists  := ExecuteGitCommand( rRepo.Path,
          Format( 'tag -a "%s" -m "Version %s"', [ sTagName, sVersion ] ), sOutput );

        if bTagExists then
          AddLog( Format( 'Created tag: %s', [ sTagName ] ) )
        else
          AddLog( Format( 'Warning: Failed to create tag: %s', [ Trim( sOutput ) ] ) );
      end;

      // Pushed whether it was created just now or already existed: a tag whose
      // push failed last time used to be reported as "already exists" and was
      // never sent.  Pushing one the remote already has is a no-op.  It goes
      // to the same remote as the commit, not to whatever is called origin.
      if bTagExists then
      begin
        if ExecuteGitCommand( rRepo.Path, Format( 'push %s -- "refs/tags/%s"', [ sRemote, sTagName ] ), sOutput,
          GIT_NETWORK_TIMEOUT ) then
          AddLog( Format( 'Tag on the remote: %s', [ sTagName ] ) )
        else
          AddLog( Format( 'Warning: Failed to push tag %s: %s', [ sTagName, Trim( sOutput ) ] ) );
      end;
    end;
  end;

  Result            := True;
  RefreshStatus( rRepo.Path );

end;

function TGitRepoManager.ExecuteApiRequest( const sVerb, sBaseURL, sEndpoint, sBody: string;
  const aHeaders: TArray<TNameValuePair>; out sResponse: string; out iStatusCode: Integer ): Boolean;
var
  HttpClient        : TNetHTTPClient;
  Response          : IHTTPResponse;
  RequestStream     : TStringStream;
begin

  Result            := False;
  sResponse         := '';
  iStatusCode       := 0;

  HttpClient        := TNetHTTPClient.Create( nil );
  RequestStream     := TStringStream.Create( sBody, TEncoding.UTF8 );

  try
    ConfigureHttpClient( HttpClient );

    try
      if SameText( sVerb, 'POST' ) then
        Response    := HttpClient.Post( sBaseURL + sEndpoint, RequestStream, nil, aHeaders )
      else if SameText( sVerb, 'PATCH' ) then
        Response    := HttpClient.Patch( sBaseURL + sEndpoint, RequestStream, nil, aHeaders )
      else if SameText( sVerb, 'DELETE' ) then
        // No request body: GitHub takes the repository from the path and
        // rejects a DELETE that carries one.
        Response    := HttpClient.Delete( sBaseURL + sEndpoint, nil, aHeaders )
      else
      begin
        sResponse   := Format( 'Unsupported HTTP verb: %s', [ sVerb ] );
        Exit;
      end;

      iStatusCode   := Response.StatusCode;
      sResponse     := Response.ContentAsString;
      Result        := ( iStatusCode >= 200 ) and ( iStatusCode < 300 );
    except
      // No network, a refused connection, a TLS failure or a timeout: all
      // reported to the caller as text.  A defect of ours goes to EurekaLog.
      on E: Exception do
      begin
        if IsDefectException( E ) then
          raise;

        sResponse   := Format( 'HTTP Error: %s', [ E.Message ] );
      end;
    end;
  finally
    RequestStream.Free;
    HttpClient.Free;
  end;

end;

function TGitRepoManager.ExecuteGitHubApi( const sVerb, sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
begin

  Result            := ExecuteApiRequest( sVerb, GITHUB_API_URL, sEndpoint, sBody,
    [ TNameValuePair.Create( 'Authorization', Format( 'Bearer %s', [ GitHubToken ] ) ),
      TNameValuePair.Create( 'Content-Type', 'application/json' ),
      TNameValuePair.Create( 'Accept', 'application/vnd.github+json' ) ],
    sResponse, iStatusCode );

end;

function TGitRepoManager.GetRemoteOriginURL( const sRepoPath: string ): string;
var
  sOutput           : string;
begin

  Result            := '';

  if ExecuteGitCommand( sRepoPath, 'remote get-url origin', sOutput, GIT_QUICK_TIMEOUT, True ) then
    Result          := Trim( sOutput );

end;

function TGitRepoManager.GetUpstreamRemoteURL( const sRepoPath: string ): string;
var
  sBranch           : string;
  sRemoteName       : string;
  sOutput           : string;
begin

  Result            := '';
  sRemoteName       := '';
  sBranch           := GetCurrentBranch( sRepoPath );

  // branch.<name>.remote is what a bare push/pull follows. Asked this way it
  // stays quiet on a detached HEAD or an unconfigured branch, where the config
  // key simply does not exist.
  if ( not sBranch.IsEmpty ) and
    ExecuteGitCommand( sRepoPath, Format( 'config --get branch.%s.remote', [ sBranch ] ), sOutput,
    GIT_QUICK_TIMEOUT, True ) then
    sRemoteName     := Trim( sOutput );

  // A URL rather than a name is legal in branch.<name>.remote, and
  // `remote get-url` would reject it. Take it as the answer.
  if sRemoteName.Contains( '://' ) or sRemoteName.Contains( '@' ) then
    Exit( sRemoteName );

  if ( not sRemoteName.IsEmpty ) and
    ExecuteGitCommand( sRepoPath, Format( 'remote get-url %s', [ sRemoteName ] ), sOutput,
    GIT_QUICK_TIMEOUT, True ) then
    Result          := Trim( sOutput );

  // No upstream configured - fall back to origin, which is what the user would
  // reasonably assume the repository points at.
  if Result.IsEmpty then
    Result          := GetRemoteOriginURL( sRepoPath );

end;

function TGitRepoManager.DetectRemoteProvider( const sOriginURL: string ): TRemoteProvider;
begin

  Result            := rpNone;

  if sOriginURL.Trim.IsEmpty then
    Exit;

  // Compare the HOST, not the whole string. A substring test classified
  // https://gitea.internal/mirrors/github.com-backup.git as GitHub, which then
  // aimed a visibility change at api.github.com for a repository that does not
  // live there.
  var sHost         := ExtractURLHost( sOriginURL );

  if SameText( sHost, 'github.com' ) or SameText( sHost, 'www.github.com' ) then
    Result          := rpGitHub
  else
    Result          := rpOther;

end;

function TGitRepoManager.ParseOwnerRepo( const sOriginURL: string; out sOwner, sRepo: string ): Boolean;
var
  sURL              : string;
  iPosLastSlash     : Integer;
  iPosSecondLastSlash: Integer;
  sRepoWithExt      : string;
begin

  Result            := False;
  sOwner            := '';
  sRepo             := '';

  sURL              := Trim( sOriginURL );

  if sURL.IsEmpty then
    Exit;

  // Order matters, and it was wrong. Testing for '.git' first fails on
  // '.../repo.git/' because that ends with a slash, and the suffix was then
  // never re-tested - so sRepo came back as 'repo.git' and every API call 404'd
  // with "not found or no permission".
  while sURL.EndsWith( '/' ) do
    sURL            := Copy( sURL, 1, Length( sURL ) - 1 );

  if sURL.EndsWith( '.git', True ) then
    sURL            := Copy( sURL, 1, Length( sURL ) - 4 );

  while sURL.EndsWith( '/' ) do
    sURL            := Copy( sURL, 1, Length( sURL ) - 1 );

  // Find the last slash (repo name is after it)
  iPosLastSlash     := sURL.LastIndexOf( '/' );

  if iPosLastSlash < 0 then
    Exit;

  sRepoWithExt      := Copy( sURL, iPosLastSlash + 2, MaxInt );

  // Find the second-to-last slash (owner is after it)
  iPosSecondLastSlash := Copy( sURL, 1, iPosLastSlash ).LastIndexOf( '/' );

  if iPosSecondLastSlash < 0 then
  begin
    // Handle SSH format: git@github.com:owner/repo
    iPosSecondLastSlash := sURL.LastIndexOf( ':' );
  end;

  if iPosSecondLastSlash < 0 then
    Exit;

  sOwner            := Copy( sURL, iPosSecondLastSlash + 2, iPosLastSlash - iPosSecondLastSlash - 1 );
  sRepo             := sRepoWithExt;

  Result            := ( not sOwner.IsEmpty ) and ( not sRepo.IsEmpty );

end;

function TGitRepoManager.IsHigherVersion( const sCandidate, sCurrent: string ): Boolean;
var
  CandidateParts    : TArray<string>;
  CurrentParts      : TArray<string>;
begin

  if sCurrent.IsEmpty then
    Exit( not sCandidate.IsEmpty );

  CandidateParts    := sCandidate.Split( [ '.' ] );
  CurrentParts      := sCurrent.Split( [ '.' ] );

  for var i := 0 to Max( High( CandidateParts ), High( CurrentParts ) ) do
  begin
    var iNew        := 0;
    var iOld        := 0;

    if i <= High( CandidateParts ) then
      iNew          := StrToIntDef( CandidateParts[ i ], 0 );

    if i <= High( CurrentParts ) then
      iOld          := StrToIntDef( CurrentParts[ i ], 0 );

    if iNew > iOld then
      Exit( True );

    if iNew < iOld then
      Exit( False );
  end;

  Result            := False;

end;

function TGitRepoManager.ResolveActiveFileVersion( const sContent: string ): string;
var
  Lines             : TArray<string>;
  sLine             : string;
  sTrimmed          : string;
  sCondition        : string;
  sConfig           : string;
  sPlatform         : string;
  sCfgToken         : string;
  Candidates        : TArray<string>;
  iRank             : Integer;
  iBestRank         : Integer;
  iPos              : Integer;
  iEndPos           : Integer;
  sVersion          : string;

  /// Returns the value of an attribute on a single element line, or ''.
  function AttributeValue( const sElement, sAttr: string ): string;
  var
    iStart, iStop   : Integer;
  begin
    Result          := '';
    iStart          := sElement.IndexOf( sAttr + '="' );

    if iStart < 0 then
      Exit;

    Inc( iStart, Length( sAttr ) + 2 );
    iStop           := sElement.IndexOf( '"', iStart );

    if iStop > iStart then
      Result        := sElement.Substring( iStart, iStop - iStart );
  end;

  /// Returns the text of a single-line element, or ''.
  function ElementText( const sElement: string ): string;
  var
    iStart, iStop   : Integer;
  begin
    Result          := '';
    iStart          := sElement.IndexOf( '>' );
    iStop           := sElement.LastIndexOf( '</' );

    if ( iStart >= 0 ) and ( iStop > iStart ) then
      Result        := sElement.Substring( iStart + 1, iStop - iStart - 1 ).Trim;
  end;

begin

  Result            := '';
  Lines             := sContent.Split( [ #13, #10 ], TStringSplitOptions.ExcludeEmpty );

  // Pass 1 - the project's default configuration and platform. These are what
  // the IDE builds when nobody chooses otherwise, so they are what "active"
  // means for a repository we are merely tagging.
  sConfig           := '';
  sPlatform         := '';

  for sLine in Lines do
  begin
    sTrimmed := sLine.Trim;

    if sTrimmed.StartsWith( '<Config ' ) and sTrimmed.Contains( '$(Config)' ) then
      sConfig       := ElementText( sTrimmed )
    else if sTrimmed.StartsWith( '<Platform ' ) and sTrimmed.Contains( '$(Platform)' ) then
      sPlatform     := ElementText( sTrimmed );
  end;

  if sConfig.IsEmpty or sPlatform.IsEmpty then
    Exit;

  // Pass 2 - which Cfg_N token corresponds to that configuration name. The
  // numbering is per project, so Release is not reliably Cfg_1.
  //
  // The mapping lives on the declaring group's CONDITION, not on the <Cfg_N>
  // element inside it:
  //
  //   <PropertyGroup Condition="'$(Config)'=='Release' or '$(Cfg_1)'!=''">
  //     <Cfg_1>true</Cfg_1>
  //
  // so the token has to be read out of the condition string.
  sCfgToken         := '';

  for sLine in Lines do
  begin
    sTrimmed := sLine.Trim;

    if ( not sTrimmed.StartsWith( '<PropertyGroup' ) ) then
      Continue;

    sCondition      := AttributeValue( sTrimmed, 'Condition' );

    if ( not sCondition.Contains( '''$(Config)''==''' + sConfig + '''' ) ) then
      Continue;

    iPos            := sCondition.IndexOf( '''$(Cfg_' );

    if iPos < 0 then
      Continue;

    Inc( iPos, Length( '''$(' ) );
    iEndPos         := sCondition.IndexOf( ')', iPos );

    if iEndPos > iPos then
    begin
      sCfgToken     := sCondition.Substring( iPos, iEndPos - iPos );
      Break;
    end;
  end;

  if sCfgToken.IsEmpty then
    Exit;

  // The layering order MSBuild applies. Later entries override earlier ones,
  // so the LAST match wins - which is the whole point of this routine.
  Candidates        := [
    '''$(Base)''!=''''',
    Format( '''$(Base_%s)''!=''''', [ sPlatform ] ),
    Format( '''$(%s)''!=''''', [ sCfgToken ] ),
    Format( '''$(%s_%s)''!=''''', [ sCfgToken, sPlatform ] ) ];

  // Pass 3 - walk the groups, remembering the highest-ranked FileVersion seen.
  iBestRank         := -1;
  sCondition        := '';

  for sLine in Lines do
  begin
    sTrimmed := sLine.Trim;

    if sTrimmed.StartsWith( '<PropertyGroup' ) then
      sCondition    := AttributeValue( sTrimmed, 'Condition' )
    else if sTrimmed.StartsWith( '</PropertyGroup>' ) then
      sCondition    := '';

    if ( not sTrimmed.Contains( 'VerInfo_Keys' ) ) or ( not sTrimmed.Contains( 'FileVersion=' ) ) then
      Continue;

    iRank           := -1;

    for var i := 0 to High( Candidates ) do
      if sCondition = Candidates[ i ] then
      begin
        iRank       := i;
        Break;
      end;

    if iRank < iBestRank then
      Continue;

    iPos            := sTrimmed.IndexOf( 'FileVersion=' );

    if iPos < 0 then
      Continue;

    Inc( iPos, Length( 'FileVersion=' ) );
    iEndPos         := sTrimmed.IndexOf( ';', iPos );

    if iEndPos < 0 then
      iEndPos       := sTrimmed.IndexOf( '<', iPos );

    if iEndPos <= iPos then
      Continue;

    sVersion        := sTrimmed.Substring( iPos, iEndPos - iPos ).Trim;

    // Same guard as the caller: this value reaches `git tag` and `git push`,
    // so anything that is not a plain dotted number is refused outright.
    if ( iRank >= 0 ) and IsValidVersionString( sVersion ) then
    begin
      Result        := sVersion;
      iBestRank     := iRank;
    end;
  end;

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
  sKey              : string;
  CachedStamp       : TDateTime;
  CachedVersion     : string;
  ScanStamp         : TDateTime;
  NewestDprojWrite  : TDateTime;
  dt                : TDateTime;
begin

  Result            := '';
  sBestVersion      := '';
  sKey              := sRepoPath.ToLower;

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
  // Throughout this routine a folder or file that cannot be read ( removed,
  // locked, access denied ) simply contributes no version.
  try
    RootDprojFiles  := TDirectory.GetFiles( sRepoPath, '*.dproj', TSearchOption.soTopDirectoryOnly );
  except
    on E: Exception do
    begin
      if IsDefectException( E ) then
        raise;

      RootDprojFiles := nil;
    end;
  end;

  if Length( RootDprojFiles ) > 0 then
    DprojFiles      := RootDprojFiles
  else
  begin
    try
      DprojFiles    := TDirectory.GetFiles( sRepoPath, '*.dproj', TSearchOption.soAllDirectories );
    except
      on E: Exception do
      begin
        if IsDefectException( E ) then
          raise;

        Exit;
      end;
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
  NewestDprojWrite  := 0;

  for sDprojPath in DprojFiles do
  begin
    dt              := 0;

    try
      dt            := TFile.GetLastWriteTime( sDprojPath );
    except
      on E: Exception do
      begin
        if IsDefectException( E ) then
          raise;
      end;
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

  // Pass 1 - the version each project's ACTIVE configuration builds.
  //
  // This runs to completion BEFORE the fallback below, and that ordering is
  // the point: a resolved answer must never be beaten by the old
  // highest-anywhere scan of some other file in the same repository. Written
  // as one interleaved loop, an unresolvable sibling carrying a larger number
  // silently overrode the correctly resolved value.
  //
  // Across several .dproj FILES the highest still wins, which is the
  // long-standing behaviour and a different question from which group within
  // one file is active.
  for sDprojPath in DprojFiles do
  begin
    try
      sContent      := TFile.ReadAllText( sDprojPath, TEncoding.UTF8 );
    except
      on E: Exception do
      begin
        if IsDefectException( E ) then
          raise;

        Continue;
      end;
    end;

    sVersion        := ResolveActiveFileVersion( sContent );

    if IsHigherVersion( sVersion, sBestVersion ) then
      sBestVersion  := sVersion;
  end;

  // Pass 2 - only when NOTHING resolved. A project file that does not declare
  // a default Config and Platform cannot be resolved, and returning no version
  // at all would be worse than the old heuristic.
  if sBestVersion.IsEmpty then
  begin
    for sDprojPath in DprojFiles do
    begin
      try
        sContent    := TFile.ReadAllText( sDprojPath, TEncoding.UTF8 );
      except
        on E: Exception do
        begin
          if IsDefectException( E ) then
            raise;

          Continue;
        end;
      end;

      Lines         := sContent.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );

      for sLine in Lines do
      begin
        if ( not sLine.Contains( 'VerInfo_Keys' ) ) or ( not sLine.Contains( 'FileVersion=' ) ) then
          Continue;

        iPos        := sLine.IndexOf( 'FileVersion=' );

        if iPos < 0 then
          Continue;

        Inc( iPos, Length( 'FileVersion=' ) );
        iEndPos     := sLine.IndexOf( ';', iPos );

        if iEndPos < 0 then
          iEndPos   := sLine.IndexOf( '<', iPos );

        if iEndPos <= iPos then
          Continue;

        sVersion    := Trim( sLine.Substring( iPos, iEndPos - iPos ) );

        // Reject anything that is not a plain dotted number. This value comes
        // verbatim out of a .dproj belonging to the repository being
        // committed, and CommitAndPush interpolates it into `git tag` and
        // `git push` command lines - where an embedded quote closes the
        // quoting and the remainder becomes extra arguments to Git.
        if ( not IsValidVersionString( sVersion ) ) then
          Continue;

        if IsHigherVersion( sVersion, sBestVersion ) then
          sBestVersion := sVersion;
      end;
    end;
  end;

  Result            := sBestVersion;

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

  Result            := False;
  sLower            := sFileName.ToLower.Replace( '\', '/' );

  // Check by extension
  sExt              := ExtractFileExt( sLower );

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
    Result          := True;
    Exit;
  end;

  // Check by directory path.  The IDE's own folders are build output wherever
  // they appear.
  for var sDir in [ '__history/', '__recovery/' ] do
  begin
    if sLower.StartsWith( sDir ) or sLower.Contains( '/' + sDir ) then
      Exit( True );
  end;

  // A PLATFORM folder is build output only when a build-configuration folder
  // sits directly beneath it ( Win64/Release, Win32/Debug ).
  //
  // Neither half is enough alone.  Bare 'debug' and 'release' are ordinary
  // source and documentation folder names: matching them made a repository
  // whose only change was 'docs/release/notes.md' display as Clean.  And a
  // bare platform folder is ordinary too: 'Source/Win64/Thunks.pas', or the
  // per-platform package folders several of our own libraries keep, were
  // scored as build output, so a repository whose only change was real source
  // displayed as Clean and was dropped from the batch without a word.
  for var sDir in [ 'win32/', 'win64/', 'osx32/', 'osx64/', 'osxarm64/', 'iosdevice64/', 'iossimarm64/',
    'android/', 'android64/', 'linux64/' ] do
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

  Result            := False;

  if Trim( sPorcelainOutput ).IsEmpty then
    Exit;

  Lines             := sPorcelainOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );

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

    sFileName       := Copy( sLine, 4, MaxInt );

    // A rename has to be judged on BOTH sides. Testing only the destination
    // meant 'R  src/Foo.pas -> Win64/Foo.pas' looked like an artifact, so the
    // deletion of src/Foo.pas was never committed.
    if sFileName.Contains( ' -> ' ) then
    begin
      var iArrow    := Pos( ' -> ', sFileName );

      if ( not IsBuildArtifact( UnquotePorcelainPath( Copy( sFileName, 1, iArrow - 1 ) ) ) ) then
        Exit;

      sFileName     := Copy( sFileName, iArrow + 4, MaxInt );
    end;

    if ( not IsBuildArtifact( UnquotePorcelainPath( sFileName ) ) ) then
      Exit; // Found a real change
  end;

  // All changes are build artifacts
  Result            := True;

end;

function TGitRepoManager.GetRepoProvider( const sRepoPath: string ): TRemoteProvider;
var
  rRepo             : TRepoInfo;
begin

  Result            := rpNone;

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
    Exit;

  // The remote that push and pull use - the one the Remote column shows.
  Result            := DetectRemoteProvider( GetUpstreamRemoteURL( rRepo.Path ) );

end;

function TGitRepoManager.SetRepositoryVisibility( const sRepoPath: string; const bPrivate: Boolean;
  out sError: string ): Boolean;
var
  sRemoteURL        : string;
  sOwner            : string;
  sRepo             : string;
  sRequestBody      : string;
  sResponse         : string;
  iStatusCode       : Integer;
  rRepo             : TRepoInfo;
begin

  Result            := False;
  sError            := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sError          := 'Repository is no longer in the list';
    Exit;
  end;

  // The UPSTREAM remote: the one the Remote column names, and the one a
  // deletion acts on.  This used to read origin, so the three could disagree.
  sRemoteURL        := GetUpstreamRemoteURL( rRepo.Path );

  case DetectRemoteProvider( sRemoteURL ) of
    rpNone:
      begin
        sError      := 'No remote configured';
        Exit;
      end;

    rpOther:
      begin
        sError      := 'Visibility can only be changed for a GitHub repository';
        Exit;
      end;

    rpGitHub:
      ; // Supported - carry on below.
  end;

  if ( not ParseOwnerRepo( sRemoteURL, sOwner, sRepo ) ) then
  begin
    sError          := 'Could not read owner/repository from the remote URL';
    Exit;
  end;

  if ( not HasGitHubCredentials ) then
  begin
    sError          := 'GitHub credentials not configured';
    Exit;
  end;

  // Build JSON via TJSONObject so values are safely escaped.
  var oBody         := TJSONObject.Create;

  try
    oBody.AddPair( 'private', TJSONBool.Create( bPrivate ) );
    sRequestBody    := oBody.ToJSON;
  finally
    oBody.Free;
  end;

  if ( not ExecuteGitHubApi( 'PATCH', Format( '/repos/%s/%s', [ sOwner, sRepo ] ), sRequestBody, sResponse,
    iStatusCode ) ) then
  begin
    if iStatusCode = 404 then
      sError        := 'Repository not found or no permission'
    else if iStatusCode = 401 then
      sError        := 'Invalid GitHub credentials'
    else
      sError        := Format( 'GitHub API error (%d): %s', [ iStatusCode, sResponse ] );

    Exit;
  end;

  Result            := True;

end;

function TGitRepoManager.HasGitHubCredentials: Boolean;
begin

  Result            := ( not GitHubUsername.Trim.IsEmpty ) and ( not GitHubToken.Trim.IsEmpty );

end;

function TGitRepoManager.ResolveRemoteDeleteTarget( const sRepoPath: string;
  out sOwner, sRepo, sReason: string ): Boolean;
var
  sRemoteURL        : string;
  rRepo             : TRepoInfo;
begin

  Result            := False;
  sOwner            := '';
  sRepo             := '';
  sReason           := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sReason         := 'Repository is no longer in the list';
    Exit;
  end;

  // The UPSTREAM remote, not origin. This is the remote the Remote column
  // names and the one push and pull contact; deleting whatever is called
  // origin would delete a repository the user was never shown.
  sRemoteURL        := GetUpstreamRemoteURL( rRepo.Path );

  case DetectRemoteProvider( sRemoteURL ) of
    rpNone:
      begin
        sReason     := 'No remote configured';
        Exit;
      end;

    rpOther:
      begin
        sReason     := 'Remote is not on GitHub';
        Exit;
      end;

    rpGitHub:
      ; // Supported - carry on below.
  end;

  if ( not ParseOwnerRepo( sRemoteURL, sOwner, sRepo ) ) then
  begin
    sReason         := 'Could not read owner/repository from the remote URL';
    Exit;
  end;

  if ( not HasGitHubCredentials ) then
  begin
    sReason         := 'GitHub credentials not configured';
    Exit;
  end;

  Result            := True;

end;

function TGitRepoManager.DescribeRemoteDeleteTarget( const sRepoPath: string; out sDescription: string ): Boolean;
var
  sOwner            : string;
  sRepo             : string;
  sReason           : string;
begin

  Result            := ResolveRemoteDeleteTarget( sRepoPath, sOwner, sRepo, sReason );

  sDescription      := if Result then Format( 'GitHub: %s/%s', [ sOwner, sRepo ] ) else sReason;

end;

function TGitRepoManager.DeleteRemoteRepository( const sRepoPath: string; out sError: string ): Boolean;
var
  sOwner            : string;
  sRepo             : string;
  sResponse         : string;
  iStatusCode       : Integer;
begin

  Result            := False;

  if ( not ResolveRemoteDeleteTarget( sRepoPath, sOwner, sRepo, sError ) ) then
    Exit;

  // No request body: GitHub takes the repository from the path and rejects a
  // DELETE that carries one.
  if ( not ExecuteGitHubApi( 'DELETE', Format( '/repos/%s/%s', [ sOwner, sRepo ] ), '', sResponse, iStatusCode ) ) then
  begin
    case iStatusCode of
      401: sError   := 'Invalid GitHub credentials';

      // Authenticated, but the token may not delete. A GitHub fine-grained or
      // classic PAT needs the delete_repo scope, which is NOT included in repo
      // and is not needed by anything else this application does — so a token
      // that creates, pushes and changes visibility perfectly well still fails
      // here, and saying "no permission" alone would send the user looking at
      // the repository instead of at the token.
      403: sError   := Format( 'GitHub refused the deletion (%d). The access token needs the ' +
          'delete_repo scope, and you must own the repository: %s', [ iStatusCode, sResponse ] );

      404: sError   := Format( 'Repository %s/%s not found on GitHub, or the token cannot see it',
          [ sOwner, sRepo ] );
    else
      sError        := Format( 'GitHub API error (%d): %s', [ iStatusCode, sResponse ] );
    end;

    Exit;
  end;

  Result            := True;

end;

function TGitRepoManager.DeleteLocalRepository( const sRepoPath: string; const AOwnerHandle: HWND;
  out sError: string ): Boolean;
var
  sFolder           : string;
  sExeFolder        : string;
  FileOp            : TSHFileOpStruct;
  iResult           : Integer;
begin

  Result            := False;
  sError            := '';

  sFolder           := ExcludeTrailingPathDelimiter( Trim( sRepoPath ) );

  if sFolder.IsEmpty then
  begin
    sError          := 'No path recorded for this repository';
    Exit;
  end;

  if ( not TDirectory.Exists( sFolder ) ) then
  begin
    sError          := 'Folder does not exist: ' + sFolder;
    Exit;
  end;

  sFolder           := TPath.GetFullPath( sFolder );

  // Guards. The path is read back from a configuration file and the delete is
  // recursive, so each of these is the difference between removing a
  // repository and removing a drive.
  if SameText( IncludeTrailingPathDelimiter( sFolder ), TPath.GetPathRoot( sFolder ) ) then
  begin
    sError          := 'Refusing to delete a drive root: ' + sFolder;
    Exit;
  end;

  // Must be the repository ROOT. A .git entry — folder in an ordinary clone,
  // FILE in a worktree or submodule — proves it, and proves too that a
  // configured path which has since been re-pointed at some parent folder is
  // not deleted wholesale.
  if ( not TDirectory.Exists( TPath.Combine( sFolder, '.git' ) ) ) and
    ( not TFile.Exists( TPath.Combine( sFolder, '.git' ) ) ) then
  begin
    sError          := 'Not the root of a Git repository (no .git entry): ' + sFolder;
    Exit;
  end;

  sExeFolder        := IncludeTrailingPathDelimiter( TPath.GetFullPath( ExtractFilePath( ParamStr( 0 ) ) ) );

  if StartsText( IncludeTrailingPathDelimiter( sFolder ), sExeFolder ) then
  begin
    sError          := 'Refusing to delete the folder this application is running from: ' + sFolder;
    Exit;
  end;

  FillChar( FileOp, SizeOf( FileOp ), 0 );
  FileOp.Wnd        := AOwnerHandle;
  FileOp.wFunc      := FO_DELETE;

  // pFrom is a double-null-terminated list, so the terminating #0 of the last
  // entry is followed by another. A plain PChar of the path ends the list one
  // character early and the call fails with DE_INVALIDFILES (0x74).
  FileOp.pFrom      := PChar( sFolder + #0 );

  // FOF_WANTNUKEWARNING is the load-bearing flag: Windows falls back to a
  // PERMANENT delete when the tree will not fit in the Recycle Bin or the bin
  // is off for that drive, and without it that happens silently. With it, the
  // user is asked — FOF_NOCONFIRMATION suppresses the ordinary "are you sure",
  // not this one.
  FileOp.fFlags     := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_NOCONFIRMMKDIR or
    FOF_WANTNUKEWARNING or FOF_NOERRORUI;

  iResult           := SHFileOperation( FileOp );

  if iResult <> 0 then
  begin
    // SHFileOperation returns its OWN DE_* codes, not Win32 ones, and they are
    // not in GetLastError — so the raw number has to be translated here or the
    // user is told nothing. The ones named are those a repository actually
    // produces: a file held open by an editor, a Git client or an indexer, and
    // the deep paths that .git and node_modules trees reach.
    case iResult of
      $78: sError   := 'Access denied — a file in the folder is read-only or open in ' +
        'another application (an editor, a Git client or an indexer)';
      $79: sError   := 'The folder tree is nested too deeply for the shell to delete: ' + sFolder;
      $7C: sError   := 'The shell rejected the path as invalid: ' + sFolder;
      $81: sError   := 'A path inside the folder is too long for the shell to delete: ' + sFolder;
      $402: sError  := 'The shell reported an unknown error, usually an invalid path: ' + sFolder;
      $10000: sError := 'The shell could not write to the Recycle Bin for this drive';
    else
      sError        := Format( 'Delete failed with shell error 0x%x: %s', [ iResult, sFolder ] );
    end;

    Exit;
  end;

  if FileOp.fAnyOperationsAborted then
  begin
    sError          := 'Deletion was cancelled';
    Exit;
  end;

  // The shell reports success for a folder it only partly emptied, so confirm.
  if TDirectory.Exists( sFolder ) then
  begin
    sError          := 'Folder still exists after the delete reported success: ' + sFolder;
    Exit;
  end;

  Result            := True;

end;

function TGitRepoManager.CreateGitHubRepository( const sName, sDescription: string; const bPrivate: Boolean;
  out sRemoteURL, sError: string ): Boolean;
var
  sRequestBody      : string;
  sResponse         : string;
  iStatusCode       : Integer;
  oParsed           : TJSONValue;
begin

  Result            := False;
  sRemoteURL        := '';
  sError            := '';

  // Checked here as well as in the dialog: this is the last point before the
  // name leaves the machine, and whatever is typed reaches it.
  if ( not IsValidRepoName( sName ) ) then
  begin
    sError          := Format( '"%s" is not a valid repository name. Use letters, digits, "-", "_" and "." only.',
      [ sName ] );
    Exit;
  end;

  if ( not HasGitHubCredentials ) then
  begin
    sError          := 'GitHub credentials not configured';
    Exit;
  end;

  // Build request JSON via TJSONObject — safely escapes quotes/newlines in name/description.
  var oBody         := TJSONObject.Create;

  try
    oBody.AddPair( 'name', sName );
    oBody.AddPair( 'description', sDescription );
    oBody.AddPair( 'private', TJSONBool.Create( bPrivate ) );
    oBody.AddPair( 'auto_init', TJSONBool.Create( False ) );
    sRequestBody    := oBody.ToJSON;
  finally
    oBody.Free;
  end;

  if ( not ExecuteGitHubApi( 'POST', '/user/repos', sRequestBody, sResponse, iStatusCode ) ) then
  begin
    // GitHub answers 422 for EVERY validation failure, not only a duplicate.
    // Reporting them all as "already exists" sent the user looking for a
    // repository that was never there.
    if ( iStatusCode = 422 ) and ContainsText( sResponse, 'already exists' ) then
      sError        := Format( 'A repository named "%s" already exists on GitHub', [ sName ] )
    else if iStatusCode = 401 then
      sError        := 'Invalid GitHub credentials'
    else
      sError        := Format( 'GitHub API error (%d): %s', [ iStatusCode, sResponse ] );

    Exit;
  end;

  // Take clone_url from the response.  If it cannot be read, fall back to a
  // constructed URL so that the caller has *something* — the repository was
  // created on the server.  ParseJSONValue returns nil for malformed text.
  oParsed           := TJSONObject.ParseJSONValue( sResponse );

  try
    if oParsed is TJSONObject then
      sRemoteURL    := TJSONObject( oParsed ).GetValue<string>( 'clone_url', '' );
  finally
    oParsed.Free;
  end;

  if sRemoteURL.IsEmpty then
    sRemoteURL      := Format( 'https://github.com/%s/%s.git', [ GitHubUsername, sName ] );

  Result            := True;

end;

function TGitRepoManager.InitialiseRepository( const sPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result            := False;
  sLog              := '';

  if ( not TDirectory.Exists( sPath ) ) then
  begin
    sLog            := Format( 'Folder does not exist: %s', [ sPath ] );
    Exit;
  end;

  if HasGitEntry( sPath ) then
  begin
    sLog            := 'Folder is already a Git repository';
    Exit;
  end;

  if ( not ExecuteGitCommand( sPath, 'init', sOutput ) ) then
  begin
    sLog            := Format( 'Failed to initialise repository: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  sLog              := 'Initialised Git repository' + sLineBreak;

  // Rename default branch to main for consistency with modern Git defaults.
  // Older Git initialises to master — if the rename succeeds we log it, if it
  // fails we leave the branch name as-is (git 2.28+ already defaults to main
  // when init.defaultBranch is set).
  if ExecuteGitCommand( sPath, 'branch -M main', sOutput ) then
    sLog            := sLog + 'Set default branch to main' + sLineBreak;

  Result            := True;

end;

class function TGitRepoManager.HasGitEntry( const sPath: string ): Boolean;
begin

  // A folder in an ordinary clone, a FILE in a linked worktree or a submodule.
  Result            := TDirectory.Exists( TPath.Combine( sPath, '.git' ) ) or
    TFile.Exists( TPath.Combine( sPath, '.git' ) );

end;

function TGitRepoManager.CreateAndPushRepository( const sFolder, sName, sDescription: string;
  const bPrivate: Boolean; const sMessage: string; out sRemoteURL, sLog: string ): Boolean;
var
  sStepLog          : string;
  sError            : string;

  /// <summary>
  ///   Appends one line to the operation log.
  /// </summary>
  procedure AddLog( const sLine: string );
  begin
    sLog            := sLog + sLine.TrimRight + sLineBreak;
  end;

begin

  Result            := False;
  sLog              := '';
  sRemoteURL        := '';

  // Everything that can be refused WITHOUT changing anything is refused first.
  // The old order ran `git init` before the name and the credentials were
  // checked, so a rejected name left a half-made repository that a second
  // attempt then refused to touch ( "already a Git repository" ).
  if ( not TDirectory.Exists( sFolder ) ) then
  begin
    AddLog( Format( 'Folder does not exist: %s', [ sFolder ] ) );
    Exit;
  end;

  if ( not IsValidRepoName( sName ) ) then
  begin
    AddLog( Format( '"%s" is not a valid repository name. Use letters, digits, "-", "_" and "." only.', [ sName ] ) );
    Exit;
  end;

  if ( not HasGitHubCredentials ) then
  begin
    AddLog( 'GitHub credentials not configured' );
    Exit;
  end;

  // Each step below is skipped when an earlier attempt already completed it,
  // which is what makes a failed run RESUMABLE: run the command again on the
  // same folder and it carries on from where it stopped.
  if HasGitEntry( sFolder ) then
    AddLog( 'Folder is already a Git repository - continuing with it' )
  else
  begin
    if ( not InitialiseRepository( sFolder, sStepLog ) ) then
    begin
      AddLog( sStepLog );
      Exit;
    end;

    AddLog( sStepLog );
  end;

  sRemoteURL        := GetRemoteOriginURL( sFolder );

  if sRemoteURL.IsEmpty then
  begin
    if ( not CreateGitHubRepository( sName, sDescription, bPrivate, sRemoteURL, sError ) ) then
    begin
      AddLog( Format( 'Failed to create the GitHub repository: %s', [ sError ] ) );

      // An earlier run may have created it and then lost the reply.  It is not
      // adopted automatically: the name may equally belong to an unrelated
      // repository, and pushing into that is not what was asked for.
      if ContainsText( sError, 'already exists' ) then
        AddLog( Format( 'If an earlier run created it, connect this folder to it with' + sLineBreak +
          '  git remote add origin https://github.com/%s/%s.git' + sLineBreak +
          'and run the command again: it then pushes there without creating anything.', [ GitHubUsername, sName ] ) );

      Exit;
    end;

    AddLog( Format( 'Created GitHub repository: %s', [ sRemoteURL ] ) );

    if ( not AddRemoteOrigin( sFolder, sRemoteURL, sStepLog ) ) then
    begin
      AddLog( sStepLog );
      AddLog( Format( 'The repository %s now exists on GitHub but is not connected to this folder. ' +
        'Run the command again to continue.', [ sRemoteURL ] ) );
      Exit;
    end;

    AddLog( sStepLog );
  end
  else
    AddLog( Format( 'Remote origin is already set (%s) - nothing was created on GitHub', [ sRemoteURL ] ) );

  if ( not InitialCommitAndPush( sFolder, sMessage, sStepLog ) ) then
  begin
    AddLog( sStepLog );
    AddLog( Format( 'The remote repository is %s. Correct the problem and run the command again to finish the push.',
      [ sRemoteURL ] ) );
    Exit;
  end;

  AddLog( sStepLog );
  Result            := True;

end;

function TGitRepoManager.AddRemoteOrigin( const sRepoPath, sRemoteURL: string; out sLog: string ): Boolean;
var
  sOutput           : string;
begin

  Result            := False;
  sLog              := '';

  if ( not ExecuteGitCommand( sRepoPath, Format( 'remote add origin "%s"', [ sRemoteURL ] ), sOutput ) ) then
  begin
    sLog            := Format( 'Failed to add remote origin: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  sLog              := Format( 'Added remote origin: %s', [ sRemoteURL ] );
  Result            := True;

end;

function TGitRepoManager.InitialCommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sTempFile         : string;
  sBranch           : string;
begin

  Result            := False;
  sLog              := '';

  if ( not ExecuteGitCommand( sRepoPath, 'add -A', sOutput, GIT_NETWORK_TIMEOUT ) ) then
  begin
    sLog            := Format( 'Failed to stage files: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  sLog              := 'Staged all files' + sLineBreak;

  // Nothing staged: fine when a commit already exists ( a resumed run, or a
  // repository that was committed by hand ), a dead end when it does not.
  if ExecuteGitCommand( sRepoPath, 'diff --cached --quiet', sOutput ) then
  begin
    if ( not HasAnyCommit( sRepoPath ) ) then
    begin
      sLog          := sLog + 'There is nothing to commit - the folder has no files that are not ignored.';
      Exit;
    end;

    sLog            := sLog + 'Nothing new to commit - pushing the existing commits' + sLineBreak;
  end
  else
  begin
    if ( not CreateCommitMessageFile( sMessage, sTempFile ) ) then
    begin
      sLog          := sLog + 'Failed to create commit message file';
      Exit;
    end;

    try
      if ( not ExecuteGitCommand( sRepoPath, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput,
        GIT_NETWORK_TIMEOUT ) ) then
      begin
        sLog        := sLog + Format( 'Commit failed: %s', [ Trim( sOutput ) ] );
        Exit;
      end;

      sLog          := sLog + 'Created commit' + sLineBreak;
    finally
      DeleteCommitMessageFile( sTempFile );
    end;
  end;

  // Detect the current branch name rather than assuming `main` — respects
  // init.defaultBranch settings and any prior rename.
  sBranch           := GetCurrentBranch( sRepoPath );

  if sBranch.IsEmpty then
    sBranch         := 'main';

  if ( not ExecuteGitCommand( sRepoPath, Format( 'push -u origin -- %s', [ sBranch ] ), sOutput,
    GIT_NETWORK_TIMEOUT ) ) then
  begin
    sLog            := sLog + Format( 'Push failed: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  sLog              := sLog + Format( 'Pushed to origin/%s', [ sBranch ] );
  Result            := True;

end;

function TGitRepoManager.PullRepository( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  rRepo             : TRepoInfo;
begin

  Result            := False;
  sLog              := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sLog            := 'Repository is no longer in the list';
    Exit;
  end;

  // Fast-forward only — refuse to create surprise merge commits when local
  // history has diverged. If it fails, the user should explicitly reconcile.
  if ( not ExecuteGitCommand( rRepo.Path, 'pull --ff-only', sOutput, GIT_NETWORK_TIMEOUT ) ) then
  begin
    sLog            := Format( 'Pull failed: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  sLog              := Trim( sOutput );
  Result            := True;

end;

function TGitRepoManager.ResolveConflictsKeepLocal( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sGitDir           : string;
  rRepo             : TRepoInfo;

  /// <summary>
  ///   Appends one line to the operation log.
  /// </summary>
  procedure AddLog( const sLine: string );
  begin
    sLog            := sLog + sLine + sLineBreak;
  end;

begin

  Result            := False;
  sLog              := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sLog            := 'Repository is no longer in the list';
    Exit;
  end;

  AddLog( Format( '=== %s ===', [ rRepo.Name ] ) );

  // Ask Git where its directory is.  In a linked worktree or a submodule .git
  // is a FILE, and probing <path>\.git\MERGE_HEAD reported a real merge as
  // "nothing to resolve" - counted as a success.
  sGitDir           := ResolveGitDir( sRepoPath );

  if sGitDir.IsEmpty then
  begin
    AddLog( 'Not a Git repository, or Git could not be run' );
    Exit;
  end;

  // "Keep ours" only means anything while a MERGE is in progress.  In a
  // rebase the two sides are swapped, so this command must not guess.
  if ( not TFile.Exists( TPath.Combine( sGitDir, 'MERGE_HEAD' ) ) ) then
  begin
    if HasOperationInProgress( sRepoPath ) then
    begin
      AddLog( 'A rebase, cherry-pick, revert or bisect is in progress, not a merge. ' +
        'Finish or abort it in a Git client; nothing was changed.' );
      Exit;
    end;

    AddLog( 'No merge in progress - nothing to resolve' );
    Result          := True;
    Exit;
  end;

  // The CONFLICTED paths only.  This used to run `checkout --ours .` and then
  // `add .`: the first rewrote every tracked file from the index, destroying
  // uncommitted edits to files that were never in conflict, and the second
  // staged every untracked file in the tree and pushed it.
  if ( not ExecuteGitCommand( sRepoPath, 'diff --name-only --diff-filter=U -z', sOutput, GIT_COMMAND_TIMEOUT, True ) ) then
  begin
    AddLog( Format( 'Could not list the conflicted files: %s', [ Trim( sOutput ) ] ) );
    Exit;
  end;

  var saPaths       := sOutput.Split( [ #0 ], TStringSplitOptions.ExcludeEmpty );

  for var sPath in saPaths do
  begin
    // A path Git would need quoted cannot be passed safely on this command
    // line.  Windows does not allow '"' in a file name, so this is a guard
    // against a repository created elsewhere.
    if sPath.Contains( '"' ) then
    begin
      AddLog( Format( 'Cannot resolve a path containing a quote character: %s', [ sPath ] ) );
      Exit;
    end;

    if ExecuteGitCommand( sRepoPath, Format( 'checkout --ours -- "%s"', [ sPath ] ), sOutput ) then
    begin
      if ( not ExecuteGitCommand( sRepoPath, Format( 'add -- "%s"', [ sPath ] ), sOutput ) ) then
      begin
        AddLog( Format( 'Failed to stage %s: %s', [ sPath, Trim( sOutput ) ] ) );
        Exit;
      end;

      AddLog( Format( 'Kept local version: %s', [ sPath ] ) );
    end
    else if ( not ExecuteGitCommand( sRepoPath, Format( 'ls-files -u -- "%s"', [ sPath ] ), sOutput ) ) or
      sOutput.Contains( ' 2'#9 ) then
    begin
      // Stage 2 is OUR side of the conflict.  It exists, so the checkout
      // failed for some other reason - the file is open in another program,
      // or the index was locked.  Falling through to `git rm` here would
      // delete, commit and push the very file the user asked to keep.
      AddLog( Format( 'Could not restore the local version of %s - it may be open in another program. ' +
        'Nothing was committed; close it and run Resolve Conflicts again.', [ sPath ] ) );
      Exit;
    end
    else if ExecuteGitCommand( sRepoPath, Format( 'rm --quiet -- "%s"', [ sPath ] ), sOutput ) then
      // No local version exists: we deleted the file and the remote changed
      // it.  Keeping ours means it stays deleted.
      AddLog( Format( 'Kept local deletion: %s', [ sPath ] ) )
    else
    begin
      AddLog( Format( 'Failed to resolve %s: %s', [ sPath, Trim( sOutput ) ] ) );
      Exit;
    end;
  end;

  if Length( saPaths ) = 0 then
    AddLog( 'No conflicted files remain - concluding the merge' );

  // Commit the merge resolution - may fail if nothing to commit (which is OK)
  if ( not ExecuteGitCommand( sRepoPath, 'commit -m "Resolved merge conflicts - kept local version"', sOutput,
    GIT_NETWORK_TIMEOUT ) ) then
  begin
    // LC_ALL=C is pinned for the child, so this text is stable.
    if sOutput.Contains( 'nothing to commit' ) then
    begin
      AddLog( 'Already clean - no conflicts to resolve' );
      Result        := True;
      Exit;
    end;

    AddLog( Format( 'Failed to commit: %s', [ Trim( sOutput ) ] ) );
    Exit;
  end;

  AddLog( 'Committed merge resolution' );

  if ( not ExecuteGitCommand( sRepoPath, 'push', sOutput, GIT_NETWORK_TIMEOUT ) ) then
  begin
    AddLog( Format( 'Push failed: %s', [ Trim( sOutput ) ] ) );
    Exit;
  end;

  AddLog( 'Pushed successfully' );
  Result            := True;

end;

function TGitRepoManager.PushRepository( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sCommand          : string;
  sBranch           : string;
  rRepo             : TRepoInfo;
begin

  Result            := False;
  sLog              := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sLog            := 'Repository is no longer in the list';
    Exit;
  end;

  // A branch with no upstream is given one.  A bare `push` fails there with
  // "no upstream branch", and that is exactly the repository the list now
  // shows as "Push Required (not on the remote)".
  sBranch           := GetCurrentBranch( rRepo.Path );
  sCommand          := 'push';

  if ( not sBranch.IsEmpty ) and GetUpstreamSHA( rRepo.Path ).IsEmpty then
    sCommand        := Format( 'push -u %s -- %s', [ GetUpstreamRemoteName( rRepo.Path ), sBranch ] );

  if ( not ExecuteGitCommand( rRepo.Path, sCommand, sOutput, GIT_NETWORK_TIMEOUT ) ) then
  begin
    sLog            := Format( 'Push failed: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  sLog              := Trim( sOutput );

  if sLog.IsEmpty then
    sLog            := 'Pushed successfully';

  Result            := True;

end;

function TGitRepoManager.ForcePushRepository( const sRepoPath: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sBranch           : string;
  rRepo             : TRepoInfo;
begin

  Result            := False;
  sLog              := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sLog            := 'Repository is no longer in the list';
    Exit;
  end;

  sBranch           := GetCurrentBranch( rRepo.Path );

  if sBranch.IsEmpty then
  begin
    sLog            := 'Force push refused - HEAD is detached or the branch is unborn.';
    Exit;
  end;

  // A bare --force-with-lease is NOT sufficient here. The lease compares
  // against the remote-tracking ref, and this application runs `git fetch` on
  // every status refresh - so by the time the user clicks Force Push, the ref
  // has already been advanced to include the very commits the lease is
  // supposed to protect. The lease passes and those commits are destroyed.
  //
  // RemoteSHA is the upstream commit captured when this row's status was last
  // determined, i.e. what the user was actually shown. Naming it explicitly
  // makes Git refuse if the remote has moved since.  With no such commit there
  // is nothing to lease against, so the push is REFUSED: it used to fall back
  // to the bare form described above.
  if rRepo.RemoteSHA.IsEmpty then
  begin
    sLog            := Format( 'Force push refused - branch "%s" has no upstream recorded, so there is nothing ' +
      'to protect the remote with. Use Push Only to publish it, or refresh and try again.', [ sBranch ] );
    Exit;
  end;

  // The last refresh could not reach the remote, so RemoteSHA is the remote as
  // it was at some EARLIER fetch and the row is not showing what is there now.
  // The lease would probably reject the push anyway; refusing here says why,
  // and does not rest the remote's history on "probably".
  if rRepo.FetchFailed then
  begin
    sLog            := Format( 'Force push refused - the last refresh could not fetch from the remote, so the ' +
      'state of branch "%s" there is not known. Refresh, check what is incoming, then try again.', [ sBranch ] );
    Exit;
  end;

  // The same remote the lease was read from, not whatever is called origin.
  if ( not ExecuteGitCommand( rRepo.Path, Format( 'push --force-with-lease=%s:%s %s -- %s',
    [ sBranch, rRepo.RemoteSHA, GetUpstreamRemoteName( rRepo.Path ), sBranch ] ), sOutput, GIT_NETWORK_TIMEOUT ) ) then
  begin
    sLog            := Format( 'Force push failed: %s', [ Trim( sOutput ) ] );

    if sOutput.Contains( 'stale info' ) or sOutput.Contains( 'rejected' ) then
      sLog          := sLog + sLineBreak +
        'The remote has moved since this repository''s status was last refreshed. ' +
        'Refresh and review the incoming commits before force pushing - pushing now ' +
        'would destroy them.';

    Exit;
  end;

  sLog              := Trim( sOutput );

  if sLog.IsEmpty then
    sLog            := 'Force pushed successfully';

  Result            := True;

end;

function TGitRepoManager.CreateBackupBranch( const sRepoPath: string; out sBranchName: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  rRepo             : TRepoInfo;
begin

  Result            := False;
  sBranchName       := '';
  sLog              := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sLog            := 'Repository is no longer in the list';
    Exit;
  end;

  // Create a timestamped backup branch name — millisecond precision so two
  // backups within the same second don't collide ( "branch already exists" ).
  sBranchName       := Format( 'backup-%s',
    [ FormatDateTime( 'yyyy"-"mm"-"dd"-"hhnnss"-"zzz', Now, TFormatSettings.Invariant ) ] );

  if ( not ExecuteGitCommand( rRepo.Path, Format( 'branch %s', [ sBranchName ] ), sOutput ) ) then
  begin
    sLog            := Format( 'Failed to create backup branch: %s', [ Trim( sOutput ) ] );
    sBranchName     := '';
    Exit;
  end;

  sLog              := Format( 'Created backup branch: %s', [ sBranchName ] );
  Result            := True;

end;

function TGitRepoManager.GetIncomingChanges( const sRepoPath: string; out sChanges: string; out sLog: string ): Boolean;
var
  sOutput           : string;
  sBranch           : string;
  rRepo             : TRepoInfo;
begin

  Result            := False;
  sChanges          := '';
  sLog              := '';

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sLog            := 'Repository is no longer in the list';
    Exit;
  end;

  // Resolve the branch afresh. The cached Branch field carries the DISPLAY
  // string '(unknown)' when detection failed.
  sBranch           := GetCurrentBranch( sRepoPath );

  if sBranch.IsEmpty then
  begin
    sLog            := 'Could not determine the current branch (detached HEAD or no commits) - preview unavailable';
    Exit;
  end;

  if ( not ExecuteGitCommand( sRepoPath, 'fetch', sOutput, GIT_NETWORK_TIMEOUT ) ) then
  begin
    sLog            := Format( 'Fetch failed: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  // No upstream is its own answer, and must be told apart from a diff that
  // FAILED: both used to be reported as "no upstream configured", with True.
  if GetUpstreamSHA( sRepoPath ).IsEmpty then
  begin
    sLog            := Format( 'Branch "%s" has no upstream configured - nothing to preview', [ sBranch ] );
    Result          := True;
    Exit;
  end;

  // Compare against the branch's CONFIGURED upstream, not a hard-coded
  // origin/<same name>.
  if ( not ExecuteGitCommand( sRepoPath, 'diff --stat HEAD...@{upstream}', sOutput, GIT_COMMAND_TIMEOUT, True ) ) then
  begin
    sLog            := Format( 'Could not compare with the upstream: %s', [ Trim( sOutput ) ] );
    Exit;
  end;

  sChanges          := Trim( sOutput );
  sLog              := 'Fetched successfully';
  Result            := True;

end;

function TGitRepoManager.MigrateRepository( const sRepoPath, sNewRepoName, sDescription: string;
  const bPrivate: Boolean; out sNewRemoteURL, sError, sLog: string ): Boolean;
const
  OLD_REMOTE_NAME   = 'old-origin';
var
  sCurrentOrigin    : string;
  sOutput           : string;
  sOldRemoteName    : string;
  saUpstreams       : TArray<string>;
  saRecovered       : TArray<string>;
  bRenamed          : Boolean;
  bOriginAdded      : Boolean;
  rRepo             : TRepoInfo;

  /// <summary>
  ///   Appends one line to the migration log.
  /// </summary>
  procedure AddLog( const sLine: string );
  begin
    sLog            := sLog + sLine + sLineBreak;
  end;

  /// <summary>
  ///   Records a failure in both the error text and the log.
  /// </summary>
  procedure Fail( const sReason: string );
  begin
    sError          := sReason;
    AddLog( sReason );
  end;

  /// <summary>
  ///   Puts the remotes, the branch upstreams and the branch list back as they
  ///   were, and says truthfully whether that worked.
  /// </summary>
  procedure RollBack;
  begin

    var bRestored   := True;

    if bOriginAdded and ( not ExecuteGitCommand( sRepoPath, 'remote remove origin', sOutput ) ) then
    begin
      bRestored     := False;
      AddLog( Format( 'Roll-back: could not remove the new origin: %s', [ Trim( sOutput ) ] ) );
    end;

    if bRenamed and ( not ExecuteGitCommand( sRepoPath, Format( 'remote rename %s origin', [ sOldRemoteName ] ),
      sOutput ) ) then
    begin
      bRestored     := False;
      AddLog( Format( 'Roll-back: could not rename "%s" back to origin: %s', [ sOldRemoteName, Trim( sOutput ) ] ) );
    end;

    // Branches created here only so that `push --all` would carry them.
    for var sBranch in saRecovered do
    begin
      if ( not ExecuteGitCommand( sRepoPath, Format( 'branch -D -- %s', [ sBranch ] ), sOutput ) ) then
        AddLog( Format( 'Roll-back: could not remove the recovered branch %s', [ sBranch ] ) );
    end;

    // A `push -u` that got part of the way re-pointed those branches at the
    // new origin, and removing that origin then left them with no upstream at
    // all.  Each line is '<branch> <upstream>' as recorded before the swap.
    if bRestored then
    begin
      for var sLine in saUpstreams do
      begin
        var saPair  := sLine.Split( [ ' ' ], TStringSplitOptions.ExcludeEmpty );

        if ( Length( saPair ) = 2 ) and ( not ExecuteGitCommand( sRepoPath,
          Format( 'branch --set-upstream-to=%s -- %s', [ saPair[ 1 ], saPair[ 0 ] ] ), sOutput ) ) then
          AddLog( Format( 'Roll-back: could not restore the upstream of %s', [ saPair[ 0 ] ] ) );
      end;
    end;

    if bRestored then
      AddLog( 'Rolled back: the original remotes have been restored.' )
    else
      AddLog( 'ROLL-BACK INCOMPLETE: check the remotes of this repository by hand ( git remote -v ).' );

    AddLog( Format( 'The repository "%s" created on GitHub was NOT deleted - remove it manually if it is not wanted.',
      [ sNewRepoName ] ) );

  end;

begin

  Result            := False;
  sNewRemoteURL     := '';
  sError            := '';
  sLog              := '';
  bRenamed          := False;
  bOriginAdded      := False;

  if ( not GetRepoSnapshotByPath( sRepoPath, rRepo ) ) then
  begin
    sError          := 'Repository is no longer in the list';
    Exit;
  end;

  // Preconditions: repo must have at least one commit, and working tree must
  // be clean — we're about to push --all, and a partial/dirty repo leaves us
  // with a newly-created target remote and a half-migrated local state.
  if ( not HasAnyCommit( sRepoPath ) ) then
  begin
    sError          := 'Repository has no commits yet - create at least one commit before migrating';
    Exit;
  end;

  if ( not IsWorkingTreeClean( sRepoPath ) ) then
  begin
    sError          := 'Working tree has uncommitted changes - commit or stash before migrating';
    Exit;
  end;

  sCurrentOrigin    := GetRemoteOriginURL( sRepoPath );

  if DetectRemoteProvider( sCurrentOrigin ) = rpGitHub then
  begin
    sError          := 'Repository is already hosted on GitHub';
    Exit;
  end;

  if ( not HasGitHubCredentials ) then
  begin
    sError          := 'GitHub credentials not configured';
    Exit;
  end;

  // Record every local branch's upstream, for the roll-back.
  if ExecuteGitCommand( sRepoPath, 'for-each-ref --format="%(refname:short) %(upstream:short)" refs/heads',
    sOutput, GIT_QUICK_TIMEOUT, True ) then
    saUpstreams     := sOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );

  AddLog( Format( 'Creating GitHub repository "%s"...', [ sNewRepoName ] ) );

  if ( not CreateGitHubRepository( sNewRepoName, sDescription, bPrivate, sNewRemoteURL, sError ) ) then
  begin
    AddLog( Format( 'Failed: %s', [ sError ] ) );
    Exit;
  end;

  AddLog( Format( 'Created target repository: %s', [ sNewRemoteURL ] ) );

  // Everything from here to the end is reversible: if any step fails, the
  // remotes are put back as they were. Without that, a failure between the
  // rename and the push left the repository with origin pointing at an empty
  // new remote while the real one hid under an alias - and every subsequent
  // Commit & Push then pushed to the wrong place.
  try
    if ( not sCurrentOrigin.IsEmpty ) then
    begin
      sOldRemoteName := OLD_REMOTE_NAME;

      // Never silently destroy an existing remote of that name. Pick an unused
      // suffix instead.
      var iSuffix   := 2;

      while RemoteExists( sRepoPath, sOldRemoteName ) and ( iSuffix < 100 ) do
      begin
        sOldRemoteName := Format( '%s-%d', [ OLD_REMOTE_NAME, iSuffix ] );
        Inc( iSuffix );
      end;

      if ( not ExecuteGitCommand( sRepoPath, Format( 'remote rename origin %s', [ sOldRemoteName ] ), sOutput ) ) then
      begin
        Fail( Format( 'Failed to rename existing origin: %s', [ Trim( sOutput ) ] ) );
        Exit;
      end;

      bRenamed      := True;
      AddLog( Format( 'Preserved previous origin as "%s": %s', [ sOldRemoteName, RedactSecrets( sCurrentOrigin ) ] ) );
    end;

    if ( not ExecuteGitCommand( sRepoPath, Format( 'remote add origin "%s"', [ sNewRemoteURL ] ), sOutput ) ) then
    begin
      Fail( Format( 'Failed to add new origin: %s', [ Trim( sOutput ) ] ) );
      Exit;
    end;

    bOriginAdded    := True;
    AddLog( Format( 'Added new origin: %s', [ sNewRemoteURL ] ) );

    // Create local branches for anything that only ever existed on the old
    // remote. `push --all` pushes LOCAL branches only, so without this a
    // branch nobody had checked out was quietly left behind and the migration
    // still reported success.
    if bRenamed then
    begin
      // The fetch has to WORK.  Ignoring its result meant an unreachable old
      // remote left its remote-only branches behind while success was reported.
      if ( not ExecuteGitCommand( sRepoPath, Format( 'fetch %s --prune', [ sOldRemoteName ] ), sOutput,
        GIT_NETWORK_TIMEOUT ) ) then
      begin
        Fail( Format( 'Could not fetch from the previous remote, so its branches cannot all be carried over: %s',
          [ Trim( sOutput ) ] ) );
        Exit;
      end;

      if ExecuteGitCommand( sRepoPath, Format( 'for-each-ref --format=%%(refname:strip=3) refs/remotes/%s',
        [ sOldRemoteName ] ), sOutput, GIT_QUICK_TIMEOUT, True ) then
      begin
        for var sRemoteBranch in Trim( sOutput ).Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty ) do
        begin
          var sTrimmedBranch := Trim( sRemoteBranch );

          if sTrimmedBranch.IsEmpty or SameText( sTrimmedBranch, 'HEAD' ) then
            Continue;

          // Fails harmlessly when the branch already exists locally.
          if ExecuteGitCommand( sRepoPath, Format( 'branch -- %s %s/%s',
            [ sTrimmedBranch, sOldRemoteName, sTrimmedBranch ] ), sOutput ) then
          begin
            saRecovered := saRecovered + [ sTrimmedBranch ];
            AddLog( Format( 'Recovered remote-only branch: %s', [ sTrimmedBranch ] ) );
          end;
        end;
      end;
    end;

    // Push all branches (sets upstream tracking to the new origin)
    if ( not ExecuteGitCommand( sRepoPath, 'push -u origin --all', sOutput, GIT_NETWORK_TIMEOUT ) ) then
    begin
      Fail( Format( 'Failed to push branches: %s', [ Trim( sOutput ) ] ) );
      Exit;
    end;

    AddLog( 'Pushed all branches to new origin' );

    // Push all tags — not fatal if it fails
    if ExecuteGitCommand( sRepoPath, 'push origin --tags', sOutput, GIT_NETWORK_TIMEOUT ) then
      AddLog( 'Pushed all tags to new origin' )
    else
      AddLog( Format( 'Warning: tag push reported: %s', [ Trim( sOutput ) ] ) );

    Result          := True;
  finally
    if ( not Result ) then
      RollBack;
  end;

  // The row's provider, upstream and counts all changed.
  RefreshStatus( sRepoPath, False );

end;

procedure TGitRepoManager.AddToCommitHistory( const sMessage: string );
var
  sTrimmed          : string;
  iNewLen           : Integer;
  bChanged          : Boolean;
begin

  sTrimmed          := Trim( sMessage );

  if sTrimmed.IsEmpty then
    Exit;

  // This runs on the COMMIT WORKER thread, via CommitAndPush, while the UI
  // thread reads the same array to build the history menu. Re-sizing a managed
  // array under an unsynchronised reader frees the block it is walking.
  FListsLock.Enter;

  try
    // Already at the top of the history - nothing to record.
    bChanged        := ( Length( FCommitHistory ) = 0 ) or ( not SameText( FCommitHistory[ 0 ], sTrimmed ) );

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
    iNewLen         := Length( FCommitHistory ) + 1;

    if iNewLen > MAX_HISTORY_ITEMS then
      iNewLen       := MAX_HISTORY_ITEMS;

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

  sTrimmed          := Trim( sTemplate );

  if sTrimmed.IsEmpty then
    Exit;

  FListsLock.Enter;

  try
    iLen            := Length( FCommitTemplates );
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

  Groups            := TList<string>.Create;

  try
    FReposLock.Enter;

    try
      for var i := 0 to High( FRepos ) do
      begin
        sGroup      := Trim( FRepos[ i ].Group );

        if ( not sGroup.IsEmpty ) and ( not Groups.Contains( sGroup ) ) then
          Groups.Add( sGroup );
      end;
    finally
      FReposLock.Leave;
    end;

    Groups.Sort;
    Result          := Groups.ToArray;
  finally
    Groups.Free;
  end;

end;

procedure TGitRepoManager.SetRepoGroup( const sRepoPath: string; const sGroup: string );
begin

  FReposLock.Enter;

  try
    var iIndex      := IndexOfPathLocked( sRepoPath );

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
const
  /// <summary>
  ///   Most repositories refreshed at once.  Each one blocks on a chain of
  ///   Git child processes and one network fetch, so this is a limit on
  ///   concurrent processes and connections, not on processor use.
  /// </summary>
  MAX_PARALLEL_REFRESHES = 8;
var
  rRepos            : TRepoInfoArray;
begin

  // A locked copy, so the loop works against a stable array even if the live
  // one is changed by add/remove calls meanwhile.
  rRepos            := SnapshotAll;

  if Length( rRepos ) = 0 then
    Exit;

  Parallel.For( 0, High( rRepos ) ).NumTasks( Min( Length( rRepos ), MAX_PARALLEL_REFRESHES ) ).Execute(
    procedure( iIndex: Integer )
    begin

      if Assigned( AIsCancelled ) and AIsCancelled then
        Exit;

      // RefreshStatus takes the path, runs Git outside the lock and publishes
      // by path match, so it is safe to call from several threads and is
      // unaffected by the array shifting under it.
      RefreshStatus( rRepos[ iIndex ].Path );

      if Assigned( AIsCancelled ) and AIsCancelled then
        Exit;

      if Assigned( AOnRepoDone ) then
        AOnRepoDone( rRepos[ iIndex ].Name );

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

