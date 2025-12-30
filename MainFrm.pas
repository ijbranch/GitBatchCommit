(*
  MainFrm.pas - Main Form Unit

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal and commercial use

  Author:  GITLAK Software
  Version: 1.3.0

  Part of GitBatchCommit Application

  Description:
    Main form providing the user interface for managing multiple Git
    repositories and performing batch commit and push operations.
*)

unit MainFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.CommCtrl,
  System.SysUtils, System.Variants, System.Classes, System.UITypes, System.Generics.Collections,
  System.Generics.Defaults,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.FileCtrl,

  uGitRepoManager;

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
    btnAddRepo: TButton;
    btnRemoveRepo: TButton;
    btnRefresh: TButton;
    lblCommitMessage: TLabel;
    edtCommitMessage: TEdit;
    btnCommitPush: TButton;
    mmoLog: TMemo;
    splitter: TSplitter;
    btnSelectModified: TButton;
    btnSelectAll: TButton;
    btnSelectNone: TButton;
    pnlButtons: TPanel;
    procedure FormCreate( Sender: TObject );
    procedure FormDestroy( Sender: TObject );
    procedure btnAddRepoClick( Sender: TObject );
    procedure btnRemoveRepoClick( Sender: TObject );
    procedure btnRefreshClick( Sender: TObject );
    procedure btnCommitPushClick( Sender: TObject );
    procedure btnSelectModifiedClick( Sender: TObject );
    procedure btnSelectAllClick( Sender: TObject );
    procedure btnSelectNoneClick( Sender: TObject );
    procedure lvReposItemChecked( Sender: TObject; Item: TListItem );
  private
    FRepoManager: TGitRepoManager;
    FUpdatingList: Boolean;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    FFilteredIndices: TList<Integer>;
    FStatusFilter: Integer;
    FcboFilter: TComboBox;
    FlblFilter: TLabel;

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
    ///   Handles filter combo box change.
    /// </summary>
    procedure cboFilterChange( Sender: TObject );

    /// <summary>
    ///   Applies current filter and sort to the list.
    /// </summary>
    procedure ApplyFilterAndSort;

    /// <summary>
    ///   Creates runtime UI controls for filtering.
    /// </summary>
    procedure CreateFilterControls;

    /// <summary>
    ///   Sets the sort indicator arrow on column header.
    /// </summary>
    procedure SetColumnSortArrow( const iColumn: Integer; const bAscending: Boolean );
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

/// <summary>
///   Initialises the form, loads configuration, and refreshes repository status.
/// </summary>
procedure TMainForm.FormCreate( Sender: TObject );
begin

  FUpdatingList    := False;
  FSortColumn      := -1;
  FSortAscending   := True;
  FStatusFilter    := 0;
  FFilteredIndices := TList<Integer>.Create;
  FRepoManager     := TGitRepoManager.Create;

  // Create filter controls
  CreateFilterControls;

  // Enable drag-and-drop support
  DragAcceptFiles( Handle, True );

  // Wire up column click event
  lvRepos.OnColumnClick := lvReposColumnClick;

  if ( not FRepoManager.LoadConfig ) then
    mmoLog.Lines.Add( 'Warning: Failed to load configuration file' );

  mmoLog.Lines.Add( 'Config file: ' + FRepoManager.ConfigPath );
  mmoLog.Lines.Add( Format( 'Loaded %d repositories', [ Length( FRepoManager.Repos ) ] ) );
  mmoLog.Lines.Add( 'Refreshing status...' );
  ScrollLogToEnd;
  Application.ProcessMessages;

  FRepoManager.RefreshAllStatus;
  PopulateListView;

  mmoLog.Lines.Add( 'Ready. Drag and drop repository folders to add them.' );
  mmoLog.Lines.Add( 'Click column headers to sort. Use filter dropdown to filter by status.' );
  ScrollLogToEnd;

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
///   Creates runtime UI controls for filtering.
/// </summary>
procedure TMainForm.CreateFilterControls;
begin

  FlblFilter         := TLabel.Create( Self );
  FlblFilter.Parent  := pnlTop;
  FlblFilter.Left    := pnlTop.Width - 220;
  FlblFilter.Top     := 12;
  FlblFilter.Caption := 'Filter:';
  FlblFilter.Anchors := [ akTop, akRight ];

  FcboFilter             := TComboBox.Create( Self );
  FcboFilter.Parent      := pnlTop;
  FcboFilter.Style       := csDropDownList;
  FcboFilter.Left        := pnlTop.Width - 180;
  FcboFilter.Top         := 8;
  FcboFilter.Width       := 170;
  FcboFilter.Anchors     := [ akTop, akRight ];
  FcboFilter.Items.Add( 'All' );
  FcboFilter.Items.Add( 'Clean' );
  FcboFilter.Items.Add( 'Modified' );
  FcboFilter.Items.Add( 'Pull Required' );
  FcboFilter.Items.Add( 'Error' );
  FcboFilter.ItemIndex   := 0;
  FcboFilter.OnChange    := cboFilterChange;

