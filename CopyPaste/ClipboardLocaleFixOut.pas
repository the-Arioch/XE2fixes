// (C) Arioch 'The, licensed under GNU GPL v.3
// https://github.com/the-Arioch/XE2fixes.git
// ”бираем "кракоз€бры" при копировании русского текста между юникодными и
// не-юникодными программами WIN NT x86 (не поддерживаетс€ x64!).
// Ёто юнит исправл€ет "исход€щие" перехватыва€ CloseClipboard и
// добавл€€ CF_LOCALE, если копирующа€ программа забыла его добавить.
unit ClipboardLocaleFixOut;

{$WARN SYMBOL_PLATFORM OFF}{$T+}{$W-}

{.$Define HookAtWill} // отладки дл€ ~ for debug purposes

interface

{$IfDef HookAtWill}
procedure InstallHook;
procedure RemoveHook;
{$EndIf HookAtWill}

{$IfNDef HookAtWill}
implementation
uses
  Win32SimpleHooks,
  Windows,
  SysUtils; // Win32Platform
{$EndIf HookAtWill}

var
  HookMethod: byte;
  HookInstalled: boolean;
  HookError: (heNoError, heNotWinNT, heNoMethod, heCanNotRemove, heCanNotInstall);
  HookOriginalAddress: pointer;

{$IfDef HookAtWill}
implementation
uses
  Win32SimpleHooks,
  Windows,
  SysUtils; // Win32Platform
{$EndIf HookAtWill}

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
      Loc^ := GetThreadLocale(); // LOCALE_USER_DEFAULT;
    finally
      GlobalUnlock(Mem);
    end;
    Clip := SetClipboardData(CF_LOCALE, Mem);
  finally
    if Clip = 0 then
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
  Result := GetProcAddress(LoadLibrary(user32), 'CloseClipboard' );
end;

function StartOfNtUserCloseClipboard: pointer;
var LIB: THandle;
begin
  Result := nil;
  LIB := LoadLibrary('Win32U.DLL');
  if 0 = LIB then exit; // Old OS without user/kernel gateway

  Result := GetProcAddress(LIB, 'NtUserCloseClipboard' );
//  FreeLibrary(LIB); - no! if this library present it is the real user32.dll
//  backend and is never freed until process exit. Also, we should not release
//  our hook code path.
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

  HookError := heNoError;

  HookOriginalAddress := StartOfNtUserCloseClipboard;
  if nil <> HookOriginalAddress then begin
     Result := 3; if CanMethod_FastSysCall then Exit;
  end;

  HookOriginalAddress := StartOfCloseClipboard;
  if nil <> HookOriginalAddress then begin
     Result := 1; if CanMethod_HotPatch then Exit;
     Result := 2; if CanMethod_FastSysCall then Exit;
  end;

  Result := 0;
  HookError := heNoMethod;
  HookOriginalAddress := nil;
end;

procedure InstallHook;
begin
  if HookInstalled then exit;

{$IfDef HookAtWill} // debug
  HookMethod := 0;
  HookError := heNoError;
{$EndIf}

  if HookMethod = 0 then
     HookMethod := detectMethod;

  if (HookMethod > 0) and (HookError = heNoError) then begin
     HookError := heCanNotInstall;
     case HookMethod of
       1: InstallMethod_HotPatch;
       2,3: InstallMethod_FastSysCall;
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
    2, 3: RemoveMethod_FastSysCall;
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
  Assert( SizeOf(RRelativeLongJmp) = SizeOf(RFastSysCall), 'CanMethod_FastSysCall' );
end;

procedure InstallMethod_HotPatch;
var
  OldProt: Cardinal;
  HP: PWindowsHotPatchBuffer;
  PostHP: PWindowsHotPatchBuffer absolute ContinueCloseClipboard;
