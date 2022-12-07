// (C) Arioch 'The, licensed under GNU GPL v.3
// ”бираем "кракоз€бры" при копировании русского текста между юникодными и
// не-юникодными программами WIN NT x86 (не поддерживаетс€ x64!).
// Ёто юнит исправл€ет "исход€щие" перехватыва€ CloseClipboard и
// добавл€€ CF_LOCALE, если копирующа€ программа забыла его добавить.
unit ClipboardLocaleFixOut;

{$T+}
interface

uses Windows;

implementation

uses SysUtils; // Win32Platform

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

var
  HookMethod: byte;
  HookInstalled: boolean;
  HookError: (heNoError, heNotWinNT, heNoMethod);
  HookOriginalAddress: pointer;

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
