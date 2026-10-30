{ Classic main-window interactions. Included in mainform.pas. }
procedure TMainForm.RebuildNavigation;
var Doc: TDocument; I, P: Integer; Scope, SymbolName, PreviousScope: string; Root, Node: TTreeNode;
  Started: QWord;
begin
  if FUpdatingNavigation or (FScopeCombo = nil) or (FClassTree = nil) then Exit;
  FUpdatingNavigation := True;
  Started := GetTickCount64;
  try
    FNavigationDirty := False;
    PreviousScope := '(globals)';
    if FScopeCombo.ItemIndex >= 0 then PreviousScope := FScopeCombo.Items[FScopeCombo.ItemIndex];
    Doc := CurrentDoc;
    FSymbols.Clear;
    FClassTree.Items.Clear;
    FScopeCombo.Items.Clear;
    FScopeCombo.Items.Add('(globals)');
    FScopeCombo.Enabled := CodeDocument(Doc);
    FFunctionCombo.Enabled := CodeDocument(Doc);
    if CodeDocument(Doc) then
    begin
      CollectSourceSymbols(Doc.Editor.Lines, FSymbols);
    end;
    for I := 0 to FSymbols.Count - 1 do
    begin
      P := Pos('|', FSymbols[I]);
      Scope := Copy(FSymbols[I], 1, P - 1);
      SymbolName := Copy(FSymbols[I], P + 1, MaxInt);
      if Scope = '' then Scope := '(globals)';
      if FScopeCombo.Items.IndexOf(Scope) < 0 then FScopeCombo.Items.Add(Scope);
      Root := FClassTree.Items.GetFirstNode;
      while (Root <> nil) and (Root.Text <> Scope) do Root := Root.GetNextSibling;
      if Root = nil then Root := FClassTree.Items.Add(nil, Scope);
      if SymbolName <> '' then
      begin
        Node := FClassTree.Items.AddChild(Root, SymbolName + '()');
        Node.Data := Pointer(PtrInt(FSymbols.Objects[I]));
      end
      else Root.Data := Pointer(PtrInt(FSymbols.Objects[I]));
    end;
    FScopeCombo.ItemIndex := Max(0, FScopeCombo.Items.IndexOf(PreviousScope));
    FClassTree.FullExpand;
  finally FUpdatingNavigation := False; end;
  ScopeChanged(Self);
  UpdateStatus;
  SetStatusMessage(Format(Tr('Parsed in %.3f s'), [(GetTickCount64 - Started) / 1000]));
end;

procedure TMainForm.ScopeChanged(Sender: TObject);
var I, P: Integer; Scope, SymbolName: string;
begin
  if FLoading or FUpdatingNavigation or (FSymbols = nil) then Exit;
  FUpdatingNavigation := True;
  try
    FFunctionCombo.Items.Clear;
    if FScopeCombo.ItemIndex < 0 then Exit;
    for I := 0 to FSymbols.Count - 1 do
    begin
      P := Pos('|', FSymbols[I]);
      Scope := Copy(FSymbols[I], 1, P - 1);
      SymbolName := Copy(FSymbols[I], P + 1, MaxInt);
      if Scope = '' then Scope := '(globals)';
      if (Scope = FScopeCombo.Items[FScopeCombo.ItemIndex]) and (SymbolName <> '') then
        FFunctionCombo.Items.AddObject(SymbolName + '()', FSymbols.Objects[I]);
    end;
    FFunctionCombo.ItemIndex := -1;
  finally FUpdatingNavigation := False; end;
end;

procedure TMainForm.FunctionChanged(Sender: TObject);
var Doc: TDocument; Line: Integer;
begin
  if FUpdatingNavigation or (FFunctionCombo.ItemIndex < 0) then Exit;
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  Line := PtrInt(FFunctionCombo.Items.Objects[FFunctionCombo.ItemIndex]);
  Doc.Editor.CaretXY := Point(1, Line);
  Doc.Editor.EnsureCursorPosVisible;
  Doc.Editor.SetFocus;
  UpdateStatus;
