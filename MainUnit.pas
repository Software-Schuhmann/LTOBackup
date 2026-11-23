{ <description>

  Copyright (C) 2026 Ronald Schuhmann info@softwareschuhmann.de

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 51 Franklin Street - Fifth Floor,
  Boston, MA 02110-1335, USA.
}


unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, Windows, ShellApi, Forms, Controls, StdCtrls, ComCtrls, Dialogs,
  CheckLst, Menus,
  ExtCtrls, ImgList, Graphics, Math, DB, SQLDB, SQLite3Conn,
  BackupTypes, TapeFormat, BackupWorkers, CatalogDatabase, BackupJobStore, TapeDevice;

type
  TSPDevInfoData = record
    cbSize: DWORD;
    ClassGuid: TGUID;
    DevInst: DWORD;
    Reserved: NativeUInt;
  end;

function SetupDiGetClassDevsA(ClassGuid: PGUID; Enumerator: PAnsiChar; hwndParent: HWND; Flags: DWORD): THandle; stdcall; external 'setupapi.dll' name 'SetupDiGetClassDevsA';
function SetupDiEnumDeviceInfo(DeviceInfoSet: THandle; MemberIndex: DWORD; var DeviceInfoData: TSPDevInfoData): BOOL; stdcall; external 'setupapi.dll' name 'SetupDiEnumDeviceInfo';
function SetupDiGetDeviceRegistryPropertyA(DeviceInfoSet: THandle; var DeviceInfoData: TSPDevInfoData; Property_: DWORD; var PropertyRegDataType: DWORD; PropertyBuffer: Pointer; PropertyBufferSize: DWORD; var RequiredSize: DWORD): BOOL; stdcall; external 'setupapi.dll' name 'SetupDiGetDeviceRegistryPropertyA';
function SetupDiDestroyDeviceInfoList(DeviceInfoSet: THandle): BOOL; stdcall; external 'setupapi.dll' name 'SetupDiDestroyDeviceInfoList';

const
  DIGCF_PRESENT = $00000002;
  SPDRP_DEVICEDESC = $00000000;
  SPDRP_FRIENDLYNAME = $0000000C;

