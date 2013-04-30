unit DispatchUnsignedAsSignedPatch;
{.$D-,L-}
{
  DispatchUnsignedAsSignedPatch replaces the Variants.GetDispatchInvokeArgs by a bug fixed version
  that handles DispatchUnsignedAsSigned with varRef parameters.
}

interface

implementation

uses
  Windows, SysConst, SysUtils, Variants;

const
  {$IFDEF CPUX64}
  HookByteCount = 5;
  {$ELSE}
  HookByteCount = 6;
  {$ENDIF CPUX64}

var
  _EmptyBSTR: PWideChar = nil;
  AddrOfGetDispatchInvokeArgs: PByte;
  HookedOpCodes: array[0..HookByteCount - 1] of Byte;

function Replacement_GetDispatchInvokeArgs(CallDesc: PCallDesc; Params: Pointer; var Strings: TStringRefList;
  OrderLTR : Boolean): TVarDataArray;

  {$IFDEF CPUX64}
  function _GetXMM3: Double;
  asm
    MOVDQA  XMM0, XMM3
  end;

  function _GetXMM3AsSingle: Single;
  asm
    MOVDQA  XMM0, XMM3
  end;
  {$ENDIF}

const
  { Parameter type masks - keep in sync with decl.h/ap* enumerations}
  atString   = $48;
  atUString  = $4A;
  atVarMask  = $3F;
  atTypeMask = $7F;
  atByRef    = $80;
var
  I: Integer;
  ArgType: Byte;
  PVarParm: PVarData;
  StringCount: Integer;