end;

procedure TMainForm.ClassDoubleClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (FClassTree.Selected = nil) or (FClassTree.Selected.Data = nil) then Exit;
  Doc.Editor.CaretXY := Point(1, PtrInt(FClassTree.Selected.Data));
  Doc.Editor.EnsureCursorPosVisible;
  Doc.Editor.SetFocus;
end;

procedure TMainForm.ResourceDoubleClick(Sender: TObject);
var Index: Integer;
begin
  if FResourceTree.Selected = nil then Exit;
  Index := PtrInt(FResourceTree.Selected.Data);
  if (Index >= 0) and (Index < FProjectFiles.Count) then OpenFile(FProjectFiles[Index]);
end;

procedure TMainForm.ReportChanged(Sender: TObject);
begin
  if FReportTabs.ActivePage=FDebugTab then InitializeDebugger;
  if (FCloseReportTab <> nil) and (FReportTabs.ActivePage = FCloseReportTab) then
    Application.QueueAsyncCall(@HideReportAsync, 0)
  else FLastReportTab := FReportTabs.ActivePage;
end;

procedure TMainForm.HideReportAsync(Data: PtrInt);
begin
  { Finish GTK's notebook activation before restoring the previous page and
    hiding its parent; otherwise the activation can show the report again. }
  FReportTabs.ActivePage := FLastReportTab;
  FBottomPanel.Hide;
  FReportSplitter.Hide;
end;

procedure TMainForm.ToggleReportClick(Sender: TObject);
begin
  FBottomPanel.Visible := not FBottomPanel.Visible;
  FReportSplitter.Visible := FBottomPanel.Visible;
end;

procedure TMainForm.ShortenPathsChanged(Sender: TObject);
var LogDisplay: string;
begin
  if FCompileLogRaw = '' then Exit;
  LogDisplay := FCompileLogRaw;
  if FShortenPaths.Checked and (FCompileDirectory <> '') then
    LogDisplay := StringReplace(LogDisplay, IncludeTrailingPathDelimiter(FCompileDirectory), '', [rfReplaceAll]);
  FOutput.Text := LogDisplay;
end;

procedure TMainForm.StopExecuteClick(Sender: TObject);
begin
  if FCompileActive then AbortCompileClick(Sender)
  else DebugStopClick(Sender);
end;

procedure TMainForm.ToggleFirstBookmarkClick(Sender: TObject);
var Doc: TDocument; X, Y: Integer;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  if Doc.Editor.GetBookMark(1, X, Y) then Doc.Editor.ClearBookMark(1)
  else Doc.Editor.SetBookMark(1, Doc.Editor.CaretX, Doc.Editor.CaretY);
end;

procedure TMainForm.GotoFirstBookmarkClick(Sender: TObject);
begin
  if CurrentDoc <> nil then CurrentDoc.Editor.GotoBookMark(1);
end;

procedure TMainForm.PropertiesClick(Sender: TObject);
var Doc: TDocument; SymbolName: string;
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@PropertiesClick); Exit; end;
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  SymbolName := Doc.FileName;
  if SymbolName = '' then SymbolName := Doc.UntitledName;
  UiMessageDlg(SymbolName + LineEnding + Tr('Lines') + ': ' + IntToStr(Doc.Editor.Lines.Count) +
    LineEnding + Tr('Length') + ': ' + IntToStr(UTF8Length(Doc.Editor.Text)), mtInformation, [mbOK], 0);
end;

procedure TMainForm.FormatOptionsClick(Sender: TObject);
var Source:string;
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@FormatOptionsClick);Exit;end;
  Source:='int main(){return 0;}';if CurrentDoc<>nil then Source:=CurrentDoc.Editor.Text;
  EditFormatOptions(Self,FOptionsPath,Source);