end;

/// <summary>
///   Handles filter combo box change.
/// </summary>
procedure TMainForm.cboFilterChange( Sender: TObject );
begin

  FStatusFilter := FcboFilter.ItemIndex;
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
    FSortColumn    := Column.Index;
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
  Header: HWND;
  Item: THDItem;
begin

  Header := ListView_GetHeader( lvRepos.Handle );

  // Clear all arrows first
  for var i := 0 to lvRepos.Columns.Count - 1 do
  begin
    ZeroMemory( @Item, SizeOf( Item ) );
    Item.Mask := HDI_FORMAT;
    Header_GetItem( Header, i, Item );
    Item.fmt  := Item.fmt and not ( HDF_SORTDOWN or HDF_SORTUP );
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
  FilterStatus: TRepoStatus;
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
      end
    ) );
  end;

end;

/// <summary>
///   Scrolls the log memo to the end.
/// </summary>
procedure TMainForm.ScrollLogToEnd;
begin

  mmoLog.SelStart  := Length( mmoLog.Text );
  mmoLog.SelLength := 0;
  mmoLog.Perform( EM_SCROLLCARET, 0, 0 );

end;

/// <summary>
///   Handles WM_DROPFILES message for drag-and-drop support.
/// </summary>
procedure TMainForm.WMDropFiles( var Msg: TWMDropFiles );
var
  iFileCount: Integer;
  iAdded: Integer;
  iSkipped: Integer;
  Buffer: array[ 0..MAX_PATH ] of Char;
  sPath: string;
begin

  iAdded   := 0;
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
  iRepoIndex: Integer;
begin

  FUpdatingList := True;

  try
    ApplyFilterAndSort;

    lvRepos.Items.BeginUpdate;

    try
      lvRepos.Items.Clear;

      for var i := 0 to FFilteredIndices.Count - 1 do
      begin
        iRepoIndex      := FFilteredIndices[ i ];
        var Item        := lvRepos.Items.Add;
        Item.Caption    := FRepoManager.Repos[ iRepoIndex ].Name;
        Item.SubItems.Add( FRepoManager.Repos[ iRepoIndex ].Path );
        Item.SubItems.Add( FRepoManager.Repos[ iRepoIndex ].Branch );
        Item.SubItems.Add( FRepoManager.Repos[ iRepoIndex ].StatusText );
        Item.Checked    := FRepoManager.Repos[ iRepoIndex ].Selected;
        Item.Data       := Pointer( iRepoIndex );
      end;
    finally
      lvRepos.Items.EndUpdate;
    end;
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
        var Item           := lvRepos.Items[ i ];
        Item.Caption       := FRepoManager.Repos[ iIndex ].Name;
        Item.SubItems[ 0 ] := FRepoManager.Repos[ iIndex ].Path;
        Item.SubItems[ 1 ] := FRepoManager.Repos[ iIndex ].Branch;
        Item.SubItems[ 2 ] := FRepoManager.Repos[ iIndex ].StatusText;
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
///   Handles the Add Repository button click.
/// </summary>
procedure TMainForm.btnAddRepoClick( Sender: TObject );
var
  sFolder: string;
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
///   Handles the Remove Selected button click.
/// </summary>
procedure TMainForm.btnRemoveRepoClick( Sender: TObject );
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
///   Handles the Refresh Status button click.
/// </summary>
procedure TMainForm.btnRefreshClick( Sender: TObject );
begin

  Screen.Cursor := crHourGlass;

  try
    Log( 'Refreshing all repositories...' );
    FRepoManager.RefreshAllStatus;
    PopulateListView;
    Log( 'Refresh complete.' );
  finally
    Screen.Cursor := crDefault;
  end;

end;

/// <summary>
///   Handles the Commit and Push Selected button click.
/// </summary>
procedure TMainForm.btnCommitPushClick( Sender: TObject );
var
  sLog: string;
  iRepoIndex: Integer;
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
  iRepoIndex: Integer;
begin

  FUpdatingList := True;

  try
    for var i := 0 to lvRepos.Items.Count - 1 do
    begin
      iRepoIndex                 := Integer( lvRepos.Items[ i ].Data );
      lvRepos.Items[ i ].Checked := ( FRepoManager.Repos[ iRepoIndex ].Status = rsModified );
    end;
  finally
    FUpdatingList := False;
  end;

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

end;

/// <summary>
///   Handles checkbox state changes in the repository list.
/// </summary>
procedure TMainForm.lvReposItemChecked( Sender: TObject; Item: TListItem );
var
  iIndex: Integer;
begin

  if FUpdatingList then
    Exit;

  iIndex := Integer( Item.Data );

  if ( iIndex >= 0 ) and ( iIndex <= High( FRepoManager.Repos ) ) then
    FRepoManager.Repos[ iIndex ].Selected := Item.Checked;

end;

end.
