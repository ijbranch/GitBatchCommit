(*
  uGitRepoManager.pas - Git Repository Manager Class

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal and commercial use

  Author:  GITLAK Software
  Version: 1.1.0

  Part of GitBatchCommit Application

  Description:
    Provides the TGitRepoManager class for managing multiple Git repositories,
    including status detection, configuration persistence, and batch
    commit/push operations.
*)

unit uGitRepoManager;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Generics.Collections,
  Winapi.Windows;

const
  /// <summary>
  ///   Default timeout for Git operations in milliseconds (60 seconds).
  /// </summary>
  GIT_COMMAND_TIMEOUT = 60000;

type
  /// <summary>
  ///   Represents the status of a Git repository.
  /// </summary>
  TRepoStatus = ( rsClean, rsModified, rsPullRequired, rsError, rsUnknown );

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
  end;

  TRepoInfoArray = TArray<TRepoInfo>;

  /// <summary>
  ///   Manages multiple Git repositories for batch operations.
  /// </summary>
  /// <remarks>
  ///   Handles repository configuration persistence, status detection,
  ///   and commit/push operations via Git command-line interface.
  /// </remarks>
  TGitRepoManager = class
  private
    FRepos: TRepoInfoArray;
    FConfigPath: string;

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
    ///   Determines the status of a repository.
    /// </summary>
    function GetRepoStatus( const sRepoPath: string ): TRepoStatus;

    /// <summary>
    ///   Gets the current branch name for a repository.
    /// </summary>
    function GetRepoBranch( const sRepoPath: string ): string;

    /// <summary>
    ///   Checks if a repository needs to pull from remote.
    /// </summary>
    function NeedsPull( const sRepoPath: string ): Boolean;

    /// <summary>
    ///   Returns the path to the configuration file.
    /// </summary>
    function GetConfigFilePath: string;

    /// <summary>
    ///   Escapes a string for safe use in Git commit messages via temp file.
    /// </summary>
    /// <param name="sMessage">The commit message to use.</param>
    /// <param name="sTempFile">Returns the path to the temp file created.</param>
    /// <returns>True if temp file was created successfully.</returns>
    function CreateCommitMessageFile( const sMessage: string; out sTempFile: string ): Boolean;
  public
    constructor Create;
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
    /// <param name="iIndex">Index of the repository to remove.</param>
    procedure RemoveRepository( const iIndex: Integer );

    /// <summary>
    ///   Refreshes the status of all repositories.
    /// </summary>
    procedure RefreshAllStatus;

    /// <summary>
    ///   Refreshes the status of a single repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository to refresh.</param>
    procedure RefreshStatus( const iIndex: Integer );

    /// <summary>
    ///   Commits and pushes changes for a repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="sMessage">Commit message.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if the operation succeeded.</returns>
    function CommitAndPush( const iIndex: Integer; const sMessage: string; out sLog: string ): Boolean;

    property Repos: TRepoInfoArray read FRepos;
    property ConfigPath: string read FConfigPath;
  end;

/// <summary>
///   Converts a repository status to a human-readable string.
/// </summary>
function RepoStatusToString( const Status: TRepoStatus ): string;

implementation

function RepoStatusToString( const Status: TRepoStatus ): string;
begin

  case Status of
    rsClean:        Result := 'Clean';
    rsModified:     Result := 'Modified';
    rsPullRequired: Result := 'Pull Required';
    rsError:        Result := 'Error';
  else
    Result := 'Unknown';
  end;

end;

{ TGitRepoManager }

constructor TGitRepoManager.Create;
begin

  inherited Create;
  FConfigPath := GetConfigFilePath;
  SetLength( FRepos, 0 );

end;

destructor TGitRepoManager.Destroy;
begin

  SetLength( FRepos, 0 );
  inherited;

end;

function TGitRepoManager.GetConfigFilePath: string;
var
  sDir: string;
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
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  SecurityAttr: TSecurityAttributes;
  hReadPipe, hWritePipe: THandle;
  Buffer: TBytes;
  dwBytesRead: DWORD;
  dwBytesAvail: DWORD;
  lSuccess: Boolean;
  dwWaitResult: DWORD;
  dwExitCode: DWORD;
  sFullCommand: string;
  iRemainingTimeout: Integer;
