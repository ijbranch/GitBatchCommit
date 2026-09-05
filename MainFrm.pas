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
  File last update : 2026-01-04T05:22:04.270+11:00
  Signature : d26f7f5526780a3160043a967157d5bbcb6ffafb
  ***************************************************************************
*)

(*
  MainFrm.pas - Main Form Unit

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.6.0

  Part of GitBatchCommit Application

  Description:
    Main form providing the user interface for managing multiple Git
    repositories and performing batch commit and push operations,
    including Codeberg repository creation.
*)

{
04/01/2026 - Fixed issue with Remove Selected option.
}

unit MainFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.CommCtrl,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.FileCtrl, Vcl.Menus,
  System.SysUtils, System.StrUtils, System.Variants, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Generics.Defaults,
  System.Threading, System.SyncObjs, System.IOUtils,
  VCL.StyledTaskDialog,
  uGitRepoManager, uNewRepositoryDialog, uCodebergSettings, uGitHubSettings, uTemplateSettings;

type
  /// <summary>
  ///   Main application form for Git Batch Commit utility.
  /// </summary>
  /// <remarks>
  ///   Provides UI for managing multiple Git repositories and performing
  ///   batch commit and push operations with a single commit message.
  /// </remarks>
  TMainForm = class( TForm )
    pnlTop: TPanel;
    pnlBottom: TPanel;
    pnlClient: TPanel;
    lvRepos: TListView;
    btnSelectModified: TButton;
    btnSelectAll: TButton;
    btnSelectNone: TButton;
    lblCommitMessage: TLabel;
    edtCommitMessage: TEdit;
    btnCommitPush: TButton;
    mmoLog: TMemo;
    splitter: TSplitter;
    MainMenu: TMainMenu;
    mnuFile: TMenuItem;
    mnuAddRepository: TMenuItem;
    mnuRemoveSelected: TMenuItem;
    mnuFileSep1: TMenuItem;
    mnuRefreshStatus: TMenuItem;
    mnuFileSep2: TMenuItem;
    mnuExit: TMenuItem;
    mnuCodeberg: TMenuItem;
    mnuInitPushCodeberg: TMenuItem;
    mnuMigrateToCodeberg: TMenuItem;
    mnuCodebergSep1: TMenuItem;
    mnuCodebergSettings: TMenuItem;
    mnuGitHub: TMenuItem;
    mnuInitPushGitHub: TMenuItem;
    mnuMigrateToGitHub: TMenuItem;
    mnuGitHubSep1: TMenuItem;
    mnuGitHubSettings: TMenuItem;
    mnuView: TMenuItem;
    mnuFilter: TMenuItem;
    mnuFilterAll: TMenuItem;
    mnuFilterClean: TMenuItem;
    mnuFilterModified: TMenuItem;
    mnuFilterPullRequired: TMenuItem;
    mnuFilterPushRequired: TMenuItem;
    mnuFilterDiverged: TMenuItem;
    mnuFilterConflicted: TMenuItem;
    mnuFilterError: TMenuItem;
    mnuHelp: TMenuItem;
    mnuHelpContents: TMenuItem;
    mnuHelpSep1: TMenuItem;
    mnuAbout: TMenuItem;
    pmRepos: TPopupMenu;
    pmSetPublic: TMenuItem;
    pmSetPrivate: TMenuItem;
    pmSep1: TMenuItem;
    pmEditGitignore: TMenuItem;
    pmFixGitignore: TMenuItem;
    pmSep2: TMenuItem;
    pmOpenInExplorer: TMenuItem;
    pmOpenInGitClient: TMenuItem;
    pmSep3: TMenuItem;
    pmPull: TMenuItem;
    pmSep4: TMenuItem;
    pmHistory: TPopupMenu;
    btnHistory: TButton;
    mnuSettings: TMenuItem;
    mnuFileSep3: TMenuItem;
    btnTemplates: TButton;
    pmTemplates: TPopupMenu;
    mnuTemplateSettings: TMenuItem;
    cboGroupFilter: TComboBox;
    lblGroupFilter: TLabel;
    pmSetGroup: TMenuItem;
    btnDetails: TButton;
    btnPullSelected: TButton;
    btnResolveConflicts: TButton;
    btnPushOnly: TButton;
    btnForcePush: TButton;
    pnlDetails: TPanel;
    lblDetails: TLabel;
    mmoDetails: TMemo;
    /// <summary>
    ///   Initialises form state and creates the repository manager.
    /// </summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>
    ///   Cancels every background worker, waits for them to finish, saves the
    ///   configuration and releases the objects this form owns.
    /// </summary>
    procedure FormDestroy( Sender: TObject );
    /// <summary>
    ///   Refuses to close while Git work is in flight, offering to cancel it
    ///   first.
    /// </summary>
    /// <param name="Sender">The form raising the event.</param>
    /// <param name="CanClose">Set False to keep the window open.</param>
    procedure FormCloseQuery( Sender: TObject; var CanClose: Boolean );
    /// <summary>
    ///   Posts the deferred load message the first time the form is shown, so the
    ///   repository list loads once the window is painted rather than blocking it.
    /// </summary>
    procedure FormShow( Sender: TObject );
    /// <summary>
    ///   Commits and pushes every checked repository that has modifications, using
    ///   the entered message, on a background thread.
    /// </summary>
    procedure btnCommitPushClick( Sender: TObject );
    /// <summary>
    ///   Ticks only the repositories whose status is Modified.
    /// </summary>
    procedure btnSelectModifiedClick( Sender: TObject );
    /// <summary>
    ///   Ticks every repository currently shown in the list.
    /// </summary>
    procedure btnSelectAllClick( Sender: TObject );
    /// <summary>
    ///   Clears the tick on every repository currently shown in the list.
    /// </summary>
    procedure btnSelectNoneClick( Sender: TObject );
    /// <summary>
    ///   Mirrors a row tick into the repository record, unless the list is being
    ///   updated programmatically.
    /// </summary>
    /// <param name="Item">The row whose checkbox changed.</param>
    procedure lvReposItemChecked( Sender: TObject; Item: TListItem );
    /// <summary>
    ///   Prompts for a folder and adds it to the managed repository list.
    /// </summary>
    procedure mnuAddRepositoryClick( Sender: TObject );
    /// <summary>
    ///   Removes every checked repository from the managed list.
    /// </summary>
    procedure mnuRemoveSelectedClick( Sender: TObject );
    /// <summary>
    ///   Starts an asynchronous refresh of every repository status.
    /// </summary>
    procedure mnuRefreshStatusClick( Sender: TObject );
    /// <summary>
    ///   Closes the application.
    /// </summary>
    procedure mnuExitClick( Sender: TObject );
    /// <summary>
    ///   Initialises the chosen folder as a Git repository and pushes it to a newly
    ///   created Codeberg repository.
    /// </summary>
    procedure mnuInitPushCodebergClick( Sender: TObject );
    /// <summary>
    ///   Opens the Codeberg credentials dialog.
    /// </summary>
    procedure mnuCodebergSettingsClick( Sender: TObject );
    /// <summary>
    ///   Initialises the chosen folder as a Git repository and pushes it to a newly
    ///   created GitHub repository.
    /// </summary>
    procedure mnuInitPushGitHubClick( Sender: TObject );
    /// <summary>
    ///   Opens the GitHub credentials dialog.
    /// </summary>
    procedure mnuGitHubSettingsClick( Sender: TObject );
    /// <summary>
    ///   Migrates the selected repository's remote to Codeberg.
    /// </summary>
    procedure mnuMigrateToCodebergClick( Sender: TObject );
    /// <summary>
    ///   Migrates the selected repository's remote to GitHub.
    /// </summary>
    procedure mnuMigrateToGitHubClick( Sender: TObject );
    /// <summary>
    ///   Applies the status filter chosen from the View menu and rebuilds the list.
    /// </summary>
    /// <param name="Sender">The filter menu item that was chosen; identifies the filter.</param>
    procedure mnuFilterClick( Sender: TObject );
    /// <summary>
    ///   Makes the selected repository public on its remote host.
    /// </summary>
    procedure pmSetPublicClick( Sender: TObject );
    /// <summary>
    ///   Makes the selected repository private on its remote host.
    /// </summary>
    procedure pmSetPrivateClick( Sender: TObject );
    /// <summary>
    ///   Enables or disables popup items according to the current selection, and
    ///   rebuilds the Set Group submenu from the groups currently in use.
    /// </summary>
    procedure pmReposPopup( Sender: TObject );
    /// <summary>
    ///   Opens the selected repository's .gitignore in the registered editor.
    /// </summary>
    procedure pmEditGitignoreClick( Sender: TObject );
    /// <summary>
    ///   Adds any missing standard Delphi ignore patterns to the selected
    ///   repository's .gitignore.
    /// </summary>
    procedure pmFixGitignoreClick( Sender: TObject );
    /// <summary>
    ///   Re-evaluates whether Commit & Push can be enabled.
    /// </summary>
    procedure edtCommitMessageChange( Sender: TObject );
    /// <summary>
    ///   Handles a click in the repository list, including shift-click range ticking
    ///   from the previously clicked row.
    /// </summary>
    procedure lvReposClick( Sender: TObject );
    /// <summary>
    ///   Opens the bundled documentation in the registered Markdown viewer.
    /// </summary>
    procedure mnuHelpContentsClick( Sender: TObject );
    /// <summary>
    ///   Shows the About box.
    /// </summary>
    procedure mnuAboutClick( Sender: TObject );
    /// <summary>
    ///   Colours each list row according to its repository status.
    /// </summary>
    procedure lvReposCustomDrawItem( Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean );
    /// <summary>
    ///   Opens the selected repository folder in Windows Explorer.
    /// </summary>
    procedure pmOpenInExplorerClick( Sender: TObject );
    /// <summary>
    ///   Opens the selected repository in the configured external Git client.
    /// </summary>
    procedure pmOpenInGitClientClick( Sender: TObject );
    /// <summary>
    ///   Pulls the selected repository, previewing the incoming changes and creating
    ///   a backup branch first.
    /// </summary>
    procedure pmPullClick( Sender: TObject );
    /// <summary>
    ///   Builds and drops down the commit-message history menu.
    /// </summary>
    procedure btnHistoryClick( Sender: TObject );
    /// <summary>
    ///   Opens the Settings dialog (Git client path, file pattern, indexer path).
    /// </summary>
    procedure mnuSettingsClick( Sender: TObject );
    /// <summary>
    ///   Builds and drops down the commit-message template menu.
    /// </summary>
    procedure btnTemplatesClick( Sender: TObject );
    /// <summary>
    ///   Opens the commit-message template maintenance dialog.
    /// </summary>
    procedure mnuTemplateSettingsClick( Sender: TObject );
    /// <summary>
    ///   Applies the group chosen in the filter combo and rebuilds the list.
    /// </summary>
    procedure cboGroupFilterChange( Sender: TObject );
    /// <summary>
    ///   Shows or hides the extended commit-message details panel.
    /// </summary>
    procedure btnDetailsClick( Sender: TObject );
    /// <summary>
    ///   Pulls every checked repository, previewing incoming changes and creating a
    ///   backup branch for each first.
    /// </summary>
    procedure btnPullSelectedClick( Sender: TObject );
    /// <summary>
    ///   Resolves an in-progress merge in every checked repository by keeping the
    ///   local version of each conflicted file, then commits and pushes.
    /// </summary>
    procedure btnResolveConflictsClick( Sender: TObject );
    /// <summary>
    ///   Pushes every checked repository without committing.
    /// </summary>
    procedure btnPushOnlyClick( Sender: TObject );
    /// <summary>
    ///   Force-pushes every checked repository, using --force-with-lease.
    /// </summary>
    procedure btnForcePushClick( Sender: TObject );
    /// <summary>
    ///   Adds Ctrl+A (select all) support to the log memo.
    /// </summary>
    /// <param name="Key">Virtual key code; set to 0 to swallow the keystroke.</param>
    /// <param name="Shift">Modifier keys held down.</param>
    procedure mmoLogKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );
  private
    const
      WM_LOAD_REPOS = WM_USER + 100;
      // A TColor literal is $00BBGGRR — blue, green, red — NOT $RRGGBB. Four of
      // these were written in RGB order and therefore painted a different
      // colour from the one their comment named: Modified rendered pale cyan,
      // Pull Required light blue, Push Required pale yellow and Diverged pink,
      // so Modified and Push Required were effectively transposed. Each value
      // below is now written as RGB( r, g, b ) so the intent and the paint
      // cannot drift apart again.
      clStatusClean = TColor( $00E0FFE0 );        // RGB( 224, 255, 224 ) light green
      clStatusModified = TColor( $00C0FFFF );     // RGB( 255, 255, 192 ) light yellow
      clStatusPullRequired = TColor( $00C0E0FF ); // RGB( 255, 224, 192 ) light orange
      clStatusError = TColor( $00C0C0FF );        // RGB( 255, 192, 192 ) light red
      clStatusConflicted = TColor( $008080FF );   // RGB( 255, 128, 128 ) stronger red
      clStatusPushRequired = TColor( $00C0FFC0 ); // RGB( 192, 255, 192 ) pale green
      clStatusDiverged = TColor( $00FFC0E0 );     // RGB( 224, 192, 255 ) light purple

      /// <summary>
      ///   Upper bound on the number of lines retained in the log memo. Oldest
      ///   lines are discarded beyond this; a batch across a large estate would
      ///   otherwise grow the memo without limit.
      /// </summary>
      MAX_LOG_LINES = 5000;

      /// <summary>
      ///   How long form teardown waits for background workers to finish
      ///   before giving up and closing anyway. Generous, because a worker may
      ///   be inside a Git call that has its own timeout to run down.
      /// </summary>
      WORKER_SHUTDOWN_TIMEOUT_MS = 90000;
    var
      FRepoManager  : TGitRepoManager;
      FUpdatingList : Boolean;
      FSortColumn   : Integer;
      FSortAscending: Boolean;
      FFilteredIndices: TList<Integer>;
      FStatusFilter : Integer;
      FInitialLoadDone: Boolean;
      FLastClickedIndex: Integer;
      FRefreshing   : Boolean;
      FCancelRefresh: Integer;
      FGroupFilter  : string;

      /// <summary>
      ///   Main-thread-owned copy of the repository list, refreshed from
      ///   <c>TGitRepoManager.SnapshotAll</c> whenever the view is rebuilt.
      /// </summary>
      /// <remarks>
      ///   Every list row's <c>Data</c> is an index into THIS array, and every
      ///   read the UI performs comes from here. The form must never touch the
      ///   manager's live array: <c>TRepoInfo</c> holds managed strings, and a
      ///   worker publishing a new <c>StatusText</c> while the UI copies the
      ///   old one frees the string out from under the reader.
      /// </remarks>
      FRepoCache    : TRepoInfoArray;

      /// <summary>
      ///   Set once the form has begun closing. Queued worker callbacks test it
      ///   before touching any control, because a callback that was already in
      ///   the synchronisation queue cannot be withdrawn — <c>RemoveQueuedEvents</c>
      ///   is a no-op for the <c>TThread.Queue( nil, … )</c> form these use.
      /// </summary>
      FShuttingDown : Boolean;

      /// <summary>
      ///   Count of background worker threads still running. Incremented and
      ///   decremented with TInterlocked so that FormDestroy can wait for ALL
      ///   of them, not only the status refresh — the commit/push and migrate
      ///   threads never touched FRefreshing, so closing the window mid-commit
      ///   used to free the repository manager out from under them.
      /// </summary>
      FActiveWorkers: Integer;

      /// <summary>
      ///   True while a commit/push batch is in flight. Blocks the commit
      ///   button from being re-enabled by an unrelated UI event ( typing in
      ///   the message box fires UpdateCommitButtonState ), which otherwise
      ///   allowed a second concurrent batch over the same repositories.
      /// </summary>
      FCommitting   : Boolean;

      /// <summary>
      ///   True while a synchronous batch loop is running. Because those loops
      ///   pump the message queue via Log, the user could otherwise re-enter
      ///   the same handler, or repopulate the list and invalidate the indices
      ///   the loop is walking.
      /// </summary>
      FBatchRunning : Boolean;

      /// <summary>
      ///   Set when PopulateListView is suppressed during a batch; the rebuild
      ///   is then performed once the batch finishes.
      /// </summary>
      FPopulatePending: Boolean;

      /// <summary>
      ///   Handles custom message to load repositories after form is visible.
      /// </summary>
    /// <param name="Msg">The posted WM_LOAD_REPOS message.</param>
    procedure WMLoadRepos( var Msg: TMessage ); message WM_USER + 100;

    /// <summary>
    ///   Refreshes all repositories asynchronously in background threads.
    /// </summary>
    procedure RefreshReposAsync;

    /// <summary>
    ///   Populates the list view with all repositories from the manager.
    /// </summary>
    procedure PopulateListView;

    /// <summary>
    ///   Updates a single list item with current repository data.
    /// </summary>
    /// <param name="iIndex">Index of the repository to update.</param>
    procedure UpdateListItem( const sRepoPath: string );

    /// <summary>
    ///   Appends a message to the log memo and scrolls to show it.
    /// </summary>
    /// <param name="sText">Text to append to the log.</param>
    procedure Log( const sText: string );

    /// <summary>
    ///   Scrolls the log memo to the end.
    /// </summary>
    procedure ScrollLogToEnd;

    /// <summary>
    ///   Handles WM_DROPFILES message for drag-and-drop support.
    /// </summary>
    /// <param name="Msg">The WM_DROPFILES message carrying the drop handle.</param>
    procedure WMDropFiles( var Msg: TWMDropFiles ); message WM_DROPFILES;

    /// <summary>
    ///   Handles column click for sorting.
    /// </summary>
    /// <param name="Sender">The list view raising the event.</param>
    /// <param name="Column">The column header that was clicked.</param>
    procedure lvReposColumnClick( Sender: TObject; Column: TListColumn );

    /// <summary>
    ///   Applies current filter and sort to the list.
    /// </summary>
    procedure ApplyFilterAndSort;

    /// <summary>
    ///   Sets the sort indicator arrow on column header.
    /// </summary>
    /// <param name="iColumn">Index of the column to mark, or -1 to clear all.</param>
    /// <param name="bAscending">True to draw an ascending arrow.</param>
    procedure SetColumnSortArrow( const iColumn: Integer; const bAscending: Boolean );

    /// <summary>
    ///   Updates the filter menu checkmarks.
    /// </summary>
    procedure UpdateFilterMenuChecks;

    /// <summary>
    ///   Updates the enabled state of the Commit & Push button.
    /// </summary>
    procedure UpdateCommitButtonState;

    /// <summary>
    ///   Builds the commit message history popup menu.
    /// </summary>
    procedure BuildHistoryMenu;

    /// <summary>
    ///   Handles click on a history menu item.
    /// </summary>
    /// <param name="Sender">The history menu item that was chosen.</param>
    procedure HistoryMenuItemClick( Sender: TObject );

    /// <summary>
    ///   Builds the commit message templates popup menu.
    /// </summary>
    procedure BuildTemplatesMenu;

    /// <summary>
    ///   Handles click on a template menu item.
    /// </summary>
    /// <param name="Sender">The template menu item that was chosen.</param>
    procedure TemplateMenuItemClick( Sender: TObject );

    /// <summary>
    ///   Updates the group filter combo box with available groups.
    /// </summary>
    procedure UpdateGroupFilterCombo;

    /// <summary>
    ///   Handles click on a Set Group submenu item.
    /// </summary>
    /// <param name="Sender">The Set Group menu item that was chosen.</param>
    procedure SetGroupMenuItemClick( Sender: TObject );

    /// <summary>
    ///   Writes a line to the log from ANY thread. Marshals to the UI thread
    ///   when called from a worker, so long-running work no longer has to be
    ///   dragged onto the main thread just to report progress.
    /// </summary>
    /// <param name="sText">Line to append to the log.</param>
    procedure LogSafe( const sText: string );

    /// <summary>
    ///   Queues one repository's commit log and list-row refresh onto the UI
    ///   thread.
    /// </summary>
    /// <remarks>
    ///   This exists to give each queued closure its OWN captured copy of the
    ///   log text and index. Delphi allocates a single closure capture frame
    ///   per ROUTINE, not per loop iteration, so a TThread.Queue closure
    ///   created inline in a for-loop shares one variable with every other
    ///   iteration — and because Queue is asynchronous, the worker overwrites
    ///   it before the UI thread reads it. The observed effect was every log
    ///   block being attributed to the NEXT repository, the first repository
    ///   never appearing at all, and UpdateListItem refreshing the wrong row.
    ///   Calling a method per iteration gives one frame per call.
    /// </remarks>
    /// <param name="ALog">Log text for this repository.</param>
    /// <param name="AIndex">Index of the repository whose row should refresh.</param>
    /// <summary>
    ///   Applies a newly discovered delphi-indexer path on the UI thread.
    /// </summary>
    /// <param name="APath">The resolved path to delphi-indexer.exe.</param>
    procedure QueueIndexerPathUpdate( const APath: string );

    procedure QueueCommitLog( const ALog, ARepoPath: string );

    /// <summary>
    ///   Copies the list view's checkbox states into the repository records.
    ///   The bulk select handlers suppress lvReposItemChecked ( the only other
    ///   writer ) via FUpdatingList, so without this their result is discarded
    ///   and the next repopulate silently clears every tick.
    /// </summary>
    procedure SyncCheckedStateToManager;

    /// <summary>
    ///   Re-reads <see cref="FRepoCache"/> from the manager under its lock.
    /// </summary>
    procedure RefreshRepoCache;

    /// <summary>
    ///   Returns a cached repository record by row index, bounds-checked.
    /// </summary>
    /// <remarks>
    ///   Release builds have range checking off, so an unguarded
    ///   <c>FRepoCache[ i ]</c> on a stale index reads past the array and treats
    ///   whatever follows as string pointers. Every handler goes through here.
    /// </remarks>
    /// <param name="iIndex">Index carried by the list row.</param>
    /// <param name="ARepo">Receives the cached record.</param>
    /// <returns>True if the index was in range.</returns>
    function RepoAt( const iIndex: Integer; out ARepo: TRepoInfo ): Boolean;

    /// <summary>
    ///   Returns the working-tree path of a cached repository, or an empty
    ///   string when the index is out of range.
    /// </summary>
    /// <param name="iIndex">Index carried by the list row.</param>
    /// <returns>The repository path, or empty.</returns>
    function RepoPathAt( const iIndex: Integer ): string;

    /// <summary>
    ///   Shows an error dialog with credentials masked.
    /// </summary>
    /// <remarks>
    ///   Git echoes the remote URL verbatim in most push and fetch errors, so a
    ///   remote of the form <c>https://user:token@host</c> puts a live
    ///   credential in the message. <c>Log</c> already redacted; the dialogs did
    ///   not — and the dialog is the window that gets screenshotted into a bug
    ///   report.
    /// </remarks>
    /// <param name="sMessage">The message to display.</param>
    /// <param name="DlgType">Dialog type; defaults to an error.</param>
    procedure ErrorDlg( const sMessage: string; const DlgType: TMsgDlgType = mtError );

    /// <summary>
    ///   Enables or disables every action that starts Git work.
    /// </summary>
    /// <remarks>
    ///   A boolean flag consulted by some handlers is not a guard. Disabling the
    ///   controls is, and it is what stops Force Push being clicked part-way
    ///   through a commit batch — two threads running Git in the same working
    ///   tree, which surfaces to the user as an <c>index.lock</c> failure.
    /// </remarks>
    /// <param name="bBusy">True while work is in flight.</param>
    procedure SetBatchUIState( const bBusy: Boolean );

    /// <summary>
    ///   Returns True when a batch, refresh or worker thread is still active.
    /// </summary>
    /// <returns>True if any Git work is in flight.</returns>
    function IsBusy: Boolean;

    /// <summary>
    ///   Takes the batch guard. Returns False ( and tells the user ) when a
    ///   batch is already running.
    /// </summary>
    /// <returns>True if the guard was taken; False if a batch is already running.</returns>
    function BeginBatch: Boolean;

    /// <summary>
    ///   Releases the batch guard and applies any list rebuild deferred while
    ///   it was held.
    /// </summary>
    procedure EndBatch;

    /// <summary>
    ///   Returns the repository indices of every checked row, resolved once so
    ///   that a batch loop never indexes a list view that has been rebuilt
    ///   underneath it.
    /// </summary>
    /// <returns>Repository indices for every checked row, resolved once.</returns>
    function CheckedRepoIndices: TArray<Integer>;

    /// <summary>
    ///   Executes a command and captures output.
    /// </summary>
    /// <param name="ACommand">Full command line to execute.</param>
    /// <param name="AOutput">Captured stdout/stderr output.</param>
    /// <param name="ATimeout">Timeout in milliseconds (default 30000 = 30s).</param>
    /// <returns>True if command executed successfully (exit code 0).</returns>
    function ExecuteCommand( const ACommand: string; out AOutput: string;
      const ATimeout: Cardinal = 30000 ): Boolean;

    /// <summary>
    ///   Runs delphi-indexer for all unique directories in the list.
    /// </summary>
    /// <param name="ADirs">StringList with entries in format 'category|path'</param>
    /// <remarks>
    ///   Captures output and logs success/failure with details.
    ///   Incremental indexing is fast (~100ms when nothing changed).
    /// </remarks>
    procedure RunPendingReindexes( const ADirs: TStringList );

    /// <summary>
    ///   Prompts the user to initialise a non-Git folder and push to a remote provider.
    /// </summary>
    /// <param name="sFolder">Path to the dropped folder.</param>
    /// <returns>True if the folder was initialised and added.</returns>
    function InitializeDroppedFolder( const sFolder: string ): Boolean;

    /// <summary>
    ///   Writes a .gitignore file appropriate for the given project type.
    /// </summary>
    /// <param name="sFolder">Folder to write the .gitignore into.</param>
    /// <param name="sProjectType">Project type whose template to use.</param>
    procedure WriteGitIgnoreForProjectType( const sFolder, sProjectType: string );

    /// <summary>
    ///   Handles form-level key events for keyboard shortcuts.
    /// </summary>
    /// <param name="Sender">The form raising the event.</param>
    /// <param name="Key">Virtual key code; set to 0 to swallow the keystroke.</param>
    /// <param name="Shift">Modifier keys held down.</param>
    procedure FormKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );

    /// <summary>
    ///   Migrates the currently selected repository's remote to the given provider.
    /// </summary>
    /// <param name="TargetProvider">Destination provider (rpCodeberg or rpGitHub).</param>
    procedure MigrateSelectedTo( const TargetProvider: TRemoteProvider );

    /// <summary>
    ///   Updates main-menu items whose enabled state depends on whether a
    ///   repository is currently selected in the list view.
    /// </summary>
    procedure UpdateMenuSelectionState;
  public
  end;

