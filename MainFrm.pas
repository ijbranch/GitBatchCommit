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
  This project was developed jointly by the Author and Clode Code.

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
  Version: 1.4.0

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

  System.SysUtils, System.StrUtils, System.Variants, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, System.Generics.Defaults, System.Threading,

  uGitRepoManager, uCodebergDialog, uCodebergSettings, uGitHubSettings, uTemplateSettings;

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
    mnuCodebergSep1: TMenuItem;
    mnuCodebergSettings: TMenuItem;
    mnuGitHub: TMenuItem;
    mnuInitPushGitHub: TMenuItem;
    mnuGitHubSep1: TMenuItem;
    mnuGitHubSettings: TMenuItem;
    mnuView: TMenuItem;
    mnuFilter: TMenuItem;
    mnuFilterAll: TMenuItem;
    mnuFilterClean: TMenuItem;
    mnuFilterModified: TMenuItem;
    mnuFilterPullRequired: TMenuItem;
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
    procedure FormCreate( Sender: TObject );
    procedure FormDestroy( Sender: TObject );
    procedure FormShow( Sender: TObject );
    procedure btnCommitPushClick( Sender: TObject );
    procedure btnSelectModifiedClick( Sender: TObject );
    procedure btnSelectAllClick( Sender: TObject );
    procedure btnSelectNoneClick( Sender: TObject );
    procedure lvReposItemChecked( Sender: TObject; Item: TListItem );
    procedure mnuAddRepositoryClick( Sender: TObject );
    procedure mnuRemoveSelectedClick( Sender: TObject );
    procedure mnuRefreshStatusClick( Sender: TObject );
    procedure mnuExitClick( Sender: TObject );
    procedure mnuInitPushCodebergClick( Sender: TObject );
    procedure mnuCodebergSettingsClick( Sender: TObject );
    procedure mnuInitPushGitHubClick( Sender: TObject );
    procedure mnuGitHubSettingsClick( Sender: TObject );
    procedure mnuFilterClick( Sender: TObject );
    procedure pmSetPublicClick( Sender: TObject );
    procedure pmSetPrivateClick( Sender: TObject );
    procedure pmReposPopup( Sender: TObject );
    procedure pmEditGitignoreClick( Sender: TObject );
    procedure pmFixGitignoreClick( Sender: TObject );
    procedure edtCommitMessageChange( Sender: TObject );
    procedure lvReposClick( Sender: TObject );
    procedure mnuHelpContentsClick( Sender: TObject );
    procedure mnuAboutClick( Sender: TObject );
    procedure lvReposCustomDrawItem( Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean );
    procedure pmOpenInExplorerClick( Sender: TObject );
    procedure pmOpenInGitClientClick( Sender: TObject );
    procedure pmPullClick( Sender: TObject );
    procedure btnHistoryClick( Sender: TObject );
    procedure mnuSettingsClick( Sender: TObject );
    procedure btnTemplatesClick( Sender: TObject );
    procedure mnuTemplateSettingsClick( Sender: TObject );
    procedure cboGroupFilterChange( Sender: TObject );
    procedure btnDetailsClick( Sender: TObject );
    procedure btnPullSelectedClick( Sender: TObject );
    procedure btnResolveConflictsClick( Sender: TObject );
    procedure btnPushOnlyClick( Sender: TObject );
    procedure btnForcePushClick( Sender: TObject );
    procedure mmoLogKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );
  private
    const
      WM_LOAD_REPOS = WM_USER + 100;
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
      FGroupFilter  : string;

      /// <summary>
      ///   Handles custom message to load repositories after form is visible.
      /// </summary>
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
    procedure UpdateListItem( const iIndex: Integer );

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
    procedure WMDropFiles( var Msg: TWMDropFiles ); message WM_DROPFILES;

    /// <summary>
    ///   Handles column click for sorting.
    /// </summary>
    procedure lvReposColumnClick( Sender: TObject; Column: TListColumn );

    /// <summary>
    ///   Applies current filter and sort to the list.
    /// </summary>
    procedure ApplyFilterAndSort;

    /// <summary>
    ///   Sets the sort indicator arrow on column header.
    /// </summary>
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
    procedure HistoryMenuItemClick( Sender: TObject );

    /// <summary>
    ///   Builds the commit message templates popup menu.
    /// </summary>
    procedure BuildTemplatesMenu;

    /// <summary>
    ///   Handles click on a template menu item.
    /// </summary>
    procedure TemplateMenuItemClick( Sender: TObject );

    /// <summary>
    ///   Updates the group filter combo box with available groups.
    /// </summary>
    procedure UpdateGroupFilterCombo;

    /// <summary>
    ///   Handles click on a Set Group submenu item.
    /// </summary>
    procedure SetGroupMenuItemClick( Sender: TObject );

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
    ///   Triggers delphi-lookup reindex for a specific repository path.
    /// </summary>
    /// <param name="ARepoPath">
    ///   Full path to the repository that was committed.
    /// </param>
    /// <remarks>
    ///   Captures output and logs success/failure with details.
    ///   Only reindexes if the path matches one of the indexed directories.
    ///   Incremental indexing is fast (~100ms when nothing changed).
    /// </remarks>
    procedure TriggerDelphiLookupReindex( const ARepoPath: string );
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

  FUpdatingList := False;
  FSortColumn := 0;
  FSortAscending := True;
  FStatusFilter := 0;
  FGroupFilter := '';
  FInitialLoadDone := False;
  FLastClickedIndex := -1;
  FFilteredIndices := TList<Integer>.Create;
  FRepoManager := TGitRepoManager.Create;

  // Enable drag-and-drop support
  DragAcceptFiles( Handle, True );

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

  FInitialLoadDone := True;

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

  Screen.Cursor := crHourGlass;

  try
    mmoLog.Lines.Add( 'Loading configuration...' );
    ScrollLogToEnd;
    Update;

    if ( not FRepoManager.LoadConfig ) then
      mmoLog.Lines.Add( 'Warning: Failed to load configuration file' );

    iCount := Length( FRepoManager.Repos );
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
    Screen.Cursor := crDefault;
  end;

end;

/// <summary>
///   Refreshes all repositories asynchronously using parallel processing.
/// </summary>
procedure TMainForm.RefreshReposAsync;
var
  iCount            : Integer;
begin

  if FRefreshing then
  begin
    Log( 'Refresh already in progress...' );
    Exit;
  end;

  iCount := Length( FRepoManager.Repos );
  if iCount = 0 then
    Exit;

  FRefreshing := True;
  Screen.Cursor := crHourGlass;

  TThread.CreateAnonymousThread(
    procedure
    begin
      TParallel.For( 0, iCount - 1,
        procedure( AIndex: Integer )
        var
          sName: string;
        begin
          FRepoManager.RefreshStatus( AIndex );
          sName := FRepoManager.Repos[ AIndex ].Name;

          TThread.Queue( nil,
            procedure
            begin
              UpdateListItem( AIndex );
              mmoLog.Lines.Add( Format( 'Checked %s', [ sName ] ) );
              ScrollLogToEnd;
            end );
        end );

      TThread.Synchronize( nil,
        procedure
        begin
          FRefreshing := False;
          Screen.Cursor := crDefault;
          Log( 'Refresh complete.' );
        end );
    end ).Start;

end;

/// <summary>
///   Cleans up resources when the form is destroyed.
/// </summary>
procedure TMainForm.FormDestroy( Sender: TObject );
begin

  // Save selection state before closing
  FRepoManager.SaveConfig;
  FRepoManager.Free;
  FFilteredIndices.Free;

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

end;

/// <summary>
///   Updates the enabled state of the Commit & Push button.
/// </summary>
procedure TMainForm.UpdateCommitButtonState;
var
  lHasChecked       : Boolean;
  lHasMessage       : Boolean;