end;
procedure TMainForm.FormatClick(Sender:TObject);
var Doc:TDocument;Formatted:string;
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@FormatClick);Exit;end;
  Doc:=CurrentDoc;if not CodeDocument(Doc) or Doc.Editor.ReadOnly or FCompileActive or DebuggerActive then Exit;
  try
    Formatted:=FormatSource(Doc.Editor.Text,FormatArguments(FOptionsPath));
    if Formatted<>Doc.Editor.Text then begin
      Doc.Editor.BeginUndoBlock;
      try Doc.Editor.SelectAll;Doc.Editor.SelText:=Copy(Formatted,1,Length(Formatted)-Length(LineEnding));finally Doc.Editor.EndUndoBlock;end;
    end;
  except on E:Exception do UiMessageDlg(E.Message,mtError,[mbOK],0);end;
end;

procedure TMainForm.PrintClick(Sender: TObject);
var Doc: TDocument;
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@PrintClick); Exit; end;
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  try PrintSourceText(Doc.Editor.Text, Doc.Tab.Caption, False);
  except on E: Exception do UiMessageDlg(E.Message, mtError, [mbOK], 0); end;
end;
procedure TMainForm.PrintSetupClick(Sender: TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@PrintSetupClick); Exit; end;
  try PrintSourceText('', AppName, True);
  except on E: Exception do UiMessageDlg(E.Message, mtError, [mbOK], 0); end;
end;
procedure TMainForm.ExportHtmlClick(Sender: TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@ExportHtmlClick); Exit; end;
  ExportSource('html');
end;
procedure TMainForm.ExportRtfClick(Sender: TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@ExportRtfClick); Exit; end;
  ExportSource('rtf');
end;
procedure TMainForm.ExportTexClick(Sender: TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@ExportTexClick); Exit; end;
  ExportSource('tex');
end;
procedure TMainForm.ExportSource(const Kind: string);
var Doc: TDocument; Dialog: TSaveDialog; Lines: TStringList;
  Snapshot, Saved: TFileSnapshot;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  Dialog := TSaveDialog.Create(Self);
  Lines := TStringList.Create;
  try
    Dialog.DefaultExt := Kind;
    Dialog.Filter := UpperCase(Kind) + '|*.' + Kind;
    Dialog.FileName := ChangeFileExt(Doc.Tab.Caption, '.' + Kind);
    Dialog.Options := Dialog.Options + [ofOverwritePrompt];
    if not Dialog.Execute then Exit;
    if FindDoc(Dialog.FileName) <> nil then raise Exception.Create(Tr('Cannot overwrite an open document.'));
    if (FProjectPath <> '') and SameDocumentPath(Dialog.FileName, FProjectPath) then
      raise Exception.Create(Tr('Cannot overwrite the active project.'));
    Snapshot := CaptureFileSnapshot(Dialog.FileName);
    Lines.Text := ExportSourceText(Doc.Editor.Text, Doc.Tab.Caption, Kind);
    AtomicSaveDocumentChecked(Lines, Dialog.FileName, Snapshot, Saved);
  finally Lines.Free; Dialog.Free; end;
end;

procedure TMainForm.SearchResultDoubleClick(Sender: TObject);
var Entry: TListItem; Doc: TDocument;
begin
  Entry := FSearchList.Selected;
  if (Entry = nil) or (Entry.SubItems.Count < 3) then Exit;
  Doc := TDocument(Entry.Data);
  if (Doc = nil) or (FDocs.IndexOf(Doc) < 0) then Exit;
  FPages.ActivePage := Doc.Tab;
  Doc.Editor.LogicalCaretXY := Point(StrToIntDef(Entry.SubItems[0], 1), StrToIntDef(Entry.Caption, 1));
  Doc.Editor.EnsureCursorPosVisible;
  Doc.Editor.SetFocus;
end;

