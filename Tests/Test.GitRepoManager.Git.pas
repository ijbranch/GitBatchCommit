(* GITLAK Software
  ***************************************************************************

    © 2026 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit test suite.

  Test.GitRepoManager.Git.pas - everything that needs a real repository:
  status detection, the build-artefact filter, the project version, commit,
  push, force push, pull, backup branch, incoming preview and conflict
  resolution.  Every repository, and every "origin", lives in the test's own
  temporary folder; nothing contacts the network.

  ***************************************************************************
*)

unit Test.GitRepoManager.Git;

interface

uses
  DUnitX.TestFramework,
  uGitRepoManager,
  Test.Support;

{$M+}

type
  /// <summary>
  ///   What the Git fixtures share: the sandbox, a loaded manager and the
  ///   arrangements most tests start from.  Not a fixture itself.
  /// </summary>
  TGitFixtureBase = class
  protected
    /// <summary>
    ///   The temporary folder of the running test.
    /// </summary>
    FSandbox: TGitSandbox;
    /// <summary>
    ///   The manager under test, on the sandbox's configuration file.
    /// </summary>
    FManager: TGitRepoManager;

    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    procedure StartSandbox;

    /// <summary>
    ///   Frees the manager and deletes the sandbox.
    /// </summary>
    procedure EndSandbox;

    /// <summary>
    ///   Adds a repository to the manager, which determines its local state
    ///   without fetching, and returns the record.
    /// </summary>
    /// <param name="sRepo">Working-tree path.</param>
    /// <returns>A copy of the repository's record.</returns>
    /// <exception cref="EGitSandbox">The arrangement failed, so the test cannot mean anything.</exception>
    function Track( const sRepo: string ): TRepoInfo;

    /// <summary>
    ///   Refreshes a tracked repository's status and returns the record.
    /// </summary>
    /// <param name="sRepo">Working-tree path.</param>
    /// <param name="bFetch">True to let the refresh fetch from the ( local ) remote first.</param>
    /// <returns>A copy of the repository's record.</returns>
    function Refresh( const sRepo: string; const bFetch: Boolean = False ): TRepoInfo;

    /// <summary>
    ///   Returns a tracked repository's record as it stands, without
    ///   refreshing.
    /// </summary>
    /// <param name="sRepo">Working-tree path.</param>
    /// <returns>A copy of the repository's record.</returns>
    /// <exception cref="EGitSandbox">The arrangement failed, so the test cannot mean anything.</exception>
    function Snapshot( const sRepo: string ): TRepoInfo;

    /// <summary>
    ///   Builds a bare "origin" holding one commit, and two clones of it.
    /// </summary>
    /// <param name="sBare">Receives the bare repository's path.</param>
    /// <param name="sLocal">Receives the clone the test acts on.</param>
    /// <param name="sOther">Receives a second clone, standing in for somebody else.</param>
    procedure MakeOriginAndClones( out sBare, sLocal, sOther: string );

    /// <summary>
    ///   Commits one file in a clone and pushes it to its origin.
    /// </summary>
    /// <param name="sClone">The clone to commit in.</param>
    /// <param name="sName">File name.</param>
    /// <param name="sText">The file's content.</param>
    procedure CommitAndPushFrom( const sClone, sName, sText: string );

    /// <summary>
    ///   Asserts a record's status and its display text together.
    /// </summary>
    /// <param name="rRepo">The record.</param>
    /// <param name="eStatus">Expected status.</param>
    /// <param name="sStatusText">Expected display text, exactly.</param>
    procedure AssertStatus( const rRepo: TRepoInfo; const eStatus: TRepoStatus; const sStatusText: string );
  end;

  /// <summary>
  ///   <c>RefreshStatus</c>: what each repository state is reported as.
  /// </summary>
  [TestFixture]
  TTestRefreshStatus = class( TGitFixtureBase )
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves a committed repository with no remote is Clean, with its
    ///   branch, tracked-file count and "no remote" fields filled in.
    /// </summary>
    [Test]
    procedure CleanRepositoryWithoutRemote;

    /// <summary>
    ///   Proves a brand-new untracked file alone makes the repository
    ///   Modified.
    /// </summary>
    [Test]
    procedure UntrackedFileIsModified;

    /// <summary>
    ///   Proves an edited tracked file is Modified, and that the count is the
    ///   number of porcelain entries.
    /// </summary>
    [Test]
    procedure EditedFileIsModifiedAndCounted;

    /// <summary>
    ///   Proves a folder that is not a repository is an Error, not Clean.
    /// </summary>
    [Test]
    procedure FolderThatIsNoRepositoryIsError;

    /// <summary>
    ///   Proves a fresh clone is Clean with HasUpstream set, a provider other
    ///   than GitHub, and RemoteSHA holding the origin's commit.
    /// </summary>
    [Test]
    procedure CloneIsCleanWithUpstream;

    /// <summary>
    ///   Proves a commit not yet pushed is Push Required with the count.
    /// </summary>
    [Test]
    procedure AheadIsPushRequired;

    /// <summary>
    ///   Proves a commit on the remote, once fetched, is Pull Required with
    ///   the count.
    /// </summary>
    [Test]
    procedure BehindAfterFetchIsPullRequired;

    /// <summary>
    ///   Proves <c>bFetch</c> True fetches for itself, and False does not: the
    ///   same repository reads Clean until the refresh is allowed to fetch.
    /// </summary>
    [Test]
    procedure RefreshFetchesOnlyWhenAsked;

    /// <summary>
    ///   Proves commits on both sides are Diverged with both counts.
    /// </summary>
    [Test]
    procedure AheadAndBehindIsDiverged;

    /// <summary>
    ///   Proves a repository both modified and behind says both: Modified in
    ///   the status, the pull it owes in the text and in BehindCount.
    /// </summary>
    [Test]
    procedure ModifiedAndBehindSaysBoth;

    /// <summary>
    ///   Proves a branch with commits and a remote, but nothing on that remote,
    ///   is Push Required "not on the remote" rather than Clean.
    /// </summary>
    [Test]
    procedure NeverPushedIsPushRequired;

    /// <summary>
    ///   Proves a branch pushed without an upstream is compared with origin's
    ///   branch of the same name: Clean when level, Push Required when ahead,
    ///   HasUpstream False throughout.
    /// </summary>
    [Test]
    procedure NoUpstreamComparesWithOriginBranch;

    /// <summary>
    ///   Proves a fetch that fails is flagged in FetchFailed and in the text,
    ///   and that a later refresh which does not fetch leaves the flag set: a
    ///   local-only refresh says nothing about the remote.
    /// </summary>
    [Test]
    procedure FailedFetchIsFlagged;

    /// <summary>
    ///   Proves a linked worktree, where <c>.git</c> is a file, is read like
    ///   any repository instead of being stuck in Error.
    /// </summary>
    [Test]
    procedure LinkedWorktreeIsNotAnError;

    /// <summary>
    ///   Proves <c>GetRepoProvider</c> reports no provider without a remote
    ///   and a non-GitHub one for a local remote.
    /// </summary>
    [Test]
    procedure ProviderFollowsTheRemote;
  end;

  /// <summary>
  ///   The build-artefact filter, through the status it produces.
  /// </summary>
  [TestFixture]
  TTestArtefactFilter = class( TGitFixtureBase )
  private
    /// <summary>
    ///   Makes a repository, commits the given files, then rewrites each so it
    ///   shows as modified, and adds untracked ones.
    /// </summary>
    /// <param name="saModified">Tracked files to commit and then modify.</param>
    /// <param name="saUntracked">Files to create without adding.</param>
    /// <returns>The repository's record after it is tracked.</returns>
    function StatusWith( const saModified, saUntracked: TArray<string> ): TRepoInfo;
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves a change that is only a compiled unit scores Clean, is flagged
    ///   ArtifactOnlyChanges and says "build output only" so the skip is
    ///   visible.
    /// </summary>
    [Test]
    procedure CompiledUnitAloneIsBuildOutputOnly;

    /// <summary>
    ///   Proves a file under a platform folder with a configuration folder
    ///   directly beneath it ( Win64/Debug ) is build output.
    /// </summary>
    [Test]
    procedure PlatformConfigurationFolderIsBuildOutput;

    /// <summary>
    ///   Proves the IDE's __history folder is build output.
    /// </summary>
    [Test]
    procedure HistoryFolderIsBuildOutput;

    /// <summary>
    ///   Proves an untracked platform folder holding nothing but compiled
    ///   units is build output.  Git's default status reports a wholly
    ///   untracked folder as one collapsed entry ( "?? Win64/" ), which the
    ///   filter cannot recognise, so the status must list it file by file.
    /// </summary>
    [Test]
    procedure UntrackedPlatformFolderIsBuildOutput;

    /// <summary>
    ///   Proves a bare "release" folder is ordinary content: a change under
    ///   docs/release is Modified.
    /// </summary>
    [Test]
    procedure ReleaseFolderAloneIsARealChange;

    /// <summary>
    ///   Proves a bare platform folder is ordinary content: a change to
    ///   Source/Win64/Thunks.pas is Modified.
    /// </summary>
    [Test]
    procedure PlatformFolderAloneIsARealChange;

    /// <summary>
    ///   Proves an executable is NOT build output, as documented: tracked
    ///   tooling must not vanish from the batch.
    /// </summary>
    [Test]
    procedure ExecutableIsARealChange;

    /// <summary>
    ///   Proves one real change among build output makes the repository
    ///   Modified.
    /// </summary>
    [Test]
    procedure RealChangeAmongBuildOutputIsModified;

    /// <summary>
    ///   Proves build-output-only changes do not hide an unpushed commit: the
    ///   status is Push Required, with both qualifiers in the text.
    /// </summary>
    [Test]
    procedure BuildOutputOnlyStillReportsUnpushedCommits;
  end;

  /// <summary>
  ///   <c>GetProjectVersion</c>: which FileVersion a repository is said to
  ///   build.
  /// </summary>
  [TestFixture]
  TTestProjectVersion = class( TGitFixtureBase )
  private
    /// <summary>
    ///   Returns a minimal project file whose default configuration is
    ///   Release on Win64, mapped to Cfg_1, carrying the given property groups.
    /// </summary>
    /// <param name="sGroups">The version-carrying property groups, in file order.</param>
    /// <returns>The .dproj text.</returns>
    function ProjectText( const sGroups: string ): string;

    /// <summary>
    ///   Returns one property group that sets FileVersion.
    /// </summary>
    /// <param name="sCondition">The group's condition symbol, e.g. <c>Base_Win64</c>.</param>
    /// <param name="sVersion">The FileVersion to set.</param>
    /// <returns>The property group's text.</returns>
    function VersionGroup( const sCondition, sVersion: string ): string;
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves the ACTIVE configuration's version is returned, not the
    ///   highest in the file: the documented 2.0.0.0 on Base_Win64 against
    ///   1.0.0.347 on Cfg_1_Win64 case.
    /// </summary>
    [Test]
    procedure ActiveConfigurationWinsOverHighest;

    /// <summary>
    ///   Proves the layering goes by rank, not by position in the file: the
    ///   same groups in the opposite order give the same answer.
    /// </summary>
    [Test]
    procedure LayeringIsByRankNotFileOrder;

    /// <summary>
    ///   Proves a project that names no default configuration falls back to
    ///   the highest FileVersion, compared number by number ( 1.10 beats 1.9 ).
    /// </summary>
    [Test]
    procedure UnresolvableProjectFallsBackToHighest;

    /// <summary>
    ///   Proves a project in the repository root decides the version, and a
    ///   vendored one in a sub-folder with a larger number does not.
    /// </summary>
    [Test]
    procedure RootProjectBeatsVendoredProject;

    /// <summary>
    ///   Proves a FileVersion that is not a plain dotted number is refused,
    ///   since it would reach a Git command line.
    /// </summary>
    [Test]
    procedure VersionThatIsNotDottedDigitsIsRefused;

    /// <summary>
    ///   Proves a folder with no project has no version.
    /// </summary>
    [Test]
    procedure NoProjectMeansNoVersion;

    /// <summary>
    ///   Proves <c>bForceRescan</c> re-reads the project: inside the scan
    ///   window an edited version is not seen without it and is seen with it.
    /// </summary>
    [Test]
    procedure ForceRescanSeesAVersionJustChanged;
  end;

  /// <summary>
  ///   Commit &amp; Push against a local bare origin.
  /// </summary>
  [TestFixture]
  TTestCommitAndPush = class( TGitFixtureBase )
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves the commit lands on the origin with the message exactly as
    ///   given ( quotes and shell characters included ), the status returns to
    ///   Clean and the message joins the history.
    /// </summary>
    [Test]
    procedure CommitLandsOnTheOrigin;

    /// <summary>
    ///   Proves a repository that is no longer in the list is refused by every
    ///   operation, with the reason, rather than acted on.
    /// </summary>
    [Test]
    procedure OperationsRefuseARepositoryNotInTheList;

    /// <summary>
    ///   Proves a branch behind its upstream is refused BEFORE anything is
    ///   committed, leaving the work uncommitted for a pull.
    /// </summary>
    [Test]
    procedure BehindIsRefusedBeforeCommitting;

    /// <summary>
    ///   Proves a detached HEAD is refused before anything is committed.
    /// </summary>
    [Test]
    procedure DetachedHeadIsRefused;

    /// <summary>
    ///   Proves a branch with no upstream is pushed with one set, instead of
    ///   the commit being stranded by a bare push.
    /// </summary>
    [Test]
    procedure NoUpstreamIsPushedAndSet;

    /// <summary>
    ///   Proves "nothing staged" is not a failure: work already committed but
    ///   not pushed is pushed.
    /// </summary>
    [Test]
    procedure NothingToCommitStillPushes;

    /// <summary>
    ///   Proves a failed push returns False, says the commit was made locally
    ///   and not pushed, and leaves the row no longer saying Modified.
    /// </summary>
    [Test]
    procedure FailedPushKeepsTheCommitAndSaysSo;

    /// <summary>
    ///   Proves a file pattern restricts what is staged: the matching file is
    ///   committed and the other stays modified.
    /// </summary>
    [Test]
    procedure FilePatternLimitsWhatIsStaged;

    /// <summary>
    ///   Proves a pattern starting with '-' is staged as a PATH, never read by
    ///   Git as an option.
    /// </summary>
    [Test]
    procedure PatternStartingWithDashIsAPath;

    /// <summary>
    ///   Proves the project's version becomes an annotated tag that is pushed
    ///   to the origin with the commit.
    /// </summary>
    [Test]
    procedure ProjectVersionIsTaggedAndPushed;
  end;

  /// <summary>
  ///   Push, force push, pull, backup branch and the incoming-changes preview.
  /// </summary>
  [TestFixture]
  TTestRemoteOperations = class( TGitFixtureBase )
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves Push Only sends an unpushed commit to the origin.
    /// </summary>
    [Test]
    procedure PushSendsUnpushedCommits;

    /// <summary>
    ///   Proves Push Only gives a branch with no upstream one, so the
    ///   repository shown as "not on the remote" can be published.
    /// </summary>
    [Test]
    procedure PushSetsUpstreamWhenThereIsNone;

    /// <summary>
    ///   Proves a force push is refused when no upstream commit was recorded,
    ///   and that nothing reaches the remote.
    /// </summary>
    [Test]
    procedure ForcePushRefusesWithoutARecordedRemoteCommit;

    /// <summary>
    ///   Proves a force push overwrites the origin when it still stands where
    ///   the user was shown.
    /// </summary>
    [Test]
    procedure ForcePushOverwritesWhenTheRemoteHasNotMoved;

    /// <summary>
    ///   Proves the explicit lease: when the remote moved after the status was
    ///   shown, the force push is refused and the new remote commit survives,
    ///   even though a fetch has since advanced the remote-tracking ref.
    /// </summary>
    [Test]
    procedure ForcePushRefusesWhenTheRemoteMoved;

    /// <summary>
    ///   Proves a force push is refused, and nothing is pushed, while the last
    ///   fetching refresh failed: the recorded remote commit may be stale, so
    ///   the lease would protect nothing.  A refresh that does not fetch does
    ///   not lift the refusal; a fetching refresh that succeeds does, and the
    ///   force push then goes through.
    /// </summary>
    [Test]
    procedure ForcePushIsRefusedWhileTheLastFetchFailed;

    /// <summary>
    ///   Proves a pull fast-forwards to the origin's commit.
    /// </summary>
    [Test]
    procedure PullFastForwards;

    /// <summary>
    ///   Proves a pull of diverged history fails instead of creating a merge
    ///   commit, leaving the local branch where it was.
    /// </summary>
    [Test]
    procedure PullRefusesToMergeDivergedHistory;

    /// <summary>
    ///   Proves the backup branch is created at HEAD and its name returned,
    ///   and that two in a row do not collide.
    /// </summary>
    [Test]
    procedure BackupBranchIsCreatedAtHead;

    /// <summary>
    ///   Proves the preview lists an incoming file and merges nothing.
    /// </summary>
    [Test]
    procedure IncomingChangesListsIncomingFiles;

    /// <summary>
    ///   Proves the preview succeeds with an empty list when nothing is
    ///   incoming.
    /// </summary>
    [Test]
    procedure IncomingChangesIsEmptyWhenUpToDate;

    /// <summary>
    ///   Proves a branch with no upstream previews as True with nothing
    ///   incoming and a log line saying why.
    /// </summary>
    [Test]
    procedure IncomingChangesWithoutUpstreamSaysSo;
  end;

  /// <summary>
  ///   <c>ResolveConflictsKeepLocal</c> on real merge conflicts.
  /// </summary>
  [TestFixture]
  TTestResolveConflicts = class( TGitFixtureBase )
  private
    /// <summary>
    ///   Builds a clone whose <c>shared.txt</c> was changed both locally and
    ///   on the origin, with a second, non-conflicting file incoming.
    /// </summary>
    /// <param name="sBare">Receives the origin's path.</param>
    /// <param name="sLocal">Receives the clone's path; nothing is fetched or merged yet.</param>
    procedure ArrangeBothSidesChanged( out sBare, sLocal: string );

    /// <summary>
    ///   Returns True when a file exists in the repository's Git directory.
    /// </summary>
    /// <param name="sRepo">The repository.</param>
    /// <param name="sName">Name inside <c>.git</c>, e.g. <c>MERGE_HEAD</c>.</param>
    /// <returns>True if it exists as a file or a folder.</returns>
    function GitDirHas( const sRepo, sName: string ): Boolean;
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves an unfinished merge with an unmerged path is reported
    ///   Conflicted, and that Commit &amp; Push refuses it without committing.
    /// </summary>
    [Test]
    procedure ConflictIsReportedAndCommitRefused;

    /// <summary>
    ///   Proves the conflicted file ends with the LOCAL content, the incoming
    ///   non-conflicted file is kept, and the merge is committed with both
    ///   parents and pushed.
    /// </summary>
    [Test]
    procedure KeepsLocalContentAndTheIncomingFile;

    /// <summary>
    ///   Proves only the conflicted path is touched: an uncommitted edit to
    ///   another tracked file and an untracked file are left exactly as they
    ///   were, uncommitted.
    /// </summary>
    [Test]
    procedure LeavesUncommittedAndUntrackedFilesAlone;

    /// <summary>
    ///   Proves a file deleted locally and changed remotely stays deleted.
    /// </summary>
    [Test]
    procedure KeepsALocalDeletion;

    /// <summary>
    ///   Proves that with no merge in progress it reports success, says there
    ///   is nothing to resolve and changes nothing.
    /// </summary>
    [Test]
    procedure NoMergeInProgressIsSkipped;

    /// <summary>
    ///   Proves it refuses during a rebase, where "ours" is not the local
    ///   work, and leaves the conflict exactly as it was.
    /// </summary>
    [Test]
    procedure RebaseInProgressIsRefused;
  end;

  /// <summary>
  ///   The local steps of publishing a new repository: initialise, connect
  ///   the origin, first commit and push.  The GitHub step is not run.
  /// </summary>
  [TestFixture]
  TTestNewRepository = class( TGitFixtureBase )
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves a plain folder is turned into a repository on branch
    ///   <c>main</c>.
    /// </summary>
    [Test]
    procedure InitialiseCreatesARepositoryOnMain;

    /// <summary>
    ///   Proves a missing folder and a folder that is already a repository
    ///   are both refused, each with its own reason.
    /// </summary>
    [Test]
    procedure InitialiseRefusesMissingFolderAndExistingRepository;

    /// <summary>
    ///   Proves the origin is added with the URL given, and that a second
    ///   origin is refused with Git's reason.
    /// </summary>
    [Test]
    procedure AddRemoteOriginAddsTheRemote;

    /// <summary>
    ///   Proves the first commit takes every file, carries the message, lands
    ///   on the origin and leaves the branch tracking it.
    /// </summary>
    [Test]
    procedure InitialCommitAndPushPublishesTheFolder;

    /// <summary>
    ///   Proves an empty folder is refused with "nothing to commit" instead of
    ///   failing at the push.
    /// </summary>
    [Test]
    procedure InitialCommitOfAnEmptyFolderIsRefused;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.RegularExpressions;

