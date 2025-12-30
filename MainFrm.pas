(*
  MainFrm.pas - Main Form Unit

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal and commercial use

  Author:  GITLAK Software
  Version: 1.5.0

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
  System.SysUtils, System.StrUtils, System.Variants, System.Classes, System.UITypes, System.Generics.Collections,
  System.Generics.Defaults,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.FileCtrl,
  Vcl.Menus,

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
    pmRepos: TPopupMenu;
    pmSetPublic: TMenuItem;
    pmSetPrivate: TMenuItem;
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
  private
    const
      WM_LOAD_REPOS = WM_USER + 100;
    var
      FRepoManager: TGitRepoManager;
      FUpdatingList: Boolean;
      FSortColumn: Integer;
      FSortAscending: Boolean;
      FFilteredIndices: TList<Integer>;
      FStatusFilter: Integer;
      FInitialLoadDone: Boolean;

    /// <summary>
    ///   Handles custom message to load repositories after form is visible.
    /// </summary>
    procedure WMLoadRepos( var Msg: TMessage ); message WM_USER + 100;

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
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

/// <summary>
///   Initialises the form and prepares for loading.
/// </summary>
procedure TMainForm.FormCreate( Sender: TObject );
begin

  FUpdatingList    := False;
  FSortColumn      := -1;
  FSortAscending   := True;
  FStatusFilter    := 0;
  FInitialLoadDone := False;
  FFilteredIndices := TList<Integer>.Create;
  FRepoManager     := TGitRepoManager.Create;

  // Enable drag-and-drop support
  DragAcceptFiles( Handle, True );

  // Wire up column click event
  lvRepos.OnColumnClick := lvReposColumnClick;

  // Set initial filter menu state
  UpdateFilterMenuChecks;

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
  iCount: Integer;
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

    // Refresh each repository individually so user sees activity
    if iCount > 0 then
    begin
      for var i := 0 to iCount - 1 do
      begin
        mmoLog.Lines.Add( Format( 'Checking %s... (%d of %d)',
          [ FRepoManager.Repos[ i ].Name, i + 1, iCount ] ) );
        ScrollLogToEnd;
        Update;

        FRepoManager.RefreshStatus( i );
        UpdateListItem( i );
        Update;
      end;
    end;

    mmoLog.Lines.Add( '' );
    mmoLog.Lines.Add( 'Ready. Drag and drop repository folders to add them.' );
    mmoLog.Lines.Add( 'Click column headers to sort. Use View > Filter to filter by status.' );
    ScrollLogToEnd;
  finally
    Screen.Cursor := crDefault;
  end;

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

  mnuFilterAll.Checked          := ( FStatusFilter = 0 );
  mnuFilterClean.Checked        := ( FStatusFilter = 1 );
  mnuFilterModified.Checked     := ( FStatusFilter = 2 );
  mnuFilterPullRequired.Checked := ( FStatusFilter = 3 );
  mnuFilterError.Checked        := ( FStatusFilter = 4 );

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
        iValA, iValB: Integer;
      begin
        // Handle numeric columns separately
        if FSortColumn in [ 3, 4 ] then
        begin
          case FSortColumn of
            3:
            begin
              iValA := FRepoManager.Repos[ A ].TrackedFileCount;
              iValB := FRepoManager.Repos[ B ].TrackedFileCount;
            end;
            4:
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
            5:
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
        Item.SubItems.Add( IntToStr( FRepoManager.Repos[ iRepoIndex ].TrackedFileCount ) );
        Item.SubItems.Add( IntToStr( FRepoManager.Repos[ iRepoIndex ].ModifiedFileCount ) );
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
        Item.SubItems[ 2 ] := IntToStr( FRepoManager.Repos[ iIndex ].TrackedFileCount );
        Item.SubItems[ 3 ] := IntToStr( FRepoManager.Repos[ iIndex ].ModifiedFileCount );
        Item.SubItems[ 4 ] := FRepoManager.Repos[ iIndex ].StatusText;
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

/// <summary>
///   Handles the Codeberg > Settings menu click.
/// </summary>
procedure TMainForm.mnuCodebergSettingsClick( Sender: TObject );
var
  sUsername, sToken: string;
begin

  sUsername := FRepoManager.CodebergUsername;
  sToken    := FRepoManager.CodebergToken;

  if TCodebergSettingsDialog.Execute( sUsername, sToken ) then
  begin
    FRepoManager.CodebergUsername := sUsername;
    FRepoManager.CodebergToken    := sToken;
    FRepoManager.SaveConfig;
    Log( 'Codeberg credentials updated.' );
  end;

end;

/// <summary>
///   Handles the Codeberg > Initialize and Push menu click.
/// </summary>
procedure TMainForm.mnuInitPushCodebergClick( Sender: TObject );
var
  sFolder: string;
  sRepoName: string;
  sDescription: string;
  bPrivate: Boolean;
  sRemoteURL: string;
  sError: string;
  sLog: string;
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
  sRepoName    := ExtractFileName( ExcludeTrailingPathDelimiter( sFolder ) );
  sDescription := '';
  bPrivate     := False;

  if ( not TCodebergDialog.Execute( sRepoName, sDescription, bPrivate ) ) then
    Exit;

  // Confirm operation
  if MessageDlg( Format( 'This will:%s%s' +
                         '1. Initialize Git repository in: %s%s' +
                         '2. Create %s repository "%s" on Codeberg%s' +
                         '3. Commit all files and push%s%s' +
                         'Continue?',
                         [ sLineBreak, sLineBreak,
                           sFolder, sLineBreak,
                           IfThen( bPrivate, 'private', 'public' ), sRepoName, sLineBreak,
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

    if ( not FRepoManager.CreateCodebergRepository( sRepoName, sDescription, bPrivate, sRemoteURL, sError ) ) then
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
  sUsername, sToken: string;
begin

  sUsername := FRepoManager.GitHubUsername;
  sToken    := FRepoManager.GitHubToken;

  if TGitHubSettingsDialog.Execute( sUsername, sToken ) then
  begin
    FRepoManager.GitHubUsername := sUsername;
    FRepoManager.GitHubToken    := sToken;
    FRepoManager.SaveConfig;
    Log( 'GitHub credentials updated.' );
  end;

end;

/// <summary>
///   Handles the GitHub > Initialize and Push menu click.
/// </summary>
procedure TMainForm.mnuInitPushGitHubClick( Sender: TObject );
var
  sFolder: string;
  sRepoName: string;
  sDescription: string;
  bPrivate: Boolean;
  sRemoteURL: string;
  sError: string;
  sLog: string;
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
  sRepoName    := ExtractFileName( ExcludeTrailingPathDelimiter( sFolder ) );
  sDescription := '';
  bPrivate     := False;

  if ( not TCodebergDialog.Execute( sRepoName, sDescription, bPrivate ) ) then
    Exit;

  // Confirm operation
  if MessageDlg( Format( 'This will:%s%s' +
                         '1. Initialize Git repository in: %s%s' +
                         '2. Create %s repository "%s" on GitHub%s' +
                         '3. Commit all files and push%s%s' +
                         'Continue?',
                         [ sLineBreak, sLineBreak,
                           sFolder, sLineBreak,
                           IfThen( bPrivate, 'private', 'public' ), sRepoName, sLineBreak,
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

    if ( not FRepoManager.CreateGitHubRepository( sRepoName, sDescription, bPrivate, sRemoteURL, sError ) ) then
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
  iIndex: Integer;
  sError: string;
  Provider: TRemoteProvider;
  sProviderName: string;
begin

  if lvRepos.Selected = nil then
  begin
    MessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex   := Integer( lvRepos.Selected.Data );
  Provider := FRepoManager.GetRepoProvider( iIndex );

  case Provider of
    rpCodeberg: sProviderName := 'Codeberg';
    rpGitHub:   sProviderName := 'GitHub';
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
  iIndex: Integer;
  sError: string;
  Provider: TRemoteProvider;
  sProviderName: string;
begin

  if lvRepos.Selected = nil then
  begin
    MessageDlg( 'Please select a repository.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  iIndex   := Integer( lvRepos.Selected.Data );
  Provider := FRepoManager.GetRepoProvider( iIndex );

  case Provider of
    rpCodeberg: sProviderName := 'Codeberg';
    rpGitHub:   sProviderName := 'GitHub';
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

end.