procedure TMainForm.AssignMenuIcons(Item: TMenuItem);
var I, J: Integer; Button: TToolButton; IconName, IconPath: string; Bitmap: TBitmap;
begin
  if Assigned(Item.OnClick) and (FMainToolbar <> nil) then
    for J := 0 to FMainToolbar.ButtonCount - 1 do
    begin
      Button := FMainToolbar.Buttons[J];
      if SameHandler(Item.OnClick, Button.OnClick) then Item.ImageIndex := Button.ImageIndex;
    end;
  IconName := '';
  if SameHandler(Item.OnClick, @CompilerOptionsClick) then IconName := 'compopt';
  if SameHandler(Item.OnClick, @EnvironmentOptionsClick) then IconName := 'envopt';
  if SameHandler(Item.OnClick, @EditorOptionsClick) then IconName := 'editopt';
  if SameHandler(Item.OnClick, @ShortcutOptionsClick) then IconName := 'run';
  if SameHandler(Item.OnClick, @ConfigureToolsClick) then IconName := 'tools';
  if SameHandler(Item.OnClick, @PackageManagerClick) then IconName := 'packman';
  if SameHandler(Item.OnClick, @SaveAsClick) then IconName := 'saveas';
  if SameHandler(Item.OnClick, @ExportHtmlClick) or SameHandler(Item.OnClick, @ExportRtfClick) or
    SameHandler(Item.OnClick, @ExportTexClick) then IconName := 'export';
  if SameHandler(Item.OnClick, @ClearRecentClick) then IconName := 'clrhist';
  if SameHandler(Item.OnClick, @NewClick) then IconName := 'newsrc';
  if SameHandler(Item.OnClick, @NewProjectClick) then IconName := 'newproj';
  if SameHandler(Item.OnClick, @CloseClick) then IconName := 'closefl';
  if SameHandler(Item.OnClick, @CloseAllClick) then IconName := 'clsall';
  if SameHandler(Item.OnClick, @CloseProjectClick) or SameHandler(Item.OnClick, @ExitClick) then IconName := 'close';
  if SameHandler(Item.OnClick, @CutClick) then IconName := 'cut';
  if SameHandler(Item.OnClick, @CopyClick) then IconName := 'copy';
  if SameHandler(Item.OnClick, @PasteClick) then IconName := 'paste';
  if IconName <> '' then
  begin
    IconPath := ExtractFilePath(ParamStr(0)) + 'icons/' + IconName + '.bmp';
    if FileExists(IconPath) then
    begin
      Bitmap := TBitmap.Create;
      try
        Bitmap.LoadFromFile(IconPath);
        Item.ImageIndex := FMenuImages.AddMasked(Bitmap, clFuchsia);
      finally Bitmap.Free; end;
    end;
  end;
  for I := 0 to Item.Count - 1 do AssignMenuIcons(Item.Items[I]);
end;

function TMainForm.LoadUiIcon(const IconName: string): Integer;
var IconPath: string; Bitmap: TBitmap;
begin
  Result := -1;
  IconPath := ExtractFilePath(ParamStr(0)) + 'icons/' + IconName + '.bmp';
  if not FileExists(IconPath) then Exit;
  Bitmap := TBitmap.Create;
  try
    Bitmap.LoadFromFile(IconPath);
    Result := FMenuImages.AddMasked(Bitmap, clFuchsia);
  finally Bitmap.Free; end;
end;

procedure TMainForm.NavigationDropDown(Sender: TObject);
begin
  if FNavigationDirty then RebuildNavigation;
end;

procedure TMainForm.ClassicResize(Sender: TObject);
var ComboWidth: Integer;
begin
  if FCompilerProfileCombo <> nil then
    FCompilerProfileCombo.Width := Min(250, Max(120, ClientWidth - FCompilerProfileCombo.Left - 8));
  if (FScopeCombo = nil) or (FFunctionCombo = nil) then Exit;
  ComboWidth := Min(350, Max(140, (ClientWidth - 100) div 2));
  FScopeCombo.Width := ComboWidth;
  FFunctionCombo.Left := FScopeCombo.Left + ComboWidth;
  FFunctionCombo.Width := ComboWidth;
end;

