﻿unit HTTPSender;

interface

// (c) Z.Razor | zt.am | 2012

uses Windows, WinInet, Classes, Sysutils;

type
  THTTPCookie = record
    FDomain: String;
    FName: String;
    FValue: String;
    FExpires: String;
    FPath: String;
    FHTTPOnly: boolean;
  end;

  THTTPCookieArray = array of THTTPCookie;

  THTTPCookieCollection = class(TPersistent)
  private
    Cookies: THTTPCookieArray;
    RCustomCookies: string;
    function GetCookie(Index: Integer): THTTPCookie;
    procedure PutCookie(Index: Integer; Cookie: THTTPCookie);
  public
    property Items[Index: Integer]: THTTPCookie read GetCookie write PutCookie;
    function Add(Cookie: THTTPCookie; ReplaceIfExists: boolean): Integer;
    function DeleteCookie(Index: Integer): boolean;
    function Count: Integer;
    function GetCookies(Domain, Path: string): string;
    procedure Clear;
  published
    property CustomCookies: string read RCustomCookies write RCustomCookies;

  end;

type
  THTTPResponse = record
    StatusCode: Integer;
    StatusText: string;
    RawHeaders: string;
    ContentLength: Integer;
    ContentEncoding: String;
    Location: String;
    Expires: String;
  end;

  THTTPHeaders = record
    ContentType: String;
    Accept: String;
    AcceptLanguage: String;
    AcceptEncoding: String;
    ExtraHeaders: string;
    Refferer: string;
    UserAgent: string;
  end;

  THTTPBasicAuth = record
    Username: string;
    Password: string;
  end;

type
  TCookieAddEvent = procedure(Sender: TObject; Cookie: THTTPCookie) of object;
  TWorkBeginEvent = procedure(Sender: TObject; WorkCountMax: int64) of object;
  TWorkEvent = procedure(Sender: TObject; WorkCount: int64) of object;
  TWorkEndEvent = procedure(Sender: TObject) of object;

type
  THTTPSender = class(TComponent)
  private
    RResponse: THTTPResponse;
    RResponseText: AnsiString;
    RAllowCookies: boolean;
    RAutoRedirects: boolean;
    RConnectTimeout: Integer;
    RReadTimeout: Integer;
    RSendTimeout: Integer;
    RProxy: String;
    RProxyBypass: String;
    RUseIECookies: boolean;
    RHeaders: THTTPHeaders;
    RBasicAuth: THTTPBasicAuth;
    ROnCookieAdd: TCookieAddEvent;
    ROnWorkBegin: TWorkBeginEvent;
    ROnWork: TWorkEvent;
    ROnWorkEnd: TWorkEndEvent;
    RCookies: THTTPCookieCollection;
    function URLEncode(const URL: string): string;
    function GetWinInetError(ErrorCode: Cardinal): string;
    function GetQueryInfo(hRequest: Pointer; Flag: Integer): String;
    function GetHeaders: PWideChar;
    procedure ProcessCookies(Data: string);
    procedure URLExecute(HTTPS: boolean; const ServerName, Resource, ExtraInfo: string; Method: String;
      const PostData: AnsiString = '');
    procedure ParseURL(const lpszUrl: string; var Host, Resource, ExtraInfo: string);
  public
    property Response: THTTPResponse read RResponse;
    property ResponseText: AnsiString read RResponseText;
    function Get(URL: String): AnsiString;
    function Post(URL: String; PostData: AnsiString): AnsiString;
    function Put(URL: String): AnsiString;
    procedure Free;
    constructor Create(AOwner: TComponent); override;
  published
    property Cookies: THTTPCookieCollection read RCookies write RCookies;
    property Proxy: string read RProxy write RProxy;
    property ProxyBypass: string read RProxyBypass write RProxyBypass;
    property AllowCookies: boolean read RAllowCookies write RAllowCookies default true;
    property AutoRedirects: boolean read RAutoRedirects write RAutoRedirects default true;
    property ConnectTimeout: Integer read RConnectTimeout write RConnectTimeout default 60000;
    property ReadTimeout: Integer read RReadTimeout write RReadTimeout default 60000;
    property SendTimeout: Integer read RSendTimeout write RSendTimeout default 60000;
    property UseIECookies: boolean read RUseIECookies write RUseIECookies default true;
    property Headers: THTTPHeaders read RHeaders write RHeaders;
    property BasicAuth: THTTPBasicAuth read RBasicAuth write RBasicAuth;
    property OnCookieAdd: TCookieAddEvent read ROnCookieAdd write ROnCookieAdd;
    property OnWorkBegin: TWorkBeginEvent read ROnWorkBegin write ROnWorkBegin;
    property OnWork: TWorkEvent read ROnWork write ROnWork;
    property OnWorkEnd: TWorkEndEvent read ROnWorkEnd write ROnWorkEnd;
  end;