var
  MainForm          : TMainForm;

implementation

{$R *.dfm}

/// <summary>
///   Initialises the form and prepares for loading.
/// </summary>
procedure TMainForm.FormCreate( Sender: TObject );
begin

  FUpdatingList     := False;
  FSortColumn       := 0;
  FSortAscending    := True;
  FStatusFilter     := 0;
  FGroupFilter      := '';
  FInitialLoadDone  := False;
  FLastClickedIndex := -1;
  FCancelRefresh    := 0;
  FShuttingDown     := False;
  FActiveWorkers    := 0;
  FCommitting       := False;
  FBatchRunning     := False;
  FPopulatePending  := False;
  FFilteredIndices  := TList<Integer>.Create;
  FRepoManager      := TGitRepoManager.Create;

  // Enable drag-and-drop support
  DragAcceptFiles( Handle, True );

  // Enable Ctrl+Enter shortcut for Commit & Push
  KeyPreview        := True;
  OnKeyDown         := FormKeyDown;

  // Wire up column click event
  lvRepos.OnColumnClick := lvReposColumnClick;

  // Set initial filter menu state
  UpdateFilterMenuChecks;

  // Set initial button state (disabled until conditions met)
  UpdateCommitButtonState;

end;

/// <summary>
///   Posts a message to trigger loading after form is fully visible.
/// </summary>
procedure TMainForm.FormShow( Sender: TObject );
begin

  if FInitialLoadDone then
    Exit;

  FInitialLoadDone  := True;

  // Post message to load after form is fully painted
  PostMessage( Handle, WM_LOAD_REPOS, 0, 0 );

end;

/// <summary>
///   Loads configuration and refreshes repository status.
/// </summary>
procedure TMainForm.WMLoadRepos( var Msg: TMessage );
var
  iCount            : Integer;
begin

  Screen.Cursor     := crHourGlass;

  try
    mmoLog.Lines.Add( 'Loading configuration...' );
    ScrollLogToEnd;
    Update;

    if ( not FRepoManager.LoadConfig ) then
      mmoLog.Lines.Add( 'Warning: Failed to load configuration file' );

    // FRepoCache is the UI-side snapshot and is not filled until
    // PopulateListView below, so reading its length here saw 0 on a cold
    // start and silently skipped the initial refresh - every row drew with
    // no branch, no remote and 0/0 counts. Ask the manager for the live
    // count instead.
    iCount          := FRepoManager.ReposCount;
    mmoLog.Lines.Add( Format( 'Found %d repositories', [ iCount ] ) );
    ScrollLogToEnd;

    // Show list immediately with unknown status
    PopulateListView;
    UpdateGroupFilterCombo;
    SetColumnSortArrow( FSortColumn, FSortAscending );
    Update;

    mmoLog.Lines.Add( '' );
    mmoLog.Lines.Add( 'Ready. Drag and drop repository folders to add them.' );
    mmoLog.Lines.Add( 'Click column headers to sort. Use View > Filter to filter by status.' );
    ScrollLogToEnd;

    // Refresh repositories asynchronously to keep UI responsive
    if iCount > 0 then
      RefreshReposAsync;
  finally
    Screen.Cursor   := crDefault;
  end;

end;

/// <summary>
///   Refreshes all repositories asynchronously using parallel processing.
/// </summary>
procedure TMainForm.RefreshReposAsync;
var
  iCount            : Integer;
begin

  if IsBusy then
  begin
    Log( 'Another operation is already running - refresh skipped.' );
    Exit;
  end;

  iCount            := FRepoManager.ReposCount;

  if iCount = 0 then
    Exit;

  FRefreshing       := True;
  TInterlocked.Exchange( FCancelRefresh, 0 );
  Screen.Cursor     := crHourGlass;

  TInterlocked.Increment( FActiveWorkers );

  SetBatchUIState( True );

  var RefreshThread: TThread := TThread.CreateAnonymousThread(
    procedure
    begin

      try
        try
          // Delegate to the manager's own parallel refresh. The hand-rolled
          // TParallel.For that used to live here called RefreshStatus with a
          // raw index while Add/Remove could SetLength the array from the UI
          // thread — a reallocation there moves the array body out from under
          // the workers. RefreshAllStatusParallel snapshots under the lock and
          // writes back by matching on path.
          FRepoManager.RefreshAllStatusParallel(
            procedure( AName: string )
            begin
              LogSafe( Format( 'Checked %s', [ AName ] ) );
            end,
            function: Boolean
            begin
              Result := TInterlocked.CompareExchange( FCancelRefresh, 0, 0 ) <> 0;
            end );
        except
          on E: Exception do
          begin
            LogSafe( 'Refresh failed: ' + E.Message );
            ReRaiseIfDefect( E );
          end;
        end;

        TThread.Synchronize( nil,
          procedure
          begin

            FRefreshing := False;

            // The form may already be tearing down. A queued or synchronised
            // callback cannot be withdrawn - RemoveQueuedEvents is a no-op for
            // the TThread.Queue( nil, ... ) form used throughout - so every one
            // of them has to check for itself before touching a control.
            if FShuttingDown then
              Exit;

            SetBatchUIState( False );

            if TInterlocked.CompareExchange( FCancelRefresh, 0, 0 ) = 0 then
            begin
              Screen.Cursor := crDefault;
              PopulateListView;
              Log( 'Refresh complete.' );
            end;

          end );
      finally
        TInterlocked.Decrement( FActiveWorkers );
      end;

    end );
  RefreshThread.FreeOnTerminate := True;
  RefreshThread.Start;

end;

