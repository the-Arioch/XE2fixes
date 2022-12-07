// (C) Arioch 'The, licensed under GNU GPL v.3
// ”бираем "кракоз€бры" при копировании русского текста между юникодными и
// не-юникодными программами WIN NT x86 (не поддерживаетс€ x64!).
// Ёто юнит исправл€ет "исход€щие" перехватыва€ CloseClipboard и
// добавл€€ CF_LOCALE, если копирующа€ программа забыла его добавить.
unit ClipboardLocaleFixOut;

{$WARN SYMBOL_PLATFORM OFF}

{$Define HookAtWill} // отладки дл€ ~ for debug purposes

{$T+}
interface

{$IfDef HookAtWill}
procedure InstallHook;
procedure RemoveHook;
{$EndIf HookAtWill}

{$IfNDef HookAtWill}
implementation
uses Windows,
     SysUtils; // Win32Platform
{$EndIf HookAtWill}

var
  HookMethod: byte;
  HookInstalled: boolean;
  HookError: (heNoError, heNotWinNT, heNoMethod, heCanNotRemove, heCanNotInstall);
  HookOriginalAddress: pointer;

{$IfDef HookAtWill}
implementation
uses Windows,
     SysUtils; // Win32Platform
{$EndIf HookAtWill}

{$Region ' -= Win32 patcher =- '}

{$if CompilerVersion < 19}
type
  NativeUInt = Cardinal; NativeInt = Integer;
// https://blog.dummzeuch.de/2018/09/08/nativeint-nativeuint-type-in-various-delphi-versions/
// https://stackoverflow.com/questions/7630781/delphi-2007-and-xe2-using-nativeint
{$ifend}

type
  PAbsoluteIndirectJmp = ^RAbsoluteIndirectJmp;
  RAbsoluteIndirectJmp = packed record
    OpCode: Word;
    Addr: ^Pointer;
    const EtalonOpCode = $25FF;

    function IsThisPattern: boolean; overload; inline;
    class function IsThisPattern(const at: pointer): boolean; overload; inline; static;

    function TargetAdress: Pointer; overload; inline;
    class function TargetAdress(const at: pointer): Pointer; overload; inline; static;
  end;

{ RAbsoluteIndirectJmp }

class function RAbsoluteIndirectJmp.IsThisPattern(const at: pointer): boolean;
begin
  Result := PAbsoluteIndirectJmp(at)^.OpCode = EtalonOpCode;
end;

function RAbsoluteIndirectJmp.IsThisPattern: boolean;
begin
  Result := IsThisPattern(@Self);
end;

class function RAbsoluteIndirectJmp.TargetAdress(const at: pointer): Pointer;
begin
  Assert(IsThisPattern(at), 'Wrong OpCode!');
  Result := PAbsoluteIndirectJmp(at)^.Addr^;
end;

function RAbsoluteIndirectJmp.TargetAdress: Pointer;
begin
  Result := TargetAdress(@Self);
end;

// ==================

type
  PRelativeLongJmp = ^RRelativeLongJmp;
  RRelativeLongJmp = packed record
    OpCode: byte;
    Offset: NativeInt;
    const EtalonOpCode = $E9;

    function IsThisPattern: boolean; overload; inline;
    class function IsThisPattern(const at: pointer): boolean; overload; inline; static;

    function TargetAdress: Pointer; overload; inline;
    class function TargetAdress(const at: pointer): Pointer; overload; inline; static;

    procedure WriteHookInPlace(const NewCode: pointer); inline;
    procedure WriteHookToBuffer(const NewCode, OldCode: pointer); overload; inline;
    class procedure WriteHookToBuffer(const NewCode, OldCode, Buffer: pointer); overload; inline; static;
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

class function RRelativeLongJmp.TargetAdress(const at: pointer): Pointer;
begin
{$R-}
  Result := Pointer(
       NativeInt(at)
       + PRelativeLongJmp(at)^.Offset
       + SizeOf(RRelativeLongJmp)
  );
// https://wasm.in/threads/jmp-v-e9-kak-opredelit-operand-mashinnogo-koda.25851
// https://stackoverflow.com/questions/8196835/calculate-the-jmp-opcodes
end;

function RRelativeLongJmp.TargetAdress: Pointer;
begin
  Result := TargetAdress(@Self);
end;

class procedure RRelativeLongJmp.WriteHookToBuffer(const NewCode, OldCode,
  Buffer: pointer);
begin
  with PRelativeLongJmp(Buffer)^ do begin
    Offset := NativeInt(NewCode)
            - SizeOf(RRelativeLongJmp)
            - NativeInt(OldCode);
    Assert( NewCode = TargetAdress(), 'RRelativeLongJmp.WriteHook' );
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

// ==================
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
    procedure WriteHookInPlace(const NewCode: pointer); inline;
    procedure WriteHookToBuffer(const NewCode, OldCode: pointer); overload; inline;
    class procedure WriteHookToBuffer(const NewCode, OldCode, Buffer: pointer); overload; inline; static;
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

  PJ := Pointer(PByte(@Self) - PreBuffLen);

  PJ^.WriteHookToBuffer(NewCode, OldCode);

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

// ==============

type
  PFastSysCall = ^RFastSysCall;
  RFastSysCall = packed record
    OpCode: byte;
    Value: NativeInt;
    const EtalonOpCode = $B8;  // MOV EAX, CONST
          EtalonOpCodeMask = $07; // MOV EAX..EDI, CONST

    function IsThisPattern: boolean; overload; inline;
    class function IsThisPattern(const at: pointer): boolean; overload; inline; static;
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

{$EndRegion}

procedure InjectLocale;
var
  Loc: ^LCID;
  Mem, Clip: THandle;
