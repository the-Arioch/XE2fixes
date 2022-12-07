// (C) Arioch 'The, licensed under GNU GPL v.3
// ������� "����������" ��� ����������� �������� ������ ����� ���������� �
// ��-���������� ����������� WIN NT x86 (�� �������������� x64!).
// ��� ���� ���������� "���������" ������������ CloseClipboard �
// �������� CF_LOCALE, ���� ���������� ��������� ������ ��� ��������.
unit ClipboardLocaleFixOut;

{$T+}
interface

uses Windows;

implementation

uses SysUtils; // Win32Platform

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
@NoInject:     // � ���������, ����� ���� ����� ����� ������

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

var
  HookMethod: byte;
  HookInstalled: boolean;
  HookError: (heNoError, heNotWinNT, heNoMethod);
  HookOriginalAddress: pointer;

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
     case HookMethod of
       1: InstallMethod_HotPatch;
       2: InstallMethod_FastSysCall;
     else
       HookError := heNoMethod;
     end;

     HookInstalled := HookError = heNoError;
  end;
end;


function CanMethod_HotPatch:  boolean; begin end;
function CanMethod_FastSysCall: boolean; begin end;

procedure InstallMethod_HotPatch; begin end;
procedure InstallMethod_FastSysCall; begin end;

procedure RemoveMethod_HotPatch; begin end;
procedure RemoveMethod_FastSysCall; begin end;

end.
