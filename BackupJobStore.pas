unit BackupJobStore;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, DB, SQLDB, SQLite3Conn, BackupTypes;

function ListJobNames(const DatabaseFile: string; Names: TStrings): Boolean;
function SaveJobEntries(const DatabaseFile, JobName: string; const Entries: TArchiveEntryArray): Boolean;
{ Reduziert alte expandierte Auftragsdaten auf Ordnerquellen und Einzeldateien. }
function CompactJobSources(const Entries: TArchiveEntryArray): TArchiveEntryArray;
function RenameJobEntry(const DatabaseFile, OldName, NewName: string): Boolean;
function DeleteJobEntry(const DatabaseFile, JobName: string): Boolean;

implementation

function NormalizeJobPath(const PathName: string): string;
begin

  Result := StringReplace(PathName, '/', '\', [rfReplaceAll]);
  while (Length(Result) > 0) and (Result[Length(Result)] = '\') do
    Delete(Result, Length(Result), 1);
  Result := LowerCase(Result);
end;

function CompactJobSources(const Entries: TArchiveEntryArray): TArchiveEntryArray;
var I, N, MapIndex: Integer; DirMap, RootMap: TStringList; P, Parent: string;
  function HasDirectoryAncestor(const Map: TStringList; const PathName: string): Boolean;
  var Current, Next: string;
  begin
    Current := NormalizeJobPath(PathName);
    repeat
      Next := NormalizeJobPath(ExtractFileDir(Current));
      if SameText(Next, Current) then Exit(False);
      if Map.IndexOfName(Next) >= 0 then Exit(True);
      Current := Next;
    until False;
  end;
begin
  SetLength(Result, 0);
  DirMap := TStringList.Create; RootMap := TStringList.Create;
  try
    DirMap.NameValueSeparator := #1; DirMap.Sorted := True;
    RootMap.NameValueSeparator := #1; RootMap.Sorted := True;
    for I := 0 to High(Entries) do
      if Entries[I].IsDirectory then begin
        P := NormalizeJobPath(Entries[I].SourcePath);
        if DirMap.IndexOfName(P) < 0 then DirMap.Add(P + #1 + IntToStr(I));
      end;
    { Nur die obersten ausgewählten Ordner speichern. }
    for I := 0 to High(Entries) do
      if Entries[I].IsDirectory then begin
        P := NormalizeJobPath(Entries[I].SourcePath);
        MapIndex := DirMap.IndexOfName(P);
        if (MapIndex >= 0) and (StrToIntDef(DirMap.ValueFromIndex[MapIndex], -1) = I) and
           not HasDirectoryAncestor(DirMap, P) then begin
          N := Length(Result); SetLength(Result, N + 1); Result[N] := Entries[I];
          RootMap.Add(P + #1 + IntToStr(N));
        end;
      end;
    for I := 0 to High(Entries) do
      if not Entries[I].IsDirectory then begin
        Parent := NormalizeJobPath(ExtractFileDir(Entries[I].SourcePath));
        if (RootMap.IndexOfName(Parent) < 0) and
           not HasDirectoryAncestor(RootMap, Entries[I].SourcePath) then begin
          N := Length(Result); SetLength(Result, N + 1); Result[N] := Entries[I];
        end;
      end;
  finally DirMap.Free; RootMap.Free; end;
end;

procedure EnsureSchema(Conn: TSQLite3Connection);
begin
  Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS jobs (job_name TEXT PRIMARY KEY, updated_at TEXT)');
  Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS job_entries (job_name TEXT NOT NULL, entry_index INTEGER NOT NULL, source_path TEXT NOT NULL, relative_path TEXT NOT NULL, file_size INTEGER NOT NULL, last_modified INTEGER NOT NULL, is_directory INTEGER NOT NULL, PRIMARY KEY (job_name, entry_index))');
end;

function ListJobNames(const DatabaseFile: string; Names: TStrings): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery;
begin
  Result := False; Names.Clear; if not FileExists(DatabaseFile) then Exit(True);
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := DatabaseFile; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open; Q.Database := Conn;
    Q.SQL.Text := 'SELECT job_name FROM jobs ORDER BY job_name'; Q.Open;
    while not Q.EOF do begin Names.Add(Q.Fields[0].AsString); Q.Next; end; Q.Close; Result := True;
  except Result := False; end;
  Q.Free; Tx.Free; Conn.Free;
end;

{ Schreibt die bereits kompakte Quellenliste eines Auftrags in SQLite. }
function SaveJobEntries(const DatabaseFile, JobName: string; const Entries: TArchiveEntryArray): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery; I: Integer; StoredEntries: TArchiveEntryArray;
begin
  Result := False; if Trim(JobName) = '' then Exit; if not ForceDirectories(ExtractFilePath(DatabaseFile)) then Exit;
  { Entries enthält im aktuellen Modell bereits ausschließlich die
    gespeicherten Quellen. Eine erneute Komprimierung im UI-Speicherpfad
    würde bei alten, expandierten Aufträgen unnötig lange synchron laufen. }
  StoredEntries := Copy(Entries);
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := DatabaseFile; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open; Tx.StartTransaction; EnsureSchema(Conn); Q.Database := Conn;
    Q.SQL.Text := 'DELETE FROM job_entries WHERE job_name = :job_name'; Q.ParamByName('job_name').AsString := JobName; Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM jobs WHERE job_name = :job_name'; Q.ParamByName('job_name').AsString := JobName; Q.ExecSQL;
    Q.SQL.Text := 'INSERT INTO jobs (job_name, updated_at) VALUES (:job_name, :updated_at)'; Q.ParamByName('job_name').AsString := JobName; Q.ParamByName('updated_at').AsString := DateTimeToStr(Now); Q.ExecSQL;
    Q.SQL.Text := 'INSERT INTO job_entries (job_name, entry_index, source_path, relative_path, file_size, last_modified, is_directory) VALUES (:job_name, :entry_index, :source_path, :relative_path, :file_size, :last_modified, :is_directory)';
    for I := 0 to High(StoredEntries) do begin
      Q.ParamByName('job_name').AsString := JobName; Q.ParamByName('entry_index').AsInteger := I; Q.ParamByName('source_path').AsString := StoredEntries[I].SourcePath;
      Q.ParamByName('relative_path').AsString := StoredEntries[I].RelativePath; Q.ParamByName('file_size').AsString := IntToStr(StoredEntries[I].Size); Q.ParamByName('last_modified').AsString := IntToStr(StoredEntries[I].LastModified); Q.ParamByName('is_directory').AsInteger := Ord(StoredEntries[I].IsDirectory); Q.ExecSQL;
    end;
    Tx.Commit; Result := True;
  except if Tx.Active then Tx.Rollback; end;
  Q.Free; Tx.Free; Conn.Free;
end;

function RenameJobEntry(const DatabaseFile, OldName, NewName: string): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery;
begin
  Result := False; if (Trim(OldName) = '') or (Trim(NewName) = '') or SameText(OldName, NewName) then Exit;
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := DatabaseFile; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open; Tx.StartTransaction; EnsureSchema(Conn); Q.Database := Conn;
    Q.SQL.Text := 'UPDATE jobs SET job_name = :new_name WHERE job_name = :old_name'; Q.ParamByName('new_name').AsString := NewName; Q.ParamByName('old_name').AsString := OldName; Q.ExecSQL;
    if Q.RowsAffected = 0 then begin Tx.Rollback; Exit; end;
    Q.SQL.Text := 'UPDATE job_entries SET job_name = :new_name WHERE job_name = :old_name'; Q.ParamByName('new_name').AsString := NewName; Q.ParamByName('old_name').AsString := OldName; Q.ExecSQL; Tx.Commit; Result := True;
  except if Tx.Active then Tx.Rollback; end;
  Q.Free; Tx.Free; Conn.Free;
end;

function DeleteJobEntry(const DatabaseFile, JobName: string): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery;
begin
  Result := False; if not FileExists(DatabaseFile) then Exit(True);
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := DatabaseFile; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open; Tx.StartTransaction; Q.Database := Conn;
    Q.SQL.Text := 'DELETE FROM job_entries WHERE job_name = :job_name'; Q.ParamByName('job_name').AsString := JobName; Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM jobs WHERE job_name = :job_name'; Q.ParamByName('job_name').AsString := JobName; Q.ExecSQL; Tx.Commit; Result := True;
  except if Tx.Active then Tx.Rollback; end;
  Q.Free; Tx.Free; Conn.Free;
end;

end.