procedure TMainForm.LoadEnvironmentSettings;
var Ini: TIniFile;
begin
  Ini := TIniFile.Create(FOptionsPath);
  try
    FDefaultDirectory:=Ini.ReadString('Interface','DefaultDirectory','');
    Font.Name:=Ini.ReadString('Interface','Font','Sans');Font.Size:=EnsureRange(Ini.ReadInteger('Interface','FontSize',9),7,24);
    if Ini.ReadBool('Interface','ReportTabsBottom',False) then FReportTabs.TabPosition:=tpBottom else FReportTabs.TabPosition:=tpTop;
    FFileWatchTimer.Enabled := Ini.ReadBool('Interface', 'WatchFiles', True);
    FBottomPanel.Visible := Ini.ReadBool('Interface', 'ShowReports', True);
    FReportSplitter.Visible := FBottomPanel.Visible;
    FCustomToolItem.Caption := StringReplace(Ini.ReadString('ExternalTool', 'Name', Tr('External tool')),'&','&&',[rfReplaceAll]);
    if Trim(FCustomToolItem.Caption) = '' then FCustomToolItem.Caption := Tr('External tool');
    FCustomToolItem.Visible := Trim(Ini.ReadString('ExternalTool', 'Executable', '')) <> '';
  finally Ini.Free; end;
end;
procedure TMainForm.EnvironmentOptionsClick(Sender: TObject);
var Language: string; WatchFiles, Reports: Boolean; Ini: TIniFile; I: Integer;
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@EnvironmentOptionsClick); Exit; end;
  Language := CurrentUiLanguage; WatchFiles := FFileWatchTimer.Enabled; Reports := FBottomPanel.Visible;
  if not EditClassicEnvironment(Self,FOptionsPath,Language,FEditorThemeName,WatchFiles,Reports) then Exit;
  Ini := TIniFile.Create(FOptionsPath);
  try
    Ini.WriteString('Editor','Theme',FEditorThemeName);
    Ini.WriteBool('Interface', 'WatchFiles', WatchFiles);
    Ini.WriteBool('Interface', 'ShowReports', Reports);
  finally Ini.Free; end;
  LoadEnvironmentSettings;ApplyAllEditorSettings;
  SetUiLanguage(Language); ApplyUiLanguage(Self);
  for I := 0 to FLanguageMenu.Count - 1 do
    FLanguageMenu.Items[I].Checked := CurrentUiLanguage = UiLanguageCode(FLanguageMenu.Items[I].Tag);
  FFileWatchTimer.Enabled := WatchFiles; FBottomPanel.Visible := Reports; FReportSplitter.Visible := Reports;
  if FDebugger <> nil then FDebugger.RefreshBreakpoints;
  UpdateStatus;
end;
procedure TMainForm.ShortcutOptionsClick(Sender: TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@ShortcutOptionsClick); Exit; end;
  if FMenuShortcuts <> nil then FMenuShortcuts.Edit(Self, FOptionsPath);
end;
procedure TMainForm.ConfigureToolsClick(Sender: TObject);
var Values, Args: TStringList; Ini: TIniFile; I: Integer; ErrorText: string;
const Names: array[0..3] of string = ('Name', 'Executable', 'Arguments', 'Working directory');
  Keys: array[0..3] of string = ('Name', 'Executable', 'Arguments', 'Directory');
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@ConfigureToolsClick); Exit; end;
  Values := TStringList.Create; Args := TStringList.Create; Ini := TIniFile.Create(FOptionsPath);
  try
    for I := 0 to 3 do Values.Add(Tr(Names[I]) + '=' + Ini.ReadString('ExternalTool', Keys[I], ''));
    while EditSettingValues(Self, 'Configure Tools', Values) do begin
      if not ParseRunArguments(Values.ValueFromIndex[2], Args, ErrorText) then begin
        UiMessageDlg(Tr(ErrorText), mtError, [mbOK], 0); Continue;
      end;
      for I := 0 to 3 do Ini.WriteString('ExternalTool', Keys[I], Values.ValueFromIndex[I]);
      LoadEnvironmentSettings; Break;
    end;
  finally Ini.Free; Args.Free; Values.Free; end;