/// <summary>
///   Cleans up resources when the form is destroyed.
/// </summary>
procedure TMainForm.FormCloseQuery( Sender: TObject; var CanClose: Boolean );
begin

  CanClose := True;

  if ( not IsBusy ) then
    Exit;

  // Refuse to close while Git work is in flight, rather than closing and
  // hoping the wait in FormDestroy is long enough. It was not: RefreshStatus
  // issues up to six Git calls per repository, one of them a network fetch
  // with a 60-second timeout, so a single unreachable remote comfortably
  // outlasts the shutdown budget - and the old code then freed the manager
  // anyway, out from under a running worker.
  if StyledMessageDlg( 'Git operations are still running.' + sLineBreak + sLineBreak +
    'Cancel them and close once they have stopped?', mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
  begin
    CanClose := False;
    Exit;
  end;

  TInterlocked.Exchange( FCancelRefresh, 1 );
  Log( 'Cancelling background work...' );
  Screen.Cursor := crHourGlass;

  try
    // Cancellation is checked between repositories, so a drain normally takes
    // only as long as the Git call in flight. Bounded so a wedged network call
    // cannot lock the user out of their own window.
    var iWaited := 0;

    while ( TInterlocked.CompareExchange( FActiveWorkers, 0, 0 ) > 0 ) and
          ( iWaited < WORKER_SHUTDOWN_TIMEOUT_MS ) do
    begin
      CheckSynchronize( 10 );
      Sleep( 10 );
      Inc( iWaited, 20 );
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  CanClose := TInterlocked.CompareExchange( FActiveWorkers, 0, 0 ) = 0;

  if ( not CanClose ) then
    StyledMessageDlg( 'A Git operation has not stopped yet - it is probably waiting on a ' +
      'network timeout. Try closing again in a moment.', mtWarning, [ mbOK ], 0 );

end;

procedure TMainForm.FormDestroy( Sender: TObject );
begin

  // From here on, no queued callback may touch this form. RemoveQueuedEvents
  // cannot help: for the TThread.Queue( nil, ... ) form used throughout, both
  // overloads test the thread or method against nil and therefore remove
  // nothing at all. A flag each callback checks is the only thing that works.
  FShuttingDown     := True;
  TInterlocked.Exchange( FCancelRefresh, 1 );

  // FormCloseQuery already refuses to close while work is in flight, so
  // reaching here with workers running means shutdown was not user-initiated
  // (a Windows session end, or Application.Terminate). Wait, but bounded - an
  // unbounded wait here would hang the logoff.
  var iWaited       := 0;

  while ( TInterlocked.CompareExchange( FActiveWorkers, 0, 0 ) > 0 ) and
        ( iWaited < WORKER_SHUTDOWN_TIMEOUT_MS ) do
  begin
    // CheckSynchronize lets the workers' Synchronize/Queue calls complete so
    // they can actually finish, and Sleep keeps this off a 100% CPU spin.
    CheckSynchronize( 10 );
    Sleep( 10 );
    Inc( iWaited, 20 );
  end;

  // Detach the handlers that read repository state before anything is freed. A
  // WM_PAINT dispatched between here and TCustomForm.Destroy would otherwise
  // reach the custom-draw handler with a nil manager.
  lvRepos.OnCustomDrawItem := nil;
  lvRepos.OnItemChecked := nil;

  // Bring the records in step with the ticked rows before the final save.
  // NOTE: tick state is intentionally NOT persisted across sessions - the app
  // should never reopen with repositories pre-armed for a Commit & Push.
  if Assigned( FRepoManager ) then
  begin
    SyncCheckedStateToManager;
    FRepoManager.SaveConfig;

    // Only free the manager once nothing can still be inside it. If a worker
    // is somehow still running, LEAK IT DELIBERATELY: the process is going
    // away regardless, and freeing it here would put an access violation on a
    // freed critical section in front of the user on their way out. The old
    // code freed unconditionally after a capped wait, which is exactly that
    // crash.
    if TInterlocked.CompareExchange( FActiveWorkers, 0, 0 ) = 0 then
      FreeAndNil( FRepoManager )
    else
    begin
      OutputDebugString( PChar( 'GitBatchCommit: worker still running at shutdown - ' +
        'the repository manager was leaked deliberately rather than freed under it.' ) );
      FRepoManager := nil;
    end;
  end;

  SetLength( FRepoCache, 0 );
  FreeAndNil( FFilteredIndices );

end;

procedure TMainForm.RefreshRepoCache;
begin

  if Assigned( FRepoManager ) then
    FRepoCache := FRepoManager.SnapshotAll
  else
    SetLength( FRepoCache, 0 );

end;

function TMainForm.RepoAt( const iIndex: Integer; out ARepo: TRepoInfo ): Boolean;
begin

  Result := ( iIndex >= 0 ) and ( iIndex <= High( FRepoCache ) );

  if Result then
    ARepo := FRepoCache[ iIndex ];

end;

function TMainForm.RepoPathAt( const iIndex: Integer ): string;
begin

  Result := '';

  if ( iIndex >= 0 ) and ( iIndex <= High( FRepoCache ) ) then
    Result := FRepoCache[ iIndex ].Path;

end;

procedure TMainForm.ErrorDlg( const sMessage: string; const DlgType: TMsgDlgType );
begin

  StyledMessageDlg( RedactSecrets( sMessage ), DlgType, [ mbOK ], 0 );

end;

function TMainForm.IsBusy: Boolean;
begin

  Result := FRefreshing or FCommitting or FBatchRunning or
    ( TInterlocked.CompareExchange( FActiveWorkers, 0, 0 ) > 0 );

end;

procedure TMainForm.SetBatchUIState( const bBusy: Boolean );
begin

  if FShuttingDown then
    Exit;

  btnPullSelected.Enabled     := not bBusy;
  btnResolveConflicts.Enabled := not bBusy;
  btnPushOnly.Enabled         := not bBusy;
  btnForcePush.Enabled        := not bBusy;
  btnSelectModified.Enabled   := not bBusy;
  btnSelectAll.Enabled        := not bBusy;
  btnSelectNone.Enabled       := not bBusy;
  mnuAddRepository.Enabled    := not bBusy;
  mnuRemoveSelected.Enabled   := not bBusy;
  mnuRefreshStatus.Enabled    := not bBusy;
  mnuSettings.Enabled         := not bBusy;
  pmRepos.AutoPopup           := not bBusy;

  if bBusy then
    btnCommitPush.Enabled := False
  else
    UpdateCommitButtonState;

end;

/// <summary>
///   Updates the filter menu checkmarks.
/// </summary>
procedure TMainForm.UpdateFilterMenuChecks;
begin

  mnuFilterAll.Checked := ( FStatusFilter = 0 );
  mnuFilterClean.Checked := ( FStatusFilter = 1 );
  mnuFilterModified.Checked := ( FStatusFilter = 2 );
  mnuFilterPullRequired.Checked := ( FStatusFilter = 3 );
  mnuFilterError.Checked := ( FStatusFilter = 4 );
  mnuFilterPushRequired.Checked := ( FStatusFilter = 5 );
  mnuFilterDiverged.Checked := ( FStatusFilter = 6 );
  mnuFilterConflicted.Checked := ( FStatusFilter = 7 );

end;

/// <summary>
///   Updates the enabled state of the Commit & Push button.
/// </summary>
procedure TMainForm.UpdateCommitButtonState;
var
  lHasChecked       : Boolean;
  lHasMessage       : Boolean;
begin

  lHasChecked       := False;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ i ].Checked then
    begin
      lHasChecked   := True;
      Break;
    end;
  end;

  lHasMessage       := Trim( edtCommitMessage.Text ) <> '';

  // FCommitting keeps the button down for the whole batch. Without it, typing
  // a single character in the message box while a commit was running fired
  // this method, re-enabled the button, and let a second worker thread commit
  // and push the same repositories concurrently.
  btnCommitPush.Enabled := lHasChecked and lHasMessage and ( not FCommitting );

end;

/// <summary>
///   Handles the commit message edit change event.
/// </summary>
procedure TMainForm.edtCommitMessageChange( Sender: TObject );
begin

  UpdateCommitButtonState;

end;

/// <summary>
///   Handles list view click for shift-click range selection.
/// </summary>
procedure TMainForm.lvReposClick( Sender: TObject );
var
  iCurrentIndex     : Integer;
  iStartIndex       : Integer;
  iEndIndex         : Integer;
  lNewState         : Boolean;
begin

  if lvRepos.Selected = nil then
    Exit;

  iCurrentIndex     := lvRepos.Selected.Index;

  // Check if Shift is held and we have a previous click
  if ( GetKeyState( VK_SHIFT ) < 0 ) and ( FLastClickedIndex >= 0 ) and
    ( FLastClickedIndex <> iCurrentIndex ) then
  begin
    // Determine range
    if FLastClickedIndex < iCurrentIndex then
    begin
      iStartIndex   := FLastClickedIndex;
      iEndIndex     := iCurrentIndex;
    end
    else
    begin
      iStartIndex   := iCurrentIndex;
      iEndIndex     := FLastClickedIndex;
    end;

    // Use the opposite of the anchor item's state as the target
    lNewState       := not lvRepos.Items[ FLastClickedIndex ].Checked;

    FUpdatingList   := True;

    try
      for var i := iStartIndex to iEndIndex do
        lvRepos.Items[ i ].Checked := lNewState;
    finally
      FUpdatingList := False;
    end;

    SyncCheckedStateToManager;
    UpdateCommitButtonState;
  end
  else
  begin
    // Always update last clicked index (only when not shift-clicking)
    FLastClickedIndex := iCurrentIndex;
  end;

  UpdateMenuSelectionState;

end;

/// <summary>
///   Handles filter menu item click.
/// </summary>
procedure TMainForm.mnuFilterClick( Sender: TObject );
begin

  if Sender = mnuFilterAll then
    FStatusFilter   := 0
  else if Sender = mnuFilterClean then
    FStatusFilter   := 1
  else if Sender = mnuFilterModified then
    FStatusFilter   := 2
  else if Sender = mnuFilterPullRequired then
    FStatusFilter   := 3
  else if Sender = mnuFilterPushRequired then
    FStatusFilter   := 5
  else if Sender = mnuFilterDiverged then
    FStatusFilter   := 6
  else if Sender = mnuFilterConflicted then
    FStatusFilter   := 7
  else if Sender = mnuFilterError then
    FStatusFilter   := 4;

  UpdateFilterMenuChecks;
  PopulateListView;

end;

/// <summary>
///   Handles column click for sorting.
/// </summary>
procedure TMainForm.lvReposColumnClick( Sender: TObject; Column: TListColumn );
begin

  if FSortColumn = Column.Index then
    FSortAscending  := not FSortAscending
  else
  begin
    FSortColumn     := Column.Index;
    FSortAscending  := True;
  end;

  SetColumnSortArrow( FSortColumn, FSortAscending );
  PopulateListView;

end;

/// <summary>
///   Sets the sort indicator arrow on column header.
/// </summary>
procedure TMainForm.SetColumnSortArrow( const iColumn: Integer; const bAscending: Boolean );
var
  Header            : HWND;
  Item              : THDItem;
begin

  Header            := ListView_GetHeader( lvRepos.Handle );

  // Clear all arrows first
  for var i := 0 to lvRepos.Columns.Count - 1 do
  begin
    ZeroMemory( @Item, SizeOf( Item ) );
    Item.Mask       := HDI_FORMAT;
    Header_GetItem( Header, i, Item );
    Item.fmt        := Item.fmt and not ( HDF_SORTDOWN or HDF_SORTUP );
    Header_SetItem( Header, i, Item );
  end;

  // Set arrow on current column
  if iColumn >= 0 then
  begin
    ZeroMemory( @Item, SizeOf( Item ) );
    Item.Mask       := HDI_FORMAT;
    Header_GetItem( Header, iColumn, Item );

    if bAscending then
      Item.fmt      := Item.fmt or HDF_SORTUP
    else
      Item.fmt      := Item.fmt or HDF_SORTDOWN;

    Header_SetItem( Header, iColumn, Item );
  end;

end;

/// <summary>
///   Applies current filter and sort to the list.
/// </summary>
procedure TMainForm.ApplyFilterAndSort;
var
  FilterStatus      : TRepoStatus;
begin

  // One locked copy per rebuild. Every read below - the filter, the sort
  // comparer and PopulateListView's row fill - works from this array, so the
  // manager's live records are never touched from the UI thread.
  RefreshRepoCache;

  FFilteredIndices.Clear;

  // Apply filter
  for var i := 0 to High( FRepoCache ) do
  begin
    // Apply group filter first
    // Case-insensitive: groups are free text from InputQuery, so 'Delphi' and
    // 'delphi' would otherwise be two different groups.
    if ( FGroupFilter <> '' ) and ( not SameText( FRepoCache[ i ].Group, FGroupFilter ) ) then
      Continue;

    // Apply status filter
    if FStatusFilter = 0 then
      FFilteredIndices.Add( i )
    else
    begin
      case FStatusFilter of
        1: FilterStatus := rsClean;
        2: FilterStatus := rsModified;
        3: FilterStatus := rsPullRequired;
        4: FilterStatus := rsError;
        5: FilterStatus := rsPushRequired;
        6: FilterStatus := rsDiverged;
        7: FilterStatus := rsConflicted;
      else
        FilterStatus := rsUnknown;
      end;

      if FRepoCache[ i ].Status = FilterStatus then
        FFilteredIndices.Add( i );
    end;
  end;

  // Apply sort
  if FSortColumn >= 0 then
  begin
    FFilteredIndices.Sort( TComparer<Integer>.Construct(
        function( const A, B: Integer ): Integer
        var
          sValA, sValB: string;
          iValA, iValB: Integer;
        begin
          // Handle numeric columns separately
          if FSortColumn in [ 4, 5 ] then
          begin
            case FSortColumn of
              4:
                begin
                  iValA := FRepoCache[ A ].TrackedFileCount;
                  iValB := FRepoCache[ B ].TrackedFileCount;
                end;
              5:
                begin
                  iValA := FRepoCache[ A ].ModifiedFileCount;
                  iValB := FRepoCache[ B ].ModifiedFileCount;
                end;
            else
              iValA := 0;
              iValB := 0;
            end;

            Result  := iValA - iValB;

            if ( not FSortAscending ) then
              Result := -Result;
          end
          else
          begin
            case FSortColumn of
              0:
                begin
                  sValA := FRepoCache[ A ].Name;
                  sValB := FRepoCache[ B ].Name;
                end;
              1:
                begin
                  sValA := FRepoCache[ A ].Path;
                  sValB := FRepoCache[ B ].Path;
                end;
              2:
                begin
                  sValA := FRepoCache[ A ].Branch;
                  sValB := FRepoCache[ B ].Branch;
                end;
              3:
                begin
                  sValA := RemoteProviderToString( FRepoCache[ A ].Provider );
                  sValB := RemoteProviderToString( FRepoCache[ B ].Provider );
                end;
              6:
                begin
                  sValA := FRepoCache[ A ].StatusText;
                  sValB := FRepoCache[ B ].StatusText;
                end;
              7:
                begin
                  sValA := FRepoCache[ A ].Version;
                  sValB := FRepoCache[ B ].Version;
                end;
            else
              sValA := '';
              sValB := '';
            end;

            Result  := CompareText( sValA, sValB );

            if ( not FSortAscending ) then
              Result := -Result;
          end;
        end
        ) );
  end;

end;

/// <summary>
///   Scrolls the log memo to the end.
/// </summary>
procedure TMainForm.ScrollLogToEnd;
begin

  // EM_LINESCROLL by the line count is O(1). Reading mmoLog.Text to find the
  // caret position concatenates every line in the memo, which made logging a
  // large batch quadratic.
  mmoLog.Perform( EM_LINESCROLL, 0, mmoLog.Lines.Count );

end;

/// <summary>
///   Handles WM_DROPFILES message for drag-and-drop support.
/// </summary>
procedure TMainForm.WMDropFiles( var Msg: TWMDropFiles );
var
  iFileCount        : Integer;
  iAdded            : Integer;
  iSkipped          : Integer;
  iLen              : Integer;
  sPath             : string;
begin

  iAdded            := 0;
  iSkipped          := 0;

  try
    iFileCount      := DragQueryFile( Msg.Drop, $FFFFFFFF, nil, 0 );

    for var i := 0 to iFileCount - 1 do
    begin
      iLen          := DragQueryFile( Msg.Drop, i, nil, 0 );
      SetLength( sPath, iLen );
      DragQueryFile( Msg.Drop, i, PChar( sPath ), iLen + 1 );

      // Only process directories
      if ( not System.SysUtils.DirectoryExists( sPath ) ) then
      begin
        Inc( iSkipped );
        Continue;
      end;

      // Check if it's a valid Git repository
      if ( not System.SysUtils.DirectoryExists( TPath.Combine( sPath, '.git' ) ) ) then
      begin
        // Offer to initialise as a new Git repo
        if InitializeDroppedFolder( sPath ) then
          Inc( iAdded )
        else
          Inc( iSkipped );

        Continue;
      end;

      // Add the repository
      FRepoManager.AddRepository( sPath );
      Log( Format( 'Added repository: %s', [ sPath ] ) );
      Inc( iAdded );
    end;

    if iAdded > 0 then
      PopulateListView;

    if ( iAdded > 0 ) or ( iSkipped > 0 ) then
      Log( Format( 'Drop complete: %d added, %d skipped', [ iAdded, iSkipped ] ) );
  finally
    DragFinish( Msg.Drop );
  end;

  Msg.Result        := 0;

end;

/// <summary>
///   Populates the list view with all repositories from the manager.
/// </summary>
procedure TMainForm.PopulateListView;
var
  iRepoIndex        : Integer;
begin

  // A rebuild during a batch would invalidate the row indices the batch is
  // working through; defer it to EndBatch instead. Batches now address
  // repositories by path, so this is about the VIEW staying stable rather than
  // about correctness.
  if FBatchRunning then
  begin
    FPopulatePending := True;
    Exit;
  end;

  // Every row is about to be destroyed, so the shift-click anchor — a ROW
  // index, not a repository index — is no longer meaningful. Leaving it set
  // made a shift-click after any filter change index past the end of a
  // shortened list.
  FLastClickedIndex := -1;

  FUpdatingList     := True;

  try
    ApplyFilterAndSort;

    lvRepos.Items.BeginUpdate;

    try
      lvRepos.Items.Clear;

      for var i := 0 to FFilteredIndices.Count - 1 do
      begin
        iRepoIndex  := FFilteredIndices[ i ];
        var Item    := lvRepos.Items.Add;
        Item.Caption := FRepoCache[ iRepoIndex ].Name;
        Item.SubItems.Add( FRepoCache[ iRepoIndex ].Path );
        Item.SubItems.Add( FRepoCache[ iRepoIndex ].Branch );
        Item.SubItems.Add( RemoteProviderToString( FRepoCache[ iRepoIndex ].Provider ) );
        Item.SubItems.Add( IntToStr( FRepoCache[ iRepoIndex ].TrackedFileCount ) );
        Item.SubItems.Add( IntToStr( FRepoCache[ iRepoIndex ].ModifiedFileCount ) );
        Item.SubItems.Add( FRepoCache[ iRepoIndex ].StatusText );
        Item.SubItems.Add( FRepoCache[ iRepoIndex ].Version );
        Item.Checked := FRepoCache[ iRepoIndex ].Selected;
        Item.Data   := Pointer( iRepoIndex );
      end;
    finally
      lvRepos.Items.EndUpdate;
    end;

    UpdateCommitButtonState;
    UpdateMenuSelectionState;
  finally
    FUpdatingList   := False;
  end;

end;

/// <summary>
///   Updates a single list item with current repository data.
/// </summary>
procedure TMainForm.UpdateListItem( const sRepoPath: string );
var
  Repo              : TRepoInfo;
begin

  if sRepoPath.IsEmpty or ( not Assigned( FRepoManager ) ) then
    Exit;

  // Take the current record from the manager, under its lock, and refresh the
  // cached copy with it. Addressing the row by PATH means a list that has been
  // rebuilt, filtered or shortened since the work started still updates the
  // right row - or none at all, which is also correct.
  if ( not FRepoManager.GetRepoSnapshotByPath( sRepoPath, Repo ) ) then
    Exit;

  for var iI := 0 to lvRepos.Items.Count - 1 do
  begin
    var iRepoIndex := Integer( lvRepos.Items[ iI ].Data );

    if ( iRepoIndex < 0 ) or ( iRepoIndex > High( FRepoCache ) ) then
      Continue;

    if ( not SameText( FRepoCache[ iRepoIndex ].Path, sRepoPath ) ) then
      Continue;

    FRepoCache[ iRepoIndex ] := Repo;
    FUpdatingList := True;

    try
      var Item    := lvRepos.Items[ iI ];
      Item.Caption := Repo.Name;
      Item.SubItems[ 0 ] := Repo.Path;
      Item.SubItems[ 1 ] := Repo.Branch;
      Item.SubItems[ 2 ] := RemoteProviderToString( Repo.Provider );
      Item.SubItems[ 3 ] := IntToStr( Repo.TrackedFileCount );
      Item.SubItems[ 4 ] := IntToStr( Repo.ModifiedFileCount );
      Item.SubItems[ 5 ] := Repo.StatusText;
      Item.SubItems[ 6 ] := Repo.Version;
      lvRepos.UpdateItems( iI, iI );
    finally
      FUpdatingList := False;
    end;

    Exit;
  end;