begin

  lHasChecked := False;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ i ].Checked then
    begin
      lHasChecked := True;
      Break;
    end;
  end;

  lHasMessage := Trim( edtCommitMessage.Text ) <> '';

  btnCommitPush.Enabled := lHasChecked and lHasMessage;

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

  iCurrentIndex := lvRepos.Selected.Index;

  // Check if Shift is held and we have a previous click
  if ( GetKeyState( VK_SHIFT ) < 0 ) and ( FLastClickedIndex >= 0 ) and
    ( FLastClickedIndex <> iCurrentIndex ) then
  begin
    // Determine range
    if FLastClickedIndex < iCurrentIndex then
    begin
      iStartIndex := FLastClickedIndex;
      iEndIndex := iCurrentIndex;
    end
    else
    begin
      iStartIndex := iCurrentIndex;
      iEndIndex := FLastClickedIndex;
    end;

    // Use the opposite of the anchor item's state as the target
    lNewState := not lvRepos.Items[ FLastClickedIndex ].Checked;

    FUpdatingList := True;

    try
      for var i := iStartIndex to iEndIndex do
        lvRepos.Items[ i ].Checked := lNewState;
    finally
      FUpdatingList := False;
    end;

    UpdateCommitButtonState;
  end
  else
  begin
    // Always update last clicked index (only when not shift-clicking)
    FLastClickedIndex := iCurrentIndex;
  end;

end;

/// <summary>
///   Handles filter menu item click.
/// </summary>
procedure TMainForm.mnuFilterClick( Sender: TObject );
begin

  if Sender = mnuFilterAll then
    FStatusFilter := 0
  else if Sender = mnuFilterClean then
    FStatusFilter := 1
  else if Sender = mnuFilterModified then
    FStatusFilter := 2
  else if Sender = mnuFilterPullRequired then
    FStatusFilter := 3
  else if Sender = mnuFilterError then
    FStatusFilter := 4;

  UpdateFilterMenuChecks;
  PopulateListView;

end;

/// <summary>
///   Handles column click for sorting.
/// </summary>
procedure TMainForm.lvReposColumnClick( Sender: TObject; Column: TListColumn );
begin

  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := Column.Index;
    FSortAscending := True;
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

  Header := ListView_GetHeader( lvRepos.Handle );

  // Clear all arrows first
  for var i := 0 to lvRepos.Columns.Count - 1 do
  begin
    ZeroMemory( @Item, SizeOf( Item ) );
    Item.Mask := HDI_FORMAT;
    Header_GetItem( Header, i, Item );
    Item.fmt := Item.fmt and not ( HDF_SORTDOWN or HDF_SORTUP );
    Header_SetItem( Header, i, Item );
  end;

  // Set arrow on current column
  if iColumn >= 0 then
  begin
    ZeroMemory( @Item, SizeOf( Item ) );
    Item.Mask := HDI_FORMAT;
    Header_GetItem( Header, iColumn, Item );

    if bAscending then
      Item.fmt := Item.fmt or HDF_SORTUP
    else
      Item.fmt := Item.fmt or HDF_SORTDOWN;

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

  FFilteredIndices.Clear;

  // Apply filter
  for var i := 0 to High( FRepoManager.Repos ) do
  begin
    // Apply group filter first
    if ( FGroupFilter <> '' ) and ( FRepoManager.Repos[ i ].Group <> FGroupFilter ) then
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
      else
        FilterStatus := rsUnknown;
      end;

      if FRepoManager.Repos[ i ].Status = FilterStatus then
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
                iValA := FRepoManager.Repos[ A ].TrackedFileCount;
                iValB := FRepoManager.Repos[ B ].TrackedFileCount;
              end;
            5:
              begin
                iValA := FRepoManager.Repos[ A ].ModifiedFileCount;
                iValB := FRepoManager.Repos[ B ].ModifiedFileCount;
              end;
          else
            iValA := 0;
            iValB := 0;
          end;

          Result := iValA - iValB;

          if ( not FSortAscending ) then
            Result := -Result;
        end
        else
        begin
          case FSortColumn of
            0:
              begin
                sValA := FRepoManager.Repos[ A ].Name;
                sValB := FRepoManager.Repos[ B ].Name;
              end;
            1:
              begin
                sValA := FRepoManager.Repos[ A ].Path;
                sValB := FRepoManager.Repos[ B ].Path;
              end;
            2:
              begin
                sValA := FRepoManager.Repos[ A ].Branch;
                sValB := FRepoManager.Repos[ B ].Branch;
              end;
            3:
              begin
                sValA := RemoteProviderToString( FRepoManager.Repos[ A ].Provider );
                sValB := RemoteProviderToString( FRepoManager.Repos[ B ].Provider );
              end;
            6:
              begin
                sValA := FRepoManager.Repos[ A ].StatusText;
                sValB := FRepoManager.Repos[ B ].StatusText;
              end;
            7:
              begin
                sValA := FRepoManager.Repos[ A ].Version;
                sValB := FRepoManager.Repos[ B ].Version;
              end;
          else
            sValA := '';
            sValB := '';
          end;

          Result := CompareText( sValA, sValB );

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

  mmoLog.SelStart := Length( mmoLog.Text );
  mmoLog.SelLength := 0;
  mmoLog.Perform( EM_SCROLLCARET, 0, 0 );

end;

/// <summary>
///   Handles WM_DROPFILES message for drag-and-drop support.
/// </summary>
procedure TMainForm.WMDropFiles( var Msg: TWMDropFiles );
var
  iFileCount        : Integer;
  iAdded            : Integer;
  iSkipped          : Integer;
  Buffer            : array[ 0..MAX_PATH ] of Char;
  sPath             : string;
begin

  iAdded := 0;
  iSkipped := 0;

  try
    iFileCount := DragQueryFile( Msg.Drop, $FFFFFFFF, nil, 0 );

    for var i := 0 to iFileCount - 1 do
    begin
      DragQueryFile( Msg.Drop, i, Buffer, MAX_PATH );
      sPath := Buffer;

      // Only process directories
      if ( not System.SysUtils.DirectoryExists( sPath ) ) then
      begin
        Inc( iSkipped );
        Continue;
      end;

      // Check if it's a valid Git repository
      if ( not System.SysUtils.DirectoryExists( sPath + '\.git' ) ) then
      begin
        Log( Format( 'Skipped (not a Git repository): %s', [ sPath ] ) );
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

  Msg.Result := 0;

end;

/// <summary>
///   Populates the list view with all repositories from the manager.
/// </summary>
procedure TMainForm.PopulateListView;
var
  iRepoIndex        : Integer;
begin

  FUpdatingList := True;

  try
    ApplyFilterAndSort;

    lvRepos.Items.BeginUpdate;

    try
      lvRepos.Items.Clear;

      for var i := 0 to FFilteredIndices.Count - 1 do
      begin
        iRepoIndex := FFilteredIndices[ i ];
        var Item := lvRepos.Items.Add;
        Item.Caption := FRepoManager.Repos[ iRepoIndex ].Name;
        Item.SubItems.Add( FRepoManager.Repos[ iRepoIndex ].Path );
        Item.SubItems.Add( FRepoManager.Repos[ iRepoIndex ].Branch );
        Item.SubItems.Add( RemoteProviderToString( FRepoManager.Repos[ iRepoIndex ].Provider ) );
        Item.SubItems.Add( IntToStr( FRepoManager.Repos[ iRepoIndex ].TrackedFileCount ) );
        Item.SubItems.Add( IntToStr( FRepoManager.Repos[ iRepoIndex ].ModifiedFileCount ) );
        Item.SubItems.Add( FRepoManager.Repos[ iRepoIndex ].StatusText );
        Item.SubItems.Add( FRepoManager.Repos[ iRepoIndex ].Version );
        Item.Checked := FRepoManager.Repos[ iRepoIndex ].Selected;
        Item.Data := Pointer( iRepoIndex );
      end;
    finally
      lvRepos.Items.EndUpdate;
    end;

    UpdateCommitButtonState;
  finally
    FUpdatingList := False;
  end;

end;