end;
procedure TMainForm.RunCustomToolClick(Sender: TObject);
var Ini: TIniFile; Args: TStringList; Proc: TProcess; ErrorText, DirectoryName: string;
  I: Integer; Doc: TDocument; ToolName: string;
  function ExpandArgument(const Value: string): string;
  begin
    Result := Value;
    if Doc <> nil then begin
      Result := StringReplace(Result, '%FILE%', Doc.FileName, [rfReplaceAll]);
      Result := StringReplace(Result, '%DIR%', ExtractFileDir(Doc.FileName), [rfReplaceAll]);
    end;
  end;
begin
  Ini := TIniFile.Create(FOptionsPath); Args := TStringList.Create; Proc := TProcess.Create(nil); Doc := CurrentDoc;
  try
    try
      ToolName := FindDefaultExecutablePath(Ini.ReadString('ExternalTool', 'Executable', ''));
      if ToolName = '' then raise Exception.Create(Tr('External tool executable not found.'));
      { FPC 3.0.4 StrNew('') truncates TProcess argv at an empty argument.
        Prefix every tool argument and remove the prefix in an exec bridge;
        arguments remain literal, including empty strings and shell symbols. }
      Proc.Executable := '/usr/bin/python3';
      Proc.Parameters.Add('-c');
      Proc.Parameters.Add('import os,sys; os.execv(sys.argv[1], [sys.argv[1]] + [x[1:] for x in sys.argv[2:]])');
      Proc.Parameters.Add(ToolName);
      if not ParseRunArguments(Ini.ReadString('ExternalTool', 'Arguments', ''), Args, ErrorText) then
        raise Exception.Create(Tr(ErrorText));
      for I := 0 to Args.Count - 1 do Proc.Parameters.Add(':' + ExpandArgument(Args[I]));
      DirectoryName := ExpandArgument(Ini.ReadString('ExternalTool', 'Directory', ''));
      if DirectoryName <> '' then Proc.CurrentDirectory := DirectoryName;
      Proc.Execute;
    except on E: Exception do UiMessageDlg(E.Message, mtError, [mbOK], 0); end;
  finally Proc.Free; Args.Free; Ini.Free; end;
end;
procedure TMainForm.PackageManagerClick(Sender: TObject);
var Dialog: TOpenDialog;
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@PackageManagerClick); Exit; end;
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := Tr('Open a Debian package with the system installer');
    Dialog.Filter := 'Debian packages (*.deb)|*.deb';
    Dialog.Options := [ofFileMustExist, ofEnableSizing];
    if Dialog.Execute and not OpenDocument(Dialog.FileName) then
      UiMessageDlg(Tr('Could not open the system package installer.'), mtError, [mbOK], 0);
  finally Dialog.Free; end;
end;

procedure TMainForm.RebuildInsertMenu;
var I: Integer; Item:TMenuItem;
begin
  if FInsertMenu=nil then Exit;
  FInsertMenu.Clear;
  AddMenu(FInsertMenu,'Date/time',@InsertDateClick);
  if FEditorPreferences.Snippets.Count>0 then AddMenu(FInsertMenu,'-',nil);
  for I:=0 to FEditorPreferences.Snippets.Count-1 do begin
    Item:=AddMenu(FInsertMenu,'',@InsertSnippetClick);Item.Tag:=I;
    Item.Name:='UserText_Insert_'+IntToStr(I);
    Item.Caption:=StringReplace(FEditorPreferences.Snippets.Names[I],'&','&&',[rfReplaceAll]);
  end;
