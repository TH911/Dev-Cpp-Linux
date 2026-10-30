{ Unified 5.11-style search pages; all offsets stay in original UTF-8 bytes. }
function TMainForm.SearchOffset(Doc:TDocument;P:TPoint):Integer;
var I:Integer;
begin
  Result:=1;
  for I:=0 to Min(P.Y-2,Doc.Editor.Lines.Count-1) do Inc(Result,Length(Doc.Editor.Lines[I])+Length(LineEnding));
  if (P.Y>=1) and (P.Y<=Doc.Editor.Lines.Count) then Inc(Result,Max(0,P.X-1));
end;
function TMainForm.SearchPoint(Doc:TDocument;Offset:Integer):TPoint;
var I,N:Integer;
begin
  Offset:=Max(1,Offset);
  for I:=0 to Doc.Editor.Lines.Count-1 do begin
    N:=Length(Doc.Editor.Lines[I])+Length(LineEnding);
    if Offset<=N then Exit(Point(Min(Offset,Length(Doc.Editor.Lines[I])+1),I+1));
    Dec(Offset,N);
  end;
  Result:=Point(1,Max(1,Doc.Editor.Lines.Count));
end;
procedure TMainForm.FindClick(Sender:TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@FindClick);Exit;end;
  SearchDialogAction(smFind);
end;
procedure TMainForm.FindAllClick(Sender:TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@FindAllClick);Exit;end;
  SearchDialogAction(smFindFiles);
end;
procedure TMainForm.ReplaceClick(Sender:TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@ReplaceClick);Exit;end;
  SearchDialogAction(smReplace);
end;
procedure TMainForm.ReplaceAllClick(Sender:TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@ReplaceAllClick);Exit;end;
  SearchDialogAction(smReplaceFiles);