begin
  //InitEmptyBSTR;
  StringCount := 0;
  SetLength(Result, CallDesc^.ArgCount);
  for I := 0 to CallDesc^.ArgCount-1 do
  begin
    ArgType := CallDesc^.ArgTypes[I];

    if OrderLTR then
      PVarParm := @Result[I]
    else
      PVarParm := @Result[CallDesc^.ArgCount-I-1];

    if (ArgType and atByRef) = atByRef then
    begin
      if (ArgType and atTypeMask) = atString then
      begin
        PVarData(PVarParm)^.VType := varByRef or varOleStr;
        PVarData(PVarParm)^.VPointer := Strings[StringCount].FromAnsi(PAnsiString(Params^));
        Inc(StringCount);
      end
      else if (ArgType and atTypeMask) = atUString then
      begin
        PVarData(PVarParm)^.VType := varByRef or varOleStr;
        PVarData(PVarParm)^.VPointer := Strings[StringCount].FromUnicode(PUnicodeString(Params^));
        Inc(StringCount);
      end
      else
      begin
        if ((ArgType and atTypeMask) = varVariant) and
          ((PVarData(Params^)^.VType = varString) or (PVarData(Params^)^.VType = varUString)) then
          VarCast(PVariant(Params^)^, PVariant(Params^)^, varOleStr);

        {<Bugfix>}
        //PVarData(PVarParm)^.VType := varByRef or (ArgType and atTypeMask);
        ArgType := ArgType and atTypeMask;
        if DispatchUnsignedAsSigned then
          case ArgType of
            varUInt64:   ArgType := varInt64;
            varLongWord: ArgType := varInteger;
            varWord:     ArgType := varSmallint;
            varByte:     ArgType := varShortInt;
          end;
        PVarData(PVarParm)^.VType := varByRef or ArgType;
        {</Bugfix>}

        PVarData(PVarParm)^.VPointer := PPointer(Params)^;
      end;
      Inc(PByte(Params), SizeOf(Pointer));
    end
    else // ByVal
    begin
      PVarParm^.VType := ArgType;
      case ArgType of
        varEmpty, varNull: ; // Only need to set VType
        varSmallint:  PVarParm^.VSmallInt := PSmallInt(Params)^;
        varInteger:   PVarParm^.VInteger := PInteger(Params)^;
        varSingle:
{$IFDEF CPUX64}
        if I = 0 then
          PVarParm^.VSingle := _GetXMM3AsSingle
        else
{$ENDIF}
          PVarParm^.VSingle := PSingle(Params)^;
        varDouble:
{$IFDEF CPUX64}
        if I = 0 then
          PVarParm^.VDouble := _GetXMM3
        else
{$ENDIF}
          PVarParm^.VDouble := PDouble(Params)^;
        varCurrency:  PVarParm^.VCurrency := PCurrency(Params)^;
        varDate:
{$IFDEF CPUX64}
        if I = 0 then
          PVarParm^.VDate := _GetXMM3
        else
{$ENDIF}
          PVarParm^.VDate := PDateTime(Params)^;
        varOleStr:    PVarParm^.VPointer := PPointer(Params)^;
        varDispatch:  PVarParm^.VDispatch := PPointer(Params)^;
        varError:     PVarParm^.VError := HRESULT($80020004); //DISP_E_PARAMNOTFOUND;
        varBoolean:   PVarParm^.VBoolean := PBoolean(Params)^;
        varVariant:
        begin
          PVarParm^.VType := varEmpty;
{$IFDEF CPUX64}
          PVariant(PVarParm)^ := PVariant(Params^)^;
{$ELSE}
          PVariant(PVarParm)^ := PVariant(Params)^;
{$ENDIF}
        end;
        varUnknown:   PVarParm^.VUnknown := PPointer(Params)^;
        varShortInt:  PVarParm^.VShortInt := PShortInt(Params)^;
        varByte:      PVarParm^.VByte :=  PByte(Params)^;
        varWord:
        begin
          if DispatchUnsignedAsSigned then
          begin
            PVarParm^.VType := varInteger;
            PVarParm^.VInteger := Integer(PWord(Params)^);
          end else
            PVarParm^.VWord := PWord(Params)^;
        end;
        varLongWord:
        begin
          if DispatchUnsignedAsSigned then
          begin
            PVarParm^.VType := varInteger;
            PVarParm^.VInteger := Integer(PLongWord(Params)^);
          end else
            PVarParm^.VLongWord := PLongWord(Params)^;
        end;
        varInt64:     PVarParm^.VInt64 := PInt64(Params)^;
        varUInt64:
        begin
          if DispatchUnsignedAsSigned then
          begin
            PVarParm^.VType := varInt64;
            PVarParm^.VInt64 := Int64(PInt64(Params)^);
          end else
            PVarParm^.VUInt64 := PUInt64(Params)^;
        end;
        atString:
        begin
          PVarParm^.VType := varOleStr;
          if PAnsiString(Params)^ <> '' then
          begin
            PVarParm^.VPointer := PWideChar(Strings[StringCount].FromAnsi(PAnsiString(Params))^);
            Strings[StringCount].Ansi := nil;
            Inc(StringCount);
          end
          else
            PVarParm^.VPointer := _EmptyBSTR;
        end;
        atUString:
        begin
          PVarParm^.VType := varOleStr;
          if PUnicodeString(Params)^ <> '' then
          begin
            PVarParm^.VPointer := PWideChar(Strings[StringCount].FromUnicode(PUnicodeString(Params))^);
            Strings[StringCount].Unicode := nil;
            Inc(StringCount);
          end
          else
            PVarParm^.VPointer := _EmptyBSTR;
        end;
      else
        // Unsupported Var Types
        //varDecimal  = $000E; { vt_decimal     14 } {UNSUPPORTED as of v6.x code base}
        //varUndef0F  = $000F; { undefined      15 } {UNSUPPORTED per Microsoft}
        //varRecord   = $0024; { VT_RECORD      36 }
        //varString   = $0100; { Pascal string  256 } {not OLE compatible }
        //varAny      = $0101; { Corba any      257 } {not OLE compatible }
        //varUString  = $0102; { Unicode string 258 } {not OLE compatible }
        //_DispInvokeError;
        raise EVariantDispatchError.CreateRes(@SDispatchError);
      end;
      case ArgType of
        varError: ; // don't increase param pointer
{$IFDEF CPUX86}
      varDouble, varCurrency, varDate, varInt64, varUInt64:
        Inc(PByte(Params), 8);
      varVariant:
        Inc(PByte(Params), SizeOf(Variant));
{$ENDIF}
      else
        Inc(PByte(Params), SizeOf(Pointer));
      end;
    end;
  end;
