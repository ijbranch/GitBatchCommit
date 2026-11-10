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
  File last update : 2026-01-04T05:22:04.270+11:00
  Signature : d26f7f5526780a3160043a967157d5bbcb6ffafb
  ***************************************************************************
*)

(*
  MainFrm.pas - Main Form Unit

  Copyright (c) 2026 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.9.0

  Part of GitBatchCommit Application

  Description:
    Main form providing the user interface for managing multiple Git
    repositories and performing batch commit and push operations,
    including GitHub repository creation.
*)

{
04/01/2026 - Fixed issue with Remove Selected option.
}

{
Requires to be built with Delphi v 13 or higher.
3rd Party libraries used are listed in README.md (section "Third-party libraries").
}
unit MainFrm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Buttons,
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  uGitRepoManager;

type
  /// <summary>
  ///   One repository's share of a batch: does the work and returns its log.
  /// </summary>
  /// <remarks>
  ///   Runs on a worker thread, so it must not touch a control.
  /// </remarks>
  /// <param name="sRepoPath">Working-tree path of the repository to act on.</param>
  /// <param name="sLog">Receives the text to show in the log for this repository.</param>
  /// <returns>True when the operation succeeded for this repository.</returns>
  TRepoWork = reference to function( const sRepoPath: string; out sLog: string ): Boolean;

  /// <summary>
  ///   Everything asked of the user about one folder that is to become a new
  ///   GitHub repository, gathered before any work starts.
  /// </summary>
  TNewRepoJob = record
    /// <summary>
    ///   Normalised path of the local folder.
    /// </summary>
    Folder: string;
    /// <summary>
    ///   Name of the repository to create on GitHub.
    /// </summary>
    Name: string;
    /// <summary>
    ///   Optional description for the GitHub repository.
    /// </summary>
    Description: string;
    /// <summary>
    ///   Project type whose .gitignore template is written first; one of the
    ///   <c>TNewRepositoryForm.PROJECT_TYPE_*</c> values.
    /// </summary>
    ProjectType: string;
    /// <summary>
    ///   True to create the repository private.
    /// </summary>
    IsPrivate: Boolean;
  end;

  /// <summary>
  ///   Main application form for Git Batch Commit utility.
  /// </summary>
  /// <remarks>
  ///   Provides UI for managing multiple Git repositories and performing
  ///   batch commit and push operations with a single commit message.
  /// </remarks>
  TMainForm = class( TForm )
    /// <summary>
    ///   The pnlTop panel.
    /// </summary>
    pnlTop: TPanel;
    /// <summary>
    ///   The pnlBottom panel.
    /// </summary>
    pnlBottom: TPanel;
    /// <summary>
    ///   The pnlClient panel.
    /// </summary>
    pnlClient: TPanel;
    /// <summary>
    ///   The repository list: one ticked or unticked row per managed repository.
    /// </summary>
    lvRepos: TListView;
    /// <summary>
    ///   The "Select Modified" button.
    /// </summary>
    btnSelectModified: TBitBtn;
    /// <summary>
    ///   The "Select All" button.
    /// </summary>
    btnSelectAll: TBitBtn;
    /// <summary>
    ///   The "Select None" button.
    /// </summary>
    btnSelectNone: TBitBtn;
    /// <summary>
    ///   The "Commit Message" label.
    /// </summary>
    lblCommitMessage: TLabel;
    /// <summary>
    ///   The commit message summary line.
    /// </summary>
    edtCommitMessage: TEdit;
    /// <summary>
    ///   The "Commit &amp; Push Selected" button.
    /// </summary>
    btnCommitPush: TBitBtn;
    /// <summary>
    ///   The operation log.
    /// </summary>
    mmoLog: TMemo;
    /// <summary>
    ///   The splitter splitter.
    /// </summary>
    splitter: TSplitter;
    /// <summary>
    ///   The MainMenu main menu.
    /// </summary>
    MainMenu: TMainMenu;
    /// <summary>
    ///   The "File" menu item.
    /// </summary>
    mnuFile: TMenuItem;
    /// <summary>
    ///   The "Add Repository" menu item.
    /// </summary>
    mnuAddRepository: TMenuItem;
    /// <summary>
    ///   The "Remove Selected" menu item.
    /// </summary>
    mnuRemoveSelected: TMenuItem;
    /// <summary>
    ///   The "Delete Selected" menu item.
    /// </summary>
    mnuDeleteSelected: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    mnuFileSep1: TMenuItem;
    /// <summary>
    ///   The "Refresh Status" menu item.
    /// </summary>
    mnuRefreshStatus: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    mnuFileSep2: TMenuItem;
    /// <summary>
    ///   The "Exit" menu item.
    /// </summary>
    mnuExit: TMenuItem;
    /// <summary>
    ///   The "GitHub" menu item.
    /// </summary>
    mnuGitHub: TMenuItem;
    /// <summary>
    ///   The "Initialise &amp; Push to GitHub" menu item.
    /// </summary>
    mnuInitPushGitHub: TMenuItem;
    /// <summary>
    ///   The "Migrate Selected Repository to GitHub" menu item.
    /// </summary>
    mnuMigrateToGitHub: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    mnuGitHubSep1: TMenuItem;
    /// <summary>
    ///   The "Settings" menu item.
    /// </summary>
    mnuGitHubSettings: TMenuItem;
    /// <summary>
    ///   The "View" menu item.
    /// </summary>
    mnuView: TMenuItem;
    /// <summary>
    ///   The "Filter" menu item.
    /// </summary>
    mnuFilter: TMenuItem;
    /// <summary>
    ///   The "All" menu item.
    /// </summary>
    mnuFilterAll: TMenuItem;
    /// <summary>
    ///   The "Clean" menu item.
    /// </summary>
    mnuFilterClean: TMenuItem;
    /// <summary>
    ///   The "Modified" menu item.
    /// </summary>
    mnuFilterModified: TMenuItem;
    /// <summary>
    ///   The "Pull Required" menu item.
    /// </summary>
    mnuFilterPullRequired: TMenuItem;
    /// <summary>
    ///   The "Push Required" menu item.
    /// </summary>
    mnuFilterPushRequired: TMenuItem;
    /// <summary>
    ///   The "Diverged" menu item.
    /// </summary>
    mnuFilterDiverged: TMenuItem;
    /// <summary>
    ///   The "Conflicted" menu item.
    /// </summary>
    mnuFilterConflicted: TMenuItem;
    /// <summary>
    ///   The "Error" menu item.
    /// </summary>
    mnuFilterError: TMenuItem;
    /// <summary>
    ///   The View > Style submenu; filled at run time with the linked VCL styles.
    /// </summary>
    mnuStyle: TMenuItem;
    /// <summary>
    ///   The "Help" menu item.
    /// </summary>
    mnuHelp: TMenuItem;
    /// <summary>
    ///   The "Help Contents" menu item.
    /// </summary>
    mnuHelpContents: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    mnuHelpSep1: TMenuItem;
    /// <summary>
    ///   The "About" menu item.
    /// </summary>
    mnuAbout: TMenuItem;
    /// <summary>
    ///   Context menu of the repository list.
    /// </summary>
    pmRepos: TPopupMenu;
    /// <summary>
    ///   The "Set Public" menu item.
    /// </summary>
    pmSetPublic: TMenuItem;
    /// <summary>
    ///   The "Set Private" menu item.
    /// </summary>
    pmSetPrivate: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    pmSep1: TMenuItem;
    /// <summary>
    ///   The "Edit .gitignore" menu item.
    /// </summary>
    pmEditGitignore: TMenuItem;
    /// <summary>
    ///   The "Fix .gitignore (Add Delphi Patterns)" menu item.
    /// </summary>
    pmFixGitignore: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    pmSep2: TMenuItem;
    /// <summary>
    ///   The "Open in Explorer" menu item.
    /// </summary>
    pmOpenInExplorer: TMenuItem;
    /// <summary>
    ///   The "Open in Git Client" menu item.
    /// </summary>
    pmOpenInGitClient: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    pmSep3: TMenuItem;
    /// <summary>
    ///   The "Pull" menu item.
    /// </summary>
    pmPull: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    pmSep4: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    pmSep5: TMenuItem;
    /// <summary>
    ///   The "Delete Selected" menu item.
    /// </summary>
    pmDeleteSelected: TMenuItem;
    /// <summary>
    ///   Dropped by the History button; rebuilt from the commit message history each time.
    /// </summary>
    pmHistory: TPopupMenu;
    /// <summary>
    ///   Drops the commit message history menu.
    /// </summary>
    btnHistory: TBitBtn;
    /// <summary>
    ///   The "Settings" menu item.
    /// </summary>
    mnuSettings: TMenuItem;
    /// <summary>
    ///   Menu separator.
    /// </summary>
    mnuFileSep3: TMenuItem;
    /// <summary>
    ///   Drops the commit message template menu.
    /// </summary>
    btnTemplates: TBitBtn;
    /// <summary>
    ///   Dropped by the Templates button; rebuilt from the commit message templates each time.
    /// </summary>
    pmTemplates: TPopupMenu;
    /// <summary>
    ///   The "Templates" menu item.
    /// </summary>
    mnuTemplateSettings: TMenuItem;
    /// <summary>
    ///   Chooses the group the list is filtered to.
    /// </summary>
    cbGroupFilter: TComboBox;
    /// <summary>
    ///   The "Group" label.
    /// </summary>
    lblGroupFilter: TLabel;
    /// <summary>
    ///   The Set Group submenu; rebuilt each time the context menu opens.
    /// </summary>
    pmSetGroup: TMenuItem;
    /// <summary>
    ///   Shows or hides the extended commit message panel.
    /// </summary>
    btnDetails: TBitBtn;
    /// <summary>
    ///   The "Pull Selected" button.
    /// </summary>
    btnPullSelected: TBitBtn;
    /// <summary>
    ///   The "Resolve Conflicts" button.
    /// </summary>
    btnResolveConflicts: TBitBtn;
    /// <summary>
    ///   The "Push Only" button.
    /// </summary>
    btnPushOnly: TBitBtn;
    /// <summary>
    ///   The "Force Push" button.
    /// </summary>
    btnForcePush: TBitBtn;
    /// <summary>
    ///   The pnlDetails panel.
    /// </summary>
    pnlDetails: TPanel;
    /// <summary>
    ///   The "Details" label.
    /// </summary>
    lblDetails: TLabel;
    /// <summary>
    ///   Optional extended commit message, below the summary line.
    /// </summary>
    mmoDetails: TMemo;
    /// <summary>
    ///   Initialises form state and creates the repository manager.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>
    ///   Cancels every background worker, waits for them to finish, saves the
    ///   configuration and releases the objects this form owns.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
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
    /// <param name="Sender">The control raising the event.</param>
    procedure FormShow( Sender: TObject );
    /// <summary>
    ///   Commits and pushes every checked repository that has modifications, using
    ///   the entered message, on a background thread.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnCommitPushClick( Sender: TObject );
    /// <summary>
    ///   Ticks only the repositories whose status is Modified.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnSelectModifiedClick( Sender: TObject );
    /// <summary>
    ///   Ticks every repository currently shown in the list.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnSelectAllClick( Sender: TObject );
    /// <summary>
    ///   Clears the tick on every repository currently shown in the list.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnSelectNoneClick( Sender: TObject );
    /// <summary>
    ///   Mirrors a row tick into the repository record, unless the list is being
    ///   updated programmatically.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    /// <param name="Item">The row whose checkbox changed.</param>
    procedure lvReposItemChecked( Sender: TObject; Item: TListItem );
    /// <summary>
    ///   Prompts for a folder and adds it to the managed repository list.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuAddRepositoryClick( Sender: TObject );
    /// <summary>
    ///   Removes every ticked repository from the managed list, after
    ///   confirmation.  Nothing on disk or on the remote is touched.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuRemoveSelectedClick( Sender: TObject );
    /// <summary>
    ///   Deletes every ticked repository, asking first which of the list
    ///   entry, the remote repository and the local folder to delete.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuDeleteSelectedClick( Sender: TObject );
    /// <summary>
    ///   The context-menu Delete: acts on the right-clicked row when it is not
    ///   ticked, and on every ticked row when it is.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmDeleteSelectedClick( Sender: TObject );
    /// <summary>
    ///   Starts an asynchronous refresh of every repository status.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuRefreshStatusClick( Sender: TObject );
    /// <summary>
    ///   Closes the application.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuExitClick( Sender: TObject );
    /// <summary>
    ///   Publishes the chosen folder to GitHub: initialises it if it is not a
    ///   repository yet, creates the GitHub repository, commits and pushes.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuInitPushGitHubClick( Sender: TObject );
    /// <summary>
    ///   Opens the GitHub credentials dialog.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuGitHubSettingsClick( Sender: TObject );
    /// <summary>
    ///   Moves the highlighted repository to a newly created GitHub repository.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuMigrateToGitHubClick( Sender: TObject );
    /// <summary>
    ///   Applies the status filter chosen from the View menu and rebuilds the list.
    /// </summary>
    /// <param name="Sender">The filter menu item that was chosen; identifies the filter.</param>
    procedure mnuFilterClick( Sender: TObject );
    /// <summary>
    ///   Makes the highlighted repository public on GitHub.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmSetPublicClick( Sender: TObject );
    /// <summary>
    ///   Makes the highlighted repository private on GitHub.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmSetPrivateClick( Sender: TObject );
    /// <summary>
    ///   Enables or disables popup items according to the current selection, and
    ///   rebuilds the Set Group submenu from the groups currently in use.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmReposPopup( Sender: TObject );
    /// <summary>
    ///   Opens the selected repository's .gitignore in the registered editor.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmEditGitignoreClick( Sender: TObject );
    /// <summary>
    ///   Adds any missing standard Delphi ignore patterns to the selected
    ///   repository's .gitignore.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmFixGitignoreClick( Sender: TObject );
    /// <summary>
    ///   Re-evaluates whether Commit & Push can be enabled.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure edtCommitMessageChange( Sender: TObject );
    /// <summary>
    ///   Handles a click in the repository list, including shift-click range ticking
    ///   from the previously clicked row.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure lvReposClick( Sender: TObject );
    /// <summary>
    ///   Opens the bundled documentation in the registered Markdown viewer.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuHelpContentsClick( Sender: TObject );
    /// <summary>
    ///   Shows the About box.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuAboutClick( Sender: TObject );
    /// <summary>
    ///   Colours each list row according to its repository status.
    /// </summary>
    /// <param name="Sender">The repository list.</param>
    /// <param name="Item">The row about to be drawn.</param>
    /// <param name="State">Draw state of the row.</param>
    /// <param name="DefaultDraw">Left True so the list draws the row itself.</param>
    procedure lvReposCustomDrawItem( Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean );
    /// <summary>
    ///   Opens the selected repository folder in Windows Explorer.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmOpenInExplorerClick( Sender: TObject );
    /// <summary>
    ///   Opens the selected repository in the configured external Git client.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmOpenInGitClientClick( Sender: TObject );
    /// <summary>
    ///   Pulls the highlighted repository; see <see cref="PullRepositories"/>.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure pmPullClick( Sender: TObject );
    /// <summary>
    ///   Builds and drops down the commit-message history menu.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnHistoryClick( Sender: TObject );
    /// <summary>
    ///   Opens the Settings dialog (Git client path, file pattern, indexer path).
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuSettingsClick( Sender: TObject );
    /// <summary>
    ///   Builds and drops down the commit-message template menu.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnTemplatesClick( Sender: TObject );
    /// <summary>
    ///   Opens the commit-message template maintenance dialog.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure mnuTemplateSettingsClick( Sender: TObject );
    /// <summary>
    ///   Applies the group chosen in the filter combo and rebuilds the list.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure cbGroupFilterChange( Sender: TObject );
    /// <summary>
    ///   Shows or hides the extended commit-message details panel.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnDetailsClick( Sender: TObject );
    /// <summary>
    ///   Pulls every ticked repository; see <see cref="PullRepositories"/>.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnPullSelectedClick( Sender: TObject );
    /// <summary>
    ///   Resolves an in-progress merge in every checked repository by keeping the
    ///   local version of each conflicted file, then commits and pushes.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnResolveConflictsClick( Sender: TObject );
    /// <summary>
    ///   Pushes every checked repository without committing.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnPushOnlyClick( Sender: TObject );
    /// <summary>
    ///   Force-pushes every checked repository, using --force-with-lease.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    procedure btnForcePushClick( Sender: TObject );
    /// <summary>
    ///   Adds Ctrl+A (select all) support to the log memo.
    /// </summary>
    /// <param name="Sender">The control raising the event.</param>
    /// <param name="Key">Virtual key code; set to 0 to swallow the keystroke.</param>
    /// <param name="Shift">Modifier keys held down.</param>
    procedure mmoLogKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );
  protected
    /// <summary>
    ///   Registers the window for folder drag-and-drop. Done here rather than in
    ///   FormCreate because changing the VCL style can recreate the handle, which
    ///   would silently drop the registration.
    /// </summary>
    procedure CreateWnd; override;
  private
    const
      /// <summary>
      ///   Posted by FormShow so the repository list loads after the first paint.
      /// </summary>
      WM_LOAD_REPOS = WM_USER + 100;
      // A TColor literal is $00BBGGRR — blue, green, red — NOT $RRGGBB. Four of
      // these were written in RGB order and therefore painted a different
      // colour from the one their comment named: Modified rendered pale cyan,
      // Pull Required light blue, Push Required pale yellow and Diverged pink,
      // so Modified and Push Required were effectively transposed. Each value
      // below is now written as RGB( r, g, b ) so the intent and the paint
      // cannot drift apart again.
      /// <summary>
      ///   Row background for a Clean repository.
      /// </summary>
      clStatusClean = TColor( $00E0FFE0 ); // RGB( 224, 255, 224 ) light green
      /// <summary>
      ///   Row background for a Modified repository.
      /// </summary>
      clStatusModified = TColor( $00C0FFFF ); // RGB( 255, 255, 192 ) light yellow
      /// <summary>
      ///   Row background for a Pull Required repository.
      /// </summary>
      clStatusPullRequired = TColor( $00C0E0FF ); // RGB( 255, 224, 192 ) light orange
      /// <summary>
      ///   Row background for an Error repository.
      /// </summary>
      clStatusError = TColor( $00C0C0FF ); // RGB( 255, 192, 192 ) light red
      /// <summary>
      ///   Row background for a Conflicted repository.
      /// </summary>
      clStatusConflicted = TColor( $008080FF ); // RGB( 255, 128, 128 ) stronger red
      /// <summary>
      ///   Row background for a Push Required repository.
      /// </summary>
      clStatusPushRequired = TColor( $00C0FFC0 ); // RGB( 192, 255, 192 ) pale green
      /// <summary>
      ///   Row background for a Diverged repository.
      /// </summary>
      clStatusDiverged = TColor( $00FFC0E0 ); // RGB( 224, 192, 255 ) light purple

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
      /// <summary>
      ///   The engine: owns the repository list, the configuration and every Git
      ///   and GitHub call.  Created in FormCreate, freed in FormDestroy.
      /// </summary>
      FRepoManager  : TGitRepoManager;
      /// <summary>
      ///   Style names behind the View > Style items, indexed by each item's Tag.
      /// </summary>
      FStyleNames   : TArray<string>;
      /// <summary>
      ///   Index into FStyleNames of the style waiting for ApplyPendingStyle, or -1.
      /// </summary>
      FPendingStyle : Integer;
      /// <summary>
      ///   True while the list is being changed in code, so that the tick
      ///   handler ignores the events that causes.
      /// </summary>
      FUpdatingList : Boolean;
      /// <summary>
      ///   Index of the column the list is sorted by.
      /// </summary>
      FSortColumn   : Integer;
      /// <summary>
      ///   True when the sort is ascending.
      /// </summary>
      FSortAscending: Boolean;
      /// <summary>
      ///   Indices into <see cref="FRepoCache"/> of the rows shown, in display order.
      /// </summary>
      FFilteredIndices: TList<Integer>;
      /// <summary>
      ///   Status filter chosen from View > Filter; 0 shows every status.
      /// </summary>
      FStatusFilter : Integer;
      /// <summary>
      ///   Set once the deferred first load has been posted, so that FormShow
      ///   posts it only once.
      /// </summary>
      FInitialLoadDone: Boolean;
      /// <summary>
      ///   Row index of the last click in the list, the anchor for a shift-click
      ///   range; -1 when there is none.
      /// </summary>
      FLastClickedIndex: Integer;
      /// <summary>
      ///   True while a status refresh is in flight.
      /// </summary>
      FRefreshing   : Boolean;
      /// <summary>
      ///   Non-zero once the running operation has been asked to stop.  Written
      ///   and read with TInterlocked: workers poll it through
      ///   <see cref="IsCancelled"/>.
      /// </summary>
      FCancelRefresh: Integer;
      /// <summary>
      ///   Group the list is filtered to; empty shows every group.
      /// </summary>
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
      ///   True from <see cref="BeginBatch"/> to <see cref="EndBatch"/>: one
      ///   batch of Git work owns the repositories, and no other may start.
      /// </summary>
      FBatchRunning : Boolean;

      /// <summary>
      ///   True while a batch is running on the UI thread itself ( Delete
      ///   Selected ).  FormCloseQuery must not wait for such a batch: it is
      ///   further up the same call stack and cannot move until the handler
      ///   returns.
      /// </summary>
      FSyncBatchRunning: Boolean;

      /// <summary>
      ///   True while FormCloseQuery is waiting for workers to stop, so that a
      ///   second close request made during the wait is turned away.
      /// </summary>
      FClosePending : Boolean;

      /// <summary>
      ///   Set when PopulateListView is suppressed during a batch; the rebuild
      ///   is then performed once the batch finishes.
      /// </summary>
      FPopulatePending: Boolean;

    /// <summary>
    ///   Loads the configuration and the repository list once the form is
    ///   visible, reports a configuration file that could not be read, and
    ///   starts the first status refresh.
    /// </summary>
    /// <param name="Msg">The posted WM_LOAD_REPOS message.</param>
    procedure WMLoadRepos( var Msg: TMessage ); message WM_LOAD_REPOS;

    /// <summary>
    ///   One-shot Application.OnIdle handler: applies and saves the style chosen
    ///   from View > Style, then unhooks itself.
    /// </summary>
    /// <param name="Sender">The application.</param>
    /// <param name="Done">Left True so the application waits for the next message.</param>
    procedure ApplyPendingStyle( Sender: TObject; var Done: Boolean );

    /// <summary>
    ///   Refreshes the status of every repository on pooled worker threads,
    ///   then rebuilds the list.  Does nothing while other work is running.
    /// </summary>
    procedure RefreshReposAsync;

    /// <summary>
    ///   Populates the list view with all repositories from the manager.
    /// </summary>
    procedure PopulateListView;

    /// <summary>
    ///   Updates a single list item with current repository data.
    /// </summary>
    /// <param name="sRepoPath">Working-tree path of the repository whose row to update.</param>
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
    ///   Fills View > Style with one radio item per VCL style linked into the
    ///   executable, in alphabetical order.
    /// </summary>
    procedure BuildStyleMenu;

    /// <summary>
    ///   Ticks the View > Style item for the style currently active.
    /// </summary>
    procedure UpdateStyleMenuChecks;

    /// <summary>
    ///   Queues the chosen style for <see cref="ApplyPendingStyle"/>. Never switches
    ///   style directly: that frees the styled menu bar's hook while its menu
    ///   loop is still on the stack, and the loop then touches the freed hook.
    /// </summary>
    /// <param name="Sender">The View > Style item clicked.</param>
    procedure mnuStyleItemClick( Sender: TObject );

    /// <summary>
    ///   Activates a VCL style by name and redraws what a style change does not
    ///   restore by itself.
    /// </summary>
    /// <param name="sStyleName">Registered style name; unknown names are ignored.</param>
    /// <returns>True when the style is now active.</returns>
    function ApplyStyle( const sStyleName: string ): Boolean;

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
    /// <param name="ARepoPath">Path of the repository whose row should refresh.</param>
    procedure QueueCommitLog( const ALog, ARepoPath: string );

    /// <summary>
    ///   Applies and saves a newly discovered delphi-indexer path on the UI
    ///   thread.
    /// </summary>
    /// <param name="APath">The resolved path to delphi-indexer.exe.</param>
    procedure QueueIndexerPathUpdate( const APath: string );

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
    ///   Renders a repository count as "1 repository" or "N repositories".
    /// </summary>
    /// <remarks>
    ///   Every count in this form was written as <c>%d repository(ies)</c>,
    ///   which reads as boilerplate in the one case that matters most - the
    ///   single repository the user is about to act on destructively. Text that
    ///   looks machine-generated invites the reader to skim it.
    /// </remarks>
    /// <param name="iCount">Number of repositories.</param>
    /// <returns>The count and its correctly pluralised noun.</returns>
    function RepositoryCountText( const iCount: Integer ): string;

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
    procedure ErrorDlg( const sMessage: string; const DlgType: TMsgDlgType = TMsgDlgType.mtError );

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
    ///   Takes the batch guard, clears any stale cancel request and disables
    ///   the controls.  Returns False ( and tells the user ) when any Git work
    ///   is already running.
    /// </summary>
    /// <returns>True if the guard was taken; False if work is already running.</returns>
    function BeginBatch: Boolean;

    /// <summary>
    ///   Releases the batch guard and applies any list rebuild deferred while
    ///   it was held.
    /// </summary>
    procedure EndBatch;

    /// <summary>
    ///   Says whether the running operation has been asked to stop.  Safe from
    ///   any thread.
    /// </summary>
    /// <returns>True once cancellation has been requested.</returns>
    function IsCancelled: Boolean;

    /// <summary>
    ///   Runs work on a pooled worker thread, then a completion handler on the
    ///   UI thread.
    /// </summary>
    /// <remarks>
    ///   The completion handler runs whether the work returned or raised, so
    ///   whatever it releases ( the batch guard, the disabled controls ) is
    ///   always released.  An exception from the work is re-raised on the UI
    ///   thread afterwards, where EurekaLog reports it.  The handler is skipped
    ///   only when the form is shutting down.
    /// </remarks>
    /// <param name="AWork">Executed on the worker; must not touch a control.</param>
    /// <param name="ADone">Executed on the UI thread once the work has ended.</param>
    procedure RunWorker( const AWork, ADone: TProc );

    /// <summary>
    ///   Releases every busy flag and re-enables the controls after an
    ///   operation failed in a way that skipped its own clean-up.
    /// </summary>
    /// <remarks>
    ///   Without it an exception in a completion handler, or in starting a
    ///   worker, left the batch guard held: every command disabled and the
    ///   window refusing to close until the process was killed.
    /// </remarks>
    procedure AbandonBusyState;

    /// <summary>
    ///   Runs one operation over a list of repositories on a worker, logging
    ///   each result as it arrives, then summarises and releases the batch guard.
    /// </summary>
    /// <remarks>
    ///   The caller must already hold the guard ( <see cref="BeginBatch"/> ).
    ///   Cancellation is honoured between repositories.
    /// </remarks>
    /// <param name="sTitle">Name of the operation, used in the log.</param>
    /// <param name="saPaths">Working-tree paths to process, in order.</param>
    /// <param name="AWork">The operation for one repository; runs on the worker.</param>
    /// <param name="bReindex">True to run the Delphi indexer over the repositories that succeeded.</param>
    /// <param name="AAfter">
    ///   Optional; called on the UI thread after the guard is released, with
    ///   the success count and the names of the repositories that failed.
    /// </param>
    procedure RunRepoBatch( const sTitle: string; const saPaths: TArray<string>; const AWork: TRepoWork;
      const bReindex: Boolean; const AAfter: TProc<Integer, TArray<string>> );

    /// <summary>
    ///   The guard for a command that must not start while Git work is running;
    ///   tells the user when it is.
    /// </summary>
    /// <returns>True when nothing is running and the command may proceed.</returns>
    function NotBusy: Boolean;

    /// <summary>
    ///   Returns the index into <see cref="FRepoCache"/> that a list row carries.
    /// </summary>
    /// <param name="AItem">The list row; may be nil.</param>
    /// <returns>The index, or -1 for a nil row.</returns>
    function RowRepoIndex( const AItem: TListItem ): Integer;

    /// <summary>
    ///   Returns the repository of the highlighted row.
    /// </summary>
    /// <param name="ARepo">Receives the cached record.</param>
    /// <returns>True when a row is highlighted and resolves to a repository.</returns>
    function SelectedRepo( out ARepo: TRepoInfo ): Boolean;

    /// <summary>
    ///   Returns the working-tree path of every ticked row, resolved once so
    ///   that a batch never depends on a list that is rebuilt underneath it.
    /// </summary>
    /// <returns>The paths, in display order; empty when nothing is ticked.</returns>
    function CheckedRepoPaths: TArray<string>;

    /// <summary>
    ///   Returns the repositories a context-menu command applies to: the
    ///   right-clicked row alone when it is not ticked, otherwise every ticked row.
    /// </summary>
    /// <returns>The working-tree paths; empty when there is no target.</returns>
    function ContextRepoPaths: TArray<string>;

    /// <summary>
    ///   Makes arbitrary text safe to use as a menu item caption: first line
    ///   only, bounded length, ampersands escaped, and never a separator.
    /// </summary>
    /// <param name="sText">The text to show.</param>
    /// <returns>The caption.</returns>
    class function MenuCaption( const sText: string ): string;

    /// <summary>
    ///   Asks the user to choose a folder.
    /// </summary>
    /// <param name="sTitle">Title of the dialog.</param>
    /// <param name="sFolder">Receives the chosen folder; empty when cancelled.</param>
    /// <returns>True when a folder was chosen.</returns>
    function PickFolder( const sTitle: string; out sFolder: string ): Boolean;

    /// <summary>
    ///   Saves the configuration and reports the outcome in the log, and in a
    ///   dialog when anything could not be saved.
    /// </summary>
    /// <param name="sWhat">What was being saved, for the message ( "Settings" ).</param>
    /// <returns>True when everything was saved.</returns>
    function SaveConfigReporting( const sWhat: string ): Boolean;

    /// <summary>
    ///   Sets the tick of every row shown from a rule, and records the result.
    /// </summary>
    /// <param name="AShouldTick">Returns True for a repository that is to be ticked.</param>
    procedure SetChecks( const AShouldTick: TFunc<TRepoInfo, Boolean> );

    /// <summary>
    ///   Makes sure GitHub credentials are configured, opening the credentials
    ///   dialog when they are not.
    /// </summary>
    /// <returns>True when credentials are available.</returns>
    function EnsureGitHubCredentials: Boolean;

    /// <summary>
    ///   Asks everything needed to publish one folder to GitHub.
    /// </summary>
    /// <param name="sFolder">The folder to publish.</param>
    /// <param name="bDropped">True when the folder arrived by drag and drop.</param>
    /// <param name="AJob">Receives the answers.</param>
    /// <returns>True when the user confirmed; False when any prompt was cancelled.</returns>
    function PromptNewRepoJob( const sFolder: string; const bDropped: Boolean; out AJob: TNewRepoJob ): Boolean;

    /// <summary>
    ///   Publishes folders to GitHub: asks about each first, then does all the
    ///   work on a worker thread.  Shared by the GitHub menu and drag and drop.
    /// </summary>
    /// <param name="saFolders">The folders to publish.</param>
    /// <param name="bDropped">True when the folders arrived by drag and drop.</param>
    procedure CreateRepositoriesFromFolders( const saFolders: TArray<string>; const bDropped: Boolean );

    /// <summary>
    ///   Runs confirmed publish jobs on a worker thread, then lists every
    ///   folder that is now a repository.  The caller holds the batch guard.
    /// </summary>
    /// <param name="AJobs">The jobs to run, in order.</param>
    procedure RunCreateJobs( const AJobs: TArray<TNewRepoJob> );

    /// <summary>
    ///   Moves the highlighted repository to a new GitHub repository, on a
    ///   worker thread and under the batch guard.
    /// </summary>
    procedure MigrateSelectedToGitHub;

    /// <summary>
    ///   Changes the GitHub visibility of the highlighted repository, on a
    ///   worker thread.
    /// </summary>
    /// <param name="bPrivate">True to make it private; False to make it public.</param>
    procedure SetSelectedVisibility( const bPrivate: Boolean );

    /// <summary>
    ///   Pulls repositories: previews what is incoming, asks, creates a backup
    ///   branch for each repository that has incoming changes, then pulls.
    /// </summary>
    /// <remarks>
    ///   A repository whose backup branch cannot be created is not pulled.
    /// </remarks>
    /// <param name="saPaths">Working-tree paths of the repositories to pull.</param>
    procedure PullRepositories( const saPaths: TArray<string> );

    /// <summary>
    ///   Runs the Delete command over the given repositories.
    /// </summary>
    /// <remarks>
    ///   The dialog lists every repository it is about to act on by name,
    ///   resolved remote and path.
    ///   <para>
    ///   When any step fails for a repository the remaining steps for that
    ///   repository are skipped, leaving it exactly as it was. Deleting the
    ///   local folder after the remote deletion had already failed would leave
    ///   the user with neither the outcome they asked for nor a clear way back.
    ///   </para>
    /// </remarks>
    /// <param name="saPaths">Working-tree paths of the repositories to delete.</param>
    procedure DeleteRepositories( const saPaths: TArray<string> );

    /// <summary>
    ///   Runs delphi-indexer over each folder.  Called on a worker thread.
    /// </summary>
    /// <remarks>
    ///   Does nothing, silently, when the indexer cannot be found.
    /// </remarks>
    /// <param name="saDirs">The repository folders to reindex.</param>
    procedure RunPendingReindexes( const saDirs: TArray<string> );

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
    ///   Enables Migrate to GitHub only while a row is highlighted and nothing
    ///   is running.
    /// </summary>
    procedure UpdateMenuSelectionState;
  public
  end;

