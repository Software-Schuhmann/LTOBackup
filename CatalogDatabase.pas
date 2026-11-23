unit CatalogDatabase;

{$mode objfpc}{$H+}

interface

uses SysUtils, DB, SQLDB, SQLite3Conn, BackupTypes;

function SaveCatalog(const DatabaseFile: string; const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
function LoadCatalog(const DatabaseFile: string; const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
function DeleteCatalog(const DatabaseFile: string; const TapeId: TGUID): Boolean;

implementation

function SaveCatalog(const DatabaseFile: string; const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery; I: Integer; IdText: string;
begin
  Result := False; IdText := GUIDToString(TapeId); if not ForceDirectories(ExtractFilePath(DatabaseFile)) then Exit;
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := DatabaseFile; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open; Tx.StartTransaction;
    Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS tapes (tape_id TEXT PRIMARY KEY, updated_at TEXT)');
    Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS entries (tape_id TEXT NOT NULL, entry_index INTEGER NOT NULL, relative_path TEXT NOT NULL, file_size INTEGER NOT NULL, is_directory INTEGER NOT NULL, set_number INTEGER NOT NULL, PRIMARY KEY (tape_id, entry_index))');
    Conn.ExecuteDirect('CREATE INDEX IF NOT EXISTS idx_entries_path ON entries (tape_id, relative_path)'); Q.Database := Conn;
    Q.SQL.Text := 'DELETE FROM entries WHERE tape_id = :tape_id'; Q.ParamByName('tape_id').AsString := IdText; Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM tapes WHERE tape_id = :tape_id'; Q.ParamByName('tape_id').AsString := IdText; Q.ExecSQL;
    Q.SQL.Text := 'INSERT INTO tapes (tape_id, updated_at) VALUES (:tape_id, :updated_at)'; Q.ParamByName('tape_id').AsString := IdText; Q.ParamByName('updated_at').AsString := DateTimeToStr(Now); Q.ExecSQL;
    Q.SQL.Text := 'INSERT INTO entries (tape_id, entry_index, relative_path, file_size, is_directory, set_number) VALUES (:tape_id, :entry_index, :relative_path, :file_size, :is_directory, :set_number)';
    for I := 0 to High(Entries) do begin
      Q.ParamByName('tape_id').AsString := IdText; Q.ParamByName('entry_index').AsInteger := I; Q.ParamByName('relative_path').AsString := Entries[I].RelativePath;
      Q.ParamByName('file_size').AsString := IntToStr(Entries[I].Size); Q.ParamByName('is_directory').AsInteger := Ord(Entries[I].IsDirectory); Q.ParamByName('set_number').AsInteger := Entries[I].SetNumber; Q.ExecSQL;
    end;
    Tx.Commit; Result := True;
  except
    if Tx.Active then Tx.Rollback;
  end;
  Q.Free; Tx.Free; Conn.Free;
end;

function LoadCatalog(const DatabaseFile: string; const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery; IdText: string; I: Integer;
begin
  Result := False; SetLength(Entries, 0); IdText := GUIDToString(TapeId); if not FileExists(DatabaseFile) then Exit;
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := DatabaseFile; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open; Q.Database := Conn;
    Q.SQL.Text := 'SELECT relative_path, file_size, is_directory, set_number FROM entries WHERE tape_id = :tape_id ORDER BY entry_index'; Q.ParamByName('tape_id').AsString := IdText; Q.Open;
    while not Q.EOF do begin
      I := Length(Entries); SetLength(Entries, I + 1); Entries[I].SourcePath := ''; Entries[I].RelativePath := Q.FieldByName('relative_path').AsString;
      Entries[I].Size := StrToInt64Def(Q.FieldByName('file_size').AsString, 0); Entries[I].IsDirectory := Q.FieldByName('is_directory').AsInteger <> 0; Entries[I].SetNumber := Q.FieldByName('set_number').AsInteger; Q.Next;
    end;
    Q.Close; Result := Length(Entries) > 0;
  except SetLength(Entries, 0); end;
  Q.Free; Tx.Free; Conn.Free;
end;

function DeleteCatalog(const DatabaseFile: string; const TapeId: TGUID): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery; IdText: string;
begin
  Result := False; IdText := GUIDToString(TapeId); if not FileExists(DatabaseFile) then Exit;
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := DatabaseFile; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open; Tx.StartTransaction; Q.Database := Conn;
    Q.SQL.Text := 'DELETE FROM entries WHERE tape_id = :tape_id'; Q.ParamByName('tape_id').AsString := IdText; Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM tapes WHERE tape_id = :tape_id'; Q.ParamByName('tape_id').AsString := IdText; Q.ExecSQL; Tx.Commit; Result := True;
  except if Tx.Active then Tx.Rollback; end;
  Q.Free; Tx.Free; Conn.Free;
end;

end.
