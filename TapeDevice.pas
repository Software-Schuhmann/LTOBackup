unit TapeDevice;

{$mode objfpc}{$H+}

interface

uses Windows, BackupTypes;

function OpenTapeDevice(const DeviceName: string; AccessMode: DWORD): THandle;
function GetTapeMediaInfo(TapeHandle: THandle; out Params: TAPE_GET_MEDIA_PARAMETERS): Boolean;
function WriteTapeBlock(TapeHandle: THandle; const Data; Count: Integer): Boolean;
function ReadTapeBlock(TapeHandle: THandle; var Data): Boolean;

implementation

function OpenTapeDevice(const DeviceName: string; AccessMode: DWORD): THandle;
begin
  Result := CreateFile(PChar(DeviceName), AccessMode, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
end;

function GetTapeMediaInfo(TapeHandle: THandle; out Params: TAPE_GET_MEDIA_PARAMETERS): Boolean;
var Size: DWORD;
begin
  FillChar(Params, SizeOf(Params), 0); Size := SizeOf(Params);
  Result := GetTapeParameters(TapeHandle, GET_TAPE_MEDIA_INFORMATION, Size, @Params) = NO_ERROR;
end;

function WriteTapeBlock(TapeHandle: THandle; const Data; Count: Integer): Boolean;
var Buffer: array[0..BLOCK_SIZE - 1] of Byte; Written: DWORD;
begin
  FillChar(Buffer, SizeOf(Buffer), 0); if (Count < 0) or (Count > BLOCK_SIZE) then Exit(False); Move(Data, Buffer, Count);
  Result := Windows.WriteFile(TapeHandle, Buffer, BLOCK_SIZE, Written, nil) and (Written = BLOCK_SIZE);
end;

function ReadTapeBlock(TapeHandle: THandle; var Data): Boolean;
var Read: DWORD;
begin
  Result := Windows.ReadFile(TapeHandle, Data, BLOCK_SIZE, Read, nil) and (Read = BLOCK_SIZE);
end;

end.