const
  /// <summary>
  ///   Shape of a full commit hash.
  /// </summary>
  SHA_PATTERN = '^[0-9a-f]{40}$';

{ TGitFixtureBase }

procedure TGitFixtureBase.StartSandbox;
begin

  FSandbox := TGitSandbox.Create;
  FManager := FSandbox.NewManager;

end;

procedure TGitFixtureBase.EndSandbox;
begin

  FreeAndNil( FManager );
  FreeAndNil( FSandbox );

end;

function TGitFixtureBase.Snapshot( const sRepo: string ): TRepoInfo;
begin

  if ( not FManager.GetRepoSnapshotByPath( sRepo, Result ) ) then
    raise EGitSandbox.CreateFmt( 'Arrangement failed: "%s" is not in the manager''s list', [ sRepo ] );

end;

function TGitFixtureBase.Track( const sRepo: string ): TRepoInfo;
begin

  if ( not FManager.AddRepository( sRepo ) ) then
    raise EGitSandbox.CreateFmt( 'Arrangement failed: "%s" could not be added', [ sRepo ] );

  Result := Snapshot( sRepo );

end;

function TGitFixtureBase.Refresh( const sRepo: string; const bFetch: Boolean ): TRepoInfo;
begin

  FManager.RefreshStatus( sRepo, bFetch );
  Result := Snapshot( sRepo );

