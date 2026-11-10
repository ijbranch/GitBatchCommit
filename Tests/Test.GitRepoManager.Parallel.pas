(* GITLAK Software
  ***************************************************************************

    © 2026 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit test suite.

  Test.GitRepoManager.Parallel.pas - RefreshAllStatusParallel: every
  repository refreshed, the progress callback, cancellation, and a start from
  a pooled worker thread as the application does it.

  ***************************************************************************
*)

unit Test.GitRepoManager.Parallel;

interface

uses
  DUnitX.TestFramework,
  uGitRepoManager,
  Test.Support;

{$M+}

type
  /// <summary>
  ///   <c>RefreshAllStatusParallel</c> over several repositories.
  /// </summary>
  [TestFixture]
  TTestParallelRefresh = class
  private const
    /// <summary>
    ///   Repositories each test refreshes.
    /// </summary>
    REPO_COUNT = 6;

    /// <summary>
    ///   Longest the worker-thread test waits for the refresh to finish, in
    ///   milliseconds.  A healthy run takes a few seconds; only a deadlock
    ///   reaches this.
    /// </summary>
    DEADLOCK_TIMEOUT = 120000;
  private
    /// <summary>
    ///   The temporary folder of the running test.
    /// </summary>
    FSandbox: TGitSandbox;
    /// <summary>
    ///   The manager under test, on the sandbox's configuration file.
    /// </summary>
    FManager: TGitRepoManager;
    /// <summary>
    ///   Paths of the repositories made by <see cref="MakeStaleRepositories"/>.
    /// </summary>
    FRepos: TArray<string>;

    /// <summary>
    ///   Creates the repositories, adds them to the manager while clean, then
    ///   gives each an untracked file.  The manager's records therefore say
    ///   Clean until something refreshes them, and Modified afterwards.
    /// </summary>
    /// <exception cref="EGitSandbox">The arrangement failed, so the test cannot mean anything.</exception>
    procedure MakeStaleRepositories;

    /// <summary>
    ///   Counts the manager's repositories that hold a given status.
    /// </summary>
    /// <param name="eStatus">The status to count.</param>
    /// <returns>How many records have it.</returns>
    function CountWithStatus( const eStatus: TRepoStatus ): Integer;
  public
    /// <summary>
    ///   Creates the sandbox and the manager.
    /// </summary>
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Frees the manager and removes the sandbox.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Proves every repository ends refreshed and the callback fires exactly
    ///   once for each, with that repository's name.
    /// </summary>
    [Test]
    procedure EveryRepositoryIsRefreshedAndReportedOnce;

    /// <summary>
    ///   Proves it runs without either callback, and that an empty list is a
    ///   no-op.
    /// </summary>
    [Test]
    procedure CallbacksAreOptional;

    /// <summary>
    ///   Proves a cancel probe that answers True from the start stops the
    ///   refresh before any repository is touched or reported.
    /// </summary>
    [Test]
    procedure CancelledFromTheStartRefreshesNothing;

    /// <summary>
    ///   Proves cancellation part-way stops it early: the probe lets one item
    ///   through, so exactly one repository is refreshed and none is reported
    ///   as done.
    /// </summary>
    [Test]
    procedure CancelledPartWayStopsEarly;

    /// <summary>
    ///   Proves it does not deadlock when started from a pooled worker thread
    ///   ( Parallel.Async ) while the starting thread only pumps messages: the
    ///   OnTerminated handler fires within the timeout and every repository
    ///   is refreshed.
    /// </summary>
    [Test]
    procedure StartedFromAPooledWorkerItCompletes;
  end;

implementation

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections, System.Diagnostics,
  OtlTaskControl, OtlParallel;

{ TTestParallelRefresh }

procedure TTestParallelRefresh.Setup;
begin

  FSandbox := TGitSandbox.Create;
  FManager := FSandbox.NewManager;

end;

procedure TTestParallelRefresh.TearDown;
begin

  FreeAndNil( FManager );
  FreeAndNil( FSandbox );

end;

procedure TTestParallelRefresh.MakeStaleRepositories;
begin

  SetLength( FRepos, REPO_COUNT );

  for var iI := 0 to REPO_COUNT - 1 do
  begin
    FRepos[ iI ] := FSandbox.InitRepo( Format( 'repo-%d', [ iI + 1 ] ) );

    if ( not FManager.AddRepository( FRepos[ iI ] ) ) then
      raise EGitSandbox.CreateFmt( 'Arrangement failed: "%s" could not be added', [ FRepos[ iI ] ] );
  end;

  if CountWithStatus( rsClean ) <> REPO_COUNT then
    raise EGitSandbox.Create( 'Arrangement failed: every repository should start Clean' );

  for var sRepo in FRepos do
    FSandbox.WriteText( sRepo, 'new-work.pas', 'unit x;' );

end;

function TTestParallelRefresh.CountWithStatus( const eStatus: TRepoStatus ): Integer;
begin

  Result := 0;

  for var rRepo in FManager.SnapshotAll do
  begin
    if rRepo.Status = eStatus then
      Inc( Result );
  end;

end;