/// <summary>
///   Updates a single list item with current repository data.
/// </summary>
procedure TMainForm.UpdateListItem( const iIndex: Integer );
begin

  // Find the list item with matching repo index
  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if Integer( lvRepos.Items[ i ].Data ) = iIndex then
    begin
      FUpdatingList := True;

      try
        var Item := lvRepos.Items[ i ];
        Item.Caption := FRepoManager.Repos[ iIndex ].Name;
        Item.SubItems[ 0 ] := FRepoManager.Repos[ iIndex ].Path;
        Item.SubItems[ 1 ] := FRepoManager.Repos[ iIndex ].Branch;
        Item.SubItems[ 2 ] := RemoteProviderToString( FRepoManager.Repos[ iIndex ].Provider );
        Item.SubItems[ 3 ] := IntToStr( FRepoManager.Repos[ iIndex ].TrackedFileCount );
        Item.SubItems[ 4 ] := IntToStr( FRepoManager.Repos[ iIndex ].ModifiedFileCount );
        Item.SubItems[ 5 ] := FRepoManager.Repos[ iIndex ].StatusText;
        Item.SubItems[ 6 ] := FRepoManager.Repos[ iIndex ].Version;
        lvRepos.UpdateItems( i, i );
      finally
        FUpdatingList := False;
      end;

      Exit;
    end;
  end;

end;

/// <summary>
///   Appends a message to the log memo and scrolls to show it.
/// </summary>
procedure TMainForm.Log( const sText: string );
begin

  mmoLog.Lines.Add( sText );
  ScrollLogToEnd;
  Application.ProcessMessages;

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
    if ( not System.SysUtils.DirectoryExists( sFolder + '\.git' ) ) then
    begin
      MessageDlg( 'The selected folder is not a Git repository.', mtWarning, [ mbOK ], 0 );
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
  IndicesToRemove := TList<Integer>.Create;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
        IndicesToRemove.Add( Integer( lvRepos.Items[ i ].Data ) );
    end;

    if IndicesToRemove.Count = 0 then
    begin
      MessageDlg( 'Please check one or more repositories to remove.', mtInformation, [ mbOK ], 0 );
      Exit;
    end;

    if MessageDlg( Format( 'Remove %d repository(ies) from the list?', [ IndicesToRemove.Count ] ),
      mtConfirmation, [ mbYes, mbNo ], 0 ) = mrYes then
    begin
      // Sort descending so we remove from highest index first (avoids index shifting issues)
      IndicesToRemove.Sort( TComparer<Integer>.Construct(
        function( const A, B: Integer ): Integer
        begin
          Result := B - A;
        end ) );

      for iRepoIndex in IndicesToRemove do
      begin
        Log( Format( 'Removed repository: %s', [ FRepoManager.Repos[ iRepoIndex ].Name ] ) );
        FRepoManager.RemoveRepository( iRepoIndex );
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

  Log( Format( 'Refreshing %d repositories...', [ Length( FRepoManager.Repos ) ] ) );
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
  sLog              : string;
  iRepoIndex        : Integer;
  sSummary          : string;
  sDetails          : string;
  sMessage          : string;