end;
procedure TMainForm.SearchDialogAction(Mode:TSearchMode);
var Doc:TDocument;Proposed:TClassicSearchSpec;Accepted:Boolean;
begin
  Doc:=CurrentDoc;if (Doc=nil) or FCompileActive or (FDocumentDialogs<>0) then Exit;
  if not FSearchInitialized then begin
    FSearchFirst:=False;FSearchSpec.FromCaret:=True;FSearchSpec.Scope:=scOpen;FSearchInitialized:=True;
  end;
  Proposed:=FSearchSpec;Proposed.Mode:=Mode;Proposed.Query:=FFindText;
  if Doc.Editor.SelAvail and (Pos(#10,Doc.Editor.SelText)=0) and (Pos(#13,Doc.Editor.SelText)=0) then Proposed.Query:=Doc.Editor.SelText
  else if (Proposed.Query='') and (efFindAtCursor in FEditorPreferences.Flags) then Proposed.Query:=Doc.Editor.GetWordAtRowCol(Doc.Editor.LogicalCaretXY);
  Inc(FDocumentDialogs);
  try Accepted:=EditSearch(Self,Proposed,Doc.Editor.SelAvail,FProjectPath<>'');finally Dec(FDocumentDialogs);end;
  if not Accepted or (FDocs.IndexOf(Doc)<0) then Exit;
  FSearchSpec:=Proposed;FFindText:=Proposed.Query;FSearchFirst:=True;
  if Proposed.SelectedOnly and Doc.Editor.SelAvail then begin
    FSearchScopeDoc:=Doc;FSearchBegin:=Doc.Editor.BlockBegin;FSearchEnd:=Doc.Editor.BlockEnd;
  end else FSearchScopeDoc:=nil;
  case Proposed.Mode of
    smFind:LocateSearch(Doc,Proposed.Backward);
    smFindFiles:SearchFiles(False);
    smReplace:ReplaceSearch(Doc,False);
    smReplaceFiles:SearchFiles(True);
  end;
end;
procedure TMainForm.FindNextClick(Sender:TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@FindNextClick);Exit;end;
  LocateSearch(CurrentDoc,FSearchSpec.Backward);
end;
procedure TMainForm.FindPreviousClick(Sender:TObject);
begin
  if Sender is TMenuItem then begin QueueMenuDialog(@FindPreviousClick);Exit;end;
  LocateSearch(CurrentDoc,not FSearchSpec.Backward);
end;
function TMainForm.LocateSearch(Doc:TDocument;Backward:Boolean):Boolean;
var ContentText:string;Lo,Hi,Start,Pass,A,B,Found,N:Integer;
begin
  Result:=False;if (Doc=nil) or (FFindText='') then Exit;
  ContentText:=Doc.Editor.Text;Lo:=1;Hi:=Length(ContentText)+1;
  if FSearchSpec.SelectedOnly and (FSearchScopeDoc=Doc) then begin Lo:=SearchOffset(Doc,FSearchBegin);Hi:=SearchOffset(Doc,FSearchEnd);end;
  Start:=SearchOffset(Doc,Doc.Editor.LogicalCaretXY);
  if Backward then begin
    if Doc.Editor.SelAvail then Start:=SearchOffset(Doc,Doc.Editor.BlockBegin);
    Dec(Start);
  end;
  if FSearchFirst and not FSearchSpec.FromCaret then begin if Backward then Start:=Hi-1 else Start:=Lo;end;
  FSearchFirst:=False;
  for Pass:=0 to 1 do begin
    if not Backward then begin
      if Pass=0 then begin A:=Max(Lo,Start);B:=Hi-1;end else begin A:=Lo;B:=Min(Hi-1,Start-1);end;
      Found:=FindTextForward(ContentText,FFindText,A,B,N,FSearchSpec.MatchCase,FSearchSpec.WholeWord);
    end else begin
      if Pass=0 then begin A:=Lo;B:=Min(Hi-1,Start);end else begin A:=Max(Lo,Start+1);B:=Hi-1;end;
      Found:=FindTextBackward(ContentText,FFindText,A,B,N,FSearchSpec.MatchCase,FSearchSpec.WholeWord);
    end;
    if (Found>0) and (Found+N<=Hi) then begin
      FPages.ActivePage:=Doc.Tab;Doc.Editor.BlockBegin:=SearchPoint(Doc,Found);
      Doc.Editor.BlockEnd:=SearchPoint(Doc,Found+N);Doc.Editor.LogicalCaretXY:=SearchPoint(Doc,Found+N);
      Doc.Editor.EnsureCursorPosVisible;Doc.Editor.SetFocus;Exit(True);
    end;
  end;
  SetStatusMessage(Format(Tr('Text not found: %s'),[FFindText]));
end;
function TMainForm.ReplaceSearch(Doc:TDocument;All:Boolean):Integer;
var ContentText,NewText:string;Lo,Hi,At,N,Match,Answer,OldOffset:Integer;
  Pieces:TStringStream;StopNow:Boolean;
begin
  Result:=0;if (Doc=nil) or Doc.Editor.ReadOnly or (FFindText='') then Exit;
  ContentText:=Doc.Editor.Text;Lo:=1;Hi:=Length(ContentText)+1;
  if FSearchSpec.SelectedOnly and (FSearchScopeDoc=Doc) then begin Lo:=SearchOffset(Doc,FSearchBegin);Hi:=SearchOffset(Doc,FSearchEnd);end;
  if not All then begin
    Match:=0;
    if Doc.Editor.SelAvail then begin
      At:=SearchOffset(Doc,Doc.Editor.BlockBegin);N:=FindTextMatchLengthAt(ContentText,FFindText,At,FSearchSpec.MatchCase,FSearchSpec.WholeWord);
      if (N>0) and (N=Length(Doc.Editor.SelText)) and (At>=Lo) and (At+N<=Hi) then Match:=At;
    end;
    if (Match=0) and not LocateSearch(Doc,FSearchSpec.Backward) then Exit;
    if FSearchSpec.Prompt and (UiMessageDlg(Tr('Replace this occurrence?'),mtConfirmation,[mbYes,mbNo],0)<>mrYes) then Exit;
    N:=Length(Doc.Editor.SelText);Doc.Editor.BeginUndoBlock;
    try Doc.Editor.SelText:=FSearchSpec.Replacement;finally Doc.Editor.EndUndoBlock;end;
    if FSearchScopeDoc=Doc then FSearchEnd:=SearchPoint(Doc,Hi+Length(FSearchSpec.Replacement)-N);
    Result:=1;LocateSearch(Doc,FSearchSpec.Backward);Exit;
  end;
  OldOffset:=SearchOffset(Doc,Doc.Editor.LogicalCaretXY);Pieces:=TStringStream.Create('');At:=Lo;StopNow:=False;
  Inc(FDocumentDialogs);
  try
    Pieces.WriteString(Copy(ContentText,1,Lo-1));
    while At<Hi do begin
      Match:=FindTextForward(ContentText,FFindText,At,Hi-1,N,FSearchSpec.MatchCase,FSearchSpec.WholeWord);
      if (Match=0) or (Match+N>Hi) then Break;
      Pieces.WriteString(Copy(ContentText,At,Match-At));Answer:=mrYes;
      if FSearchSpec.Prompt then begin
        FPages.ActivePage:=Doc.Tab;Doc.Editor.BlockBegin:=SearchPoint(Doc,Match);Doc.Editor.BlockEnd:=SearchPoint(Doc,Match+N);
        Doc.Editor.EnsureCursorPosVisible;
        Answer:=UiMessageDlg(Tr('Replace this occurrence?'),mtConfirmation,[mbYes,mbNo,mbCancel],0);
      end;
      if Answer=mrCancel then begin At:=Match;StopNow:=True;Break;end;
      if Answer=mrYes then begin Pieces.WriteString(FSearchSpec.Replacement);Inc(Result);end
      else Pieces.WriteString(Copy(ContentText,Match,N));
      At:=Match+N;
    end;
    Pieces.WriteString(Copy(ContentText,At,MaxInt));NewText:=Pieces.DataString;
    if Result>0 then begin
      Doc.Editor.BeginUndoBlock;
      try Doc.Editor.SelectAll;Doc.Editor.SelText:=Copy(NewText,1,Length(NewText)-Length(LineEnding));Doc.Editor.LogicalCaretXY:=SearchPoint(Doc,Min(Length(NewText)+1,OldOffset));
      finally Doc.Editor.EndUndoBlock;end;
      if FSearchScopeDoc=Doc then FSearchEnd:=SearchPoint(Doc,Hi+Length(NewText)-Length(ContentText));
    end;
    if StopNow then FSearchCancelled:=True;
  finally Dec(FDocumentDialogs);Pieces.Free;end;
  if CurrentDoc=Doc then Doc.Editor.SetFocus;
end;
procedure TMainForm.SearchFiles(Replacing:Boolean);
const Limit=10000;
var Targets,Lines:TStringList;I,J,Row,At,Found,N,Changes:Integer;Path,SourceLine:string;
  Doc,OriginalDoc:TDocument;Entry:TListItem;Snapshot:TFileSnapshot;
  procedure ScanRows;
  var Row,At,Found,N:Integer;
  begin
    for Row:=0 to Lines.Count-1 do begin
      At:=1;SourceLine:=Lines[Row];
      while At<=Length(SourceLine) do begin
        Found:=FindTextForward(SourceLine,FFindText,At,Length(SourceLine),N,FSearchSpec.MatchCase,FSearchSpec.WholeWord);
        if Found=0 then Break;
        Entry:=FSearchList.Items.Add;Entry.Caption:=IntToStr(Row+1);Entry.SubItems.Add(IntToStr(Found));
        Entry.SubItems.Add(Path);Entry.SubItems.Add(Trim(SourceLine));Entry.SubItems.Add(IntToStr(N));Entry.Data:=Pointer(Doc);
        if FSearchList.Items.Count>=Limit then Exit;At:=Found+N;
      end;
    end;
  end;
begin
  OriginalDoc:=CurrentDoc;Targets:=TStringList.Create;Lines:=TStringList.Create;Changes:=0;FSearchCancelled:=False;
  try
    case FSearchSpec.Scope of
      scProject:Targets.Assign(FProjectFiles);
      scOpen:for I:=0 to FDocs.Count-1 do Targets.AddObject('',TDocument(FDocs[I]));
      scCurrent:if OriginalDoc<>nil then Targets.AddObject('',OriginalDoc);
    end;
    FSearchList.Items.BeginUpdate;
    try
      FSearchList.Items.Clear;
      for I:=0 to Targets.Count-1 do begin
        Doc:=TDocument(Targets.Objects[I]);Path:=Targets[I];
        if Doc=nil then Doc:=FindDoc(Path);
        if Replacing then begin
          if Doc=nil then begin
            try
              LoadDocumentLines(Lines,Path,Snapshot);
              Found:=FindTextForward(Lines.Text,FFindText,1,Length(Lines.Text),N,FSearchSpec.MatchCase,FSearchSpec.WholeWord);
              if Found=0 then Continue;
              OpenFile(Path);Doc:=FindDoc(Path);
            except on E:Exception do begin SetStatusMessage(E.Message);Continue;end;end;
          end;
          Inc(Changes,ReplaceSearch(Doc,True));if FSearchCancelled then Break;
        end else begin
          if Doc<>nil then begin
            Lines.Assign(Doc.Editor.Lines);Path:=Doc.FileName;if Path='' then Path:=Doc.UntitledName;
          end else begin try LoadDocumentLines(Lines,Path,Snapshot);except on E:Exception do begin SetStatusMessage(E.Message);Continue;end;end;end;
          ScanRows;if FSearchList.Items.Count>=Limit then Break;
        end;
      end;
    finally FSearchList.Items.EndUpdate;end;
    if OriginalDoc<>nil then begin FPages.ActivePage:=OriginalDoc.Tab;OriginalDoc.Editor.SetFocus;end;
    if not Replacing then begin FBottomPanel.Show;FReportSplitter.Show;FReportTabs.ActivePage:=FSearchTab;
      SetStatusMessage(Format(Tr('%d matches for %s'),[FSearchList.Items.Count,FFindText]));
      if FSearchList.Items.Count>=Limit then SetStatusMessage(Tr('First 10000 matches shown; refine the search.'));
    end else SetStatusMessage(Format(Tr('%d replacements'),[Changes]));
  finally Lines.Free;Targets.Free;end;
end;