type
  { TMainForm }

  TMainForm = class(TForm)
  published
    AddFilesButton: TButton;
    AddFolderButton: TButton;
    ClearSourcesButton: TButton;
    DeleteJobButton: TButton;
    EjectButton: TButton;
    EraseButton: TButton;
    JobNameCombo: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    LoadJobButton: TButton;
    Panel1: TPanel;
    Panel2: TPanel;
    RenameJobButton: TButton;
    SaveJobButton: TButton;
    TopPanel: TPanel;
    ReadCatalogButton: TButton;
    RefreshCatalogButton: TButton;
    RestoreButton: TButton;
    TapeDeviceLabel: TLabel;
    TapeDeviceEdit: TComboBox;
    SourceTitle: TLabel;
    CatalogTitle: TLabel;
    TapeInfoButton: TButton;
    TensionButton: TButton;
    SourcesSectionLabel: TLabel;
    TapeSectionLabel: TLabel;
    BackupSectionLabel: TLabel;
    JobsSectionLabel: TLabel;
    OptionsSectionLabel: TLabel;
    SourcesActionPanel: TPanel;
    TapeActionPanel: TPanel;
    BackupActionPanel: TPanel;
    JobsActionPanel: TPanel;
    MainMenu1: TMainMenu;
    FileMenuItem: TMenuItem;
    OptionsMenuItem: TMenuItem;
    ExitMenuItem: TMenuItem;
    SourcePanel: TPanel;
    CatalogPanel: TPanel;
    BottomPanel: TPanel;
    ProgressLabel: TLabel;
    ProgressBar: TProgressBar;
    SourceTree: TTreeView;
    CatalogTree: TTreeView;
    LogMemo: TMemo;
    WriteBackupButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure AddFilesClick(Sender: TObject);
    procedure AddFolderClick(Sender: TObject);
    procedure ClearSourcesClick(Sender: TObject);
    procedure JobsActionPanelClick(Sender: TObject);
    procedure Label1Click(Sender: TObject);
    procedure TapeActionPanelClick(Sender: TObject);
    procedure TapeDeviceEditChange(Sender: TObject);
    procedure WriteBackupClick(Sender: TObject);
    procedure ReadCatalogClick(Sender: TObject);
    procedure RefreshCatalogClick(Sender: TObject);
    procedure RestoreClick(Sender: TObject);
    procedure EjectClick(Sender: TObject);
    procedure EraseClick(Sender: TObject);
    procedure SaveSettingsClick(Sender: TObject);
    procedure TapeInfoClick(Sender: TObject);
    procedure TensionClick(Sender: TObject);
    procedure SaveJobClick(Sender: TObject);
    procedure LoadJobClick(Sender: TObject);
    procedure JobNameComboChange(Sender: TObject);
    procedure RenameJobClick(Sender: TObject);
    procedure DeleteJobClick(Sender: TObject);
    procedure SourceTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure CatalogTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OptionsMenuClick(Sender: TObject);
    procedure ExitMenuClick(Sender: TObject);
  private
    FSources, FJobSources, FCatalog: TArchiveEntryArray;
    FSetCounts: array of Cardinal;
    FDevice: string;
    FTapeId: TGUID;
    FTapeIdValid: Boolean;
    FBackupTotalBytes, FBackupBytesWritten: Int64;
    FBackupStartTick: QWord;
    FTapePositionSupported: Boolean;
    FTreeImages: TImageList;
    FSelectionImages: TImageList;
    FFolderImageIndex, FFileImageIndex: Integer;
    FJobValidationThread: TJobValidationThread;
    FPendingJobName: string;
    FPendingCommandLineJob: Boolean;
    FJobSourcesValidated: Boolean;
    FJobNeedsExpansion: Boolean;
    FBackupWaitingForSourceScan: Boolean;
    FOperationBusy: Boolean;
    FUseCompression: Boolean;
    FAppendBackup: Boolean;
    FShutdownAfterBackup: Boolean;
    FVerifyWrittenData: Boolean;
    FCommandLineRun: Boolean;
    FForceCatalogRefresh: Boolean;
    FCatalogLoaded: Boolean;
    function SettingsFileName: string;
    procedure EnumerateTapeDevices;
    procedure InitializeTreeImages;
    procedure InitializeSelectionImages;
    procedure UpdateTapeDescription;
    function GetTapeFriendlyName(const DeviceName: string): string;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure AddFile(const FileName, RelativeName: string; KnownSize: Int64 = -1);
    procedure AddTreeEntry(Tree: TTreeView; const RelativePath: string; IsDirectory: Boolean; Size: Int64; CatalogIndex: Integer; NodeMap: TStringList = nil);
    procedure RebuildSourceTree;
    procedure DeleteSourceEntry(Index: Integer);
    procedure Log(const S: string);
    procedure SetBusy(Value: Boolean);
    function OpenTape(AccessMode: DWORD): THandle;
    function EnsureTapeReady(TapeHandle: THandle; const OperationName: string): DWORD;
    function ConfigureTape(TapeHandle: THandle): Boolean;
    function GetTapeMedia(TapeHandle: THandle; out Params: TAPE_GET_MEDIA_PARAMETERS): Boolean;
    function ScanTapeUsedBytes(TapeHandle: THandle; out UsedBytes: Int64): Boolean;
    function ConfirmCapacity(TapeHandle: THandle; RequiredBytes: Int64): Boolean;
    procedure LogTapeParameters(TapeHandle: THandle);
    function WriteBlock(TapeHandle: THandle; const Data; Count: Integer): Boolean;
    function ReadBlock(TapeHandle: THandle; var Data): Boolean;
    function CatalogFileName(const TapeId: TGUID): string;
    function SaveLocalCatalog(const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
    function LoadLocalCatalog(const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
    function CatalogDatabaseFileName: string;
    function JobDatabaseFileName: string;
    procedure LoadJobNames;
    function SaveJob(const JobName: string; AllowEmpty: Boolean = False): Boolean;
    function LoadJob(const JobName: string): Boolean;
    procedure ApplyJobValidation(Sender: TObject; const CurrentEntries, Entries: TArchiveEntryArray; Missing: Integer; SourcesChanged: Boolean; const ErrorText: string);
    procedure ApplyJobValidationProgress(Sender: TObject; Processed, Total: Integer; const CurrentPath: string);
    function RenameJob(const OldName, NewName: string): Boolean;
    function DeleteJob(const JobName: string): Boolean;
    function SaveLocalCatalogSQLite(const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
    function LoadLocalCatalogSQLite(const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
    function DeleteLocalCatalog(const TapeId: TGUID): Boolean;
    function SaveLegacyLocalCatalog(const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
    function LoadLegacyLocalCatalog(const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
    function ReadTapeIdentity(TapeHandle: THandle; out TapeId: TGUID): Boolean;
    procedure AddSourcesToCatalog(var Entries: TArchiveEntryArray; SetNumber: Integer; Count: Integer = -1);
    function WriteTapeEntry(TapeHandle: THandle; const Entry: TArchiveEntry; Prefetch: TFilePrefetchThread = nil): Boolean;
    function CaptureTapePosition(TapeHandle: THandle; out Partition, OffsetLow, OffsetHigh: DWORD): Boolean;
    function TrimTapeAt(TapeHandle: THandle; Partition, OffsetLow, OffsetHigh: DWORD): Boolean;
    function ReadTapeEntry(TapeHandle: THandle; out Entry: TArchiveEntry): Boolean;
    function SkipTapeSetData(TapeHandle: THandle; Count: Cardinal): Boolean;
    function VerifyWrittenBackup(TapeHandle: THandle; const ExpectedEntries: TArchiveEntryArray; const TapeId: TGUID; CompareContent: Boolean; SetNumber: Cardinal; out VerifiedBytes: Int64): Boolean;
    procedure FreeArray(var Entries: TArchiveEntryArray);
    function EnsureDirectory(const DirName: string): Boolean;
    function NormalizeArchivePath(const Path: string): string;
    function FormatDuration(Seconds: Int64): string;
    procedure UpdateBackupProgress(const CurrentPath: string);
    function SelectRestoreEntries(out SelectedPaths, SelectedDirs: TStringList; out SelectedSet: Integer): Boolean;
    procedure UpdateActionState;
    procedure StartCommandLineJob(Data: PtrInt);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ Initialisiert Oberfläche, Laufwerk, Einstellungen und Auftragsliste. }
procedure TMainForm.FormCreate(Sender: TObject);
begin
  FOperationBusy := False; FJobValidationThread := nil; FPendingCommandLineJob := False; FJobSourcesValidated := False; FJobNeedsExpansion := False; FBackupWaitingForSourceScan := False; FCatalogLoaded := False;
  FDevice := TAPE_DEVICE;
  InitializeTreeImages;
  InitializeSelectionImages;
  ProgressLabel.ShowAccelChar := False;
  EnumerateTapeDevices;
  LoadSettings;
  LoadJobNames;
  UpdateTapeDescription;
  CatalogTitle.Caption := 'Bandkatalog auf ' + FDevice;
  Log('Bereit. Bandlaufwerk: ' + FDevice);
  UpdateActionState;
  if ParamCount > 0 then Application.QueueAsyncCall(@StartCommandLineJob, 0);
end;

procedure TMainForm.StartCommandLineJob(Data: PtrInt);
var JobName: string;
begin
  JobName := Trim(ParamStr(1));
  FPendingCommandLineJob := True;
  if (JobName = '') or not LoadJob(JobName) then begin
    FPendingCommandLineJob := False;
    ShowMessage('Der Sicherungsauftrag "' + JobName + '" wurde nicht gefunden oder konnte nicht geladen werden.' + LineEnding +
      'Das Programm wird normal geöffnet.');
    Exit;
  end;
  JobNameCombo.Text := JobName;
  WriteBackupClick(Self);
end;

procedure TMainForm.OptionsMenuClick(Sender: TObject);
var Dlg: TForm; CompressionBox, AppendBox, ShutdownBox, VerifyBox: TCheckBox; SaveButton, CancelButton: TButton;
begin
  Dlg := TForm.CreateNew(Self);
  try
    Dlg.Caption := 'Optionen'; Dlg.Width := 450; Dlg.Height := 280; Dlg.Position := poScreenCenter;
    CompressionBox := TCheckBox.Create(Dlg); CompressionBox.Parent := Dlg; CompressionBox.SetBounds(20, 20, 360, 24); CompressionBox.Caption := 'Hardware-Kompression verwenden'; CompressionBox.Checked := FUseCompression;
    AppendBox := TCheckBox.Create(Dlg); AppendBox.Parent := Dlg; AppendBox.SetBounds(20, 55, 380, 24); AppendBox.Caption := 'An vorhandenes Backup anhängen'; AppendBox.Checked := FAppendBackup;
    ShutdownBox := TCheckBox.Create(Dlg); ShutdownBox.Parent := Dlg; ShutdownBox.SetBounds(20, 90, 390, 24); ShutdownBox.Caption := 'Nach erfolgreichem Backup PC herunterfahren'; ShutdownBox.Checked := FShutdownAfterBackup;
    VerifyBox := TCheckBox.Create(Dlg); VerifyBox.Parent := Dlg; VerifyBox.SetBounds(20, 125, 390, 24); VerifyBox.Caption := 'Dateiinhalte nach dem Schreiben byteweise prüfen'; VerifyBox.Checked := FVerifyWrittenData;
    SaveButton := TButton.Create(Dlg); SaveButton.Parent := Dlg; SaveButton.SetBounds(195, 170, 115, 30); SaveButton.Caption := 'Speichern'; SaveButton.ModalResult := mrOk;
    CancelButton := TButton.Create(Dlg); CancelButton.Parent := Dlg; CancelButton.SetBounds(315, 170, 85, 28); CancelButton.Caption := 'Abbrechen'; CancelButton.ModalResult := mrCancel;
    if Dlg.ShowModal = mrOk then begin
      FUseCompression := CompressionBox.Checked; FAppendBackup := AppendBox.Checked;
      FShutdownAfterBackup := ShutdownBox.Checked; FVerifyWrittenData := VerifyBox.Checked; SaveSettings;
    end;
  finally Dlg.Free; end;
end;

procedure TMainForm.ExitMenuClick(Sender: TObject);
begin
  Close;
end;

function TMainForm.GetTapeFriendlyName(const DeviceName: string): string;
var ClassGuid: TGUID; DeviceInfoSet: THandle; DeviceInfo: TSPDevInfoData;
  I, TapeIndex, CurrentIndex, P: Integer; RegType, RequiredSize: DWORD;
  Buffer: array[0..1023] of AnsiChar;
begin
  Result := '';
  P := Pos('TAPE', UpperCase(DeviceName));
  if (P = 0) or not TryStrToInt(Copy(DeviceName, P + 4, MaxInt), TapeIndex) then Exit;
  ClassGuid := StringToGUID('{6D807884-7D21-11CF-801C-08002BE10318}');
  DeviceInfoSet := SetupDiGetClassDevsA(@ClassGuid, nil, 0, DIGCF_PRESENT);
  if DeviceInfoSet = INVALID_HANDLE_VALUE then Exit;
  try
    CurrentIndex := 0;
    for I := 0 to 255 do begin
      FillChar(DeviceInfo, SizeOf(DeviceInfo), 0);
      DeviceInfo.cbSize := SizeOf(DeviceInfo);
      if not SetupDiEnumDeviceInfo(DeviceInfoSet, I, DeviceInfo) then Break;
      if CurrentIndex = TapeIndex then begin
        FillChar(Buffer, SizeOf(Buffer), 0);
        RegType := 0; RequiredSize := 0;
        if SetupDiGetDeviceRegistryPropertyA(DeviceInfoSet, DeviceInfo, SPDRP_FRIENDLYNAME,
          RegType, @Buffer[0], SizeOf(Buffer), RequiredSize) or
          SetupDiGetDeviceRegistryPropertyA(DeviceInfoSet, DeviceInfo, SPDRP_DEVICEDESC,
          RegType, @Buffer[0], SizeOf(Buffer), RequiredSize) then
          Result := string(PAnsiChar(@Buffer[0]));
        Break;
      end;
      Inc(CurrentIndex);
    end;
  finally
    SetupDiDestroyDeviceInfoList(DeviceInfoSet);
  end;
end;

procedure TMainForm.UpdateTapeDescription;
var FriendlyName: string;
begin
  FriendlyName := GetTapeFriendlyName(FDevice);
  if FriendlyName = '' then FriendlyName := 'unbekanntes Bandlaufwerk';
  Label2.Caption := 'Laufwerk: ' + FriendlyName;
end;

procedure TMainForm.InitializeTreeImages;
var Info: TSHFileInfo; ShellIcon: TIcon;
begin
  FTreeImages := TImageList.Create(Self);
  FTreeImages.Width := GetSystemMetrics(SM_CXSMICON);
  FTreeImages.Height := GetSystemMetrics(SM_CYSMICON);
  SourceTree.Images := FTreeImages;
  CatalogTree.Images := FTreeImages;
  FFolderImageIndex := -1;
  FFileImageIndex := -1;

  FillChar(Info, SizeOf(Info), 0);
  if SHGetFileInfo('Folder', FILE_ATTRIBUTE_DIRECTORY, Info, SizeOf(Info),
    SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES) <> 0 then begin
    ShellIcon := TIcon.Create;
    try
      ShellIcon.Handle := Info.hIcon;
      FFolderImageIndex := FTreeImages.AddIcon(ShellIcon);
    finally
      ShellIcon.Free;
    end;
  end;

  FillChar(Info, SizeOf(Info), 0);
  if SHGetFileInfo('.txt', FILE_ATTRIBUTE_NORMAL, Info, SizeOf(Info),
    SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES) <> 0 then begin
    ShellIcon := TIcon.Create;
    try
      ShellIcon.Handle := Info.hIcon;
      FFileImageIndex := FTreeImages.AddIcon(ShellIcon);
    finally
      ShellIcon.Free;
    end;
  end;
end;

procedure TMainForm.InitializeSelectionImages;
var B: TBitmap; R: TRect;
begin
  FSelectionImages := TImageList.Create(Self); FSelectionImages.Width := 16; FSelectionImages.Height := 16;
  B := TBitmap.Create;
  try
    B.SetSize(16, 16); B.Canvas.Brush.Color := clWindow; R.Left := 0; R.Top := 0; R.Right := 16; R.Bottom := 16; B.Canvas.FillRect(R);
    R.Left := 1; R.Top := 1; R.Right := 15; R.Bottom := 15; DrawFrameControl(B.Canvas.Handle, R, DFC_BUTTON, DFCS_BUTTONCHECK); FSelectionImages.Add(B, nil);
    B.Canvas.Brush.Color := clWindow; R.Left := 0; R.Top := 0; R.Right := 16; R.Bottom := 16; B.Canvas.FillRect(R);
    R.Left := 1; R.Top := 1; R.Right := 15; R.Bottom := 15;
    DrawFrameControl(B.Canvas.Handle, R, DFC_BUTTON, DFCS_BUTTONCHECK or DFCS_CHECKED); FSelectionImages.Add(B, nil);
  finally B.Free; end;
  CatalogTree.StateImages := FSelectionImages;
end;

procedure TMainForm.EnumerateTapeDevices;
var I: Integer; DeviceName: string; H: THandle;
begin
  TapeDeviceEdit.Items.BeginUpdate;
  try
    TapeDeviceEdit.Items.Clear;
    for I := 0 to 31 do begin
      DeviceName := '\\.\TAPE' + IntToStr(I);
      H := CreateFile(PChar(DeviceName), GENERIC_READ, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
      if H <> INVALID_HANDLE_VALUE then begin
        TapeDeviceEdit.Items.Add(DeviceName);
        CloseHandle(H);
      end;
    end;
    if TapeDeviceEdit.Items.Count = 0 then
      Log('Keine erreichbaren Bandlaufwerke gefunden.');
  finally
    TapeDeviceEdit.Items.EndUpdate;
  end;
end;

function TMainForm.SettingsFileName: string;
begin
  Result := ChangeFileExt(Application.ExeName, '.ini');
end;

procedure TMainForm.LoadSettings;
var Ini: TIniFile;
begin
  Ini := TIniFile.Create(SettingsFileName);
  try
    FDevice := Ini.ReadString('Tape', 'Device', TAPE_DEVICE);
    if TapeDeviceEdit.Items.IndexOf(FDevice) < 0 then
      TapeDeviceEdit.Items.Add(FDevice);
    TapeDeviceEdit.ItemIndex := TapeDeviceEdit.Items.IndexOf(FDevice);
    FUseCompression := Ini.ReadBool('Tape', 'HardwareCompression', True);
    FAppendBackup := Ini.ReadBool('Tape', 'AppendBackup', False);
    FShutdownAfterBackup := Ini.ReadBool('Backup', 'ShutdownAfterSuccess', False);
    FVerifyWrittenData := Ini.ReadBool('Backup', 'VerifyWrittenData', False);
  finally Ini.Free; end;
end;

procedure TMainForm.SaveSettings;
var Ini: TIniFile;
begin
  FDevice := Trim(TapeDeviceEdit.Text);
  if FDevice = '' then FDevice := TAPE_DEVICE;
  TapeDeviceEdit.Text := FDevice;
  Ini := TIniFile.Create(SettingsFileName);
  try
    Ini.WriteString('Tape', 'Device', FDevice);
    Ini.WriteBool('Tape', 'HardwareCompression', FUseCompression);
    Ini.WriteBool('Tape', 'AppendBackup', FAppendBackup);
    Ini.WriteBool('Backup', 'ShutdownAfterSuccess', FShutdownAfterBackup);
    Ini.WriteBool('Backup', 'VerifyWrittenData', FVerifyWrittenData);
    Ini.UpdateFile;
  finally Ini.Free; end;
  Log('Einstellungen gespeichert: ' + SettingsFileName);
end;

procedure TMainForm.SaveSettingsClick(Sender: TObject);
begin SaveSettings; end;

procedure TMainForm.Log(const S: string);
begin LogMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + S); LogMemo.SelStart := Length(LogMemo.Text); end;

{ Sperrt bzw. gibt die Bedienoberfläche während langer Laufwerksvorgänge frei. }
procedure TMainForm.SetBusy(Value: Boolean);
begin
  FOperationBusy := Value;
  if Value then Screen.Cursor := crHourGlass else Screen.Cursor := crDefault;
  UpdateActionState; Enabled := not Value; Application.ProcessMessages;
end;

procedure TMainForm.UpdateActionState;
var Available: Boolean;
begin
  Available := not FOperationBusy;
  AddFilesButton.Enabled := Available; AddFolderButton.Enabled := Available;
  ClearSourcesButton.Enabled := Available and (Length(FSources) > 0);
  WriteBackupButton.Enabled := Available and (Length(FSources) > 0);
  ReadCatalogButton.Enabled := Available; RefreshCatalogButton.Enabled := Available;
  RestoreButton.Enabled := Available and FCatalogLoaded and (Length(FCatalog) > 0);
  EjectButton.Enabled := Available; EraseButton.Enabled := Available;
  TapeInfoButton.Enabled := Available; TensionButton.Enabled := Available;
  TapeDeviceEdit.Enabled := Available;
  SaveJobButton.Enabled := Available and (Length(FSources) > 0);
  LoadJobButton.Enabled := Available and (JobNameCombo.Items.Count > 0);
  RenameJobButton.Enabled := Available and (JobNameCombo.ItemIndex >= 0);
  DeleteJobButton.Enabled := Available and (JobNameCombo.ItemIndex >= 0);
end;

function TMainForm.FormatDuration(Seconds: Int64): string;
var H, M, S: Int64;
begin
  if Seconds < 0 then Seconds := 0;
  H := Seconds div 3600;
  M := (Seconds mod 3600) div 60;
  S := Seconds mod 60;
  Result := Format('%d:%0.2d:%0.2d', [H, M, S]);
end;

procedure TMainForm.UpdateBackupProgress(const CurrentPath: string);
var Percent, RemainingSeconds: Double; ElapsedSeconds: Int64;
begin
  if FBackupTotalBytes > 0 then begin
    Percent := (FBackupBytesWritten * 100.0) / FBackupTotalBytes;
    if Percent > 100 then Percent := 100;
    ProgressBar.Position := Round(Percent * 10);
  end else begin
    Percent := 100;
    ProgressBar.Position := 1000;
  end;
  ElapsedSeconds := (GetTickCount64 - FBackupStartTick) div 1000;
  if (FBackupBytesWritten > 0) and (FBackupTotalBytes > FBackupBytesWritten) then
    RemainingSeconds := (ElapsedSeconds * (FBackupTotalBytes - FBackupBytesWritten)) / FBackupBytesWritten
  else
    RemainingSeconds := 0;
  if (FBackupBytesWritten > 0) and (FBackupBytesWritten < FBackupTotalBytes) then
    ProgressLabel.Caption := 'Sichere: ' + CurrentPath + '    ' + FormatFloat('0.0', Percent) +
      ' %    Restzeit (Schätzung): ' + FormatDuration(Round(RemainingSeconds))
  else if FBackupTotalBytes = 0 then
    ProgressLabel.Caption := 'Sichere: ' + CurrentPath + '    (keine Dateidaten)'
  else
    ProgressLabel.Caption := 'Sichere: ' + CurrentPath + '    ' + FormatFloat('0.0', Percent) + ' %';
  Application.ProcessMessages;
end;

{ Fügt eine einzelne Datei als gespeicherte Quelle und Backup-Eintrag hinzu. }
procedure TMainForm.AddFile(const FileName, RelativeName: string; KnownSize: Int64);
var I: Integer; FS: TFileStream; FileSize: Int64; E: TArchiveEntry;
begin
  FJobSourcesValidated := False;
  for I := 0 to High(FJobSources) do if SameText(FJobSources[I].SourcePath, FileName) then Exit;
  if KnownSize >= 0 then
    FileSize := KnownSize
  else begin
    FS := TFileStream.Create(WindowsPathForIO(FileName), fmOpenRead or fmShareDenyWrite);
    try
      FileSize := FS.Size;
    finally
      FS.Free;
    end;
  end;
  E.SourcePath := FileName; E.RelativePath := RelativeName; E.IsDirectory := False;
  E.Size := FileSize; E.LastModified := FileAge(FileName); E.SetNumber := 0;
  SetLength(FJobSources, Length(FJobSources) + 1); FJobSources[High(FJobSources)] := E;
  SetLength(FSources, Length(FSources) + 1); FSources[High(FSources)] := E;
end;

procedure TMainForm.AddFilesClick(Sender: TObject);
var D: TOpenDialog; I: Integer;
begin
  D := TOpenDialog.Create(Self); try D.Options := [ofAllowMultiSelect, ofFileMustExist];
    if D.Execute then begin
      SourceTree.BeginUpdate;
      try
        for I := 0 to D.Files.Count - 1 do AddFile(D.Files[I], ExtractFileName(D.Files[I]));
      finally
        SourceTree.EndUpdate;
      end;
      RebuildSourceTree;
      UpdateActionState;
    end;
  finally D.Free; end;
end;

{ Fügt nur den ausgewählten Ordner hinzu; dessen Inhalt wird erst beim Backup gelesen. }
procedure TMainForm.AddFolderClick(Sender: TObject);
var D, R: string; I: Integer;
begin
  if SelectDirectory('Ordner für Backup auswählen', '', D) then begin
    R := ExtractFileName(ExcludeTrailingPathDelimiter(D));
    for I := 0 to High(FJobSources) do
      if SameText(FJobSources[I].SourcePath, D) then Exit;
    I := Length(FSources); SetLength(FSources, I + 1);
    FSources[I].SourcePath := D; FSources[I].RelativePath := R; FSources[I].IsDirectory := True;
    { Beim Hinzufügen einer Ordnerquelle keinerlei Netzwerk-Metadaten lesen.
      Der Ordnerinhalt wird erst beim Start des Backups geprüft. }
    FSources[I].Size := 0; FSources[I].LastModified := 0; FSources[I].SetNumber := 0;
    SetLength(FJobSources, Length(FJobSources) + 1);
    FJobSources[High(FJobSources)] := FSources[I];
    FJobSourcesValidated := False; FJobNeedsExpansion := True;
    { Alle gespeicherten Quellen neu anzeigen; dabei wird kein Ordnerinhalt
      gelesen. So bleiben bereits hinzugefügte Ordner sichtbar. }
    RebuildSourceTree;
    Log('Ordner als Quelle hinzugefügt: ' + D + '. Inhalt wird erst beim Backup eingelesen.');
    UpdateActionState;
  end;
end;

procedure TMainForm.AddTreeEntry(Tree: TTreeView; const RelativePath: string; IsDirectory: Boolean; Size: Int64; CatalogIndex: Integer; NodeMap: TStringList);
var Parts: TStringList; I, MapIndex: Integer; ParentNode, Node: TTreeNode; PartName, DisplayText, NodePath: string;
begin
  Parts := TStringList.Create;
  try
    ExtractStrings(['\', '/'], [], PChar(RelativePath), Parts);
    ParentNode := nil;
    NodePath := '';
    for I := 0 to Parts.Count - 1 do begin
      PartName := Parts[I];
      if NodePath = '' then NodePath := PartName else NodePath := NodePath + '\' + PartName;
      Node := nil;
      if Assigned(NodeMap) then begin
        MapIndex := NodeMap.IndexOf(NodePath);
        if MapIndex >= 0 then Node := TTreeNode(NodeMap.Objects[MapIndex]);
      end else begin
        if ParentNode = nil then Node := Tree.Items.GetFirstNode else Node := ParentNode.GetFirstChild;
        while Node <> nil do begin
          { Datei-Knoten tragen zur Anzeige die Größe hinter dem Namen.}
          if SameText(Node.Text, PartName) or
            SameText(Copy(Node.Text, 1, Length(PartName) + 3), PartName + '  (') then Break;
          Node := Node.GetNextSibling;
        end;
      end;
      if Node = nil then begin
        if ParentNode = nil then Node := Tree.Items.Add(nil, PartName) else Node := Tree.Items.AddChild(ParentNode, PartName);
        if Assigned(NodeMap) then NodeMap.AddObject(NodePath, Node);
        Node.ImageIndex := FFolderImageIndex;
        Node.SelectedIndex := FFolderImageIndex;
        if Tree = CatalogTree then Node.StateIndex := 0;
      end;
      ParentNode := Node;
    end;
    if ParentNode <> nil then begin
      if IsDirectory then begin
        ParentNode.ImageIndex := FFolderImageIndex;
        ParentNode.SelectedIndex := FFolderImageIndex;
      end else begin
        ParentNode.ImageIndex := FFileImageIndex;
        ParentNode.SelectedIndex := FFileImageIndex;
      end;
      if not IsDirectory then begin
        DisplayText := ParentNode.Text + '  (' + IntToStr(Size) + ' Bytes)';
        ParentNode.Text := DisplayText;
      end;
      if CatalogIndex >= 0 then
        if Tree = SourceTree then
          ParentNode.Data := Pointer(PtrInt(-(CatalogIndex + 1)))
        else
          ParentNode.Data := Pointer(PtrInt(CatalogIndex));
    end;
  finally Parts.Free; end;
end;

procedure TMainForm.ClearSourcesClick(Sender: TObject);
begin
  FJobSourcesValidated := False;
  FJobNeedsExpansion := False;
  FBackupWaitingForSourceScan := False;
  FreeArray(FSources); FreeArray(FJobSources);
  SourceTree.Items.Clear; UpdateActionState;
end;

{ Baut die Quellenanzeige ausschließlich aus den gespeicherten Quellen neu auf. }
procedure TMainForm.RebuildSourceTree;
var I, J, ActualIndex: Integer; NodeMap: TStringList; DisplayEntries: TArchiveEntryArray;
begin
  { Der Quellbaum zeigt ausschließlich die gespeicherten Quellen.}
  DisplayEntries := Copy(FJobSources);
  NodeMap := TStringList.Create;
  NodeMap.Sorted := True; NodeMap.CaseSensitive := False; NodeMap.Duplicates := dupIgnore;
  SourceTree.Items.BeginUpdate;
  try
    SourceTree.Items.Clear;
    for I := 0 to High(DisplayEntries) do begin
      ActualIndex := -1;
      for J := 0 to High(FSources) do
        if SameText(FSources[J].SourcePath, DisplayEntries[I].SourcePath) then begin ActualIndex := J; Break; end;
      AddTreeEntry(SourceTree, DisplayEntries[I].RelativePath, DisplayEntries[I].IsDirectory,
        DisplayEntries[I].Size, ActualIndex, NodeMap);
    end;
  finally
    SourceTree.Items.EndUpdate;
    NodeMap.Free;
  end;
end;

procedure TMainForm.DeleteSourceEntry(Index: Integer);
var I: Integer; JobName, RemovedPath: string;
begin
  FJobSourcesValidated := False;
  if (Index < 0) or (Index > High(FSources)) then Exit;
  RemovedPath := FSources[Index].SourcePath;
  for I := Index to High(FSources) - 1 do FSources[I] := FSources[I + 1];
  SetLength(FSources, Length(FSources) - 1);
  for I := 0 to High(FJobSources) do
    if SameText(FJobSources[I].SourcePath, RemovedPath) then begin
      FJobSources[I] := FJobSources[High(FJobSources)];
      SetLength(FJobSources, Length(FJobSources) - 1);
      Break;
    end;
  RebuildSourceTree;
  UpdateActionState;

  JobName := Trim(JobNameCombo.Text);
  if (JobName <> '') and (JobNameCombo.Items.IndexOf(JobName) >= 0) then begin
    if not SaveJob(JobName, True) then
      ShowMessage('Die Datei wurde aus der Liste entfernt, aber der geänderte Auftrag konnte nicht gespeichert werden.');
  end;
end;

procedure TMainForm.JobsActionPanelClick(Sender: TObject);
begin

end;

procedure TMainForm.Label1Click(Sender: TObject);
begin

end;

procedure TMainForm.TapeActionPanelClick(Sender: TObject);
begin

end;

procedure TMainForm.TapeDeviceEditChange(Sender: TObject);
begin
  FDevice := Trim(TapeDeviceEdit.Text);
  UpdateTapeDescription;
  if Assigned(CatalogTitle) then
    CatalogTitle.Caption := 'Bandkatalog auf ' + FDevice;
end;

procedure TMainForm.FreeArray(var Entries: TArchiveEntryArray);
begin SetLength(Entries, 0); end;

function TMainForm.OpenTape(AccessMode: DWORD): THandle;
begin
  Result := OpenTapeDevice(FDevice, AccessMode);
  if Result = INVALID_HANDLE_VALUE then Log('Bandlaufwerk ' + FDevice + ' konnte nicht geöffnet werden. Fehler: ' + IntToStr(GetLastError));
end;

function TMainForm.EnsureTapeReady(TapeHandle: THandle; const OperationName: string): DWORD;
const
  MaxAttempts = 8;
  RetryDelayMs = 1000;
var
  Attempt: Integer;
  Status, LoadStatus: DWORD;
begin
  Status := ERROR_NOT_READY;
  for Attempt := 1 to MaxAttempts do begin
    Status := GetTapeStatus(TapeHandle);
    if Status = NO_ERROR then begin
      if Attempt > 1 then Log('Bandstatus: bereit.');
      Exit(Status);
    end;

    if (Status = ERROR_NO_MEDIA_IN_DRIVE) or (Status = ERROR_MEDIA_CHANGED) or
       (Status = ERROR_NOT_READY) then begin
      if Attempt = 1 then
        Log(OperationName + ': Band ist noch nicht bereit. Lade Band ...')
      else
        Log(OperationName + ': Band wird noch geladen (Versuch ' + IntToStr(Attempt) + ' von ' + IntToStr(MaxAttempts) + ') ...');
      LoadStatus := PrepareTape(TapeHandle, TAPE_LOAD, False);
      if LoadStatus <> NO_ERROR then
        Status := LoadStatus
      else
        Status := GetTapeStatus(TapeHandle);
    end;

    if Status = NO_ERROR then begin
      Log('Bandstatus: bereit.');
      Exit(Status);
    end;
    if Attempt < MaxAttempts then Sleep(RetryDelayMs);
  end;
  Result := Status;
end;

function TMainForm.ConfigureTape(TapeHandle: THandle): Boolean;
var Params: TAPE_SET_MEDIA_PARAMETERS; DriveParams: TAPE_SET_DRIVE_PARAMETERS; CurrentParams: TAPE_GET_DRIVE_PARAMETERS; Size, Status: DWORD;
begin
  FillChar(Params, SizeOf(Params), 0);
  Params.BlockSize := BLOCK_SIZE;
  Status := SetTapeParameters(TapeHandle, SET_TAPE_MEDIA_INFORMATION, @Params);
  Result := Status = NO_ERROR;
  if not Result then
    Log('Hinweis: 64-KB-Blockgröße konnte nicht gesetzt werden. Windows-Fehler: ' + IntToStr(Status));
  FillChar(DriveParams, SizeOf(DriveParams), 0);
  DriveParams.ECC := True;
  DriveParams.Compression := FUseCompression;
  DriveParams.DataPadding := False;
  DriveParams.ReportSetmarks := False;
  Status := SetTapeParameters(TapeHandle, SET_TAPE_DRIVE_INFORMATION, @DriveParams);
  if Status <> NO_ERROR then begin
    FillChar(CurrentParams, SizeOf(CurrentParams), 0); Size := SizeOf(CurrentParams);
    if GetTapeParameters(TapeHandle, GET_TAPE_DRIVE_INFORMATION, Size, @CurrentParams) = NO_ERROR then begin
      if CurrentParams.Compression then
        Log('Hardware-Kompression ist bereits aktiviert. Das Laufwerk erlaubt keine Änderung per Software.')
      else
        Log('Hinweis: Hardware-Kompression konnte nicht eingestellt werden. Windows-Fehler: ' + IntToStr(Status));
    end else
      Log('Hinweis: Hardware-Kompression konnte nicht eingestellt werden. Windows-Fehler: ' + IntToStr(Status));
  end
  else if FUseCompression then
    Log('Hardware-Kompression: EIN')
  else
    Log('Hardware-Kompression: AUS');
end;

function TMainForm.GetTapeMedia(TapeHandle: THandle; out Params: TAPE_GET_MEDIA_PARAMETERS): Boolean;
begin
  Result := GetTapeMediaInfo(TapeHandle, Params);
  if not Result then Log('Bandkapazität konnte nicht ermittelt werden. Windows-Fehler: ' + IntToStr(GetLastError));
end;

function TMainForm.ScanTapeUsedBytes(TapeHandle: THandle; out UsedBytes: Int64): Boolean;
var Status, Partition, OffsetLow, OffsetHigh: DWORD;
  LogicalBlock: QWord;
begin
  Result := False; UsedBytes := 0;
  Status := SetTapePosition(TapeHandle, TAPE_SPACE_END_OF_DATA, 0, 0, 0, False);
  if Status <> NO_ERROR then begin
    Log('Schnelle Bandpositionsabfrage nicht unterstützt. Windows-Fehler: ' + IntToStr(Status));
    Exit;
  end;
  Partition := 0; OffsetLow := 0; OffsetHigh := 0;
  if GetTapePosition(TapeHandle, TAPE_LOGICAL_BLOCK, Partition, OffsetLow, @OffsetHigh) <> NO_ERROR then begin
    Log('Logische Bandposition konnte nicht gelesen werden.');
    Exit;
  end;
  LogicalBlock := QWord(OffsetLow) or (QWord(OffsetHigh) shl 32);
  UsedBytes := Int64(LogicalBlock * BLOCK_SIZE);
  Result := True;
end;

function TMainForm.ConfirmCapacity(TapeHandle: THandle; RequiredBytes: Int64): Boolean;
var Params: TAPE_GET_MEDIA_PARAMETERS; Remaining: Int64; Msg: string;
begin
  Result := True;
  if not GetTapeMedia(TapeHandle, Params) then Exit;
  Remaining := Params.Remaining.QuadPart;
  if RequiredBytes <= Remaining then Exit;
  Msg := 'Die ausgewählten Daten benötigen ca. ' + FormatFloat('0.00', RequiredBytes / 1073741824.0) + ' GB.' + LineEnding +
    'Nativ sind auf dem Band nur noch ca. ' + FormatFloat('0.00', Remaining / 1073741824.0) + ' GB frei.' + LineEnding + LineEnding +
    'Hardware-Kompression ist aktiviert und kann helfen, ist aber nicht garantiert.' + LineEnding +
    'Trotzdem mit dem Schreiben fortfahren?';
  Result := MessageDlg('Warnung: Bandkapazität', Msg, mtWarning, [mbYes, mbNo], 0) = mrYes;
end;

procedure TMainForm.LogTapeParameters(TapeHandle: THandle);
var Params: TAPE_GET_MEDIA_PARAMETERS;
begin
  if GetTapeMedia(TapeHandle, Params) then
    Log('Bandparameter: Kapazität=' + IntToStr(Params.Capacity.QuadPart) + ' Bytes (' + FormatFloat('0.00', Params.Capacity.QuadPart / 1073741824.0) + ' GB), ' +
      'Treiber-Restwert=' + IntToStr(Params.Remaining.QuadPart) + ' Bytes (' + FormatFloat('0.00', Params.Remaining.QuadPart / 1073741824.0) + ' GB), ' +
      'Blockgröße=' + IntToStr(Params.BlockSize) + ' Bytes, Partitionen=' + IntToStr(Params.PartitionCount) + ', Schreibschutz=' + BoolToStr(Params.WriteProtected, True))
end;

procedure TMainForm.TapeInfoClick(Sender: TObject);
var H: THandle; Status: DWORD; Params: TAPE_GET_MEDIA_PARAMETERS; UsedBytes, FreeBytes: Int64;
begin
  H := OpenTape(GENERIC_READ or GENERIC_WRITE); if H = INVALID_HANDLE_VALUE then Exit;
  SetBusy(True);
  try
    ProgressLabel.Caption := 'Bitte warten: Bandbelegung wird ermittelt ...';
    Log('Bitte warten: Bandbelegung wird ermittelt ...');
    Application.ProcessMessages;
    Status := EnsureTapeReady(H, 'Bandinfo');
    if Status <> NO_ERROR then begin
      Log('Bandstatus: Windows-Fehler ' + IntToStr(Status));
      if Status = ERROR_NO_MEDIA_IN_DRIVE then
        Log('Bitte das Band vollständig einlegen und am Laufwerk laden.');
      if Status = ERROR_MEDIA_CHANGED then
        Log('Das Band ist noch nicht vollständig geladen oder der Laufwerksstatus ist noch nicht bereit.');
      Exit;
    end;
    LogTapeParameters(H);
    if GetTapeMedia(H, Params) and ScanTapeUsedBytes(H, UsedBytes) then begin
      FreeBytes := Params.Capacity.QuadPart - UsedBytes;
      if FreeBytes < 0 then FreeBytes := 0;
      Log('Ermittelte Belegung dieses Backup-Formats: ' + IntToStr(UsedBytes) +
        ' Bytes (' + FormatFloat('0.00', UsedBytes / 1073741824.0) + ' GB), frei: ' +
        IntToStr(FreeBytes) + ' Bytes (' + FormatFloat('0.00', FreeBytes / 1073741824.0) + ' GB).');
    end else if GetTapeMedia(H, Params) and (Params.Remaining.QuadPart >= 0) and
      (Params.Remaining.QuadPart <= Params.Capacity.QuadPart) then begin
      UsedBytes := Params.Capacity.QuadPart - Params.Remaining.QuadPart;
      Log('Bandposition nicht auslesbar; verwende den nach der Positionierung aktualisierten Treiberwert. ' +
        'Belegt: ' + IntToStr(UsedBytes) + ' Bytes (' + FormatFloat('0.00', UsedBytes / 1073741824.0) +
        ' GB), frei: ' + IntToStr(Params.Remaining.QuadPart) + ' Bytes (' +
        FormatFloat('0.00', Params.Remaining.QuadPart / 1073741824.0) + ' GB).');
    end else
      Log('Bandbelegung konnte weder aus der Bandposition noch aus dem Treiberwert ermittelt werden.');
  finally CloseHandle(H); SetBusy(False); end;
end;

procedure TMainForm.TensionClick(Sender: TObject);
var H: THandle; Status: DWORD;
begin
  if MessageDlg('Das Band wird vollständig gespannt. Dieser Vorgang kann mehrere Minuten dauern. Fortfahren?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  H := OpenTape(GENERIC_READ or GENERIC_WRITE); if H = INVALID_HANDLE_VALUE then Exit;
  SetBusy(True);
  try
    Log('Band wird gespannt. Bitte warten...');
    Status := EnsureTapeReady(H, 'Band spannen');
    if Status <> NO_ERROR then begin
      Log('Band ist nicht bereit. Windows-Fehler: ' + IntToStr(Status));
      Exit;
    end;
    Status := PrepareTape(H, TAPE_TENSION, False);
    if Status = NO_ERROR then Log('Band wurde erfolgreich gespannt.')
    else if Status = ERROR_INVALID_PARAMETER then
      Log('Der Tandberg TS400 bzw. sein Windows-Treiber unterstützt den TAPE_TENSION-Befehl nicht. Das ist kein Bandfehler; das Laufwerk regelt die Bandspannung automatisch.')
    else Log('Band konnte nicht gespannt werden. Windows-Fehler: ' + IntToStr(Status));
  finally CloseHandle(H); SetBusy(False); end;
end;

function TMainForm.WriteBlock(TapeHandle: THandle; const Data; Count: Integer): Boolean;
begin
  Result := WriteTapeBlock(TapeHandle, Data, Count);
  if not Result then
    Log('WriteFile fehlgeschlagen. Windows-Fehler: ' + IntToStr(GetLastError) + ', Blockgröße: ' + IntToStr(BLOCK_SIZE));
end;

function TMainForm.ReadBlock(TapeHandle: THandle; var Data): Boolean;
begin
  Result := ReadTapeBlock(TapeHandle, Data);
  if not Result and (GetLastError <> ERROR_FILEMARK_DETECTED) then
    Log('ReadFile fehlgeschlagen. Windows-Fehler: ' + IntToStr(GetLastError));
end;

function TMainForm.CatalogFileName(const TapeId: TGUID): string;
var IdText: string;
begin
  IdText := GUIDToString(TapeId);
  IdText := StringReplace(IdText, '{', '', [rfReplaceAll]);
  IdText := StringReplace(IdText, '}', '', [rfReplaceAll]);
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
    'Catalogs' + PathDelim + IdText + '.catalog.ini';
end;

function TMainForm.SaveLegacyLocalCatalog(const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
var Ini: TIniFile; I: Integer; Section: string; DirName: string;
begin
  Result := False;
  DirName := ExtractFilePath(CatalogFileName(TapeId));
  if not ForceDirectories(DirName) then Exit;
  Ini := TIniFile.Create(CatalogFileName(TapeId));
  try
    Ini.WriteInteger('Catalog', 'Version', 1);
    Ini.WriteInteger('Catalog', 'Count', Length(Entries));
    for I := 0 to High(Entries) do begin
      Section := 'Entry' + IntToStr(I);
      Ini.WriteString(Section, 'RelativePath', Entries[I].RelativePath);
      Ini.WriteString(Section, 'Size', IntToStr(Entries[I].Size));
      Ini.WriteBool(Section, 'Directory', Entries[I].IsDirectory);
      Ini.WriteInteger(Section, 'SetNumber', Entries[I].SetNumber);
    end;
    Ini.UpdateFile;
    Result := True;
  finally
    Ini.Free;
  end;
end;

function TMainForm.LoadLegacyLocalCatalog(const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
var Ini: TIniFile; I, Count: Integer; Section: string;
begin
  Result := False; SetLength(Entries, 0);
  if not FileExists(CatalogFileName(TapeId)) then Exit;
  Ini := TIniFile.Create(CatalogFileName(TapeId));
  try
    Count := Ini.ReadInteger('Catalog', 'Count', -1);
    if Count < 0 then Exit;
    SetLength(Entries, Count);
    for I := 0 to Count - 1 do begin
      Section := 'Entry' + IntToStr(I);
      Entries[I].SourcePath := '';
      Entries[I].RelativePath := Ini.ReadString(Section, 'RelativePath', '');
      Entries[I].Size := StrToInt64Def(Ini.ReadString(Section, 'Size', '0'), 0);
      Entries[I].IsDirectory := Ini.ReadBool(Section, 'Directory', False);
      Entries[I].SetNumber := Ini.ReadInteger(Section, 'SetNumber', 0);
    end;
    Result := True;
  finally
    Ini.Free;
  end;
end;

function TMainForm.CatalogDatabaseFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
    'Catalogs' + PathDelim + 'catalog.sqlite3';
end;

function TMainForm.JobDatabaseFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
    'BackupJobs' + PathDelim + 'backup_jobs.sqlite3';
end;

procedure TMainForm.LoadJobNames;
var Names: TStringList;
begin
  Names := TStringList.Create;
  try
    if not ListJobNames(JobDatabaseFileName, Names) then Exit;
    JobNameCombo.Items.BeginUpdate;
    try JobNameCombo.Items.Assign(Names); finally JobNameCombo.Items.EndUpdate; end;
  finally Names.Free; end;
end;

{ Speichert nur Ordnerquellen und ausdrücklich ausgewählte Einzeldateien. }
function TMainForm.SaveJob(const JobName: string; AllowEmpty: Boolean): Boolean;
begin
  Result := False;
  if Trim(JobName) = '' then Exit;
  if (Length(FJobSources) = 0) and not AllowEmpty then begin ShowMessage('Bitte zuerst Dateien oder Ordner auswählen.'); Exit; end;
  Result := SaveJobEntries(JobDatabaseFileName, JobName, FJobSources);
  if Result then begin
    LoadJobNames; JobNameCombo.Text := JobName;
    Log('Sicherungsauftrag gespeichert: ' + JobName + ' (' + IntToStr(Length(FJobSources)) + ' Quellen).');
  end else Log('Sicherungsauftrag konnte nicht gespeichert werden.');
end;

{ Lädt einen Auftrag ohne Ordner zu durchsuchen; die Prüfung erfolgt beim Backup. }
function TMainForm.LoadJob(const JobName: string): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery; E: TArchiveEntry;
  Entries: TArchiveEntryArray; TotalEntries: Integer;
begin
  Result := False;
  if (Trim(JobName) = '') or FOperationBusy then Exit;
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := JobDatabaseFileName; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open;
    Q.Database := Conn;
    Q.SQL.Text := 'SELECT COUNT(*) FROM job_entries WHERE job_name = :job_name';
    Q.ParamByName('job_name').AsString := JobName; Q.Open; TotalEntries := Q.Fields[0].AsInteger; Q.Close;
    SetLength(Entries, 0);
    Q.SQL.Text := 'SELECT source_path, relative_path, file_size, last_modified, is_directory FROM job_entries WHERE job_name = :job_name ORDER BY entry_index';
    Q.ParamByName('job_name').AsString := JobName; Q.Open;
    while not Q.EOF do begin
      E.SourcePath := Q.FieldByName('source_path').AsString; E.RelativePath := Q.FieldByName('relative_path').AsString;
      E.Size := StrToInt64Def(Q.FieldByName('file_size').AsString, 0); E.LastModified := StrToInt64Def(Q.FieldByName('last_modified').AsString, 0);
      E.IsDirectory := Q.FieldByName('is_directory').AsInteger <> 0; E.SetNumber := 0;
      SetLength(Entries, Length(Entries) + 1); Entries[High(Entries)] := E; Q.Next;
    end;
    Q.Close; Result := True;
  except
    on E: Exception do Log('Sicherungsauftrag konnte nicht geladen werden: ' + E.Message);
  end;
  Q.Free; Tx.Free; Conn.Free;
  if not Result then Exit;
  FPendingJobName := JobName;
  FJobSources := Copy(Entries);
  FSources := Copy(Entries);
  FJobNeedsExpansion := True;
  FJobSourcesValidated := False;
  RebuildSourceTree;
  ProgressBar.Max := Max(1, TotalEntries); ProgressBar.Position := 0;
  ProgressLabel.Caption := 'Sicherungsauftrag geladen; Ordner werden erst beim Backup eingelesen.';
  Log('Sicherungsauftrag geladen: Quellen=' + IntToStr(Length(Entries)) + '. Ordnerprüfung erfolgt beim Backup.');
  UpdateActionState;
end;

procedure TMainForm.ApplyJobValidationProgress(Sender: TObject; Processed, Total: Integer; const CurrentPath: string);
begin
  ProgressBar.Max := Max(1, Total); ProgressBar.Position := Min(Processed, ProgressBar.Max);
  ProgressLabel.Caption := 'Prüfe Auftrag ' + IntToStr(Processed) + ' von ' + IntToStr(Total) + ': ' + CurrentPath;
end;

procedure TMainForm.ApplyJobValidation(Sender: TObject; const CurrentEntries, Entries: TArchiveEntryArray; Missing: Integer; SourcesChanged: Boolean; const ErrorText: string);
var I: Integer;
begin
  FJobValidationThread := nil;
  if ErrorText <> '' then begin
    Log('Sicherungsauftrag konnte nicht geprüft werden: ' + ErrorText);
    ProgressLabel.Caption := 'Prüfung des Sicherungsauftrags fehlgeschlagen.';
    SetBusy(False); FPendingCommandLineJob := False; Exit;
  end;
  FSources := Copy(CurrentEntries);
  if SourcesChanged then begin
    if not SaveJob(FPendingJobName, True) then
      Log('WARNUNG: Der aktualisierte Sicherungsauftrag konnte nicht gespeichert werden.')
    else
      Log('Sicherungsauftrag aktualisiert: Quellen haben sich geändert.');
  end else
    Log('Sicherungsauftrag unverändert; Datenbank wird nicht neu gespeichert.');
  FSources := Copy(Entries);
  FJobSourcesValidated := True;
  if FBackupWaitingForSourceScan then begin
    FBackupWaitingForSourceScan := False;
    FJobNeedsExpansion := False;
    RebuildSourceTree;
    ProgressBar.Position := ProgressBar.Max;
    ProgressLabel.Caption := 'Ordnerprüfung abgeschlossen; Backup wird gestartet ...';
    SetBusy(False);
    if Length(FSources) = 0 then begin
      FPendingCommandLineJob := False;
      ShowMessage('Der Auftrag "' + FPendingJobName + '" enthält keine lesbaren Dateien.');
      Exit;
    end;
    if FPendingCommandLineJob then begin
      FPendingCommandLineJob := False; FCommandLineRun := True;
      try WriteBackupClick(Self); finally FCommandLineRun := False; end;
    end else
      WriteBackupClick(Self);
    Exit;
  end;
  SourceTree.Items.Clear; SourceTree.BeginUpdate;
  try
    for I := 0 to High(FSources) do
      AddTreeEntry(SourceTree, FSources[I].RelativePath, FSources[I].IsDirectory, FSources[I].Size, I);
  finally SourceTree.EndUpdate; end;
  ProgressBar.Position := ProgressBar.Max;
  ProgressLabel.Caption := 'Auftrag geladen: ' + IntToStr(Length(FSources)) + ' neue/geänderte Einträge';
  Log('Sicherungsauftrag geladen: ' + FPendingJobName + '. Neue/geänderte Einträge: ' + IntToStr(Length(FSources)) +
    ', fehlende Quellen: ' + IntToStr(Missing) + '.');
  SetBusy(False);
  if FPendingCommandLineJob then begin
    FPendingCommandLineJob := False;
    if Length(FSources) = 0 then begin
      ShowMessage('Der Auftrag "' + FPendingJobName + '" enthält keine neuen oder geänderten Dateien.');
      Exit;
    end;
    FCommandLineRun := True;
    try WriteBackupClick(Self); finally FCommandLineRun := False; end;
  end;
end;

procedure TMainForm.SaveJobClick(Sender: TObject);
var JobName: string;
begin
  JobName := Trim(JobNameCombo.Text);
  if InputQuery('Sicherungsauftrag speichern', 'Name des Auftrags:', JobName) then SaveJob(JobName);
end;

procedure TMainForm.LoadJobClick(Sender: TObject);
begin
  if JobNameCombo.ItemIndex < 0 then begin ShowMessage('Bitte zuerst einen Sicherungsauftrag auswählen.'); Exit; end;
  LoadJob(JobNameCombo.Text);
end;

procedure TMainForm.JobNameComboChange(Sender: TObject);
begin
  UpdateActionState;
end;

function TMainForm.RenameJob(const OldName, NewName: string): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery;
begin
  Result := RenameJobEntry(JobDatabaseFileName, OldName, NewName);
  if Result then begin LoadJobNames; JobNameCombo.Text := NewName; Log('Sicherungsauftrag umbenannt: ' + OldName + ' -> ' + NewName); end;
  Exit;
  Result := False;
  if (Trim(OldName) = '') or (Trim(NewName) = '') or SameText(OldName, NewName) then Exit;
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := JobDatabaseFileName; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open;
    Tx.StartTransaction; Q.Database := Conn;
    Q.SQL.Text := 'UPDATE jobs SET job_name = :new_name WHERE job_name = :old_name';
    Q.ParamByName('new_name').AsString := NewName; Q.ParamByName('old_name').AsString := OldName; Q.ExecSQL;
    if Q.RowsAffected = 0 then begin Tx.Rollback; Exit; end;
    Q.SQL.Text := 'UPDATE job_entries SET job_name = :new_name WHERE job_name = :old_name';
    Q.ParamByName('new_name').AsString := NewName; Q.ParamByName('old_name').AsString := OldName; Q.ExecSQL;
    Tx.Commit; Result := True; LoadJobNames; JobNameCombo.Text := NewName;
    Log('Sicherungsauftrag umbenannt: ' + OldName + ' -> ' + NewName);
  except
    on E: Exception do begin if Tx.Active then Tx.Rollback; Log('Auftrag konnte nicht umbenannt werden: ' + E.Message); end;
  end;
  Q.Free; Tx.Free; Conn.Free;
end;

function TMainForm.DeleteJob(const JobName: string): Boolean;
var Conn: TSQLite3Connection; Tx: TSQLTransaction; Q: TSQLQuery;
begin
  Result := DeleteJobEntry(JobDatabaseFileName, JobName);
  if Result then begin LoadJobNames; JobNameCombo.Text := ''; Log('Sicherungsauftrag gelöscht: ' + JobName); end;
  Exit;
  Result := False;
  if Trim(JobName) = '' then Exit;
  Conn := TSQLite3Connection.Create(nil); Tx := TSQLTransaction.Create(nil); Q := TSQLQuery.Create(nil);
  try
    Conn.DatabaseName := JobDatabaseFileName; Conn.Transaction := Tx; Tx.Database := Conn; Conn.Open;
    Tx.StartTransaction; Q.Database := Conn;
    Q.SQL.Text := 'DELETE FROM job_entries WHERE job_name = :job_name'; Q.ParamByName('job_name').AsString := JobName; Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM jobs WHERE job_name = :job_name'; Q.ParamByName('job_name').AsString := JobName; Q.ExecSQL;
    Tx.Commit; Result := True; LoadJobNames; JobNameCombo.Text := '';
    Log('Sicherungsauftrag gelöscht: ' + JobName);
  except
    on E: Exception do begin if Tx.Active then Tx.Rollback; Log('Auftrag konnte nicht gelöscht werden: ' + E.Message); end;
  end;
  Q.Free; Tx.Free; Conn.Free;
end;

procedure TMainForm.RenameJobClick(Sender: TObject);
var OldName, NewName: string;
begin
  if JobNameCombo.ItemIndex < 0 then begin ShowMessage('Bitte zuerst einen Sicherungsauftrag auswählen.'); Exit; end;
  OldName := JobNameCombo.Text; NewName := OldName;
  if InputQuery('Sicherungsauftrag umbenennen', 'Neuer Name:', NewName) then
    if not RenameJob(OldName, Trim(NewName)) then ShowMessage('Der Auftrag konnte nicht umbenannt werden.');
end;

procedure TMainForm.DeleteJobClick(Sender: TObject);
var JobName: string;
begin
  if JobNameCombo.ItemIndex < 0 then begin ShowMessage('Bitte zuerst einen Sicherungsauftrag auswählen.'); Exit; end;
  JobName := JobNameCombo.Text;
  if MessageDlg('Sicherungsauftrag "' + JobName + '" wirklich löschen?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    if not DeleteJob(JobName) then ShowMessage('Der Auftrag konnte nicht gelöscht werden.');
end;

function TMainForm.SaveLocalCatalogSQLite(const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
begin
  Result := SaveCatalog(CatalogDatabaseFileName, TapeId, Entries);
end;

function TMainForm.LoadLocalCatalogSQLite(const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
begin
  Result := LoadCatalog(CatalogDatabaseFileName, TapeId, Entries);
end;

function TMainForm.SaveLocalCatalog(const TapeId: TGUID; const Entries: TArchiveEntryArray): Boolean;
begin
  Result := SaveLocalCatalogSQLite(TapeId, Entries);
end;

function TMainForm.LoadLocalCatalog(const TapeId: TGUID; out Entries: TArchiveEntryArray): Boolean;
begin
  Result := LoadLocalCatalogSQLite(TapeId, Entries);
  if not Result then Result := LoadLegacyLocalCatalog(TapeId, Entries);
end;

function TMainForm.DeleteLocalCatalog(const TapeId: TGUID): Boolean;
begin
  Result := DeleteCatalog(CatalogDatabaseFileName, TapeId);
  SysUtils.DeleteFile(CatalogFileName(TapeId));
end;

function TMainForm.ReadTapeIdentity(TapeHandle: THandle; out TapeId: TGUID): Boolean;
var B: TBytes; Count, Version, Status: Cardinal; Magic: AnsiString;
begin
  Result := False; FillChar(TapeId, SizeOf(TapeId), 0);
  Status := PrepareTape(TapeHandle, TAPE_REWIND, False);
  if Status <> NO_ERROR then begin
    Log('Bandkopfprüfung: Zurückspulen fehlgeschlagen. Windows-Fehler: ' + IntToStr(Status));
    Exit;
  end;
  ConfigureTape(TapeHandle);
  SetLength(B, BLOCK_SIZE);
  if not ReadBlock(TapeHandle, B[0]) then begin
    Status := GetLastError;
    Log('Bandkopfprüfung: erster Bandblock konnte nicht gelesen werden. Windows-Fehler: ' + IntToStr(Status));
    Exit;
  end;
  Result := ParseHeader(B, Count, TapeId);
  if not Result then begin
    SetLength(Magic, Length(FORMAT_MAGIC));
    Move(B[0], Magic[1], Length(FORMAT_MAGIC));
    Move(B[Length(FORMAT_MAGIC)], Version, SizeOf(Version));
    Log('Bandkopfprüfung: Formatkennung="' + string(Magic) + '", Formatversion=' + IntToStr(Version) +
      ', Einträge im ersten Satz=' + IntToStr(Count) + '.');
    Exit;
  end;
  if GUIDToString(TapeId) = '{00000000-0000-0000-0000-000000000000}' then begin
    Log('Bandkopfprüfung: älteres Format Version 1 erkannt; dieses enthält keine Band-ID und kann noch nicht sicher angehängt werden.');
    Exit(False);
  end;
end;

procedure TMainForm.AddSourcesToCatalog(var Entries: TArchiveEntryArray; SetNumber: Integer; Count: Integer);
var I, Start, EntryCount: Integer;
begin
  EntryCount := Length(FSources);
  if (Count >= 0) and (Count < EntryCount) then EntryCount := Count;
  Start := Length(Entries); SetLength(Entries, Start + EntryCount);
  for I := 0 to EntryCount - 1 do begin
    Entries[Start + I] := FSources[I];
    Entries[Start + I].SetNumber := SetNumber;
    Entries[Start + I].SourcePath := '';
  end;
end;

function TMainForm.WriteTapeEntry(TapeHandle: THandle; const Entry: TArchiveEntry; Prefetch: TFilePrefetchThread): Boolean;
var B, Data: TBytes; FS: TFileStream; Buf: array[0..BLOCK_SIZE-1] of Byte; N: Integer; Written: DWORD;
begin
  UpdateBackupProgress(Entry.RelativePath);
  B := BuildMetadata(Entry);
  if not WriteBlock(TapeHandle, B[0], BLOCK_SIZE) then Exit(False);
  Result := True;
  if Entry.IsDirectory then Exit;
  try
    if Assigned(Prefetch) then begin
      while Prefetch.PopBlock(Data, N) do begin
        if not Windows.WriteFile(TapeHandle, Data[0], BLOCK_SIZE, Written, nil) or (Written <> BLOCK_SIZE) then Exit(False);
        Inc(FBackupBytesWritten, N); UpdateBackupProgress(Entry.RelativePath);
      end;
      if Prefetch.ErrorText <> '' then raise Exception.Create(Prefetch.ErrorText);
    end else begin
      FS := TFileStream.Create(WindowsPathForIO(Entry.SourcePath), fmOpenRead or fmShareDenyWrite);
      try
        if FS.Size <> Entry.Size then
          raise Exception.Create('Dateigröße hat sich seit der Auswahl geändert.');
        while FS.Position < FS.Size do begin
          FillChar(Buf, SizeOf(Buf), 0); N := FS.Read(Buf, SizeOf(Buf));
          if not Windows.WriteFile(TapeHandle, Buf, BLOCK_SIZE, Written, nil) or (Written <> BLOCK_SIZE) then Exit(False);
          Inc(FBackupBytesWritten, N); UpdateBackupProgress(Entry.RelativePath);
        end;
      finally FS.Free; end;
    end;
  except
    on E: Exception do begin
      Log('Quelldatei nicht erreichbar oder nicht vollständig lesbar: ' + Entry.SourcePath);
      raise Exception.Create('Netzwerk-/Lesefehler bei ' + Entry.RelativePath + ': ' + E.Message);
    end;
  end;
end;

function TMainForm.CaptureTapePosition(TapeHandle: THandle; out Partition, OffsetLow, OffsetHigh: DWORD): Boolean;
var Status: DWORD;
begin
  Partition := 0; OffsetLow := 0; OffsetHigh := 0;
  if not FTapePositionSupported then Exit(False);
  Status := GetTapePosition(TapeHandle, TAPE_LOGICAL_BLOCK, Partition, OffsetLow, @OffsetHigh);
  Result := Status = NO_ERROR;
  if not Result then begin
    { Einige Bandtreiber unterstützen die logische Positionsabfrage während
      des Schreibens nicht. Nach dem ersten Fehler nicht bei jeder Datei
      erneut abfragen und das Protokoll fluten. }
    FTapePositionSupported := False;
    Log('Bandposition kann von diesem Treiber nicht ermittelt werden. Windows-Fehler: ' + IntToStr(Status) +
      '. Die Sicherung wird fortgesetzt; eine automatische Bereinigung bei Abbruch ist damit nicht möglich.');
  end;
end;

function TMainForm.TrimTapeAt(TapeHandle: THandle; Partition, OffsetLow, OffsetHigh: DWORD): Boolean;
var Status: DWORD;
begin
  Result := False;
  Status := SetTapePosition(TapeHandle, TAPE_LOGICAL_BLOCK, Partition, OffsetLow, OffsetHigh, False);
  if Status <> NO_ERROR then begin
    Log('Band konnte nicht auf den Anfang des fehlerhaften Eintrags positioniert werden. Windows-Fehler: ' + IntToStr(Status));
    Exit;
  end;
  Status := EraseTape(TapeHandle, TAPE_ERASE_SHORT, False);
  Result := Status = NO_ERROR;
  if Result then
    Log('Unvollständiger Dateiabschnitt wurde bis zum Bandende entfernt.')
  else
    Log('Unvollständiger Dateiabschnitt konnte nicht entfernt werden. Windows-Fehler: ' + IntToStr(Status));
end;

function TMainForm.ReadTapeEntry(TapeHandle: THandle; out Entry: TArchiveEntry): Boolean;
var B: TBytes;
begin SetLength(B, BLOCK_SIZE); Result := ReadBlock(TapeHandle, B[0]); if Result then Result := ParseMetadata(B, Entry); end;

function TMainForm.SkipTapeSetData(TapeHandle: THandle; Count: Cardinal): Boolean;
var I, K: Cardinal; Entries: TArchiveEntryArray; Buffer: array[0..BLOCK_SIZE-1] of Byte;
begin
  Result := True;
  SetLength(Entries, Count);
  for I := 0 to Count - 1 do
    if not ReadTapeEntry(TapeHandle, Entries[I]) then Exit(False);
  for I := 0 to Count - 1 do
    if not Entries[I].IsDirectory then
      for K := 1 to (Entries[I].Size + BLOCK_SIZE - 1) div BLOCK_SIZE do
        if not ReadBlock(TapeHandle, Buffer[0]) then Exit(False);
end;

function TMainForm.VerifyWrittenBackup(TapeHandle: THandle; const ExpectedEntries: TArchiveEntryArray; const TapeId: TGUID; CompareContent: Boolean; SetNumber: Cardinal; out VerifiedBytes: Int64): Boolean;
var Status, Count, I, J, N, SetIndex: Cardinal; B, Buffer, SourceBuffer: TBytes; HeaderTapeId: TGUID; E: TArchiveEntry; Entries: TArchiveEntryArray; Blocks: Int64; SourceStream: TFileStream;
begin
  Result := False;
  VerifiedBytes := 0;
  Status := PrepareTape(TapeHandle, TAPE_REWIND, False);
  if Status <> NO_ERROR then begin
    Log('Abschlussprüfung: Band konnte nicht zurückgespult werden. Windows-Fehler: ' + IntToStr(Status));
    Exit;
  end;
  ConfigureTape(TapeHandle);
  SetLength(B, BLOCK_SIZE);
  { Beim Anhängen liegt das neu geschriebene Set nicht am Bandanfang. Die
    älteren Sets müssen vor der Prüfung vollständig übersprungen werden. }
  SetIndex := 0;
  while SetIndex <= SetNumber do begin
    while not ReadBlock(TapeHandle, B[0]) do
      if GetLastError <> ERROR_FILEMARK_DETECTED then begin
        Log('Abschlussprüfung: Bandkopf konnte nicht gelesen werden. Windows-Fehler: ' + IntToStr(GetLastError));
        Exit;
      end;
    if not ParseHeader(B, Count, HeaderTapeId) then begin
      Log('Abschlussprüfung: ungültiger oder beschädigter Bandkopf.');
      Exit;
    end;
    if SetIndex < SetNumber then begin
      { Ein Backup-Set endet mit genau einem Filemark. Den Bandtreiber das
        gesamte Set bis hinter diesen Filemark überspringen lassen; das ist
        robuster als 136000 einzelne Blocks manuell zu lesen. }
      Status := SetTapePosition(TapeHandle, TAPE_SPACE_FILEMARKS, 0, 1, 0, False);
      if Status <> NO_ERROR then begin
        Log('Abschlussprüfung: vorheriges Backup-Set konnte nicht übersprungen werden. Windows-Fehler: ' + IntToStr(Status));
        Exit;
      end;
      Inc(SetIndex);
    end else
      Break;
  end;
  if Count <> Cardinal(Length(ExpectedEntries)) then begin
    Log('Abschlussprüfung: erwartete Einträge=' + IntToStr(Length(ExpectedEntries)) +
      ', auf dem Band=' + IntToStr(Count) + '.');
    Exit;
  end;
  if GUIDToString(HeaderTapeId) <> GUIDToString(TapeId) then begin
    Log('Abschlussprüfung: Band-ID stimmt nicht mit der gerade geschriebenen Sicherung überein.');
    Exit;
  end;
  { Ein Set enthält zuerst alle Metadatenblöcke und erst danach die
    Datenblöcke. Daher müssen die Metadaten vollständig eingelesen werden,
    bevor die Dateidaten geprüft werden. }
  SetLength(Entries, Count);
  for I := 0 to Count - 1 do begin
    if not ReadTapeEntry(TapeHandle, Entries[I]) then begin
      Log('Abschlussprüfung: Metadaten für Eintrag ' + IntToStr(I + 1) + ' konnten nicht gelesen werden.');
      Exit;
    end;
    if (Entries[I].RelativePath <> ExpectedEntries[I].RelativePath) or
       (Entries[I].IsDirectory <> ExpectedEntries[I].IsDirectory) or
       (Entries[I].Size <> ExpectedEntries[I].Size) then begin
      Log('Abschlussprüfung: Eintrag ' + IntToStr(I + 1) + ' stimmt nicht mit der Sicherungsauswahl überein.');
      Exit;
    end;
  end;
  SetLength(Buffer, BLOCK_SIZE);
  for I := 0 to Count - 1 do begin
    E := Entries[I];
    if not E.IsDirectory then begin
      VerifiedBytes := VerifiedBytes + E.Size;
      Blocks := (E.Size + BLOCK_SIZE - 1) div BLOCK_SIZE;
      SourceStream := nil;
      try
        if CompareContent then begin
          try
            SourceStream := TFileStream.Create(WindowsPathForIO(ExpectedEntries[I].SourcePath), fmOpenRead or fmShareDenyWrite);
          except
            Log('Abschlussprüfung: Originaldatei konnte nicht geöffnet werden: ' + ExpectedEntries[I].SourcePath);
            Exit;
          end;
          if SourceStream.Size <> E.Size then begin
            Log('Abschlussprüfung: Größe der Originaldatei hat sich geändert: ' + ExpectedEntries[I].RelativePath);
            Exit;
          end;
        end;
        SetLength(SourceBuffer, BLOCK_SIZE);
        for J := 1 to Blocks do begin
          if not ReadBlock(TapeHandle, Buffer[0]) then begin
            Log('Abschlussprüfung: Datenblock von Eintrag ' + IntToStr(I + 1) + ' konnte nicht gelesen werden.');
            Exit;
          end;
          if CompareContent then begin
            FillChar(SourceBuffer[0], BLOCK_SIZE, 0);
            N := SourceStream.Read(SourceBuffer[0], BLOCK_SIZE);
            if (N = 0) or not CompareMem(@Buffer[0], @SourceBuffer[0], BLOCK_SIZE) then begin
              Log('Abschlussprüfung: Inhalt stimmt nicht überein: ' + ExpectedEntries[I].RelativePath +
                ', Block ' + IntToStr(J) + '.');
              Exit;
            end;
          end;
        end;
      finally
        SourceStream.Free;
      end;
    end;
  end;
  Result := True;
end;

{ Prüft Quellen, schreibt den Backup-Satz auf Band und aktualisiert den Katalog. }
procedure TMainForm.WriteBackupClick(Sender: TObject);
var H: THandle; I: Integer; B: TBytes; Total: Int64; FailedPositionValid: Boolean;
  FailedPartition, FailedOffsetLow, FailedOffsetHigh: DWORD; LocalCatalog: TArchiveEntryArray;
  NewSetNumber, CompletedCount, J, SourceHandle, CheckTotal, CheckNumber: Integer; BackupErrors: TStringList;
  CurrentSize: Int64; ErrorText: string; Prefetch, NextPrefetch: TFilePrefetchThread;
  Status: DWORD; VerifiedBytes: Int64; UseValidatedSources: Boolean;
  BackupSucceeded: Boolean;
begin
  BackupSucceeded := False;
  FailedPositionValid := False;
  CompletedCount := 0;
  NewSetNumber := 0;
  UseValidatedSources := FJobSourcesValidated;
  FJobSourcesValidated := False;
  if Length(FSources) = 0 then begin ShowMessage('Bitte zuerst Dateien oder Ordner auswählen.'); Exit; end;
  if FJobNeedsExpansion then begin
    FBackupWaitingForSourceScan := True;
    ProgressBar.Max := Max(1, Length(FSources)); ProgressBar.Position := 0;
    ProgressLabel.Caption := 'Ordner werden für das Backup eingelesen ...';
    SetBusy(True);
    FJobValidationThread := TJobValidationThread.Create(FSources, @ApplyJobValidation, @ApplyJobValidationProgress);
    Exit;
  end;
  BackupErrors := TStringList.Create;
  Prefetch := nil;
  H := OpenTape(GENERIC_READ or GENERIC_WRITE); if H = INVALID_HANDLE_VALUE then begin BackupErrors.Free; Exit; end; SetBusy(True); try
    if FAppendBackup then begin
      if not ReadTapeIdentity(H, FTapeId) then raise Exception.Create('Anhängen abgebrochen: Das Band konnte nicht eindeutig identifiziert werden. Details stehen im Protokoll. Es wurden keine Daten geschrieben.');
      FTapeIdValid := True;
      if SetTapePosition(H, TAPE_SPACE_END_OF_DATA, 0, 0, 0, False) <> NO_ERROR then raise Exception.Create('Bandende konnte nicht gefunden werden.');
    end else begin
      Status := EnsureTapeReady(H, 'Backup');
      if Status <> NO_ERROR then begin
        Log('Band ist nicht bereit. Windows-Fehler: ' + IntToStr(Status));
        raise Exception.Create('Band ist nicht bereit. Windows-Fehler: ' + IntToStr(Status));
      end;
      if CreateGUID(FTapeId) <> S_OK then raise Exception.Create('Eindeutige Band-ID konnte nicht erzeugt werden.');
      FTapeIdValid := True;
      Status := PrepareTape(H, TAPE_REWIND, False);
      if Status <> NO_ERROR then begin
        Log('Band konnte nicht zurückgespult werden. Windows-Fehler: ' + IntToStr(Status));
        raise Exception.Create('Band konnte nicht zurückgespult werden. Windows-Fehler: ' + IntToStr(Status));
      end;
    end;
    SetLength(LocalCatalog, 0);
    if FAppendBackup then LoadLocalCatalog(FTapeId, LocalCatalog);
    NewSetNumber := 0;
    for I := 0 to High(LocalCatalog) do
      if LocalCatalog[I].SetNumber >= NewSetNumber then NewSetNumber := LocalCatalog[I].SetNumber + 1;
    ConfigureTape(H);
    if not UseValidatedSources then begin
      { Bei manuell zusammengestellten Quellen muss vor dem Header geprüft
        werden, welche Dateien tatsächlich gelesen werden können. Bei einem
        geladenen Auftrag wurde diese Prüfung bereits im Hintergrund erledigt. }
      CheckTotal := Length(FSources); CheckNumber := 0;
      ProgressBar.Max := Max(1, CheckTotal); ProgressBar.Position := 0;
      ProgressLabel.Caption := 'Dateien werden geprüft ...'; Application.ProcessMessages;
      I := 0;
      while I < Length(FSources) do begin
        Inc(CheckNumber);
        ProgressBar.Position := Min(CheckNumber, ProgressBar.Max);
        ProgressLabel.Caption := 'Prüfe Datei ' + IntToStr(CheckNumber) + ' von ' + IntToStr(CheckTotal) +
          ': ' + FSources[I].RelativePath;
        Application.ProcessMessages;
        if not FSources[I].IsDirectory then begin
            SourceHandle := FileOpen(WindowsPathForIO(FSources[I].SourcePath), fmOpenRead or fmShareDenyWrite);
          if SourceHandle < 0 then begin
            BackupErrors.Add(FSources[I].RelativePath + ': Datei konnte nicht geöffnet werden.');
            for J := I to High(FSources) - 1 do FSources[J] := FSources[J + 1];
            SetLength(FSources, Length(FSources) - 1);
            Continue;
          end;
          CurrentSize := FileSeek(SourceHandle, 0, 2); FileClose(SourceHandle);
          if CurrentSize <> FSources[I].Size then begin
            BackupErrors.Add(FSources[I].RelativePath + ': Dateigröße hat sich seit der Auswahl geändert.');
            for J := I to High(FSources) - 1 do FSources[J] := FSources[J + 1];
            SetLength(FSources, Length(FSources) - 1);
            Continue;
          end;
        end;
        Inc(I);
      end;
    end else begin
      ProgressBar.Max := Max(1, Length(FSources)); ProgressBar.Position := ProgressBar.Max;
      ProgressLabel.Caption := 'Netzwerkprüfung abgeschlossen; Backup wird vorbereitet ...'; Application.ProcessMessages;
    end;
    SourceTree.Items.Clear; SourceTree.BeginUpdate;
    try
      for I := 0 to High(FSources) do
        AddTreeEntry(SourceTree, FSources[I].RelativePath, FSources[I].IsDirectory, FSources[I].Size, I);
    finally SourceTree.EndUpdate; end;
    if Length(FSources) = 0 then begin
      ErrorText := 'Keine lesbaren Dateien für die Sicherung vorhanden.';
      raise Exception.Create(ErrorText);
    end;
    Total := 0; for I := 0 to High(FSources) do Inc(Total, FSources[I].Size);
    if not ConfirmCapacity(H, Total) then raise Exception.Create('Schreiben vom Benutzer abgebrochen.');
    FBackupTotalBytes := Total;
    FBackupBytesWritten := 0;
    FBackupStartTick := GetTickCount64;
    FTapePositionSupported := True;
    ProgressBar.Max := 1000;
    ProgressBar.Position := 0;
    ProgressLabel.Caption := 'Backup wird vorbereitet ...';
    Application.ProcessMessages;
    if UseValidatedSources and (Length(FSources) > 0) and not FSources[0].IsDirectory then
      Prefetch := TFilePrefetchThread.Create(FSources[0].SourcePath, FSources[0].Size);
    B := BuildHeader(Length(FSources), FTapeId); if not WriteBlock(H, B[0], BLOCK_SIZE) then raise Exception.Create('Bandkopf konnte nicht geschrieben werden.');
    for I := 0 to High(FSources) do begin B := BuildMetadata(FSources[I]); if not WriteBlock(H, B[0], BLOCK_SIZE) then raise Exception.Create('Inhaltsverzeichnis konnte nicht geschrieben werden.'); end;
    FailedPositionValid := False;
    for I := 0 to High(FSources) do begin
      NextPrefetch := nil;
      if (I < High(FSources)) and not FSources[I + 1].IsDirectory then
        NextPrefetch := TFilePrefetchThread.Create(FSources[I + 1].SourcePath, FSources[I + 1].Size);
      FailedPositionValid := CaptureTapePosition(H, FailedPartition, FailedOffsetLow, FailedOffsetHigh);
      try
        if not WriteTapeEntry(H, FSources[I], Prefetch) then
          raise Exception.Create('Fehler beim Schreiben von ' + FSources[I].RelativePath);
      finally
        if Assigned(Prefetch) then begin Prefetch.WaitFor; Prefetch.Free; end;
        Prefetch := NextPrefetch;
      end;
      Inc(CompletedCount);
      FailedPositionValid := False;
    end;
    if WriteTapemark(H, TAPE_FILEMARKS, 1, False) <> NO_ERROR then raise Exception.Create('Filemark konnte nicht geschrieben werden.');
    if (Total > 0) and (FBackupBytesWritten = 0) then
      raise Exception.Create('Es wurden keine Nutzdaten geschrieben, obwohl Dateien mit Inhalt ausgewählt waren.');
    Log('Geschriebene Nutzdaten: ' + IntToStr(FBackupBytesWritten) + ' Bytes (' +
      FormatFloat('0.00', FBackupBytesWritten / 1073741824.0) + ' GB).');
    ProgressLabel.Caption := 'Abschlussprüfung: Banddaten werden gelesen ...';
    Application.ProcessMessages;
    if not VerifyWrittenBackup(H, FSources, FTapeId, FVerifyWrittenData, Cardinal(NewSetNumber), VerifiedBytes) then
      raise Exception.Create('Abschlussprüfung der Bandsicherung fehlgeschlagen.');
    if VerifiedBytes <> FBackupBytesWritten then
      raise Exception.Create('Abschlussprüfung: Geschriebene Nutzdaten stimmen nicht überein. Erwartet ' +
        IntToStr(FBackupBytesWritten) + ', gelesen ' + IntToStr(VerifiedBytes) + ' Bytes.');
    if (Total > 0) and (VerifiedBytes = 0) then
      raise Exception.Create('Abschlussprüfung: Es wurden keine Nutzdaten vom Band gelesen.');
    if FVerifyWrittenData then
      Log('Byteweiser Vergleich mit den Originaldateien: erfolgreich.');
    Log('Abschlussprüfung erfolgreich: ' + IntToStr(Length(FSources)) +
      ' Einträge und ' + IntToStr(VerifiedBytes) + ' Nutzdaten-Bytes gelesen.');
    ProgressBar.Position := 1000;
    ProgressLabel.Caption := 'Backup abgeschlossen: 100,0 %    Restzeit: 0:00:00';
    Log('Backup erfolgreich geschrieben: ' + IntToStr(Length(FSources)) + ' Einträge.');
    if BackupErrors.Count > 0 then begin
      Log('Backup mit übersprungenen Dateien abgeschlossen: ' + IntToStr(BackupErrors.Count) + ' Fehler.');
      for I := 0 to BackupErrors.Count - 1 do Log('Übersprungen: ' + BackupErrors[I]);
    end;
    AddSourcesToCatalog(LocalCatalog, NewSetNumber);
    if SaveLocalCatalog(FTapeId, LocalCatalog) then
      Log('SQLite-Katalog gespeichert: ' + CatalogDatabaseFileName);
    BackupSucceeded := True;
  except on E: Exception do begin
    if Assigned(Prefetch) then begin Prefetch.Terminate; Prefetch.Free; Prefetch := nil; end;
    ProgressLabel.Caption := 'Backup abgebrochen: ' + E.Message;
    ShowMessage('Backup abgebrochen.' + LineEnding + E.Message + LineEnding +
      'Die unvollständige Datei wird nicht als gültiger Katalogeintrag angezeigt.');
    if FailedPositionValid then begin
      Log('Backup abgebrochen: ' + E.Message);
      if not TrimTapeAt(H, FailedPartition, FailedOffsetLow, FailedOffsetHigh) then
        Log('WARNUNG: Das fehlerhafte Bandende muss manuell bereinigt werden.');
    end else
      Log('FEHLER: ' + E.Message);
    { Auch bei einem Abbruch den bereits vollständig geschriebenen Teil
      katalogisieren. Die aktuelle/abgebrochene Datei bleibt außen vor. }
    if FTapeIdValid and ((CompletedCount > 0) or FAppendBackup) then begin
      AddSourcesToCatalog(LocalCatalog, NewSetNumber, CompletedCount);
      if SaveLocalCatalog(FTapeId, LocalCatalog) then
        Log('Unvollständiger SQLite-Katalog gespeichert: ' + IntToStr(CompletedCount) + ' vollständige Einträge.');
    end;
  end; end; CloseHandle(H); SetBusy(False);
  BackupErrors.Free;
  if BackupSucceeded and FShutdownAfterBackup then begin
    Log('Backup erfolgreich. Band wird vor dem Herunterfahren ausgeworfen ...');
    H := OpenTape(GENERIC_READ or GENERIC_WRITE);
    if H = INVALID_HANDLE_VALUE then
      Log('Herunterfahren abgebrochen: Bandlaufwerk konnte zum Auswerfen nicht geöffnet werden.')
    else begin
      try
        ProgressLabel.Caption := 'Bitte warten: Band wird zurückgespult und ausgeworfen ...';
        Application.ProcessMessages;
        if PrepareTape(H, TAPE_UNLOAD, False) = NO_ERROR then begin
          Log('Band erfolgreich ausgeworfen. Windows wird in 60 Sekunden heruntergefahren.');
          ProgressLabel.Caption := 'Band ausgeworfen. Windows fährt herunter ...';
          ShellExecute(0, 'open', 'shutdown.exe', '/s /t 60 /c "Backup erfolgreich abgeschlossen"', nil, SW_HIDE);
        end else begin
          Log('Herunterfahren abgebrochen: Band konnte nicht ausgeworfen werden. Windows-Fehler: ' + IntToStr(GetLastError));
          ProgressLabel.Caption := 'Herunterfahren abgebrochen: Band konnte nicht ausgeworfen werden.';
        end;
      finally CloseHandle(H); end;
    end;
  end;
end;

{ Liest Inhaltsverzeichnisse und Daten vom Band und aktualisiert den lokalen Katalog. }
procedure TMainForm.ReadCatalogClick(Sender: TObject);
var H: THandle; B: TBytes; N, I, J, SetNo, ValidCount, Status: Cardinal; E: TArchiveEntry;
  SetEntries, LocalCatalog: TArchiveEntryArray; LastErr: DWORD; TotalEntries: Integer; CompleteSet: Boolean; Buffer: array[0..BLOCK_SIZE-1] of Byte; HeaderTapeId: TGUID; K: Integer; CatalogTapeIdValid: Boolean; CatalogTapeId: TGUID; NodeMap: TStringList; ForceRefresh: Boolean;
begin
  ForceRefresh := FForceCatalogRefresh;
  FForceCatalogRefresh := False;
  FCatalogLoaded := False; UpdateActionState;
  H := OpenTape(GENERIC_READ); if H = INVALID_HANDLE_VALUE then Exit; SetBusy(True); try
    ProgressBar.Max := 1; ProgressBar.Position := 0;
    ProgressLabel.Caption := 'Bandverzeichnis wird vorbereitet ...'; Application.ProcessMessages;
    Status := EnsureTapeReady(H, 'Inhaltsverzeichnis');
    if Status <> NO_ERROR then
      raise Exception.Create('Band ist nicht bereit. Windows-Fehler: ' + IntToStr(Status));
    if PrepareTape(H, TAPE_REWIND, False) <> NO_ERROR then raise Exception.Create('Band konnte nicht zurückgespult werden.');
    ConfigureTape(H);
    LogTapeParameters(H);
    SetLength(B, BLOCK_SIZE); FreeArray(FCatalog); SetLength(FSetCounts, 0); CatalogTree.Items.Clear; SetNo := 0; CatalogTapeIdValid := False;
    while True do begin
      if not ReadBlock(H, B[0]) then begin LastErr := GetLastError; if LastErr = ERROR_FILEMARK_DETECTED then Continue else Break; end;
      if not ParseHeader(B, N, HeaderTapeId) then begin if Length(FCatalog) = 0 then raise Exception.Create('Unbekanntes oder beschädigtes LTO-Backup.'); Break; end;
      if GUIDToString(HeaderTapeId) <> '{00000000-0000-0000-0000-000000000000}' then begin CatalogTapeId := HeaderTapeId; CatalogTapeIdValid := True; end;
      if ForceRefresh then
        Log('Lokaler Katalog wird ignoriert. Das Band wird vollständig neu eingelesen.')
      else if (GUIDToString(HeaderTapeId) <> '{00000000-0000-0000-0000-000000000000}') and LoadLocalCatalog(HeaderTapeId, LocalCatalog) then begin
        FCatalog := LocalCatalog; CatalogTree.Items.Clear; SetLength(FSetCounts, 0);
        ProgressBar.Max := Max(1, Length(FCatalog)); ProgressBar.Position := 0;
        CatalogTree.Items.BeginUpdate;
        NodeMap := TStringList.Create;
        NodeMap.Sorted := True; NodeMap.CaseSensitive := False; NodeMap.Duplicates := dupIgnore;
        try
          for K := 0 to High(FCatalog) do begin
            ProgressBar.Position := K + 1;
            if (K mod 500 = 0) or (K = High(FCatalog)) then begin
              ProgressLabel.Caption := 'Lokales Inhaltsverzeichnis: ' + IntToStr(K + 1) + ' von ' + IntToStr(Length(FCatalog)) +
                ': ' + FCatalog[K].RelativePath;
              Application.ProcessMessages;
            end;
            AddTreeEntry(CatalogTree, FCatalog[K].RelativePath, FCatalog[K].IsDirectory, FCatalog[K].Size, K, NodeMap);
            while Length(FSetCounts) <= FCatalog[K].SetNumber do SetLength(FSetCounts, Length(FSetCounts) + 1);
            Inc(FSetCounts[FCatalog[K].SetNumber]);
          end;
        finally
          NodeMap.Free;
          CatalogTree.Items.EndUpdate;
        end;
        SetNo := 0;
        for K := 0 to High(FCatalog) do
          if FCatalog[K].SetNumber >= SetNo then SetNo := FCatalog[K].SetNumber + 1;
        Log('Lokaler SQLite-Katalog geladen: ' + CatalogDatabaseFileName);
        Log('Inhaltsverzeichnis gelesen: ' + IntToStr(Length(FCatalog)) + ' Einträge in ' + IntToStr(SetNo) + ' Backup-Set(s) (lokaler Katalog).');
        Break;
      end;
      SetLength(SetEntries, N); CompleteSet := True;
      ProgressBar.Max := Max(1, Integer(N)); ProgressBar.Position := 0;
      for I := 0 to N - 1 do begin
        if not ReadTapeEntry(H, SetEntries[I]) then begin CompleteSet := False; Break; end;
        SetEntries[I].SetNumber := SetNo;
        ProgressBar.Position := I + 1;
        ProgressLabel.Caption := 'Bandverzeichnis: Eintrag ' + IntToStr(I + 1) + ' von ' + IntToStr(N) +
          ': ' + SetEntries[I].RelativePath; Application.ProcessMessages;
      end;
      ValidCount := 0;
      if CompleteSet then
        for I := 0 to N - 1 do begin
          if not SetEntries[I].IsDirectory then
            for J := 1 to (SetEntries[I].Size + BLOCK_SIZE - 1) div BLOCK_SIZE do begin
              ProgressLabel.Caption := 'Lese Banddaten: ' + SetEntries[I].RelativePath;
              Application.ProcessMessages;
              if not ReadBlock(H, Buffer[0]) then begin CompleteSet := False; Break; end;
            end;
          if not CompleteSet then Break;
          E := SetEntries[I]; SetLength(FCatalog, Length(FCatalog) + 1); FCatalog[High(FCatalog)] := E;
          AddTreeEntry(CatalogTree, E.RelativePath, E.IsDirectory, E.Size, Length(FCatalog) - 1);
          Inc(ValidCount);
        end;
      SetLength(FSetCounts, Length(FSetCounts) + 1); FSetCounts[High(FSetCounts)] := ValidCount;
      if not CompleteSet then begin
        Log('WARNUNG: Unvollständiger letzter Datei-Eintrag wurde aus dem Inhaltsverzeichnis entfernt.');
        Break;
      end;
      Inc(SetNo);
    end;
    TotalEntries := Length(FCatalog); FCatalogLoaded := TotalEntries > 0; UpdateActionState; ProgressBar.Position := ProgressBar.Max;
    ProgressLabel.Caption := 'Inhaltsverzeichnis gelesen: ' + IntToStr(TotalEntries) + ' Einträge';
    Log('Inhaltsverzeichnis gelesen: ' + IntToStr(TotalEntries) + ' Einträge aus ' + IntToStr(SetNo) + ' Backup-Set(s).');
    if CatalogTapeIdValid and SaveLocalCatalog(CatalogTapeId, FCatalog) then
      Log('SQLite-Katalog nach dem Einlesen gespeichert: ' + CatalogDatabaseFileName);
  except on E: Exception do begin FCatalogLoaded := False; ProgressLabel.Caption := 'Fehler beim Lesen des Bandverzeichnisses'; Log('FEHLER: ' + E.Message); end; end; CloseHandle(H); SetBusy(False);
end;

procedure TMainForm.RefreshCatalogClick(Sender: TObject);
begin
  if MessageDlg('Der lokale Katalog dieses Bandes wird ignoriert und vollständig vom Band neu aufgebaut. Fortfahren?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FForceCatalogRefresh := True;
  ReadCatalogClick(Sender);
end;

function TMainForm.EnsureDirectory(const DirName: string): Boolean;
begin Result := ForceDirectories(DirName) or DirectoryExists(DirName); end;

function TMainForm.NormalizeArchivePath(const Path: string): string;
begin
  { Führende/abschließende Leerzeichen können Teil eines Dateinamens sein. }
  Result := StringReplace(Path, '/', '\', [rfReplaceAll]);
  while (Length(Result) > 0) and (Result[1] = '\') do Delete(Result, 1, 1);
  while (Length(Result) > 0) and (Result[Length(Result)] = '\') do Delete(Result, Length(Result), 1);
end;

procedure TMainForm.SourceTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var Node: TTreeNode; Index: Integer; EntryName: string;
begin
  if Button <> mbRight then Exit;
  Node := SourceTree.GetNodeAt(X, Y);
  if not Assigned(Node) then Exit;
  SourceTree.Selected := Node;
  Index := -PtrInt(Node.Data) - 1;
  if (Index < 0) or (Index > High(FSources)) or FSources[Index].IsDirectory then Exit;
  EntryName := FSources[Index].RelativePath;
  if MessageDlg('Datei "' + EntryName + '" wirklich aus dem Sicherungsauftrag entfernen?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    DeleteSourceEntry(Index);
end;

procedure TMainForm.CatalogTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var Node: TTreeNode;
begin
  if Button = mbLeft then begin
    Node := CatalogTree.GetNodeAt(X, Y);
    if Assigned(Node) then begin
      { StateIndex kann bei einem neu erzeugten Knoten -1 sein. Die
        Zustandsbilder enthalten aber nur die Indizes 0 und 1. }
      if Node.StateIndex = 1 then
        Node.StateIndex := 0
      else
        Node.StateIndex := 1;
      CatalogTree.Selected := Node;
    end;
  end;
end;

function TMainForm.SelectRestoreEntries(out SelectedPaths, SelectedDirs: TStringList; out SelectedSet: Integer): Boolean;
var Dlg: TForm; List: TCheckListBox; Bottom: TPanel; OkButton, CancelButton: TButton;
  I, K, Index: Integer; Node: TTreeNode; InitialIndex: Integer;
begin
  Result := False; SelectedPaths := TStringList.Create; SelectedDirs := TStringList.Create; SelectedSet := -1;
  Dlg := TForm.CreateNew(Self); try
    Dlg.Caption := 'Einträge für Rücksicherung auswählen'; Dlg.Width := 760; Dlg.Height := 620; Dlg.Position := poScreenCenter;
    List := TCheckListBox.Create(Dlg); List.Parent := Dlg; List.Align := alClient; List.BorderStyle := bsSingle;
    List.IntegralHeight := True; List.MultiSelect := False;
    for I := 0 to High(FCatalog) do begin
      if FCatalog[I].IsDirectory then
        List.Items.AddObject('[Ordner] ' + FCatalog[I].RelativePath, TObject(PtrInt(I)))
      else
        List.Items.AddObject('[Datei]  ' + FCatalog[I].RelativePath, TObject(PtrInt(I)));
    end;
    InitialIndex := -1;
    if CatalogTree.Selected <> nil then begin
      K := PtrInt(CatalogTree.Selected.Data);
      if (K >= 0) and (K <= High(FCatalog)) then InitialIndex := K;
    end;
    if InitialIndex >= 0 then
      for I := 0 to List.Items.Count - 1 do
        if PtrInt(List.Items.Objects[I]) = InitialIndex then begin List.Checked[I] := True; Break; end;
    Bottom := TPanel.Create(Dlg); Bottom.Parent := Dlg; Bottom.Align := alBottom; Bottom.Height := 46; Bottom.BevelOuter := bvNone;
    OkButton := TButton.Create(Dlg); OkButton.Parent := Bottom; OkButton.Caption := 'Auswahl übernehmen'; OkButton.ModalResult := mrOk; OkButton.Left := 470; OkButton.Top := 10; OkButton.Width := 130;
    CancelButton := TButton.Create(Dlg); CancelButton.Parent := Bottom; CancelButton.Caption := 'Abbrechen'; CancelButton.ModalResult := mrCancel; CancelButton.Left := 610; CancelButton.Top := 10; CancelButton.Width := 100;
    if Dlg.ShowModal <> mrOk then Exit;
    for I := 0 to List.Items.Count - 1 do if List.Checked[I] then begin
      Index := PtrInt(List.Items.Objects[I]);
      if SelectedSet < 0 then SelectedSet := FCatalog[Index].SetNumber
      else if SelectedSet <> FCatalog[Index].SetNumber then begin
        ShowMessage('Bitte Einträge aus demselben Backup-Satz auswählen.'); SelectedSet := -1; Exit;
      end;
      if FCatalog[Index].IsDirectory then SelectedDirs.Add(FCatalog[Index].RelativePath)
      else SelectedPaths.Add(FCatalog[Index].RelativePath);
    end;
    if (SelectedPaths.Count = 0) and (SelectedDirs.Count = 0) then begin ShowMessage('Bitte mindestens einen Eintrag auswählen.'); Exit; end;
    Result := True;
  finally Dlg.Free; end;
end;

{ Stellt ausgewählte Dateien oder Ordner aus einem Band-Backup wieder her. }
procedure TMainForm.RestoreClick(Sender: TObject);
var H: THandle; D, Target, RestoreStage: string; B: TBytes; N, J, TargetCount, Status: Cardinal; K, SetNo, SelectedSet, I, RestoredCount: Integer; E: TArchiveEntry; Wanted, FoundSet: Boolean; FS: TFileStream; Buf: array[0..BLOCK_SIZE-1] of Byte; Remaining, ReadNow: Int64; LastErr: DWORD; HeaderTapeId: TGUID; SelectedPaths, SelectedDirs: TStringList; Node: TTreeNode; SetEntries: TArchiveEntryArray;
begin
  RestoreStage := 'Auswahl vorbereiten';
  if not FCatalogLoaded then begin ShowMessage('Bitte zuerst das Inhaltsverzeichnis des Bandes lesen.'); Exit; end;
  SelectedPaths := TStringList.Create; SelectedDirs := TStringList.Create; SelectedSet := -1;
  RestoredCount := 0;
  Node := CatalogTree.Items.GetFirstNode;
  while Node <> nil do begin
    if Node.StateIndex = 1 then begin
      I := PtrInt(Node.Data);
      if (I >= 0) and (I <= High(FCatalog)) then begin
        if SelectedSet < 0 then SelectedSet := FCatalog[I].SetNumber;
        if SelectedSet <> FCatalog[I].SetNumber then begin
          SelectedPaths.Free; SelectedDirs.Free; ShowMessage('Bitte Einträge aus demselben Backup-Satz markieren.'); Exit;
        end;
        if SelectedSet = FCatalog[I].SetNumber then
          if FCatalog[I].IsDirectory then SelectedDirs.Add(FCatalog[I].RelativePath)
          else SelectedPaths.Add(FCatalog[I].RelativePath);
      end;
    end;
    Node := Node.GetNext;
  end;
  if (SelectedPaths.Count = 0) and (SelectedDirs.Count = 0) then begin
    SelectedPaths.Free; SelectedDirs.Free; ShowMessage('Bitte zuerst Dateien oder Ordner im Bandverzeichnis markieren.'); Exit;
  end;
  Log('Rücksicherungsauswahl: Backup-Set ' + IntToStr(SelectedSet) + ', Dateien=' +
    IntToStr(SelectedPaths.Count) + ', Ordner=' + IntToStr(SelectedDirs.Count));
  for I := 0 to SelectedPaths.Count - 1 do
    Log('  Datei: [' + NormalizeArchivePath(SelectedPaths[I]) + ']');
  for I := 0 to SelectedDirs.Count - 1 do
    Log('  Ordner: [' + NormalizeArchivePath(SelectedDirs[I]) + ']');
  if not SelectDirectory('Zielordner für Wiederherstellung auswählen', '', D) then begin SelectedPaths.Free; SelectedDirs.Free; Exit; end;
  try
    RestoreStage := 'Zielordner auswählen';
    H := OpenTape(GENERIC_READ); if H = INVALID_HANDLE_VALUE then Exit; SetBusy(True); try
    Status := EnsureTapeReady(H, 'Rücksicherung');
    if Status <> NO_ERROR then raise Exception.Create('Band ist nicht bereit. Windows-Fehler: ' + IntToStr(Status));
    RestoreStage := 'Band zurückspulen';
    if PrepareTape(H, TAPE_REWIND, False) <> NO_ERROR then raise Exception.Create('Band konnte nicht zurückgespult werden.');
    ConfigureTape(H);
    LogTapeParameters(H);
    RestoreStage := 'Bandkopf lesen';
    SetLength(B, BLOCK_SIZE); SetNo := 0; FoundSet := False;
    while not FoundSet do begin
      while not ReadBlock(H, B[0]) do begin LastErr := GetLastError; if LastErr <> ERROR_FILEMARK_DETECTED then raise Exception.Create('Ungültiges Backup oder Bandende.'); end;
      RestoreStage := 'Bandkopf auswerten';
      if not ParseHeader(B, N, HeaderTapeId) then raise Exception.Create('Ungültiges Backup.');
      if SetNo < SelectedSet then begin
        if SetTapePosition(H, TAPE_SPACE_FILEMARKS, 0, 1, 0, False) <> NO_ERROR then
          raise Exception.Create('Backup-Set konnte nicht übersprungen werden.');
      end else if SetNo = SelectedSet then begin
        { Die Anzahl im Bandkopf gehört zum tatsächlich gelesenen Backup-Satz.
          FSetCounts stammt nur aus dem lokalen Katalog und kann bei alten,
          unvollständigen oder nachträglich aktualisierten Katalogen abweichen. }
        TargetCount := N;
        if TargetCount = 0 then
          raise Exception.Create('Der ausgewählte Backup-Satz enthält keine Einträge.');
        ProgressBar.Max := Max(1, Integer(TargetCount)); ProgressBar.Position := 0;
        { Das Bandformat enthält zuerst das komplette Inhaltsverzeichnis und
          danach die Datenblöcke. Deshalb müssen alle Metadaten vor dem Lesen
          irgendeiner ausgewählten Datei eingelesen werden. }
        SetLength(SetEntries, TargetCount);
        RestoreStage := 'Metadaten des Backup-Satzes lesen';
        for J := 0 to TargetCount - 1 do begin
          ProgressBar.Position := J + 1;
          if (J mod 500 = 0) or (J = TargetCount - 1) then begin
            ProgressLabel.Caption := 'Rücksicherung ' + IntToStr(J + 1) + ' von ' + IntToStr(TargetCount) + ' wird geprüft ...';
            Application.ProcessMessages;
          end;
          RestoreStage := 'Metadaten von Eintrag ' + IntToStr(J + 1) + ' lesen';
          if not ReadTapeEntry(H, SetEntries[J]) then raise Exception.Create('Datenfehler.');
        end;
        for J := 0 to TargetCount - 1 do begin
          E := SetEntries[J];
          RestoreStage := 'Auswahl von Eintrag ' + IntToStr(J + 1) + ' prüfen';
          Wanted := False;
          for K := 0 to SelectedPaths.Count - 1 do
            if not Wanted and SameText(NormalizeArchivePath(E.RelativePath), NormalizeArchivePath(SelectedPaths[K])) then begin
              Wanted := True;
              Break;
            end;
          RestoreStage := 'Ordnerauswahl von Eintrag ' + IntToStr(J + 1) + ' prüfen';
          if not Wanted then
            for K := 0 to SelectedDirs.Count - 1 do
              if SameText(NormalizeArchivePath(E.RelativePath), NormalizeArchivePath(SelectedDirs[K])) or
                SameText(Copy(NormalizeArchivePath(E.RelativePath), 1, Length(NormalizeArchivePath(SelectedDirs[K])) + 1), NormalizeArchivePath(SelectedDirs[K]) + '\') then begin Wanted := True; Break; end;
          RestoreStage := 'Daten von Eintrag ' + IntToStr(J + 1) + ' verarbeiten';
          if Wanted then begin
            RestoreStage := 'Ausgewählte Datei wiederherstellen';
            Target := IncludeTrailingPathDelimiter(D) + NormalizeArchivePath(E.RelativePath);
            if E.IsDirectory then begin
              if not EnsureDirectory(Target) then raise Exception.Create('Zielordner konnte nicht angelegt werden: ' + Target);
            end else begin
              if not EnsureDirectory(ExtractFileDir(Target)) then
                raise Exception.Create('Zielpfad konnte nicht angelegt werden: ' + ExtractFileDir(Target));
              try
                FS := TFileStream.Create(Target, fmCreate);
              except
                on CreateError: Exception do
                  raise Exception.Create('Zieldatei konnte nicht erstellt werden: ' + Target + LineEnding + CreateError.Message);
              end;
              try
                Remaining := E.Size;
                while Remaining > 0 do begin
                  ProgressLabel.Caption := 'Rücksicherung: ' + E.RelativePath + ' (' + IntToStr(E.Size - Remaining) + ' / ' + IntToStr(E.Size) + ' Bytes)';
                  Application.ProcessMessages;
                  if not ReadBlock(H, Buf[0]) then raise Exception.Create('Datei konnte nicht gelesen werden.');
                  ReadNow := Min(Remaining, Int64(BLOCK_SIZE)); FS.WriteBuffer(Buf, Longint(ReadNow)); Dec(Remaining, ReadNow);
                end;
              finally FS.Free; end;
              Inc(RestoredCount);
              Log('Wiederhergestellt: ' + E.RelativePath);
            end;
          end else if not E.IsDirectory then
            for K := 1 to (E.Size + BLOCK_SIZE - 1) div BLOCK_SIZE do
              if not ReadBlock(H, Buf[0]) then raise Exception.Create('Banddaten konnten nicht übersprungen werden.');
        end;
        FoundSet := True;
      end else raise Exception.Create('Gesuchtes Backup-Set wurde nicht gefunden.');
      Inc(SetNo);
    end;
    if RestoredCount = 0 then
      raise Exception.Create('Keine der ausgewählten Dateien wurde im Backup-Satz gefunden. Es wurde nichts zurückgesichert.');
    ProgressBar.Position := ProgressBar.Max; ProgressLabel.Caption := 'Rücksicherung abgeschlossen.';
    Log('Wiederherstellung abgeschlossen.');
  except on E: Exception do begin ProgressLabel.Caption := 'Rücksicherung fehlgeschlagen.'; Log('FEHLER (' + RestoreStage + '): ' + E.Message); end; end; CloseHandle(H); SetBusy(False);
  finally SelectedPaths.Free; SelectedDirs.Free; end;
end;

procedure TMainForm.EjectClick(Sender: TObject);
var H: THandle;
  Status: DWORD;
begin
  H := OpenTape(GENERIC_READ or GENERIC_WRITE); if H = INVALID_HANDLE_VALUE then Exit;
  SetBusy(True);
  try
    ProgressLabel.Caption := 'Bitte warten: Band wird zurückgespult und ausgeworfen ...';
    Log('Bitte warten: Band wird zurückgespult und ausgeworfen ...');
    Application.ProcessMessages;
    Status := EnsureTapeReady(H, 'Band auswerfen');
    if Status <> NO_ERROR then begin
      Log('Band ist nicht bereit. Windows-Fehler: ' + IntToStr(Status));
      Exit;
    end;
    Status := PrepareTape(H, TAPE_UNLOAD, False);
    if Status = NO_ERROR then begin
      FCatalogLoaded := False;
      Log('Band ausgeworfen.');
      ProgressLabel.Caption := 'Band ausgeworfen.';
    end else begin
      Log('Auswerfen fehlgeschlagen: Windows-Fehler ' + IntToStr(Status));
      ProgressLabel.Caption := 'Auswerfen fehlgeschlagen.';
    end;
  finally
    CloseHandle(H);
    SetBusy(False);
  end;
end;

procedure TMainForm.EraseClick(Sender: TObject);
var H: THandle; Status: DWORD; TapeId: TGUID; TapeIdValid: Boolean;
begin
  if MessageDlg('ACHTUNG: Das komplette Band wird gelöscht. Alle Daten darauf gehen verloren. Fortfahren?', mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  H := OpenTape(GENERIC_READ or GENERIC_WRITE); if H = INVALID_HANDLE_VALUE then Exit;
  SetBusy(True);
  try
    Status := EnsureTapeReady(H, 'Band löschen');
    if Status <> NO_ERROR then begin
      Log('Band ist nicht bereit. Windows-Fehler: ' + IntToStr(Status));
      Exit;
    end;
    TapeIdValid := ReadTapeIdentity(H, TapeId);
    Status := PrepareTape(H, TAPE_REWIND, False);
    if Status <> NO_ERROR then begin Log('Band konnte vor dem Löschen nicht zurückgespult werden. Fehler: ' + IntToStr(Status)); Exit; end;
    Status := EraseTape(H, TAPE_ERASE_LONG, False);
    if Status = NO_ERROR then begin
      FCatalogLoaded := False;
      Log('Band wurde vollständig gelöscht.');
      if TapeIdValid then begin
        if DeleteLocalCatalog(TapeId) then
          Log('Zugehöriger lokaler SQLite-Katalog wurde gelöscht.')
        else
          Log('WARNUNG: Zugehöriger lokaler SQLite-Katalog konnte nicht gelöscht werden.');
      end;
    end else Log('Band konnte nicht gelöscht werden. Windows-Fehler: ' + IntToStr(Status));
  finally CloseHandle(H); SetBusy(False); end;
end;

end.
