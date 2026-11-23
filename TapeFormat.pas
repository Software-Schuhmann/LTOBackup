unit TapeFormat;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, BackupTypes;

function BuildHeader(Count: Cardinal; const TapeId: TGUID): TBytes;
function ParseHeader(const Buffer: TBytes; out Count: Cardinal; out TapeId: TGUID): Boolean;
function BuildMetadata(const Entry: TArchiveEntry): TBytes;
function ParseMetadata(const Buffer: TBytes; out Entry: TArchiveEntry): Boolean;

implementation

function BuildHeader(Count: Cardinal; const TapeId: TGUID): TBytes;
var M: TMemoryStream; V: Cardinal; S: AnsiString;
begin
  SetLength(Result, BLOCK_SIZE); FillChar(Result[0], Length(Result), 0); M := TMemoryStream.Create;
  try
    S := FORMAT_MAGIC; M.WriteBuffer(S[1], Length(S)); V := FORMAT_VERSION;
    M.WriteBuffer(V, SizeOf(V)); M.WriteBuffer(Count, SizeOf(Count)); M.WriteBuffer(TapeId, SizeOf(TapeId)); Move(M.Memory^, Result[0], M.Size);
  finally M.Free; end;
end;

function ParseHeader(const Buffer: TBytes; out Count: Cardinal; out TapeId: TGUID): Boolean;
var S: AnsiString; V: Cardinal;
begin
  Result := False; FillChar(TapeId, SizeOf(TapeId), 0); Count := 0; if Length(Buffer) < BLOCK_SIZE then Exit;
  SetLength(S, Length(FORMAT_MAGIC)); Move(Buffer[0], S[1], Length(S)); Move(Buffer[Length(FORMAT_MAGIC)], V, SizeOf(V));
  Move(Buffer[Length(FORMAT_MAGIC) + SizeOf(V)], Count, SizeOf(Count));
  Result := (S = FORMAT_MAGIC) and ((V = FORMAT_VERSION) or (V = LEGACY_FORMAT_VERSION));
  if Result and (V = FORMAT_VERSION) then Move(Buffer[Length(FORMAT_MAGIC) + SizeOf(V) + SizeOf(Count)], TapeId, SizeOf(TapeId));
end;

function BuildMetadata(const Entry: TArchiveEntry): TBytes;
var M: TMemoryStream; Kind, L: Cardinal; S: UTF8String;
begin
  SetLength(Result, BLOCK_SIZE); FillChar(Result[0], Length(Result), 0); M := TMemoryStream.Create;
  try
    Kind := Ord(Entry.IsDirectory); M.WriteBuffer(Kind, SizeOf(Kind)); M.WriteBuffer(Entry.Size, SizeOf(Entry.Size));
    S := UTF8Encode(Entry.RelativePath); L := Length(S); M.WriteBuffer(L, SizeOf(L)); if L > 0 then M.WriteBuffer(S[1], L); Move(M.Memory^, Result[0], M.Size);
  finally M.Free; end;
end;

function ParseMetadata(const Buffer: TBytes; out Entry: TArchiveEntry): Boolean;
var P, Kind, L: Cardinal; S: UTF8String;
begin
  Result := False; FillChar(Entry, SizeOf(Entry), 0); P := 0; if Length(Buffer) < BLOCK_SIZE then Exit;
  Move(Buffer[P], Kind, SizeOf(Kind)); Inc(P, SizeOf(Kind)); Move(Buffer[P], Entry.Size, SizeOf(Entry.Size)); Inc(P, SizeOf(Entry.Size));
  Move(Buffer[P], L, SizeOf(L)); Inc(P, SizeOf(L)); if L > BLOCK_SIZE - P then Exit;
  SetLength(S, L); if L > 0 then Move(Buffer[P], S[1], L); Entry.RelativePath := string(S); Entry.IsDirectory := Kind <> 0; Result := True;
end;

end.