end;

procedure TGitFixtureBase.MakeOriginAndClones( out sBare, sLocal, sOther: string );
begin

  sBare  := FSandbox.InitSeededBare( 'origin.git' );
  sLocal := FSandbox.CloneRepo( sBare, 'local' );
  sOther := FSandbox.CloneRepo( sBare, 'other' );

end;

procedure TGitFixtureBase.CommitAndPushFrom( const sClone, sName, sText: string );
begin

  FSandbox.CommitFile( sClone, sName, sText, 'Change ' + sName );
  FSandbox.Git( sClone, 'push origin main' );

end;

procedure TGitFixtureBase.AssertStatus( const rRepo: TRepoInfo; const eStatus: TRepoStatus; const sStatusText: string );
begin

  Assert.AreEqual<TRepoStatus>( eStatus, rRepo.Status, 'Status; the text was "' + rRepo.StatusText + '"' );
  Assert.AreEqual( sStatusText, rRepo.StatusText, False, 'StatusText' );

end;

{ TTestRefreshStatus }

procedure TTestRefreshStatus.Setup;
begin

  StartSandbox;

end;

procedure TTestRefreshStatus.TearDown;
begin

  EndSandbox;

end;

procedure TTestRefreshStatus.CleanRepositoryWithoutRemote;
begin

  var sRepo := FSandbox.InitRepo( 'solo' );
  var rRepo := Track( sRepo );

  AssertStatus( rRepo, rsClean, 'Clean' );
  Assert.AreEqual( 'main', rRepo.Branch, False );
  Assert.AreEqual( 1, rRepo.TrackedFileCount, 'TrackedFileCount' );
  Assert.AreEqual( 0, rRepo.ModifiedFileCount, 'ModifiedFileCount' );
  Assert.AreEqual<TRemoteProvider>( rpNone, rRepo.Provider );
  Assert.IsFalse( rRepo.HasUpstream, 'HasUpstream' );
  Assert.IsFalse( rRepo.FetchFailed, 'FetchFailed' );
  Assert.IsFalse( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );
  Assert.AreEqual( '', rRepo.RemoteSHA, False );
  Assert.AreEqual( '', rRepo.Version, False );
  Assert.AreEqual( 0, rRepo.AheadCount, 'AheadCount' );
  Assert.AreEqual( 0, rRepo.BehindCount, 'BehindCount' );

end;

procedure TTestRefreshStatus.UntrackedFileIsModified;
begin

  var sRepo := FSandbox.InitRepo( 'solo' );

  Track( sRepo );
  FSandbox.WriteText( sRepo, 'brand-new.pas', 'unit x;' );

  var rRepo := Refresh( sRepo );

  AssertStatus( rRepo, rsModified, 'Modified' );
  Assert.AreEqual( 1, rRepo.ModifiedFileCount );
  Assert.AreEqual( 1, rRepo.TrackedFileCount, 'an untracked file is not a tracked one' );

end;

procedure TTestRefreshStatus.EditedFileIsModifiedAndCounted;
begin

  var sRepo := FSandbox.InitRepo( 'solo' );

  FSandbox.WriteText( sRepo, SEED_FILE_NAME, 'edited' + #10 );

  var rRepo := Track( sRepo );

  AssertStatus( rRepo, rsModified, 'Modified' );
  Assert.AreEqual( 1, rRepo.ModifiedFileCount );

  FSandbox.WriteText( sRepo, 'one.txt', '1' );
  FSandbox.WriteText( sRepo, 'two.txt', '2' );
  rRepo := Refresh( sRepo );

  Assert.AreEqual( 3, rRepo.ModifiedFileCount, 'one edited and two untracked' );

end;

procedure TTestRefreshStatus.FolderThatIsNoRepositoryIsError;
begin

  var sFolder := FSandbox.MakeFolder( 'plain' );

  FSandbox.WriteText( sFolder, 'file.txt', 'x' );

  var rRepo := Track( sFolder );

  AssertStatus( rRepo, rsError, 'Error' );
  Assert.AreEqual( '(unknown)', rRepo.Branch, False );

end;

procedure TTestRefreshStatus.CloneIsCleanWithUpstream;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );

  var rRepo := Track( sLocal );

  AssertStatus( rRepo, rsClean, 'Clean' );
  Assert.IsTrue( rRepo.HasUpstream, 'HasUpstream' );
  Assert.IsFalse( rRepo.FetchFailed, 'FetchFailed' );
  Assert.AreEqual<TRemoteProvider>( rpOther, rRepo.Provider );
  Assert.IsTrue( TRegEx.IsMatch( rRepo.RemoteSHA, SHA_PATTERN ), 'RemoteSHA is a commit hash: ' + rRepo.RemoteSHA );
  Assert.AreEqual( FSandbox.RevParse( sBare, 'main' ), rRepo.RemoteSHA, False, 'and it is the origin''s commit' );

end;

procedure TTestRefreshStatus.AheadIsPushRequired;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.CommitFile( sLocal, 'a.txt', 'a', 'One' );
  FSandbox.CommitFile( sLocal, 'b.txt', 'b', 'Two' );

  var rRepo := Track( sLocal );

  AssertStatus( rRepo, rsPushRequired, 'Push Required (2)' );
  Assert.AreEqual( 2, rRepo.AheadCount, 'AheadCount' );
  Assert.AreEqual( 0, rRepo.BehindCount, 'BehindCount' );
  Assert.IsTrue( rRepo.HasUpstream, 'HasUpstream' );

end;

procedure TTestRefreshStatus.BehindAfterFetchIsPullRequired;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' );
  FSandbox.Git( sLocal, 'fetch' );

  var rRepo := Track( sLocal );

  AssertStatus( rRepo, rsPullRequired, 'Pull Required (1)' );
  Assert.AreEqual( 1, rRepo.BehindCount, 'BehindCount' );
  Assert.AreEqual( 0, rRepo.AheadCount, 'AheadCount' );
  Assert.AreEqual( FSandbox.RevParse( sBare, 'main' ), rRepo.RemoteSHA, False, 'RemoteSHA follows the fetched upstream' );

end;

procedure TTestRefreshStatus.RefreshFetchesOnlyWhenAsked;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  Track( sLocal );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' );

  AssertStatus( Refresh( sLocal, False ), rsClean, 'Clean' );

  var rRepo := Refresh( sLocal, True );

  AssertStatus( rRepo, rsPullRequired, 'Pull Required (1)' );
  Assert.IsFalse( rRepo.FetchFailed, 'FetchFailed' );

end;

procedure TTestRefreshStatus.AheadAndBehindIsDiverged;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' );
  FSandbox.CommitFile( sLocal, 'mine1.txt', 'm', 'Mine 1' );
  FSandbox.CommitFile( sLocal, 'mine2.txt', 'm', 'Mine 2' );
  FSandbox.Git( sLocal, 'fetch' );

  var rRepo := Track( sLocal );

  AssertStatus( rRepo, rsDiverged, 'Diverged (+2/-1)' );
  Assert.AreEqual( 2, rRepo.AheadCount, 'AheadCount' );
  Assert.AreEqual( 1, rRepo.BehindCount, 'BehindCount' );

end;

procedure TTestRefreshStatus.ModifiedAndBehindSaysBoth;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' );
  FSandbox.Git( sLocal, 'fetch' );
  FSandbox.WriteText( sLocal, 'work-in-progress.pas', 'unit x;' );

  var rRepo := Track( sLocal );

  AssertStatus( rRepo, rsModified, 'Modified - 1 to pull' );
  Assert.AreEqual( 1, rRepo.BehindCount, 'BehindCount' );

end;

procedure TTestRefreshStatus.NeverPushedIsPushRequired;
begin

  var sBare := FSandbox.InitBare( 'empty-origin.git' );
  var sRepo := FSandbox.InitRepo( 'unpublished' );

  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );

  var rRepo := Track( sRepo );

  AssertStatus( rRepo, rsPushRequired, 'Push Required (not on the remote)' );
  Assert.IsFalse( rRepo.HasUpstream, 'HasUpstream' );
  Assert.AreEqual( '', rRepo.RemoteSHA, False );
  Assert.AreEqual<TRemoteProvider>( rpOther, rRepo.Provider );