procedure TTestParallelRefresh.EveryRepositoryIsRefreshedAndReportedOnce;
begin

  MakeStaleRepositories;

  var oNames := TList<string>.Create;
  var oLock  := TCriticalSection.Create;

  try
    // The callback runs on worker threads, several at once.
    FManager.RefreshAllStatusParallel(
      procedure( sName: string )
      begin
        oLock.Enter;

        try
          oNames.Add( sName );
        finally
          oLock.Leave;
        end;
      end );

    Assert.AreEqual( REPO_COUNT, CountWithStatus( rsModified ), 'every repository was refreshed' );
    Assert.AreEqual( REPO_COUNT, Integer( oNames.Count ), 'one callback per repository' );

    oNames.Sort;

    for var iI := 0 to REPO_COUNT - 1 do
      Assert.AreEqual( Format( 'repo-%d', [ iI + 1 ] ), oNames[ iI ], False, 'each repository reported once, by name' );
  finally
    oLock.Free;
    oNames.Free;
  end;

end;

procedure TTestParallelRefresh.CallbacksAreOptional;
begin

  Assert.WillNotRaiseAny(
    procedure
    begin
      FManager.RefreshAllStatusParallel;
    end, 'an empty list' );

  MakeStaleRepositories;
  FManager.RefreshAllStatusParallel;

  Assert.AreEqual( REPO_COUNT, CountWithStatus( rsModified ) );

end;

procedure TTestParallelRefresh.CancelledFromTheStartRefreshesNothing;
begin

  MakeStaleRepositories;

  var iDone := 0;

  FManager.RefreshAllStatusParallel(
    procedure( sName: string )
    begin
      TInterlocked.Increment( iDone );
    end,
    function: Boolean
    begin
      Result := True;
    end );

  Assert.AreEqual( 0, iDone, 'no repository was reported done' );
  Assert.AreEqual( REPO_COUNT, CountWithStatus( rsClean ), 'and none was refreshed: the stale Clean records stand' );

end;

procedure TTestParallelRefresh.CancelledPartWayStopsEarly;
begin

  MakeStaleRepositories;

  var iDone   := 0;
  var iProbes := 0;

  // False for the very first probe only: one item gets past its "before"
  // check, and every probe after that - the other items' "before" checks and
  // this item's "after" check - answers cancelled.
  FManager.RefreshAllStatusParallel(
    procedure( sName: string )
    begin
      TInterlocked.Increment( iDone );
    end,
    function: Boolean
    begin
      Result := TInterlocked.Increment( iProbes ) > 1;
    end );

  Assert.AreEqual( 1, CountWithStatus( rsModified ), 'only the item already under way was refreshed' );
  Assert.AreEqual( REPO_COUNT - 1, CountWithStatus( rsClean ), 'the rest were abandoned' );
  Assert.AreEqual( 0, iDone, 'and nothing was reported done after the cancel' );
  Assert.AreEqual( REPO_COUNT + 1, iProbes, 'the probe was polled before every item and after the one that ran' );

end;

procedure TTestParallelRefresh.StartedFromAPooledWorkerItCompletes;
var
  rMsg: TMsg;
  hNone: THandle;
begin

  MakeStaleRepositories;

  hNone := 0;

  var iDone        := 0;
  var bTerminated  := False;
  var iWorkerId    := TThreadID( 0 );
  var iTestThread  := TThread.CurrentThread.ThreadID;
  var oWorkerEnded := TEvent.Create( nil, True, False, '' );

  try
    Parallel.Async(
      procedure
      begin
        iWorkerId := TThread.CurrentThread.ThreadID;

        try
          FManager.RefreshAllStatusParallel(
            procedure( sName: string )
            begin
              TInterlocked.Increment( iDone );
            end );
        finally
          oWorkerEnded.SetEvent;
        end;
      end,
      Parallel.TaskConfig.OnTerminated(
        procedure( const ATask: IOmniTaskControl )
        begin
          bTerminated := True;
        end ) );

    // What the application's main thread does meanwhile: dispatch messages and
    // run queued calls.  OnTerminated arrives as a message to this thread.
    var rWatch := TStopwatch.StartNew;

    while ( not bTerminated ) and ( rWatch.ElapsedMilliseconds < DEADLOCK_TIMEOUT ) do
    begin
      MsgWaitForMultipleObjects( 0, hNone, False, 50, QS_ALLINPUT );

      while PeekMessage( rMsg, 0, 0, 0, PM_REMOVE ) do
      begin
        TranslateMessage( rMsg );
        DispatchMessage( rMsg );
      end;

      CheckSynchronize;
    end;

    Assert.IsTrue( oWorkerEnded.WaitFor( 0 ) = wrSignaled,
      Format( 'the refresh had not returned on the worker after %d ms: deadlock', [ rWatch.ElapsedMilliseconds ] ) );
    Assert.IsTrue( bTerminated, 'OnTerminated did not fire on the starting thread' );
    Assert.IsTrue( iTestThread <> iWorkerId, 'arrangement: the refresh ran on another thread' );
    Assert.AreEqual( REPO_COUNT, iDone, 'one callback per repository' );
    Assert.AreEqual( REPO_COUNT, CountWithStatus( rsModified ), 'every repository was refreshed' );
  finally
    // Never free the event, the sandbox or the manager under a worker that is
    // still running: if it has not ended, wait for it here.
    oWorkerEnded.WaitFor( DEADLOCK_TIMEOUT );
    oWorkerEnded.Free;
  end;

end;

initialization

  TDUnitX.RegisterTestFixture( TTestParallelRefresh );

end.
