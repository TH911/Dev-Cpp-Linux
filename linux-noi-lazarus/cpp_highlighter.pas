unit cpp_highlighter;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, SynEditHighlighter, noi_syn_cpp;
type
  TNoiCppSyn = class(TSynCppSyn)
  private
    FCurrentLine: string;
    FBracketAttri, FCharacterAttri, FFloatAttri, FHexAttri, FOctalAttri: TSynHighlighterAttributes;
  public
    constructor Create(AOwner: TComponent); override;
    property BracketAttri: TSynHighlighterAttributes read FBracketAttri;
    property FloatAttri: TSynHighlighterAttributes read FFloatAttri;
    property HexAttri: TSynHighlighterAttributes read FHexAttri;
    property OctalAttri: TSynHighlighterAttributes read FOctalAttri;
    property CharacterAttri: TSynHighlighterAttributes read FCharacterAttri;
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
  end;


implementation
procedure TNoiCppSyn.SetLine(const NewValue: string; LineNumber: Integer);
begin
  FCurrentLine := NewValue;
  inherited SetLine(NewValue, LineNumber);
end;

function ValidIntegerLiteral(const S: string): Boolean;
var
  I, StartDigits, Base: Integer;
  Suffix: string;
begin
  Result := False;
  I := 1;
  Base := 10;
  if (Length(S) > 1) and (S[1] = '0') then
    if S[2] in ['x', 'X'] then begin Base := 16; I := 3; end
    else if S[2] in ['b', 'B'] then begin Base := 2; I := 3; end
    else Base := 8;
  StartDigits := I;
  while I <= Length(S) do
  begin
    if ((Base = 16) and (S[I] in ['0'..'9', 'a'..'f', 'A'..'F'])) or
       ((Base = 10) and (S[I] in ['0'..'9'])) or
       ((Base = 8) and (S[I] in ['0'..'7'])) or
       ((Base = 2) and (S[I] in ['0', '1'])) then Inc(I)
    else Break;
  end;
  if I = StartDigits then Exit;
  Suffix := Copy(S, I, MaxInt);
  if (Pos('lL', Suffix) > 0) or (Pos('Ll', Suffix) > 0) then Exit;
  Suffix := LowerCase(Suffix);
  Result := (Suffix = '') or (Suffix = 'u') or (Suffix = 'l') or
    (Suffix = 'll') or (Suffix = 'ul') or (Suffix = 'ull') or
    (Suffix = 'lu') or (Suffix = 'llu');
end;

function ValidFloatingLiteral(const S: string): Boolean;
var
  I, Digits, ExponentStart: Integer;
  Hexadecimal, HasPoint, HasExponent: Boolean;

  function MantissaDigit(C: Char): Boolean;
  begin
    Result := (C in ['0'..'9']) or
      (Hexadecimal and (C in ['a'..'f', 'A'..'F']));
  end;

begin
  Result := False;
  I := 1;
  Hexadecimal := (Length(S) > 2) and (S[1] = '0') and (S[2] in ['x', 'X']);
  if Hexadecimal then I := 3;
  Digits := 0;
  while (I <= Length(S)) and MantissaDigit(S[I]) do
  begin Inc(I); Inc(Digits); end;
  HasPoint := (I <= Length(S)) and (S[I] = '.');
  if HasPoint then
  begin
    Inc(I);
    while (I <= Length(S)) and MantissaDigit(S[I]) do
    begin Inc(I); Inc(Digits); end;
  end;
  if Digits = 0 then Exit;
  HasExponent := (I <= Length(S)) and
    (((not Hexadecimal) and (S[I] in ['e', 'E'])) or
      (Hexadecimal and (S[I] in ['p', 'P'])));
  if HasExponent then
  begin
    Inc(I);
    if (I <= Length(S)) and (S[I] in ['+', '-']) then Inc(I);
    ExponentStart := I;
    while (I <= Length(S)) and (S[I] in ['0'..'9']) do Inc(I);
    if I = ExponentStart then Exit;
  end;
  if Hexadecimal and not HasExponent then Exit;
  if not (HasPoint or HasExponent) then Exit;
  if (I <= Length(S)) and (S[I] in ['f', 'F', 'l', 'L']) then Inc(I);
  Result := I > Length(S);
