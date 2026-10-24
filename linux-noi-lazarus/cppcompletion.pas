unit cppcompletion;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

{ A local, lexical C++ member index. It intentionally does not guess members
  from unrelated headers when the type of an expression is unknown. }
function CollectCppMembers(const SourceText, ObjectName: string;
  Results: TStrings; const SourceFile: string = ''): Boolean;
procedure CollectCppFunctionSignatures(const SourceText: string;
  Results: TStrings; const SourceFile: string = '');

implementation

function IsIdentChar(C: Char): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

function IsIdentifier(const S: string): Boolean;
var I: Integer;
begin
  Result := (S <> '') and (S[1] in ['A'..'Z', 'a'..'z', '_']);
  if not Result then Exit;
  for I := 2 to Length(S) do
    if not IsIdentChar(S[I]) then Exit(False);
end;

procedure Tokenize(const S: string; Tokens: TStrings);
var I, StartPos: Integer; QuoteChar: Char;
begin
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '#' then
    begin
      while (I <= Length(S)) and not (S[I] in [#10, #13]) do Inc(I);
      Continue;
    end;
    if (S[I] = '/') and (I < Length(S)) and (S[I + 1] = '/') then
    begin
      while (I <= Length(S)) and not (S[I] in [#10, #13]) do Inc(I);
      Continue;
    end;
    if (S[I] = '/') and (I < Length(S)) and (S[I + 1] = '*') then
    begin
      Inc(I, 2);
      while (I < Length(S)) and not ((S[I] = '*') and (S[I + 1] = '/')) do Inc(I);
      Inc(I, 2);
      Continue;
    end;
    if S[I] in ['"', ''''] then
    begin
      QuoteChar := S[I];
      Inc(I);
      while I <= Length(S) do
      begin
        if S[I] = '\' then Inc(I, 2)
        else if S[I] = QuoteChar then begin Inc(I); Break; end
        else Inc(I);
      end;
      Continue;
    end;
    if S[I] in ['A'..'Z', 'a'..'z', '_'] then
    begin
      StartPos := I;
      Inc(I);
      while (I <= Length(S)) and IsIdentChar(S[I]) do Inc(I);
      Tokens.Add(Copy(S, StartPos, I - StartPos));
      Continue;
    end;
    if S[I] in ['{', '}', ';', ',', '(', ')', '[', ']', ':', '*', '&', '=', '<', '>', '.'] then
      Tokens.Add(S[I]);
    Inc(I);
  end;
end;

procedure AddMember(const TypeName, MemberName, Kind: string; Members: TStrings);
var Key: string;
begin
  if not IsIdentifier(MemberName) then Exit;
  if (MemberName = 'public') or (MemberName = 'private') or
    (MemberName = 'protected') then Exit;
  Key := TypeName + '|' + MemberName + '=' + Kind;
  if Members.IndexOf(Key) < 0 then Members.Add(Key);
end;

procedure ParseMemberStatement(const TypeName: string; Statement, Members: TStrings);
var I, K, SegmentStart, BracketDepth: Integer; Candidate: string;
begin
  if Statement.Count = 0 then Exit;
  for I := 0 to Statement.Count - 1 do
    if Statement[I] = '(' then
    begin
      if I > 0 then
      begin
        if (I + 1 < Statement.Count) and (Statement[I + 1] = ')') then
          AddMember(TypeName, Statement[I - 1], 'function0', Members)
        else
          AddMember(TypeName, Statement[I - 1], 'function', Members);
      end;
      Exit;
    end;
  SegmentStart := 0;
  for I := 0 to Statement.Count do
    if (I = Statement.Count) or (Statement[I] = ',') then
    begin
      Candidate := '';
      BracketDepth := 0;
      for K := SegmentStart to I - 1 do
      begin
        if Statement[K] = '[' then Inc(BracketDepth)
        else if Statement[K] = ']' then Dec(BracketDepth)
        else if (Statement[K] = '=') and (BracketDepth = 0) then Break
        else if (BracketDepth = 0) and IsIdentifier(Statement[K]) then
          Candidate := Statement[K];
      end;
      if (Candidate <> '') and
        ((SegmentStart > 0) or (Statement.Count = 1) or
         (Candidate <> Statement[0])) then
      begin
        if (Statement[0] = 'typedef') or (Statement[0] = 'using') then
          AddMember(TypeName, Candidate, 'type', Members)
        else
          AddMember(TypeName, Candidate, 'variable', Members);
      end;
      SegmentStart := I + 1;
    end;
end;

procedure ParseTypeBody(Tokens: TStrings; OpenAt, CloseAt: Integer;
  const TypeName: string; Members: TStrings);
var I, Depth, K: Integer; Statement: TStringList;
begin
  Statement := TStringList.Create;
  try
    Depth := 0;
    for I := OpenAt + 1 to CloseAt - 1 do
    begin
      if Tokens[I] = '{' then
      begin
        if Depth = 0 then
        begin
          if (Statement.Count >= 2) and
            ((Statement[0] = 'struct') or (Statement[0] = 'class') or
             (Statement[0] = 'enum')) then
            AddMember(TypeName, Statement[1], 'type', Members);
          for K := 0 to Statement.Count - 1 do
            if (Statement[K] = '(') and (K > 0) then
            begin
              if (K + 1 < Statement.Count) and (Statement[K + 1] = ')') then
                AddMember(TypeName, Statement[K - 1], 'function0', Members)
              else
                AddMember(TypeName, Statement[K - 1], 'function', Members);
              Break;
            end;
          Statement.Clear;
        end;
        Inc(Depth);
      end
      else if Tokens[I] = '}' then
      begin
        if Depth > 0 then Dec(Depth);
      end
      else if Depth = 0 then
      begin
        if Tokens[I] = ';' then
        begin
          ParseMemberStatement(TypeName, Statement, Members);
          Statement.Clear;
        end
        else Statement.Add(Tokens[I]);
      end;
    end;
  finally Statement.Free; end;
end;

procedure ReadLocalHeaders(const SourceText, SourceFile: string;
  Seen: TStrings; var Combined: string; Depth: Integer);
var
  Lines, HeaderLines: TStringList;
  HeaderStream: TFileStream;
  I, P, Q: Integer;
  Line, HeaderFile: string;
begin
  if (Depth >= 4) or (SourceFile = '') then Exit;
  Lines := TStringList.Create;
  HeaderLines := TStringList.Create;
  try
    Lines.Text := SourceText;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Copy(Line, 1, 8) <> '#include' then Continue;
      P := Pos('"', Line);
      if P = 0 then Continue;
      Q := Pos('"', Copy(Line, P + 1, MaxInt));
      if Q = 0 then Continue;
      HeaderFile := ExpandFileName(ExtractFilePath(SourceFile) +
        Copy(Line, P + 1, Q - 1));
      if (Seen.IndexOf(HeaderFile) >= 0) or not FileExists(HeaderFile) then Continue;
      Seen.Add(HeaderFile);
      try
        HeaderStream := TFileStream.Create(HeaderFile, fmOpenRead or fmShareDenyNone);
        try
          if HeaderStream.Size > 262144 then Continue;
        finally HeaderStream.Free; end;
        HeaderLines.LoadFromFile(HeaderFile);
        if Length(Combined) + Length(HeaderLines.Text) > 1048576 then Exit;
        Combined := Combined + LineEnding + HeaderLines.Text;
        ReadLocalHeaders(HeaderLines.Text, HeaderFile, Seen, Combined, Depth + 1);
      except
        { A missing or unreadable optional header must not disable completion. }
      end;
    end;
  finally
    HeaderLines.Free;
    Lines.Free;
  end;
end;

procedure AddStandardMembers(const TypeName: string; Members: TStrings);
var
  Words: TStringList;
  procedure AddWords(const Names, Kind: string);
  var
    I: Integer;
  begin
    Words.DelimitedText := Names;
    for I := 0 to Words.Count - 1 do
      if Words[I] <> '' then AddMember(TypeName, Words[I], Kind, Members);
  end;
begin
  Words := TStringList.Create;
  try
    Words.Delimiter := ' ';
    Words.StrictDelimiter := True;
    if (TypeName = 'vector') or (TypeName = 'deque') or
      (TypeName = 'list') or (TypeName = 'string') then
    begin
      AddWords('begin end cbegin cend rbegin rend empty size max_size ' +
        'front back clear', 'function0');
      AddWords('insert erase assign swap', 'function');
      AddWords('value_type size_type iterator const_iterator reference ' +
        'const_reference', 'type');
    end;
    if (TypeName = 'vector') or (TypeName = 'deque') or
      (TypeName = 'list') then
    begin
      AddWords('pop_back', 'function0');
      AddWords('push_back emplace_back emplace resize', 'function');
      if TypeName <> 'list' then AddWords('at', 'function');
    end;
    if (TypeName = 'deque') or (TypeName = 'list') then
    begin
      AddWords('pop_front', 'function0');
      AddWords('push_front emplace_front', 'function');
    end;
    if TypeName = 'vector' then
    begin
      AddWords('data capacity shrink_to_fit', 'function0');
      AddWords('reserve', 'function');
    end;
    if TypeName = 'string' then
    begin
      AddWords('data c_str capacity length', 'function0');
      AddWords('pop_back', 'function0');
      AddWords('reserve substr find rfind append compare replace at ' +
        'push_back resize', 'function');
    end;
    if (TypeName = 'map') or (TypeName = 'set') or
      (TypeName = 'unordered_map') or (TypeName = 'unordered_set') then
    begin
      AddWords('begin end cbegin cend empty size clear', 'function0');
      AddWords('insert erase find count emplace swap', 'function');
      AddWords('value_type size_type iterator const_iterator', 'type');
      if (TypeName = 'map') or (TypeName = 'set') then
        AddWords('lower_bound upper_bound equal_range', 'function');
    end;
    if (TypeName = 'queue') or (TypeName = 'stack') or
      (TypeName = 'priority_queue') then
    begin
      AddWords('empty size pop', 'function0');
      AddWords('push emplace swap', 'function');
      if TypeName = 'queue' then AddWords('front back', 'function0')
      else AddWords('top', 'function0');
    end;
    if TypeName = 'pair' then
    begin
      AddWords('first second', 'variable');
      AddWords('swap', 'function');
    end;
    if TypeName = 'array' then
    begin
      AddWords('begin end cbegin cend empty size front back data', 'function0');
      AddWords('fill swap at', 'function');
      AddWords('value_type size_type iterator const_iterator', 'type');
    end;
  finally Words.Free; end;
end;

procedure CollectCppFunctionSignatures(const SourceText: string;
  Results: TStrings; const SourceFile: string);
var
  Tokens, Seen: TStringList;
  Combined, FunctionName, Signature, PreviousToken, CurrentToken: string;
  I, J, K, ParenDepth, DeclarationStart: Integer;
begin
  Results.Clear;
  Tokens := TStringList.Create;
  Seen := TStringList.Create;
  try
    Combined := SourceText;
    ReadLocalHeaders(SourceText, SourceFile, Seen, Combined, 0);
    Tokenize(Combined, Tokens);
    for I := 1 to Tokens.Count - 3 do
    begin
      FunctionName := Tokens[I];
      if not IsIdentifier(FunctionName) or (Tokens[I + 1] <> '(') then Continue;
      PreviousToken := Tokens[I - 1];
      if not (IsIdentifier(PreviousToken) or (PreviousToken = '*') or
        (PreviousToken = '&') or (PreviousToken = '>')) then Continue;
      if (PreviousToken = 'return') or (PreviousToken = 'if') or
        (PreviousToken = 'while') or (PreviousToken = 'for') or
        (PreviousToken = 'switch') or (PreviousToken = 'catch') or
        (PreviousToken = 'sizeof') then Continue;
      J := I + 2;
      ParenDepth := 1;
      while (J < Tokens.Count) and (ParenDepth > 0) do
      begin
        if Tokens[J] = '(' then Inc(ParenDepth)
        else if Tokens[J] = ')' then Dec(ParenDepth);
        Inc(J);
      end;
      if ParenDepth <> 0 then Continue;
      if (J < Tokens.Count) and
        (Tokens[J] <> '{') and (Tokens[J] <> ';') and
        (Tokens[J] <> 'const') and (Tokens[J] <> 'noexcept') and
        (Tokens[J] <> ':') then Continue;
      DeclarationStart := I - 1;
      while (DeclarationStart > 0) and
        not (Tokens[DeclarationStart - 1] = ';') and
        not (Tokens[DeclarationStart - 1] = '{') and
        not (Tokens[DeclarationStart - 1] = '}') and
        not (Tokens[DeclarationStart - 1] = ':') do Dec(DeclarationStart);
      Signature := '';
      for K := DeclarationStart to J - 1 do
      begin
        CurrentToken := Tokens[K];
        if (Signature <> '') and (K > DeclarationStart) and
          ((IsIdentifier(CurrentToken) and IsIdentifier(Tokens[K - 1])) or
           ((K = I) and (Tokens[K - 1] = '>')) or
           (Tokens[K - 1] = ',')) then Signature := Signature + ' ';
        Signature := Signature + CurrentToken;
      end;
      if Results.IndexOfName(FunctionName) < 0 then
        Results.Values[FunctionName] := Signature;
    end;
  finally
    Seen.Free;
    Tokens.Free;
  end;
end;

function CollectCppMembers(const SourceText, ObjectName: string;
  Results: TStrings; const SourceFile: string): Boolean;
var
  Tokens, TypeNames, Members, CloseTypes, VarTypes, AliasTypes, Seen: TStringList;
  I, J, K, Depth: Integer;
  TypeName, MemberPrefix, VariableName, Combined, ResolvedType: string;
const
  StandardTypes: array[0..11] of string =
    ('vector', 'deque', 'list', 'string', 'map', 'unordered_map',
     'set', 'unordered_set', 'queue', 'stack', 'priority_queue', 'pair');
  ExtraType = 'array';
begin
  Result := False;
  Results.Clear;
  Tokens := TStringList.Create;
  TypeNames := TStringList.Create;
  Members := TStringList.Create;
  CloseTypes := TStringList.Create;
  VarTypes := TStringList.Create;
  AliasTypes := TStringList.Create;
  Seen := TStringList.Create;
  try
    TypeNames.CaseSensitive := True;
    Members.CaseSensitive := True;
    VarTypes.CaseSensitive := True;
    AliasTypes.CaseSensitive := True;
    Combined := SourceText;
    ReadLocalHeaders(SourceText, SourceFile, Seen, Combined, 0);
    Tokenize(Combined, Tokens);
    for I := Low(StandardTypes) to High(StandardTypes) + 1 do
    begin
      if I <= High(StandardTypes) then TypeName := StandardTypes[I]
      else TypeName := ExtraType;
      TypeNames.Add(TypeName);
      AddStandardMembers(TypeName, Members);
    end;
    for I := 0 to Tokens.Count - 3 do
      if ((Tokens[I] = 'struct') or (Tokens[I] = 'class')) and
        IsIdentifier(Tokens[I + 1]) then
      begin
        J := I + 2;
        while (J < Tokens.Count) and (Tokens[J] <> '{') and
          (Tokens[J] <> ';') do Inc(J);
        if (J >= Tokens.Count) or (Tokens[J] <> '{') then Continue;
        Depth := 1;
        K := J + 1;
        while (K < Tokens.Count) and (Depth > 0) do
        begin
          if Tokens[K] = '{' then Inc(Depth)
          else if Tokens[K] = '}' then Dec(Depth);
          Inc(K);
        end;
        if Depth <> 0 then Continue;
        TypeName := Tokens[I + 1];
        if TypeNames.IndexOf(TypeName) < 0 then TypeNames.Add(TypeName);
        CloseTypes.Values[IntToStr(K - 1)] := TypeName;
        ParseTypeBody(Tokens, J, K - 1, TypeName, Members);
      end;
    { C++ type aliases preserve the underlying member set.  A full C++
      parser is needed for dependent aliases, but ordinary contest aliases
      such as "using Graph = vector<int>" and "typedef vector<int> Graph"
      can be resolved without guessing members from unrelated types. }
    for I := 0 to Tokens.Count - 1 do
    begin
      if (Tokens[I] = 'using') and (I + 3 < Tokens.Count) and
        IsIdentifier(Tokens[I + 1]) and (Tokens[I + 2] = '=') then
      begin
        J := I + 3;
        while (J < Tokens.Count) and (Tokens[J] <> ';') do
        begin
          if TypeNames.IndexOf(Tokens[J]) >= 0 then
          begin
            AliasTypes.Values[Tokens[I + 1]] := Tokens[J];
            if TypeNames.IndexOf(Tokens[I + 1]) < 0 then
              TypeNames.Add(Tokens[I + 1]);
            Break;
          end;
          Inc(J);
        end;
      end
      else if Tokens[I] = 'typedef' then
      begin
        J := I + 1;
        ResolvedType := '';
        VariableName := '';
        while (J < Tokens.Count) and (Tokens[J] <> ';') do
        begin
          if TypeNames.IndexOf(Tokens[J]) >= 0 then
            ResolvedType := Tokens[J];
          if IsIdentifier(Tokens[J]) then VariableName := Tokens[J];
          Inc(J);
        end;
        if (ResolvedType <> '') and (VariableName <> '') and
          (VariableName <> ResolvedType) then
        begin
          AliasTypes.Values[VariableName] := ResolvedType;
          if TypeNames.IndexOf(VariableName) < 0 then
            TypeNames.Add(VariableName);
        end;
      end;
    end;
    for I := 0 to Tokens.Count - 1 do
    begin
      TypeName := CloseTypes.Values[IntToStr(I)];
      if TypeName <> '' then
      begin
        J := I + 1;
        while (J < Tokens.Count) and IsIdentifier(Tokens[J]) do
        begin
          VarTypes.Values[Tokens[J]] := TypeName;
          Inc(J);
          while (J < Tokens.Count) and (Tokens[J] = '[') do
          begin
            Inc(J);
            while (J < Tokens.Count) and (Tokens[J] <> ']') do Inc(J);
            if J < Tokens.Count then Inc(J);
          end;
          if (J >= Tokens.Count) or (Tokens[J] <> ',') then Break;
          Inc(J);
        end;
      end;
      if (TypeNames.IndexOf(Tokens[I]) >= 0) and
        ((I = 0) or ((Tokens[I - 1] <> 'struct') and
                      (Tokens[I - 1] <> 'class'))) then
      begin
        J := I + 1;
        if (J < Tokens.Count) and (Tokens[J] = '<') then
        begin
          Depth := 1;
          Inc(J);
          while (J < Tokens.Count) and (Depth > 0) do
          begin
            if Tokens[J] = '<' then Inc(Depth)
            else if Tokens[J] = '>' then Dec(Depth);
            Inc(J);
          end;
        end;
        while (J < Tokens.Count) and
          ((Tokens[J] = '*') or (Tokens[J] = '&')) do Inc(J);
        if (J < Tokens.Count) and IsIdentifier(Tokens[J]) then
        begin
          ResolvedType := AliasTypes.Values[Tokens[I]];
          if ResolvedType = '' then ResolvedType := Tokens[I];
          VarTypes.Values[Tokens[J]] := ResolvedType;
        end;
      end;
    end;
    TypeName := VarTypes.Values[ObjectName];
    if (TypeName = '') and (TypeNames.IndexOf(ObjectName) >= 0) then
    begin
      TypeName := AliasTypes.Values[ObjectName];
      if TypeName = '' then TypeName := ObjectName;
    end;
    Result := TypeName <> '';
    if not Result then Exit;
    MemberPrefix := TypeName + '|';
    for I := 0 to Members.Count - 1 do
      if Copy(Members[I], 1, Length(MemberPrefix)) = MemberPrefix then
      begin
        VariableName := Copy(Members[I], Length(MemberPrefix) + 1, MaxInt);
        if Results.IndexOf(VariableName) < 0 then Results.Add(VariableName);
      end;
  finally
    Seen.Free;
    VarTypes.Free;
    AliasTypes.Free;
    CloseTypes.Free;
    Members.Free;
    TypeNames.Free;
    Tokens.Free;
  end;
end;

end.