var
  /// <summary>
  ///   The application's main form, created by the project file.
  /// </summary>
  MainForm          : TMainForm;

implementation

uses
  Winapi.ShellAPI, Winapi.CommCtrl,
  Vcl.Dialogs, Vcl.Themes, Vcl.StyledTaskDialog,
  System.StrUtils, System.Types, System.Generics.Defaults, System.SyncObjs, System.IOUtils,
  OtlParallel,
  uNewRepositoryDialog, uDeleteRepositoryDialog, uGitHubSettings, uTemplateSettings;

{$R *.dfm}

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
  FRefreshing       := False;
  FBatchRunning     := False;
  FSyncBatchRunning := False;
  FClosePending     := False;
  FPopulatePending  := False;
  FPendingStyle     := -1;
  FFilteredIndices  := TList<Integer>.Create;
  FRepoManager      := TGitRepoManager.Create;

  // Enable Ctrl+Enter shortcut for Commit & Push
  KeyPreview        := True;
  OnKeyDown         := FormKeyDown;

  // Wire up column click event
  lvRepos.OnColumnClick := lvReposColumnClick;

  // Set initial filter menu state
  UpdateFilterMenuChecks;
  BuildStyleMenu;

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

procedure TMainForm.WMLoadRepos( var Msg: TMessage );
var
  bLoaded           : Boolean;
  iCount            : Integer;