end;

constructor TNoiCppSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBracketAttri := TSynHighlighterAttributes.Create('Bracket', 'Bracket');
  AddAttribute(FBracketAttri);
  FCharacterAttri := TSynHighlighterAttributes.Create('Character', 'Character');
  AddAttribute(FCharacterAttri);
  FFloatAttri := TSynHighlighterAttributes.Create('Float', 'Float');
  AddAttribute(FFloatAttri);
  FHexAttri := TSynHighlighterAttributes.Create('Hexadecimal', 'Hexadecimal');
  AddAttribute(FHexAttri);
  FOctalAttri := TSynHighlighterAttributes.Create('Octal', 'Octal');
  AddAttribute(FOctalAttri);
  SetAttributesOnChange(@DefHighlightChange);
end;

function TNoiCppSyn.GetTokenAttribute: TSynHighlighterAttributes;
const
  NewKeywords = ' alignas alignof char8_t char16_t char32_t concept consteval ' +
    'constexpr constinit decltype final noexcept nullptr override requires ' +
    'static_assert thread_local co_await co_return co_yield import module ';
var
  TokenValue: string;
  StartPos, EndPos: Integer;
  WholeLiteral: string;
begin
  Result := inherited GetTokenAttribute;
  TokenValue := GetToken;
  if (GetTokenID = tkIdentifier) and
    (Pos(' ' + TokenValue + ' ', NewKeywords) > 0) then
    Result := KeyAttri;
  if (TokenValue <> '') and
    (GetTokenPos < Length(FCurrentLine)) then
  begin
    StartPos := GetTokenPos + 1;
    EndPos := StartPos;
    while StartPos > 1 do
      if (FCurrentLine[StartPos - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) or
        ((StartPos > 2) and (FCurrentLine[StartPos - 1] in ['+', '-']) and
          (FCurrentLine[StartPos - 2] in ['e', 'E', 'p', 'P'])) then Dec(StartPos)
      else Break;
    while EndPos <= Length(FCurrentLine) do
      if (FCurrentLine[EndPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) or
        ((EndPos > 1) and (FCurrentLine[EndPos] in ['+', '-']) and
          (FCurrentLine[EndPos - 1] in ['e', 'E', 'p', 'P'])) then Inc(EndPos)
      else Break;
    WholeLiteral := Copy(FCurrentLine, StartPos, EndPos - StartPos);
    if (WholeLiteral <> '') and (WholeLiteral[1] in ['0'..'9', '.']) and
      (GetTokenID in [tkNumber, tkIdentifier]) then
    begin
      if ValidFloatingLiteral(WholeLiteral) then Result := FFloatAttri
      else if ValidIntegerLiteral(WholeLiteral) then
      begin
        if (Length(WholeLiteral) > 2) and (WholeLiteral[1] = '0') and
          (WholeLiteral[2] in ['x', 'X']) then Result := FHexAttri
        else if (Length(WholeLiteral) > 1) and (WholeLiteral[1] = '0') and
          (WholeLiteral[2] in ['0'..'7']) then Result := FOctalAttri
        else Result := NumberAttri;
      end
      else Result := IdentifierAttri;
    end;
    { GTK2's older lexer can split leading decimal points, hex exponents and
      suffixes. Color only punctuation contained in a complete valid float. }
    if (GetTokenID = tkSymbol) and (Length(TokenValue) = 1) and
      (TokenValue[1] in ['.', '+', '-']) and
      (GetTokenPos + Length(TokenValue) < EndPos) and
      ValidFloatingLiteral(WholeLiteral) then Result := FFloatAttri;
  end;
  { Lazarus may emit a quote delimiter as a symbol rather than include it
    in the string token.  Keep the original Classic Plus string/char colors. }
  if Copy(TokenValue, 1, 1) = '"' then
    Result := StringAttri;
  if Copy(TokenValue, 1, 1) = '''' then
    Result := FCharacterAttri;
  if (Length(TokenValue) = 1) and (TokenValue[1] in ['(', ')', '[', ']', '{', '}']) and
    (GetTokenID = tkSymbol) then Result := FBracketAttri;
end;


end.