end;

procedure TTestRefreshStatus.NoUpstreamComparesWithOriginBranch;
begin

  var sBare := FSandbox.InitBare( 'origin.git' );
  var sRepo := FSandbox.InitRepo( 'no-upstream' );

  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );
  FSandbox.Git( sRepo, 'push origin main' );

  var rRepo := Track( sRepo );

  AssertStatus( rRepo, rsClean, 'Clean' );
  Assert.IsFalse( rRepo.HasUpstream, 'HasUpstream' );

  FSandbox.CommitFile( sRepo, 'more.txt', 'more', 'More' );
  rRepo := Refresh( sRepo );

  AssertStatus( rRepo, rsPushRequired, 'Push Required (1)' );
  Assert.AreEqual( 1, rRepo.AheadCount, 'AheadCount' );
  Assert.IsFalse( rRepo.HasUpstream, 'HasUpstream' );

end;

procedure TTestRefreshStatus.FailedFetchIsFlagged;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );

  // A remote that is not there: a local path, so nothing leaves the machine.
  FSandbox.Git( sLocal, Format( 'remote set-url origin "%s"', [ FSandbox.PathOf( 'gone.git' ) ] ) );
  Track( sLocal );

  var rRepo := Refresh( sLocal, True );

  Assert.IsTrue( rRepo.FetchFailed, 'FetchFailed' );
  AssertStatus( rRepo, rsClean, 'Clean - fetch failed' );

  rRepo := Refresh( sLocal, False );

  Assert.IsTrue( rRepo.FetchFailed, 'a refresh that does not fetch must not clear the failure' );
  Assert.AreEqual<TRepoStatus>( rsClean, rRepo.Status );

end;

procedure TTestRefreshStatus.LinkedWorktreeIsNotAnError;
begin

  var sRepo := FSandbox.InitRepo( 'main-tree' );
  var sSide := FSandbox.PathOf( 'side-tree' );

  FSandbox.Git( sRepo, Format( 'worktree add -b side "%s"', [ sSide ] ) );

  Assert.IsTrue( TFile.Exists( TPath.Combine( sSide, '.git' ) ), 'arrangement: .git is a FILE in a linked worktree' );
  Assert.IsTrue( TGitRepoManager.HasGitEntry( sSide ) );

  var rRepo := Track( sSide );

  AssertStatus( rRepo, rsClean, 'Clean' );
  Assert.AreEqual( 'side', rRepo.Branch, False );

  FSandbox.WriteText( sSide, 'new.txt', 'x' );

  AssertStatus( Refresh( sSide ), rsModified, 'Modified' );

end;

procedure TTestRefreshStatus.ProviderFollowsTheRemote;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );

  var sSolo := FSandbox.InitRepo( 'solo' );

  Assert.AreEqual<TRemoteProvider>( rpNone, FManager.GetRepoProvider( sLocal ), 'a repository that is not in the list has no provider' );

  Track( sSolo );
  Track( sLocal );

  Assert.AreEqual<TRemoteProvider>( rpNone, FManager.GetRepoProvider( sSolo ) );
  Assert.AreEqual<TRemoteProvider>( rpOther, FManager.GetRepoProvider( sLocal ) );

  // The URL is only read, never contacted.
  FSandbox.Git( sSolo, 'remote add origin https://github.com/example-owner/example-repo.git' );

  Assert.AreEqual<TRemoteProvider>( rpGitHub, FManager.GetRepoProvider( sSolo ) );

end;

{ TTestArtefactFilter }

procedure TTestArtefactFilter.Setup;
begin

  StartSandbox;

end;

procedure TTestArtefactFilter.TearDown;
begin

  EndSandbox;

end;

