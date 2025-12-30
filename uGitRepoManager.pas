(*
  uGitRepoManager.pas - Git Repository Manager Class

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal and commercial use

  Author:  GITLAK Software
  Version: 1.2.0

  Part of GitBatchCommit Application

  Description:
    Provides the TGitRepoManager class for managing multiple Git repositories,
    including status detection, configuration persistence, batch commit/push
    operations, and Codeberg repository creation.
*)

unit uGitRepoManager;

interface

uses
  System.SysUtils, System.StrUtils, System.Classes, System.IOUtils, System.JSON, System.Generics.Collections,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient, System.NetEncoding,
  Winapi.Windows;

const
  /// <summary>
  ///   Default timeout for Git operations in milliseconds (60 seconds).
  /// </summary>
  GIT_COMMAND_TIMEOUT = 60000;

  /// <summary>
  ///   Codeberg API base URL.
  /// </summary>
  CODEBERG_API_URL = 'https://codeberg.org/api/v1';

  /// <summary>
  ///   GitHub API base URL.
  /// </summary>
  GITHUB_API_URL = 'https://api.github.com';

type
  /// <summary>
  ///   Represents the status of a Git repository.
  /// </summary>
  TRepoStatus = ( rsClean, rsModified, rsPullRequired, rsError, rsUnknown );

  /// <summary>
  ///   Represents a remote Git hosting provider.
  /// </summary>
  TRemoteProvider = ( rpNone, rpCodeberg, rpGitHub, rpOther );

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
    TrackedFileCount: Integer;
    ModifiedFileCount: Integer;
    Provider: TRemoteProvider;
  end;

  TRepoInfoArray = TArray<TRepoInfo>;

  /// <summary>
  ///   Manages multiple Git repositories for batch operations.
  /// </summary>
  /// <remarks>
  ///   Handles repository configuration persistence, status detection,
  ///   commit/push operations via Git command-line interface, and
  ///   Codeberg repository creation.
  /// </remarks>
  TGitRepoManager = class
  private
    FRepos: TRepoInfoArray;
    FConfigPath: string;
    FCodebergUsername: string;
    FCodebergToken: string;
    FGitHubUsername: string;
    FGitHubToken: string;

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
    ///   Gets the number of files tracked by Git in the repository.
    /// </summary>
    function GetTrackedFileCount( const sRepoPath: string ): Integer;

    /// <summary>
    ///   Gets the number of modified/staged/untracked files in the repository.
    /// </summary>
    function GetModifiedFileCount( const sRepoPath: string ): Integer;

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

    /// <summary>
    ///   Makes an HTTP POST request to the Codeberg API.
    /// </summary>
    function ExecuteCodebergApiPost( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP POST request to the GitHub API.
    /// </summary>
    function ExecuteGitHubApiPost( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP PATCH request to the Codeberg API.
    /// </summary>
    function ExecuteCodebergApiPatch( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Makes an HTTP PATCH request to the GitHub API.
    /// </summary>
    function ExecuteGitHubApiPatch( const sEndpoint, sBody: string; out sResponse: string;
      out iStatusCode: Integer ): Boolean;

    /// <summary>
    ///   Gets the remote origin URL for a repository.
    /// </summary>
    function GetRemoteOriginURL( const sRepoPath: string ): string;

    /// <summary>
    ///   Detects the remote provider from an origin URL.
    /// </summary>
    function DetectRemoteProvider( const sOriginURL: string ): TRemoteProvider;

    /// <summary>
    ///   Parses owner and repository name from an origin URL.
    /// </summary>
    function ParseOwnerRepo( const sOriginURL: string; out sOwner, sRepo: string ): Boolean;
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

    /// <summary>
    ///   Initializes a new Git repository in the specified folder.
    /// </summary>
    /// <param name="sPath">Path to the folder to initialize.</param>
    /// <param name="sLog">Output log of the operation.</param>
    /// <returns>True if initialization succeeded.</returns>
    function InitializeRepository( const sPath: string; out sLog: string ): Boolean;

    /// <summary>
    ///   Creates a new repository on Codeberg.
    /// </summary>
    /// <param name="sName">Repository name.</param>
    /// <param name="sDescription">Repository description.</param>
    /// <param name="bPrivate">True to create a private repository.</param>
    /// <param name="sRemoteURL">Returns the clone URL of the created repository.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if creation succeeded.</returns>
    function CreateCodebergRepository( const sName, sDescription: string; const bPrivate: Boolean;
      out sRemoteURL, sError: string ): Boolean;

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
    ///   Returns True if Codeberg credentials are configured.
    /// </summary>
    function HasCodebergCredentials: Boolean;

    /// <summary>
    ///   Creates a new repository on GitHub.
    /// </summary>
    /// <param name="sName">Repository name.</param>
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
    function HasGitHubCredentials: Boolean;

    /// <summary>
    ///   Gets the remote provider for a repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <returns>The detected remote provider.</returns>
    function GetRepoProvider( const iIndex: Integer ): TRemoteProvider;

    /// <summary>
    ///   Changes the visibility of a remote repository.
    /// </summary>
    /// <param name="iIndex">Index of the repository.</param>
    /// <param name="bPrivate">True to make private, False to make public.</param>
    /// <param name="sError">Returns error message if failed.</param>
    /// <returns>True if the operation succeeded.</returns>
    function SetRepositoryVisibility( const iIndex: Integer; const bPrivate: Boolean;
      out sError: string ): Boolean;

    property Repos: TRepoInfoArray read FRepos;
    property ConfigPath: string read FConfigPath;
    property CodebergUsername: string read FCodebergUsername write FCodebergUsername;
    property CodebergToken: string read FCodebergToken write FCodebergToken;
    property GitHubUsername: string read FGitHubUsername write FGitHubUsername;
    property GitHubToken: string read FGitHubToken write FGitHubToken;
  end;

/// <summary>
///   Converts a repository status to a human-readable string.
/// </summary>
function RepoStatusToString( const Status: TRepoStatus ): string;

/// <summary>
///   Converts a remote provider to a human-readable string.
/// </summary>
function RemoteProviderToString( const Provider: TRemoteProvider ): string;

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

function RemoteProviderToString( const Provider: TRemoteProvider ): string;
begin

  case Provider of
    rpCodeberg: Result := 'Codeberg';
    rpGitHub:   Result := 'GitHub';
    rpOther:    Result := 'Other';
  else
    Result := 'None';
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

function TGitRepoManager.GetTrackedFileCount( const sRepoPath: string ): Integer;
var
  sOutput: string;
  Lines: TArray<string>;
begin

  Result := 0;

  // Use git ls-files to get list of tracked files
  if ExecuteGitCommand( sRepoPath, 'ls-files', sOutput ) then
  begin
    sOutput := Trim( sOutput );

    if ( not sOutput.IsEmpty ) then
    begin
      Lines  := sOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );
      Result := Length( Lines );
    end;
  end;

end;

function TGitRepoManager.GetModifiedFileCount( const sRepoPath: string ): Integer;
var
  sOutput: string;
  Lines: TArray<string>;
begin

  Result := 0;

  // Use git status --porcelain to get modified/staged/untracked files
  if ExecuteGitCommand( sRepoPath, 'status --porcelain', sOutput ) then
  begin
    sOutput := Trim( sOutput );

    if ( not sOutput.IsEmpty ) then
    begin
      Lines  := sOutput.Split( [ #10, #13 ], TStringSplitOptions.ExcludeEmpty );
      Result := Length( Lines );
    end;
  end;

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
  JSONRoot: TJSONObject;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
begin

  Result := False;
  SetLength( FRepos, 0 );
  FCodebergUsername := '';
  FCodebergToken    := '';
  FGitHubUsername   := '';
  FGitHubToken      := '';

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
    // Support both old format (array) and new format (object with repos and credentials)
    if ( JSONValue is TJSONArray ) then
    begin
      JSONArray := JSONValue as TJSONArray;
    end
    else if ( JSONValue is TJSONObject ) then
    begin
      JSONRoot := JSONValue as TJSONObject;

      // Load Codeberg credentials
      FCodebergUsername := JSONRoot.GetValue<string>( 'codeberg_username', '' );
      FCodebergToken    := JSONRoot.GetValue<string>( 'codeberg_token', '' );

      // Load GitHub credentials
      FGitHubUsername := JSONRoot.GetValue<string>( 'github_username', '' );
      FGitHubToken    := JSONRoot.GetValue<string>( 'github_token', '' );

      // Get repositories array
      if JSONRoot.GetValue( 'repositories' ) is TJSONArray then
        JSONArray := JSONRoot.GetValue( 'repositories' ) as TJSONArray
      else
      begin
        Result := True;
        Exit;
      end;
    end
    else
      Exit;

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

      FRepos[ i ].Branch            := '';
      FRepos[ i ].Status            := rsUnknown;
      FRepos[ i ].StatusText        := '';
      FRepos[ i ].Selected          := False;
      FRepos[ i ].TrackedFileCount  := 0;
      FRepos[ i ].ModifiedFileCount := 0;
      FRepos[ i ].Provider          := rpNone;
    end;

    Result := True;
  finally
    JSONValue.Free;
  end;

end;

function TGitRepoManager.SaveConfig: Boolean;
var
  JSONRoot: TJSONObject;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
begin

  Result   := False;
  JSONRoot := TJSONObject.Create;

  try
    // Save Codeberg credentials
    JSONRoot.AddPair( 'codeberg_username', FCodebergUsername );
    JSONRoot.AddPair( 'codeberg_token', FCodebergToken );

    // Save GitHub credentials
    JSONRoot.AddPair( 'github_username', FGitHubUsername );
    JSONRoot.AddPair( 'github_token', FGitHubToken );

    // Save repositories
    JSONArray := TJSONArray.Create;

    for var i := 0 to High( FRepos ) do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair( 'path', FRepos[ i ].Path );
      JSONArray.AddElement( JSONObj );
    end;

    JSONRoot.AddPair( 'repositories', JSONArray );

    try
      TFile.WriteAllText( FConfigPath, JSONRoot.Format, TEncoding.UTF8 );
      Result := True;
    except
      on E: Exception do
        ; // Silently fail, Result remains False
    end;
  finally
    JSONRoot.Free;
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

  FRepos[ iLen ].Path              := sPath;
  FRepos[ iLen ].Name              := ExtractFileName( ExcludeTrailingPathDelimiter( sPath ) );
  FRepos[ iLen ].Branch            := '';
  FRepos[ iLen ].Status            := rsUnknown;
  FRepos[ iLen ].StatusText        := '';
  FRepos[ iLen ].Selected          := False;
  FRepos[ iLen ].TrackedFileCount  := 0;
  FRepos[ iLen ].ModifiedFileCount := 0;
  FRepos[ iLen ].Provider          := rpNone;

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
var
  sOriginURL: string;
begin

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
    Exit;

  FRepos[ iIndex ].Branch            := GetRepoBranch( FRepos[ iIndex ].Path );
  FRepos[ iIndex ].Status            := GetRepoStatus( FRepos[ iIndex ].Path );
  FRepos[ iIndex ].StatusText        := RepoStatusToString( FRepos[ iIndex ].Status );
  FRepos[ iIndex ].TrackedFileCount  := GetTrackedFileCount( FRepos[ iIndex ].Path );
  FRepos[ iIndex ].ModifiedFileCount := GetModifiedFileCount( FRepos[ iIndex ].Path );

  sOriginURL                         := GetRemoteOriginURL( FRepos[ iIndex ].Path );
  FRepos[ iIndex ].Provider          := DetectRemoteProvider( sOriginURL );

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

function TGitRepoManager.HasCodebergCredentials: Boolean;
begin

  Result := ( not FCodebergUsername.Trim.IsEmpty ) and ( not FCodebergToken.Trim.IsEmpty );

end;

function TGitRepoManager.ExecuteCodebergApiPost( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  RequestStream: TStringStream;
  Headers: TArray<TNameValuePair>;
begin

  Result      := False;
  sResponse   := '';
  iStatusCode := 0;

  HttpClient    := TNetHTTPClient.Create( nil );
  RequestStream := TStringStream.Create( sBody, TEncoding.UTF8 );

  try
    HttpClient.ContentType := 'application/json';

    SetLength( Headers, 2 );
    Headers[ 0 ] := TNameValuePair.Create( 'Authorization', 'token ' + FCodebergToken );
    Headers[ 1 ] := TNameValuePair.Create( 'Content-Type', 'application/json' );

    try
      Response := HttpClient.Post( CODEBERG_API_URL + sEndpoint, RequestStream, nil, Headers );

      iStatusCode := Response.StatusCode;
      sResponse   := Response.ContentAsString;
      Result      := ( iStatusCode >= 200 ) and ( iStatusCode < 300 );
    except
      on E: Exception do
        sResponse := 'HTTP Error: ' + E.Message;
    end;
  finally
    RequestStream.Free;
    HttpClient.Free;
  end;

end;

function TGitRepoManager.ExecuteGitHubApiPost( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  RequestStream: TStringStream;
  Headers: TArray<TNameValuePair>;
begin

  Result      := False;
  sResponse   := '';
  iStatusCode := 0;

  HttpClient    := TNetHTTPClient.Create( nil );
  RequestStream := TStringStream.Create( sBody, TEncoding.UTF8 );

  try
    HttpClient.ContentType := 'application/json';

    SetLength( Headers, 3 );
    Headers[ 0 ] := TNameValuePair.Create( 'Authorization', 'Bearer ' + FGitHubToken );
    Headers[ 1 ] := TNameValuePair.Create( 'Content-Type', 'application/json' );
    Headers[ 2 ] := TNameValuePair.Create( 'Accept', 'application/vnd.github+json' );

    try
      Response := HttpClient.Post( GITHUB_API_URL + sEndpoint, RequestStream, nil, Headers );

      iStatusCode := Response.StatusCode;
      sResponse   := Response.ContentAsString;
      Result      := ( iStatusCode >= 200 ) and ( iStatusCode < 300 );
    except
      on E: Exception do
        sResponse := 'HTTP Error: ' + E.Message;
    end;
  finally
    RequestStream.Free;
    HttpClient.Free;
  end;

end;

function TGitRepoManager.ExecuteCodebergApiPatch( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  RequestStream: TStringStream;
  Headers: TArray<TNameValuePair>;
begin

  Result      := False;
  sResponse   := '';
  iStatusCode := 0;

  HttpClient    := TNetHTTPClient.Create( nil );
  RequestStream := TStringStream.Create( sBody, TEncoding.UTF8 );

  try
    HttpClient.ContentType := 'application/json';

    SetLength( Headers, 2 );
    Headers[ 0 ] := TNameValuePair.Create( 'Authorization', 'token ' + FCodebergToken );
    Headers[ 1 ] := TNameValuePair.Create( 'Content-Type', 'application/json' );

    try
      Response := HttpClient.Patch( CODEBERG_API_URL + sEndpoint, RequestStream, nil, Headers );

      iStatusCode := Response.StatusCode;
      sResponse   := Response.ContentAsString;
      Result      := ( iStatusCode >= 200 ) and ( iStatusCode < 300 );
    except
      on E: Exception do
        sResponse := 'HTTP Error: ' + E.Message;
    end;
  finally
    RequestStream.Free;
    HttpClient.Free;
  end;

end;

function TGitRepoManager.ExecuteGitHubApiPatch( const sEndpoint, sBody: string; out sResponse: string;
  out iStatusCode: Integer ): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  RequestStream: TStringStream;
  Headers: TArray<TNameValuePair>;
begin

  Result      := False;
  sResponse   := '';
  iStatusCode := 0;

  HttpClient    := TNetHTTPClient.Create( nil );
  RequestStream := TStringStream.Create( sBody, TEncoding.UTF8 );

  try
    HttpClient.ContentType := 'application/json';

    SetLength( Headers, 3 );
    Headers[ 0 ] := TNameValuePair.Create( 'Authorization', 'Bearer ' + FGitHubToken );
    Headers[ 1 ] := TNameValuePair.Create( 'Content-Type', 'application/json' );
    Headers[ 2 ] := TNameValuePair.Create( 'Accept', 'application/vnd.github+json' );

    try
      Response := HttpClient.Patch( GITHUB_API_URL + sEndpoint, RequestStream, nil, Headers );

      iStatusCode := Response.StatusCode;
      sResponse   := Response.ContentAsString;
      Result      := ( iStatusCode >= 200 ) and ( iStatusCode < 300 );
    except
      on E: Exception do
        sResponse := 'HTTP Error: ' + E.Message;
    end;
  finally
    RequestStream.Free;
    HttpClient.Free;
  end;

end;

function TGitRepoManager.GetRemoteOriginURL( const sRepoPath: string ): string;
var
  sOutput: string;
begin

  Result := '';

  if ExecuteGitCommand( sRepoPath, 'remote get-url origin', sOutput ) then
    Result := Trim( sOutput );

end;

function TGitRepoManager.DetectRemoteProvider( const sOriginURL: string ): TRemoteProvider;
var
  sLower: string;
begin

  Result := rpNone;

  if sOriginURL.IsEmpty then
    Exit;

  sLower := sOriginURL.ToLower;

  if sLower.Contains( 'codeberg.org' ) then
    Result := rpCodeberg
  else if sLower.Contains( 'github.com' ) then
    Result := rpGitHub
  else if ( not sOriginURL.IsEmpty ) then
    Result := rpOther;

end;

function TGitRepoManager.ParseOwnerRepo( const sOriginURL: string; out sOwner, sRepo: string ): Boolean;
var
  sURL: string;
  iPosLastSlash: Integer;
  iPosSecondLastSlash: Integer;
  sRepoWithExt: string;
begin

  Result := False;
  sOwner := '';
  sRepo  := '';

  sURL := Trim( sOriginURL );

  if sURL.IsEmpty then
    Exit;

  // Remove trailing .git if present
  if sURL.EndsWith( '.git', True ) then
    sURL := Copy( sURL, 1, Length( sURL ) - 4 );

  // Remove trailing slash if present
  if sURL.EndsWith( '/' ) then
    sURL := Copy( sURL, 1, Length( sURL ) - 1 );

  // Find the last slash (repo name is after it)
  iPosLastSlash := sURL.LastIndexOf( '/' );

  if iPosLastSlash < 0 then
    Exit;

  sRepoWithExt := Copy( sURL, iPosLastSlash + 2, MaxInt );

  // Find the second-to-last slash (owner is after it)
  iPosSecondLastSlash := Copy( sURL, 1, iPosLastSlash ).LastIndexOf( '/' );

  if iPosSecondLastSlash < 0 then
  begin
    // Handle SSH format: git@github.com:owner/repo
    iPosSecondLastSlash := sURL.LastIndexOf( ':' );
  end;

  if iPosSecondLastSlash < 0 then
    Exit;

  sOwner := Copy( sURL, iPosSecondLastSlash + 2, iPosLastSlash - iPosSecondLastSlash - 1 );
  sRepo  := sRepoWithExt;

  Result := ( not sOwner.IsEmpty ) and ( not sRepo.IsEmpty );

end;

function TGitRepoManager.GetRepoProvider( const iIndex: Integer ): TRemoteProvider;
var
  sOriginURL: string;
begin

  Result := rpNone;

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
    Exit;

  sOriginURL := GetRemoteOriginURL( FRepos[ iIndex ].Path );
  Result     := DetectRemoteProvider( sOriginURL );

end;

function TGitRepoManager.SetRepositoryVisibility( const iIndex: Integer; const bPrivate: Boolean;
  out sError: string ): Boolean;
var
  sOriginURL: string;
  Provider: TRemoteProvider;
  sOwner, sRepo: string;
  sRequestBody: string;
  sResponse: string;
  iStatusCode: Integer;
begin

  Result := False;
  sError := '';

  if ( iIndex < 0 ) or ( iIndex > High( FRepos ) ) then
  begin
    sError := 'Invalid repository index';
    Exit;
  end;

  sOriginURL := GetRemoteOriginURL( FRepos[ iIndex ].Path );
  Provider   := DetectRemoteProvider( sOriginURL );

  if Provider = rpNone then
  begin
    sError := 'No remote origin configured';
    Exit;
  end;

  if Provider = rpOther then
  begin
    sError := 'Visibility change only supported for GitHub and Codeberg';
    Exit;
  end;

  if ( not ParseOwnerRepo( sOriginURL, sOwner, sRepo ) ) then
  begin
    sError := 'Could not parse owner/repository from origin URL';
    Exit;
  end;

  sRequestBody := Format( '{"private": %s}', [ IfThen( bPrivate, 'true', 'false' ) ] );

  case Provider of
    rpCodeberg:
    begin
      if ( not HasCodebergCredentials ) then
      begin
        sError := 'Codeberg credentials not configured';
        Exit;
      end;

      if ( not ExecuteCodebergApiPatch( Format( '/repos/%s/%s', [ sOwner, sRepo ] ), sRequestBody, sResponse, iStatusCode ) ) then
      begin
        if iStatusCode = 404 then
          sError := 'Repository not found or no permission'
        else if iStatusCode = 401 then
          sError := 'Invalid Codeberg credentials'
        else
          sError := Format( 'Codeberg API error (%d): %s', [ iStatusCode, sResponse ] );

        Exit;
      end;

      Result := True;
    end;

    rpGitHub:
    begin
      if ( not HasGitHubCredentials ) then
      begin
        sError := 'GitHub credentials not configured';
        Exit;
      end;

      if ( not ExecuteGitHubApiPatch( Format( '/repos/%s/%s', [ sOwner, sRepo ] ), sRequestBody, sResponse, iStatusCode ) ) then
      begin
        if iStatusCode = 404 then
          sError := 'Repository not found or no permission'
        else if iStatusCode = 401 then
          sError := 'Invalid GitHub credentials'
        else
          sError := Format( 'GitHub API error (%d): %s', [ iStatusCode, sResponse ] );

        Exit;
      end;

      Result := True;
    end;
  end;

end;

function TGitRepoManager.HasGitHubCredentials: Boolean;
begin

  Result := ( not FGitHubUsername.Trim.IsEmpty ) and ( not FGitHubToken.Trim.IsEmpty );

end;

function TGitRepoManager.CreateGitHubRepository( const sName, sDescription: string; const bPrivate: Boolean;
  out sRemoteURL, sError: string ): Boolean;
var
  sRequestBody: string;
  sResponse: string;
  iStatusCode: Integer;
  JSONResponse: TJSONObject;
begin

  Result     := False;
  sRemoteURL := '';
  sError     := '';

  if ( not HasGitHubCredentials ) then
  begin
    sError := 'GitHub credentials not configured';
    Exit;
  end;

  // Build request JSON
  sRequestBody := Format(
    '{"name": "%s", "description": "%s", "private": %s, "auto_init": false}',
    [ sName, sDescription, IfThen( bPrivate, 'true', 'false' ) ]
  );

  if ( not ExecuteGitHubApiPost( '/user/repos', sRequestBody, sResponse, iStatusCode ) ) then
  begin
    if iStatusCode = 422 then
      sError := 'Repository already exists on GitHub'
    else if iStatusCode = 401 then
      sError := 'Invalid GitHub credentials'
    else
      sError := Format( 'GitHub API error (%d): %s', [ iStatusCode, sResponse ] );

    Exit;
  end;

  // Parse response to get clone URL
  try
    JSONResponse := TJSONObject.ParseJSONValue( sResponse ) as TJSONObject;

    if JSONResponse <> nil then
    begin
      try
        sRemoteURL := JSONResponse.GetValue<string>( 'clone_url', '' );

        if sRemoteURL.IsEmpty then
          sRemoteURL := Format( 'https://github.com/%s/%s.git', [ FGitHubUsername, sName ] );

        Result := True;
      finally
        JSONResponse.Free;
      end;
    end
    else
    begin
      // Fallback URL construction
      sRemoteURL := Format( 'https://github.com/%s/%s.git', [ FGitHubUsername, sName ] );
      Result     := True;
    end;
  except
    on E: Exception do
    begin
      // Fallback URL construction
      sRemoteURL := Format( 'https://github.com/%s/%s.git', [ FGitHubUsername, sName ] );
      Result     := True;
    end;
  end;

end;

function TGitRepoManager.InitializeRepository( const sPath: string; out sLog: string ): Boolean;
var
  sOutput: string;
begin

  Result := False;
  sLog   := '';

  // Check if folder exists
  if ( not TDirectory.Exists( sPath ) ) then
  begin
    sLog := 'Folder does not exist: ' + sPath;
    Exit;
  end;

  // Check if already a git repository
  if TDirectory.Exists( TPath.Combine( sPath, '.git' ) ) then
  begin
    sLog := 'Folder is already a Git repository';
    Exit;
  end;

  // Initialize repository
  if ( not ExecuteGitCommand( sPath, 'init', sOutput ) ) then
  begin
    sLog := 'Failed to initialize repository: ' + Trim( sOutput );
    Exit;
  end;

  sLog := 'Initialized Git repository' + sLineBreak;

  // Rename default branch to main
  if ExecuteGitCommand( sPath, 'branch -M main', sOutput ) then
    sLog := sLog + 'Set default branch to main' + sLineBreak
  else
    sLog := sLog + 'Warning: Could not rename branch to main' + sLineBreak;

  Result := True;

end;

function TGitRepoManager.CreateCodebergRepository( const sName, sDescription: string; const bPrivate: Boolean;
  out sRemoteURL, sError: string ): Boolean;
var
  sRequestBody: string;
  sResponse: string;
  iStatusCode: Integer;
  JSONResponse: TJSONObject;
begin

  Result     := False;
  sRemoteURL := '';
  sError     := '';

  if ( not HasCodebergCredentials ) then
  begin
    sError := 'Codeberg credentials not configured';
    Exit;
  end;

  // Build request JSON
  sRequestBody := Format(
    '{"name": "%s", "description": "%s", "private": %s, "auto_init": false}',
    [ sName, sDescription, IfThen( bPrivate, 'true', 'false' ) ]
  );

  if ( not ExecuteCodebergApiPost( '/user/repos', sRequestBody, sResponse, iStatusCode ) ) then
  begin
    if iStatusCode = 409 then
      sError := 'Repository already exists on Codeberg'
    else if iStatusCode = 401 then
      sError := 'Invalid Codeberg credentials'
    else
      sError := Format( 'Codeberg API error (%d): %s', [ iStatusCode, sResponse ] );

    Exit;
  end;

  // Parse response to get clone URL
  try
    JSONResponse := TJSONObject.ParseJSONValue( sResponse ) as TJSONObject;

    if JSONResponse <> nil then
    begin
      try
        sRemoteURL := JSONResponse.GetValue<string>( 'clone_url', '' );

        if sRemoteURL.IsEmpty then
          sRemoteURL := Format( 'https://codeberg.org/%s/%s.git', [ FCodebergUsername, sName ] );

        Result := True;
      finally
        JSONResponse.Free;
      end;
    end
    else
    begin
      // Fallback URL construction
      sRemoteURL := Format( 'https://codeberg.org/%s/%s.git', [ FCodebergUsername, sName ] );
      Result     := True;
    end;
  except
    on E: Exception do
    begin
      // Fallback URL construction
      sRemoteURL := Format( 'https://codeberg.org/%s/%s.git', [ FCodebergUsername, sName ] );
      Result     := True;
    end;
  end;

end;

function TGitRepoManager.AddRemoteOrigin( const sRepoPath, sRemoteURL: string; out sLog: string ): Boolean;
var
  sOutput: string;
begin

  Result := False;
  sLog   := '';

  if ( not ExecuteGitCommand( sRepoPath, Format( 'remote add origin "%s"', [ sRemoteURL ] ), sOutput ) ) then
  begin
    sLog := 'Failed to add remote origin: ' + Trim( sOutput );
    Exit;
  end;

  sLog   := 'Added remote origin: ' + sRemoteURL + sLineBreak;
  Result := True;

end;

function TGitRepoManager.InitialCommitAndPush( const sRepoPath, sMessage: string; out sLog: string ): Boolean;
var
  sOutput: string;
  sTempFile: string;
begin

  Result := False;
  sLog   := '';

  // Stage all files
  if ( not ExecuteGitCommand( sRepoPath, 'add -A', sOutput ) ) then
  begin
    sLog := 'Failed to stage files: ' + Trim( sOutput );
    Exit;
  end;

  sLog := 'Staged all files' + sLineBreak;

  // Create temp file for commit message
  if ( not CreateCommitMessageFile( sMessage, sTempFile ) ) then
  begin
    sLog := sLog + 'Failed to create commit message file';
    Exit;
  end;

  try
    // Commit
    if ( not ExecuteGitCommand( sRepoPath, Format( 'commit -F "%s"', [ sTempFile ] ), sOutput ) ) then
    begin
      sLog := sLog + 'Commit failed: ' + Trim( sOutput );
      Exit;
    end;

    sLog := sLog + 'Created initial commit' + sLineBreak;
  finally
    if TFile.Exists( sTempFile ) then
    begin
      try
        TFile.Delete( sTempFile );
      except
        ; // Ignore cleanup errors
      end;
    end;
  end;

  // Push with upstream tracking
  if ( not ExecuteGitCommand( sRepoPath, 'push -u origin main', sOutput ) ) then
  begin
    sLog := sLog + 'Push failed: ' + Trim( sOutput );
    Exit;
  end;

  sLog   := sLog + 'Pushed to origin/main' + sLineBreak;
  Result := True;

end;

end.