begin
  Clip := 0;
  Mem := GlobalAlloc(GMEM_MOVEABLE+GMEM_DDESHARE, SizeOf(Loc^));
  try
    Loc := GlobalLock(Mem);
    try
      Loc^ := LOCALE_USER_DEFAULT;
      Clip := SetClipboardData(CF_LOCALE, Mem);
    finally
      GlobalUnlock(Mem);
    end;
  finally
    if Clip <> 0 then
       GlobalFree(Mem);
  end;
end;

function NeedAddLocale: boolean;
begin
  Result := (not IsClipboardFormatAvailable(CF_LOCALE))
     and ( IsClipboardFormatAvailable(CF_TEXT)
        or IsClipboardFormatAvailable(CF_UNICODETEXT)
        or IsClipboardFormatAvailable(CF_OEMTEXT) );
end;

var ContinueCloseClipboard: pointer;

procedure CloseClipboard5Bytes; forward;

procedure InterceptCloseClipboard; assembler;
asm
  call NeedAddLocale;
  or AL, AL;
  jz @NoInject;
  call InjectLocale;
@NoInject:     // к сожалению, адрес этой метки вз€ть нельз€

  jmp CloseClipboard5Bytes
end;

procedure CloseClipboard5Bytes; assembler;
asm
  NOP;
  NOP;
  NOP;
  NOP;
  NOP;

  JMP DWORD PTR [ContinueCloseClipboard]
end;

function StartOfCloseClipboard: pointer;
begin
  Result := GetProcAddress(LoadLibrary('user32.dll'), 'CloseClipboard' );
end;

function CanMethod_HotPatch: boolean; forward;
function CanMethod_FastSysCall: boolean; forward;

procedure InstallMethod_HotPatch; forward;
procedure InstallMethod_FastSysCall; forward;

procedure RemoveMethod_HotPatch; forward;
procedure RemoveMethod_FastSysCall; forward;

function detectMethod: byte;
begin
  Result := 0;
  HookError := heNotWinNT;
  if Win32Platform <> VER_PLATFORM_WIN32_NT then exit;

  HookOriginalAddress := StartOfCloseClipboard;

  HookError := heNoError;
  if CanMethod_HotPatch then Exit(1);
  if CanMethod_FastSysCall then Exit(2);

  HookError := heNoMethod;
  HookOriginalAddress := nil;
end;

procedure InstallHook;
begin
  if HookInstalled then exit;

  if HookMethod = 0 then
     HookMethod := detectMethod;

  if (HookMethod > 0) and (HookError = heNoError) then begin
     HookError := heCanNotInstall;
     case HookMethod of
       1: InstallMethod_HotPatch;
       2: InstallMethod_FastSysCall;
     else
       HookError := heNoMethod;
     end;

     HookInstalled := HookError = heNoError;
  end;
end;

procedure RemoveHook;
begin
  if not HookInstalled then exit;

  case HookMethod of
    1: RemoveMethod_HotPatch;
    2: RemoveMethod_FastSysCall;
  else
    HookError := heNoMethod;
  end;

  if HookInstalled then
     HookError := heCanNotRemove;
end;

function CanMethod_HotPatch: boolean;
begin
  Result := PWindowsHotPatch(HookOriginalAddress)^.IsThisPattern;
end;

function CanMethod_FastSysCall: boolean;
begin
  Result := PFastSysCall(HookOriginalAddress)^.IsThisPattern;
end;

procedure InstallMethod_HotPatch;
var
  OldProt: Cardinal;
  HP: PWindowsHotPatchBuffer;
begin
  HP := Pointer(PByte(HookOriginalAddress) - HP^.HPTarget.PreBuffLen);
  Assert( @HP^.HPTarget = HookOriginalAddress, 'InstallMethod_HotPatch' );

  // force memory pages committed
{$O-}
  OldProt := PNativeUInt(HookOriginalAddress)^;
  OldProt := PNativeUInt(HP)^;
{$O+}

  Win32Check( VirtualProtect( HP, SizeOf(HP^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    HP^.WriteHookInPlace(@InterceptCloseClipboard);
  finally
    Win32Check( VirtualProtect( HP, SizeOf(HP^), OldProt, OldProt) );
  end;

  HookInstalled := True;
  HookError := heNoError;
end;

procedure RemoveMethod_HotPatch;
var
  OldProt: Cardinal;
  HP: PWindowsHotPatchBuffer;
begin
  HP := Pointer(PByte(HookOriginalAddress) - HP^.HPTarget.PreBuffLen);
  Assert( @HP^.HPTarget = HookOriginalAddress, 'RemoveMethod_HotPatch' );

  // force memory pages committed
{$O-}
  OldProt := PNativeUInt(HookOriginalAddress)^;
  OldProt := PNativeUInt(HP)^;
{$O+}

  Win32Check( VirtualProtect( HP, SizeOf(HP^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    HP^.HPTarget.RemoveHook;
  finally
    Win32Check( VirtualProtect( HP, SizeOf(HP^), OldProt, OldProt) );
  end;

  HookInstalled := False;
  HookError := heNoError;
end;

procedure InstallMethod_FastSysCall;
begin
  // copy MOV EAX, XXX to CloseClipboard5Bytes

  // install patch

  HookInstalled := True;
  HookError := heNoError;
end;

procedure RemoveMethod_FastSysCall;
begin
  // remove patch

  // flood NOPx5 to CloseClipboard5Bytes


  HookInstalled := False;
  HookError := heNoError;
end;

{$IfNDef HookAtWill}
initialization
   InstallHook;
finalization
   RemoveHook;
{$EndIf HookAtWill}

end.