begin

  Screen.Cursor     := crHourGlass;

  try
    Log( 'Loading configuration...' );
    Update;

    bLoaded         := FRepoManager.LoadConfig;

    if ( not bLoaded ) then
      Log( Format( 'Warning: %s', [ FRepoManager.LastLoadError ] ) );

    // Empty means no choice has been saved yet: keep the start-up default.
    var sStyle      := FRepoManager.StyleName;

    if ( not sStyle.IsEmpty ) and ( not ApplyStyle( sStyle ) ) then
      Log( Format( 'Warning: Saved style "%s" is not available', [ sStyle ] ) );

    // FRepoCache is the UI-side snapshot and is not filled until
    // PopulateListView below, so ask the manager for the live count.
    iCount          := FRepoManager.ReposCount;
    Log( Format( 'Found %s', [ RepositoryCountText( iCount ) ] ) );

    // Show list immediately with unknown status
    PopulateListView;
    UpdateGroupFilterCombo;
    SetColumnSortArrow( FSortColumn, FSortAscending );
    Update;

    Log( '' );
    Log( 'Ready. Drag and drop repository folders to add them.' );
    Log( 'Click column headers to sort. Use View > Filter to filter by status.' );
  finally
    Screen.Cursor   := crDefault;
  end;

  // Said in a dialog as well as in the log: the user is looking at an empty
  // list where their repositories used to be, and has to be told where the
  // file went before doing anything else.
  if ( not bLoaded ) then
    ErrorDlg( FRepoManager.LastLoadError, mtWarning );

  // Refresh repositories asynchronously to keep UI responsive
  if iCount > 0 then
    RefreshReposAsync;

end;

function TMainForm.IsCancelled: Boolean;
begin

  Result            := TInterlocked.CompareExchange( FCancelRefresh, 0, 0 ) <> 0;

end;

procedure TMainForm.RunWorker( const AWork, ADone: TProc );
begin

  TInterlocked.Increment( FActiveWorkers );
  Screen.Cursor     := crHourGlass;

  try
    // OmniThreadLibrary runs AWork on a pooled thread and then calls the
    // OnTerminated handler on THIS thread, whatever happened in between.  If
    // AWork raised, the handler still runs first - so the buttons come back
    // and the batch guard is released - and the exception is then re-raised
    // here, where EurekaLog reports it.  The hand-rolled threads this replaces
    // re-raised on the worker instead, which skipped the completion call and
    // left the window disabled with an hourglass for the rest of the session.
    Parallel.Async(
      procedure
      begin

        try
          AWork( );
        finally
          TInterlocked.Decrement( FActiveWorkers );
        end;

      end,
      Parallel.TaskConfig.OnTerminated(
        procedure
        begin

          if FShuttingDown then
            Exit;

          // The worker's log lines travel by TThread.Queue and this call by a
          // window message, so they can arrive in either order.  Draining the
          // queue first keeps the summary below the lines it summarises.
          CheckSynchronize;
          Screen.Cursor := crDefault;

          try
            ADone( );
          except
            AbandonBusyState;
            raise;
          end;

        end ) );
  except
    TInterlocked.Decrement( FActiveWorkers );
    Screen.Cursor   := crDefault;
    AbandonBusyState;
    raise;
  end;

end;

procedure TMainForm.AbandonBusyState;
begin

  FRefreshing       := False;
  FSyncBatchRunning := False;

  if FBatchRunning then
    EndBatch
  else
    SetBatchUIState( False );

end;

procedure TMainForm.RunRepoBatch( const sTitle: string; const saPaths: TArray<string>; const AWork: TRepoWork;
  const bReindex: Boolean; const AAfter: TProc<Integer, TArray<string>> );
var
  iSuccess          : Integer;
  saFailed          : TArray<string>;
  bFinished         : Boolean;
begin

  // Written by the worker, read by the completion handler.  The handler runs
  // only after the worker has ended, so the two never touch them together.
  iSuccess          := 0;
  saFailed          := nil;
  bFinished         := False;

  RunWorker(
    procedure
    var
      saDone        : TArray<string>;
    begin

      for var sPath in saPaths do
      begin
        if IsCancelled then
        begin
          LogSafe( Format( '%s cancelled.', [ sTitle ] ) );
          Break;
        end;

        var rRepo: TRepoInfo;
        var sName   := if FRepoManager.GetRepoSnapshotByPath( sPath, rRepo ) then rRepo.Name else sPath;
        var sLog: string;

        if AWork( sPath, sLog ) then
        begin
          Inc( iSuccess );
          saDone    := saDone + [ sPath ];
        end
        else
          saFailed  := saFailed + [ sName ];

        sLog        := sLog.TrimRight;

        if ( not sLog.StartsWith( '===' ) ) then
          sLog      := Format( '=== %s: %s ===%s%s', [ sTitle, sName, sLineBreak, sLog ] );

        // Via a method call, so this iteration's text gets its own capture
        // frame - see QueueCommitLog's remarks.
        QueueCommitLog( sLog, sPath );
      end;

      // Still on the worker: the indexer can take minutes over a large tree.
      if bReindex then
        RunPendingReindexes( saDone );

      bFinished     := True;

    end,
    procedure
    begin

      // The worker was stopped by an exception ( reported once this handler
      // returns ).  Without this entry the caller would announce a success
      // for a batch that never reached some of its repositories.
      if ( not bFinished ) then
        saFailed    := saFailed + [ '(stopped on an unexpected error before every repository was processed)' ];

      Log( Format( '%s completed: %d of %d successful.', [ sTitle, iSuccess, Length( saPaths ) ] ) );

      if Length( saFailed ) > 0 then
        Log( Format( 'Not completed: %s', [ string.Join( ', ', saFailed ) ] ) );

      EndBatch;
      ScrollLogToEnd;

      if Assigned( AAfter ) then
        AAfter( iSuccess, saFailed );

    end );

end;

procedure TMainForm.RefreshReposAsync;
begin

  if IsBusy then
  begin
    Log( 'Another operation is already running - refresh skipped.' );
    Exit;
  end;

  if FRepoManager.ReposCount = 0 then
    Exit;

  FRefreshing       := True;
  TInterlocked.Exchange( FCancelRefresh, 0 );
  SetBatchUIState( True );

  RunWorker(
    procedure
    begin

      // RefreshAllStatusParallel snapshots under the lock and writes back by
      // matching on path, so it is unaffected by the list changing under it.
      FRepoManager.RefreshAllStatusParallel(
        procedure( AName: string )
        begin
          LogSafe( Format( 'Checked %s', [ AName ] ) );
        end,
        function: Boolean
        begin
          Result    := IsCancelled;
        end );

    end,
    procedure
    begin

      FRefreshing   := False;
      SetBatchUIState( False );

      // Shown whether or not it was cancelled: what was refreshed is real.
      PopulateListView;
      UpdateGroupFilterCombo;

      if IsCancelled then
        Log( 'Refresh cancelled.' )
      else
        Log( 'Refresh complete.' );

    end );

end;