begin

  sSummary := Trim( edtCommitMessage.Text );

  if sSummary.IsEmpty then
  begin
    MessageDlg( 'Please enter a commit message.', mtWarning, [ mbOK ], 0 );
    edtCommitMessage.SetFocus;
    Exit;
  end;

  // Build full commit message with optional details
  sDetails := Trim( mmoDetails.Text );

  if sDetails.IsEmpty then
    sMessage := sSummary
  else
    sMessage := sSummary + sLineBreak + sLineBreak + sDetails;

  // Count selected repositories with modifications
  var iCount := 0;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    iRepoIndex := Integer( lvRepos.Items[ i ].Data );

    if lvRepos.Items[ i ].Checked and ( FRepoManager.Repos[ iRepoIndex ].Status = rsModified ) then
      Inc( iCount );
  end;

  if iCount = 0 then
  begin
    MessageDlg( 'No modified repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if MessageDlg( Format( 'Commit and push %d repository(ies)?', [ iCount ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;

  var iSuccess := 0;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      iRepoIndex := Integer( lvRepos.Items[ i ].Data );

      if lvRepos.Items[ i ].Checked and ( FRepoManager.Repos[ iRepoIndex ].Status = rsModified ) then
      begin
        var bCommitSuccess := FRepoManager.CommitAndPush( iRepoIndex, sMessage, sLog );

        if bCommitSuccess then
          Inc( iSuccess );

        Log( sLog );

        // Trigger reindex after logging commit details (only if commit succeeded)
        if bCommitSuccess then
          TriggerDelphiLookupReindex( FRepoManager.Repos[ iRepoIndex ].Path );

        UpdateListItem( iRepoIndex );
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  Log( Format( 'Completed: %d of %d successful.', [ iSuccess, iCount ] ) );

  // Clear details after successful commit
  if iSuccess > 0 then
  begin
    mmoDetails.Clear;
    pnlDetails.Visible := False;
  end;

  MessageDlg( Format( 'Completed: %d of %d successful.', [ iSuccess, iCount ] ), mtInformation, [ mbOK ], 0 );

end;

/// <summary>
///   Selects only repositories with modified status.
/// </summary>
procedure TMainForm.btnSelectModifiedClick( Sender: TObject );
var
  iRepoIndex        : Integer;
begin

  FUpdatingList := True;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      iRepoIndex := Integer( lvRepos.Items[ i ].Data );
      lvRepos.Items[ i ].Checked := ( FRepoManager.Repos[ iRepoIndex ].Status = rsModified );
    end;
  finally
    FUpdatingList := False;
  end;

  UpdateCommitButtonState;

end;

/// <summary>
///   Selects all repositories in the list.
/// </summary>
procedure TMainForm.btnSelectAllClick( Sender: TObject );
begin

  FUpdatingList := True;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
      lvRepos.Items[ i ].Checked := True;
  finally
    FUpdatingList := False;
  end;

  UpdateCommitButtonState;

end;

/// <summary>
///   Deselects all repositories in the list.
/// </summary>
procedure TMainForm.btnSelectNoneClick( Sender: TObject );
begin

  FUpdatingList := True;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
      lvRepos.Items[ i ].Checked := False;
  finally
    FUpdatingList := False;
  end;

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

  iIndex := Integer( Item.Data );

  if ( iIndex >= 0 ) and ( iIndex <= High( FRepoManager.Repos ) ) then
    FRepoManager.Repos[ iIndex ].Selected := Item.Checked;

  UpdateCommitButtonState;

end;

/// <summary>
///   Handles the Codeberg > Settings menu click.
/// </summary>
procedure TMainForm.mnuCodebergSettingsClick( Sender: TObject );
var
  sUsername, sToken : string;
begin

  sUsername := FRepoManager.CodebergUsername;
  sToken := FRepoManager.CodebergToken;

  if TCodebergSettingsDialog.Execute( sUsername, sToken ) then
  begin
    FRepoManager.CodebergUsername := sUsername;
    FRepoManager.CodebergToken := sToken;
    FRepoManager.SaveConfig;
    Log( 'Codeberg credentials updated.' );
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
    MessageDlg( 'Please configure Codeberg credentials first.', mtWarning, [ mbOK ], 0 );
    mnuCodebergSettingsClick( nil );

    if ( not FRepoManager.HasCodebergCredentials ) then
      Exit;
  end;

  // Select folder
  if ( not SelectDirectory( 'Select Folder to Initialize as Git Repository', '', sFolder ) ) then
    Exit;

  // Check if already a Git repository
  if System.SysUtils.DirectoryExists( sFolder + '\.git' ) then
  begin
    MessageDlg( 'The selected folder is already a Git repository.' + sLineBreak +
      'Use File > Add Repository instead.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  // Get repository details
  sRepoName := ExtractFileName( ExcludeTrailingPathDelimiter( sFolder ) );
  sDescription := '';
  lPrivate := False;

  if ( not TCodebergDialog.Execute( sRepoName, sDescription, lPrivate ) ) then
    Exit;

  // Confirm operation
  if MessageDlg( Format( 'This will:%s%s' +
    '1. Initialize Git repository in: %s%s' +
    '2. Create %s repository "%s" on Codeberg%s' +
    '3. Commit all files and push%s%s' +
    'Continue?',
    [ sLineBreak, sLineBreak,
      sFolder, sLineBreak,
      IfThen( lPrivate, 'private', 'public' ), sRepoName, sLineBreak,
      sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;

  try
    // Step 1: Initialize local repository
    Log( '=== Initializing Local Repository ===' );

    if ( not FRepoManager.InitializeRepository( sFolder, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      MessageDlg( 'Failed to initialize repository: ' + sLog, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( sLog );

    // Step 2: Create Codeberg repository
    Log( '=== Creating Codeberg Repository ===' );

    if ( not FRepoManager.CreateCodebergRepository( sRepoName, sDescription, lPrivate, sRemoteURL, sError ) ) then
    begin
      Log( 'Error: ' + sError );
      MessageDlg( 'Failed to create Codeberg repository: ' + sError, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( 'Created repository: ' + sRemoteURL );

    // Step 3: Add remote origin
    Log( '=== Adding Remote Origin ===' );

    if ( not FRepoManager.AddRemoteOrigin( sFolder, sRemoteURL, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      MessageDlg( 'Failed to add remote origin: ' + sLog, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( sLog );

    // Step 4: Initial commit and push
    Log( '=== Initial Commit and Push ===' );

    if ( not FRepoManager.InitialCommitAndPush( sFolder, 'Initial commit', sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      MessageDlg( 'Failed to commit and push: ' + sLog, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( sLog );

    // Add to repository list
    FRepoManager.AddRepository( sFolder );
    PopulateListView;

    Log( '=== Complete ===' );
    Log( 'Repository URL: https://codeberg.org/' + FRepoManager.CodebergUsername + '/' + sRepoName );

    MessageDlg( 'Repository created and pushed successfully!' + sLineBreak + sLineBreak +
      'URL: https://codeberg.org/' + FRepoManager.CodebergUsername + '/' + sRepoName,
      mtInformation, [ mbOK ], 0 );
  finally
    Screen.Cursor := crDefault;
  end;

end;

/// <summary>
///   Handles the GitHub > Settings menu click.
/// </summary>
procedure TMainForm.mnuGitHubSettingsClick( Sender: TObject );
var
  sUsername, sToken : string;
begin

  sUsername := FRepoManager.GitHubUsername;
  sToken := FRepoManager.GitHubToken;

  if TGitHubSettingsDialog.Execute( sUsername, sToken ) then
  begin
    FRepoManager.GitHubUsername := sUsername;
    FRepoManager.GitHubToken := sToken;
    FRepoManager.SaveConfig;
    Log( 'GitHub credentials updated.' );
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
    MessageDlg( 'Please configure GitHub credentials first.', mtWarning, [ mbOK ], 0 );
    mnuGitHubSettingsClick( nil );

    if ( not FRepoManager.HasGitHubCredentials ) then
      Exit;
  end;

  // Select folder
  if ( not SelectDirectory( 'Select Folder to Initialize as Git Repository', '', sFolder ) ) then
    Exit;

  // Check if already a Git repository
  if System.SysUtils.DirectoryExists( sFolder + '\.git' ) then
  begin
    MessageDlg( 'The selected folder is already a Git repository.' + sLineBreak +
      'Use File > Add Repository instead.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  // Get repository details (reuse Codeberg dialog as it has same fields)
  sRepoName := ExtractFileName( ExcludeTrailingPathDelimiter( sFolder ) );
  sDescription := '';
  lPrivate := False;

  if ( not TCodebergDialog.Execute( sRepoName, sDescription, lPrivate ) ) then
    Exit;

  // Confirm operation
  if MessageDlg( Format( 'This will:%s%s' +
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

  Screen.Cursor := crHourGlass;

  try
    // Step 1: Initialize local repository
    Log( '=== Initializing Local Repository ===' );

    if ( not FRepoManager.InitializeRepository( sFolder, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      MessageDlg( 'Failed to initialize repository: ' + sLog, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( sLog );

    // Step 2: Create GitHub repository
    Log( '=== Creating GitHub Repository ===' );

    if ( not FRepoManager.CreateGitHubRepository( sRepoName, sDescription, lPrivate, sRemoteURL, sError ) ) then
    begin
      Log( 'Error: ' + sError );
      MessageDlg( 'Failed to create GitHub repository: ' + sError, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( 'Created repository: ' + sRemoteURL );

    // Step 3: Add remote origin
    Log( '=== Adding Remote Origin ===' );

    if ( not FRepoManager.AddRemoteOrigin( sFolder, sRemoteURL, sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      MessageDlg( 'Failed to add remote origin: ' + sLog, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( sLog );

    // Step 4: Initial commit and push
    Log( '=== Initial Commit and Push ===' );

    if ( not FRepoManager.InitialCommitAndPush( sFolder, 'Initial commit', sLog ) ) then
    begin
      Log( 'Error: ' + sLog );
      MessageDlg( 'Failed to commit and push: ' + sLog, mtError, [ mbOK ], 0 );
      Exit;
    end;

    Log( sLog );

    // Add to repository list
    FRepoManager.AddRepository( sFolder );
    PopulateListView;

    Log( '=== Complete ===' );
    Log( 'Repository URL: https://github.com/' + FRepoManager.GitHubUsername + '/' + sRepoName );

    MessageDlg( 'Repository created and pushed successfully!' + sLineBreak + sLineBreak +
      'URL: https://github.com/' + FRepoManager.GitHubUsername + '/' + sRepoName,
      mtInformation, [ mbOK ], 0 );
  finally
    Screen.Cursor := crDefault;
  end;

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
    MessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex := Integer( lvRepos.Selected.Data );
  Provider := FRepoManager.GetRepoProvider( iIndex );

  case Provider of
    rpCodeberg: sProviderName := 'Codeberg';
    rpGitHub: sProviderName := 'GitHub';
    rpOther:
      begin
        MessageDlg( 'Visibility change only supported for GitHub and Codeberg repositories.',
          mtWarning, [ mbOK ], 0 );
        Exit;
      end;
    rpNone:
      begin
        MessageDlg( 'This repository has no remote origin configured.', mtWarning, [ mbOK ], 0 );
        Exit;
      end;
  end;

  if MessageDlg( Format( 'Make repository "%s" PUBLIC on %s?%s%s' +
    'This will make the repository visible to everyone.',
    [ FRepoManager.Repos[ iIndex ].Name, sProviderName, sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;

  try
    if FRepoManager.SetRepositoryVisibility( iIndex, False, sError ) then
    begin
      Log( Format( 'Repository "%s" set to PUBLIC on %s',
        [ FRepoManager.Repos[ iIndex ].Name, sProviderName ] ) );
      MessageDlg( 'Repository visibility changed to PUBLIC.', mtInformation, [ mbOK ], 0 );
    end
    else
    begin
      Log( 'Error: ' + sError );
      MessageDlg( 'Failed to change visibility: ' + sError, mtError, [ mbOK ], 0 );
    end;
  finally
    Screen.Cursor := crDefault;
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
    MessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex := Integer( lvRepos.Selected.Data );
  Provider := FRepoManager.GetRepoProvider( iIndex );

  case Provider of
    rpCodeberg: sProviderName := 'Codeberg';
    rpGitHub: sProviderName := 'GitHub';
    rpOther:
      begin
        MessageDlg( 'Visibility change only supported for GitHub and Codeberg repositories.',
          mtWarning, [ mbOK ], 0 );
        Exit;
      end;
    rpNone:
      begin
        MessageDlg( 'This repository has no remote origin configured.', mtWarning, [ mbOK ], 0 );
        Exit;
      end;
  end;

  if MessageDlg( Format( 'Make repository "%s" PRIVATE on %s?%s%s' +
    'This will make the repository visible only to you.',
    [ FRepoManager.Repos[ iIndex ].Name, sProviderName, sLineBreak, sLineBreak ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;

  try
    if FRepoManager.SetRepositoryVisibility( iIndex, True, sError ) then
    begin
      Log( Format( 'Repository "%s" set to PRIVATE on %s',
        [ FRepoManager.Repos[ iIndex ].Name, sProviderName ] ) );
      MessageDlg( 'Repository visibility changed to PRIVATE.', mtInformation, [ mbOK ], 0 );
    end
    else
    begin
      Log( 'Error: ' + sError );
      MessageDlg( 'Failed to change visibility: ' + sError, mtError, [ mbOK ], 0 );
    end;
  finally
    Screen.Cursor := crDefault;
  end;

end;

/// <summary>
///   Handles the popup menu opening to enable/disable items.
/// </summary>
procedure TMainForm.pmReposPopup( Sender: TObject );
var
  Groups            : TArray<string>;
  MenuItem          : TMenuItem;
  SubMenu           : TMenuItem;
begin

  // Enable .gitignore options only when a single repository is selected
  pmEditGitignore.Enabled := ( lvRepos.Selected <> nil );
  pmFixGitignore.Enabled := ( lvRepos.Selected <> nil );

  // Build the Set Group submenu
  pmSetGroup.Clear;

  Groups := FRepoManager.GetAllGroups;

  // Add existing groups
  for var i := 0 to High( Groups ) do
  begin
    MenuItem := TMenuItem.Create( pmSetGroup );
    MenuItem.Caption := Groups[ i ];
    MenuItem.Tag := i;
    MenuItem.OnClick := SetGroupMenuItemClick;
    pmSetGroup.Add( MenuItem );
  end;

  // Add separator if there are groups
  if Length( Groups ) > 0 then
  begin
    SubMenu := TMenuItem.Create( pmSetGroup );
    SubMenu.Caption := '-';
    pmSetGroup.Add( SubMenu );
  end;

  // Add "Clear Group" option
  MenuItem := TMenuItem.Create( pmSetGroup );
  MenuItem.Caption := '(Clear Group)';
  MenuItem.Tag := -1;
  MenuItem.OnClick := SetGroupMenuItemClick;
  pmSetGroup.Add( MenuItem );

  // Add "New Group..." option
  MenuItem := TMenuItem.Create( pmSetGroup );
  MenuItem.Caption := 'New Group...';
  MenuItem.Tag := -2;
  MenuItem.OnClick := SetGroupMenuItemClick;
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
    MessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex := Integer( lvRepos.Selected.Data );
  sGitignorePath := IncludeTrailingPathDelimiter( FRepoManager.Repos[ iIndex ].Path ) + '.gitignore';

  // Check if .gitignore exists, offer to create if not
  if ( not FileExists( sGitignorePath ) ) then
  begin
    if MessageDlg( Format( 'No .gitignore file exists in "%s".%s%sCreate one now?',
      [ FRepoManager.Repos[ iIndex ].Name, sLineBreak, sLineBreak ] ),
      mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
      Exit;

    // Create empty .gitignore file
    try
      FileStream := TFileStream.Create( sGitignorePath, fmCreate );
      try
        // File created empty
      finally
        FileStream.Free;
      end;

      Log( 'Created .gitignore in ' + FRepoManager.Repos[ iIndex ].Name );
    except
      on E: Exception do
      begin
        MessageDlg( 'Failed to create .gitignore: ' + E.Message, mtError, [ mbOK ], 0 );
        Exit;
      end;
    end;
  end;

  // Open in default editor
  ShellExecute( Handle, 'open', PChar( sGitignorePath ), nil, nil, SW_SHOWNORMAL );

end;

/// <summary>
///   Handles the Fix .gitignore menu click - adds standard Delphi ignore patterns.
/// </summary>
procedure TMainForm.pmFixGitignoreClick( Sender: TObject );
const
  DELPHI_PATTERNS: array[0..24] of string = (
    '# Delphi build artifacts',
    '*.dcu',
    '*.exe',
    '*.dll',
    '*.bpl',
    '*.dcp',
    '*.dres',
    '*.res',
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
  sLowerContent     : string;
  iAddedCount       : Integer;
begin

  if lvRepos.Selected = nil then
  begin
    MessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex := Integer( lvRepos.Selected.Data );
  sGitignorePath := IncludeTrailingPathDelimiter( FRepoManager.Repos[ iIndex ].Path ) + '.gitignore';

  slExisting := TStringList.Create;
  slToAdd := TStringList.Create;

  try
    // Read existing .gitignore content
    if FileExists( sGitignorePath ) then
    begin
      try
        slExisting.LoadFromFile( sGitignorePath );
      except
        on E: Exception do
        begin
          MessageDlg( 'Failed to read .gitignore: ' + E.Message, mtError, [ mbOK ], 0 );
          Exit;
        end;
      end;
    end;

    // Build lowercase version for case-insensitive comparison
    sLowerContent := slExisting.Text.ToLower;

    // Check which patterns are missing
    for sPattern in DELPHI_PATTERNS do
    begin
      // Skip the comment header - always add it if we're adding patterns
      if sPattern.StartsWith( '#' ) then
        Continue;

      // Check if pattern already exists (case-insensitive)
      if not sLowerContent.Contains( sPattern.ToLower ) then
        slToAdd.Add( sPattern );
    end;

    if slToAdd.Count = 0 then
    begin
      MessageDlg( 'All standard Delphi patterns are already in .gitignore.', mtInformation, [ mbOK ], 0 );
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
      iAddedCount := 0;
      for sPattern in DELPHI_PATTERNS do
      begin
        if sPattern.StartsWith( '#' ) then
          Continue;

        if not sLowerContent.Contains( sPattern.ToLower ) then
        begin
          slExisting.Add( sPattern );
          Inc( iAddedCount );
        end;
      end;

      // Save the file
      slExisting.SaveToFile( sGitignorePath );

      Log( Format( 'Added %d Delphi patterns to .gitignore in %s', [ iAddedCount, FRepoManager.Repos[ iIndex ].Name ] ) );
      MessageDlg( Format( 'Added %d patterns to .gitignore.', [ iAddedCount ] ), mtInformation, [ mbOK ], 0 );

      // Refresh the repository status
      FRepoManager.RefreshStatus( iIndex );
      UpdateListItem( iIndex );

    except
      on E: Exception do
      begin
        MessageDlg( 'Failed to save .gitignore: ' + E.Message, mtError, [ mbOK ], 0 );
        Exit;
      end;
    end;

  finally
    slExisting.Free;
    slToAdd.Free;
  end;

end;

/// <summary>
///   Handles the Help > Help Contents menu click.
/// </summary>
procedure TMainForm.mnuHelpContentsClick( Sender: TObject );
var
  sReadmePath       : string;
begin

  sReadmePath := ExtractFilePath( Application.ExeName ) + 'README.md';

  if ( not FileExists( sReadmePath ) ) then
  begin
    MessageDlg( 'README.md not found in application folder.', mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  ShellExecute( Handle, 'open', PChar( sReadmePath ), nil, nil, SW_SHOWNORMAL );

end;

/// <summary>
///   Handles the Help > About menu click.
/// </summary>
procedure TMainForm.mnuAboutClick( Sender: TObject );
const
  APP_VERSION       = '1.4.0';
begin

  MessageDlg(
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

  if Item = nil then
    Exit;

  iIndex := Integer( Item.Data );

  if ( iIndex < 0 ) or ( iIndex > High( FRepoManager.Repos ) ) then
    Exit;

  Status := FRepoManager.Repos[ iIndex ].Status;

  // Set background colour based on status
  case Status of
    rsClean:
      Sender.Canvas.Brush.Color := $E0FFE0; // Light green
    rsModified:
      Sender.Canvas.Brush.Color := $FFFFC0; // Light yellow
    rsPullRequired:
      Sender.Canvas.Brush.Color := $FFE0C0; // Light orange
    rsError:
      Sender.Canvas.Brush.Color := $C0C0FF; // Light red
    rsUnknown:
      Sender.Canvas.Brush.Color := clWindow;
  end;

  // If selected, use highlight colour
  if cdsSelected in State then
    Sender.Canvas.Brush.Color := clHighlight;

  DefaultDraw := True;

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

  iIndex := Integer( lvRepos.Selected.Data );
  ShellExecute( Handle, 'explore', PChar( FRepoManager.Repos[ iIndex ].Path ), nil, nil, SW_SHOWNORMAL );

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

  iIndex := Integer( lvRepos.Selected.Data );
  sRepoPath := FRepoManager.Repos[ iIndex ].Path;
  sClientPath := FRepoManager.GitClientPath;

  if sClientPath.IsEmpty then
  begin
    MessageDlg( 'No Git client configured. Please set the Git client path in File > Settings.',
      mtWarning, [ mbOK ], 0 );
    Exit;
  end;

  if ( not FileExists( sClientPath ) ) then
  begin
    MessageDlg( 'Git client not found: ' + sClientPath, mtError, [ mbOK ], 0 );
    Exit;
  end;

  ShellExecute( Handle, 'open', PChar( sClientPath ), PChar( '"' + sRepoPath + '"' ), nil, SW_SHOWNORMAL );

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
begin

  if lvRepos.Selected = nil then
    Exit;

  iIndex := Integer( lvRepos.Selected.Data );

  // Strong warning about local code being modified
  if MessageDlg(
    'WARNING: Pull will merge remote changes into your LOCAL code.' + sLineBreak + sLineBreak +
    'Your local files for "' + FRepoManager.Repos[ iIndex ].Name + '" MAY BE MODIFIED.' + sLineBreak + sLineBreak +
    'A backup branch will be created before pulling.' + sLineBreak + sLineBreak +
    'Do you want to continue?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;

  try
    // Preview incoming changes
    Log( 'Fetching and previewing incoming changes...' );
    if FRepoManager.GetIncomingChanges( iIndex, sChanges, sLog ) then
    begin
      if not sChanges.IsEmpty then
      begin
        Screen.Cursor := crDefault;
        if MessageDlg(
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
    if FRepoManager.CreateBackupBranch( iIndex, sBranchName, sLog ) then
      Log( sLog )
    else
      Log( 'Warning: Could not create backup branch: ' + sLog );

    // Now pull
    Log( 'Pulling ' + FRepoManager.Repos[ iIndex ].Name + '...' );

    if FRepoManager.PullRepository( iIndex, sLog ) then
    begin
      Log( sLog );
      Log( 'Pull complete.' );
      Log( 'Backup branch "' + sBranchName + '" was created. Delete with: git branch -d ' + sBranchName );
      FRepoManager.RefreshStatus( iIndex );
      UpdateListItem( iIndex );
    end
    else
    begin
      Log( 'Pull failed: ' + sLog );
      MessageDlg( 'Pull failed: ' + sLog, mtError, [ mbOK ], 0 );
    end;
  finally
    Screen.Cursor := crDefault;
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

  Pt := btnHistory.ClientToScreen( Point( 0, btnHistory.Height ) );
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

  History := FRepoManager.CommitHistory;

  if Length( History ) = 0 then
  begin
    MenuItem := TMenuItem.Create( pmHistory );
    MenuItem.Caption := '(No history)';
    MenuItem.Enabled := False;
    pmHistory.Items.Add( MenuItem );
    Exit;
  end;

  for var i := 0 to High( History ) do
  begin
    MenuItem := TMenuItem.Create( pmHistory );
    MenuItem.Caption := History[ i ];
    MenuItem.Tag := i;
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

  MenuItem := Sender as TMenuItem;
  History := FRepoManager.CommitHistory;

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

  sClientPath := FRepoManager.GitClientPath;
  sFilePattern := FRepoManager.FilePattern;
  sIndexerPath := FRepoManager.DelphiIndexerPath;

  // Use separate InputQuery calls since the multi-value version has issues
  if InputQuery( 'Settings', 'Git Client Path (e.g., C:\Program Files\Fork\Fork.exe):', sClientPath ) then
  begin
    if InputQuery( 'Settings', 'File Pattern (e.g., *.pas or empty for all):', sFilePattern ) then
    begin
      // Ask if user wants to configure delphi-indexer path
      if MessageDlg( 'Configure delphi-indexer.exe path?' + sLineBreak + sLineBreak +
        'Current: ' + IfThen( sIndexerPath.IsEmpty, '(Auto-detect)', sIndexerPath ),
        mtConfirmation, [ mbYes, mbNo ], 0 ) = mrYes then
      begin
        OpenDialog := TOpenDialog.Create( nil );
        try
          OpenDialog.Title := 'Locate delphi-indexer.exe';
          OpenDialog.Filter := 'Delphi Indexer|delphi-indexer.exe|Executable Files|*.exe|All Files|*.*';
          OpenDialog.FilterIndex := 1;
          OpenDialog.Options := [ ofFileMustExist, ofPathMustExist ];

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

  Pt := btnTemplates.ClientToScreen( Point( 0, btnTemplates.Height ) );
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

  Templates := FRepoManager.CommitTemplates;

  if Length( Templates ) = 0 then
  begin
    MenuItem := TMenuItem.Create( pmTemplates );
    MenuItem.Caption := '(No templates - use File > Template Settings to add)';
    MenuItem.Enabled := False;
    pmTemplates.Items.Add( MenuItem );
    Exit;
  end;

  for var i := 0 to High( Templates ) do
  begin
    MenuItem := TMenuItem.Create( pmTemplates );
    MenuItem.Caption := Templates[ i ];
    MenuItem.Tag := i;
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

  MenuItem := Sender as TMenuItem;
  Templates := FRepoManager.CommitTemplates;

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

  Templates := FRepoManager.CommitTemplates;

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

  sCurrentGroup := cboGroupFilter.Text;
  cboGroupFilter.Items.Clear;
  cboGroupFilter.Items.Add( '(All Groups)' );

  Groups := FRepoManager.GetAllGroups;

  for var i := 0 to High( Groups ) do
    cboGroupFilter.Items.Add( Groups[ i ] );

  // Restore selection
  if sCurrentGroup.IsEmpty or ( sCurrentGroup = '(All Groups)' ) then
    cboGroupFilter.ItemIndex := 0
  else
  begin
    var iIndex := cboGroupFilter.Items.IndexOf( sCurrentGroup );

    if iIndex >= 0 then
      cboGroupFilter.ItemIndex := iIndex
    else
      cboGroupFilter.ItemIndex := 0;
  end;

end;

/// <summary>
///   Handles group filter combo box change.
/// </summary>
procedure TMainForm.cboGroupFilterChange( Sender: TObject );
begin

  if cboGroupFilter.ItemIndex <= 0 then
    FGroupFilter := ''
  else
    FGroupFilter := cboGroupFilter.Text;

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
begin

  MenuItem := Sender as TMenuItem;
  sGroup := '';

  // Determine group name first
  if MenuItem.Tag = -1 then
  begin
    // Clear group
    sGroup := '';
  end
  else if MenuItem.Tag = -2 then
  begin
    // New group
    if ( not InputQuery( 'New Group', 'Enter group name:', sGroup ) ) then
      Exit;

    sGroup := Trim( sGroup );

    if sGroup.IsEmpty then
      Exit;
  end
  else
  begin
    // Existing group
    Groups := FRepoManager.GetAllGroups;

    if ( MenuItem.Tag >= 0 ) and ( MenuItem.Tag <= High( Groups ) ) then
      sGroup := Groups[ MenuItem.Tag ]
    else
      Exit;
  end;

  // Apply to all checked repositories
  iCount := 0;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ i ].Checked then
    begin
      iRepoIndex := Integer( lvRepos.Items[ i ].Data );
      FRepoManager.SetRepoGroup( iRepoIndex, sGroup );
      Inc( iCount );
    end;
  end;

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
begin

  // Count selected repositories
  iCount := 0;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ i ].Checked then
      Inc( iCount );
  end;

  if iCount = 0 then
  begin
    MessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  // Strong warning about local code being modified
  if MessageDlg(
    'WARNING: Pull will merge remote changes into your LOCAL code.' + sLineBreak + sLineBreak +
    'Your local files MAY BE MODIFIED by this operation.' + sLineBreak + sLineBreak +
    'A backup branch will be created before pulling.' + sLineBreak + sLineBreak +
    'Do you want to continue?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  // Fetch and preview incoming changes
  Log( 'Fetching and previewing incoming changes...' );
  Screen.Cursor := crHourGlass;
  slPreview := TStringList.Create;
  bHasChanges := False;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
      begin
        iRepoIndex := Integer( lvRepos.Items[ i ].Data );
        if FRepoManager.GetIncomingChanges( iRepoIndex, sChanges, sLog ) then
        begin
          if not sChanges.IsEmpty then
          begin
            slPreview.Add( '=== ' + FRepoManager.Repos[ iRepoIndex ].Name + ' ===' );
            slPreview.Add( sChanges );
            slPreview.Add( '' );
            bHasChanges := True;
          end;
        end;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  // Show preview and confirm
  if bHasChanges then
  begin
    if MessageDlg(
      'The following files will be MODIFIED by the pull:' + sLineBreak + sLineBreak +
      slPreview.Text + sLineBreak +
      'Do you want to proceed? (Backup branches will be created)',
      mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    begin
      slPreview.Free;
      Log( 'Pull cancelled by user.' );
      Exit;
    end;
  end
  else
    Log( 'No incoming changes detected (or could not determine changes).' );

  slPreview.Free;

  // Now perform the actual pull with backup
  Screen.Cursor := crHourGlass;
  iSuccess := 0;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
      begin
        iRepoIndex := Integer( lvRepos.Items[ i ].Data );

        Log( Format( '=== Pulling %s ===', [ FRepoManager.Repos[ iRepoIndex ].Name ] ) );

        // Create backup branch first
        if FRepoManager.CreateBackupBranch( iRepoIndex, sBranchName, sLog ) then
          Log( sLog )
        else
          Log( 'Warning: Could not create backup branch: ' + sLog );

        // Now pull
        if FRepoManager.PullRepository( iRepoIndex, sLog ) then
        begin
          Log( sLog );
          Inc( iSuccess );
        end
        else
          Log( 'Pull failed: ' + sLog );

        FRepoManager.RefreshStatus( iRepoIndex );
        UpdateListItem( iRepoIndex );
        Application.ProcessMessages;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  Log( Format( 'Pull completed: %d of %d successful.', [ iSuccess, iCount ] ) );
  Log( 'Backup branches were created. Use "git branch -d <branch-name>" to delete them if no longer needed.' );
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
begin

  // Count selected repositories
  iCount := 0;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ i ].Checked then
      Inc( iCount );
  end;

  if iCount = 0 then
  begin
    MessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if MessageDlg( Format( 'Resolve conflicts for %d repository(ies) by keeping LOCAL versions?' + sLineBreak +
    sLineBreak + 'This will:' + sLineBreak +
    '- Keep your local version of all conflicted files' + sLineBreak +
    '- Commit the merge resolution' + sLineBreak +
    '- Push to remote', [ iCount ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;
  iSuccess := 0;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
      begin
        iRepoIndex := Integer( lvRepos.Items[ i ].Data );

        var bResolveSuccess := FRepoManager.ResolveConflictsKeepLocal( iRepoIndex, sLog );

        Log( sLog );

        if bResolveSuccess then
        begin
          Inc( iSuccess );
          // Trigger reindex after successful conflict resolution (commits and pushes)
          TriggerDelphiLookupReindex( FRepoManager.Repos[ iRepoIndex ].Path );
        end;

        FRepoManager.RefreshStatus( iRepoIndex );
        UpdateListItem( iRepoIndex );
        Application.ProcessMessages;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  Log( Format( 'Resolve conflicts completed: %d of %d successful.', [ iSuccess, iCount ] ) );
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
begin

  // Count selected repositories
  iCount := 0;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ i ].Checked then
      Inc( iCount );
  end;

  if iCount = 0 then
  begin
    MessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  if MessageDlg( Format( 'Push %d repository(ies) without committing?', [ iCount ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;
  iSuccess := 0;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
      begin
        iRepoIndex := Integer( lvRepos.Items[ i ].Data );

        Log( Format( '=== Pushing %s ===', [ FRepoManager.Repos[ iRepoIndex ].Name ] ) );

        var bPushSuccess := FRepoManager.PushRepository( iRepoIndex, sLog );

        Log( sLog );

        if bPushSuccess then
        begin
          Inc( iSuccess );
          // Trigger reindex after successful push
          TriggerDelphiLookupReindex( FRepoManager.Repos[ iRepoIndex ].Path );
        end;

        FRepoManager.RefreshStatus( iRepoIndex );
        UpdateListItem( iRepoIndex );
        Application.ProcessMessages;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  Log( Format( 'Push completed: %d of %d successful.', [ iSuccess, iCount ] ) );
  ScrollLogToEnd;

end;

procedure TMainForm.btnForcePushClick( Sender: TObject );
var
  iRepoIndex        : Integer;
  sLog              : string;
  iCount            : Integer;
  iSuccess          : Integer;
begin

  // Count selected repositories
  iCount := 0;

  for var i := 0 to lvRepos.Items.Count - 1 do
  begin
    if lvRepos.Items[ i ].Checked then
      Inc( iCount );
  end;

  if iCount = 0 then
  begin
    MessageDlg( 'No repositories selected.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  // Strong warning about force push
  if MessageDlg(
    'WARNING: Force Push will OVERWRITE the remote repository history!' + sLineBreak + sLineBreak +
    'This makes your local code the definitive version.' + sLineBreak +
    'Any commits on the remote that are not in your local will be LOST.' + sLineBreak + sLineBreak +
    'This operation affects ' + IntToStr( iCount ) + ' repository(ies).' + sLineBreak + sLineBreak +
    'Are you ABSOLUTELY sure you want to continue?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  // Second confirmation for safety
  if MessageDlg(
    'FINAL CONFIRMATION' + sLineBreak + sLineBreak +
    'You are about to force push ' + IntToStr( iCount ) + ' repository(ies).' + sLineBreak + sLineBreak +
    'Remote history will be overwritten. This cannot be undone.' + sLineBreak + sLineBreak +
    'Proceed with force push?',
    mtWarning, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;
  iSuccess := 0;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      if lvRepos.Items[ i ].Checked then
      begin
        iRepoIndex := Integer( lvRepos.Items[ i ].Data );

        Log( Format( '=== Force Pushing %s ===', [ FRepoManager.Repos[ iRepoIndex ].Name ] ) );

        var bPushSuccess := FRepoManager.ForcePushRepository( iRepoIndex, sLog );

        Log( sLog );

        if bPushSuccess then
        begin
          Inc( iSuccess );
          // Trigger reindex after successful force push
          TriggerDelphiLookupReindex( FRepoManager.Repos[ iRepoIndex ].Path );
        end;

        FRepoManager.RefreshStatus( iRepoIndex );
        UpdateListItem( iRepoIndex );
        Application.ProcessMessages;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  Log( Format( 'Force push completed: %d of %d successful.', [ iSuccess, iCount ] ) );
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
  iRemainingTimeout : Integer;
begin

  Result := False;
  AOutput := '';

  SecurityAttr.nLength := SizeOf( TSecurityAttributes );
  SecurityAttr.bInheritHandle := True;
  SecurityAttr.lpSecurityDescriptor := nil;

  if not CreatePipe( hReadPipe, hWritePipe, @SecurityAttr, 0 ) then
    Exit;

  try
    ZeroMemory( @StartupInfo, SizeOf( TStartupInfo ) );
    StartupInfo.cb := SizeOf( TStartupInfo );
    StartupInfo.hStdOutput := hWritePipe;
    StartupInfo.hStdError := hWritePipe;
    StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow := SW_HIDE;

    ZeroMemory( @ProcessInfo, SizeOf( TProcessInformation ) );

    lSuccess := CreateProcess(
      nil,
      PChar( ACommand ),
      nil,
      nil,
      True,
      CREATE_NO_WINDOW,
      nil,
      nil,
      StartupInfo,
      ProcessInfo
      );

    if lSuccess then
    begin
      CloseHandle( hWritePipe );
      hWritePipe := 0;

      SetLength( Buffer, 4096 );
      iRemainingTimeout := ATimeout;

      // Read output while process is running
      repeat
        dwWaitResult := WaitForSingleObject( ProcessInfo.hProcess, 100 );

        // Check for available data
        while PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
        begin
          if ReadFile( hReadPipe, Buffer[ 0 ], Length( Buffer ), dwBytesRead, nil ) and ( dwBytesRead > 0 ) then
            AOutput := AOutput + TEncoding.UTF8.GetString( Buffer, 0, dwBytesRead );
        end;

        // Check for timeout
        if dwWaitResult = WAIT_TIMEOUT then
        begin
          Dec( iRemainingTimeout, 100 );

          if iRemainingTimeout <= 0 then
          begin
            TerminateProcess( ProcessInfo.hProcess, 1 );
            AOutput := AOutput + sLineBreak + 'Operation timed out';
            Break;
          end;
        end;
      until dwWaitResult = WAIT_OBJECT_0;

      // Read any remaining output
      while PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
      begin
        if ReadFile( hReadPipe, Buffer[ 0 ], Length( Buffer ), dwBytesRead, nil ) and ( dwBytesRead > 0 ) then
          AOutput := AOutput + TEncoding.UTF8.GetString( Buffer, 0, dwBytesRead );
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

/// <summary>
///   Triggers delphi-lookup reindex for a specific repository path.
/// </summary>
/// <param name="ARepoPath">
///   Full path to the repository that was committed.
/// </param>
/// <remarks>
///   Captures output and logs success/failure with details.
///   Only reindexes if the path matches one of the indexed directories.
///   Incremental indexing is fast (~100ms when nothing changed).
/// </remarks>
procedure TMainForm.TriggerDelphiLookupReindex( const ARepoPath: string );
const
  DELPHI_INDEXER_EXE = 'delphi-indexer.exe';
  DEFAULT_INSTALL_PATH = 'D:\delphi-lookup\delphi-indexer.exe';

  // User-owned directories indexed by delphi-lookup
  INDEXED_DIRS_USER: array[ 0..6 ] of string = (
    'E:\DBiWorkflow Development',
    'D:\GITLAKLib',
    'D:\Delphi Tools\nlhTable',
    'D:\Delphi Tools\EDBImage',
    'D:\Delphi Tools\nlhImage',
    'D:\Delphi Tools\utilcomps',
    'D:\Rapid.Generics.v3'
  );
  // Standard library directories indexed by delphi-lookup
  INDEXED_DIRS_STDLIB: array[ 0..0 ] of string = (
    'D:\ElevateDB 2 VCL-CS-SRC\RAD Studio 13 (Delphi Win32)\code\source'
  );
var
  sIndexedDir       : string;
  sNormalizedRepo   : string;
  sParams           : string;
  sIndexerPath      : string;
  sOutput           : string;
  Buffer            : array[ 0..MAX_PATH ] of Char;
  FilePart          : PChar;
begin

  // Find delphi-indexer.exe location
  sIndexerPath := '';

  // 1. Check user-configured path first (verify it still exists)
  if not FRepoManager.DelphiIndexerPath.IsEmpty then
  begin
    if FileExists( FRepoManager.DelphiIndexerPath ) then
      sIndexerPath := FRepoManager.DelphiIndexerPath
    else
    begin
      // Configured path no longer valid - clear it and try auto-detection
      FRepoManager.DelphiIndexerPath := '';
      FRepoManager.SaveConfig;
    end;
  end;

  // 2. If not found yet, check PATH environment variable
  FilePart := nil;
  if sIndexerPath.IsEmpty and ( SearchPath( nil, PChar( DELPHI_INDEXER_EXE ), nil, MAX_PATH, Buffer, FilePart ) <> 0 ) then
  begin
    sIndexerPath := Buffer;
    // Save auto-detected path to config for faster future lookups
    FRepoManager.DelphiIndexerPath := sIndexerPath;
    FRepoManager.SaveConfig;
  end;

  // 3. If not found yet, check default installation location
  if sIndexerPath.IsEmpty and FileExists( DEFAULT_INSTALL_PATH ) then
  begin
    sIndexerPath := DEFAULT_INSTALL_PATH;
    // Save auto-detected path to config for faster future lookups
    FRepoManager.DelphiIndexerPath := sIndexerPath;
    FRepoManager.SaveConfig;
  end;

  // 4. Not found - skip reindexing
  if sIndexerPath.IsEmpty then
    Exit;

  // Normalize the repository path (remove trailing backslash, uppercase for comparison)
  sNormalizedRepo := ExcludeTrailingPathDelimiter( ARepoPath ).ToUpper;

  // Check user directories (exact match or subdirectory)
  for var i := Low( INDEXED_DIRS_USER ) to High( INDEXED_DIRS_USER ) do
  begin
    sIndexedDir := ExcludeTrailingPathDelimiter( INDEXED_DIRS_USER[ i ] ).ToUpper;

    // Match if: exact match OR repo is subdirectory of indexed dir
    if ( sNormalizedRepo = sIndexedDir ) or
       ( sNormalizedRepo.StartsWith( sIndexedDir + '\' ) ) then
    begin
      // Found a match - trigger incremental reindex for parent indexed directory
      Log( Format( 'Triggering delphi-lookup reindex: %s', [ INDEXED_DIRS_USER[ i ] ] ) );
      sParams := Format( '"%s" "%s" --category user', [ sIndexerPath, INDEXED_DIRS_USER[ i ] ] );

      if ExecuteCommand( sParams, sOutput ) then
        Log( 'delphi-lookup reindex completed successfully' )
      else
      begin
        Log( 'delphi-lookup reindex FAILED' );
        if not sOutput.Trim.IsEmpty then
          Log( 'Error: ' + sOutput.Trim );
      end;

      Exit;
    end;
  end;

  // Check stdlib directories (exact match or subdirectory)
  for var i := Low( INDEXED_DIRS_STDLIB ) to High( INDEXED_DIRS_STDLIB ) do
  begin
    sIndexedDir := ExcludeTrailingPathDelimiter( INDEXED_DIRS_STDLIB[ i ] ).ToUpper;

    // Match if: exact match OR repo is subdirectory of indexed dir
    if ( sNormalizedRepo = sIndexedDir ) or
       ( sNormalizedRepo.StartsWith( sIndexedDir + '\' ) ) then
    begin
      // Found a match - trigger incremental reindex for parent indexed directory
      Log( Format( 'Triggering delphi-lookup reindex: %s', [ INDEXED_DIRS_STDLIB[ i ] ] ) );
      sParams := Format( '"%s" "%s" --category stdlib', [ sIndexerPath, INDEXED_DIRS_STDLIB[ i ] ] );

      if ExecuteCommand( sParams, sOutput ) then
        Log( 'delphi-lookup reindex completed successfully' )
      else
      begin
        Log( 'delphi-lookup reindex FAILED' );
        if not sOutput.Trim.IsEmpty then
          Log( 'Error: ' + sOutput.Trim );
      end;

      Exit;
    end;
  end;

  // Repository not in indexed list - skip reindexing

end;

procedure TMainForm.mmoLogKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );
begin
  // Handle Ctrl+A to select all text in the log memo
  if ( ssCtrl in Shift ) and ( Key = Ord( 'A' ) ) then
  begin
    mmoLog.SelectAll;
    Key := 0;
  end;
end;

end.

