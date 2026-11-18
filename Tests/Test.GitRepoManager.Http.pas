(* GITLAK Software
  ***************************************************************************

    © 2026 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit test suite.

  Test.GitRepoManager.Http.pas - the GitHub API request never follows a
  redirect, so the token it carries cannot reach another host ( the RTL
  replays Authorization to any redirect target; GITLAKRTL finding D2 ).

  ***************************************************************************
*)

unit Test.GitRepoManager.Http;

interface

uses
  DUnitX.TestFramework,
  Test.Support;

type
  /// <summary>The API request and redirects (the token must stay with the host it was given for).</summary>
  [TestFixture]
  TTestApiRedirect = class
  private
    /// <summary>Per-test sandbox holding the configuration file.</summary>
    FSandbox: TGitSandbox;
  public
    /// <summary>Creates the sandbox.</summary>
    [Setup]
    procedure Setup;
    /// <summary>Frees the sandbox.</summary>
    [TearDown]
    procedure TearDown;
    /// <summary>
    ///   Proves a 302 from the API to another host is not followed: the request fails with status 302, the response
    ///   names the Location, and the other host receives nothing (so the Authorization token never reaches it).
    ///   Without the fix the RTL follows the redirect, replays the token there and reports success.
    /// </summary>
    [Test]
    procedure RedirectIsNotFollowedWithTheToken;
    /// <summary>Regression control: proves a 200 answer is still a success carrying the token to the API host.</summary>
    [Test]
    procedure DirectSuccessUnchanged;
    /// <summary>
    ///   Proves a redirect within the API's own origin (GitHub's 307 for a renamed repository) is followed once,
    ///   with the same verb and the token, and the request succeeds.
    /// </summary>
    [Test]
    procedure SameOriginRedirectIsFollowedOnce;
    /// <summary>Proves a second redirect, even within the origin, is refused: a loop cannot keep re-sending the token.</summary>
    [Test]
    procedure SecondRedirectIsRefused;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.Winsock2,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Net.URLClient,
  uGitRepoManager;

type
  /// <summary>Exposes the protected API request to the tests.</summary>
  TApiProbe = class( TGitRepoManager )
  public
    /// <summary>Calls ExecuteApiRequest.</summary>
    /// <param name="ABaseURL">The base URL.</param>
    /// <param name="AStatus">The status code received.</param>
    /// <param name="AResponse">The response text.</param>
    /// <returns>ExecuteApiRequest's result.</returns>
    function Post( const ABaseURL: string; out AStatus: Integer; out AResponse: string ): Boolean;
  end;

  /// <summary>
  ///   A one-thread HTTP/1.1 server on 127.0.0.1: /a answers 302 to RedirectTo (or 200 when RedirectTo is empty),
  ///   anything else 200.  Every request's header block is recorded.
  /// </summary>
  TMiniHttpServer = class( TThread )
  private
    /// <summary>The listening socket.</summary>
    FListen: TSocket;
    /// <summary>The port the system chose.</summary>
    FPort: Word;
    /// <summary>The header blocks received.</summary>
    FRequests: TStringList;
    /// <summary>Guards FRequests.</summary>
    FLock: TCriticalSection;
    /// <summary>Location sent in answer to /a; empty for a 200.</summary>
    FRedirectTo: string;
  protected
    /// <summary>Accepts and answers connections until the listening socket is closed.</summary>
    procedure Execute; override;
  public
    /// <summary>Opens the listening socket on 127.0.0.1 and starts the thread.</summary>
    /// <exception cref="EOSError">The socket could not be opened or bound.</exception>
    constructor Create;
    /// <summary>Closes the socket and waits for the thread.</summary>
    destructor Destroy; override;
    /// <summary>Starts the thread once construction has succeeded.</summary>
    procedure AfterConstruction; override;
    /// <summary>The number of requests received.</summary>
    /// <returns>The count.</returns>
    function RequestCount: Integer;
    /// <summary>The header block of request AIndex, or ''.</summary>
    /// <param name="AIndex">0-based index.</param>
    /// <returns>The raw header block.</returns>
    function Request( AIndex: Integer ): string;
    /// <summary>The port the server listens on.</summary>
    property Port: Word read FPort;
    /// <summary>Where /a redirects to; empty for a 200.</summary>
    property RedirectTo: string read FRedirectTo write FRedirectTo;
  end;