function TTestArtefactFilter.StatusWith( const saModified, saUntracked: TArray<string> ): TRepoInfo;
begin

  var sRepo := FSandbox.InitRepo( 'project' );

  for var sName in saModified do
    FSandbox.CommitFile( sRepo, sName, 'committed', 'Add ' + sName.Replace( '\', '/' ) );

  for var sName in saModified do
    FSandbox.WriteText( sRepo, sName, 'changed since' );

  for var sName in saUntracked do
    FSandbox.WriteText( sRepo, sName, 'new' );

  Result := Track( sRepo );

end;

procedure TTestArtefactFilter.CompiledUnitAloneIsBuildOutputOnly;
begin

  var rRepo := StatusWith( [], [ 'Unit1.dcu' ] );

  AssertStatus( rRepo, rsClean, 'Clean - build output only' );
  Assert.IsTrue( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );
  Assert.AreEqual( 1, rRepo.ModifiedFileCount, 'the entry is still counted' );

end;

procedure TTestArtefactFilter.PlatformConfigurationFolderIsBuildOutput;
begin

  var rRepo := StatusWith( [ 'Win64\Debug\settings.txt', 'pkg\Win32\Release\notes.txt' ], [] );

  AssertStatus( rRepo, rsClean, 'Clean - build output only' );
  Assert.IsTrue( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );

end;

procedure TTestArtefactFilter.HistoryFolderIsBuildOutput;
begin

  var rRepo := StatusWith( [], [ '__history\Unit1.pas.~1~' ] );

  AssertStatus( rRepo, rsClean, 'Clean - build output only' );
  Assert.IsTrue( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );

end;

procedure TTestArtefactFilter.UntrackedPlatformFolderIsBuildOutput;
begin

  var rRepo := StatusWith( [], [ 'Win64\Debug\Unit1.dcu', 'Win64\Debug\Unit2.dcu' ] );

  AssertStatus( rRepo, rsClean, 'Clean - build output only' );
  Assert.IsTrue( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );

end;

procedure TTestArtefactFilter.ReleaseFolderAloneIsARealChange;
begin

  var rRepo := StatusWith( [ 'docs\release\notes.md' ], [] );

  AssertStatus( rRepo, rsModified, 'Modified' );
  Assert.IsFalse( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );

end;

procedure TTestArtefactFilter.PlatformFolderAloneIsARealChange;
begin

  var rRepo := StatusWith( [ 'Source\Win64\Thunks.pas' ], [] );

  AssertStatus( rRepo, rsModified, 'Modified' );
  Assert.IsFalse( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );

end;

procedure TTestArtefactFilter.ExecutableIsARealChange;
begin

  var rRepo := StatusWith( [], [ 'tool.exe' ] );

  AssertStatus( rRepo, rsModified, 'Modified' );
  Assert.IsFalse( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );

end;

procedure TTestArtefactFilter.RealChangeAmongBuildOutputIsModified;
begin

  var rRepo := StatusWith( [ 'Win64\Debug\settings.txt' ], [ 'Unit1.dcu', 'Unit1.pas' ] );

  AssertStatus( rRepo, rsModified, 'Modified' );
  Assert.IsFalse( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );
  Assert.AreEqual( 3, rRepo.ModifiedFileCount );

end;

procedure TTestArtefactFilter.BuildOutputOnlyStillReportsUnpushedCommits;
var
  sBare, sLocal, sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.CommitFile( sLocal, 'real.pas', 'unit real;', 'Real work' );
  FSandbox.WriteText( sLocal, 'real.dcu', 'compiled' );

  var rRepo := Track( sLocal );

  AssertStatus( rRepo, rsPushRequired, 'Push Required (1) - build output only' );
  Assert.IsTrue( rRepo.ArtifactOnlyChanges, 'ArtifactOnlyChanges' );

end;

{ TTestProjectVersion }

procedure TTestProjectVersion.Setup;
begin

  StartSandbox;

end;

procedure TTestProjectVersion.TearDown;
begin

  EndSandbox;

end;

function TTestProjectVersion.VersionGroup( const sCondition, sVersion: string ): string;
begin

  Result := Format( '    <PropertyGroup Condition="''$(%s)''!=''''">' + #13#10 +
    '        <VerInfo_Keys>CompanyName=X;FileVersion=%s;ProductVersion=%s;Comments=</VerInfo_Keys>' + #13#10 +
    '    </PropertyGroup>' + #13#10, [ sCondition, sVersion, sVersion ] );

end;

function TTestProjectVersion.ProjectText( const sGroups: string ): string;
begin

  Result := '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + #13#10 +
    '    <PropertyGroup>' + #13#10 +
    '        <Config Condition="''$(Config)''==''''">Release</Config>' + #13#10 +
    '        <Platform Condition="''$(Platform)''==''''">Win64</Platform>' + #13#10 +
    '    </PropertyGroup>' + #13#10 +
    '    <PropertyGroup Condition="''$(Config)''==''Release'' or ''$(Cfg_1)''!=''''">' + #13#10 +
    '        <Cfg_1>true</Cfg_1>' + #13#10 +
    '    </PropertyGroup>' + #13#10 +
    '    <PropertyGroup Condition="''$(Config)''==''Debug'' or ''$(Cfg_2)''!=''''">' + #13#10 +
    '        <Cfg_2>true</Cfg_2>' + #13#10 +
    '    </PropertyGroup>' + #13#10 +
    sGroups +
    '</Project>' + #13#10;

end;

procedure TTestProjectVersion.ActiveConfigurationWinsOverHighest;
begin

  var sFolder := FSandbox.MakeFolder( 'project' );

  FSandbox.WriteText( sFolder, 'App.dproj', ProjectText(
    VersionGroup( 'Base', '0.9.0.0' ) +
    VersionGroup( 'Base_Win64', '2.0.0.0' ) +
    VersionGroup( 'Cfg_1_Win64', '1.0.0.347' ) +
    VersionGroup( 'Cfg_2_Win64', '7.7.7.7' ) ) );

  Assert.AreEqual( '1.0.0.347', FManager.GetProjectVersion( sFolder ), False );

end;

procedure TTestProjectVersion.LayeringIsByRankNotFileOrder;
begin

  var sFolder := FSandbox.MakeFolder( 'project' );

  FSandbox.WriteText( sFolder, 'App.dproj', ProjectText(
    VersionGroup( 'Cfg_1_Win64', '1.0.0.347' ) +
    VersionGroup( 'Cfg_1', '1.5.0.0' ) +
    VersionGroup( 'Base_Win64', '2.0.0.0' ) +
    VersionGroup( 'Base', '3.0.0.0' ) ) );

  Assert.AreEqual( '1.0.0.347', FManager.GetProjectVersion( sFolder ), False );

end;

procedure TTestProjectVersion.UnresolvableProjectFallsBackToHighest;
begin

  var sFolder := FSandbox.MakeFolder( 'project' );

  // No <Config> or <Platform> default: nothing says which group is active.
  FSandbox.WriteText( sFolder, 'App.dproj', '<Project>' + #13#10 +
    VersionGroup( 'Base', '1.9.0.0' ) + VersionGroup( 'Cfg_1', '1.10.0.0' ) + VersionGroup( 'Cfg_2', '1.2.0.0' ) +
    '</Project>' + #13#10 );

  Assert.AreEqual( '1.10.0.0', FManager.GetProjectVersion( sFolder ), False );

end;

procedure TTestProjectVersion.RootProjectBeatsVendoredProject;
begin

  var sFolder := FSandbox.MakeFolder( 'project' );

  FSandbox.WriteText( sFolder, 'App.dproj', ProjectText( VersionGroup( 'Cfg_1_Win64', '1.0.0.1' ) ) );
  FSandbox.WriteText( sFolder, 'vendor\Lib\Lib.dproj', ProjectText( VersionGroup( 'Cfg_1_Win64', '9.9.9.9' ) ) );

  Assert.AreEqual( '1.0.0.1', FManager.GetProjectVersion( sFolder ), False );

  // With no project in the root, the tree is searched.
  var sDeep := FSandbox.MakeFolder( 'deep-only' );

  FSandbox.WriteText( sDeep, 'src\App.dproj', ProjectText( VersionGroup( 'Cfg_1_Win64', '4.3.2.1' ) ) );

  Assert.AreEqual( '4.3.2.1', FManager.GetProjectVersion( sDeep ), False );

end;

procedure TTestProjectVersion.VersionThatIsNotDottedDigitsIsRefused;
begin

  var sResolved := FSandbox.MakeFolder( 'resolved' );
  var sFallback := FSandbox.MakeFolder( 'fallback' );

  FSandbox.WriteText( sResolved, 'App.dproj', ProjectText( VersionGroup( 'Cfg_1_Win64', '1.0" --force "x' ) ) );
  FSandbox.WriteText( sFallback, 'App.dproj', '<Project>' + #13#10 + VersionGroup( 'Base', '1.0.0.0.0' ) + '</Project>' + #13#10 );

  Assert.AreEqual( '', FManager.GetProjectVersion( sResolved ), False, 'a quote and an option' );
  Assert.AreEqual( '', FManager.GetProjectVersion( sFallback ), False, 'five groups of digits' );

end;

procedure TTestProjectVersion.NoProjectMeansNoVersion;
begin

  var sFolder := FSandbox.MakeFolder( 'no-project' );

  FSandbox.WriteText( sFolder, 'readme.md', 'FileVersion=1.2.3.4;' );

  Assert.AreEqual( '', FManager.GetProjectVersion( sFolder ), False );

end;

procedure TTestProjectVersion.ForceRescanSeesAVersionJustChanged;
begin

  var sFolder := FSandbox.MakeFolder( 'project' );

  FSandbox.WriteText( sFolder, 'App.dproj', ProjectText( VersionGroup( 'Cfg_1_Win64', '1.0.0.1' ) ) );

  Assert.AreEqual( '1.0.0.1', FManager.GetProjectVersion( sFolder ), False, 'first read' );

  FSandbox.WriteText( sFolder, 'App.dproj', ProjectText( VersionGroup( 'Cfg_1_Win64', '1.0.0.2' ) ) );

  Assert.AreEqual( '1.0.0.1', FManager.GetProjectVersion( sFolder ), False, 'inside the scan window the cached value is reused' );
  Assert.AreEqual( '1.0.0.2', FManager.GetProjectVersion( sFolder, True ), False, 'a forced rescan re-reads the project' );

end;

{ TTestCommitAndPush }

procedure TTestCommitAndPush.Setup;
begin

  StartSandbox;

end;

procedure TTestCommitAndPush.TearDown;
begin

  EndSandbox;

end;

procedure TTestCommitAndPush.CommitLandsOnTheOrigin;
const
  MESSAGE = 'Fix "quoted" text & 100% of it | done > now';
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.WriteText( sLocal, SEED_FILE_NAME, 'edited' + #10 );
  FSandbox.WriteText( sLocal, 'added.pas', 'unit added;' );

  var sBefore := FSandbox.RevParse( sBare, 'main' );

  AssertStatus( Track( sLocal ), rsModified, 'Modified' );

  Assert.IsTrue( FManager.CommitAndPush( sLocal, MESSAGE, sLog ), sLog );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.AreNotEqual( sBefore, sHead, False, 'a commit was made' );
  Assert.AreEqual( sHead, FSandbox.RevParse( sBare, 'main' ), False, 'and it is on the origin' );
  Assert.AreEqual( MESSAGE, FSandbox.Git( sBare, 'log -1 --format=%s main' ), False, 'with the message as given' );
  Assert.AreEqual( 'unit added;', FSandbox.Git( sBare, 'show main:added.pas' ), False, 'the new file went too' );
  Assert.IsTrue( sLog.Contains( 'Pushed successfully' ), sLog );

  AssertStatus( Snapshot( sLocal ), rsClean, 'Clean' );
  Assert.AreEqual( MESSAGE, FManager.CommitHistory[ 0 ], False, 'the message joined the history' );

end;

procedure TTestCommitAndPush.OperationsRefuseARepositoryNotInTheList;
const
  REASON = 'Repository is no longer in the list';
var
  sLog, sName, sChanges: string;
begin

  var sRepo := FSandbox.InitRepo( 'untracked-by-manager' );
  var sHead := FSandbox.RevParse( sRepo, 'HEAD' );

  FSandbox.WriteText( sRepo, 'work.txt', 'x' );

  Assert.IsFalse( FManager.CommitAndPush( sRepo, 'msg', sLog ), 'CommitAndPush' );
  Assert.AreEqual( REASON, sLog, False );
  Assert.IsFalse( FManager.PushRepository( sRepo, sLog ), 'PushRepository' );
  Assert.AreEqual( REASON, sLog, False );
  Assert.IsFalse( FManager.ForcePushRepository( sRepo, sLog ), 'ForcePushRepository' );
  Assert.AreEqual( REASON, sLog, False );
  Assert.IsFalse( FManager.PullRepository( sRepo, sLog ), 'PullRepository' );
  Assert.AreEqual( REASON, sLog, False );
  Assert.IsFalse( FManager.ResolveConflictsKeepLocal( sRepo, sLog ), 'ResolveConflictsKeepLocal' );
  Assert.AreEqual( REASON, sLog, False );
  Assert.IsFalse( FManager.CreateBackupBranch( sRepo, sName, sLog ), 'CreateBackupBranch' );
  Assert.AreEqual( REASON, sLog, False );
  Assert.IsFalse( FManager.GetIncomingChanges( sRepo, sChanges, sLog ), 'GetIncomingChanges' );
  Assert.AreEqual( REASON, sLog, False );

  Assert.AreEqual( sHead, FSandbox.RevParse( sRepo, 'HEAD' ), False, 'nothing was committed' );
  Assert.AreEqual( 'main', FSandbox.Git( sRepo, 'branch --format=%(refname:short)' ), False, 'and no branch was created' );

end;

procedure TTestCommitAndPush.BehindIsRefusedBeforeCommitting;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  Track( sLocal );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' );
  FSandbox.WriteText( sLocal, 'mine.txt', 'mine' );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsFalse( FManager.CommitAndPush( sLocal, 'Would diverge', sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'Refused to commit - the branch is 1 commit(s) behind' ), sLog );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'nothing was committed' );
  Assert.AreEqual( '?? mine.txt', FSandbox.Git( sLocal, 'status --porcelain' ), False, 'the work is still there, not even staged' );
  Assert.AreEqual( 0, Integer( Length( FManager.CommitHistory ) ), 'a message that committed nothing is not remembered' );

end;

procedure TTestCommitAndPush.DetachedHeadIsRefused;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.Git( sLocal, 'checkout --detach' );
  FSandbox.WriteText( sLocal, 'mine.txt', 'mine' );
  Track( sLocal );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsFalse( FManager.CommitAndPush( sLocal, 'On no branch', sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'Refused to commit - HEAD is detached' ), sLog );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'nothing was committed' );

end;

procedure TTestCommitAndPush.NoUpstreamIsPushedAndSet;
var
  sLog: string;
begin

  var sBare := FSandbox.InitBare( 'empty-origin.git' );
  var sRepo := FSandbox.InitRepo( 'unpublished' );

  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );
  FSandbox.WriteText( sRepo, 'work.txt', 'work' );
  Track( sRepo );

  Assert.IsTrue( FManager.CommitAndPush( sRepo, 'First publish', sLog ), sLog );
  Assert.AreEqual( FSandbox.RevParse( sRepo, 'HEAD' ), FSandbox.RevParse( sBare, 'main' ), False, 'the branch is on the origin' );
  Assert.AreEqual( 'origin/main', FSandbox.Git( sRepo, 'rev-parse --abbrev-ref @{upstream}' ), False, 'and tracks it' );

  var rRepo := Snapshot( sRepo );

  AssertStatus( rRepo, rsClean, 'Clean' );
  Assert.IsTrue( rRepo.HasUpstream, 'HasUpstream' );

end;

procedure TTestCommitAndPush.NothingToCommitStillPushes;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.CommitFile( sLocal, 'done.txt', 'done', 'Already committed' );
  AssertStatus( Track( sLocal ), rsPushRequired, 'Push Required (1)' );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsTrue( FManager.CommitAndPush( sLocal, 'Unused message', sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'Nothing staged - skipping the commit' ), sLog );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'no empty commit was made' );
  Assert.AreEqual( sHead, FSandbox.RevParse( sBare, 'main' ), False, 'the earlier commit was pushed' );
  Assert.AreEqual( 0, Integer( Length( FManager.CommitHistory ) ), 'the unused message is not remembered' );

end;

procedure TTestCommitAndPush.FailedPushKeepsTheCommitAndSaysSo;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.Git( sLocal, Format( 'remote set-url origin "%s"', [ FSandbox.PathOf( 'gone.git' ) ] ) );
  FSandbox.WriteText( sLocal, 'work.txt', 'work' );
  AssertStatus( Track( sLocal ), rsModified, 'Modified' );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsFalse( FManager.CommitAndPush( sLocal, 'Cannot be pushed', sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'Push failed:' ), sLog );
  Assert.IsTrue( sLog.Contains( 'The commit was made locally and has NOT been pushed' ), sLog );
  Assert.AreNotEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'the commit exists locally' );

  AssertStatus( Snapshot( sLocal ), rsPushRequired, 'Push Required (1)' );
  Assert.AreEqual( 'Cannot be pushed', FManager.CommitHistory[ 0 ], False, 'the message is kept once it is in a commit' );

end;

procedure TTestCommitAndPush.FilePatternLimitsWhatIsStaged;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.WriteText( sLocal, 'wanted.txt', 'wanted' );
  FSandbox.WriteText( sLocal, 'unwanted.md', 'unwanted' );
  Track( sLocal );
  FManager.FilePattern := '*.txt';

  Assert.IsTrue( FManager.CommitAndPush( sLocal, 'Text files only', sLog ), sLog );
  Assert.AreEqual( 'wanted.txt', FSandbox.Git( sBare, 'show --name-only --format= main' ), False, 'only the matching file was committed' );
  Assert.AreEqual( '?? unwanted.md', FSandbox.Git( sLocal, 'status --porcelain' ), False, 'the other is left as it was' );

end;

procedure TTestCommitAndPush.PatternStartingWithDashIsAPath;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.WriteText( sLocal, '-A', 'a file whose name is a Git option' );
  FSandbox.WriteText( sLocal, 'other.txt', 'must not be staged' );
  Track( sLocal );
  FManager.FilePattern := '-A';

  Assert.IsTrue( FManager.CommitAndPush( sLocal, 'A dash file', sLog ), sLog );
  Assert.AreEqual( '-A', FSandbox.Git( sBare, 'show --name-only --format= main' ), False, 'the file named -A, and only it, was committed' );
  Assert.AreEqual( '?? other.txt', FSandbox.Git( sLocal, 'status --porcelain' ), False, '"add -A" would have staged this one too' );

end;

procedure TTestCommitAndPush.ProjectVersionIsTaggedAndPushed;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.WriteText( sLocal, 'App.dproj', '<Project>' + #13#10 +
    '    <PropertyGroup Condition="''$(Base)''!=''''">' + #13#10 +
    '        <VerInfo_Keys>CompanyName=X;FileVersion=3.2.1.7;ProductVersion=3.2.1.7</VerInfo_Keys>' + #13#10 +
    '    </PropertyGroup>' + #13#10 + '</Project>' + #13#10 );
  Track( sLocal );

  Assert.IsTrue( FManager.CommitAndPush( sLocal, 'Release 3.2.1.7', sLog ), sLog );
  Assert.AreEqual( 'v3.2.1.7', FSandbox.Git( sBare, 'tag -l' ), False, 'the tag is on the origin' );
  Assert.AreEqual( 'tag', FSandbox.Git( sBare, 'cat-file -t v3.2.1.7' ), False, 'and is an annotated tag' );
  Assert.AreEqual( FSandbox.RevParse( sLocal, 'HEAD' ), FSandbox.RevParse( sBare, 'v3.2.1.7' ), False, 'on the commit just pushed' );
  Assert.AreEqual( '3.2.1.7', Snapshot( sLocal ).Version, False, 'the row shows the version' );

end;

{ TTestRemoteOperations }

procedure TTestRemoteOperations.Setup;
begin

  StartSandbox;

end;

procedure TTestRemoteOperations.TearDown;
begin

  EndSandbox;

end;

procedure TTestRemoteOperations.PushSendsUnpushedCommits;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.CommitFile( sLocal, 'mine.txt', 'mine', 'Mine' );
  Track( sLocal );

  Assert.AreNotEqual( FSandbox.RevParse( sLocal, 'HEAD' ), FSandbox.RevParse( sBare, 'main' ), False, 'arrangement: not pushed yet' );
  Assert.IsTrue( FManager.PushRepository( sLocal, sLog ), sLog );
  Assert.AreNotEqual( '', sLog, False, 'the log is never empty' );
  Assert.AreEqual( FSandbox.RevParse( sLocal, 'HEAD' ), FSandbox.RevParse( sBare, 'main' ), False );

end;

procedure TTestRemoteOperations.PushSetsUpstreamWhenThereIsNone;
var
  sLog, sOutput: string;
begin

  var sBare := FSandbox.InitBare( 'empty-origin.git' );
  var sRepo := FSandbox.InitRepo( 'unpublished' );

  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );
  AssertStatus( Track( sRepo ), rsPushRequired, 'Push Required (not on the remote)' );

  Assert.IsFalse( FSandbox.TryGit( sRepo, 'rev-parse --abbrev-ref @{upstream}', sOutput ), 'arrangement: no upstream yet' );
  Assert.IsTrue( FManager.PushRepository( sRepo, sLog ), sLog );
  Assert.AreEqual( FSandbox.RevParse( sRepo, 'HEAD' ), FSandbox.RevParse( sBare, 'main' ), False, 'the branch is on the origin' );
  Assert.AreEqual( 'origin/main', FSandbox.Git( sRepo, 'rev-parse --abbrev-ref @{upstream}' ), False, 'and now tracks it' );

  var rRepo := Refresh( sRepo );

  AssertStatus( rRepo, rsClean, 'Clean' );
  Assert.IsTrue( rRepo.HasUpstream, 'HasUpstream' );

end;

procedure TTestRemoteOperations.ForcePushRefusesWithoutARecordedRemoteCommit;
var
  sLog, sOutput: string;
begin

  var sBare := FSandbox.InitBare( 'empty-origin.git' );
  var sRepo := FSandbox.InitRepo( 'unpublished' );

  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );

  Assert.AreEqual( '', Track( sRepo ).RemoteSHA, False, 'arrangement: nothing recorded to lease against' );
  Assert.IsFalse( FManager.ForcePushRepository( sRepo, sLog ), sLog );
  Assert.StartsWith( 'Force push refused - branch "main" has no upstream recorded', sLog, False );
  Assert.IsFalse( FSandbox.TryGit( sBare, 'rev-parse --verify main', sOutput ), 'nothing reached the remote' );

end;

procedure TTestRemoteOperations.ForcePushOverwritesWhenTheRemoteHasNotMoved;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.CommitFile( sLocal, 'mine.txt', 'mine', 'Mine' );
  FSandbox.Git( sLocal, 'push origin main' );
  FSandbox.Git( sLocal, 'commit --amend -m "Mine, rewritten"' );

  AssertStatus( Track( sLocal ), rsDiverged, 'Diverged (+1/-1)' );

  Assert.IsTrue( FManager.ForcePushRepository( sLocal, sLog ), sLog );
  Assert.AreEqual( FSandbox.RevParse( sLocal, 'HEAD' ), FSandbox.RevParse( sBare, 'main' ), False, 'the origin holds the rewritten commit' );
  Assert.AreEqual( 'Mine, rewritten', FSandbox.Git( sBare, 'log -1 --format=%s main' ), False );

end;

procedure TTestRemoteOperations.ForcePushIsRefusedWhileTheLastFetchFailed;
const
  REFUSED = 'Force push refused - the last refresh could not fetch from the remote';
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.CommitFile( sLocal, 'mine.txt', 'mine', 'Mine' );
  FSandbox.Git( sLocal, 'push origin main' );
  FSandbox.Git( sLocal, 'commit --amend -m "Mine, rewritten"' );
  Track( sLocal );

  var sPublished := FSandbox.RevParse( sBare, 'main' );

  // A remote that is not there: a local path, so nothing leaves the machine.
  FSandbox.Git( sLocal, Format( 'remote set-url origin "%s"', [ FSandbox.PathOf( 'gone.git' ) ] ) );

  Assert.IsTrue( Refresh( sLocal, True ).FetchFailed, 'arrangement: the fetch must fail' );
  Assert.IsFalse( FManager.ForcePushRepository( sLocal, sLog ), sLog );
  Assert.StartsWith( REFUSED, sLog, False );

  // A local-only refresh learns nothing about the remote, so the refusal stands.
  Assert.IsTrue( Refresh( sLocal, False ).FetchFailed, 'a refresh that does not fetch must not clear the failure' );
  Assert.EndsWith( ' - fetch failed', Refresh( sLocal, False ).StatusText, False,
    'the row must go on saying why Force Push is refused' );
  Assert.IsFalse( FManager.ForcePushRepository( sLocal, sLog ), sLog );
  Assert.StartsWith( REFUSED, sLog, False );

  // The refusals are proved against the real origin: had either push been
  // attempted with the origin restored, the rewritten commit would be there.
  FSandbox.Git( sLocal, Format( 'remote set-url origin "%s"', [ sBare ] ) );

  Assert.AreEqual( sPublished, FSandbox.RevParse( sBare, 'main' ), False, 'nothing was pushed' );

  Assert.IsFalse( Refresh( sLocal, True ).FetchFailed, 'a fetch that succeeds clears the failure' );
  Assert.IsTrue( FManager.ForcePushRepository( sLocal, sLog ), sLog );
  Assert.AreEqual( FSandbox.RevParse( sLocal, 'HEAD' ), FSandbox.RevParse( sBare, 'main' ), False, 'the origin holds the rewritten commit' );

end;

procedure TTestRemoteOperations.ForcePushRefusesWhenTheRemoteMoved;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.CommitFile( sLocal, 'mine.txt', 'mine', 'Mine' );
  FSandbox.Git( sLocal, 'push origin main' );
  FSandbox.Git( sLocal, 'commit --amend -m "Mine, rewritten"' );

  // This is what the user is shown, and so what the lease names.
  Track( sLocal );

  // Somebody else pushes, and a fetch moves the remote-tracking ref past it: a
  // bare --force-with-lease would now pass and destroy their commit.
  FSandbox.Git( sOther, 'pull --ff-only' );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' );
  FSandbox.Git( sLocal, 'fetch' );

  var sTheirs := FSandbox.RevParse( sBare, 'main' );

  Assert.IsFalse( FManager.ForcePushRepository( sLocal, sLog ), sLog );
  Assert.StartsWith( 'Force push failed:', sLog, False );
  Assert.IsTrue( sLog.Contains( 'The remote has moved since this repository''s status was last refreshed' ), sLog );
  Assert.AreEqual( sTheirs, FSandbox.RevParse( sBare, 'main' ), False, 'their commit survives' );

end;

procedure TTestRemoteOperations.PullFastForwards;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' + #10 );
  Track( sLocal );

  Assert.AreNotEqual( FSandbox.RevParse( sBare, 'main' ), FSandbox.RevParse( sLocal, 'HEAD' ), False, 'arrangement: behind' );
  Assert.IsTrue( FManager.PullRepository( sLocal, sLog ), sLog );
  Assert.AreEqual( FSandbox.RevParse( sBare, 'main' ), FSandbox.RevParse( sLocal, 'HEAD' ), False );
  Assert.AreEqual( 'theirs' + #10, FSandbox.ReadText( sLocal, 'theirs.txt' ), False, 'the file arrived in the working tree' );

end;

procedure TTestRemoteOperations.PullRefusesToMergeDivergedHistory;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  CommitAndPushFrom( sOther, 'theirs.txt', 'theirs' );
  FSandbox.CommitFile( sLocal, 'mine.txt', 'mine', 'Mine' );
  Track( sLocal );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsFalse( FManager.PullRepository( sLocal, sLog ), sLog );
  Assert.StartsWith( 'Pull failed:', sLog, False );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'no merge commit was created' );

end;

procedure TTestRemoteOperations.BackupBranchIsCreatedAtHead;
var
  sName, sSecond, sLog: string;
begin

  var sRepo := FSandbox.InitRepo( 'solo' );

  Track( sRepo );

  Assert.IsTrue( FManager.CreateBackupBranch( sRepo, sName, sLog ), sLog );
  Assert.IsTrue( TRegEx.IsMatch( sName, '^backup-\d{4}-\d{2}-\d{2}-\d{6}-\d{3}$' ), 'name: ' + sName );
  Assert.AreEqual( FSandbox.RevParse( sRepo, 'HEAD' ), FSandbox.RevParse( sRepo, sName ), False, 'the branch is at HEAD' );
  Assert.AreEqual( 'main', FSandbox.Git( sRepo, 'branch --show-current' ), False, 'and it was not checked out' );
  Assert.AreEqual( 'Created backup branch: ' + sName, sLog, False );

  // A second backup needs a different name; the name is to the millisecond,
  // so wait for the clock to move on rather than hope that it has.
  var sStamp := FormatDateTime( 'hhnnss"-"zzz', Now );

  while FormatDateTime( 'hhnnss"-"zzz', Now ) = sStamp do
    TThread.Yield;

  Assert.IsTrue( FManager.CreateBackupBranch( sRepo, sSecond, sLog ), sLog );
  Assert.AreNotEqual( sName, sSecond, False );

end;

procedure TTestRemoteOperations.IncomingChangesListsIncomingFiles;
var
  sBare, sLocal, sOther, sLog, sChanges: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  CommitAndPushFrom( sOther, 'incoming-file.txt', 'theirs' + #10 );
  Track( sLocal );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsTrue( FManager.GetIncomingChanges( sLocal, sChanges, sLog ), sLog );
  Assert.IsTrue( sChanges.Contains( 'incoming-file.txt' ), 'sChanges: ' + sChanges );
  Assert.AreEqual( 'Fetched successfully', sLog, False );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'a preview merges nothing' );
  Assert.IsFalse( TFile.Exists( TPath.Combine( sLocal, 'incoming-file.txt' ) ), 'and writes nothing to the working tree' );

end;

procedure TTestRemoteOperations.IncomingChangesIsEmptyWhenUpToDate;
var
  sBare, sLocal, sOther, sLog, sChanges: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );

  // A local commit the origin lacks is OUTGOING, and must not be listed.
  FSandbox.CommitFile( sLocal, 'outgoing.txt', 'mine', 'Mine' );
  Track( sLocal );
  sChanges := 'not yet assigned';

  Assert.IsTrue( FManager.GetIncomingChanges( sLocal, sChanges, sLog ), sLog );
  Assert.AreEqual( '', sChanges, False );

