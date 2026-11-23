program LTO;

{$mode objfpc}{$H+}
{$APPTYPE GUI}

uses
  Interfaces, Forms, Windows, ShellAPI, MainUnit;

function ProcessIsElevated: Boolean;
var Token: THandle; Elevation: TOKEN_ELEVATION; ReturnLength: DWORD;
begin
  Result := False;
  if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, Token) then begin
    Result := GetTokenInformation(Token, TokenElevation, @Elevation, SizeOf(Elevation), ReturnLength) and (Elevation.TokenIsElevated <> 0);
    CloseHandle(Token);
  end;
end;

{$R *.res}

begin
  if not ProcessIsElevated then begin
    ShellExecute(0, 'runas', PChar(Application.ExeName), nil, nil, SW_SHOWNORMAL);
    Halt;
  end;
  RequireDerivedFormResource := False;
  Application.Title:='TapeBackup';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
