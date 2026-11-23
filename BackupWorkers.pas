unit BackupWorkers;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, SyncObjs, BackupTypes, BackupJobStore;

const
  FILE_ATTRIBUTE_REPARSE_POINT = $00000400;

type
  TJobValidationDoneEvent = procedure(Sender: TObject; const CurrentEntries, Entries: TArchiveEntryArray; Missing: Integer; SourcesChanged: Boolean; const ErrorText: string) of object;
  TJobValidationProgressEvent = procedure(Sender: TObject; Processed, Total: Integer; const CurrentPath: string) of object;

  TJobValidationThread = class(TThread)
  private
    FEntries: TArchiveEntryArray;
    FCurrentEntries: TArchiveEntryArray;
    FValidatedEntries: TArchiveEntryArray;
    FCurrentCount, FValidatedCount: Integer;
    FMissing: Integer;
    FErrorText: string;
    FSourcesChanged: Boolean;
    FOnDone: TJobValidationDoneEvent;
    FOnProgress: TJobValidationProgressEvent;
    FProcessedCount: Integer;
    FSourceTotal: Integer;
    FScannedEntries: Integer;
    FLastPath: string;
    procedure ValidateEntries;
    procedure Finished;
    procedure ReportProgress;
  protected
    procedure Execute; override;
  public
    constructor Create(const Entries: TArchiveEntryArray; OnDone: TJobValidationDoneEvent; OnProgress: TJobValidationProgressEvent);
  end;

  TFilePrefetchThread = class(TThread)
  private
    FSourcePath: string;
    FExpectedSize: Int64;
    FQueue: array[0..3] of TBytes;
    FQueueSizes: array[0..3] of Integer;
    FHead, FTail, FCount: Integer;
    FFinished: Boolean;
    FErrorText: string;
    FLock: TCriticalSection;
    FDataEvent, FSpaceEvent: TEvent;
    procedure SetError(const S: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const SourcePath: string; ExpectedSize: Int64);
    destructor Destroy; override;
    function PopBlock(out Data: TBytes; out ActualSize: Integer): Boolean;
    function ErrorText: string;
  end;

implementation

{ Erstellt den Hintergrundprüfer für gespeicherte Ordner- und Dateiquellen. }
constructor TJobValidationThread.Create(const Entries: TArchiveEntryArray; OnDone: TJobValidationDoneEvent; OnProgress: TJobValidationProgressEvent);
var SourceEntries: TArchiveEntryArray;
begin
  inherited Create(True); FreeOnTerminate := True;
  FEntries := Copy(Entries); FOnDone := OnDone; FOnProgress := OnProgress;
  { Der Fortschritt bezieht sich auf die gespeicherten Quellen, nicht auf
    die später daraus gelesenen Dateien. Sonst kann der Zähler bei einem
    großen Ordner weit über die Anzahl der Quellen hinauslaufen. }
  SourceEntries := CompactJobSources(FEntries);
  FSourceTotal := Length(SourceEntries);
  FProcessedCount := 0; FScannedEntries := 0; FLastPath := ''; FSourcesChanged := False;
  FCurrentCount := 0; FValidatedCount := 0;
  SetLength(FCurrentEntries, Length(FEntries)); SetLength(FValidatedEntries, Length(FEntries));
  Start;
end;