end;

function GetActualAddr(Proc: Pointer): Pointer;
type
  PWin9xDebugThunk = ^TWin9xDebugThunk;
  TWin9xDebugThunk = packed record
    PUSH: Byte;
    Addr: Pointer;
    JMP: Byte;
    Rel: Integer;
  end;

  PAbsoluteIndirectJmp = ^TAbsoluteIndirectJmp;
  TAbsoluteIndirectJmp = packed record
    OpCode: Word;
    Addr: ^Pointer;
  end;

begin
  Result := Proc;
  if Result <> nil then
  begin
    {$IFDEF CPUX64}
    if PAbsoluteIndirectJmp(Result).OpCode = $25FF then
      Result := PPointer(PByte(@PAbsoluteIndirectJmp(Result).OpCode) + SizeOf(TAbsoluteIndirectJmp) + Integer(PAbsoluteIndirectJmp(Result).Addr))^;
    {$ELSE}
    if (Win32Platform <> VER_PLATFORM_WIN32_NT) and
       (PWin9xDebugThunk(Result).PUSH = $68) and (PWin9xDebugThunk(Result).JMP = $E9) then
      Result := PWin9xDebugThunk(Result).Addr;
    if PAbsoluteIndirectJmp(Result).OpCode = $25FF then
      Result := PAbsoluteIndirectJmp(Result).Addr^;
    {$ENDIF CPUX64}
  end;
end;

procedure Init;
var
  Buffer: array[0..HookByteCount - 1] of Byte;
  P: PByte;
  n: SIZE_T;
  Success: Boolean;
begin
  P := GetActualAddr(@GetDispatchInvokeArgs);

  {$IFDEF CPUX64}
  Success := (P[0] = $55) and                  // push rbp
             (P[1] = $41) and (P[2] = $55) and // push r13
             (P[3] = $57) and                  // push rdi
             (P[4] = $56);                     // push rsi
  {$ELSE}
  Buffer[5] := $90; // nop

  Success := (P[0] = $55) and                                    // push ebp
             (P[1] = $8B) and (P[2] = $EC) and                   // mov ebp, esp
             (P[3] = $83) and (P[4] = $C4) and (P[5] = $EC);     // add esp, -$14
  {$ENDIF CPUX64}

  if Success then
  begin
    Move(P^, HookedOpCodes, SizeOf(HookedOpCodes)); // backup opcodes
    Buffer[0] := $E9; // jmp rel32
    PInteger(@Buffer[1])^ := PByte(@Replacement_GetDispatchInvokeArgs) - (P + 5);
    Success := WriteProcessMemory(GetCurrentProcess, P, @Buffer, SizeOf(Buffer), n) and (n = SizeOf(Buffer));
  end;

  if not Success then
    raise EVariantInvalidOpError.Create('GetDispatchInvokeArgs patching failed');

  AddrOfGetDispatchInvokeArgs := P;
  _EmptyBSTR := StringToOleStr(''); // leaks memory
end;

procedure Fini;
var
  n: SIZE_T;
begin
  // Restore original opcodes
  if AddrOfGetDispatchInvokeArgs <> nil then
    WriteProcessMemory(GetCurrentProcess, AddrOfGetDispatchInvokeArgs, @HookedOpCodes, SizeOf(HookedOpCodes), n);
end;

initialization
  Init;

finalization
  Fini;

end.
