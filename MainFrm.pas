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
  File last update : 2025-12-31T09:31:51.605+11:00
  Signature : db94f33c5301b8d51b5498c9c0371cd161af833a
  ***************************************************************************
*)

(*
  MainFrm.pas - Main Form Unit

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.1.0

  Part of GitBatchCommit Application

  Description:
    Main form providing the user interface for managing multiple Git
    repositories and performing batch commit and push operations,
    including Codeberg repository creation.
*)

unit MainFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.CommCtrl,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.FileCtrl, Vcl.Menus,
  System.SysUtils, System.StrUtils, System.Variants, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Generics.Defaults, System.Threading,
  uGitRepoManager, uCodebergDialog, uCodebergSettings, uGitHubSettings;

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
    pmSep2: TMenuItem;
    pmOpenInExplorer: TMenuItem;
    pmOpenInGitClient: TMenuItem;
    pmSep3: TMenuItem;
    pmPull: TMenuItem;
    pmHistory: TPopupMenu;
    btnHistory: TButton;
    mnuSettings: TMenuItem;
    mnuFileSep3: TMenuItem;
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
  FSortColumn := -1;
  FSortAscending := True;
  FStatusFilter := 0;
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

    // Use the state of the current item as the target state
    lNewState := lvRepos.Items[ iCurrentIndex ].Checked;

    FUpdatingList := True;

    try
      for var i := iStartIndex to iEndIndex do
        lvRepos.Items[ i ].Checked := lNewState;
    finally
      FUpdatingList := False;
    end;

    UpdateCommitButtonState;
  end;

  // Always update last clicked index
  FLastClickedIndex := iCurrentIndex;

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
    Log( 'Added repository: ' + sFolder );
  end;

end;

/// <summary>
///   Handles the File > Remove Selected menu click.
/// </summary>
procedure TMainForm.mnuRemoveSelectedClick( Sender: TObject );
begin

  if lvRepos.Selected = nil then
  begin
    MessageDlg( 'Please select a repository to remove.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  var iIndex := Integer( lvRepos.Selected.Data );

  if MessageDlg( Format( 'Remove repository "%s" from the list?', [ FRepoManager.Repos[ iIndex ].Name ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) = mrYes then
  begin
    Log( 'Removed repository: ' + FRepoManager.Repos[ iIndex ].Name );
    FRepoManager.RemoveRepository( iIndex );
    PopulateListView;
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
begin

  var sMessage := Trim( edtCommitMessage.Text );

  if sMessage.IsEmpty then
  begin
    MessageDlg( 'Please enter a commit message.', mtWarning, [ mbOK ], 0 );
    edtCommitMessage.SetFocus;
    Exit;
  end;

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
        if FRepoManager.CommitAndPush( iRepoIndex, sMessage, sLog ) then
          Inc( iSuccess );

        Log( sLog );
        UpdateListItem( iRepoIndex );
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  Log( Format( 'Completed: %d of %d successful.', [ iSuccess, iCount ] ) );
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
begin

  // Enable .gitignore edit only when a single repository is selected
  pmEditGitignore.Enabled := ( lvRepos.Selected <> nil );

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
  APP_VERSION       = '1.1.0';
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
begin

  if lvRepos.Selected = nil then
    Exit;

  iIndex := Integer( lvRepos.Selected.Data );

  if MessageDlg( Format( 'Pull changes for "%s"?', [ FRepoManager.Repos[ iIndex ].Name ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;

  try
    Log( 'Pulling ' + FRepoManager.Repos[ iIndex ].Name + '...' );

    if FRepoManager.PullRepository( iIndex, sLog ) then
    begin
      Log( sLog );
      Log( 'Pull complete.' );
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
begin

  sClientPath := FRepoManager.GitClientPath;
  sFilePattern := FRepoManager.FilePattern;

  // Use separate InputQuery calls since the multi-value version has issues
  if InputQuery( 'Settings', 'Git Client Path (e.g., C:\Program Files\Fork\Fork.exe):', sClientPath ) then
  begin
    if InputQuery( 'Settings', 'File Pattern (e.g., *.pas or empty for all):', sFilePattern ) then
    begin
      FRepoManager.GitClientPath := sClientPath;
      FRepoManager.FilePattern := sFilePattern;
      FRepoManager.SaveConfig;
      Log( 'Settings updated.' );
    end;
  end;

end;

end.