function TApiProbe.Post( const ABaseURL: string; out AStatus: Integer; out AResponse: string ): Boolean;
begin
  Result := ExecuteApiRequest( 'POST', ABaseURL, '/a', '{}',
    [ TNameValuePair.Create( 'Authorization', 'Bearer test-token' ) ], AResponse, AStatus );
end;

constructor TMiniHttpServer.Create;
var
  lData: TWSAData;
  lAddr: TSockAddrIn;
  lLen: Integer;
begin
  inherited Create( True );
  FRequests := TStringList.Create;
  FLock := TCriticalSection.Create;
  if WSAStartup( $0202, lData ) <> 0 then
    RaiseLastOSError;
  FListen := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
  if FListen = INVALID_SOCKET then
    RaiseLastOSError;
  lAddr := Default( TSockAddrIn );
  lAddr.sin_family := AF_INET;
  lAddr.sin_addr.S_addr := htonl( INADDR_LOOPBACK );
  if ( bind( FListen, PSockAddr( @lAddr )^, SizeOf( lAddr ) ) <> 0 ) or ( listen( FListen, 4 ) <> 0 ) then
    RaiseLastOSError;
  lLen := SizeOf( lAddr );
  getsockname( FListen, PSockAddr( @lAddr )^, lLen );
  FPort := ntohs( lAddr.sin_port );
end;

procedure TMiniHttpServer.AfterConstruction;
begin
  inherited AfterConstruction;
  Start;
end;

destructor TMiniHttpServer.Destroy;
begin
  closesocket( FListen );
  inherited Destroy;
  FLock.Free;
  FRequests.Free;
  WSACleanup;
end;

function TMiniHttpServer.RequestCount: Integer;
begin
  FLock.Enter;
  try
    Result := FRequests.Count;
  finally
    FLock.Leave;
  end;
end;

function TMiniHttpServer.Request( AIndex: Integer ): string;
begin
  FLock.Enter;
  try
    if AIndex < FRequests.Count then
      Result := FRequests[ AIndex ]
    else
      Result := '';
  finally
    FLock.Leave;
  end;
end;

procedure TMiniHttpServer.Execute;
var
  lBuffer: array[ 0..4095 ] of AnsiChar;