end;

/// <summary>
///   Appends a message to the log memo and scrolls to show it.
/// </summary>
procedure TMainForm.Log( const sText: string );
begin

  // Git echoes the remote URL verbatim in most push/fetch errors, so a remote
  // of the form https://user:token@host puts a live credential in the log —
  // which is selectable, and routinely pasted into bug reports.
  mmoLog.Lines.Add( RedactSecrets( sText ) );

  // Keep the memo bounded; an unbounded log over a large estate is both a
  // memory leak in practice and progressively slower to append to.
  while mmoLog.Lines.Count > MAX_LOG_LINES do
    mmoLog.Lines.Delete( 0 );

  ScrollLogToEnd;

  // Application.ProcessMessages was called here on EVERY logged line. Log is
  // reached from worker threads through LogSafe and QueueCommitLog, so each
  // line pumped the message queue from inside a synchronisation callback and
  // re-entered arbitrary UI handlers while a batch was mid-flight. The batch
  // loops that genuinely want responsiveness pump explicitly; this one only
  // created re-entrancy.

end;

procedure TMainForm.LogSafe( const sText: string );
begin

  if TThread.CurrentThread.ThreadID = MainThreadID then
    Log( sText )
  else
    TThread.Queue( nil,
      procedure
      begin
        if FShuttingDown then
          Exit;

        Log( sText );
      end );

end;

procedure TMainForm.QueueIndexerPathUpdate( const APath: string );
begin

  // RunPendingReindexes executes on the COMMIT WORKER thread, and this both
  // writes a plain string field on the manager and persists the config. Both
  // belong on the UI thread, which owns the settings.
  TThread.Queue( nil,
    procedure
    begin
      if FShuttingDown or ( not Assigned( FRepoManager ) ) then
        Exit;

      FRepoManager.DelphiIndexerPath := APath;
      FRepoManager.SaveConfig;
    end );

end;

procedure TMainForm.QueueCommitLog( const ALog, ARepoPath: string );
begin

  TThread.Queue( nil,
    procedure
    begin
      // This closure may run after the form has begun tearing down: the
      // TThread.Queue( nil, ... ) form cannot be withdrawn, because both
      // RemoveQueuedEvents overloads match on a non-nil thread or method and
      // therefore remove nothing.
      if FShuttingDown then
        Exit;

      Log( ALog );
      UpdateListItem( ARepoPath );
    end );

end;

procedure TMainForm.SyncCheckedStateToManager;
var
  iIndex            : Integer;
begin

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    iIndex := Integer( lvRepos.Items[ i ].Data );

    if ( iIndex >= 0 ) and ( iIndex <= High( FRepoCache ) ) then
      FRepoManager.SetRepoSelected( FRepoCache[ iIndex ].Path, lvRepos.Items[ i ].Checked );
  end;

end;