{ Liest Ordner rekursiv ein und liefert die aktuelle Backup-Dateiliste. }
procedure TJobValidationThread.ValidateEntries;
var I, N: Integer; E: TArchiveEntry; SR: TSearchRec;
  OldByPath, OldDirs, Seen: TStringList;
  function SameSourceDefinitions(const A, B: TArchiveEntryArray): Boolean;
  var I, J: Integer; CA: TArchiveEntryArray; Found: Boolean;
  begin
    { B ist während der Prüfung bereits expandiert und kann hunderttausende
      Dateieinträge enthalten. Nicht nochmals die komplette Liste mit
      CompactJobSources durchlaufen; für die Quellenprüfung genügt die Suche
      nach den kompakten Quellwurzeleinträgen. }
    CA := CompactJobSources(A);
    Result := True;
    for I := 0 to High(CA) do begin
      Found := False;
      for J := 0 to High(B) do
        if (CA[I].IsDirectory = B[J].IsDirectory) and
           SameText(CA[I].SourcePath, B[J].SourcePath) and
           SameText(CA[I].RelativePath, B[J].RelativePath) then begin
          Found := True;
          Break;
        end;
      if not Found then begin
        Result := False; Exit;
      end;
    end;
  end;
  function SameStoredEntries(const A, B: TArchiveEntryArray): Boolean;
  var I: Integer;
  begin
    Result := Length(A) = Length(B);
    if not Result then Exit;
    for I := 0 to High(A) do begin
      if (A[I].IsDirectory <> B[I].IsDirectory) or
         not SameText(A[I].SourcePath, B[I].SourcePath) or
         not SameText(A[I].RelativePath, B[I].RelativePath) or
         (A[I].Size <> B[I].Size) or (A[I].LastModified <> B[I].LastModified) then begin
        Result := False; Exit;
      end;
    end;
  end;
  function EntryKey(const S: string): string;
  begin
    Result := LowerCase(ExcludeTrailingPathDelimiter(S));
  end;
  function HasDirectoryAncestor(const SourcePath: string): Boolean;
  var Current, Next: string;
  begin
    Current := EntryKey(SourcePath);
    repeat
      Next := EntryKey(ExtractFileDir(Current));
      if SameText(Next, Current) then Exit(False);
      if OldDirs.IndexOf(Next) >= 0 then Exit(True);
      Current := Next;
    until False;
  end;
  function IsReparsePoint(const PathName: string): Boolean;
  var LinkSR: TSearchRec;
  begin
    Result := (FindFirst(PathName, faAnyFile, LinkSR) = 0);
    if Result then begin
      Result := (LinkSR.Attr and FILE_ATTRIBUTE_REPARSE_POINT) <> 0;
      SysUtils.FindClose(LinkSR);
    end;
  end;
  procedure AddEntry(const NewEntry: TArchiveEntry);
  var Key: string; Selected: Boolean; NewCapacity: Integer;
  begin
    if Terminated then Exit;
    Inc(FScannedEntries);
    FLastPath := NewEntry.RelativePath;
    if (FScannedEntries mod 256 = 0) and Assigned(FOnProgress) then
      Synchronize(@ReportProgress);
    Key := EntryKey(NewEntry.SourcePath);
    Seen.Add(Key);
    if FCurrentCount >= Length(FCurrentEntries) then begin
      NewCapacity := Length(FCurrentEntries) * 2;
      if NewCapacity < 256 then NewCapacity := 256;
      SetLength(FCurrentEntries, NewCapacity);
    end;
    N := FCurrentCount; Inc(FCurrentCount); FCurrentEntries[N] := NewEntry;
    { Bei Ordnerquellen werden immer alle aktuell vorhandenen Dateien
      gesichert. }
    Selected := True;
    if Selected then begin
      if FValidatedCount >= Length(FValidatedEntries) then begin
        NewCapacity := Length(FValidatedEntries) * 2;
        if NewCapacity < 256 then NewCapacity := 256;
        SetLength(FValidatedEntries, NewCapacity);
      end;
      N := FValidatedCount; Inc(FValidatedCount); FValidatedEntries[N] := NewEntry;
    end;
  end;
  procedure ScanDirectory(const FolderName, RelativeRoot: string);
  var ChildName, ChildRelative: string; D: TArchiveEntry; LocalSR: TSearchRec;
  begin
    if Terminated then Exit;
    FLastPath := RelativeRoot;
    if Assigned(FOnProgress) then Synchronize(@ReportProgress);
    D.SourcePath := FolderName; D.RelativePath := RelativeRoot; D.IsDirectory := True;
    D.Size := 0; D.LastModified := FileAge(FolderName); D.SetNumber := 0; AddEntry(D);
    if FindFirst(IncludeTrailingPathDelimiter(FolderName) + '*', faAnyFile, LocalSR) <> 0 then Exit;
    try
      repeat
        if Terminated then Break;
        if (LocalSR.Name = '.') or (LocalSR.Name = '..') then Continue;
        ChildName := IncludeTrailingPathDelimiter(FolderName) + LocalSR.Name;
        ChildRelative := IncludeTrailingPathDelimiter(RelativeRoot) + LocalSR.Name;
        if (LocalSR.Attr and faDirectory) <> 0 then begin
          if (LocalSR.Attr and FILE_ATTRIBUTE_REPARSE_POINT) = 0 then
            ScanDirectory(ChildName, ChildRelative);
        end else begin
          D.SourcePath := ChildName; D.RelativePath := ChildRelative; D.IsDirectory := False;
          D.Size := LocalSR.Size; D.LastModified := FileAge(ChildName); D.SetNumber := 0; AddEntry(D);
        end;
      until FindNext(LocalSR) <> 0;
    finally SysUtils.FindClose(LocalSR); end;
  end;
  procedure BeginSource(const SourcePath: string);
  begin
    FLastPath := SourcePath;
    if Assigned(FOnProgress) then Synchronize(@ReportProgress);
  end;
  procedure CompleteSource;
  begin
    Inc(FProcessedCount);
    if Assigned(FOnProgress) then Synchronize(@ReportProgress);
  end;