procedure Register;

implementation

{ THTTPSender }
function THTTPSender.URLEncode(const URL: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(URL) do begin
    case URL[i] of
      'A' .. 'Z', 'a' .. 'z', '0' .. '9', '-', '_', '.': Result := Result + URL[i];
    else Result := Result + '%' + IntToHex(Ord(URL[i]), 2);
    end;
  end;
end;

procedure THTTPSender.ParseURL(const lpszUrl: string; var Host, Resource, ExtraInfo: string);
var
  lpszScheme: array [0 .. INTERNET_MAX_SCHEME_LENGTH - 1] of Char;
  lpszHostName: array [0 .. INTERNET_MAX_HOST_NAME_LENGTH - 1] of Char;
  lpszUserName: array [0 .. INTERNET_MAX_USER_NAME_LENGTH - 1] of Char;
  lpszPassword: array [0 .. INTERNET_MAX_PASSWORD_LENGTH - 1] of Char;
  lpszUrlPath: array [0 .. INTERNET_MAX_PATH_LENGTH - 1] of Char;
  lpszExtraInfo: array [0 .. 1024 - 1] of Char;
  lpUrlComponents: TURLComponents;
begin
  ZeroMemory(@lpszScheme, SizeOf(lpszScheme));
  ZeroMemory(@lpszHostName, SizeOf(lpszHostName));
  ZeroMemory(@lpszUserName, SizeOf(lpszUserName));
  ZeroMemory(@lpszPassword, SizeOf(lpszPassword));
  ZeroMemory(@lpszUrlPath, SizeOf(lpszUrlPath));
  ZeroMemory(@lpszExtraInfo, SizeOf(lpszExtraInfo));
  ZeroMemory(@lpUrlComponents, SizeOf(TURLComponents));

  lpUrlComponents.dwStructSize := SizeOf(TURLComponents);
  lpUrlComponents.lpszScheme := lpszScheme;
  lpUrlComponents.dwSchemeLength := SizeOf(lpszScheme);
  lpUrlComponents.lpszHostName := lpszHostName;
  lpUrlComponents.dwHostNameLength := SizeOf(lpszHostName);
  lpUrlComponents.lpszUserName := lpszUserName;
  lpUrlComponents.dwUserNameLength := SizeOf(lpszUserName);
  lpUrlComponents.lpszPassword := lpszPassword;
  lpUrlComponents.dwPasswordLength := SizeOf(lpszPassword);
  lpUrlComponents.lpszUrlPath := lpszUrlPath;
  lpUrlComponents.dwUrlPathLength := SizeOf(lpszUrlPath);
  lpUrlComponents.lpszExtraInfo := lpszExtraInfo;
  lpUrlComponents.dwExtraInfoLength := SizeOf(lpszExtraInfo);

  InternetCrackUrl(PChar(lpszUrl), Length(lpszUrl), ICU_DECODE or ICU_ESCAPE, lpUrlComponents);

  Host := lpszHostName;
  Resource := lpszUrlPath;
  ExtraInfo := lpszExtraInfo;
end;

function THTTPSender.GetQueryInfo(hRequest: Pointer; Flag: Integer): String;
var
  code: String;
  size, Index: Cardinal;
begin
  Result := '';
  SetLength(code, 8);
  size := Length(code);
  index := 0;
  if HttpQueryInfo(hRequest, Flag, PChar(code), size, index) then Result := code
  else if GetLastError = ERROR_INSUFFICIENT_BUFFER then begin
    SetLength(code, size);
    size := Length(code);
    if HttpQueryInfo(hRequest, Flag, PChar(code), size, index) then Result := code;
  end;
end;

function THTTPSender.GetWinInetError(ErrorCode: Cardinal): string;
const
  winetdll = 'wininet.dll';
var
  Len: Integer;
  Buffer: PChar;
begin
  Len := FormatMessage(FORMAT_MESSAGE_FROM_HMODULE or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER or
    FORMAT_MESSAGE_IGNORE_INSERTS or FORMAT_MESSAGE_ARGUMENT_ARRAY, Pointer(GetModuleHandle(winetdll)), ErrorCode, 0,
    @Buffer, SizeOf(Buffer), nil);
  try
    while (Len > 0) and {$IFDEF UNICODE}(CharInSet(Buffer[Len - 1], [#0 .. #32, '.']))
{$ELSE}(Buffer[Len - 1] in [#0 .. #32, '.']) {$ENDIF} do Dec(Len);
    SetString(Result, Buffer, Len);
  finally
    LocalFree(HLOCAL(Buffer));
  end;
end;

procedure THTTPSender.URLExecute(HTTPS: boolean; const ServerName, Resource, ExtraInfo: string; Method: String;
  const PostData: AnsiString = '');
const
  C_PROXYCONNECTION = 'Proxy-Connection: Keep-Alive'#10#13;
var
  hInet: HINTERNET;
  hConnect: HINTERNET;
  hRequest: HINTERNET;
  ErrorCode: Integer;
  lpvBuffer: PansiChar;
  lpdwBufferLength: DWORD;
  dwBytesRead: DWORD;
  lpdwNumberOfBytesAvailable: DWORD;
  ConnectPort: INTERNET_PORT;
  OpenTypeFlags: DWORD;
  OpenRequestFlags: DWORD;
  PostDataPointer: Pointer;
  PostDataLength: DWORD;
  lpOtherHeaders: String;
  Buffer: array [0 .. 1024] of AnsiChar;

  function ExtractHeaders: boolean;
  var
    lpdwReserved: DWORD;
  begin
    Result := true;
    with RResponse do begin
      lpdwBufferLength := SizeOf(StatusCode);
      lpdwReserved := 0;
      Result := Result and HttpQueryInfo(hRequest, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER, @StatusCode,
        lpdwBufferLength, lpdwReserved);
      SetLength(StatusText, 1024);
      lpdwBufferLength := Length(StatusText);
      Result := Result and HttpQueryInfo(hRequest, HTTP_QUERY_STATUS_TEXT, @StatusText[1], lpdwBufferLength,
        lpdwReserved);
      lpdwBufferLength := SizeOf(ContentLength);
      if not HttpQueryInfo(hRequest, HTTP_QUERY_CONTENT_LENGTH or HTTP_QUERY_FLAG_NUMBER, @ContentLength,
        lpdwBufferLength, lpdwReserved) then ContentLength := 0;
      SetLength(ContentEncoding, 1024);
      lpdwBufferLength := Length(ContentEncoding);
      if not HttpQueryInfo(hRequest, HTTP_QUERY_CONTENT_ENCODING, @ContentEncoding[1], lpdwBufferLength, lpdwReserved)
      then ContentEncoding := '';
      SetLength(Location, 1024);
      lpdwBufferLength := Length(Location);
      if not HttpQueryInfo(hRequest, HTTP_QUERY_LOCATION, @Location[1], lpdwBufferLength, lpdwReserved) then
          Location := '';
      SetLength(Expires, 1024);
      lpdwBufferLength := Length(Expires);
      if not HttpQueryInfo(hRequest, HTTP_QUERY_EXPIRES, @Expires[1], lpdwBufferLength, lpdwReserved) then
          Expires := '';
    end;
  end;

begin
  with RResponse do begin
    StatusCode := 0;
    StatusText := '';
    RawHeaders := '';
    ContentLength := 0;
    Expires := '';
  end;
  RResponseText := '';
  lpOtherHeaders := '';

  if RProxy <> '' then OpenTypeFlags := INTERNET_OPEN_TYPE_PROXY
  else OpenTypeFlags := INTERNET_OPEN_TYPE_PRECONFIG;

  hInet := InternetOpen(PChar(RHeaders.UserAgent), OpenTypeFlags, PChar(RProxy), PChar(RProxyBypass), 0);

  InternetSetOption(hInet, INTERNET_OPTION_CONNECT_TIMEOUT, @RConnectTimeout, SizeOf(RConnectTimeout));
  InternetSetOption(hInet, INTERNET_OPTION_RECEIVE_TIMEOUT, @RReadTimeout, SizeOf(RReadTimeout));
  InternetSetOption(hInet, INTERNET_OPTION_SEND_TIMEOUT, @RSendTimeout, SizeOf(RSendTimeout));

  if hInet = nil then begin
    ErrorCode := GetLastError;
    raise Exception.Create(Format('InternetOpen Error %d Description %s', [ErrorCode, GetWinInetError(ErrorCode)]));
  end;

  try
    if HTTPS then ConnectPort := INTERNET_DEFAULT_HTTPS_PORT
    else ConnectPort := INTERNET_DEFAULT_HTTP_PORT;
    hConnect := InternetConnect(hInet, PChar(ServerName), ConnectPort, PChar(RBasicAuth.Username),
      PChar(RBasicAuth.Password), INTERNET_SERVICE_HTTP, 0, 0);
    if hConnect = nil then begin
      ErrorCode := GetLastError;
      raise Exception.Create(Format('InternetConnect Error %d Description %s',
        [ErrorCode, GetWinInetError(ErrorCode)]));
    end;

    try
      if HTTPS then OpenRequestFlags := INTERNET_FLAG_SECURE
      else OpenRequestFlags := INTERNET_FLAG_RELOAD;
      if not RAutoRedirects then OpenRequestFlags := OpenRequestFlags or INTERNET_FLAG_NO_AUTO_REDIRECT;
      if (not RUseIECookies) or (not RAllowCookies) then
          OpenRequestFlags := OpenRequestFlags or INTERNET_FLAG_NO_COOKIES;

      hRequest := HttpOpenRequest(hConnect, PChar(Method), PChar(Resource + ExtraInfo), HTTP_VERSION,
        PChar(RHeaders.Refferer), nil, OpenRequestFlags, 0);
      if hRequest = nil then begin
        ErrorCode := GetLastError;
        raise Exception.Create(Format('HttpOpenRequest Error %d Description %s',
          [ErrorCode, GetWinInetError(ErrorCode)]));
      end;
      if RAllowCookies and (not RUseIECookies) then
          lpOtherHeaders := RCookies.GetCookies('.' + ServerName, Resource) + #10#13;
      if RProxy <> '' then lpOtherHeaders := lpOtherHeaders + C_PROXYCONNECTION + #10#13;

      try
        if Method = 'POST' then begin
          PostDataPointer := @PostData[1];
          PostDataLength := Length(PostData);
        end else begin
          PostDataPointer := nil;
          PostDataLength := 0;
        end;

        if not HTTPSendRequest(hRequest, PWideChar(GetHeaders + lpOtherHeaders), 0, PostDataPointer, PostDataLength)
        then begin
          ErrorCode := GetLastError;
          raise Exception.Create(Format('HttpSendRequest Error %d Description %s',
            [ErrorCode, GetWinInetError(ErrorCode)]));
        end;

        RResponse.RawHeaders := GetQueryInfo(hRequest, HTTP_QUERY_RAW_HEADERS_CRLF);
        if RAllowCookies and (not RUseIECookies) then ProcessCookies(RResponse.RawHeaders);

        if not ExtractHeaders then begin
          ErrorCode := GetLastError;
          raise Exception.Create(Format('HttpQueryInfo Error %d Description %s',
            [ErrorCode, GetWinInetError(ErrorCode)]));
        end;
        if Assigned(ROnWorkBegin) then ROnWorkBegin(self, Response.ContentLength);
        if RResponse.StatusCode = 200 then begin
          repeat
            if not InternetReadFile(hRequest, @Buffer, SizeOf(Buffer), dwBytesRead) then begin
              ErrorCode := GetLastError;
              raise Exception.Create(Format('InternetReadFile Error %d Description %s',
                [ErrorCode, GetWinInetError(ErrorCode)]));
            end;
            Buffer[dwBytesRead] := #0;
            lpvBuffer := PansiChar(@Buffer);
            RResponseText := RResponseText + AnsiString(lpvBuffer);
            if Assigned(ROnWork) then ROnWork(self, Length(RResponseText));
          until dwBytesRead = 0;
        end;
        if Assigned(ROnWorkEnd) then ROnWorkEnd(self);
      finally
        InternetCloseHandle(hRequest);
      end;
    finally
      InternetCloseHandle(hConnect);
    end;
  finally
    InternetCloseHandle(hInet);
  end;
end;

constructor THTTPSender.Create(AOwner: TComponent);
begin
  inherited;
  RCookies := THTTPCookieCollection.Create;
  RReadTimeout := 60000;
  RConnectTimeout := 60000;
  RSendTimeout := 60000;
  RProxy := '';
  RProxyBypass := '';
  RUseIECookies := true;
  RAllowCookies := true;
  with RHeaders do begin
    ContentType := 'application/x-www-form-urlencoded';
    Accept := '';
    AcceptLanguage := '';
    AcceptEncoding := '';
    ExtraHeaders := '';
    Refferer := '';
    UserAgent := 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)';
  end;
end;

procedure THTTPSender.Free;
begin
  RCookies.Free;
  Destroy;
end;

function THTTPSender.Get(URL: String): AnsiString;
var
  Host, Resource, ExtraInfo: string;
begin
  Result := '';
  ParseURL(URL, Host, Resource, ExtraInfo);
  if Pos('http', URL) = 1 then URLExecute((Pos('https', URL) = 1), Host, Resource, ExtraInfo, 'GET')
  else raise Exception.Create(Format('Unknown Protocol %s', [URL]));
  Result := RResponseText;
end;

function THTTPSender.GetHeaders: PWideChar;
begin
  Result := '';
  with RHeaders do begin
    if ContentType <> '' then Result := PChar(Format('%sContent-type: %s'#10#13, [Result, ContentType]));
    if AcceptLanguage <> '' then Result := PChar(Format('%sAccept-Language: %s'#10#13, [Result, AcceptLanguage]));
    if AcceptEncoding <> '' then Result := PChar(Format('%sAccept-Encoding: %s'#10#13, [Result, AcceptEncoding]));
    if Accept <> '' then Result := PChar(Format('%sAccept: %s'#10#13, [Result, Accept]));
    if ExtraHeaders <> '' then Result := PChar(Format('%s'#10#13'%s'#10#13, [Result, ExtraHeaders]));
  end;
end;

function THTTPSender.Post(URL: String; PostData: AnsiString): AnsiString;
var
  Host, Resource, ExtraInfo: string;
begin
  Result := '';
  ParseURL(URL, Host, Resource, ExtraInfo);
  if Pos('http', URL) = 1 then URLExecute((Pos('https', URL) = 1), Host, Resource, ExtraInfo, 'POST', PostData)
  else raise Exception.Create(Format('Unknown Protocol %s', [URL]));
  Result := RResponseText;
end;

function Pars(const source, left, right: string): string;
var
  r, l: Integer;
begin
  l := Pos(left, source);
  r := Pos(right, (Copy(source, l + Length(left), Length(source) - l - Length(left)))) + l;
  if l = r then exit('');
  Result := Copy(source, l + Length(left), r - l - 1);
end;

procedure THTTPSender.ProcessCookies(Data: string);
const
  SetCookie = 'Set-Cookie:';
var
  NCookie: THTTPCookie;

  function GetCookie(s: string): THTTPCookie;
  var
    t: string;
  begin
    with Result do begin
      FName := Copy(s, 1, Pos('=', s) - 1);
      FValue := Pars(s, '=', ';');
      FPath := Pars(s, 'path=', ';');
      FExpires := Pars(s, 'expires=', ';');
      FDomain := Pars(s, 'domain=', ';');
      FHTTPOnly := (Pos('; HttpOnly', s) > 0);
    end;
  end;

begin
  while Pos(SetCookie, Data) > 0 do begin
    NCookie := GetCookie(Pars(Data, SetCookie, #10#13));
    RCookies.Add(NCookie, true);
    if Assigned(ROnCookieAdd) then ROnCookieAdd(self, NCookie);
    Delete(Data, Pos(SetCookie, Data), Length(SetCookie));
  end;
end;

function THTTPSender.Put(URL: String): AnsiString;
var
  Host, Resource, ExtraInfo: string;
begin
  Result := '';
  ParseURL(URL, Host, Resource, ExtraInfo);
  if Pos('http', URL) = 1 then URLExecute((Pos('https', URL) = 1), Host, Resource, ExtraInfo, 'PUT')
  else raise Exception.Create(Format('Unknown Protocol %s', [URL]));
  Result := RResponseText;
end;

{ THTTPCookieCollection }

function THTTPCookieCollection.Add(Cookie: THTTPCookie; ReplaceIfExists: boolean): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(Cookies) do
    if (Cookies[i].FDomain = Cookie.FDomain) and (Cookies[i].FName = Cookie.FName) then begin
      Cookies[i] := Cookie;
      exit(i);
    end;
  SetLength(Cookies, Length(Cookies) + 1);
  Cookies[high(Cookies)] := Cookie;
end;

procedure THTTPCookieCollection.Clear;
begin
  SetLength(Cookies, 0);
end;

function THTTPCookieCollection.Count: Integer;
begin
  Result := Length(Cookies);
end;

function THTTPCookieCollection.DeleteCookie(Index: Integer): boolean;
var
  i: Integer;
begin
  Result := false;
  if (index < 0) or (index > high(Cookies)) then exit;
  for i := Index to High(Cookies) - 1 do Cookies[i] := Cookies[i + 1];
  SetLength(Cookies, Length(Cookies) - 1);
  Result := true;
end;

function THTTPCookieCollection.GetCookie(Index: Integer): THTTPCookie;
begin
  Result := Cookies[Index];
end;

function THTTPCookieCollection.GetCookies(Domain, Path: string): string;
var
  i: Integer;
begin
  for i := Length(Path) downto 1 do
    if (Path[i] = '/') and (i > 1) then begin
      Path := Copy(Path, 1, i);
      break;
    end;
  Result := 'Cookies:';
  for i := 0 to High(Cookies) do
    if Cookies[i].FDomain = Domain then Result := Format('%s %s=%s;', [Result, Cookies[i].FName, Cookies[i].FValue]);
  Result := Result + ' ' + RCustomCookies;
  if Result[Length(Result) - 1] = ';' then Delete(Result, Length(Result) - 1, 2);
  if Length(Result) = 7 then Result := '';
end;

procedure THTTPCookieCollection.PutCookie(Index: Integer; Cookie: THTTPCookie);
begin
  Cookies[Index] := Cookie;
end;

procedure Register;
begin
  RegisterComponents('Internet', [THTTPSender]);
end;

end.
