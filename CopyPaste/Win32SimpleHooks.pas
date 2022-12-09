// (C) Arioch 'The, licensed under GNU GPL v.3
// https://github.com/the-Arioch/XE2fixes.git
unit Win32SimpleHooks;

interface

{$WARN SYMBOL_PLATFORM OFF}{$T+}{$W-}

{$if CompilerVersion < 19}
uses Types;

type
  SIZE_T = DWORD;
  NativeUInt = Cardinal; NativeInt = Integer;
// https://blog.dummzeuch.de/2018/09/08/nativeint-nativeuint-type-in-various-delphi-versions/
// https://stackoverflow.com/questions/7630781/delphi-2007-and-xe2-using-nativeint
  PNativeUInt = ^NativeUInt; PNativeInt = ^NativeInt;
// Delphi 2007 - misses {$POINTERMATH ON} !!!
// https://sergworks.wordpress.com/2010/06/09/a-hidden-feature-of-pointermath-directive-in-delphi-2009/

{$Define ICE2007}
// when the advanced records were moved to a separate unit and got into "interface" section
// Delphi 2007 started giving Internal Compiler Error on non-static inline methods.
// [DCC Error] Win32SimpleHooks.pas(250): F2084 Internal Error: AV21BA6FD9-R84C40AB7-0
// [DCC Error] Разрушительный сбой (Исключение из HRESULT: 0x8000FFFF (E_UNEXPECTED))
// [DCC Error] Win32SimpleHooks.pas(250): F2084 Internal Error: URW926
{$ifend}

type
  PAbsoluteIndirectJmp = ^RAbsoluteIndirectJmp;
  RAbsoluteIndirectJmp = packed record
    OpCode: Word;
    Addr: ^Pointer;
    const EtalonOpCode = $25FF;

    function IsThisPattern: boolean; overload; {$IfNDef ICE2007} inline; {$EndIf}
    class function IsThisPattern(const at: pointer): boolean; overload; {$IfNDef ICE2007} inline; {$EndIf} static;

    function TargetAddress: Pointer; overload; {$IfNDef ICE2007} inline; {$EndIf}
    class function TargetAddress(const at: pointer): Pointer; overload; {$IfNDef ICE2007} inline; {$EndIf} static;
  end;

type
  PRelativeLongJmp = ^RRelativeLongJmp;
  RRelativeLongJmp = packed record
    OpCode: byte;
    Offset: NativeInt;
    const EtalonOpCode = $E9;

    function IsThisPattern: boolean; overload; {$IfNDef ICE2007} inline; {$EndIf}
    class function IsThisPattern(const at: pointer): boolean; overload; inline; static;

    function TargetAddress: Pointer; overload; {$IfNDef ICE2007} inline; {$EndIf}
    class function TargetAddress(const at: pointer): Pointer; overload; static;

    procedure WriteHookInPlace(const NewCode: pointer); {$IfNDef ICE2007} inline; {$EndIf}
    procedure WriteHookToBuffer(const NewCode, OldCode: pointer); overload; {$IfNDef ICE2007} inline; {$EndIf}
    class procedure WriteHookToBuffer(const NewCode, OldCode, Buffer: pointer); overload; static;
  end;

type
  PWindowsHotPatch = ^RWindowsHotPatch;
  RWindowsHotPatch = packed record
    OpCode: Word;
    const PreBuffLen = 5;
    const TargetOpCode = $FF8B;  // MOV EDI, EDI
          FillerOpCode1 = $90; FillerOpCode2 = $CC;  // NOP = XCHG EAX, EAX; INT 3

    function IsThisPattern: boolean;
    procedure WriteHookInPlace(const NewCode: pointer);
    procedure WriteHookToBuffer(const NewCode, OldCode: pointer);
    procedure RemoveHook;
  end;

  PWindowsHotPatchBuffer = ^RWindowsHotPatchBuffer;
  RWindowsHotPatchBuffer = packed record
    CodeBuffer: array [1..RWindowsHotPatch.PreBuffLen] of byte;
    HPTarget: RWindowsHotPatch;
    procedure WriteHookInPlace(const NewCode: pointer); {$IfNDef ICE2007} inline; {$EndIf}
    procedure WriteHookToBuffer(const NewCode, OldCode: pointer); overload; {$IfNDef ICE2007} inline; {$EndIf}
    class procedure WriteHookToBuffer(const NewCode, OldCode, Buffer: pointer); overload; inline; static;
  end;

type
  PFastSysCall = ^RFastSysCall;
  RFastSysCall = packed record
    OpCode: byte;
    Value: NativeInt;
    const EtalonOpCode = $B8;  // MOV EAX, CONST
          EtalonOpCodeMask = $07; // MOV EAX..EDI, CONST

    function IsThisPattern: boolean; overload; {$IfNDef ICE2007} inline; {$EndIf}
    class function IsThisPattern(const at: pointer): boolean; overload; inline; static;
  end;

implementation
uses SysUtils; // WordRec

{ RAbsoluteIndirectJmp }