begin
  HP := Pointer(PAnsiChar(HookOriginalAddress) - HP^.HPTarget.PreBuffLen);
  Assert( @HP^.HPTarget = HookOriginalAddress, 'InstallMethod_HotPatch' );

  // force memory pages committed
{$O-}
  OldProt := PNativeUInt(HookOriginalAddress)^;
  OldProt := PNativeUInt(HP)^;
{$O+}

  PostHP := HP; Inc(PostHP); // no pointermath in D2007

  Win32Check( VirtualProtect( HP, SizeOf(HP^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    HP^.WriteHookInPlace(@InterceptCloseClipboard);
    FlushInstructionCache(GetCurrentProcess, HP, SizeOf(HP^));
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
  HP := Pointer(PAnsiChar(HookOriginalAddress) - HP^.HPTarget.PreBuffLen);
  Assert( @HP^.HPTarget = HookOriginalAddress, 'RemoveMethod_HotPatch' );

  // force memory pages committed
{$O-}
  OldProt := PNativeUInt(HookOriginalAddress)^;
  OldProt := PNativeUInt(HP)^;
{$O+}

  Win32Check( VirtualProtect( HP, SizeOf(HP^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    HP^.HPTarget.RemoveHook;
    FlushInstructionCache(GetCurrentProcess, HP, SizeOf(HP^));
  finally
    Win32Check( VirtualProtect( HP, SizeOf(HP^), OldProt, OldProt) );
  end;

  HookInstalled := False;
  HookError := heNoError;
end;

procedure InstallMethod_FastSysCall;
var
  PJmp: PRelativeLongJmp;
  PostJmp: PRelativeLongJmp absolute ContinueCloseClipboard;
  n: SIZE_T;
  OldProt: Cardinal;
  Success: Boolean;
begin
  // copy MOV EAX, XXX to CloseClipboard5Bytes
  PJmp := HookOriginalAddress;

  Success := WriteProcessMemory(GetCurrentProcess,
		@CloseClipboard5Bytes, PJmp, SizeOf(PJmp^), n)
                and (n = SizeOf(RFastSysCall));

  HookError := heCanNotInstall;
  if not Success then exit;

  // install patch

  PostJmp := PJmp; Inc(PostJmp); // no pointermath in D2007

  Win32Check( VirtualProtect( PJmp, SizeOf(PJmp^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    PJmp^.WriteHookInPlace(@InterceptCloseClipboard);
    FlushInstructionCache(GetCurrentProcess, PJmp, SizeOf(PJmp^));
  finally
    Win32Check( VirtualProtect( PJmp, SizeOf(PJmp^), OldProt, OldProt) );
  end;

  HookInstalled := True;
  HookError := heNoError;
end;

procedure RemoveMethod_FastSysCall;
var
  PJmp: PRelativeLongJmp;
  PHook: pointer;
  n: SIZE_T;
  OldProt: Cardinal;
  Success: Boolean;
begin
  // remove patch
  PJmp := HookOriginalAddress;

  Success := WriteProcessMemory(GetCurrentProcess,
			  PJmp, @CloseClipboard5Bytes, SizeOf(PJmp^), n)
	     and (n = SizeOf(RFastSysCall));

  HookError := heCanNotRemove;
  if not Success then exit;

  // flood NOPx5 to CloseClipboard5Bytes
  PHook := @CloseClipboard5Bytes;
  Win32Check( VirtualProtect( PHook, SizeOf(PJmp^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    FillChar( PHook^, SizeOf(PJmp^), $90 {NOP} );
    FlushInstructionCache(GetCurrentProcess, PHook, SizeOf(PJmp^));
  finally
    Win32Check( VirtualProtect( PHook, SizeOf(PJmp^), OldProt, OldProt) );
  end;
  ContinueCloseClipboard := nil;

  HookInstalled := False;
  HookError := heNoError;
end;

(****  Win10 Pro 22H2 19045.2364
win32u.NtUserCloseClipboard:
76591C20 B8C2100100       mov eax,$000110c2
76591C25 BA10635976       mov edx,$76596310
76591C2A FFD2             call edx
76591C2C C3               ret
76591C2D 8D4900           lea ecx,[ecx+$00]
win32u.NtUserOpenClipboard:
76591C30 B8C3100700       mov eax,$000710c3
76591C35 BA10635976       mov edx,$76596310
76591C3A FFD2             call edx
76591C3C C20800           ret $0008
76591C3F 90               nop
win32u.NtUserSetClipboardData:
76591C40 B8C4100F00       mov eax,$000f10c4
76591C45 BA10635976       mov edx,$76596310
76591C4A FFD2             call edx
76591C4C C20C00           ret $000c
76591C4F 90               nop
****)

{$IfNDef HookAtWill}
initialization
   InstallHook;
finalization
   RemoveHook;
{$EndIf HookAtWill}

end.