end;
procedure TMainForm.InsertDateClick(Sender:TObject);
begin if (CurrentDoc<>nil) and not CurrentDoc.Editor.ReadOnly then CurrentDoc.Editor.SelText:=FormatDateTime('yyyy-mm-dd hh:nn:ss',Now);end;
procedure TMainForm.InsertSnippetClick(Sender:TObject);
var I:Integer;
begin
  if not (Sender is TMenuItem) or (CurrentDoc=nil) or CurrentDoc.Editor.ReadOnly then Exit;
  I:=TMenuItem(Sender).Tag;
  if (I>=0) and (I<FEditorPreferences.Snippets.Count) then CurrentDoc.Editor.SelText:=FEditorPreferences.Snippets.ValueFromIndex[I];
end;
procedure TMainForm.IndentClick(Sender:TObject);
begin if (CurrentDoc<>nil) and not CurrentDoc.Editor.ReadOnly then CurrentDoc.Editor.CommandProcessor(ecBlockIndent,#0,nil);end;
procedure TMainForm.UnindentClick(Sender:TObject);
begin if (CurrentDoc<>nil) and not CurrentDoc.Editor.ReadOnly then CurrentDoc.Editor.CommandProcessor(ecBlockUnindent,#0,nil);end;
procedure TMainForm.FoldAllClick(Sender:TObject);
begin if CurrentDoc<>nil then CurrentDoc.Editor.FoldAll;end;
procedure TMainForm.UnfoldAllClick(Sender:TObject);
begin if CurrentDoc<>nil then CurrentDoc.Editor.UnfoldAll;end;
procedure TMainForm.SaveRecoveryCopies;
var I:Integer;Doc:TDocument;Folder,BaseName,RecoveryFile,Extension:string;ID:TGUID;Snapshot:TFileSnapshot;
begin
  if (FEditorPreferences=nil) or not (efAutoSave in FEditorPreferences.Flags) or
    FLoading or FCompileActive or DebuggerActive or (FDocumentDialogs<>0) or
    (Application.ModalLevel>0) or (GetTickCount64-FLastRecoveryAt<QWord(FEditorPreferences.AutoSaveSeconds)*1000) then Exit;
  FLastRecoveryAt:=GetTickCount64;
  Folder:=GetEnvironmentVariable('XDG_CACHE_HOME');
  if (Folder='') or (Folder[1]<>'/') then Folder:=GetEnvironmentVariable('HOME')+'/.cache';
  Folder:=IncludeTrailingPathDelimiter(Folder)+'dev-cpp/autosave/';
  try
    if not ForceDirectories(Folder) then raise Exception.Create('Cannot create recovery directory.');
    for I:=0 to FDocs.Count-1 do begin
      Doc:=TDocument(FDocs[I]);if not Doc.Dirty then Continue;
      if (FEditorPreferences.AutoSaveScope=0) and (Doc<>CurrentDoc) then Continue;
      if (FEditorPreferences.AutoSaveScope=2) and (FProjectFiles.IndexOf(Doc.FileName)<0) then Continue;
      if Doc.RecoveryPath='' then begin
        CreateGUID(ID);BaseName:=ChangeFileExt(ExtractFileName(Doc.FileName),'');if BaseName='' then BaseName:=Doc.UntitledName;
        Extension:=ExtractFileExt(Doc.FileName);if Extension='' then Extension:='.cpp';
        Doc.RecoveryPath:=Folder+BaseName+'-'+GUIDToString(ID)+Extension;
      end;
      RecoveryFile:=Doc.RecoveryPath;
      if FEditorPreferences.AutoSaveNaming=1 then RecoveryFile:=ChangeFileExt(RecoveryFile,'')+'-'+IntToStr(DateTimeToUnix(LocalTimeToUniversal(Now)))+'-'+IntToStr(GetTickCount64)+ExtractFileExt(RecoveryFile);
      if FEditorPreferences.AutoSaveNaming=2 then RecoveryFile:=ChangeFileExt(RecoveryFile,'')+'-'+FormatDateTime('yyyymmdd-hhnnss-zzz',Now)+ExtractFileExt(RecoveryFile);
      AtomicSaveDocumentChecked(Doc.Editor.Lines,RecoveryFile,CaptureFileSnapshot(RecoveryFile),Snapshot);
    end;
  except on E:Exception do SetStatusMessage(Tr('Recovery copy failed: ')+E.Message);end;
end;

procedure TMainForm.ToggleToolbarClick(Sender:TObject);
var Item:TMenuItem;
begin
  Item:=TMenuItem(Sender);Item.Checked:=not Item.Checked;
  case Item.Tag of 0:FMainToolbar.Visible:=Item.Checked;1:FNavigationBar.Visible:=Item.Checked;2:FCompilerProfileCombo.Visible:=Item.Checked;end;
end;
procedure TMainForm.PrepareWindowMenu(Sender:TObject);
var I:Integer;Item:TMenuItem;Doc:TDocument;NameText:string;
begin
  while FWindowMenu.Count>7 do FWindowMenu.Items[FWindowMenu.Count-1].Free;
  for I:=0 to FDocs.Count-1 do begin
    Doc:=TDocument(FDocs[I]);NameText:=Doc.FileName;if NameText='' then NameText:=Doc.UntitledName;
    Item:=TMenuItem.Create(Self);Item.Name:='UserText_Window'+IntToStr(I);
    Item.Caption:=IntToStr(I)+' '+StringReplace(NameText,'&','&&',[rfReplaceAll]);Item.Tag:=PtrInt(Doc);
    Item.OnClick:=@WindowDocumentClick;Item.Checked:=Doc=CurrentDoc;FWindowMenu.Add(Item);
  end;
  Item:=TMenuItem.Create(Self);Item.Caption:=Tr('List...');Item.OnClick:=@WindowListClick;FWindowMenu.Add(Item);
end;
procedure TMainForm.WindowDocumentClick(Sender:TObject);
var Doc:TDocument;
begin
  Doc:=TDocument(TMenuItem(Sender).Tag);if FDocs.IndexOf(Doc)<0 then Exit;
  FPages.ActivePage:=Doc.Tab;Doc.Editor.SetFocus;
end;
procedure TMainForm.WindowListClick(Sender:TObject);
var D:TForm;List:TListBox;B:TButton;I:Integer;Doc:TDocument;NameText:string;
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@WindowListClick);Exit;end;
  D:=TForm.CreateNew(Self);Inc(FDocumentDialogs);
  try
    D.Caption:=Tr('Open files');D.Position:=poMainFormCenter;D.BorderStyle:=bsDialog;D.ClientWidth:=600;D.ClientHeight:=360;
    List:=TListBox.Create(D);List.Parent:=D;List.SetBounds(10,10,580,300);
    for I:=0 to FDocs.Count-1 do begin Doc:=TDocument(FDocs[I]);NameText:=Doc.FileName;if NameText='' then NameText:=Doc.UntitledName;List.Items.AddObject(NameText,Doc);if Doc=CurrentDoc then List.ItemIndex:=I;end;
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(390,320,94,28);B.Caption:=Tr('OK');B.ModalResult:=mrOK;B.Default:=True;
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(494,320,96,28);B.Caption:=Tr('Cancel');B.ModalResult:=mrCancel;B.Cancel:=True;
    if (D.ShowModal=mrOK) and (List.ItemIndex>=0) then begin Doc:=TDocument(List.Items.Objects[List.ItemIndex]);FPages.ActivePage:=Doc.Tab;Doc.Editor.SetFocus;end;
  finally Dec(FDocumentDialogs);D.Free;end;
end;
procedure TMainForm.GotoBreakpointClick(Sender:TObject);
var BP:TGdbBreakpoint;Doc:TDocument;
begin
  if (FDebugger=nil) or (FDebugger.Session.Breakpoints.Count=0) then Exit;
  BP:=TGdbBreakpoint(FDebugger.Session.Breakpoints[0]);OpenFile(BP.FileName);Doc:=FindDoc(BP.FileName);
  if Doc<>nil then begin Doc.Editor.CaretXY:=Point(1,BP.Line);Doc.Editor.EnsureCursorPosVisible;Doc.Editor.SetFocus;end;
end;