begin

  Result  := False;
  sOutput := '';

  SecurityAttr.nLength              := SizeOf( TSecurityAttributes );
  SecurityAttr.bInheritHandle       := True;
  SecurityAttr.lpSecurityDescriptor := nil;

  if ( not CreatePipe( hReadPipe, hWritePipe, @SecurityAttr, 0 ) ) then
    Exit;

  try
    ZeroMemory( @StartupInfo, SizeOf( TStartupInfo ) );
    StartupInfo.cb          := SizeOf( TStartupInfo );
    StartupInfo.hStdOutput  := hWritePipe;
    StartupInfo.hStdError   := hWritePipe;
    StartupInfo.dwFlags     := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow := SW_HIDE;

    ZeroMemory( @ProcessInfo, SizeOf( TProcessInformation ) );

    sFullCommand := Format( 'cmd.exe /c cd /d "%s" && git %s', [ sRepoPath, sCommand ] );

    lSuccess := CreateProcess(
      nil,
      PChar( sFullCommand ),
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
      iRemainingTimeout := iTimeout;

      // Read output while process is running
      repeat
        dwWaitResult := WaitForSingleObject( ProcessInfo.hProcess, 100 );

        // Check for available data
        while PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
        begin
          if ReadFile( hReadPipe, Buffer[ 0 ], Length( Buffer ), dwBytesRead, nil ) and ( dwBytesRead > 0 ) then
            sOutput := sOutput + TEncoding.UTF8.GetString( Buffer, 0, dwBytesRead );
        end;

        // Check for timeout
        if dwWaitResult = WAIT_TIMEOUT then
        begin
          Dec( iRemainingTimeout, 100 );

          if iRemainingTimeout <= 0 then
          begin
            TerminateProcess( ProcessInfo.hProcess, 1 );
            sOutput := sOutput + sLineBreak + 'Operation timed out';
            Break;
          end;
        end;
      until dwWaitResult = WAIT_OBJECT_0;

      // Read any remaining output
      while PeekNamedPipe( hReadPipe, nil, 0, nil, @dwBytesAvail, nil ) and ( dwBytesAvail > 0 ) do
      begin
        if ReadFile( hReadPipe, Buffer[ 0 ], Length( Buffer ), dwBytesRead, nil ) and ( dwBytesRead > 0 ) then
          sOutput := sOutput + TEncoding.UTF8.GetString( Buffer, 0, dwBytesRead );
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

function TGitRepoManager.CreateCommitMessageFile( const sMessage: string; out sTempFile: string ): Boolean;
begin

  Result := False;

  try
    sTempFile := TPath.Combine( TPath.GetTempPath, Format( 'gitcommit_%d.txt', [ GetTickCount ] ) );
    TFile.WriteAllText( sTempFile, sMessage, TEncoding.UTF8 );
    Result := True;
  except
    on E: Exception do
      sTempFile := '';
  end;

end;

function TGitRepoManager.GetRepoBranch( const sRepoPath: string ): string;
var
  sOutput: string;
begin

  Result := '';

  if ExecuteGitCommand( sRepoPath, 'branch --show-current', sOutput ) then
    Result := Trim( sOutput );

  if Result.IsEmpty then
    Result := '(unknown)';

end;

function TGitRepoManager.NeedsPull( const sRepoPath: string ): Boolean;
var
  sOutput: string;
begin

  Result := False;

  // Fetch latest from remote (without merging)
  ExecuteGitCommand( sRepoPath, 'fetch', sOutput );

  // Check if we're behind the remote
  if ExecuteGitCommand( sRepoPath, 'status -uno', sOutput ) then
    Result := sOutput.Contains( 'Your branch is behind' );

end;

function TGitRepoManager.GetRepoStatus( const sRepoPath: string ): TRepoStatus;
var
  sOutput: string;
begin

  if ( not TDirectory.Exists( TPath.Combine( sRepoPath, '.git' ) ) ) then
  begin
    Result := rsError;
    Exit;
  end;

  // Check for local modifications first
  if ExecuteGitCommand( sRepoPath, 'status --porcelain', sOutput ) then
  begin
    if Trim( sOutput ).IsEmpty then
    begin
      // No local changes - check if we need to pull
      if NeedsPull( sRepoPath ) then
        Result := rsPullRequired
      else
        Result := rsClean;
    end
    else
      Result := rsModified;
  end
  else
    Result := rsError;

end;

function TGitRepoManager.LoadConfig: Boolean;
var
  sJSON: string;
  JSONValue: TJSONValue;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  lSelected: Boolean;
begin

  Result := False;
  SetLength( FRepos, 0 );

  if ( not TFile.Exists( FConfigPath ) ) then
  begin
    Result := True; // No config file is not an error
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
    if ( not ( JSONValue is TJSONArray ) ) then
      Exit;

    JSONArray := JSONValue as TJSONArray;
    SetLength( FRepos, JSONArray.Count );

    for var i := 0 to JSONArray.Count - 1 do
    begin
      if ( not ( JSONArray.Items[ i ] is TJSONObject ) ) then
      begin
        // Skip invalid items but continue processing
        FRepos[ i ].Path   := '';
        FRepos[ i ].Status := rsError;
        Continue;
      end;

      JSONObj := JSONArray.Items[ i ] as TJSONObject;

      FRepos[ i ].Path := JSONObj.GetValue<string>( 'path', '' );
      FRepos[ i ].Name := ExtractFileName( ExcludeTrailingPathDelimiter( FRepos[ i ].Path ) );

      // Load persisted selection state
      lSelected := JSONObj.GetValue<Boolean>( 'selected', False );

      FRepos[ i ].Branch     := '';
      FRepos[ i ].Status     := rsUnknown;
      FRepos[ i ].StatusText := '';
      FRepos[ i ].Selected   := lSelected;
    end;

    Result := True;
  finally
    JSONValue.Free;
  end;

end;

function TGitRepoManager.SaveConfig: Boolean;
var
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
begin

  Result    := False;
  JSONArray := TJSONArray.Create;

  try
    for var i := 0 to High( FRepos ) do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair( 'path', FRepos[ i ].Path );
      JSONObj.AddPair( 'selected', TJSONBool.Create( FRepos[ i ].Selected ) );
      JSONArray.AddElement( JSONObj );
    end;

    try
      TFile.WriteAllText( FConfigPath, JSONArray.Format, TEncoding.UTF8 );
      Result := True;
    except
      on E: Exception do
        ; // Silently fail, Result remains False
    end;
  finally
    JSONArray.Free;
  end;

end;

procedure TGitRepoManager.AddRepository( const sPath: string );
var
  iLen: Integer;
begin

  // Check if already exists
  for var i := 0 to High( FRepos ) do
  begin
    if SameText( FRepos[ i ].Path, sPath ) then
      Exit;
  end;

  iLen := Length( FRepos );
  SetLength( FRepos, iLen + 1 );

  FRepos[ iLen ].Path       := sPath;
  FRepos[ iLen ].Name       := ExtractFileName( ExcludeTrailingPathDelimiter( sPath ) );
  FRepos[ iLen ].Branch     := '';
  FRepos[ iLen ].Status     := rsUnknown;
  FRepos[ iLen ].StatusText := '';
  FRepos[ iLen ].Selected   := False;

  RefreshStatus( iLen );
  SaveConfig;

end;

procedure TGitRepoManager.RemoveRepository( const iIndex: Integer );
begin

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
    Exit;

  for var i := iIndex to High( FRepos ) - 1 do
    FRepos[ i ] := FRepos[ i + 1 ];

  SetLength( FRepos, Length( FRepos ) - 1 );
  SaveConfig;

end;

procedure TGitRepoManager.RefreshStatus( const iIndex: Integer );
begin

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
    Exit;

  FRepos[ iIndex ].Branch     := GetRepoBranch( FRepos[ iIndex ].Path );
  FRepos[ iIndex ].Status     := GetRepoStatus( FRepos[ iIndex ].Path );
  FRepos[ iIndex ].StatusText := RepoStatusToString( FRepos[ iIndex ].Status );

end;

procedure TGitRepoManager.RefreshAllStatus;
begin

  for var i := 0 to High( FRepos ) do
    RefreshStatus( i );

end;

function TGitRepoManager.CommitAndPush( const iIndex: Integer; const sMessage: string; out sLog: string ): Boolean;
var
  sOutput: string;
  sTempFile: string;
begin

  Result := False;
  sLog   := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sLog := 'Invalid repository index';
    Exit;
  end;

  sLog := Format( '=== %s ===%s', [ FRepos[ iIndex ].Name, sLineBreak ] );

  // Stage all changes
  if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'add -A', sOutput ) ) then
  begin
    sLog := sLog + 'Failed to stage changes: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Staged changes' + sLineBreak;

  // Create temp file for commit message (avoids command injection)
  if ( not CreateCommitMessageFile( sMessage, sTempFile ) ) then
  begin
    sLog := sLog + 'Failed to create commit message file' + sLineBreak;
    Exit;
  end;

  try
    // Commit using file-based message
    if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput ) ) then
    begin
      sLog := sLog + 'Commit failed: ' + Trim( sOutput ) + sLineBreak;
      Exit;
    end;

    sLog := sLog + 'Committed: ' + Trim( sOutput ) + sLineBreak;
  finally
    // Clean up temp file
    if TFile.Exists( sTempFile ) then
    begin
      try
        TFile.Delete( sTempFile );
      except
        ; // Ignore cleanup errors
      end;
    end;
  end;

  // Push
  if ( not ExecuteGitCommand( FRepos[ iIndex ].Path, 'push', sOutput ) ) then
  begin
    sLog := sLog + 'Push failed: ' + Trim( sOutput ) + sLineBreak;
    Exit;
  end;

  sLog := sLog + 'Pushed successfully' + sLineBreak;

  Result := True;
  RefreshStatus( iIndex );

end;

end.