procedure TMainForm.FormCloseQuery( Sender: TObject; var CanClose: Boolean );
begin

  CanClose          := True;

  // Asked again from inside the wait below ( a second click on the close box ).
  if FClosePending then
  begin
    CanClose        := False;
    Exit;
  end;

  if ( not IsBusy ) then
    Exit;

  // Refuse to close while Git work is in flight, rather than closing and
  // hoping the wait in FormDestroy is long enough.
  if StyledMessageDlg( 'Git operations are still running.' + sLineBreak + sLineBreak +
    'Cancel them and close once they have stopped?', mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
  begin
    CanClose        := False;
    Exit;
  end;

  TInterlocked.Exchange( FCancelRefresh, 1 );
  Log( 'Cancelling background work...' );

  // A batch that runs on this thread ( Delete Selected ) is further up this
  // very call stack, pumping messages between repositories.  Waiting here
  // would wait for something that cannot move until this handler returns.
  if FSyncBatchRunning then
  begin
    CanClose        := False;
    StyledMessageDlg( 'The operation will stop after the repository it is working on. ' +
      'Close the window again once it has.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  FClosePending     := True;
  Screen.Cursor     := crHourGlass;

  try
    // Cancellation is checked between repositories, so a drain normally takes
    // only as long as the Git call in flight.  Messages are pumped so that
    // each worker's completion handler runs and releases its own state; every
    // command is disabled meanwhile, and a repeated close is turned away
    // above.  Bounded, so a wedged network call cannot lock the user out.
    var iWaited     := 0;

    while IsBusy and ( iWaited < WORKER_SHUTDOWN_TIMEOUT_MS ) do
    begin
      Application.ProcessMessages;
      Sleep( 20 );
      Inc( iWaited, 20 );
    end;
  finally
    FClosePending   := False;
    Screen.Cursor   := crDefault;
  end;

  CanClose          := not IsBusy;

  // The cancel request stays set for the worker that has not stopped yet; it
  // is cleared when the next operation starts ( BeginBatch, RefreshReposAsync ).
  // It used to stay set for good, so every later refresh skipped every
  // repository and never repainted the list.
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
  Application.OnIdle := nil;

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
      FRepoManager  := nil;
    end;
  end;

  SetLength( FRepoCache, 0 );
  FreeAndNil( FFilteredIndices );

end;

procedure TMainForm.RefreshRepoCache;
begin

  if Assigned( FRepoManager ) then
    FRepoCache      := FRepoManager.SnapshotAll
  else
    SetLength( FRepoCache, 0 );

end;

function TMainForm.RepoAt( const iIndex: Integer; out ARepo: TRepoInfo ): Boolean;
begin

  Result            := ( iIndex >= 0 ) and ( iIndex <= High( FRepoCache ) );

  if Result then
    ARepo           := FRepoCache[ iIndex ];

end;

function TMainForm.RepoPathAt( const iIndex: Integer ): string;
begin

  Result            := '';

  if ( iIndex >= 0 ) and ( iIndex <= High( FRepoCache ) ) then
    Result          := FRepoCache[ iIndex ].Path;

end;

function TMainForm.RepositoryCountText( const iCount: Integer ): string;
begin

  if iCount = 1 then
    Result          := '1 repository'
  else
    Result          := Format( '%d repositories', [ iCount ] );

end;

procedure TMainForm.ErrorDlg( const sMessage: string; const DlgType: TMsgDlgType );
begin

  StyledMessageDlg( RedactSecrets( sMessage ), DlgType, [ mbOK ], 0 );

end;

function TMainForm.IsBusy: Boolean;
begin

  Result            := FRefreshing or FBatchRunning or ( TInterlocked.CompareExchange( FActiveWorkers, 0, 0 ) > 0 );

end;

function TMainForm.NotBusy: Boolean;
begin

  Result            := not IsBusy;

  if ( not Result ) then
    StyledMessageDlg( 'An operation is already running. Please wait for it to finish.', mtInformation, [ mbOK ], 0 );

end;

function TMainForm.RowRepoIndex( const AItem: TListItem ): Integer;
begin

  Result            := -1;

  if Assigned( AItem ) then
    Result          := Integer( NativeInt( AItem.Data ) );

end;

function TMainForm.SelectedRepo( out ARepo: TRepoInfo ): Boolean;
begin

  Result            := Assigned( lvRepos.Selected ) and RepoAt( RowRepoIndex( lvRepos.Selected ), ARepo );

end;

function TMainForm.CheckedRepoPaths: TArray<string>;
begin

  Result            := nil;

  for var iI := 0 to lvRepos.Items.Count - 1 do
  begin
    if ( not lvRepos.Items[ iI ].Checked ) then
      Continue;

    var sPath       := RepoPathAt( RowRepoIndex( lvRepos.Items[ iI ] ) );

    if ( not sPath.IsEmpty ) then
      Result        := Result + [ sPath ];
  end;

end;

function TMainForm.ContextRepoPaths: TArray<string>;
var
  rRepo             : TRepoInfo;
begin

  // The row under the right-click decides.  Ticked: the command means every
  // ticked row.  Not ticked: it means that row and nothing else.  The context
  // menu used to act on the ticked rows whichever row it was opened on, so
  // right-clicking one repository could re-group or delete several others.
  if SelectedRepo( rRepo ) and ( not lvRepos.Selected.Checked ) then
    Result          := [ rRepo.Path ]
  else
    Result          := CheckedRepoPaths;

end;

class function TMainForm.MenuCaption( const sText: string ): string;
const
  MAX_CAPTION_LENGTH = 120;
begin

  // First line only, and short enough to be a menu item.
  Result            := sText.Trim;

  var iBreak        := Result.IndexOfAny( [ #13, #10 ] );

  if iBreak >= 0 then
    Result          := Result.Substring( 0, iBreak ).TrimRight;

  if Length( Result ) > MAX_CAPTION_LENGTH then
    Result          := Result.Substring( 0, MAX_CAPTION_LENGTH ) + '...';

  // A menu reads '&' as "underline the next letter" and a lone '-' as "draw a
  // separator", so "Fix A&B" lost its ampersand and a template of "-" became
  // an unclickable line.
  Result            := Result.Replace( '&', '&&' );

  if Result = '-' then
    Result          := '- ';

end;

function TMainForm.PickFolder( const sTitle: string; out sFolder: string ): Boolean;
begin

  sFolder           := '';

  var oDialog       := TFileOpenDialog.Create( Self );

  try
    oDialog.Title   := sTitle;
    oDialog.Options := oDialog.Options + [ fdoPickFolders, fdoPathMustExist, fdoForceFileSystem ];
    Result          := oDialog.Execute;

    if Result then
      sFolder       := oDialog.FileName;
  finally
    oDialog.Free;
  end;

end;

function TMainForm.SaveConfigReporting( const sWhat: string ): Boolean;
begin

  // SaveConfig returns True when the file was written, and still leaves a
  // message when the one thing it could not write was a new access token.
  Result            := FRepoManager.SaveConfig and FRepoManager.LastSaveError.IsEmpty;

  if Result then
    Log( Format( '%s saved.', [ sWhat ] ) )
  else
  begin
    var sError      := FRepoManager.LastSaveError;

    Log( Format( '%s NOT fully saved: %s', [ sWhat, sError ] ) );
    ErrorDlg( sError, mtWarning );
  end;

end;

procedure TMainForm.SetBatchUIState( const bBusy: Boolean );
begin

  if FShuttingDown then
    Exit;

  btnPullSelected.Enabled := not bBusy;
  btnResolveConflicts.Enabled := not bBusy;
  btnPushOnly.Enabled := not bBusy;
  btnForcePush.Enabled := not bBusy;
  btnSelectModified.Enabled := not bBusy;
  btnSelectAll.Enabled := not bBusy;
  btnSelectNone.Enabled := not bBusy;
  mnuAddRepository.Enabled := not bBusy;
  mnuRemoveSelected.Enabled := not bBusy;
  mnuDeleteSelected.Enabled := not bBusy;
  mnuRefreshStatus.Enabled := not bBusy;
  mnuSettings.Enabled := not bBusy;
  mnuTemplateSettings.Enabled := not bBusy;
  mnuInitPushGitHub.Enabled := not bBusy;
  mnuGitHubSettings.Enabled := not bBusy;
  pmRepos.AutoPopup := not bBusy;

  // These two also depend on the rows, so they work the answer out themselves.
  UpdateCommitButtonState;
  UpdateMenuSelectionState;

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
///   Registers the window for folder drag-and-drop each time its handle is created.
/// </summary>
procedure TMainForm.CreateWnd;
begin

  inherited;
  DragAcceptFiles( Handle, True );

end;

/// <summary>
///   Fills View > Style with one radio item per VCL style linked into the executable.
/// </summary>
procedure TMainForm.BuildStyleMenu;
begin

  FStyleNames       := TStyleManager.StyleNames;
  TArray.Sort<string>( FStyleNames );
  mnuStyle.Clear;

  for var i := 0 to High( FStyleNames ) do
  begin
    var Item        := TMenuItem.Create( mnuStyle );
    Item.Caption    := FStyleNames[ i ];
    Item.Tag        := i;
    Item.RadioItem  := True;
    Item.GroupIndex := 1;
    Item.OnClick    := mnuStyleItemClick;
    mnuStyle.Add( Item );
  end;

  UpdateStyleMenuChecks;

end;

/// <summary>
///   Ticks the View > Style item for the style currently active.
/// </summary>
procedure TMainForm.UpdateStyleMenuChecks;
begin

  var sActive       := TStyleManager.ActiveStyle.Name;

  for var i := 0 to mnuStyle.Count - 1 do
    mnuStyle.Items[ i ].Checked := SameText( FStyleNames[ mnuStyle.Items[ i ].Tag ], sActive );

end;

/// <summary>
///   Queues the chosen style; it is applied after the menu loop has exited.
/// </summary>
procedure TMainForm.mnuStyleItemClick( Sender: TObject );
begin

  // Changing style here, inside the menu loop, frees TMainMenuBarStyleHook
  // under TrackMenuFromItem, which then calls Invalidate on it (EAccessViolation).
  // A posted message is no better: ProcessMenuLoop runs one more
  // PeekMessage/DispatchMessage pass after the click, and then calls MenuExit on
  // itself. OnIdle fires only from TApplication.HandleMessage, which that loop
  // never calls, so by then the menu loop is gone.
  FPendingStyle     := ( Sender as TMenuItem ).Tag;
  Application.OnIdle := ApplyPendingStyle;

end;

procedure TMainForm.ApplyPendingStyle( Sender: TObject; var Done: Boolean );
begin

  Application.OnIdle := nil;

  var iIndex        := FPendingStyle;

  FPendingStyle     := -1;

  if ( iIndex < 0 ) or ( iIndex > High( FStyleNames ) ) then
    Exit;

  var sStyleName    := FStyleNames[ iIndex ];

  if ( not ApplyStyle( sStyleName ) ) then
  begin
    Log( Format( 'Could not apply style "%s"', [ sStyleName ] ) );
    Exit;
  end;

  FRepoManager.StyleName := sStyleName;

  // Logged, not put in a dialog: the style is applied either way, and only
  // its being remembered is in doubt.
  if ( not FRepoManager.SaveConfig ) then
    Log( Format( 'The style choice could not be saved: %s', [ FRepoManager.LastSaveError ] ) );

end;

/// <summary>
///   Activates a VCL style by name and redraws what a style change does not restore.
/// </summary>
function TMainForm.ApplyStyle( const sStyleName: string ): Boolean;
begin

  if SameText( TStyleManager.ActiveStyle.Name, sStyleName ) then
    Result          := True
  else
    Result          := TStyleManager.TrySetStyle( sStyleName, False );

  // The header sort arrow is drawn by a header message, not stored by the VCL,
  // so a recreated list view loses it.
  if Result then
    SetColumnSortArrow( FSortColumn, FSortAscending );

  UpdateStyleMenuChecks;

end;

procedure TMainForm.UpdateCommitButtonState;
begin

  var bHasChecked   := False;

  for var iI := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ iI ].Checked then
    begin
      bHasChecked   := True;
      Break;
    end;
  end;

  // Off for the whole of ANY operation, not only a commit.  It used to test
  // the commit flag alone, so typing in the message box during a refresh or a
  // pull re-enabled the button and Ctrl+Enter then started a commit alongside.
  btnCommitPush.Enabled := bHasChecked and ( not Trim( edtCommitMessage.Text ).IsEmpty ) and ( not IsBusy );

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
  bNewState         : Boolean;
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
    bNewState       := not lvRepos.Items[ FLastClickedIndex ].Checked;

    FUpdatingList   := True;

    try
      for var i := iStartIndex to iEndIndex do
        lvRepos.Items[ i ].Checked := bNewState;
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

procedure TMainForm.WMDropFiles( var Msg: TWMDropFiles );
var
  saDropped         : TArray<string>;
  saNewFolders      : TArray<string>;
  iAdded            : Integer;
  iSkipped          : Integer;
begin

  Msg.Result        := 0;

  try
    var iFileCount  := DragQueryFile( Msg.Drop, $FFFFFFFF, nil, 0 );

    for var iI := 0 to Integer( iFileCount ) - 1 do
    begin
      var sPath: string;
      var iLen      := DragQueryFile( Msg.Drop, iI, nil, 0 );

      SetLength( sPath, iLen );
      DragQueryFile( Msg.Drop, iI, PChar( sPath ), iLen + 1 );
      saDropped     := saDropped + [ sPath ];
    end;
  finally
    DragFinish( Msg.Drop );
  end;

  // A drop arrives as a message, so the disabled menus do not stop it.  It
  // used to add repositories, and start an initialise-and-push, in the middle
  // of whatever batch was running.
  if IsBusy then
  begin
    Log( 'Drop ignored - an operation is running. Drop the folders again when it has finished.' );
    Exit;
  end;

  iAdded            := 0;
  iSkipped          := 0;

  for var sPath in saDropped do
  begin
    if ( not TDirectory.Exists( sPath ) ) then
    begin
      Inc( iSkipped );
      Continue;
    end;

    // Not a repository yet: offered for creation once the rest are in.
    if ( not TGitRepoManager.HasGitEntry( sPath ) ) then
    begin
      saNewFolders  := saNewFolders + [ sPath ];
      Continue;
    end;

    if FRepoManager.AddRepository( sPath ) then
    begin
      Log( Format( 'Added repository: %s', [ sPath ] ) );
      Inc( iAdded );
    end
    else
    begin
      Log( Format( 'Already in the list: %s', [ sPath ] ) );
      Inc( iSkipped );
    end;
  end;

  if iAdded > 0 then
  begin
    PopulateListView;
    UpdateGroupFilterCombo;
  end;

  if ( iAdded > 0 ) or ( iSkipped > 0 ) then
    Log( Format( 'Drop complete: %d added, %d skipped', [ iAdded, iSkipped ] ) );

  if Length( saNewFolders ) > 0 then
    CreateRepositoriesFromFolders( saNewFolders, True );

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
    var iRepoIndex  := Integer( lvRepos.Items[ iI ].Data );

    if ( iRepoIndex < 0 ) or ( iRepoIndex > High( FRepoCache ) ) then
      Continue;

    if ( not SameText( FRepoCache[ iRepoIndex ].Path, sRepoPath ) ) then
      Continue;

    FRepoCache[ iRepoIndex ] := Repo;
    FUpdatingList   := True;

    try
      var Item      := lvRepos.Items[ iI ];
      Item.Caption  := Repo.Name;
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

  // RunPendingReindexes executes on a worker thread, and this persists the
  // configuration.  That belongs on the UI thread, which owns the settings.
  TThread.Queue( nil,
    procedure
    begin
      if FShuttingDown or ( not Assigned( FRepoManager ) ) then
        Exit;

      FRepoManager.DelphiIndexerPath := APath;

      if ( not FRepoManager.SaveConfig ) then
        Log( Format( 'The indexer path could not be saved: %s', [ FRepoManager.LastSaveError ] ) );
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
begin

  for var iI := 0 to lvRepos.Items.Count - 1 do
  begin
    var sPath       := RepoPathAt( RowRepoIndex( lvRepos.Items[ iI ] ) );

    if ( not sPath.IsEmpty ) then
      FRepoManager.SetRepoSelected( sPath, lvRepos.Items[ iI ].Checked );
  end;

end;

function TMainForm.BeginBatch: Boolean;
begin

  // Gate on every kind of Git work: another batch, a refresh, or a worker
  // that is still running.
  Result            := NotBusy;

  if ( not Result ) then
    Exit;

  FBatchRunning     := True;
  FPopulatePending  := False;

  // A cancel request left over from a close that was abandoned must not stop
  // the batch that is starting now.
  TInterlocked.Exchange( FCancelRefresh, 0 );

  // The flag alone is not a guard.  Disabling the controls is.
  SetBatchUIState( True );

end;

procedure TMainForm.EndBatch;
begin

  FBatchRunning     := False;

  if FShuttingDown then
    Exit;

  SetBatchUIState( False );

  if FPopulatePending then
  begin
    FPopulatePending := False;
    PopulateListView;
  end;

end;

procedure TMainForm.mnuAddRepositoryClick( Sender: TObject );
var
  sFolder           : string;
begin

  if ( not NotBusy ) then
    Exit;

  if ( not PickFolder( 'Select Git Repository Folder', sFolder ) ) then
    Exit;

  // A linked worktree or a submodule has a .git FILE, and is a repository
  // just the same.  Testing for a folder turned those away.
  if ( not TGitRepoManager.HasGitEntry( sFolder ) ) then
  begin
    StyledMessageDlg( 'The selected folder is not a Git repository.' + sLineBreak + sLineBreak +
      'To publish a folder that is not one yet, use GitHub > Initialise && Push to GitHub.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  if FRepoManager.AddRepository( sFolder ) then
  begin
    PopulateListView;
    UpdateGroupFilterCombo;
    Log( Format( 'Added repository: %s', [ sFolder ] ) );
  end
  else
    Log( Format( 'Already in the list: %s', [ sFolder ] ) );

end;

procedure TMainForm.mnuRemoveSelectedClick( Sender: TObject );
begin

  // Reached by Alt+F, R whatever the menu shows, so it checks for itself.
  if ( not NotBusy ) then
    Exit;

  var saPaths       := CheckedRepoPaths;

  if Length( saPaths ) = 0 then
  begin
    StyledMessageDlg( 'Please tick one or more repositories to remove.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg( Format( 'Remove %s from the list?' + sLineBreak + sLineBreak +
    'Nothing on disk or on the remote is touched.', [ RepositoryCountText( Length( saPaths ) ) ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  for var sPath in saPaths do
  begin
    FRepoManager.RemoveRepository( sPath );
    Log( Format( 'Removed repository: %s', [ sPath ] ) );
  end;

  PopulateListView;
  UpdateGroupFilterCombo;

end;

procedure TMainForm.mnuDeleteSelectedClick( Sender: TObject );
begin

  DeleteRepositories( CheckedRepoPaths );

end;

procedure TMainForm.pmDeleteSelectedClick( Sender: TObject );
begin

  DeleteRepositories( ContextRepoPaths );

end;

procedure TMainForm.DeleteRepositories( const saPaths: TArray<string> );
var
  saNames           : TArray<string>;
  saLines           : TArray<string>;
  rOptions          : TDeleteRepositoryOptions;
  sRemoteTarget     : string;
  sError            : string;
  baRemote          : TArray<Boolean>;
  bAnyRemote        : Boolean;
  bStopped          : Boolean;
  iCount            : Integer;
  iSuccess          : Integer;
begin

  if ( not NotBusy ) then
    Exit;

  bStopped          := False;
  iCount            := Length( saPaths );

  if iCount = 0 then
  begin
    StyledMessageDlg( 'Please tick one or more repositories to delete.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  SetLength( saNames, iCount );
  SetLength( saLines, iCount );
  SetLength( baRemote, iCount );
  bAnyRemote        := False;

  // Resolving each remote runs a pair of quick local Git calls, so a large
  // selection is a visible pause before the dialog appears.
  Screen.Cursor     := crHourGlass;

  try
    for var iI := 0 to iCount - 1 do
    begin
      saNames[ iI ] := ExtractFileName( saPaths[ iI ] );

      // Name the exact remote, not just its provider. The user is authorising
      // an irreversible deletion, and two entries can point at repositories of
      // the same name under different owners.
      baRemote[ iI ] := FRepoManager.DescribeRemoteDeleteTarget( saPaths[ iI ], sRemoteTarget );

      if baRemote[ iI ] then
        bAnyRemote  := True
      else
        sRemoteTarget := Format( '[no deletable remote - %s]', [ sRemoteTarget ] );

      // Remote BEFORE the path. A working-tree path is long and unbounded -
      // whatever comes after it is what gets pushed off the right-hand edge of
      // the list, and the remote is the detail the user most needs to check.
      saLines[ iI ] := Format( '%s  -  %s  -  %s', [ saNames[ iI ], RedactSecrets( sRemoteTarget ), saPaths[ iI ] ] );
    end;
  finally
    Screen.Cursor   := crDefault;
  end;

  if ( not TDeleteRepositoryForm.Execute( saLines, bAnyRemote, rOptions ) ) then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  // This batch stays on the UI thread: the shell's own Recycle Bin dialogs
  // are owned by this window.  FormCloseQuery needs to know that.
  FSyncBatchRunning := True;
  iSuccess          := 0;

  try
    Screen.Cursor   := crHourGlass;

    try
      for var iI := 0 to iCount - 1 do
      begin
        // Asked for by closing the window.  It used to be ignored here, so
        // the loop went on deleting after the user had said stop.
        // Pumped at the TOP, so that a run of failures ( each a Continue )
        // still lets a close request through.
        Application.ProcessMessages;

        if IsCancelled then
        begin
          Log( Format( 'Delete cancelled - %s not processed.', [ RepositoryCountText( iCount - iI ) ] ) );
          bStopped  := True;
          Break;
        end;

        Log( Format( '=== Deleting %s ===', [ saNames[ iI ] ] ) );

        if rOptions.DeleteRemote then
        begin
          // The dialog listed this one as having no remote that can be
          // deleted, so there is no remote step to fail: the rest goes ahead.
          // It used to be attempted anyway, fail, and leave the repository
          // untouched and counted as an error.
          if ( not baRemote[ iI ] ) then
            Log( '  No remote this application can delete - remote step skipped.' )
          else if FRepoManager.DeleteRemoteRepository( saPaths[ iI ], sError ) then
            Log( '  Remote repository deleted.' )
          else
          begin
            // Stop here for this repository. Going on to delete the local
            // folder would destroy the working copy while the remote the user
            // asked to remove is still there.
            Log( Format( '  Remote deletion FAILED: %s', [ sError ] ) );
            Log( '  Local folder and list entry left untouched.' );
            Continue;
          end;
        end;

        if rOptions.DeleteLocal then
        begin
          if FRepoManager.DeleteLocalRepository( saPaths[ iI ], Handle, sError ) then
            Log( '  Local folder sent to the Recycle Bin.' )
          else
          begin
            // The entry is deliberately kept: it is the only record of where
            // the folder was, and the user needs it to retry.
            Log( Format( '  Local folder deletion FAILED: %s', [ sError ] ) );
            Log( '  List entry kept so the deletion can be retried.' );
            Continue;
          end;
        end;

        if rOptions.RemoveEntry then
        begin
          FRepoManager.RemoveRepository( saPaths[ iI ] );
          Log( '  Removed from the list.' );
        end;

        Inc( iSuccess );
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    Log( Format( 'Delete completed: %d of %s fully processed.', [ iSuccess, RepositoryCountText( iCount ) ] ) );
  finally
    FSyncBatchRunning := False;
    EndBatch;
  end;

  PopulateListView;
  UpdateGroupFilterCombo;
  ScrollLogToEnd;

  // Not after a cancel: what was not reached did not fail, and the window is
  // on its way to closing.
  if ( iSuccess < iCount ) and ( not bStopped ) then
    ErrorDlg( Format( '%s could not be deleted. See the log for the reason in each case.',
      [ RepositoryCountText( iCount - iSuccess ) ] ), mtWarning );

end;

procedure TMainForm.mnuRefreshStatusClick( Sender: TObject );
begin

  if IsBusy then
    Exit;

  Log( Format( 'Refreshing %s...', [ RepositoryCountText( FRepoManager.ReposCount ) ] ) );
  RefreshReposAsync;

end;

/// <summary>
///   Handles the File > Exit menu click.
/// </summary>
procedure TMainForm.mnuExitClick( Sender: TObject );
begin

  Close;

end;

procedure TMainForm.btnCommitPushClick( Sender: TObject );
const
  MAX_NAMES_SHOWN   = 12;
var
  sMessage          : string;
  saPaths           : TArray<string>;
  saSkipped         : TArray<string>;
  rRepo             : TRepoInfo;
begin

  var sSummary      := Trim( edtCommitMessage.Text );

  if sSummary.IsEmpty then
  begin
    StyledMessageDlg( 'Please enter a commit message.', mtWarning, [ mbOK ], 0 );
    edtCommitMessage.SetFocus;
    Exit;
  end;

  // Build full commit message with optional details
  var sDetails      := Trim( mmoDetails.Text );

  if sDetails.IsEmpty then
    sMessage        := sSummary
  else
    sMessage        := Format( '%s%s%s%s', [ sSummary, sLineBreak, sLineBreak, sDetails ] );

  // Collect the targets ONCE, as paths, and keep the ticked rows that are NOT
  // being committed as well.  They used to be dropped without a word: tick
  // five, two are not Modified, and the prompt said "Commit and push 3
  // repositories?" with nothing to say which three.
  for var iI := 0 to lvRepos.Items.Count - 1 do
  begin
    if ( not lvRepos.Items[ iI ].Checked ) or ( not RepoAt( RowRepoIndex( lvRepos.Items[ iI ] ), rRepo ) ) then
      Continue;

    if rRepo.Status = rsModified then
      saPaths       := saPaths + [ rRepo.Path ]
    else
      saSkipped     := saSkipped + [ Format( '%s  (%s)', [ rRepo.Name, rRepo.StatusText ] ) ];
  end;

  var iCount        := Length( saPaths );

  if iCount = 0 then
  begin
    StyledMessageDlg( 'None of the ticked repositories is Modified, so there is nothing to commit.' + sLineBreak +
      sLineBreak + 'Use Push Only for a repository that shows Push Required.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  var sPrompt       := Format( 'Commit and push %s?', [ RepositoryCountText( iCount ) ] );

  if Length( saSkipped ) > 0 then
  begin
    sPrompt         := Format( '%s%s%s%s ticked but not Modified, and will be SKIPPED:%s%s', [ sPrompt, sLineBreak,
      sLineBreak, RepositoryCountText( Length( saSkipped ) ), sLineBreak,
      string.Join( sLineBreak, Copy( saSkipped, 0, MAX_NAMES_SHOWN ) ) ] );

    if Length( saSkipped ) > MAX_NAMES_SHOWN then
      sPrompt       := Format( '%s%s... and %d more (all are listed in the log)', [ sPrompt, sLineBreak,
        Length( saSkipped ) - MAX_NAMES_SHOWN ] );
  end;

  if StyledMessageDlg( sPrompt, mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  for var sSkipped in saSkipped do
    Log( Format( 'Skipped (not Modified): %s', [ sSkipped ] ) );

  RunRepoBatch( 'Commit & Push', saPaths,
    function( const sRepoPath: string; out sLog: string ): Boolean
    begin
      // CommitAndPush refreshes the row's status itself, success or failure.
      Result        := FRepoManager.CommitAndPush( sRepoPath, sMessage, sLog );
    end,
    True,
    procedure( iSuccess: Integer; saFailed: TArray<string> )
    begin

      // The details are kept while anything is outstanding, so that the same
      // message can be used again for whatever did not go through.
      if iSuccess = iCount then
      begin
        mmoDetails.Clear;
        pnlDetails.Visible := False;
      end;

      // The window is closing, and the log already has it all.
      if IsCancelled then
        Exit;

      if Length( saFailed ) = 0 then
        StyledMessageDlg( Format( '%s committed and pushed.', [ RepositoryCountText( iSuccess ) ] ),
          mtInformation, [ mbOK ], 0 )
      else
        ErrorDlg( Format( '%d of %d completed.' + sLineBreak + sLineBreak + 'NOT completed:' + sLineBreak + '%s' +
          sLineBreak + sLineBreak + 'The log gives the reason for each. A repository that was committed but ' +
          'not pushed now shows Push Required.', [ iSuccess, iCount, string.Join( sLineBreak, saFailed ) ] ),
          mtWarning );

    end );

end;

procedure TMainForm.SetChecks( const AShouldTick: TFunc<TRepoInfo, Boolean> );
var
  rRepo             : TRepoInfo;
begin

  FUpdatingList     := True;

  try
    for var iI := 0 to lvRepos.Items.Count - 1 do
      lvRepos.Items[ iI ].Checked := RepoAt( RowRepoIndex( lvRepos.Items[ iI ] ), rRepo ) and AShouldTick( rRepo );
  finally
    FUpdatingList   := False;
  end;

  // lvReposItemChecked is suppressed while FUpdatingList is set, so the
  // records must be brought up to date explicitly.
  SyncCheckedStateToManager;
  UpdateCommitButtonState;

end;

procedure TMainForm.btnSelectModifiedClick( Sender: TObject );
begin

  SetChecks(
    function( ARepo: TRepoInfo ): Boolean
    begin
      Result        := ARepo.Status = rsModified;
    end );

end;

procedure TMainForm.btnSelectAllClick( Sender: TObject );
begin

  SetChecks(
    function( ARepo: TRepoInfo ): Boolean
    begin
      Result        := True;
    end );

end;

procedure TMainForm.btnSelectNoneClick( Sender: TObject );
begin

  SetChecks(
    function( ARepo: TRepoInfo ): Boolean
    begin
      Result        := False;
    end );

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

procedure TMainForm.mnuGitHubSettingsClick( Sender: TObject );
begin

  var sUsername     := FRepoManager.GitHubUsername;
  var sToken        := FRepoManager.GitHubToken;

  if ( not TGitHubSettingsForm.Execute( sUsername, sToken ) ) then
    Exit;

  FRepoManager.GitHubUsername := sUsername;
  FRepoManager.GitHubToken := sToken;
  SaveConfigReporting( 'GitHub credentials' );

end;

function TMainForm.EnsureGitHubCredentials: Boolean;
begin

  Result            := FRepoManager.HasGitHubCredentials;

  if Result then
    Exit;

  StyledMessageDlg( 'Please configure GitHub credentials first.', mtWarning, [ mbOK ], 0 );
  mnuGitHubSettingsClick( nil );
  Result            := FRepoManager.HasGitHubCredentials;

end;

function TMainForm.PromptNewRepoJob( const sFolder: string; const bDropped: Boolean; out AJob: TNewRepoJob ): Boolean;
begin

  Result            := False;
  AJob              := Default( TNewRepoJob );
  AJob.Folder       := TGitRepoManager.NormaliseRepoPath( sFolder );
  AJob.Name         := SanitiseRepoName( ExtractFileName( AJob.Folder ) );
  AJob.IsPrivate    := True;
  AJob.ProjectType  := TNewRepositoryForm.PROJECT_TYPE_DELPHI;

  var bIsRepo       := TGitRepoManager.HasGitEntry( AJob.Folder );

  if bDropped then
  begin
    if StyledMessageDlg( Format( '"%s" is not a Git repository.' + sLineBreak + sLineBreak +
      'Initialise it and push it to a new GitHub repository?', [ AJob.Folder ] ), mtConfirmation, [ mbYes, mbNo ],
      0 ) <> mrYes then
      Exit;
  end
  else if bIsRepo then
  begin
    // Allowed on purpose.  This is how a run that stopped part-way is
    // finished: the steps already done are skipped.
    if StyledMessageDlg( Format( '"%s" is already a Git repository.' + sLineBreak + sLineBreak +
      'If it has no origin, a GitHub repository is created for it; its commits are then pushed. ' +
      'If it already has an origin, nothing is created and it is pushed there.' + sLineBreak + sLineBreak +
      'Continue?', [ AJob.Folder ] ), mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
      Exit;
  end;

  // An existing repository keeps whatever .gitignore it has.
  if bIsRepo then
    AJob.ProjectType := TNewRepositoryForm.PROJECT_TYPE_NONE;

  if ( not TNewRepositoryForm.Execute( AJob.Name, AJob.Description, AJob.IsPrivate, AJob.ProjectType,
    not bIsRepo ) ) then
    Exit;

  Result            := bDropped or bIsRepo or
    ( StyledMessageDlg( Format( 'This will:' + sLineBreak + sLineBreak +
    '1. Initialise a Git repository in: %s' + sLineBreak +
    '2. Create the %s repository "%s" on GitHub' + sLineBreak +
    '3. Commit all files and push' + sLineBreak + sLineBreak + 'Continue?',
    [ AJob.Folder, IfThen( AJob.IsPrivate, 'private', 'PUBLIC' ), AJob.Name ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) = mrYes );

end;

procedure TMainForm.CreateRepositoriesFromFolders( const saFolders: TArray<string>; const bDropped: Boolean );
var
  aJobs             : TArray<TNewRepoJob>;
  rJob              : TNewRepoJob;
begin

  if ( not NotBusy ) or ( not EnsureGitHubCredentials ) then
    Exit;

  // Every question is asked before any work starts, so that a batch of
  // dropped folders does not stop for a dialog between each push.
  for var sFolder in saFolders do
  begin
    if PromptNewRepoJob( sFolder, bDropped, rJob ) then
      aJobs         := aJobs + [ rJob ];
  end;

  if ( Length( aJobs ) = 0 ) or ( not BeginBatch ) then
    Exit;

  RunCreateJobs( aJobs );

end;

procedure TMainForm.RunCreateJobs( const AJobs: TArray<TNewRepoJob> );
var
  saFailed          : TArray<string>;
  iCreated          : Integer;
  bFinished         : Boolean;
begin

  iCreated          := 0;
  saFailed          := nil;
  bFinished         := False;

  // The whole sequence - init, an HTTPS call, a commit and a push - used to
  // run on the UI thread, which froze the window for as long as the push took.
  RunWorker(
    procedure
    begin

      for var rJob in AJobs do
      begin
        if IsCancelled then
        begin
          LogSafe( 'Repository creation cancelled.' );
          Break;
        end;

        LogSafe( Format( '=== Creating %s ===', [ rJob.Name ] ) );
        WriteGitIgnoreForProjectType( rJob.Folder, rJob.ProjectType );

        var sRemoteURL: string;
        var sLog: string;

        if FRepoManager.CreateAndPushRepository( rJob.Folder, rJob.Name, rJob.Description, rJob.IsPrivate,
          'Initial commit', sRemoteURL, sLog ) then
          Inc( iCreated )
        else
          saFailed  := saFailed + [ rJob.Name ];

        LogSafe( sLog.TrimRight );
      end;

      bFinished     := True;

    end,
    procedure
    begin

      if ( not bFinished ) then
        saFailed    := saFailed + [ '(stopped on an unexpected error before every folder was processed)' ];

      // Listed whether or not the push got through: a folder that was
      // initialised is a repository now, and has to be visible to be finished.
      for var rJob in AJobs do
      begin
        if TGitRepoManager.HasGitEntry( rJob.Folder ) then
          FRepoManager.AddRepository( rJob.Folder );
      end;

      EndBatch;
      PopulateListView;
      UpdateGroupFilterCombo;
      ScrollLogToEnd;

      if IsCancelled then
        Exit;

      if Length( saFailed ) = 0 then
        StyledMessageDlg( Format( '%s created on GitHub and pushed.', [ RepositoryCountText( iCreated ) ] ),
          mtInformation, [ mbOK ], 0 )
      else
        ErrorDlg( Format( 'Not completed: %s' + sLineBreak + sLineBreak + 'The log says how far each one got. ' +
          'Once the cause is dealt with, run GitHub > Initialise && Push to GitHub on the same folder: it carries ' +
          'on from where it stopped.', [ string.Join( ', ', saFailed ) ] ), mtWarning );

    end );

end;

procedure TMainForm.mnuInitPushGitHubClick( Sender: TObject );
var
  sFolder           : string;
begin

  if ( not NotBusy ) or ( not EnsureGitHubCredentials ) then
    Exit;

  if PickFolder( 'Select the Folder to Publish to GitHub', sFolder ) then
    CreateRepositoriesFromFolders( [ sFolder ], False );

end;

procedure TMainForm.MigrateSelectedToGitHub;
var
  rRepo             : TRepoInfo;
  sRepoName         : string;
  sDescription      : string;
  sProjectType      : string;
  sNewURL           : string;
  sError            : string;
  sLog              : string;
  bPrivate          : Boolean;
  bOK               : Boolean;
  bReturned         : Boolean;
begin

  if ( not SelectedRepo( rRepo ) ) then
  begin
    StyledMessageDlg( 'Please select a repository to migrate.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  // This used to start its worker without taking the batch guard at all, so
  // a migration could run alongside a commit batch in the same repository.
  if ( not NotBusy ) or ( not EnsureGitHubCredentials ) then
    Exit;

  if rRepo.Provider = rpGitHub then
  begin
    StyledMessageDlg( Format( 'Repository "%s" is already hosted on GitHub.', [ rRepo.Name ] ), mtInformation,
      [ mbOK ], 0 );
    Exit;
  end;

  sRepoName         := SanitiseRepoName( rRepo.Name );
  sDescription      := '';
  sProjectType      := '';
  bPrivate          := True;

  if ( not TNewRepositoryForm.Execute( sRepoName, sDescription, bPrivate, sProjectType, False ) ) then
    Exit;

  if StyledMessageDlg( Format( 'Migrate repository "%s" to GitHub?' + sLineBreak + sLineBreak +
    'This will:' + sLineBreak +
    '1. Create the %s repository "%s" on GitHub' + sLineBreak +
    '2. Keep the existing origin as a second remote ( old-origin )' + sLineBreak +
    '3. Point origin at the new GitHub URL' + sLineBreak +
    '4. Push all branches and tags to GitHub' + sLineBreak + sLineBreak +
    'The old remote repository is NOT deleted - remove it by hand once the migration is verified.',
    [ rRepo.Name, IfThen( bPrivate, 'private', 'PUBLIC' ), sRepoName ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  Log( Format( '=== Migrating %s to GitHub ===', [ rRepo.Name ] ) );

  // The PATH, not an index: a migration is an HTTPS call and a full push.
  var sRepoPath     := rRepo.Path;

  bOK               := False;
  bReturned         := False;

  RunWorker(
    procedure
    begin

      bOK           := FRepoManager.MigrateRepository( sRepoPath, sRepoName, sDescription, bPrivate, sNewURL, sError,
        sLog );
      bReturned     := True;

    end,
    procedure
    begin

      if ( not sLog.Trim.IsEmpty ) then
        Log( sLog.TrimRight );

      EndBatch;
      PopulateListView;

      if bOK then
      begin
        Log( '=== Migration Complete ===' );
        Log( Format( 'New URL: %s', [ sNewURL ] ) );

        if ( not IsCancelled ) then
          StyledMessageDlg( Format( 'Repository migrated to GitHub.' + sLineBreak + sLineBreak + 'New URL: %s' +
            sLineBreak + sLineBreak + 'The old remote still exists - delete it on its own host once you are ' +
            'satisfied.', [ sNewURL ] ), mtInformation, [ mbOK ], 0 );
      end
      else
      begin
        // Not returned at all means it was stopped by an exception, which is
        // about to be reported; the roll-back still ran, and logged above.
        if ( not bReturned ) then
          sError    := 'The migration stopped on an unexpected error. Check the remotes ( git remote -v ) before ' +
            'trying again.';

        Log( Format( 'Error: %s', [ sError ] ) );

        if ( not IsCancelled ) then
          ErrorDlg( Format( 'Migration failed: %s', [ sError ] ) );
      end;

    end );

end;

procedure TMainForm.mnuMigrateToGitHubClick( Sender: TObject );
begin

  MigrateSelectedToGitHub;

end;

procedure TMainForm.SetSelectedVisibility( const bPrivate: Boolean );
var
  rRepo             : TRepoInfo;
  sError            : string;
  bOK               : Boolean;
begin

  if ( not SelectedRepo( rRepo ) ) then
  begin
    StyledMessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if ( not NotBusy ) then
    Exit;

  case rRepo.Provider of
    rpNone:
      begin
        StyledMessageDlg( 'This repository has no remote configured.', mtWarning, [ mbOK ], 0 );
        Exit;
      end;

    rpOther:
      begin
        StyledMessageDlg( 'Visibility can only be changed for a GitHub repository.', mtWarning, [ mbOK ], 0 );
        Exit;
      end;

    rpGitHub:
      ; // Supported - carry on below.
  end;

  var sWord         := IfThen( bPrivate, 'PRIVATE', 'PUBLIC' );

  if StyledMessageDlg( Format( 'Make repository "%s" %s on GitHub?' + sLineBreak + sLineBreak + '%s',
    [ rRepo.Name, sWord, IfThen( bPrivate, 'It will be visible only to you and those you grant access.',
    'It will be visible to EVERYONE.' ) ] ), mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  bOK               := False;

  // An HTTPS call with a 30-second timeout: not something for the UI thread.
  RunWorker(
    procedure
    begin
      bOK           := FRepoManager.SetRepositoryVisibility( rRepo.Path, bPrivate, sError );
    end,
    procedure
    begin

      EndBatch;

      if bOK then
      begin
        Log( Format( 'Repository "%s" set to %s on GitHub', [ rRepo.Name, sWord ] ) );

        if ( not IsCancelled ) then
          StyledMessageDlg( Format( 'Repository visibility changed to %s.', [ sWord ] ), mtInformation, [ mbOK ], 0 );
      end
      else
      begin
        Log( Format( 'Error: %s', [ sError ] ) );

        if ( not IsCancelled ) then
          ErrorDlg( Format( 'Failed to change visibility: %s', [ sError ] ) );
      end;

    end );

end;

procedure TMainForm.pmSetPublicClick( Sender: TObject );
begin

  SetSelectedVisibility( False );

end;

procedure TMainForm.pmSetPrivateClick( Sender: TObject );
begin

  SetSelectedVisibility( True );

end;

procedure TMainForm.UpdateMenuSelectionState;
begin

  // Migrate acts on the HIGHLIGHTED row.  Remove and Delete act on the TICKED
  // rows, so they are not touched here: this used to grey Remove Selected out
  // whenever rows were ticked but none was highlighted ( the normal state
  // after Select All ), and to re-enable it in the middle of a batch.
  mnuMigrateToGitHub.Enabled := Assigned( lvRepos.Selected ) and ( not IsBusy );

end;

procedure TMainForm.pmReposPopup( Sender: TObject );
var
  oItem             : TMenuItem;
begin

  var bHasSelection := Assigned( lvRepos.Selected );
  var bHasTargets   := Length( ContextRepoPaths ) > 0;

  // These act on the highlighted row.
  pmEditGitignore.Enabled := bHasSelection;
  pmFixGitignore.Enabled := bHasSelection;
  pmSetPublic.Enabled := bHasSelection;
  pmSetPrivate.Enabled := bHasSelection;
  pmOpenInExplorer.Enabled := bHasSelection;
  pmOpenInGitClient.Enabled := bHasSelection;
  pmPull.Enabled    := bHasSelection;

  // These act on the highlighted row when it is not ticked, and on every
  // ticked row when it is - see ContextRepoPaths.
  pmSetGroup.Enabled := bHasTargets;
  pmDeleteSelected.Enabled := bHasTargets;

  // Build the Set Group submenu
  pmSetGroup.Clear;

  var saGroups      := FRepoManager.GetAllGroups;

  for var iI := 0 to High( saGroups ) do
  begin
    oItem           := TMenuItem.Create( pmSetGroup );
    oItem.Caption   := MenuCaption( saGroups[ iI ] );
    oItem.Tag       := iI;
    oItem.OnClick   := SetGroupMenuItemClick;
    pmSetGroup.Add( oItem );
  end;

  if Length( saGroups ) > 0 then
  begin
    oItem           := TMenuItem.Create( pmSetGroup );
    oItem.Caption   := '-';
    pmSetGroup.Add( oItem );
  end;

  oItem             := TMenuItem.Create( pmSetGroup );
  oItem.Caption     := '(Clear Group)';
  oItem.Tag         := -1;
  oItem.OnClick     := SetGroupMenuItemClick;
  pmSetGroup.Add( oItem );

  oItem             := TMenuItem.Create( pmSetGroup );
  oItem.Caption     := 'New Group...';
  oItem.Tag         := -2;
  oItem.OnClick     := SetGroupMenuItemClick;
  pmSetGroup.Add( oItem );

end;

procedure TMainForm.pmEditGitignoreClick( Sender: TObject );
var
  rRepo             : TRepoInfo;
begin

  if ( not SelectedRepo( rRepo ) ) then
  begin
    StyledMessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  var sGitignorePath := TPath.Combine( rRepo.Path, '.gitignore' );

  // Check if .gitignore exists, offer to create if not
  if ( not TFile.Exists( sGitignorePath ) ) then
  begin
    if StyledMessageDlg( Format( 'No .gitignore file exists in "%s".' + sLineBreak + sLineBreak + 'Create one now?',
      [ rRepo.Name ] ), mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
      Exit;

    try
      TFile.WriteAllText( sGitignorePath, '' );
      Log( Format( 'Created .gitignore in %s', [ rRepo.Name ] ) );
    except
      // A read-only folder or a full disk.  Anything else is ours, and is
      // left to reach EurekaLog.
      on E: EInOutError do
      begin
        ErrorDlg( Format( 'Failed to create .gitignore: %s', [ E.Message ] ) );
        Exit;
      end;

      on E: EStreamError do
      begin
        ErrorDlg( Format( 'Failed to create .gitignore: %s', [ E.Message ] ) );
        Exit;
      end;
    end;
  end;

  // A ShellExecute result of 32 or less is a failure code, not a window
  // handle. '.gitignore' very often has no registered handler.
  if ShellExecute( Handle, 'open', PChar( sGitignorePath ), nil, nil, SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not open .gitignore - no application is registered for this file type.' + sLineBreak +
      sLineBreak + sGitignorePath, mtWarning, [ mbOK ], 0 );

end;

procedure TMainForm.pmFixGitignoreClick( Sender: TObject );
const
  DELPHI_PATTERNS   : array[ 0..22 ] of string = (
    '*.dcu', '*.exe', '*.dll', '*.bpl', '*.dcp', '*.dres', '*.map', '*.drc', '*.rsm', '*.tds', '*.dof', '*.obj',
    '*.hpp', '*.o', '__history/', '__recovery/', '*.local', '*.identcache', '*.projdata', '*.tvsconfig', '*.dsk',
    'Win32/', 'Win64/' );
  UTF8_BOM          : array[ 0..2 ] of Byte = ( $EF, $BB, $BF );
var
  rRepo             : TRepoInfo;
  naBytes           : TBytes;
  oEncoding         : TEncoding;
  sText             : string;
  sEOL              : string;
  saToAdd           : TArray<string>;
  bHadBOM           : Boolean;
begin

  if ( not SelectedRepo( rRepo ) ) then
  begin
    StyledMessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  var sGitignorePath := TPath.Combine( rRepo.Path, '.gitignore' );

  // The file is read and written back as BYTES in the encoding and with the
  // line endings it already has.  It used to go through a TStringList, which
  // rewrote every line ending as CRLF - so adding two patterns showed the
  // whole file as changed, and broke a repository that normalises to LF - and
  // raised EEncodingError, uncaught, on a file that was not valid UTF-8.
  naBytes           := nil;

  try
    if TFile.Exists( sGitignorePath ) then
      naBytes       := TFile.ReadAllBytes( sGitignorePath );
  except
    on E: EInOutError do
    begin
      ErrorDlg( Format( 'Failed to read .gitignore: %s', [ E.Message ] ) );
      Exit;
    end;

    on E: EStreamError do
    begin
      ErrorDlg( Format( 'Failed to read .gitignore: %s', [ E.Message ] ) );
      Exit;
    end;
  end;

  bHadBOM           := ( Length( naBytes ) >= 3 ) and CompareMem( @naBytes[ 0 ], @UTF8_BOM[ 0 ], 3 );

  if bHadBOM then
    naBytes         := Copy( naBytes, 3, MaxInt );

  // UTF-8 when the bytes are valid UTF-8 ( plain ASCII always is ); otherwise
  // the file is in the ANSI code page and stays there.
  oEncoding         := TEncoding.UTF8;

  try
    sText           := TEncoding.UTF8.GetString( naBytes );
  except
    on E: EEncodingError do
    begin
      oEncoding     := TEncoding.ANSI;
      sText         := TEncoding.ANSI.GetString( naBytes );
    end;
  end;

  // A new file gets LF, which Git accepts on every platform.
  sEOL              := IfThen( sText.Contains( #13#10 ), #13#10, #10 );

  // Compare whole, trimmed LINES, never substrings: '*.o' is inside '*.obj'.
  var saExisting    := sText.Split( [ #13#10, #10, #13 ], TStringSplitOptions.ExcludeEmpty );

  for var sPattern in DELPHI_PATTERNS do
  begin
    var bFound      := False;

    for var sLine in saExisting do
    begin
      if SameText( sLine.Trim, sPattern ) then
        bFound      := True;
    end;

    if ( not bFound ) then
      saToAdd       := saToAdd + [ sPattern ];
  end;

  if Length( saToAdd ) = 0 then
  begin
    StyledMessageDlg( 'All standard Delphi patterns are already in .gitignore.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if ( not sText.IsEmpty ) then
  begin
    if ( not sText.EndsWith( #10 ) ) then
      sText         := sText + sEOL;

    sText           := sText + sEOL;
  end;

  sText             := Format( '%s# Delphi build artefacts (added by GitBatchCommit)%s%s%s', [ sText, sEOL,
    string.Join( sEOL, saToAdd ), sEOL ] );

  naBytes           := oEncoding.GetBytes( sText );

  if bHadBOM then
    naBytes         := TBytes.Create( $EF, $BB, $BF ) + naBytes;

  // Only the WRITE is guarded, so that a failure anywhere else is not reported
  // as "Failed to save .gitignore".
  try
    TFile.WriteAllBytes( sGitignorePath, naBytes );
  except
    on E: EInOutError do
    begin
      ErrorDlg( Format( 'Failed to save .gitignore: %s', [ E.Message ] ) );
      Exit;
    end;

    on E: EStreamError do
    begin
      ErrorDlg( Format( 'Failed to save .gitignore: %s', [ E.Message ] ) );
      Exit;
    end;
  end;

  Log( Format( 'Added %d Delphi patterns to .gitignore in %s', [ Length( saToAdd ), rRepo.Name ] ) );

  // Local state only: nothing here needs the remote, and this is the UI thread.
  FRepoManager.RefreshStatus( rRepo.Path, False );
  UpdateListItem( rRepo.Path );

  // Ignoring a pattern does not stop Git tracking a file it already tracks.
  StyledMessageDlg( Format( 'Added %d patterns to .gitignore.' + sLineBreak + sLineBreak +
    'Files that Git ALREADY tracks are not affected by an ignore rule. To stop tracking one, run ' +
    '"git rm --cached <file>" in the repository and commit.', [ Length( saToAdd ) ] ), mtInformation, [ mbOK ], 0 );

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
    StyledMessageDlg( 'Users Guide.md not found in application folder.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  if ShellExecute( Handle, 'open', PChar( sReadmePath ), nil, nil, SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not open the documentation - no application is registered for .md files.' + sLineBreak +
      sLineBreak + sReadmePath, mtWarning, [ mbOK ], 0 );

end;

procedure TMainForm.mnuAboutClick( Sender: TObject );
begin

  StyledMessageDlg( Format( 'Git Batch Commit' + sLineBreak + sLineBreak +
    'Version %s' + sLineBreak + sLineBreak +
    'A tool for committing and pushing changes to multiple' + sLineBreak +
    'Git repositories simultaneously with a single commit message.' + sLineBreak + sLineBreak +
    'Features:' + sLineBreak +
    '  - Batch commit and push to multiple repositories' + sLineBreak +
    '  - GitHub integration' + sLineBreak +
    '  - Repository status detection' + sLineBreak +
    '  - Automatic version tagging for Delphi projects' + sLineBreak +
    '  - Drag and drop support' + sLineBreak + sLineBreak +
    'Copyright (c) 2026 GITLAK Software' + sLineBreak +
    'All Rights Reserved', [ APP_VERSION ] ), mtInformation, [ mbOK ], 0 );

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

procedure TMainForm.pmOpenInExplorerClick( Sender: TObject );
var
  rRepo             : TRepoInfo;
begin

  if ( not SelectedRepo( rRepo ) ) then
    Exit;

  if ShellExecute( Handle, 'explore', PChar( rRepo.Path ), nil, nil, SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not open the folder in Explorer:' + sLineBreak + sLineBreak + rRepo.Path, mtWarning,
      [ mbOK ], 0 );

end;

procedure TMainForm.pmOpenInGitClientClick( Sender: TObject );
var
  rRepo             : TRepoInfo;
begin

  if ( not SelectedRepo( rRepo ) ) then
    Exit;

  var sClientPath   := FRepoManager.GitClientPath;

  if sClientPath.IsEmpty then
  begin
    StyledMessageDlg( 'No Git client configured. Please set the Git client path in File > Settings.', mtWarning,
      [ mbOK ], 0 );
    Exit;
  end;

  if ( not TFile.Exists( sClientPath ) ) then
  begin
    StyledMessageDlg( Format( 'Git client not found: %s', [ sClientPath ] ), mtError, [ mbOK ], 0 );
    Exit;
  end;

  if ShellExecute( Handle, 'open', PChar( sClientPath ), PChar( Format( '"%s"', [ rRepo.Path ] ) ), nil,
    SW_SHOWNORMAL ) <= 32 then
    StyledMessageDlg( 'Could not launch the configured Git client:' + sLineBreak + sLineBreak + sClientPath,
      mtWarning, [ mbOK ], 0 );

end;

procedure TMainForm.pmPullClick( Sender: TObject );
var
  rRepo             : TRepoInfo;
begin

  if SelectedRepo( rRepo ) then
    PullRepositories( [ rRepo.Path ] );

end;

procedure TMainForm.PullRepositories( const saPaths: TArray<string> );
const
  MAX_PREVIEW_LINES = 30;
var
  saPreview         : TArray<string>;
  saNeedBackup      : TArray<string>;
  bPreviewed        : Boolean;
begin

  bPreviewed        := False;

  if Length( saPaths ) = 0 then
  begin
    StyledMessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg( Format( 'WARNING: Pull merges remote changes into your LOCAL code.' + sLineBreak + sLineBreak +
    'The local files of %s MAY BE MODIFIED.' + sLineBreak + sLineBreak +
    'The incoming changes are shown first, and a backup branch is created for every repository that has any.' +
    sLineBreak + sLineBreak + 'Do you want to continue?', [ RepositoryCountText( Length( saPaths ) ) ] ), mtWarning,
    [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  // Taken BEFORE the preview: the preview is a network fetch per repository.
  if ( not BeginBatch ) then
    Exit;

  Log( 'Fetching and previewing incoming changes...' );

  // Stage 1, on a worker: what is incoming?
  RunWorker(
    procedure
    begin

      for var sPath in saPaths do
      begin
        if IsCancelled then
          Break;

        var sChanges: string;
        var sLog: string;
        var sName   := ExtractFileName( sPath );

        if ( not FRepoManager.GetIncomingChanges( sPath, sChanges, sLog ) ) then
        begin
          // Unknown is treated as "may have changes": it gets a backup.
          LogSafe( Format( 'Warning: could not preview %s: %s', [ sName, sLog ] ) );
          saNeedBackup := saNeedBackup + [ sPath ];
        end
        else if ( not sChanges.IsEmpty ) then
        begin
          saPreview := saPreview + [ Format( '=== %s ===', [ sName ] ) ] +
            sChanges.Split( [ #13#10, #10 ], TStringSplitOptions.ExcludeEmpty ) + [ '' ];
          saNeedBackup := saNeedBackup + [ sPath ];
        end
        else
          LogSafe( Format( '%s: nothing incoming', [ sName ] ) );
      end;

      bPreviewed    := True;

    end,
    procedure
    begin

      // Every exit from here to the second stage must release the guard.  The
      // preview used to sit outside the try..finally that did so, and an
      // exception in it left every button disabled for good.
      // A preview stopped by an exception has not looked at every repository:
      // pulling the rest would merge changes nobody was shown, with no backup.
      var bProceed  := bPreviewed and ( not IsCancelled );

      try
        if bProceed and ( Length( saPreview ) > 0 ) then
        begin
          var sPreview := string.Join( sLineBreak, Copy( saPreview, 0, MAX_PREVIEW_LINES ) );

          if Length( saPreview ) > MAX_PREVIEW_LINES then
            sPreview := Format( '%s%s... (%d more lines are in the log)', [ sPreview, sLineBreak,
              Length( saPreview ) - MAX_PREVIEW_LINES ] );

          for var sLine in saPreview do
            Log( sLine );

          bProceed  := StyledMessageDlg( Format( 'These files will be MODIFIED by the pull:' + sLineBreak +
            sLineBreak + '%s' + sLineBreak + sLineBreak + 'Proceed? (Backup branches are created first.)',
            [ sPreview ] ), mtWarning, [ mbYes, mbNo ], 0 ) = mrYes;
        end;
      finally
        if ( not bProceed ) then
        begin
          Log( 'Pull cancelled.' );
          EndBatch;
        end;
      end;

      if ( not bProceed ) then
        Exit;

      // Stage 2: back up where something is incoming, then pull.
      RunRepoBatch( 'Pull', saPaths,
        function( const sRepoPath: string; out sLog: string ): Boolean
        begin

          sLog      := '';

          // A backup branch only where the pull will change something.  One
          // was made on EVERY pull, so an estate pulled daily collected a new
          // branch per repository per day, nearly all of them pointless.
          if IndexStr( sRepoPath, saNeedBackup ) >= 0 then
          begin
            var sBranch: string;
            var sBackupLog: string;

            if ( not FRepoManager.CreateBackupBranch( sRepoPath, sBranch, sBackupLog ) ) then
            begin
              // No safety net, so no pull.
              sLog  := Format( '%s%sNOT pulled, because the backup branch could not be created.', [ sBackupLog,
                sLineBreak ] );
              Exit( False );
            end;

            sLog    := Format( '%s (delete it with: git branch -D %s)%s', [ sBackupLog, sBranch, sLineBreak ] );
          end;

          var sPullLog: string;

          Result    := FRepoManager.PullRepository( sRepoPath, sPullLog );
          sLog      := sLog + sPullLog;
          FRepoManager.RefreshStatus( sRepoPath );

        end,
        False, nil );

    end );

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

procedure TMainForm.BuildHistoryMenu;
var
  oItem             : TMenuItem;
begin

  pmHistory.Items.Clear;

  var saHistory     := FRepoManager.CommitHistory;

  if Length( saHistory ) = 0 then
  begin
    oItem           := TMenuItem.Create( pmHistory );
    oItem.Caption   := '(No history)';
    oItem.Enabled   := False;
    pmHistory.Items.Add( oItem );
    Exit;
  end;

  for var iI := 0 to High( saHistory ) do
  begin
    oItem           := TMenuItem.Create( pmHistory );
    oItem.Caption   := MenuCaption( saHistory[ iI ] );
    oItem.Tag       := iI;
    oItem.OnClick   := HistoryMenuItemClick;
    pmHistory.Items.Add( oItem );
  end;

end;

procedure TMainForm.HistoryMenuItemClick( Sender: TObject );
begin

  var iIndex        := ( Sender as TMenuItem ).Tag;
  var saHistory     := FRepoManager.CommitHistory;

  if ( iIndex < 0 ) or ( iIndex > High( saHistory ) ) then
    Exit;

  // The history keeps the whole message.  Put the first line back in the
  // summary box and the rest in the details, which is how it was entered.
  var saParts       := saHistory[ iIndex ].Split( [ sLineBreak + sLineBreak ], 2 );

  edtCommitMessage.Text := saParts[ 0 ].Replace( sLineBreak, ' ' );

  if Length( saParts ) > 1 then
  begin
    mmoDetails.Text := saParts[ 1 ];
    pnlDetails.Visible := True;
  end;

end;

procedure TMainForm.mnuSettingsClick( Sender: TObject );
begin

  if ( not NotBusy ) then
    Exit;

  var sClientPath   := FRepoManager.GitClientPath;
  var sFilePattern  := FRepoManager.FilePattern;
  var sIndexerPath  := FRepoManager.DelphiIndexerPath;

  if ( not InputQuery( 'Settings', 'Git Client Path - git.exe, or a GUI client for "Open in Git Client":',
    sClientPath ) ) then
    Exit;

  if ( not InputQuery( 'Settings', 'File Pattern (e.g., *.pas or empty for all):', sFilePattern ) ) then
    Exit;

  sClientPath       := sClientPath.Trim;
  sFilePattern      := sFilePattern.Trim;

  // Restrict the pattern to a glob whitelist. Git is launched through
  // CreateProcess with no shell involved, so this is not about shell
  // metacharacters - it is about a pattern that begins with '-' being
  // taken as an OPTION to `git add` rather than as a pathspec.
  if ( not TGitRepoManager.IsSafeFilePattern( sFilePattern ) ) then
  begin
    StyledMessageDlg( 'File pattern contains characters that are not allowed.' + sLineBreak + sLineBreak +
      'Use only letters, digits, glob characters ( * ? [ ] ), dots, dashes, underscores, slashes, commas, and ' +
      'spaces.' + sLineBreak + sLineBreak + 'Nothing was changed.', mtError, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg( Format( 'Configure delphi-indexer.exe path?' + sLineBreak + sLineBreak + 'Current: %s',
    [ IfThen( sIndexerPath.IsEmpty, '(Auto-detect)', sIndexerPath ) ] ), mtConfirmation, [ mbYes, mbNo ],
    0 ) = mrYes then
  begin
    var oDialog     := TFileOpenDialog.Create( Self );

    try
      oDialog.Title := 'Locate delphi-indexer.exe';
      oDialog.Options := oDialog.Options + [ fdoFileMustExist, fdoPathMustExist ];

      var oType     := oDialog.FileTypes.Add;

      oType.DisplayName := 'Delphi Indexer';
      oType.FileMask := 'delphi-indexer.exe';
      oType         := oDialog.FileTypes.Add;
      oType.DisplayName := 'Executable Files';
      oType.FileMask := '*.exe';

      if ( not sIndexerPath.IsEmpty ) and TFile.Exists( sIndexerPath ) then
        oDialog.DefaultFolder := ExtractFileDir( sIndexerPath );

      // Cancelling here cancels the whole dialog sequence: nothing is saved.
      if ( not oDialog.Execute ) then
        Exit;

      sIndexerPath  := oDialog.FileName;
    finally
      oDialog.Free;
    end;
  end;

  FRepoManager.GitClientPath := sClientPath;
  FRepoManager.FilePattern := sFilePattern;
  FRepoManager.DelphiIndexerPath := sIndexerPath;

  // The result used to be thrown away and "Settings updated." logged anyway.
  SaveConfigReporting( 'Settings' );

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

procedure TMainForm.BuildTemplatesMenu;
var
  oItem             : TMenuItem;
begin

  pmTemplates.Items.Clear;

  var saTemplates   := FRepoManager.CommitTemplates;

  if Length( saTemplates ) = 0 then
  begin
    oItem           := TMenuItem.Create( pmTemplates );
    oItem.Caption   := '(No templates - use File > Templates to add)';
    oItem.Enabled   := False;
    pmTemplates.Items.Add( oItem );
    Exit;
  end;

  for var iI := 0 to High( saTemplates ) do
  begin
    oItem           := TMenuItem.Create( pmTemplates );
    oItem.Caption   := MenuCaption( saTemplates[ iI ] );
    oItem.Tag       := iI;
    oItem.OnClick   := TemplateMenuItemClick;
    pmTemplates.Items.Add( oItem );
  end;

end;

procedure TMainForm.TemplateMenuItemClick( Sender: TObject );
begin

  var iIndex        := ( Sender as TMenuItem ).Tag;
  var saTemplates   := FRepoManager.CommitTemplates;

  if ( iIndex >= 0 ) and ( iIndex <= High( saTemplates ) ) then
    edtCommitMessage.Text := saTemplates[ iIndex ];

end;

procedure TMainForm.mnuTemplateSettingsClick( Sender: TObject );
begin

  if ( not NotBusy ) then
    Exit;

  var saTemplates   := FRepoManager.CommitTemplates;

  if ( not TTemplateSettingsForm.Execute( saTemplates ) ) then
    Exit;

  FRepoManager.CommitTemplates := saTemplates;
  SaveConfigReporting( 'Templates' );

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

procedure TMainForm.UpdateGroupFilterCombo;
const
  ALL_GROUPS        = '(All Groups)';
begin

  // FGroupFilter is the state; the combo is rebuilt to show it.  Reading the
  // combo's text back, as this used to, lost the filter whenever the combo
  // had not been drawn yet.
  cbGroupFilter.Items.BeginUpdate;

  try
    cbGroupFilter.Items.Clear;
    cbGroupFilter.Items.Add( ALL_GROUPS );

    for var sGroup in FRepoManager.GetAllGroups do
      cbGroupFilter.Items.Add( sGroup );
  finally
    cbGroupFilter.Items.EndUpdate;
  end;

  var iIndex        := if FGroupFilter.IsEmpty then 0 else cbGroupFilter.Items.IndexOf( FGroupFilter );

  // The group being filtered on has gone ( its last member was re-grouped ):
  // fall back to all groups, and make the LIST follow, or it would go on
  // showing nothing under a combo that reads "(All Groups)".
  if iIndex < 0 then
  begin
    iIndex          := 0;
    FGroupFilter    := '';
    PopulateListView;
  end;

  cbGroupFilter.ItemIndex := iIndex;

end;

procedure TMainForm.cbGroupFilterChange( Sender: TObject );
begin

  if cbGroupFilter.ItemIndex <= 0 then
    FGroupFilter    := ''
  else
    FGroupFilter    := cbGroupFilter.Text;

  PopulateListView;

end;

procedure TMainForm.SetGroupMenuItemClick( Sender: TObject );
begin

  var iTag          := ( Sender as TMenuItem ).Tag;
  var sGroup        := '';

  case iTag of
    -1:
      ; // Clear the group.

    -2:
      begin
        if ( not InputQuery( 'New Group', 'Enter group name:', sGroup ) ) then
          Exit;

        sGroup      := Trim( sGroup );

        if sGroup.IsEmpty then
          Exit;
      end;
  else
    var saGroups    := FRepoManager.GetAllGroups;

    if ( iTag < 0 ) or ( iTag > High( saGroups ) ) then
      Exit;

    sGroup          := saGroups[ iTag ];
  end;

  // The right-clicked row when it is not ticked; every ticked row when it is.
  var saPaths       := ContextRepoPaths;

  if Length( saPaths ) = 0 then
  begin
    Log( 'No repositories selected' );
    Exit;
  end;

  for var sPath in saPaths do
    FRepoManager.SetRepoGroup( sPath, sGroup );

  if iTag = -1 then
    Log( Format( 'Cleared group for %s', [ RepositoryCountText( Length( saPaths ) ) ] ) )
  else
    Log( Format( 'Set group "%s" for %s', [ sGroup, RepositoryCountText( Length( saPaths ) ) ] ) );

  UpdateGroupFilterCombo;

  // Rebuild the list so the change is visible immediately.
  PopulateListView;

end;

procedure TMainForm.btnPullSelectedClick( Sender: TObject );
begin

  PullRepositories( CheckedRepoPaths );

end;

procedure TMainForm.btnResolveConflictsClick( Sender: TObject );
begin

  var saPaths       := CheckedRepoPaths;

  if Length( saPaths ) = 0 then
  begin
    StyledMessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg( Format( 'Resolve conflicts for %s by keeping LOCAL versions?' + sLineBreak + sLineBreak +
    'For a repository with a MERGE in progress this will:' + sLineBreak +
    '- Keep your local version of every conflicted file' + sLineBreak +
    '- DISCARD the incoming remote version of those files' + sLineBreak +
    '- Commit the merge and push it' + sLineBreak + sLineBreak +
    'Files that are not in conflict, and uncommitted or untracked files, are left as they are. ' +
    'A repository with no merge in progress is skipped; one in a rebase or cherry-pick is refused.',
    [ RepositoryCountText( Length( saPaths ) ) ] ), mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  RunRepoBatch( 'Resolve Conflicts', saPaths,
    function( const sRepoPath: string; out sLog: string ): Boolean
    begin
      Result        := FRepoManager.ResolveConflictsKeepLocal( sRepoPath, sLog );
      FRepoManager.RefreshStatus( sRepoPath );
    end,
    True, nil );

end;

procedure TMainForm.btnPushOnlyClick( Sender: TObject );
begin

  var saPaths       := CheckedRepoPaths;

  if Length( saPaths ) = 0 then
  begin
    StyledMessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if StyledMessageDlg( Format( 'Push %s without committing?', [ RepositoryCountText( Length( saPaths ) ) ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  RunRepoBatch( 'Push', saPaths,
    function( const sRepoPath: string; out sLog: string ): Boolean
    begin
      Result        := FRepoManager.PushRepository( sRepoPath, sLog );
      FRepoManager.RefreshStatus( sRepoPath );
    end,
    True, nil );

end;

procedure TMainForm.btnForcePushClick( Sender: TObject );
begin

  var saPaths       := CheckedRepoPaths;

  if Length( saPaths ) = 0 then
  begin
    StyledMessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  var sCount        := RepositoryCountText( Length( saPaths ) );

  if StyledMessageDlg( Format( 'WARNING: Force Push will OVERWRITE the remote repository history!' + sLineBreak +
    sLineBreak + 'This makes your local code the definitive version.' + sLineBreak +
    'Any commits on the remote that are not in your local will be LOST.' + sLineBreak + sLineBreak +
    'This operation affects %s.' + sLineBreak + sLineBreak + 'Are you ABSOLUTELY sure you want to continue?',
    [ sCount ] ), mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  // Second confirmation for safety
  if StyledMessageDlg( Format( 'FINAL CONFIRMATION' + sLineBreak + sLineBreak + 'You are about to force push %s.' +
    sLineBreak + sLineBreak + 'Remote history will be overwritten. This cannot be undone.' + sLineBreak + sLineBreak +
    'Proceed with force push?', [ sCount ] ), mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  if ( not BeginBatch ) then
    Exit;

  RunRepoBatch( 'Force Push', saPaths,
    function( const sRepoPath: string; out sLog: string ): Boolean
    begin
      Result        := FRepoManager.ForcePushRepository( sRepoPath, sLog );
      FRepoManager.RefreshStatus( sRepoPath );
    end,
    True, nil );

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
    Exit; // (None) — no .gitignore

  try
    // The single-argument overload writes UTF-8 WITHOUT a BOM. Git does not
    // strip a BOM from .gitignore, so the explicit-encoding overload used to
    // corrupt the FIRST rule of every non-Delphi template — 'node_modules/',
    // 'target/', '__pycache__/' and friends simply stopped being ignored.
    TFile.WriteAllText( sGitIgnorePath, sContent );

    // LogSafe throughout: this runs on the worker that publishes the folder.
    LogSafe( Format( 'Created .gitignore for %s project', [ sProjectType ] ) );
  except
    // A read-only or locked folder raises EFCreateError, a stream error, and
    // not EInOutError.  Uncaught, it ended the whole batch of folders.
    on E: EInOutError do
      LogSafe( Format( 'Warning: Failed to create .gitignore: %s', [ E.Message ] ) );

    on E: EStreamError do
      LogSafe( Format( 'Warning: Failed to create .gitignore: %s', [ E.Message ] ) );
  end;

end;

procedure TMainForm.RunPendingReindexes( const saDirs: TArray<string> );
const
  DELPHI_INDEXER_EXE = 'delphi-indexer.exe';
  DEFAULT_INSTALL_PATH = 'D:\glldelphi-lookup\delphi-indexer.exe';
  REINDEX_TIMEOUT_MS = 120000;
var
  sIndexerPath      : string;
  SearchBuffer      : array[ 0..MAX_PATH ] of Char;
  FilePart          : PChar;
  sOutput           : string;
begin

  // Nothing to reindex
  if Length( saDirs ) = 0 then
    Exit;

  sIndexerPath      := '';

  // 1. The configured path first, if it is still there.  Read once: the
  //    setting belongs to the UI thread and this is a worker.
  var sConfigured   := FRepoManager.DelphiIndexerPath;

  if ( not sConfigured.IsEmpty ) then
  begin
    if TFile.Exists( sConfigured ) then
      sIndexerPath  := sConfigured
    else
      // The setting is NOT cleared: the indexer may live on a share or a
      // removable drive that happens to be offline for this one run.
      LogSafe( Format( 'Reindex: configured indexer not found at "%s" - trying PATH.', [ sConfigured ] ) );
  end;

  // 2. The PATH environment variable
  FilePart          := nil;
  FillChar( SearchBuffer, SizeOf( SearchBuffer ), 0 );

  if sIndexerPath.IsEmpty then
  begin
    // SearchPath returns the REQUIRED buffer size when the result does not
    // fit, without writing the buffer at all - so a non-zero return is not on
    // its own proof that SearchBuffer holds anything.
    var iFound      := SearchPath( nil, PChar( DELPHI_INDEXER_EXE ), nil, Length( SearchBuffer ), SearchBuffer,
      FilePart );

    if ( iFound > 0 ) and ( iFound < Cardinal( Length( SearchBuffer ) ) ) then
    begin
      sIndexerPath  := SearchBuffer;

      // Remembered only when nothing is configured.  A configured path that
      // is offline for this run stays configured.
      if sConfigured.IsEmpty then
        QueueIndexerPathUpdate( sIndexerPath );
    end;
  end;

  // 3. The default installation location
  if sIndexerPath.IsEmpty and TFile.Exists( DEFAULT_INSTALL_PATH ) then
  begin
    sIndexerPath    := DEFAULT_INSTALL_PATH;

    if sConfigured.IsEmpty then
      QueueIndexerPathUpdate( sIndexerPath );
  end;

  // 4. Not found - skip reindexing silently
  if sIndexerPath.IsEmpty then
    Exit;

  LogSafe( Format( 'Reindex: processing %s', [ RepositoryCountText( Length( saDirs ) ) ] ) );

  for var sPath in saDirs do
  begin
    if IsCancelled then
      Break;

    LogSafe( Format( 'Triggering delphi-lookup reindex: %s', [ sPath ] ) );

    // RunProcessCaptureOutput reports every failure, including one to start
    // the indexer at all, through its result and its output.
    if RunProcessCaptureOutput( Format( '"%s" "%s" --category user', [ sIndexerPath, sPath ] ), '', sOutput,
      REINDEX_TIMEOUT_MS ) then
      LogSafe( 'delphi-lookup reindex completed successfully' )
    else
      LogSafe( Format( 'delphi-lookup reindex FAILED for %s: %s', [ sPath, sOutput.Trim ] ) );
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