begin
  FMissing := 0; OldByPath := TStringList.Create; OldDirs := TStringList.Create; Seen := TStringList.Create;
  try
    OldByPath.NameValueSeparator := #1; OldByPath.Sorted := False; OldDirs.Sorted := False; Seen.Sorted := False;
    for I := 0 to High(FEntries) do begin
      OldByPath.Add(EntryKey(FEntries[I].SourcePath) + #1 + IntToStr(I));
      if FEntries[I].IsDirectory then OldDirs.Add(EntryKey(FEntries[I].SourcePath));
    end;
    OldByPath.Sort; OldDirs.Sort;
    if Assigned(FOnProgress) then Synchronize(@ReportProgress);
    for I := 0 to High(FEntries) do begin
      if Terminated then Exit;
      E := FEntries[I];
      if E.IsDirectory then begin
        if not HasDirectoryAncestor(E.SourcePath) then begin
          BeginSource(E.SourcePath);
          if DirectoryExists(E.SourcePath) and not IsReparsePoint(E.SourcePath) then
            ScanDirectory(E.SourcePath, E.RelativePath);
          CompleteSource;
        end;
      end else if not HasDirectoryAncestor(E.SourcePath) then begin
        BeginSource(E.SourcePath);
        if FindFirst(E.SourcePath, faAnyFile, SR) = 0 then begin
          try
            E.Size := SR.Size; E.LastModified := FileAge(E.SourcePath); E.SetNumber := 0; AddEntry(E);
          finally SysUtils.FindClose(SR); end;
        end;
        CompleteSource;
      end;
    end;
    Seen.Sort;
    for I := 0 to OldByPath.Count - 1 do
      if Seen.IndexOf(OldByPath.Names[I]) < 0 then Inc(FMissing);
    SetLength(FCurrentEntries, FCurrentCount); SetLength(FValidatedEntries, FValidatedCount);
    FLastPath := 'Auswertung der Prüfergebnisse ...';
    if Assigned(FOnProgress) then Synchronize(@ReportProgress);
    { Auch eine alte expandierte Datenbank muss einmalig auf ihre kompakten
      Ordner-/Dateiquellen umgestellt werden. }
    FSourcesChanged := not SameStoredEntries(FEntries, CompactJobSources(FEntries)) or
      not SameSourceDefinitions(FEntries, FCurrentEntries);
  finally OldByPath.Free; OldDirs.Free; Seen.Free; end;
end;

procedure TJobValidationThread.ReportProgress;
begin
  if Assigned(FOnProgress) then FOnProgress(Self, FProcessedCount, FSourceTotal, FLastPath);
end;

procedure TJobValidationThread.Finished;
begin
  if Assigned(FOnDone) then FOnDone(Self, FCurrentEntries, FValidatedEntries, FMissing, FSourcesChanged, FErrorText);
end;

procedure TJobValidationThread.Execute;
begin
  try ValidateEntries except on E: Exception do FErrorText := E.Message; end;
  Synchronize(@Finished);
end;

constructor TFilePrefetchThread.Create(const SourcePath: string; ExpectedSize: Int64);
begin
  inherited Create(True); FreeOnTerminate := False; FSourcePath := SourcePath; FExpectedSize := ExpectedSize;
  FLock := SyncObjs.TCriticalSection.Create; FDataEvent := SyncObjs.TEvent.Create(nil, True, False, ''); FSpaceEvent := SyncObjs.TEvent.Create(nil, True, True, ''); Start;
end;

destructor TFilePrefetchThread.Destroy;
begin
  Terminate; FSpaceEvent.SetEvent; FDataEvent.SetEvent; WaitFor; FDataEvent.Free; FSpaceEvent.Free; FLock.Free; inherited Destroy;
end;

procedure TFilePrefetchThread.SetError(const S: string);
begin
  FLock.Acquire; try FErrorText := S; FFinished := True; finally FLock.Release; end; FDataEvent.SetEvent;
end;

procedure TFilePrefetchThread.Execute;
var FS: TFileStream; Buf: TBytes; N, Slot: Integer;
begin
  try
    FS := TFileStream.Create(WindowsPathForIO(FSourcePath), fmOpenRead or fmShareDenyWrite);
    try
      if FS.Size <> FExpectedSize then begin SetError('Dateigröße hat sich während der Vorbereitung geändert.'); Exit; end;
      while (FS.Position < FS.Size) and not Terminated do begin
        SetLength(Buf, BLOCK_SIZE); FillChar(Buf[0], BLOCK_SIZE, 0); N := FS.Read(Buf[0], BLOCK_SIZE);
        if N <= 0 then begin SetError('Datei konnte nicht vollständig gelesen werden.'); Exit; end;
        repeat
          FLock.Acquire;
          try
            if FCount < Length(FQueue) then begin
              Slot := FTail; FQueue[Slot] := Buf; FQueueSizes[Slot] := N; FTail := (FTail + 1) mod Length(FQueue); Inc(FCount);
              if FCount >= Length(FQueue) then FSpaceEvent.ResetEvent; FDataEvent.SetEvent; Break;
            end;
          finally FLock.Release; end;
          FSpaceEvent.WaitFor(100);
        until Terminated;
      end;
      FLock.Acquire; try FFinished := True; finally FLock.Release; end; FDataEvent.SetEvent;
    finally FS.Free; end;
  except on E: Exception do SetError(E.Message); end;
end;

function TFilePrefetchThread.PopBlock(out Data: TBytes; out ActualSize: Integer): Boolean;
var Slot: Integer;
begin
  Result := False; Data := nil; ActualSize := 0;
  while True do begin
    FLock.Acquire;
    try
      if FCount > 0 then begin
        Slot := FHead; Data := FQueue[Slot]; FQueue[Slot] := nil; ActualSize := FQueueSizes[Slot]; FHead := (FHead + 1) mod Length(FQueue); Dec(FCount); FSpaceEvent.SetEvent;
        if FCount = 0 then FDataEvent.ResetEvent; Exit(True);
      end;
      if FFinished then Exit(False);
    finally FLock.Release; end;
    FDataEvent.WaitFor(100);
  end;
end;

function TFilePrefetchThread.ErrorText: string;
begin
  FLock.Acquire; try Result := FErrorText; finally FLock.Release; end;
end;

end.