end;

procedure TTestRemoteOperations.IncomingChangesWithoutUpstreamSaysSo;
var
  sLog, sChanges: string;
begin

  var sBare := FSandbox.InitBare( 'origin.git' );
  var sRepo := FSandbox.InitRepo( 'no-upstream' );

  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );
  FSandbox.Git( sRepo, 'push origin main' );
  Track( sRepo );
  sChanges := 'not yet assigned';

  Assert.IsTrue( FManager.GetIncomingChanges( sRepo, sChanges, sLog ), sLog );
  Assert.AreEqual( '', sChanges, False );
  Assert.AreEqual( 'Branch "main" has no upstream configured - nothing to preview', sLog, False );

end;

{ TTestResolveConflicts }

procedure TTestResolveConflicts.Setup;
begin

  StartSandbox;

end;

procedure TTestResolveConflicts.TearDown;
begin

  EndSandbox;

end;

function TTestResolveConflicts.GitDirHas( const sRepo, sName: string ): Boolean;
begin

  var sPath := TPath.Combine( TPath.Combine( sRepo, '.git' ), sName );

  Result := TFile.Exists( sPath ) or TDirectory.Exists( sPath );

end;

procedure TTestResolveConflicts.ArrangeBothSidesChanged( out sBare, sLocal: string );
var
  sOther: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );

  CommitAndPushFrom( sOther, 'shared.txt', 'base' + #10 );
  FSandbox.Git( sLocal, 'pull --ff-only' );

  FSandbox.CommitFile( sLocal, 'shared.txt', 'local' + #10, 'Local change' );

  FSandbox.CommitFile( sOther, 'shared.txt', 'remote' + #10, 'Remote change' );
  CommitAndPushFrom( sOther, 'incoming.txt', 'incoming' + #10 );

end;

procedure TTestResolveConflicts.ConflictIsReportedAndCommitRefused;
var
  sBare, sLocal, sLog, sOutput: string;
begin

  ArrangeBothSidesChanged( sBare, sLocal );
  FSandbox.Git( sLocal, 'fetch' );

  Assert.IsFalse( FSandbox.TryGit( sLocal, 'merge origin/main', sOutput ), 'arrangement: the merge must stop on a conflict' );

  var rRepo := Track( sLocal );

  Assert.AreEqual<TRepoStatus>( rsConflicted, rRepo.Status, rRepo.StatusText );
  Assert.StartsWith( 'Conflicted', rRepo.StatusText, False );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsFalse( FManager.CommitAndPush( sLocal, 'Would commit conflict markers', sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'Refused to commit' ), sLog );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'nothing was committed' );
  Assert.IsTrue( GitDirHas( sLocal, 'MERGE_HEAD' ), 'and the merge is still in progress' );

end;

procedure TTestResolveConflicts.KeepsLocalContentAndTheIncomingFile;
var
  sBare, sLocal, sLog, sOutput: string;
begin

  ArrangeBothSidesChanged( sBare, sLocal );
  FSandbox.Git( sLocal, 'fetch' );

  var sTheirs := FSandbox.RevParse( sBare, 'main' );
  var sMine   := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsFalse( FSandbox.TryGit( sLocal, 'merge origin/main', sOutput ), 'arrangement: the merge must stop on a conflict' );
  Assert.IsTrue( FSandbox.ReadText( sLocal, 'shared.txt' ).Contains( '<<<<<<<' ), 'arrangement: the file holds conflict markers' );
  Track( sLocal );

  Assert.IsTrue( FManager.ResolveConflictsKeepLocal( sLocal, sLog ), sLog );

  Assert.AreEqual( 'local' + #10, FSandbox.ReadText( sLocal, 'shared.txt' ), False, 'the conflicted file holds the LOCAL content' );
  Assert.AreEqual( 'incoming' + #10, FSandbox.ReadText( sLocal, 'incoming.txt' ), False, 'the incoming file was not discarded' );
  Assert.IsFalse( GitDirHas( sLocal, 'MERGE_HEAD' ), 'the merge is concluded' );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.AreEqual( Format( '%s %s %s', [ sHead, sMine, sTheirs ] ), FSandbox.Git( sLocal, 'rev-list --parents -n 1 HEAD' ), False,
    'the commit is a merge of the local and the remote commit' );
  Assert.AreEqual( 'local', FSandbox.Git( sLocal, 'show HEAD:shared.txt' ), False, 'the committed file is the local one' );
  Assert.AreEqual( 'incoming', FSandbox.Git( sLocal, 'show HEAD:incoming.txt' ), False, 'the incoming file is in the commit' );
  Assert.AreEqual( sHead, FSandbox.RevParse( sBare, 'main' ), False, 'and the merge was pushed' );
  Assert.AreEqual( '', FSandbox.Git( sLocal, 'status --porcelain' ), False, 'nothing is left over' );

  Assert.IsTrue( sLog.Contains( 'Kept local version: shared.txt' ), sLog );
  Assert.IsFalse( sLog.Contains( 'incoming.txt' ), 'the non-conflicted file was not "resolved": ' + sLog );
  Assert.IsTrue( sLog.Contains( 'Pushed successfully' ), sLog );

end;

procedure TTestResolveConflicts.LeavesUncommittedAndUntrackedFilesAlone;
var
  sBare, sLocal, sLog, sOutput: string;
begin

  ArrangeBothSidesChanged( sBare, sLocal );
  FSandbox.Git( sLocal, 'fetch' );

  // Neither file is part of the merge.
  FSandbox.WriteText( sLocal, SEED_FILE_NAME, 'uncommitted edit' + #10 );
  FSandbox.WriteText( sLocal, 'scratch.txt', 'untracked' + #10 );

  Assert.IsFalse( FSandbox.TryGit( sLocal, 'merge origin/main', sOutput ), 'arrangement: the merge must stop on a conflict' );
  Track( sLocal );

  Assert.IsTrue( FManager.ResolveConflictsKeepLocal( sLocal, sLog ), sLog );

  Assert.AreEqual( 'uncommitted edit' + #10, FSandbox.ReadText( sLocal, SEED_FILE_NAME ), False, 'the uncommitted edit is intact' );
  Assert.AreEqual( 'untracked' + #10, FSandbox.ReadText( sLocal, 'scratch.txt' ), False, 'the untracked file is intact' );
  // The sandbox trims Git's output, which takes the leading blank of ' M'.
  Assert.AreEqual( 'M ' + SEED_FILE_NAME + #10 + '?? scratch.txt', FSandbox.Git( sLocal, 'status --porcelain' ).Replace( #13#10, #10 ),
    False, 'and neither was staged or committed' );
  Assert.AreEqual( 'seed', FSandbox.Git( sBare, 'show main:' + SEED_FILE_NAME ), False, 'the uncommitted edit was not pushed' );

end;

procedure TTestResolveConflicts.KeepsALocalDeletion;
var
  sBare, sLocal, sOther, sLog, sOutput: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  CommitAndPushFrom( sOther, 'shared.txt', 'base' + #10 );
  FSandbox.Git( sLocal, 'pull --ff-only' );

  FSandbox.Git( sLocal, 'rm --quiet shared.txt' );
  FSandbox.Git( sLocal, 'commit -m "Delete it locally"' );
  CommitAndPushFrom( sOther, 'shared.txt', 'remote' + #10 );
  FSandbox.Git( sLocal, 'fetch' );

  Assert.IsFalse( FSandbox.TryGit( sLocal, 'merge origin/main', sOutput ), 'arrangement: modify/delete must conflict' );
  Track( sLocal );

  Assert.IsTrue( FManager.ResolveConflictsKeepLocal( sLocal, sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'Kept local deletion: shared.txt' ), sLog );
  Assert.IsFalse( TFile.Exists( TPath.Combine( sLocal, 'shared.txt' ) ), 'the file stays deleted' );
  Assert.IsFalse( FSandbox.TryGit( sLocal, 'cat-file -e HEAD:shared.txt', sOutput ), 'and is not in the merge commit' );
  Assert.IsFalse( GitDirHas( sLocal, 'MERGE_HEAD' ), 'the merge is concluded' );

end;

procedure TTestResolveConflicts.NoMergeInProgressIsSkipped;
var
  sBare, sLocal, sOther, sLog: string;
begin

  MakeOriginAndClones( sBare, sLocal, sOther );
  FSandbox.WriteText( sLocal, 'work.txt', 'uncommitted' );
  Track( sLocal );

  var sHead := FSandbox.RevParse( sLocal, 'HEAD' );

  Assert.IsTrue( FManager.ResolveConflictsKeepLocal( sLocal, sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'No merge in progress - nothing to resolve' ), sLog );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'nothing was committed' );
  Assert.AreEqual( sHead, FSandbox.RevParse( sBare, 'main' ), False, 'nothing was pushed' );
  Assert.AreEqual( '?? work.txt', FSandbox.Git( sLocal, 'status --porcelain' ), False, 'and the working tree is untouched' );

end;

procedure TTestResolveConflicts.RebaseInProgressIsRefused;
var
  sBare, sLocal, sLog, sOutput: string;
begin

  ArrangeBothSidesChanged( sBare, sLocal );
  FSandbox.Git( sLocal, 'fetch' );

  Assert.IsFalse( FSandbox.TryGit( sLocal, 'rebase origin/main', sOutput ), 'arrangement: the rebase must stop on a conflict' );
  Assert.IsTrue( GitDirHas( sLocal, 'rebase-merge' ) or GitDirHas( sLocal, 'rebase-apply' ), 'arrangement: a rebase is in progress' );
  Track( sLocal );

  var sConflicted := FSandbox.ReadText( sLocal, 'shared.txt' );
  var sHead       := FSandbox.RevParse( sLocal, 'HEAD' );
  var sRemote     := FSandbox.RevParse( sBare, 'main' );

  Assert.IsFalse( FManager.ResolveConflictsKeepLocal( sLocal, sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'nothing was changed' ), sLog );
  Assert.AreEqual( sConflicted, FSandbox.ReadText( sLocal, 'shared.txt' ), False, 'the conflicted file is as it was' );
  Assert.AreEqual( sHead, FSandbox.RevParse( sLocal, 'HEAD' ), False, 'nothing was committed' );
  Assert.AreEqual( sRemote, FSandbox.RevParse( sBare, 'main' ), False, 'nothing was pushed' );

end;

{ TTestNewRepository }

procedure TTestNewRepository.Setup;
begin

  StartSandbox;

end;

procedure TTestNewRepository.TearDown;
begin

  EndSandbox;

end;

procedure TTestNewRepository.InitialiseCreatesARepositoryOnMain;
var
  sLog: string;
begin

  var sFolder := FSandbox.MakeFolder( 'brand-new' );

  FSandbox.WriteText( sFolder, 'Unit1.pas', 'unit Unit1;' );

  Assert.IsTrue( FManager.InitialiseRepository( sFolder, sLog ), sLog );
  Assert.IsTrue( TGitRepoManager.HasGitEntry( sFolder ), 'the folder is a repository now' );
  Assert.AreEqual( 'main', FSandbox.Git( sFolder, 'symbolic-ref --short HEAD' ), False, 'on branch main' );
  Assert.IsTrue( sLog.Contains( 'Initialised Git repository' ), sLog );

end;

procedure TTestNewRepository.InitialiseRefusesMissingFolderAndExistingRepository;
var
  sLog: string;
begin

  var sMissing := FSandbox.PathOf( 'not-there' );

  Assert.IsFalse( FManager.InitialiseRepository( sMissing, sLog ), 'missing folder' );
  Assert.AreEqual( 'Folder does not exist: ' + sMissing, sLog, False );
  Assert.IsFalse( TDirectory.Exists( sMissing ), 'and it is not created' );

  var sRepo := FSandbox.InitRepo( 'already' );
  var sHead := FSandbox.RevParse( sRepo, 'HEAD' );

  Assert.IsFalse( FManager.InitialiseRepository( sRepo, sLog ), 'existing repository' );
  Assert.AreEqual( 'Folder is already a Git repository', sLog, False );
  Assert.AreEqual( sHead, FSandbox.RevParse( sRepo, 'HEAD' ), False, 'and it is left as it was' );

end;

procedure TTestNewRepository.AddRemoteOriginAddsTheRemote;
var
  sLog: string;
begin

  var sBare := FSandbox.InitBare( 'origin.git' );
  var sRepo := FSandbox.InitRepo( 'project' );

  Assert.IsTrue( FManager.AddRemoteOrigin( sRepo, sBare, sLog ), sLog );
  Assert.AreEqual( sBare, FSandbox.Git( sRepo, 'remote get-url origin' ), False );
  Assert.AreEqual( 'Added remote origin: ' + sBare, sLog, False );

  Assert.IsFalse( FManager.AddRemoteOrigin( sRepo, FSandbox.PathOf( 'another.git' ), sLog ), 'a second origin' );
  Assert.StartsWith( 'Failed to add remote origin: ', sLog, False );
  Assert.AreEqual( sBare, FSandbox.Git( sRepo, 'remote get-url origin' ), False, 'the first origin stands' );

end;

procedure TTestNewRepository.InitialCommitAndPushPublishesTheFolder;
const
  MESSAGE = 'Initial commit of "the project"';
var
  sLog: string;
begin

  var sBare := FSandbox.InitBare( 'origin.git' );
  var sRepo := FSandbox.MakeFolder( 'project' );

  FSandbox.Git( sRepo, 'init -b main' );
  FSandbox.SetIdentity( sRepo );
  FSandbox.WriteText( sRepo, 'Unit1.pas', 'unit Unit1;' );
  FSandbox.WriteText( sRepo, 'docs\readme.md', 'read me' );
  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );

  Assert.IsTrue( FManager.InitialCommitAndPush( sRepo, MESSAGE, sLog ), sLog );

  Assert.AreEqual( FSandbox.RevParse( sRepo, 'HEAD' ), FSandbox.RevParse( sBare, 'main' ), False, 'the commit is on the origin' );
  Assert.AreEqual( MESSAGE, FSandbox.Git( sBare, 'log -1 --format=%s main' ), False );
  Assert.AreEqual( 'Unit1.pas' + #10 + 'docs/readme.md', FSandbox.Git( sBare, 'ls-tree -r --name-only main' ).Replace( #13#10, #10 ),
    False, 'every file was committed' );
  Assert.AreEqual( 'origin/main', FSandbox.Git( sRepo, 'rev-parse --abbrev-ref @{upstream}' ), False, 'and the branch tracks the origin' );
  Assert.IsTrue( sLog.EndsWith( 'Pushed to origin/main' ), sLog );

end;

procedure TTestNewRepository.InitialCommitOfAnEmptyFolderIsRefused;
var
  sLog, sOutput: string;
begin

  var sBare := FSandbox.InitBare( 'origin.git' );
  var sRepo := FSandbox.MakeFolder( 'empty-project' );

  FSandbox.Git( sRepo, 'init -b main' );
  FSandbox.SetIdentity( sRepo );
  FSandbox.Git( sRepo, Format( 'remote add origin "%s"', [ sBare ] ) );

  Assert.IsFalse( FManager.InitialCommitAndPush( sRepo, 'Nothing', sLog ), sLog );
  Assert.IsTrue( sLog.Contains( 'There is nothing to commit' ), sLog );
  Assert.IsFalse( FSandbox.TryGit( sBare, 'rev-parse --verify main', sOutput ), 'nothing reached the origin' );

end;

initialization

  TDUnitX.RegisterTestFixture( TTestNewRepository );
  TDUnitX.RegisterTestFixture( TTestRefreshStatus );
  TDUnitX.RegisterTestFixture( TTestArtefactFilter );
  TDUnitX.RegisterTestFixture( TTestProjectVersion );
  TDUnitX.RegisterTestFixture( TTestCommitAndPush );
  TDUnitX.RegisterTestFixture( TTestRemoteOperations );
  TDUnitX.RegisterTestFixture( TTestResolveConflicts );

end.
