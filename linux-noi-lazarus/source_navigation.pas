unit source_navigation;
{$mode objfpc}{$H+}
interface
uses Classes;
{ Entries are scope|name with a 1-based source line in Objects. Empty name is a scope. }
procedure CollectSourceSymbols(Lines: TStrings; Symbols: TStrings);
implementation
uses SysUtils, RegExpr;
procedure CollectSourceSymbols(Lines: TStrings; Symbols: TStrings);
var TypePattern, FunctionPattern: TRegExpr; Row, I, Depth, ScopeDepth: Integer;
  Code, Scope, PendingScope, Name: string; InComment: Boolean; Quote: Char;
begin
  Symbols.Clear;
  TypePattern := TRegExpr.Create;
  FunctionPattern := TRegExpr.Create;
  try
    TypePattern.Expression := '\b(class|struct|namespace)\s+([A-Za-z_][A-Za-z_0-9]*)';
    FunctionPattern.Expression := '([~A-Za-z_][~A-Za-z_0-9:]*)\s*\([^;{}]*\)\s*(const|noexcept|override|final|\s)*\s*(\{|$)';
    Depth := 0; ScopeDepth := -1; Scope := ''; PendingScope := ''; InComment := False;
    for Row := 0 to Lines.Count - 1 do
    begin
      Code := ''; Quote := #0; I := 1;
      while I <= Length(Lines[Row]) do
      begin
        if InComment then
        begin
          if Copy(Lines[Row], I, 2) = '*/' then begin InComment := False; Inc(I); end;
          Code := Code + ' ';
        end
        else if Quote <> #0 then
        begin
          if Lines[Row][I] = '\' then begin Inc(I); Code := Code + ' '; end
          else if Lines[Row][I] = Quote then Quote := #0;
          Code := Code + ' ';
        end
        else if Copy(Lines[Row], I, 2) = '//' then Break
        else if Copy(Lines[Row], I, 2) = '/*' then begin InComment := True; Code := Code + ' '; Inc(I); end
        else if Lines[Row][I] in ['"', ''''] then begin Quote := Lines[Row][I]; Code := Code + ' '; end
        else Code := Code + Lines[Row][I];
        Inc(I);
      end;
      if (Pos('using ', Trim(Code)) <> 1) and TypePattern.Exec(Code) then
      begin
        PendingScope := TypePattern.Match[2];
        Symbols.AddObject(PendingScope + '|', TObject(PtrInt(Row + 1)));
      end;
      if (Length(Code) < 16384) and (Pos('(', Code) > 0) and
        (Pos(')', Code) > Pos('(', Code)) and FunctionPattern.Exec(Code) then
      begin
        Name := FunctionPattern.Match[1];
        if (Name <> 'if') and (Name <> 'for') and (Name <> 'while') and
          (Name <> 'switch') and (Name <> 'catch') and (Name <> 'sizeof') and
          (Name <> 'return') and (Name <> 'decltype') then
          Symbols.AddObject(Scope + '|' + Name, TObject(PtrInt(Row + 1)));
      end;
      for I := 1 to Length(Code) do
        if Code[I] = '{' then
        begin
          Inc(Depth);
          if PendingScope <> '' then
          begin Scope := PendingScope; ScopeDepth := Depth; PendingScope := ''; end;
        end
        else if Code[I] = '}' then
        begin
          Dec(Depth);
          if Depth < ScopeDepth then begin Scope := ''; ScopeDepth := -1; end;
        end;
      if Pos(';', Code) > 0 then PendingScope := '';
    end;
  finally TypePattern.Free; FunctionPattern.Free; end;
end;
end.