class function RAbsoluteIndirectJmp.IsThisPattern(const at: pointer): boolean;
begin
  Result := PAbsoluteIndirectJmp(at)^.OpCode = EtalonOpCode;
end;

function RAbsoluteIndirectJmp.IsThisPattern: boolean;
begin
  Result := IsThisPattern(@Self);
end;

class function RAbsoluteIndirectJmp.TargetAddress(const at: pointer): Pointer;
begin
  Assert(IsThisPattern(at), 'Wrong OpCode!');
  Result := PAbsoluteIndirectJmp(at)^.Addr^;
end;

function RAbsoluteIndirectJmp.TargetAddress: Pointer;
begin
  Result := TargetAddress(@Self);
end;


{ RRelativeLongJmp }

class function RRelativeLongJmp.IsThisPattern(const at: pointer): boolean;
begin
  Result := PRelativeLongJmp(at)^.OpCode = EtalonOpCode;
end;

function RRelativeLongJmp.IsThisPattern: boolean;
begin
  Result := IsThisPattern(@Self);
end;

class function RRelativeLongJmp.TargetAddress(const at: pointer): Pointer;
var PJmp: PRelativeLongJmp absolute at;
begin
{$R-}
  Result := Pointer(
       NativeInt(at)
       + PJmp^.Offset
       + SizeOf(RRelativeLongJmp)
  );
// https://wasm.in/threads/jmp-v-e9-kak-opredelit-operand-mashinnogo-koda.25851
// https://stackoverflow.com/questions/8196835/calculate-the-jmp-opcodes
end;

function RRelativeLongJmp.TargetAddress: Pointer;
begin
  Result := TargetAddress(@Self);
end;

class procedure RRelativeLongJmp.WriteHookToBuffer(const NewCode, OldCode,
  Buffer: pointer);
var PJmp: PRelativeLongJmp absolute Buffer;
begin
  with PJmp^ do begin
    Offset := NativeInt(NewCode)
	    - SizeOf(RRelativeLongJmp)
	    - NativeInt(OldCode);
    Assert( NewCode = TargetAddress(), 'RRelativeLongJmp.WriteHook' );
    OpCode := EtalonOpCode;
  end;
end;

procedure RRelativeLongJmp.WriteHookToBuffer(const NewCode, OldCode: pointer);
begin
  WriteHookToBuffer(NewCode, OldCode, @Self);
end;

procedure RRelativeLongJmp.WriteHookInPlace(const NewCode: pointer);
begin
  WriteHookToBuffer(NewCode, @Self, @Self);
end;

{ RWindowsHotPatch }

function RWindowsHotPatch.IsThisPattern: boolean;
var PB: PByte; i: integer;
begin
  Result := OpCode = TargetOpCode;
  if not Result then exit;

  PB := pointer(@Self);
  for i := 1 to PreBuffLen do begin
    Dec(PB);
    Result := (PB^ = FillerOpCode1) or (PB^ = FillerOpCode2);
    if not Result then exit;
  end;
end;

procedure RWindowsHotPatch.RemoveHook;
var PB: PByte; i: integer;
begin
  OpCode := TargetOpCode;
  PB := pointer(@Self);
  for i := 1 to PreBuffLen do begin
    Dec(PB);
    PB^ := FillerOpCode2;
  end;
end;

procedure RWindowsHotPatch.WriteHookInPlace(const NewCode: pointer);
begin
  WriteHookToBuffer(NewCode, @Self);
end;

procedure RWindowsHotPatch.WriteHookToBuffer(const NewCode, OldCode: pointer);
var PJ: PRelativeLongJmp;
    w: word; b2: WordRec absolute w;
begin
  Assert(PreBuffLen = SizeOf(RRelativeLongJmp), 'RWindowsHotPatch.WriteHook');

  b2.Lo := $EB; //  EBF9  jmp SHORT PTR $-5
  ShortInt(b2.Hi) := -( SizeOf(b2) + PreBuffLen );

  PJ := Pointer(PAnsiChar(@Self) - PreBuffLen);

  PJ^.WriteHookInPlace(NewCode);

  PWord(@Self)^ := w;
end;

{ RWindowsHotPatchBuffer }

procedure RWindowsHotPatchBuffer.WriteHookInPlace(const NewCode: pointer);
begin
  WriteHookToBuffer( NewCode, @Self.HPTarget, @Self );
end;

class procedure RWindowsHotPatchBuffer.WriteHookToBuffer
  (const NewCode, OldCode, Buffer: pointer);
begin
  PWindowsHotPatchBuffer(Buffer)^.HPTarget.WriteHookToBuffer(NewCode, OldCode);
end;

procedure RWindowsHotPatchBuffer.WriteHookToBuffer(const NewCode,
  OldCode: pointer);
begin
  WriteHookToBuffer( NewCode, OldCode, @Self );
end;

{ RFastSysCall }

class function RFastSysCall.IsThisPattern(const at: pointer): boolean;
begin
  Result := PFastSysCall(at)^.OpCode and not EtalonOpCodeMask = EtalonOpCode;
end;

function RFastSysCall.IsThisPattern: boolean;
begin
  Result := IsThisPattern(@Self);
end;

end.
