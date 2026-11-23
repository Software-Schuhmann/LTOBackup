unit BackupTypes;

{$mode objfpc}{$H+}

interface

function WindowsPathForIO(const PathName: string): string;

const
  TAPE_DEVICE = '\\.\TAPE0';
  BLOCK_SIZE = 65536;
  FORMAT_MAGIC = 'LTOBACK1';
  FORMAT_VERSION = 2;
  LEGACY_FORMAT_VERSION = 1;

type
  TArchiveEntry = record
    SourcePath: string;
    RelativePath: string;
    IsDirectory: Boolean;
    Size: Int64;
    LastModified: Int64;
    SetNumber: Integer;
  end;
  TArchiveEntryArray = array of TArchiveEntry;

implementation

function WindowsPathForIO(const PathName: string): string;
begin
  Result := PathName;
  if Length(Result) < 240 then Exit;
  if Copy(Result, 1, 4) = '\\?\' then Exit;
  if Copy(Result, 1, 2) = '\\' then
    Result := '\\?\UNC\' + Copy(Result, 3, MaxInt)
  else if (Length(Result) >= 2) and (Result[2] = ':') then
    Result := '\\?\' + Result;
end;

end.