begin
  while not Terminated do
  begin
    var lClient := accept( FListen, nil, nil );
    if lClient = INVALID_SOCKET then
      Exit;
    try
      var lText: AnsiString := '';
      while Pos( AnsiString( #13#10#13#10 ), lText ) = 0 do
      begin
        var lGot := recv( lClient, lBuffer, SizeOf( lBuffer ), 0 );
        if lGot <= 0 then
          Break;
        var lOld := Length( lText );
        SetLength( lText, lOld + lGot );
        Move( lBuffer, lText[ lOld + 1 ], lGot );
      end;
      // Read the body too (Content-Length), so the client is not cut off mid-send.
      var lHeaderEnd := Pos( AnsiString( #13#10#13#10 ), lText ) + 3;
      var lLenPos := Pos( 'content-length:', LowerCase( string( lText ) ) );
      if ( lHeaderEnd > 3 ) and ( lLenPos > 0 ) then
      begin
        var lLenText := Trim( Copy( string( lText ), lLenPos + 15, Pos( #13, string( lText ), lLenPos ) - lLenPos - 15 ) );
        var lWant := lHeaderEnd + StrToIntDef( lLenText, 0 );
        while Length( lText ) < lWant do
        begin
          var lGot := recv( lClient, lBuffer, SizeOf( lBuffer ), 0 );
          if lGot <= 0 then
            Break;
          var lOld := Length( lText );
          SetLength( lText, lOld + lGot );
          Move( lBuffer, lText[ lOld + 1 ], lGot );
        end;
      end;
      var lHead := string( lText );
      FLock.Enter;
      try
        FRequests.Add( lHead );
      finally
        FLock.Leave;
      end;
      var lReply: AnsiString;
      if ( FRedirectTo <> '' ) and lHead.Contains( ' /a ' ) then
        lReply := AnsiString( 'HTTP/1.1 302 Found'#13#10'Location: ' + FRedirectTo +
          #13#10'Content-Length: 0'#13#10'Connection: close'#13#10#13#10 )
      else
        lReply := 'HTTP/1.1 200 OK'#13#10'Content-Length: 2'#13#10'Connection: close'#13#10#13#10'{}';
      send( lClient, PAnsiChar( lReply )^, Length( lReply ), 0 );
    finally
      closesocket( lClient );
    end;
  end;
end;

procedure TTestApiRedirect.Setup;
begin
  FSandbox := TGitSandbox.Create;
end;

procedure TTestApiRedirect.TearDown;
begin
  FreeAndNil( FSandbox );
end;

procedure TTestApiRedirect.RedirectIsNotFollowedWithTheToken;
var
  lStatus: Integer;
  lResponse: string;
begin
  var lApi: TMiniHttpServer := nil;
  var lOther: TMiniHttpServer := nil;
  var lProbe: TApiProbe := nil;
  try
    lApi := TMiniHttpServer.Create;
    lOther := TMiniHttpServer.Create;
    lProbe := TApiProbe.Create( FSandbox.ConfigFile );
    lApi.RedirectTo := Format( 'http://127.0.0.1:%d/b', [ lOther.Port ] );
    var lOk := lProbe.Post( Format( 'http://127.0.0.1:%d', [ lApi.Port ] ), lStatus, lResponse );
    Assert.AreEqual( 0, lOther.RequestCount, 'The redirect target was contacted (and given the token)' );
    Assert.IsFalse( lOk, 'A redirect is not a success' );
    Assert.AreEqual( 302, lStatus, 'Status; response: ' + lResponse );
    Assert.Contains( lResponse, lApi.RedirectTo, 'The response names where the redirect pointed' );
  finally
    lProbe.Free;
    lOther.Free;
    lApi.Free;
  end;
end;

procedure TTestApiRedirect.DirectSuccessUnchanged;
var
  lStatus: Integer;
  lResponse: string;
begin
  var lApi: TMiniHttpServer := nil;
  var lProbe: TApiProbe := nil;
  try
    lApi := TMiniHttpServer.Create;
    lProbe := TApiProbe.Create( FSandbox.ConfigFile );
    var lOk := lProbe.Post( Format( 'http://127.0.0.1:%d', [ lApi.Port ] ), lStatus, lResponse );
    Assert.IsTrue( lOk, 'Result; response: ' + lResponse );
    Assert.AreEqual( 200, lStatus, 'Status' );
    Assert.Contains( LowerCase( lApi.Request( 0 ) ), 'authorization: bearer test-token', 'The token reaches the API host' );
  finally
    lProbe.Free;
    lApi.Free;
  end;
end;

procedure TTestApiRedirect.SameOriginRedirectIsFollowedOnce;
var
  lStatus: Integer;
  lResponse: string;
begin
  var lApi: TMiniHttpServer := nil;
  var lProbe: TApiProbe := nil;
  try
    lApi := TMiniHttpServer.Create;
    lProbe := TApiProbe.Create( FSandbox.ConfigFile );
    lApi.RedirectTo := Format( 'http://127.0.0.1:%d/b', [ lApi.Port ] );
    var lOk := lProbe.Post( Format( 'http://127.0.0.1:%d', [ lApi.Port ] ), lStatus, lResponse );
    Assert.IsTrue( lOk, 'Result; response: ' + lResponse );
    Assert.AreEqual( 200, lStatus, 'Status' );
    Assert.AreEqual( 2, lApi.RequestCount, 'One hop: the request and the redirected one' );
    Assert.Contains( LowerCase( lApi.Request( 1 ) ), 'post /b ', 'The same verb goes to the new location' );
    Assert.Contains( LowerCase( lApi.Request( 1 ) ), 'authorization: bearer test-token', 'The token goes with it' );
  finally
    lProbe.Free;
    lApi.Free;
  end;
end;

procedure TTestApiRedirect.SecondRedirectIsRefused;
var
  lStatus: Integer;
  lResponse: string;
begin
  var lApi: TMiniHttpServer := nil;
  var lProbe: TApiProbe := nil;
  try
    lApi := TMiniHttpServer.Create;
    lProbe := TApiProbe.Create( FSandbox.ConfigFile );
    lApi.RedirectTo := Format( 'http://127.0.0.1:%d/a', [ lApi.Port ] );
    var lOk := lProbe.Post( Format( 'http://127.0.0.1:%d', [ lApi.Port ] ), lStatus, lResponse );
    Assert.IsFalse( lOk, 'A redirect loop is not a success' );
    Assert.AreEqual( 302, lStatus, 'Status' );
    Assert.AreEqual( 2, lApi.RequestCount, 'Exactly one hop is followed' );
    Assert.Contains( lResponse, 'not followed', 'The caller is told why the request stopped' );
  finally
    lProbe.Free;
    lApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestApiRedirect );

end.