function TMainForm.BeginBatch: Boolean;
begin

  // Gate on every kind of Git work, not just on another synchronous batch. A
  // commit batch runs on a worker thread and never set FBatchRunning, so Force
  // Push stayed clickable throughout it - two threads running Git in the same
  // working tree, which reaches the user as an index.lock failure.
  Result := ( not FBatchRunning ) and ( not FRefreshing ) and ( not FCommitting );

  if ( not Result ) then
  begin
    StyledMessageDlg( 'An operation is already running. Please wait for it to finish.',
      mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  FBatchRunning := True;
  FPopulatePending := False;

  // The flag alone is not a guard - it was only consulted by four of the
  // handlers that start Git work. Disabling the controls is.
  SetBatchUIState( True );

end;

procedure TMainForm.EndBatch;
begin

  FBatchRunning := False;

  if FShuttingDown then
    Exit;

  SetBatchUIState( False );

  if FPopulatePending then
  begin
    FPopulatePending := False;
    PopulateListView;
  end;

end;

function TMainForm.CheckedRepoIndices: TArray<Integer>;
var
  List              : TList<Integer>;
  iIndex            : Integer;
begin

  List := TList<Integer>.Create;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
      begin
        iIndex := Integer( lvRepos.Items[ i ].Data );

        if ( iIndex >= 0 ) and ( iIndex < FRepoManager.ReposCount ) then
          List.Add( iIndex );
      end;
    end;

    Result := List.ToArray;
  finally
    List.Free;
  end;

end;

/// <summary>
///   Handles the File > Add Repository menu click.
/// </summary>
procedure TMainForm.mnuAddRepositoryClick( Sender: TObject );
var
  sFolder           : string;
begin

  if SelectDirectory( 'Select Git Repository Folder', '', sFolder ) then
  begin
    if ( not System.SysUtils.DirectoryExists( TPath.Combine( sFolder, '.git' ) ) ) then
    begin
      StyledMessageDlg( 'The selected folder is not a Git repository.', mtWarning, [ mbOK ], 0 );
      Exit;
    end;

    FRepoManager.AddRepository( sFolder );
    PopulateListView;
    Log( Format( 'Added repository: %s', [ sFolder ] ) );
  end;

end;

/// <summary>
///   Handles the File > Remove Selected menu click.
/// </summary>
procedure TMainForm.mnuRemoveSelectedClick( Sender: TObject );
var
  IndicesToRemove   : TList<Integer>;
  iRepoIndex        : Integer;
begin

  // Build list of checked repository indices
  IndicesToRemove   := TList<Integer>.Create;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
        IndicesToRemove.Add( Integer( lvRepos.Items[ i ].Data ) );
    end;

    if IndicesToRemove.Count = 0 then
    begin
      StyledMessageDlg( 'Please check one or more repositories to remove.', mtInformation, [ mbOK ], 0 );
      Exit;
    end;

    if StyledMessageDlg( Format( 'Remove %d repository(ies) from the list?', [ IndicesToRemove.Count ] ),
      mtConfirmation, [ mbYes, mbNo ], 0 ) = mrYes then
    begin
      // Sort descending so we remove from highest index first (avoids index shifting issues)
      IndicesToRemove.Sort( TComparer<Integer>.Construct(
          function( const A, B: Integer ): Integer
          begin
            Result  := B - A;
          end ) );

      for iRepoIndex in IndicesToRemove do
      begin
        Log( Format( 'Removed repository: %s', [ FRepoCache[ iRepoIndex ].Name ] ) );
        FRepoManager.RemoveRepository( RepoPathAt( iRepoIndex ) );
      end;

      PopulateListView;
    end;
  finally
    IndicesToRemove.Free;
  end;

end;

/// <summary>
///   Handles the File > Refresh Status menu click.
/// </summary>
procedure TMainForm.mnuRefreshStatusClick( Sender: TObject );
begin

  Log( Format( 'Refreshing %d repositories...', [ FRepoManager.ReposCount ] ) );
  RefreshReposAsync;

end;

/// <summary>
///   Handles the File > Exit menu click.
/// </summary>
procedure TMainForm.mnuExitClick( Sender: TObject );
begin

  Close;

end;

/// <summary>
///   Handles the Commit and Push Selected button click.
/// </summary>
procedure TMainForm.btnCommitPushClick( Sender: TObject );
var
  iRepoIndex        : Integer;
  sSummary          : string;
  sDetails          : string;
  sMessage          : string;
begin

  sSummary          := Trim( edtCommitMessage.Text );

  if sSummary.IsEmpty then
  begin
    StyledMessageDlg(  'Please enter a commit message.', mtWarning, [ mbOK ], 0 );
    edtCommitMessage.SetFocus;
    Exit;
  end;

  // Build full commit message with optional details
  sDetails          := Trim( mmoDetails.Text );

  if sDetails.IsEmpty then
    sMessage        := sSummary
  else
    sMessage        := sSummary + sLineBreak + sLineBreak + sDetails;

  // Collect the target repositories ONCE, as paths.
  //
  // This used to be two passes with a modal confirmation dialog in between,
  // filling a fixed-size array sized by the first pass and then iterating to
  // High( array ). A background refresh publishing a new status while that
  // dialog was open changed how many rows matched: fewer left trailing ZEROS
  // in the array, so the loop ran CommitAndPush on repository index 0 - the
  // wrong repository, with another repository's message - and more overran the
  // array, which Release builds do not range-check.
  //
  // Paths are also immune to the list shifting under a long batch, which
  // indices are not.
  var RepoPaths: TArray<string>;
  var Repo: TRepoInfo;

  SetLength( RepoPaths, 0 );

  for var iI := 0 to lvRepos.Items.Count - 1 do
  begin
    iRepoIndex      := Integer( lvRepos.Items[ iI ].Data );

    if lvRepos.Items[ iI ].Checked and RepoAt( iRepoIndex, Repo ) and
       ( Repo.Status = rsModified ) then
      RepoPaths := RepoPaths + [ Repo.Path ];
  end;

  var iCount        := Length( RepoPaths );

  if iCount = 0 then
  begin
    StyledMessageDlg( 'No modified repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg( Format( 'Commit and push %d repository(ies)?', [ iCount ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  Screen.Cursor     := crHourGlass;
  FCommitting       := True;
  SetBatchUIState( True );
  TInterlocked.Increment( FActiveWorkers );

  TThread.CreateAnonymousThread(
    procedure
    var
      iSuccess      : Integer;
      slReindexDirs : TStringList;
    begin

      iSuccess      := 0;
      slReindexDirs := TStringList.Create;

      try
        try
          for var iJ := 0 to High( RepoPaths ) do
          begin
            if TInterlocked.CompareExchange( FCancelRefresh, 0, 0 ) <> 0 then
            begin
              LogSafe( 'Commit batch cancelled.' );
              Break;
            end;

            var sRepoPath := RepoPaths[ iJ ];
            var sCommitLog: string;
            var bCommitSuccess := FRepoManager.CommitAndPush( sRepoPath, sMessage, sCommitLog );

            if bCommitSuccess then
            begin
              Inc( iSuccess );

              // Track repo path for reindexing (only if commit succeeded)
              if slReindexDirs.IndexOf( sRepoPath ) = -1 then
                slReindexDirs.Add( sRepoPath );
            end;

            // Via a method call, so this iteration's log and path get their
            // own capture frame — see QueueCommitLog's remarks.
            QueueCommitLog( sCommitLog, sRepoPath );
          end;

          LogSafe( Format( 'Completed: %d of %d successful.', [ iSuccess, iCount ] ) );

          // Reindexing runs HERE, on the worker thread, not inside a
          // Synchronize block. Each repository can take up to the command
          // timeout, so doing it on the UI thread froze the application for
          // the length of the whole batch.
          RunPendingReindexes( slReindexDirs );
        except
          on E: Exception do
          begin
            LogSafe( 'Error during commit: ' + E.Message );
            ReRaiseIfDefect( E );
          end;
        end;

        TThread.Synchronize( nil,
          procedure
          begin

            if FShuttingDown then
              Exit;

            Screen.Cursor := crDefault;
            FCommitting := False;
            EndBatch;
            SetBatchUIState( False );

            // Clear details after successful commit
            if iSuccess > 0 then
            begin
              mmoDetails.Clear;
              pnlDetails.Visible := False;
            end;

            StyledMessageDlg( Format( 'Completed: %d of %d successful.', [ iSuccess, iCount ] ), mtInformation, [ mbOK ], 0 );

          end );
      finally
        // Single owner, single release point. The previous shape freed this
        // list inside the Synchronize block AND again in the exception
        // handler, so anything raising after the first Free double-freed it.
        slReindexDirs.Free;
        TInterlocked.Decrement( FActiveWorkers );
      end;

    end ).Start;

end;

/// <summary>
///   Selects only repositories with modified status.
/// </summary>
procedure TMainForm.btnSelectModifiedClick( Sender: TObject );
var
  iRepoIndex        : Integer;
  Repo              : TRepoInfo;
begin

  FUpdatingList     := True;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      iRepoIndex    := Integer( lvRepos.Items[ i ].Data );
      lvRepos.Items[ i ].Checked := RepoAt( iRepoIndex, Repo ) and
        ( Repo.Status = rsModified );
    end;
  finally
    FUpdatingList   := False;
  end;

  // lvReposItemChecked is suppressed while FUpdatingList is set, so the
  // records must be brought up to date explicitly.
  SyncCheckedStateToManager;

  UpdateCommitButtonState;

end;

/// <summary>
///   Selects all repositories in the list.
/// </summary>
procedure TMainForm.btnSelectAllClick( Sender: TObject );
begin

  FUpdatingList     := True;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
      lvRepos.Items[ i ].Checked := True;
  finally
    FUpdatingList   := False;
  end;

  // lvReposItemChecked is suppressed while FUpdatingList is set, so the
  // records must be brought up to date explicitly.
  SyncCheckedStateToManager;

  UpdateCommitButtonState;

end;

/// <summary>
///   Deselects all repositories in the list.
/// </summary>
procedure TMainForm.btnSelectNoneClick( Sender: TObject );
begin

  FUpdatingList     := True;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
      lvRepos.Items[ i ].Checked := False;
  finally
    FUpdatingList   := False;
  end;

  // lvReposItemChecked is suppressed while FUpdatingList is set, so the
  // records must be brought up to date explicitly.
  SyncCheckedStateToManager;

  UpdateCommitButtonState;

end;

/// <summary>
///   Handles checkbox state changes in the repository list.
/// </summary>
procedure TMainForm.lvReposItemChecked( Sender: TObject; Item: TListItem );
var
  iIndex            : Integer;
begin

  if FUpdatingList then
    Exit;

  iIndex            := Integer( Item.Data );

  if ( iIndex >= 0 ) and ( iIndex <= High( FRepoCache ) ) then
    FRepoManager.SetRepoSelected( FRepoCache[ iIndex ].Path, Item.Checked );

  UpdateCommitButtonState;

end;

/// <summary>
///   Handles the Codeberg > Settings menu click.
/// </summary>
procedure TMainForm.mnuCodebergSettingsClick( Sender: TObject );
var
  sUsername, sToken : string;
begin

  sUsername         := FRepoManager.CodebergUsername;
  sToken            := FRepoManager.CodebergToken;

  if TCodebergSettingsDialog.Execute( sUsername, sToken ) then
  begin
    FRepoManager.CodebergUsername := sUsername;
    FRepoManager.CodebergToken := sToken;

    // Report what actually happened. SaveConfig's result was discarded and
    // "credentials updated" logged either way - including when DPAPI failed
    // and the token was deliberately NOT written.
    if FRepoManager.SaveConfig and FRepoManager.LastSaveError.IsEmpty then
      Log( 'Codeberg credentials updated.' )
    else
    begin
      Log( 'Codeberg credentials NOT fully saved: ' + FRepoManager.LastSaveError );
      ErrorDlg( FRepoManager.LastSaveError, mtWarning );
    end;
  end;

end;

/// <summary>
///   Handles the Codeberg > Initialize and Push menu click.
/// </summary>
procedure TMainForm.mnuInitPushCodebergClick( Sender: TObject );
var
  sFolder           : string;
  sRepoName         : string;
  sDescription      : string;
  lPrivate          : Boolean;
  sRemoteURL        : string;
  sError            : string;
  sLog              : string;
begin

  // Check credentials first
  if ( not FRepoManager.HasCodebergCredentials ) then
  begin
    StyledMessageDlg( 'Please configure Codeberg credentials first.', mtWarning, [ mbOK ], 0 );
    mnuCodebergSettingsClick( nil );

    if ( not FRepoManager.HasCodebergCredentials ) then
      Exit;
  end;

  // Select folder
  if ( not SelectDirectory( 'Select Folder to Initialize as Git Repository', '', sFolder ) ) then
    Exit;

  // Check if already a Git repository
  if System.SysUtils.DirectoryExists( TPath.Combine( sFolder, '.git' ) ) then
  begin
    StyledMessageDlg( 'The selected folder is already a Git repository.' + sLineBreak +
      'Use File > Add Repository instead.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  // Get repository details
  sRepoName         := SanitizeRepoName( ExtractFileName( ExcludeTrailingPathDelimiter( sFolder ) ) );
  sDescription      := '';
  lPrivate          := False;

  if ( not TNewRepositoryDialog.Execute( sRepoName, sDescription, lPrivate, 'Codeberg' ) ) then
    Exit;

  // Confirm operation
  if StyledMessageDlg( Format( 'This will:%s%s' +
      '1. Initialize Git repository in: %s%s' +
      '2. Create %s repository "%s" on Codeberg%s' +
      '3. Commit all files and push%s%s' +
      'Continue?',
      [ sLineBreak, sLineBreak, sFolder, sLineBreak, IfThen( lPrivate, 'private', 'public' ), sRepoName, sLineBreak, sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor     := crHourGlass;

  try
    // Step 1: Initialize local repository
    Log( '=== Initializing Local Repository ===' );

    if ( not FRepoManager.InitializeRepository( sFolder, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to initialize repository: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Step 2: Create Codeberg repository
    Log( '=== Creating Codeberg Repository ===' );

    if ( not FRepoManager.CreateCodebergRepository( sRepoName, sDescription, lPrivate, sRemoteURL, sError ) ) then
    begin
      Log( 'Error: ' + sError );
      ErrorDlg( 'Failed to create Codeberg repository: ' + sError );
      Exit;
    end;

    Log( 'Created repository: ' + sRemoteURL );

    // Step 3: Add remote origin
    Log( '=== Adding Remote Origin ===' );

    if ( not FRepoManager.AddRemoteOrigin( sFolder, sRemoteURL, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to add remote origin: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Step 4: Initial commit and push
    Log( '=== Initial Commit and Push ===' );

    if ( not FRepoManager.InitialCommitAndPush( sFolder, 'Initial commit', sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to commit and push: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Add to repository list
    FRepoManager.AddRepository( sFolder );
    PopulateListView;

    Log( '=== Complete ===' );
    Log( 'Repository URL: https://codeberg.org/' + FRepoManager.CodebergUsername + '/' + sRepoName );

    StyledMessageDlg(  'Repository created and pushed successfully!' + sLineBreak + sLineBreak +
      'URL: https://codeberg.org/' + FRepoManager.CodebergUsername + '/' + sRepoName,
      mtInformation, [ mbOK ], 0 );
  finally
    Screen.Cursor   := crDefault;
  end;

end;

/// <summary>
///   Handles the GitHub > Settings menu click.
/// </summary>
procedure TMainForm.mnuGitHubSettingsClick( Sender: TObject );
var
  sUsername, sToken : string;
begin

  sUsername         := FRepoManager.GitHubUsername;
  sToken            := FRepoManager.GitHubToken;

  if TGitHubSettingsDialog.Execute( sUsername, sToken ) then
  begin
    FRepoManager.GitHubUsername := sUsername;
    FRepoManager.GitHubToken := sToken;

    // Report what actually happened. SaveConfig's result was discarded and
    // "credentials updated" logged either way - including when DPAPI failed
    // and the token was deliberately NOT written.
    if FRepoManager.SaveConfig and FRepoManager.LastSaveError.IsEmpty then
      Log( 'GitHub credentials updated.' )
    else
    begin
      Log( 'GitHub credentials NOT fully saved: ' + FRepoManager.LastSaveError );
      ErrorDlg( FRepoManager.LastSaveError, mtWarning );
    end;
  end;

end;

/// <summary>
///   Handles the GitHub > Initialize and Push menu click.
/// </summary>
procedure TMainForm.mnuInitPushGitHubClick( Sender: TObject );
var
  sFolder           : string;
  sRepoName         : string;
  sDescription      : string;
  lPrivate          : Boolean;
  sRemoteURL        : string;
  sError            : string;
  sLog              : string;
begin

  // Check credentials first
  if ( not FRepoManager.HasGitHubCredentials ) then
  begin
    StyledMessageDlg(  'Please configure GitHub credentials first.', mtWarning, [ mbOK ], 0 );
    mnuGitHubSettingsClick( nil );

    if ( not FRepoManager.HasGitHubCredentials ) then
      Exit;
  end;

  // Select folder
  if ( not SelectDirectory( 'Select Folder to Initialize as Git Repository', '', sFolder ) ) then
    Exit;

  // Check if already a Git repository
  if System.SysUtils.DirectoryExists( TPath.Combine( sFolder, '.git' ) ) then
  begin
    StyledMessageDlg(  'The selected folder is already a Git repository.' + sLineBreak +
      'Use File > Add Repository instead.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  // Shared new-repository dialog; the host name gives it the right caption.
  sRepoName         := SanitizeRepoName( ExtractFileName( ExcludeTrailingPathDelimiter( sFolder ) ) );
  sDescription      := '';
  lPrivate          := False;

  if ( not TNewRepositoryDialog.Execute( sRepoName, sDescription, lPrivate, 'GitHub' ) ) then
    Exit;

  // Confirm operation
  if StyledMessageDlg(  Format( 'This will:%s%s' +
      '1. Initialize Git repository in: %s%s' +
      '2. Create %s repository "%s" on GitHub%s' +
      '3. Commit all files and push%s%s' +
      'Continue?',
      [ sLineBreak, sLineBreak,
        sFolder, sLineBreak,
        IfThen( lPrivate, 'private', 'public' ), sRepoName, sLineBreak,
        sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor     := crHourGlass;

  try
    // Step 1: Initialize local repository
    Log( '=== Initializing Local Repository ===' );

    if ( not FRepoManager.InitializeRepository( sFolder, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to initialize repository: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Step 2: Create GitHub repository
    Log( '=== Creating GitHub Repository ===' );

    if ( not FRepoManager.CreateGitHubRepository( sRepoName, sDescription, lPrivate, sRemoteURL, sError ) ) then
    begin
      Log( 'Error: ' + sError );
      ErrorDlg( 'Failed to create GitHub repository: ' + sError );
      Exit;
    end;

    Log( 'Created repository: ' + sRemoteURL );

    // Step 3: Add remote origin
    Log( '=== Adding Remote Origin ===' );

    if ( not FRepoManager.AddRemoteOrigin( sFolder, sRemoteURL, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to add remote origin: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Step 4: Initial commit and push
    Log( '=== Initial Commit and Push ===' );

    if ( not FRepoManager.InitialCommitAndPush( sFolder, 'Initial commit', sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to commit and push: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Add to repository list
    FRepoManager.AddRepository( sFolder );
    PopulateListView;

    Log( '=== Complete ===' );
    Log( 'Repository URL: https://github.com/' + FRepoManager.GitHubUsername + '/' + sRepoName );

    StyledMessageDlg(  'Repository created and pushed successfully!' + sLineBreak + sLineBreak +
      'URL: https://github.com/' + FRepoManager.GitHubUsername + '/' + sRepoName,
      mtInformation, [ mbOK ], 0 );
  finally
    Screen.Cursor   := crDefault;
  end;

end;

/// <summary>
///   Migrates the currently selected repository's remote to the specified provider.
///   Prompts the user for target-side repo name / description / visibility, then
///   creates the target repo, renames the old origin to its provider name, swaps
///   in the new origin and pushes all branches and tags.
/// </summary>
procedure TMainForm.MigrateSelectedTo( const TargetProvider: TRemoteProvider );
var
  iIndex            : Integer;
  Repo              : TRepoInfo;
  sTargetName       : string;
  sSourceName       : string;
  lTargetHasCreds   : Boolean;
  sRepoName         : string;
  sDescription      : string;
  lPrivate          : Boolean;
begin

  if lvRepos.Selected = nil then
  begin
    StyledMessageDlg(  'Please select a repository to migrate.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex            := Integer( lvRepos.Selected.Data );

  if ( iIndex < 0 ) or ( iIndex > High( FRepoCache ) ) then
    Exit;

  Repo              := FRepoCache[ iIndex ];

  case TargetProvider of
    rpCodeberg:
      begin
        sTargetName := 'Codeberg';
        lTargetHasCreds := FRepoManager.HasCodebergCredentials;
      end;

    rpGitHub:
      begin
        sTargetName := 'GitHub';
        lTargetHasCreds := FRepoManager.HasGitHubCredentials;
      end;
  else
    Exit;
  end;

  // Prompt for credentials if not yet configured
  if ( not lTargetHasCreds ) then
  begin
    StyledMessageDlg(  'Please configure ' + sTargetName + ' credentials first.', mtWarning, [ mbOK ], 0 );

    if TargetProvider = rpCodeberg then
      mnuCodebergSettingsClick( nil )
    else
      mnuGitHubSettingsClick( nil );

    if TargetProvider = rpCodeberg then
      lTargetHasCreds := FRepoManager.HasCodebergCredentials
    else
      lTargetHasCreds := FRepoManager.HasGitHubCredentials;

    if ( not lTargetHasCreds ) then
      Exit;
  end;

  case Repo.Provider of
    rpCodeberg: sSourceName := 'Codeberg';
    rpGitHub: sSourceName := 'GitHub';
    rpOther: sSourceName := 'a third-party host';
    rpNone: sSourceName := '(no remote)';
  else
    sSourceName     := 'unknown';
  end;

  if Repo.Provider = TargetProvider then
  begin
    StyledMessageDlg(  Format( 'Repository "%s" is already hosted on %s.',
        [ Repo.Name, sTargetName ] ), mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  // Shared new-repository dialog; the TARGET host names it, so migrating to
  // GitHub no longer announces itself as creating a Codeberg repository.
  sRepoName         := SanitizeRepoName( Repo.Name );
  sDescription      := '';
  lPrivate          := False;

  if ( not TNewRepositoryDialog.Execute( sRepoName, sDescription, lPrivate, sTargetName ) ) then
    Exit;

  if StyledMessageDlg(  Format(
      'Migrate repository "%s" from %s to %s?%s%s' +
      'This will:%s' +
      '1. Create %s repository "%s" on %s%s' +
      '2. Preserve the existing origin as a secondary remote%s' +
      '3. Repoint origin to the new %s URL%s' +
      '4. Push all branches and tags to %s%s%s' +
      'The old remote repository is NOT deleted — remove it manually after verifying the migration.',
      [ Repo.Name, sSourceName, sTargetName, sLineBreak, sLineBreak,
        sLineBreak,
        IfThen( lPrivate, 'private', 'public' ), sRepoName, sTargetName, sLineBreak,
        sLineBreak,
        sTargetName, sLineBreak,
        sTargetName, sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor     := crHourGlass;
  Log( Format( '=== Migrating %s from %s to %s ===', [ Repo.Name, sSourceName, sTargetName ] ) );

  // Capture the PATH for the worker. An index would be meaningless by the time
  // a migration finishes: it does HTTP plus a full push, and the list can be
  // added to or filtered in the meantime.
  var sRepoPath     := Repo.Path;

  // Run the long-running network + push work off the UI thread so the app
  // stays responsive. Final UI updates are queued back to the main thread.
  SetBatchUIState( True );
  TInterlocked.Increment( FActiveWorkers );

  TThread.CreateAnonymousThread(
    procedure
    var
      lThreadOK     : Boolean;
      sThreadURL    : string;
      sThreadError  : string;
      sThreadLog    : string;
    begin

      // The worker-count decrement belongs in a finally on the WORKER, not
      // inside the queued UI closure it used to sit in. There it meant "a UI
      // callback is pending" rather than "a worker is running", and it was
      // skipped entirely if that closure raised - leaving the count stuck
      // above zero so every later shutdown waited for a worker that had
      // finished long ago.
      try
        // MigrateRepository does HTTP *and* Git; without this handler a dropped
        // connection escaped into TThread's FatalException and was discarded,
        // leaving no dialog, no log line, and the hourglass cursor stuck on for
        // the rest of the session.
        try
          lThreadOK   := FRepoManager.MigrateRepository( sRepoPath, TargetProvider,
            sRepoName, sDescription, lPrivate, sThreadURL, sThreadError, sThreadLog );
        except
          on E: Exception do
          begin
            lThreadOK := False;
            sThreadError := E.Message;
            sThreadLog := 'Migration aborted by an unexpected error. The remote may have been ' +
              'created and origin may already have been repointed - check `git remote -v` before retrying.';
          end;
        end;

        // Refresh on the WORKER. Doing it inside the queued closure ran six
        // blocking Git calls - one of them a network fetch - on the UI thread,
        // which is precisely the work this thread exists to move off it.
        if lThreadOK then
          FRepoManager.RefreshStatus( sRepoPath );

        TThread.Queue( nil,
          procedure
          begin

            if FShuttingDown then
              Exit;

            Screen.Cursor := crDefault;
            SetBatchUIState( False );

            if lThreadOK then
            begin
              Log( sThreadLog );
              Log( '=== Migration Complete ===' );
              Log( 'New URL: ' + sThreadURL );

              PopulateListView;

              StyledMessageDlg(  Format( 'Repository migrated to %s successfully.%s%sNew URL: %s%s%s' +
                  'The old remote still exists on %s — delete it via the web interface once you are satisfied.',
                  [ sTargetName, sLineBreak, sLineBreak, sThreadURL, sLineBreak, sLineBreak, sSourceName ] ),
                mtInformation, [ mbOK ], 0 );
            end
            else
            begin
              Log( sThreadLog );
              Log( 'Error: ' + sThreadError );
              ErrorDlg( 'Migration failed: ' + sThreadError );
            end;

          end );
      finally
        TInterlocked.Decrement( FActiveWorkers );
      end;

    end ).Start;

end;

/// <summary>
///   Handles the Codeberg > Migrate Selected Repository menu click.
/// </summary>
procedure TMainForm.mnuMigrateToCodebergClick( Sender: TObject );
begin

  MigrateSelectedTo( rpCodeberg );

end;

/// <summary>
///   Handles the GitHub > Migrate Selected Repository menu click.
/// </summary>
procedure TMainForm.mnuMigrateToGitHubClick( Sender: TObject );
begin

  MigrateSelectedTo( rpGitHub );

end;

/// <summary>
///   Handles the Set Public context menu click.
/// </summary>
procedure TMainForm.pmSetPublicClick( Sender: TObject );
var
  iIndex            : Integer;
  sError            : string;
  Provider          : TRemoteProvider;
  sProviderName     : string;
begin

  if lvRepos.Selected = nil then
  begin
    StyledMessageDlg(  'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex            := Integer( lvRepos.Selected.Data );
  Provider          := FRepoManager.GetRepoProvider( RepoPathAt( iIndex ) );

  case Provider of
    rpCodeberg: sProviderName := 'Codeberg';
    rpGitHub: sProviderName := 'GitHub';
    rpOther:
      begin
        StyledMessageDlg(  'Visibility change only supported for GitHub and Codeberg repositories.',
          mtWarning, [ mbOK ], 0 );
        Exit;
      end;
    rpNone:
      begin
        StyledMessageDlg(  'This repository has no remote origin configured.', mtWarning, [ mbOK ], 0 );
        Exit;
      end;
  end;

  if StyledMessageDlg(  Format( 'Make repository "%s" PUBLIC on %s?%s%s' +
      'This will make the repository visible to everyone.',
      [ FRepoCache[ iIndex ].Name, sProviderName, sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor     := crHourGlass;

  try
    if FRepoManager.SetRepositoryVisibility( RepoPathAt( iIndex ), False, sError ) then
    begin
      Log( Format( 'Repository "%s" set to PUBLIC on %s',
          [ FRepoCache[ iIndex ].Name, sProviderName ] ) );
      StyledMessageDlg(  'Repository visibility changed to PUBLIC.', mtInformation, [ mbOK ], 0 );
    end
    else
    begin
      Log( 'Error: ' + sError );
      ErrorDlg( 'Failed to change visibility: ' + sError );
    end;
  finally
    Screen.Cursor   := crDefault;
  end;

end;

/// <summary>
///   Handles the Set Private context menu click.
/// </summary>
procedure TMainForm.pmSetPrivateClick( Sender: TObject );
var
  iIndex            : Integer;
  sError            : string;
  Provider          : TRemoteProvider;
  sProviderName     : string;
begin

  if lvRepos.Selected = nil then
  begin
    StyledMessageDlg(  'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex            := Integer( lvRepos.Selected.Data );
  Provider          := FRepoManager.GetRepoProvider( RepoPathAt( iIndex ) );

  case Provider of
    rpCodeberg: sProviderName := 'Codeberg';
    rpGitHub: sProviderName := 'GitHub';
    rpOther:
      begin
        StyledMessageDlg(  'Visibility change only supported for GitHub and Codeberg repositories.',
          mtWarning, [ mbOK ], 0 );
        Exit;
      end;
    rpNone:
      begin
        StyledMessageDlg(  'This repository has no remote origin configured.', mtWarning, [ mbOK ], 0 );
        Exit;
      end;
  end;

  if StyledMessageDlg(  Format( 'Make repository "%s" PRIVATE on %s?%s%s' +
      'This will make the repository visible only to you.',
      [ FRepoCache[ iIndex ].Name, sProviderName, sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor     := crHourGlass;

  try
    if FRepoManager.SetRepositoryVisibility( RepoPathAt( iIndex ), True, sError ) then
    begin
      Log( Format( 'Repository "%s" set to PRIVATE on %s',
          [ FRepoCache[ iIndex ].Name, sProviderName ] ) );
      StyledMessageDlg(  'Repository visibility changed to PRIVATE.', mtInformation, [ mbOK ], 0 );
    end
    else
    begin
      Log( 'Error: ' + sError );
      ErrorDlg( 'Failed to change visibility: ' + sError );
    end;
  finally
    Screen.Cursor   := crDefault;
  end;

end;

/// <summary>
///   Handles the popup menu opening to enable/disable items.
/// </summary>
procedure TMainForm.UpdateMenuSelectionState;
var
  lHasSelection     : Boolean;
begin

  lHasSelection     := ( lvRepos.Selected <> nil );

  mnuRemoveSelected.Enabled := lHasSelection;
  mnuMigrateToCodeberg.Enabled := lHasSelection;
  mnuMigrateToGitHub.Enabled := lHasSelection;

end;

procedure TMainForm.pmReposPopup( Sender: TObject );
var
  Groups            : TArray<string>;
  MenuItem          : TMenuItem;
  SubMenu           : TMenuItem;
  lHasSelection     : Boolean;
begin

  lHasSelection     := ( lvRepos.Selected <> nil );

  // Enable per-repo items only when a single repository is selected
  pmEditGitignore.Enabled := lHasSelection;
  pmFixGitignore.Enabled := lHasSelection;
  pmSetPublic.Enabled := lHasSelection;
  pmSetPrivate.Enabled := lHasSelection;
  pmOpenInExplorer.Enabled := lHasSelection;
  pmOpenInGitClient.Enabled := lHasSelection;
  pmPull.Enabled    := lHasSelection;
  pmSetGroup.Enabled := lHasSelection;

  // Build the Set Group submenu
  pmSetGroup.Clear;

  Groups            := FRepoManager.GetAllGroups;

  // Add existing groups
  for var i := 0 to High( Groups ) do
  begin
    MenuItem        := TMenuItem.Create( pmSetGroup );
    MenuItem.Caption := Groups[ i ];
    MenuItem.Tag    := i;
    MenuItem.OnClick := SetGroupMenuItemClick;
    pmSetGroup.Add( MenuItem );
  end;

  // Add separator if there are groups
  if Length( Groups ) > 0 then
  begin
    SubMenu         := TMenuItem.Create( pmSetGroup );
    SubMenu.Caption := '-';
    pmSetGroup.Add( SubMenu );
  end;

  // Add "Clear Group" option
  MenuItem          := TMenuItem.Create( pmSetGroup );
  MenuItem.Caption  := '(Clear Group)';
  MenuItem.Tag      := -1;
  MenuItem.OnClick  := SetGroupMenuItemClick;
  pmSetGroup.Add( MenuItem );

  // Add "New Group..." option
  MenuItem          := TMenuItem.Create( pmSetGroup );
  MenuItem.Caption  := 'New Group...';
  MenuItem.Tag      := -2;
  MenuItem.OnClick  := SetGroupMenuItemClick;
  pmSetGroup.Add( MenuItem );

end;

/// <summary>
///   Handles the Edit .gitignore menu click.
/// </summary>
procedure TMainForm.pmEditGitignoreClick( Sender: TObject );
var
  iIndex            : Integer;
  sGitignorePath    : string;
  FileStream        : TFileStream;
begin

  if lvRepos.Selected = nil then
  begin
    StyledMessageDlg(  'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex            := Integer( lvRepos.Selected.Data );
  sGitignorePath    := IncludeTrailingPathDelimiter( FRepoCache[ iIndex ].Path ) + '.gitignore';

  // Check if .gitignore exists, offer to create if not
  if ( not FileExists( sGitignorePath ) ) then
  begin
    if StyledMessageDlg(  Format( 'No .gitignore file exists in "%s".%s%sCreate one now?',
        [ FRepoCache[ iIndex ].Name, sLineBreak, sLineBreak ] ),
      mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
      Exit;

    // Create empty .gitignore file
    try
      FileStream    := TFileStream.Create( sGitignorePath, fmCreate );
      try
        // File created empty
      finally
        FileStream.Free;
      end;

      Log( 'Created .gitignore in ' + FRepoCache[ iIndex ].Name );
    except
      // Narrowed from a bare Exception: an access violation here is a defect
      // in this application, and swallowing it reported the bug to the user as
      // a file error and hid it from EurekaLog entirely.
      on E: EStreamError do
      begin
        ErrorDlg( 'Failed to create .gitignore: ' + E.Message );
        Exit;
      end;
    end;
  end;

  // Open in default editor
  // A ShellExecute result of 32 or less is a failure code, not a window
  // handle. '.gitignore' very often has no registered handler, so this
  // silently did nothing at all.
  if ShellExecute( Handle, 'open', PChar( sGitignorePath ), nil, nil, SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not open .gitignore - no application is registered for this file type.' + sLineBreak +
      sLineBreak + sGitignorePath, mtWarning, [ mbOK ], 0 );

end;

/// <summary>
///   Handles the Fix .gitignore menu click - adds standard Delphi ignore patterns.
/// </summary>
procedure TMainForm.pmFixGitignoreClick( Sender: TObject );
const
  DELPHI_PATTERNS   : array[ 0..23 ] of string = (
    '# Delphi build artifacts',
    '*.dcu',
    '*.exe',
    '*.dll',
    '*.bpl',
    '*.dcp',
    '*.dres',
    '*.map',
    '*.drc',
    '*.rsm',
    '*.tds',
    '*.dof',
    '*.obj',
    '*.hpp',
    '*.o',
    '__history/',
    '__recovery/',
    '*.local',
    '*.identcache',
    '*.projdata',
    '*.tvsconfig',
    '*.dsk',
    'Win32/',
    'Win64/'
    );
var
  iIndex            : Integer;
  sGitignorePath    : string;
  slExisting        : TStringList;
  slToAdd           : TStringList;
  sPattern          : string;
  slExistingRules   : TStringList;
  iAddedCount       : Integer;
begin

  if lvRepos.Selected = nil then
  begin
    StyledMessageDlg(  'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex            := Integer( lvRepos.Selected.Data );
  sGitignorePath    := IncludeTrailingPathDelimiter( FRepoCache[ iIndex ].Path ) + '.gitignore';

  slExisting        := TStringList.Create;
  slToAdd           := TStringList.Create;
  slExistingRules   := TStringList.Create;

  try
    // Read existing .gitignore content
    if FileExists( sGitignorePath ) then
    begin
      try
        slExisting.LoadFromFile( sGitignorePath, TEncoding.UTF8 );
      except
        on E: EFileStreamError do
        begin
          ErrorDlg( 'Failed to read .gitignore: ' + E.Message );
          Exit;
        end;
      end;
    end;

    // Collect the existing rules as whole, trimmed, lower-cased LINES.
    //
    // The previous test was a substring search over the entire file, which
    // reported any pattern that merely appeared inside another as already
    // present: '*.o' is a substring of '*.obj', so once '*.obj' was listed
    // '*.o' could never be added. It also matched text inside comments and
    // inside longer paths.
    slExistingRules.CaseSensitive := False;

    for var i := 0 to slExisting.Count - 1 do
    begin
      var sExistingLine := slExisting[ i ].Trim.ToLower;

      if ( not sExistingLine.IsEmpty ) and ( not sExistingLine.StartsWith( '#' ) ) then
        slExistingRules.Add( sExistingLine );
    end;

    // Check which patterns are missing
    for sPattern in DELPHI_PATTERNS do
    begin
      // Skip the comment header - always add it if we're adding patterns
      if sPattern.StartsWith( '#' ) then
        Continue;

      if slExistingRules.IndexOf( sPattern.Trim.ToLower ) < 0 then
        slToAdd.Add( sPattern );
    end;

    if slToAdd.Count = 0 then
    begin
      StyledMessageDlg(  'All standard Delphi patterns are already in .gitignore.', mtInformation, [ mbOK ], 0 );
      Exit;
    end;

    // Add patterns to file
    try
      // Add blank line separator if file has content
      if slExisting.Count > 0 then
        slExisting.Add( '' );

      // Add header comment
      slExisting.Add( '# Delphi build artifacts (added by GitBatchCommit)' );

      // Add missing patterns
      iAddedCount   := 0;

      for sPattern in DELPHI_PATTERNS do
      begin
        if sPattern.StartsWith( '#' ) then
          Continue;

        if slExistingRules.IndexOf( sPattern.Trim.ToLower ) < 0 then
        begin
          slExisting.Add( sPattern );
          Inc( iAddedCount );
        end;
      end;

      // Write UTF-8 WITHOUT a BOM. TStrings.SaveToFile with no encoding uses
      // the encoding LoadFromFile settled on, which for a BOM-less file is the
      // ANSI code page — so a UTF-8 .gitignore containing a non-ASCII path was
      // silently rewritten as ANSI and its rules stopped matching.
      // Only the WRITE is guarded. The handler used to wrap the refresh and
      // the list update too, so an access violation in either surfaced as
      // "Failed to save .gitignore" - a message that sent every future
      // investigation to the wrong place.
      try
        TFile.WriteAllText( sGitignorePath, slExisting.Text );
      except
        on E: EInOutError do
        begin
          ErrorDlg( 'Failed to save .gitignore: ' + E.Message );
          Exit;
        end;
      end;

      Log( Format( 'Added %d Delphi patterns to .gitignore in %s', [ iAddedCount, FRepoCache[ iIndex ].Name ] ) );
      StyledMessageDlg(  Format( 'Added %d patterns to .gitignore.', [ iAddedCount ] ), mtInformation, [ mbOK ], 0 );

      // Refresh the repository status
      FRepoManager.RefreshStatus( RepoPathAt( iIndex ) );
      UpdateListItem( RepoPathAt( iIndex ) );

    except
      on E: EInOutError do
      begin
        ErrorDlg( 'Failed to save .gitignore: ' + E.Message );
        Exit;
      end;
    end;

  finally
    slExisting.Free;
    slToAdd.Free;
    slExistingRules.Free;
  end;

end;

/// <summary>
///   Handles the Help > Help Contents menu click.
/// </summary>
procedure TMainForm.mnuHelpContentsClick( Sender: TObject );
var
  sReadmePath       : string;
begin

  sReadmePath       := ExtractFilePath( Application.ExeName ) + 'Users Guide.md';

  if ( not FileExists( sReadmePath ) ) then
  begin
    StyledMessageDlg(  'Users Guide.md not found in application folder.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  if ShellExecute( Handle, 'open', PChar( sReadmePath ), nil, nil, SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not open the documentation - no application is registered for .md files.' + sLineBreak +
      sLineBreak + sReadmePath, mtWarning, [ mbOK ], 0 );

end;

/// <summary>
///   Handles the Help > About menu click.
/// </summary>
procedure TMainForm.mnuAboutClick( Sender: TObject );
begin

  StyledMessageDlg(
    'Git Batch Commit' + sLineBreak +
    sLineBreak +
    'Version ' + APP_VERSION + sLineBreak +
    sLineBreak +
    'A tool for committing and pushing changes to multiple' + sLineBreak +
    'Git repositories simultaneously with a single commit message.' + sLineBreak +
    sLineBreak +
    'Features:' + sLineBreak +
    '  - Batch commit and push to multiple repositories' + sLineBreak +
    '  - GitHub and Codeberg integration' + sLineBreak +
    '  - Repository status detection' + sLineBreak +
    '  - Automatic version tagging for Delphi projects' + sLineBreak +
    '  - Drag and drop support' + sLineBreak +
    sLineBreak +
    'Copyright (c) 2025 GITLAK Software' + sLineBreak +
    'All Rights Reserved',
    mtInformation, [ mbOK ], 0 );

end;

/// <summary>
///   Custom draws list items with colour-coded status.
/// </summary>
procedure TMainForm.lvReposCustomDrawItem( Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean );
var
  iIndex            : Integer;
  Status            : TRepoStatus;
begin

  if ( Item = nil ) or FShuttingDown then
    Exit;

  iIndex            := Integer( Item.Data );

  if ( iIndex < 0 ) or ( iIndex > High( FRepoCache ) ) then
    Exit;

  Status            := FRepoCache[ iIndex ].Status;

  // Set background colour based on status
  case Status of
    rsClean:
      Sender.Canvas.Brush.Color := clStatusClean;
    rsModified:
      Sender.Canvas.Brush.Color := clStatusModified;
    rsPullRequired:
      Sender.Canvas.Brush.Color := clStatusPullRequired;
    rsPushRequired:
      Sender.Canvas.Brush.Color := clStatusPushRequired;
    rsDiverged:
      Sender.Canvas.Brush.Color := clStatusDiverged;
    rsConflicted:
      Sender.Canvas.Brush.Color := clStatusConflicted;
    rsError:
      Sender.Canvas.Brush.Color := clStatusError;
    rsUnknown:
      Sender.Canvas.Brush.Color := clWindow;
  end;

  // If selected, use highlight colour. The font colour must move with it —
  // leaving it at clWindowText painted near-black text on the dark highlight
  // background, making the selected row effectively unreadable.
  if cdsSelected in State then
  begin
    Sender.Canvas.Brush.Color := clHighlight;
    Sender.Canvas.Font.Color := clHighlightText;
  end
  else
    Sender.Canvas.Font.Color := clWindowText;

  DefaultDraw       := True;

end;

/// <summary>
///   Opens the selected repository folder in Windows Explorer.
/// </summary>
procedure TMainForm.pmOpenInExplorerClick( Sender: TObject );
var
  iIndex            : Integer;
begin

  if lvRepos.Selected = nil then
    Exit;

  iIndex            := Integer( lvRepos.Selected.Data );
  if ShellExecute( Handle, 'explore', PChar( FRepoCache[ iIndex ].Path ), nil, nil, SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not open the folder in Explorer:' + sLineBreak + sLineBreak +
      FRepoCache[ iIndex ].Path, mtWarning, [ mbOK ], 0 );

end;

/// <summary>
///   Opens the selected repository in the configured Git client.
/// </summary>
procedure TMainForm.pmOpenInGitClientClick( Sender: TObject );
var
  iIndex            : Integer;
  sClientPath       : string;
  sRepoPath         : string;
begin

  if lvRepos.Selected = nil then
    Exit;

  iIndex            := Integer( lvRepos.Selected.Data );
  sRepoPath         := FRepoCache[ iIndex ].Path;
  sClientPath       := FRepoManager.GitClientPath;

  if sClientPath.IsEmpty then
  begin
    StyledMessageDlg(  'No Git client configured. Please set the Git client path in File > Settings.',
      mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  if ( not FileExists( sClientPath ) ) then
  begin
    StyledMessageDlg(  'Git client not found: ' + sClientPath, mtError, [ mbOK ], 0 );
    Exit;
  end;

  if ShellExecute( Handle, 'open', PChar( sClientPath ), PChar( '"' + sRepoPath + '"' ), nil, SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not launch the configured Git client:' + sLineBreak + sLineBreak + sClientPath,
      mtWarning, [ mbOK ], 0 );

end;

/// <summary>
///   Pulls changes for the selected repository.
/// </summary>
procedure TMainForm.pmPullClick( Sender: TObject );
var
  iIndex            : Integer;
  sLog              : string;
  sChanges          : string;
  sBranchName       : string;
  lHasBackup        : Boolean;
begin

  if lvRepos.Selected = nil then
    Exit;

  iIndex            := Integer( lvRepos.Selected.Data );

  // Strong warning about local code being modified
  if StyledMessageDlg(
    'WARNING: Pull will merge remote changes into your LOCAL code.' + sLineBreak + sLineBreak +
    'Your local files for "' + FRepoCache[ iIndex ].Name + '" MAY BE MODIFIED.' + sLineBreak + sLineBreak +
    'A backup branch will be created before pulling.' + sLineBreak + sLineBreak +
    'Do you want to continue?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor     := crHourGlass;

  try
    // Preview incoming changes
    Log( 'Fetching and previewing incoming changes...' );

    if not FRepoManager.GetIncomingChanges( RepoPathAt( iIndex ), sChanges, sLog ) then
      // Previously this failure had no else branch at all and sLog was
      // discarded, so an offline remote or an expired token went straight on
      // to pull with no preview and no warning.
      Log( 'Warning: could not preview incoming changes: ' + sLog )
    else
    begin
      if not sChanges.IsEmpty then
      begin
        Screen.Cursor := crDefault;
        if StyledMessageDlg(
          'The following files will be MODIFIED:' + sLineBreak + sLineBreak +
          sChanges + sLineBreak + sLineBreak +
          'Do you want to proceed? (A backup branch will be created)',
          mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
        begin
          Log( 'Pull cancelled by user.' );
          Exit;
        end;
        Screen.Cursor := crHourGlass;
      end
      else
        Log( 'No incoming changes detected.' );
    end;

    // Create backup branch
    lHasBackup      := FRepoManager.CreateBackupBranch( RepoPathAt( iIndex ), sBranchName, sLog );

    if lHasBackup then
      Log( sLog )
    else
    begin
      Log( 'Warning: Could not create backup branch: ' + sLog );

      if StyledMessageDlg(
        'The backup branch could NOT be created:' + sLineBreak + sLineBreak + sLog + sLineBreak + sLineBreak +
        'Pulling without a backup means local changes cannot be recovered from a branch afterwards.' + sLineBreak + sLineBreak +
        'Pull anyway?',
        mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
      begin
        Log( 'Pull cancelled by user (no backup branch).' );
        Exit;
      end;
    end;

    // Now pull
    Log( 'Pulling ' + FRepoCache[ iIndex ].Name + '...' );

    if FRepoManager.PullRepository( RepoPathAt( iIndex ), sLog ) then
    begin
      Log( sLog );
      Log( 'Pull complete.' );

      // Only claim a backup exists when one actually does — sBranchName is
      // empty when CreateBackupBranch failed, and this line used to print
      // unconditionally, telling the user about a safety net that was not
      // there and handing them a `git branch -d` with no branch name.
      if lHasBackup then
        Log( 'Backup branch "' + sBranchName + '" was created. Delete with: git branch -d ' + sBranchName );
      FRepoManager.RefreshStatus( RepoPathAt( iIndex ) );
      UpdateListItem( RepoPathAt( iIndex ) );
    end
    else
    begin
      Log( 'Pull failed: ' + sLog );
      ErrorDlg( 'Pull failed: ' + sLog );
    end;
  finally
    Screen.Cursor   := crDefault;
  end;

end;

/// <summary>
///   Shows the commit message history popup menu.
/// </summary>
procedure TMainForm.btnHistoryClick( Sender: TObject );
var
  Pt                : TPoint;
begin

  BuildHistoryMenu;

  Pt                := btnHistory.ClientToScreen( Point( 0, btnHistory.Height ) );
  pmHistory.Popup( Pt.X, Pt.Y );

end;

/// <summary>
///   Builds the commit message history popup menu.
/// </summary>
procedure TMainForm.BuildHistoryMenu;
var
  History           : TArray<string>;
  MenuItem          : TMenuItem;
begin

  pmHistory.Items.Clear;

  History           := FRepoManager.CommitHistory;

  if Length( History ) = 0 then
  begin
    MenuItem        := TMenuItem.Create( pmHistory );
    MenuItem.Caption := '(No history)';
    MenuItem.Enabled := False;
    pmHistory.Items.Add( MenuItem );
    Exit;
  end;

  for var i := 0 to High( History ) do
  begin
    MenuItem        := TMenuItem.Create( pmHistory );
    MenuItem.Caption := History[ i ];
    MenuItem.Tag    := i;
    MenuItem.OnClick := HistoryMenuItemClick;
    pmHistory.Items.Add( MenuItem );
  end;

end;

/// <summary>
///   Handles click on a history menu item.
/// </summary>
procedure TMainForm.HistoryMenuItemClick( Sender: TObject );
var
  MenuItem          : TMenuItem;
  History           : TArray<string>;
begin

  MenuItem          := Sender as TMenuItem;
  History           := FRepoManager.CommitHistory;

  if ( MenuItem.Tag >= 0 ) and ( MenuItem.Tag <= High( History ) ) then
    edtCommitMessage.Text := History[ MenuItem.Tag ];

end;

/// <summary>
///   Shows the settings dialog.
/// </summary>
procedure TMainForm.mnuSettingsClick( Sender: TObject );
var
  sClientPath       : string;
  sFilePattern      : string;
  sIndexerPath      : string;
  OpenDialog        : TOpenDialog;
begin

  sClientPath       := FRepoManager.GitClientPath;
  sFilePattern      := FRepoManager.FilePattern;
  sIndexerPath      := FRepoManager.DelphiIndexerPath;

  // Use separate InputQuery calls since the multi-value version has issues
  if InputQuery( 'Settings', 'Git Client Path - git.exe, or a GUI client for "Open in Git Client":', sClientPath ) then
  begin
    if InputQuery( 'Settings', 'File Pattern (e.g., *.pas or empty for all):', sFilePattern ) then
    begin
      // Restrict the pattern to a glob whitelist. Git is launched through
      // CreateProcess with no shell involved, so this is not about shell
      // metacharacters - it is about a pattern that begins with '-' being
      // taken as an OPTION to `git add` rather than as a pathspec. The
      // invocation also passes '--' before the pattern.
      if ( not TGitRepoManager.IsSafeFilePattern( sFilePattern ) ) then
      begin
        StyledMessageDlg(  'File pattern contains characters that are not allowed.' + sLineBreak + sLineBreak +
          'Use only letters, digits, glob characters ( * ? [ ] ), dots, dashes, underscores, slashes, commas, and spaces.',
          mtError, [ mbOK ], 0 );
        Exit;
      end;

      // Ask if user wants to configure delphi-indexer path
      if StyledMessageDlg(  'Configure delphi-indexer.exe path?' + sLineBreak + sLineBreak +
        'Current: ' + IfThen( sIndexerPath.IsEmpty, '(Auto-detect)', sIndexerPath ),
        mtConfirmation, [ mbYes, mbNo ], 0 ) = mrYes then
      begin
        OpenDialog  := TOpenDialog.Create( nil );
        try
          OpenDialog.Title := 'Locate delphi-indexer.exe';
          OpenDialog.Filter := 'Delphi Indexer|delphi-indexer.exe|Executable Files|*.exe|All Files|*.*';
          OpenDialog.FilterIndex := 1;
          OpenDialog.Options := [ ofFileMustExist, ofPathMustExist, ofNoChangeDir ];

          if not sIndexerPath.IsEmpty and FileExists( sIndexerPath ) then
            OpenDialog.InitialDir := ExtractFileDir( sIndexerPath );

          if OpenDialog.Execute then
            sIndexerPath := OpenDialog.FileName
          else
            Exit;                       // User cancelled - don't save any settings
        finally
          OpenDialog.Free;
        end;
      end;

      FRepoManager.GitClientPath := sClientPath;
      FRepoManager.FilePattern := sFilePattern;
      FRepoManager.DelphiIndexerPath := sIndexerPath;
      FRepoManager.SaveConfig;
      Log( 'Settings updated.' );
    end;
  end;

end;

/// <summary>
///   Shows the commit message templates popup menu.
/// </summary>
procedure TMainForm.btnTemplatesClick( Sender: TObject );
var
  Pt                : TPoint;
begin

  BuildTemplatesMenu;

  Pt                := btnTemplates.ClientToScreen( Point( 0, btnTemplates.Height ) );
  pmTemplates.Popup( Pt.X, Pt.Y );

end;

/// <summary>
///   Builds the commit message templates popup menu.
/// </summary>
procedure TMainForm.BuildTemplatesMenu;
var
  Templates         : TArray<string>;
  MenuItem          : TMenuItem;
begin

  pmTemplates.Items.Clear;

  Templates         := FRepoManager.CommitTemplates;

  if Length( Templates ) = 0 then
  begin
    MenuItem        := TMenuItem.Create( pmTemplates );
    MenuItem.Caption := '(No templates - use File > Template Settings to add)';
    MenuItem.Enabled := False;
    pmTemplates.Items.Add( MenuItem );
    Exit;
  end;

  for var i := 0 to High( Templates ) do
  begin
    MenuItem        := TMenuItem.Create( pmTemplates );
    MenuItem.Caption := Templates[ i ];
    MenuItem.Tag    := i;
    MenuItem.OnClick := TemplateMenuItemClick;
    pmTemplates.Items.Add( MenuItem );
  end;

end;

/// <summary>
///   Handles click on a template menu item.
/// </summary>
procedure TMainForm.TemplateMenuItemClick( Sender: TObject );
var
  MenuItem          : TMenuItem;
  Templates         : TArray<string>;
begin

  MenuItem          := Sender as TMenuItem;
  Templates         := FRepoManager.CommitTemplates;

  if ( MenuItem.Tag >= 0 ) and ( MenuItem.Tag <= High( Templates ) ) then
    edtCommitMessage.Text := Templates[ MenuItem.Tag ];

end;

/// <summary>
///   Shows the template settings dialog.
/// </summary>
procedure TMainForm.mnuTemplateSettingsClick( Sender: TObject );
var
  Templates         : TArray<string>;
begin

  Templates         := FRepoManager.CommitTemplates;

  if TTemplateSettingsDialog.Execute( Templates ) then
  begin
    FRepoManager.CommitTemplates := Templates;
    FRepoManager.SaveConfig;
    Log( 'Templates updated.' );
  end;

end;

/// <summary>
///   Toggles the visibility of the commit details panel.
/// </summary>
procedure TMainForm.btnDetailsClick( Sender: TObject );
begin

  pnlDetails.Visible := not pnlDetails.Visible;

  if pnlDetails.Visible then
    mmoDetails.SetFocus;

end;

/// <summary>
///   Updates the group filter combo box with available groups.
/// </summary>
procedure TMainForm.UpdateGroupFilterCombo;
var
  Groups            : TArray<string>;
  sCurrentGroup     : string;
begin

  sCurrentGroup     := cboGroupFilter.Text;
  cboGroupFilter.Items.Clear;
  cboGroupFilter.Items.Add( '(All Groups)' );

  Groups            := FRepoManager.GetAllGroups;

  for var i := 0 to High( Groups ) do
    cboGroupFilter.Items.Add( Groups[ i ] );

  // Restore selection. FGroupFilter must follow the combo: when the group the
  // user was filtering on disappears (its last member was re-grouped), the
  // combo snapped back to "(All Groups)" while FGroupFilter still held the old
  // name — so the list filtered on a group that no longer existed and showed
  // nothing, with the combo cheerfully reading "(All Groups)".
  if sCurrentGroup.IsEmpty or ( sCurrentGroup = '(All Groups)' ) then
  begin
    cboGroupFilter.ItemIndex := 0;
    FGroupFilter    := '';
  end
  else
  begin
    var iIndex      := cboGroupFilter.Items.IndexOf( sCurrentGroup );

    if iIndex >= 0 then
    begin
      cboGroupFilter.ItemIndex := iIndex;
      FGroupFilter  := sCurrentGroup;
    end
    else
    begin
      cboGroupFilter.ItemIndex := 0;
      FGroupFilter  := '';
    end;
  end;

end;

/// <summary>
///   Handles group filter combo box change.
/// </summary>
procedure TMainForm.cboGroupFilterChange( Sender: TObject );
begin

  if cboGroupFilter.ItemIndex <= 0 then
    FGroupFilter    := ''
  else
    FGroupFilter    := cboGroupFilter.Text;

  PopulateListView;

end;

/// <summary>
///   Handles click on a Set Group submenu item.
/// </summary>
procedure TMainForm.SetGroupMenuItemClick( Sender: TObject );
var
  MenuItem          : TMenuItem;
  iRepoIndex        : Integer;
  iCount            : Integer;
  sGroup            : string;
  Groups            : TArray<string>;
  Indices           : TArray<Integer>;
begin

  MenuItem          := Sender as TMenuItem;
  sGroup            := '';

  // Determine group name first
  if MenuItem.Tag = -1 then
  begin
    // Clear group
    sGroup          := '';
  end
  else if MenuItem.Tag = -2 then
  begin
    // New group
    if ( not InputQuery( 'New Group', 'Enter group name:', sGroup ) ) then
      Exit;

    sGroup          := Trim( sGroup );

    if sGroup.IsEmpty then
      Exit;
  end
  else
  begin
    // Existing group
    Groups          := FRepoManager.GetAllGroups;

    if ( MenuItem.Tag >= 0 ) and ( MenuItem.Tag <= High( Groups ) ) then
      sGroup        := Groups[ MenuItem.Tag ]
    else
      Exit;
  end;

  // Apply to the checked repositories.
  //
  // The Set Group submenu is enabled by SELECTION but acted on CHECKED rows,
  // and the list is RowSelect with separate checkboxes — so right-clicking a
  // highlighted but unticked row offered an enabled menu that then did
  // nothing and logged "No repositories selected". Fall back to the
  // highlighted row when nothing is ticked, which is what the user meant.
  Indices           := CheckedRepoIndices;

  if ( Length( Indices ) = 0 ) and ( lvRepos.Selected <> nil ) then
  begin
    iRepoIndex      := Integer( lvRepos.Selected.Data );

    if ( iRepoIndex >= 0 ) and ( iRepoIndex < FRepoManager.ReposCount ) then
      Indices       := [ iRepoIndex ];
  end;

  iCount            := Length( Indices );

  for iRepoIndex in Indices do
    FRepoManager.SetRepoGroup( RepoPathAt( iRepoIndex ), sGroup );

  if iCount > 0 then
  begin
    if MenuItem.Tag = -1 then
      Log( Format( 'Cleared group for %d repository(ies)', [ iCount ] ) )
    else
      Log( Format( 'Set group "%s" for %d repository(ies)', [ sGroup, iCount ] ) );
  end
  else
    Log( 'No repositories selected' );

  UpdateGroupFilterCombo;

  // Rebuild the list so the change is visible immediately; without this the
  // new grouping stayed invisible until something else happened to repopulate.
  PopulateListView;

end;

/// <summary>
///   Pulls changes for all selected repositories.
/// </summary>
procedure TMainForm.btnPullSelectedClick( Sender: TObject );
var
  iRepoIndex        : Integer;
  sLog              : string;
  sChanges          : string;
  sBranchName       : string;
  iCount            : Integer;
  iSuccess          : Integer;
  slPreview         : TStringList;
  bHasChanges       : Boolean;
  Indices           : TArray<Integer>;
  lAnyBackup        : Boolean;
begin

  // Resolve the checked rows to repository indices ONCE. These loops pump the
  // message queue (via Log), so walking lvRepos.Items live meant a filter or
  // sort change mid-batch could rebuild the list and leave the loop indexing
  // past its end.
  Indices           := CheckedRepoIndices;
  iCount            := Length( Indices );

  if iCount = 0 then
  begin
    StyledMessageDlg(  'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  // Strong warning about local code being modified
  if StyledMessageDlg(
    'WARNING: Pull will merge remote changes into your LOCAL code.' + sLineBreak + sLineBreak +
    'Your local files MAY BE MODIFIED by this operation.' + sLineBreak + sLineBreak +
    'A backup branch will be created before pulling.' + sLineBreak + sLineBreak +
    'Do you want to continue?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  // Take the batch guard BEFORE the preview, not after it. The preview runs
  // GetIncomingChanges - a network fetch - over every selected repository and
  // logs as it goes, and the buttons were all still live throughout.
  if ( not BeginBatch ) then
    Exit;

  // Fetch and preview incoming changes
  Log( 'Fetching and previewing incoming changes...' );
  Screen.Cursor     := crHourGlass;
  slPreview         := TStringList.Create;
  bHasChanges       := False;

  // One owner, one try..finally. Previously the list was freed at two separate
  // exit points and leaked whenever GetIncomingChanges or the dialog raised.
  var bProceed: Boolean;

  try
    try
      for var iRepo in Indices do
      begin
        var RepoInfo: TRepoInfo;

        if FRepoManager.GetIncomingChanges( RepoPathAt( iRepo ), sChanges, sLog ) then
        begin
          if not sChanges.IsEmpty then
          begin
            if RepoAt( iRepo, RepoInfo ) then
              slPreview.Add( '=== ' + RepoInfo.Name + ' ===' );

            slPreview.Add( sChanges );
            slPreview.Add( '' );
            bHasChanges := True;
          end;
        end
        else if RepoAt( iRepo, RepoInfo ) then
          Log( Format( 'Warning: could not preview %s: %s', [ RepoInfo.Name, sLog ] ) );
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    // Show preview and confirm
    if bHasChanges then
      bProceed := StyledMessageDlg(
        'The following files will be MODIFIED by the pull:' + sLineBreak + sLineBreak +
        slPreview.Text + sLineBreak +
        'Do you want to proceed? (Backup branches will be created)',
        mtWarning, [ mbYes, mbNo ], 0 ) = mrYes
    else
    begin
      Log( 'No incoming changes detected (or could not determine changes).' );
      bProceed := True;
    end;
  finally
    slPreview.Free;
  end;

  if ( not bProceed ) then
  begin
    Log( 'Pull cancelled by user.' );
    EndBatch;
    Exit;
  end;

  Screen.Cursor     := crHourGlass;
  iSuccess          := 0;
  lAnyBackup        := False;

  try
    try
      for iRepoIndex in Indices do
      begin
        var Repo: TRepoInfo;

        if RepoAt( iRepoIndex, Repo ) then
          Log( Format( '=== Pulling %s ===', [ Repo.Name ] ) );

        // Create backup branch first
        if FRepoManager.CreateBackupBranch( RepoPathAt( iRepoIndex ), sBranchName, sLog ) then
        begin
          Log( sLog );
          lAnyBackup := True;
        end
        else
          Log( 'Warning: Could not create backup branch: ' + sLog );

        // Now pull
        if FRepoManager.PullRepository( RepoPathAt( iRepoIndex ), sLog ) then
        begin
          Log( sLog );
          Inc( iSuccess );
        end
        else
          Log( 'Pull failed: ' + sLog );

        FRepoManager.RefreshStatus( RepoPathAt( iRepoIndex ) );
        UpdateListItem( RepoPathAt( iRepoIndex ) );
        Application.ProcessMessages;
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    Log( Format( 'Pull completed: %d of %d successful.', [ iSuccess, iCount ] ) );

    // Only mention backups if at least one was actually created. The blanket
    // "Backup branches were created." was printed even when every single one
    // had failed, telling the user a safety net existed when it did not.
    if lAnyBackup then
      Log( 'Backup branches were created. Use "git branch -d <branch-name>" to delete them if no longer needed.' )
    else
      Log( 'NOTE: no backup branches were created for this pull.' );
  finally
    EndBatch;
  end;

  ScrollLogToEnd;

end;

/// <summary>
///   Resolves merge conflicts for all selected repositories by keeping local versions.
/// </summary>
procedure TMainForm.btnResolveConflictsClick( Sender: TObject );
var
  iRepoIndex        : Integer;
  sLog              : string;
  iCount            : Integer;
  iSuccess          : Integer;
  Indices           : TArray<Integer>;
begin

  // Resolve the checked rows to repository indices ONCE. These loops pump the
  // message queue (via Log), so walking lvRepos.Items live meant a filter or
  // sort change mid-batch could rebuild the list and leave the loop indexing
  // past its end.
  Indices           := CheckedRepoIndices;
  iCount            := Length( Indices );

  if iCount = 0 then
  begin
    StyledMessageDlg(  'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg(  Format( 'Resolve conflicts for %d repository(ies) by keeping LOCAL versions?' + sLineBreak +
      sLineBreak + 'This will:' + sLineBreak +
      '- Keep your local version of every conflicted file' + sLineBreak +
      '- DISCARD the incoming remote version of those files' + sLineBreak +
      '- Commit the merge resolution' + sLineBreak +
      '- Push the result to the remote' + sLineBreak + sLineBreak +
      'The remote side of each conflicted file is lost. Repositories with no merge ' +
      'in progress are skipped.', [ iCount ] ),
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  var slReindexDirs := TStringList.Create;

  try
    Screen.Cursor   := crHourGlass;
    iSuccess        := 0;

    try
      for iRepoIndex in Indices do
      begin
        var Repo: TRepoInfo;
        var bResolveSuccess := FRepoManager.ResolveConflictsKeepLocal( RepoPathAt( iRepoIndex ), sLog );

        Log( sLog );

        if bResolveSuccess then
        begin
          Inc( iSuccess );

          // Track repo path for reindexing after loop completes
          if RepoAt( iRepoIndex, Repo ) and
             ( slReindexDirs.IndexOf( Repo.Path ) = -1 ) then
            slReindexDirs.Add( Repo.Path );
        end;

        FRepoManager.RefreshStatus( RepoPathAt( iRepoIndex ) );
        UpdateListItem( RepoPathAt( iRepoIndex ) );
        Application.ProcessMessages;
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    Log( Format( 'Resolve conflicts completed: %d of %d successful.', [ iSuccess, iCount ] ) );

    // Trigger all pending reindexes once after all operations complete
    RunPendingReindexes( slReindexDirs );

  finally
    slReindexDirs.Free;
    EndBatch;
  end;

  ScrollLogToEnd;

end;

/// <summary>
///   Pushes all selected repositories without committing.
/// </summary>
procedure TMainForm.btnPushOnlyClick( Sender: TObject );
var
  iRepoIndex        : Integer;
  sLog              : string;
  iCount            : Integer;
  iSuccess          : Integer;
  Indices           : TArray<Integer>;
begin

  // Resolve the checked rows to repository indices ONCE. These loops pump the
  // message queue (via Log), so walking lvRepos.Items live meant a filter or
  // sort change mid-batch could rebuild the list and leave the loop indexing
  // past its end.
  Indices           := CheckedRepoIndices;
  iCount            := Length( Indices );

  if iCount = 0 then
  begin
    StyledMessageDlg(  'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg(  Format( 'Push %d repository(ies) without committing?', [ iCount ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  var slReindexDirs := TStringList.Create;

  try
    Screen.Cursor   := crHourGlass;
    iSuccess        := 0;

    try
      for iRepoIndex in Indices do
      begin
        var Repo: TRepoInfo;

        if RepoAt( iRepoIndex, Repo ) then
          Log( Format( '=== Pushing %s ===', [ Repo.Name ] ) );

        var bPushSuccess := FRepoManager.PushRepository( RepoPathAt( iRepoIndex ), sLog );

        Log( sLog );

        if bPushSuccess then
        begin
          Inc( iSuccess );

          // Track repo path for reindexing after loop completes
          if ( not Repo.Path.IsEmpty ) and ( slReindexDirs.IndexOf( Repo.Path ) = -1 ) then
            slReindexDirs.Add( Repo.Path );
        end;

        FRepoManager.RefreshStatus( RepoPathAt( iRepoIndex ) );
        UpdateListItem( RepoPathAt( iRepoIndex ) );
        Application.ProcessMessages;
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    Log( Format( 'Push completed: %d of %d successful.', [ iSuccess, iCount ] ) );

    // Trigger all pending reindexes once after all operations complete
    RunPendingReindexes( slReindexDirs );

  finally
    slReindexDirs.Free;
    EndBatch;
  end;

  ScrollLogToEnd;

end;

procedure TMainForm.btnForcePushClick( Sender: TObject );
var
  iRepoIndex        : Integer;
  sLog              : string;
  iCount            : Integer;
  iSuccess          : Integer;
  Indices           : TArray<Integer>;
begin

  // Resolve the checked rows to repository indices ONCE. These loops pump the
  // message queue (via Log), so walking lvRepos.Items live meant a filter or
  // sort change mid-batch could rebuild the list and leave the loop indexing
  // past its end.
  Indices           := CheckedRepoIndices;
  iCount            := Length( Indices );

  if iCount = 0 then
  begin
    StyledMessageDlg(  'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  // Strong warning about force push
  if StyledMessageDlg(
    'WARNING: Force Push will OVERWRITE the remote repository history!' + sLineBreak + sLineBreak +
    'This makes your local code the definitive version.' + sLineBreak +
    'Any commits on the remote that are not in your local will be LOST.' + sLineBreak + sLineBreak +
    'This operation affects ' + IntToStr( iCount ) + ' repository(ies).' + sLineBreak + sLineBreak +
    'Are you ABSOLUTELY sure you want to continue?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  // Second confirmation for safety
  if StyledMessageDlg(
    'FINAL CONFIRMATION' + sLineBreak + sLineBreak +
    'You are about to force push ' + IntToStr( iCount ) + ' repository(ies).' + sLineBreak + sLineBreak +
    'Remote history will be overwritten. This cannot be undone.' + sLineBreak + sLineBreak +
    'Proceed with force push?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  var slReindexDirs := TStringList.Create;

  try
    Screen.Cursor   := crHourGlass;
    iSuccess        := 0;

    try
      for iRepoIndex in Indices do
      begin
        var Repo: TRepoInfo;

        if RepoAt( iRepoIndex, Repo ) then
          Log( Format( '=== Force Pushing %s ===', [ Repo.Name ] ) );

        var bPushSuccess := FRepoManager.ForcePushRepository( RepoPathAt( iRepoIndex ), sLog );

        Log( sLog );

        if bPushSuccess then
        begin
          Inc( iSuccess );

          // Track repo path for reindexing after loop completes
          if ( not Repo.Path.IsEmpty ) and ( slReindexDirs.IndexOf( Repo.Path ) = -1 ) then
            slReindexDirs.Add( Repo.Path );
        end;

        FRepoManager.RefreshStatus( RepoPathAt( iRepoIndex ) );
        UpdateListItem( RepoPathAt( iRepoIndex ) );
        Application.ProcessMessages;
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    Log( Format( 'Force push completed: %d of %d successful.', [ iSuccess, iCount ] ) );

    // Trigger all pending reindexes once after all operations complete
    RunPendingReindexes( slReindexDirs );

  finally
    slReindexDirs.Free;
    EndBatch;
  end;

  ScrollLogToEnd;

end;

/// <summary>
///   Executes a command and captures output.
/// </summary>
/// <param name="ACommand">Full command line to execute.</param>
/// <param name="AOutput">Captured stdout/stderr output.</param>
/// <param name="ATimeout">Timeout in milliseconds (default 30000 = 30s).</param>
/// <returns>True if command executed successfully (exit code 0).</returns>
function TMainForm.ExecuteCommand( const ACommand: string; out AOutput: string;
  const ATimeout: Cardinal ): Boolean;
begin

  // Delegates to the shared runner in uGitRepoManager. This method used to be
  // a near-duplicate of ExecuteGitCommand, and carried the same two defects:
  // output was decoded one 4096-byte pipe read at a time — so a multi-byte
  // UTF-8 character split across two reads raised EEncodingError, because
  // TEncoding.UTF8 is built with MB_ERR_INVALID_CHARS — and the process and
  // thread handles were closed only on the straight-line success path.
  Result := RunProcessCaptureOutput( ACommand, '', AOutput, ATimeout );

end;

/// <summary>
///   Runs delphi-indexer for all unique directories in the list.
/// </summary>
/// <param name="ADirs">StringList with entries in format 'category|path'</param>
/// <remarks>
///   Captures output and logs success/failure with details.
///   Incremental indexing is fast (~100ms when nothing changed).
/// </remarks>

procedure TMainForm.WriteGitIgnoreForProjectType( const sFolder, sProjectType: string );
var
  sGitIgnorePath    : string;
  sContent          : string;
begin

  sGitIgnorePath    := TPath.Combine( sFolder, '.gitignore' );

  // Don't overwrite an existing .gitignore
  if TFile.Exists( sGitIgnorePath ) then
    Exit;

  if sProjectType = 'Delphi / Pascal' then
    sContent        :=
      '# Delphi compiler-generated binaries' + sLineBreak +
      '*.exe' + sLineBreak +
      '*.dll' + sLineBreak +
      '*.bpl' + sLineBreak +
      '*.bpi' + sLineBreak +
      '*.dcp' + sLineBreak +
      '*.dcu' + sLineBreak +
      '*.drc' + sLineBreak +
      '*.map' + sLineBreak +
      '*.dres' + sLineBreak +
      '*.rsm' + sLineBreak +
      '*.tds' + sLineBreak +
      '*.lib' + sLineBreak +
      '*.a' + sLineBreak +
      '*.o' + sLineBreak +
      '*.ocx' + sLineBreak +
      '*.hpp' + sLineBreak +
      '*Resource.rc' + sLineBreak +
      sLineBreak +
      '# Delphi backup files' + sLineBreak +
      '*.~*' + sLineBreak +
      '*.bak' + sLineBreak +
      sLineBreak +
      '# Delphi local/user-specific files' + sLineBreak +
      '*.local' + sLineBreak +
      '*.identcache' + sLineBreak +
      '*.projdata' + sLineBreak +
      '*.tvsconfig' + sLineBreak +
      '*.cfg' + sLineBreak +
      '*.dsk' + sLineBreak +
      '*.stat' + sLineBreak +
      sLineBreak +
      '# Delphi history and recovery' + sLineBreak +
      '__history/' + sLineBreak +
      '__recovery/' + sLineBreak
  else if sProjectType = 'C / C++' then
    sContent        :=
      '*.o' + sLineBreak +
      '*.obj' + sLineBreak +
      '*.exe' + sLineBreak +
      '*.dll' + sLineBreak +
      '*.so' + sLineBreak +
      '*.a' + sLineBreak +
      '*.lib' + sLineBreak +
      '*.pdb' + sLineBreak +
      'build/' + sLineBreak +
      'cmake-build-*/' + sLineBreak
  else if sProjectType = 'C#' then
    sContent        :=
      'bin/' + sLineBreak +
      'obj/' + sLineBreak +
      '*.user' + sLineBreak +
      '*.suo' + sLineBreak +
      '.vs/' + sLineBreak +
      'packages/' + sLineBreak
  else if sProjectType = 'Java' then
    sContent        :=
      '*.class' + sLineBreak +
      '*.jar' + sLineBreak +
      '*.war' + sLineBreak +
      'target/' + sLineBreak +
      'build/' + sLineBreak +
      '.gradle/' + sLineBreak +
      '.idea/' + sLineBreak
  else if sProjectType = 'Python' then
    sContent        :=
      '__pycache__/' + sLineBreak +
      '*.pyc' + sLineBreak +
      '*.pyo' + sLineBreak +
      '*.egg-info/' + sLineBreak +
      'dist/' + sLineBreak +
      'build/' + sLineBreak +
      '.venv/' + sLineBreak +
      'venv/' + sLineBreak
  else if ( sProjectType = 'JavaScript / Node' ) or ( sProjectType = 'TypeScript' ) then
    sContent        :=
      'node_modules/' + sLineBreak +
      'dist/' + sLineBreak +
      'build/' + sLineBreak +
      '.env' + sLineBreak +
      '*.log' + sLineBreak
  else if sProjectType = 'Go' then
    sContent        :=
      'bin/' + sLineBreak +
      'vendor/' + sLineBreak +
      '*.exe' + sLineBreak
  else if sProjectType = 'Rust' then
    sContent        :=
      'target/' + sLineBreak +
      'Cargo.lock' + sLineBreak
  else if sProjectType = 'HTML / Web' then
    sContent        :=
      'node_modules/' + sLineBreak +
      '.env' + sLineBreak +
      'dist/' + sLineBreak
  else
    Exit;                               // (None) — no .gitignore

  try
    // The single-argument overload writes UTF-8 WITHOUT a BOM. Git does not
    // strip a BOM from .gitignore, so the explicit-encoding overload used to
    // corrupt the FIRST rule of every non-Delphi template — 'node_modules/',
    // 'target/', '__pycache__/' and friends simply stopped being ignored.
    TFile.WriteAllText( sGitIgnorePath, sContent );
    Log( Format( 'Created .gitignore for %s project', [ sProjectType ] ) );
  except
    on E: EInOutError do
      Log( 'Warning: Failed to create .gitignore: ' + E.Message );
  end;

end;

function TMainForm.InitializeDroppedFolder( const sFolder: string ): Boolean;
var
  sRepoName         : string;
  sDescription      : string;
  lPrivate          : Boolean;
  sProjectType      : string;
  sRemoteURL        : string;
  sError            : string;
  sLog              : string;
  iChoice           : Integer;
begin

  Result            := False;
  sRepoName         := SanitizeRepoName( ExtractFileName( ExcludeTrailingPathDelimiter( sFolder ) ) );

  // Ask the user what to do
  iChoice           := StyledMessageDlg(
    Format( '"%s" is not a Git repository.', [ sRepoName ] ) + sLineBreak + sLineBreak +
    'Would you like to initialise it and push to a remote?' + sLineBreak + sLineBreak +
    'Yes = GitHub' + sLineBreak +
    'No = Codeberg' + sLineBreak +
    'Cancel = Skip',
    mtConfirmation, [ mbYes, mbNo, mbCancel ], 0 );

  if iChoice = mrCancel then
    Exit;

  // Check credentials for chosen provider. Yes is GitHub - it is the host
  // this application is pointed at, and the affirmative button should be the
  // one the user almost always wants.
  if iChoice = mrYes then
  begin
    if not FRepoManager.HasGitHubCredentials then
    begin
      StyledMessageDlg(  'Please configure GitHub credentials first.', mtWarning, [ mbOK ], 0 );
      mnuGitHubSettingsClick( nil );

      if not FRepoManager.HasGitHubCredentials then
        Exit;
    end;
  end
  else
  begin
    if not FRepoManager.HasCodebergCredentials then
    begin
      StyledMessageDlg(  'Please configure Codeberg credentials first.', mtWarning, [ mbOK ], 0 );
      mnuCodebergSettingsClick( nil );

      if not FRepoManager.HasCodebergCredentials then
        Exit;
    end;
  end;

  // Get repository details with project type
  sDescription      := '';
  lPrivate          := True;
  sProjectType      := 'Delphi / Pascal';

  if ( not TNewRepositoryDialog.Execute( sRepoName, sDescription, lPrivate, sProjectType,
    IfThen( iChoice = mrYes, 'GitHub', 'Codeberg' ) ) ) then
    Exit;

  // Write .gitignore based on project type before init
  WriteGitIgnoreForProjectType( sFolder, sProjectType );

  Screen.Cursor     := crHourGlass;

  try
    // Step 1: Initialise local repository
    Log( Format( '=== Initialising %s ===', [ sRepoName ] ) );

    if not FRepoManager.InitializeRepository( sFolder, sLog ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to initialise repository: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Step 2: Create remote repository
    if iChoice = mrYes then
    begin
      Log( '=== Creating GitHub Repository ===' );

      if not FRepoManager.CreateGitHubRepository( sRepoName, sDescription, lPrivate, sRemoteURL, sError ) then
      begin
        Log( 'Error: ' + sError );
        ErrorDlg( 'Failed to create GitHub repository: ' + sError );
        Exit;
      end;
    end
    else
    begin
      Log( '=== Creating Codeberg Repository ===' );

      if not FRepoManager.CreateCodebergRepository( sRepoName, sDescription, lPrivate, sRemoteURL, sError ) then
      begin
        Log( 'Error: ' + sError );
        ErrorDlg( 'Failed to create Codeberg repository: ' + sError );
        Exit;
      end;
    end;

    Log( 'Created repository: ' + sRemoteURL );

    // Step 3: Add remote origin
    if not FRepoManager.AddRemoteOrigin( sFolder, sRemoteURL, sLog ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to add remote origin: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Step 4: Initial commit and push
    if not FRepoManager.InitialCommitAndPush( sFolder, 'Initial commit', sLog ) then
    begin
      Log( 'Error: ' + sLog );
      ErrorDlg( 'Failed to commit and push: ' + sLog );
      Exit;
    end;

    Log( sLog );

    // Add to repository list
    FRepoManager.AddRepository( sFolder );
    Log( Format( '=== %s initialised and pushed ===', [ sRepoName ] ) );
    Result          := True;
  finally
    Screen.Cursor   := crDefault;
  end;

end;

procedure TMainForm.RunPendingReindexes( const ADirs: TStringList );
const
  DELPHI_INDEXER_EXE = 'delphi-indexer.exe';
  DEFAULT_INSTALL_PATH = 'D:\glldelphi-lookup\delphi-indexer.exe';
var
  sIndexerPath      : string;
  SearchBuffer      : array[ 0..MAX_PATH ] of Char;
  FilePart          : PChar;
  iFound            : Cardinal;
  sPath             : string;
  sParams           : string;
  sOutput           : string;
begin

  // Nothing to reindex
  if ( ADirs = nil ) or ( ADirs.Count = 0 ) then
    Exit;

  // Find delphi-indexer.exe location
  sIndexerPath      := '';

  // 1. Check user-configured path first (verify it still exists)
  if not FRepoManager.DelphiIndexerPath.IsEmpty then
  begin
    if FileExists( FRepoManager.DelphiIndexerPath ) then
      sIndexerPath  := FRepoManager.DelphiIndexerPath
    else
      // Do NOT clear the setting. The indexer may live on a network share or
      // a removable drive, and one run while it happened to be offline used to
      // erase the user's configured path permanently and silently.
      LogSafe( Format( 'Reindex: configured indexer not found at "%s" - trying PATH.',
        [ FRepoManager.DelphiIndexerPath ] ) );
  end;

  // 2. Check PATH environment variable
  FilePart          := nil;
  FillChar( SearchBuffer, SizeOf( SearchBuffer ), 0 );

  if sIndexerPath.IsEmpty then
  begin
    // SearchPath returns the REQUIRED buffer size when the result does not
    // fit, without writing the buffer at all — so a non-zero return is not on
    // its own proof that SearchBuffer holds anything.
    iFound := SearchPath( nil, PChar( DELPHI_INDEXER_EXE ), nil, Length( SearchBuffer ), SearchBuffer, FilePart );

    if ( iFound > 0 ) and ( iFound < Cardinal( Length( SearchBuffer ) ) ) then
    begin
      sIndexerPath  := SearchBuffer;
      QueueIndexerPathUpdate( sIndexerPath );
    end;
  end;

  // 3. Check default installation location
  if sIndexerPath.IsEmpty and FileExists( DEFAULT_INSTALL_PATH ) then
  begin
    sIndexerPath    := DEFAULT_INSTALL_PATH;
    QueueIndexerPathUpdate( sIndexerPath );
  end;

  // 4. Not found - skip reindexing silently
  if sIndexerPath.IsEmpty then
    Exit;

  LogSafe( Format( 'Reindex: Processing %d repo(s)', [ ADirs.Count ] ) );

  // Reindex each committed repository. One repository failing must never
  // abandon the rest of the batch, so each is guarded individually.
  for sPath in ADirs do
  begin
    LogSafe( Format( 'Triggering delphi-lookup reindex: %s', [ sPath ] ) );
    sParams         := Format( '"%s" "%s" --category user', [ sIndexerPath, sPath ] );

    try
      if ExecuteCommand( sParams, sOutput ) then
        LogSafe( 'delphi-lookup reindex completed successfully' )
      else
      begin
        LogSafe( 'delphi-lookup reindex FAILED' );

        if not sOutput.Trim.IsEmpty then
          LogSafe( 'Error: ' + sOutput.Trim );
      end;
    except
      // One repository must never abandon the rest of the batch, so this stays
      // a catch-all - but a defect in our own code is re-raised so EurekaLog
      // still sees it.
      on E: Exception do
      begin
        LogSafe( Format( 'delphi-lookup reindex FAILED for %s: %s', [ sPath, E.Message ] ) );
        ReRaiseIfDefect( E );
      end;
    end;
  end;

end;

procedure TMainForm.mmoLogKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );
begin

  // Handle Ctrl+A to select all text in the log memo
  if ( ssCtrl in Shift ) and ( Key = Ord( 'A' ) ) then
  begin
    mmoLog.SelectAll;
    Key             := 0;
  end;

end;

procedure TMainForm.FormKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );
begin

  // Ctrl+Enter triggers Commit & Push.
  //
  // KeyPreview routes every keystroke here first, so this must NOT fire while
  // the focus is in a multi-line memo, where Ctrl+Enter is an ordinary editing
  // keystroke the user expects to insert a line break.
  if ( ssCtrl in Shift ) and ( Key = VK_RETURN ) then
  begin

    if ( ActiveControl is TCustomMemo ) then
      Exit;

    if btnCommitPush.Enabled then
      btnCommitPushClick( btnCommitPush );

    Key             := 0;

  end;

end;

end.

