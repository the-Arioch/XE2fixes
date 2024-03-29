// (C) Arioch 'The, licensed under GNU GPL v.3
// https://github.com/the-Arioch/XE2fixes.git
// �������� ������� � ������ "����������" ��� ��� ������� �������� ������
// ����� ���������� � ��-���������� ����������� WIN NT x86 (�� �������������� x64!).
// ������� ����� ������ ��������� "���������" ������������ CloseClipboard �
// �������� CF_LOCALE, ���� ���������� ��������� ������ ��� ��������.
// ��� ������� �� ����� ������ �������� �������, ��� ��� ����������� � �����
// ������������ ������������ �������...
unit ClipboardLocaleFixIn;

{$WARN SYMBOL_PLATFORM OFF}{$T+}{$W-}

{.$Define HookAtWill} // ������� ��� ~ for debug purposes

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


{$if CompilerVersion < 19}
type  UnicodeString = WideString;
const LOCALE_CUSTOM_UI_DEFAULT = $1400;
const LOCALE_CUSTOM_DEFAULT = $0C00;
{$ifend}
const LOCALE_CUSTOM_USER_DEFAULT = $0C00; // different docs claim different names

var // would be missed on pre-Vista
  GetThreadUILanguage: function (): LANGID; stdcall;

var
  GoodLocales: array [1..6] of LANGID =
  ( $ffFF, LOCALE_USER_DEFAULT, LOCALE_SYSTEM_DEFAULT,
    LOCALE_CUSTOM_DEFAULT, LOCALE_CUSTOM_UI_DEFAULT, $ffFF);

procedure TryFixPaste;
var
  Data: THandle; Ptr: PCardinal;
  Ansi: AnsiString; U16: UnicodeString;
  Locale: LCID; LocParsed: LongRec absolute Locale;
  MakeAnsi, MakeUni: boolean; W: LANGID;
  i, L, cntA, cntU: Cardinal;
  cA: AnsiChar; cW: WideChar; cWParsed: WordRec absolute cW;
  procedure InnerSetBuffer(const Format: Word; const Buffer: Pointer; Size: Integer);
  var
    Data: THandle;
    DataPtr: Pointer;
  begin
    Data := GlobalAlloc(GMEM_MOVEABLE+GMEM_DDESHARE, Size);
    try
      DataPtr := GlobalLock(Data);
      try
        Move(Buffer^, DataPtr^, Size);
      finally
        GlobalUnlock(Data);
      end;
      if SetClipboardData(Format, Data) <> 0 then
         Data := 0;
    finally
      if Data <> 0 then
         GlobalFree(Data);
    end;
  end;
begin
  if not IsClipboardFormatAvailable(CF_UNICODETEXT) then exit;

  Locale := GetThreadLocale;
  GoodLocales[1] := LocParsed.Lo;

  if nil <> @GetThreadUILanguage then
     GoodLocales[6] := GetThreadUILanguage();

  Data := GetClipboardData(CF_LOCALE);
  try
    Locale := Cardinal(-2);
    if Data <> 0 then begin
      Ptr := GlobalLock(Data);
      if Ptr <> nil then
         Locale := Ptr^;
    end
  finally
    if Data <> 0 then
      GlobalUnlock(Data);
  end;

  for W in GoodLocales do
    if W = LocParsed.Lo then
      Exit;

  Data := GetClipboardData(CF_UNICODETEXT);
  try
    if Data <> 0 then
      U16 := PWideChar(GlobalLock(Data))
    else
      U16 := '';
  finally
    if Data <> 0 then
      GlobalUnlock(Data);
  end;

  Data := GetClipboardData(CF_TEXT);
  try
    if Data <> 0 then
      Ansi := PAnsiChar(GlobalLock(Data))
    else
      Ansi := '';
  finally
    if Data <> 0 then
      GlobalUnlock(Data);
  end;

  MakeAnsi := False;
  MakeUni  := False;

  if Length(Ansi) <= 0 then begin
     MakeAnsi := Length(U16) > 0;
     if not MakeAnsi then
        exit;
  end else begin
     MakeUni := Length(U16) <= 0;
     if not MakeUni then begin
        // ���������� ������ - ��������� ��� ����...
        L := Length(Ansi);
        i := Length(U16);
        if i < L then L := i;

        cntA := 0; cntU := 0;
        for i := 1 to L do begin
          cA := Ansi[i];
          cW := U16[i];

          if cWParsed.Hi = 0 then begin
             if ((cWParsed.Lo and $80) <> 0) and (cWParsed.Lo = Ord(cA)) then
                Inc(cntU);
          end else begin
             if (cA = '?') and (cWParsed.Lo <> $3F) then
                Inc(cntA);
          end;
        end;

        MakeAnsi := (cntA + cntA) > cntU;
        MakeUni  := (cntU + cntU) > cntA;
     end;
  end;

  if MakeAnsi then begin
     Ansi := AnsiString(U16);
     InnerSetBuffer( CF_TEXT, @Ansi[1], SizeOf(Ansi[1])*(Length(Ansi) + 1));

     CharToOemA(@Ansi[1], @Ansi[1]);
     InnerSetBuffer( CF_OEMTEXT, @Ansi[1],
                     SizeOf(Ansi[1]) * (StrLen(PAnsiChar(@Ansi[1])) + 1));
  end else
  if MakeUni then begin
     U16 := UnicodeString(Ansi);
     InnerSetBuffer( CF_UNICODETEXT, @U16[1], SizeOf(U16[1])*(Length(U16) + 1) );
  end;
  if MakeUni or MakeAnsi then begin
     if GoodLocales[6] < $FF00
        then LocParsed.Lo := GoodLocales[6]
        else LocParsed.Lo := GoodLocales[1];
     InnerSetBuffer( CF_LOCALE, @LocParsed, SizeOf(LocParsed) );
  end;
end;

var ContinueOpenClipboard: pointer;

procedure OpenClipboard5Bytes; forward;

procedure InterceptOpenClipboard;
asm
  POP ECX; POP EDX
  PUSH ECX; PUSH EDX;

  CALL OpenClipboard5Bytes
  PUSH EAX

  CALL TryFixPaste
  POP EAX
end;

procedure OpenClipboard5Bytes; assembler;
asm
  NOP;
  NOP;
  NOP;
  NOP;
  NOP;

  JMP DWORD PTR [ContinueOpenClipboard]
end;

procedure InterceptNtUserOpenClipboard;
asm
  POP ECX; POP EDX; POP EAX
  PUSH ECX; PUSH EAX; PUSH EDX;

  CALL OpenClipboard5Bytes
  PUSH EAX

  CALL TryFixPaste
  POP EAX
end;

function StartOfOpenClipboard: pointer;
begin
  Result := GetProcAddress(LoadLibrary(user32), 'OpenClipboard' );
end;

function StartOfNtUserOpenClipboard: pointer;
var LIB: THandle;
begin
  Result := nil;
  LIB := LoadLibrary('Win32U.DLL');
  if 0 = LIB then exit;  // Old OS without user/kernel gateway

  Result := GetProcAddress(LIB, 'NtUserOpenClipboard' );
//  FreeLibrary(LIB); - no! if this library present it is the real user32.dll
//  backend and is never freed until process exit. Also, we should not release
//  our hook code path.
end;

function CanMethod_HotPatch: boolean; forward;
function CanMethod_FastSysCall: boolean; forward;

procedure InstallMethod_HotPatch; forward;
procedure InstallMethod_FastSysCall_User32; forward;
procedure InstallMethod_FastSysCall_Win32U; forward;

procedure RemoveMethod_HotPatch; forward;
procedure RemoveMethod_FastSysCall; forward;

function detectMethod: byte;
begin
  Result := 0;
  HookError := heNotWinNT;
  if Win32Platform <> VER_PLATFORM_WIN32_NT then exit;

  HookError := heNoError;

  HookOriginalAddress := StartOfNtUserOpenClipboard;
  if HookOriginalAddress <> nil then begin
    Result := 3; if CanMethod_FastSysCall then Exit;
  end;

  HookOriginalAddress := StartOfOpenClipboard;
  if HookOriginalAddress <> nil then begin
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
       2: InstallMethod_FastSysCall_User32;
       3: InstallMethod_FastSysCall_Win32U;
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
    2,3: RemoveMethod_FastSysCall;
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
  PostHP: PWindowsHotPatchBuffer absolute ContinueOpenClipboard;
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
    HP^.WriteHookInPlace(@InterceptOpenClipboard);
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

procedure InstallMethod_FastSysCall(const API_Interceptor: Pointer);
var
  PJmp: PRelativeLongJmp;
  PostJmp: PRelativeLongJmp absolute ContinueOpenClipboard;
  n: SIZE_T;
  OldProt: Cardinal;
  Success: Boolean;
begin
  // copy MOV EAX, XXX to OpenClipboard5Bytes
  PJmp := HookOriginalAddress;

  Success := WriteProcessMemory(GetCurrentProcess,
		@OpenClipboard5Bytes, PJmp, SizeOf(PJmp^), n)
                and (n = SizeOf(RFastSysCall));

  HookError := heCanNotInstall;
  if not Success then exit;

  // install patch

  PostJmp := PJmp; Inc(PostJmp); // no pointermath in D2007

  Win32Check( VirtualProtect( PJmp, SizeOf(PJmp^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    PJmp^.WriteHookInPlace(API_Interceptor);
    FlushInstructionCache(GetCurrentProcess, PJmp, SizeOf(PJmp^));
  finally
    Win32Check( VirtualProtect( PJmp, SizeOf(PJmp^), OldProt, OldProt) );
  end;

  HookInstalled := True;
  HookError := heNoError;
end;

procedure InstallMethod_FastSysCall_User32;
begin
  InstallMethod_FastSysCall(@InterceptOpenClipboard)
end;

procedure InstallMethod_FastSysCall_Win32U;
begin
  InstallMethod_FastSysCall(@InterceptNtUserOpenClipboard)
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
			  PJmp, @OpenClipboard5Bytes, SizeOf(PJmp^), n)
	     and (n = SizeOf(RFastSysCall));

  HookError := heCanNotRemove;
  if not Success then exit;

  // flood NOPx5 to CloseOpen
  PHook := @OpenClipboard5Bytes;
  Win32Check( VirtualProtect( PHook, SizeOf(PJmp^), PAGE_EXECUTE_READWRITE, OldProt) );
  try
    FillChar( PHook^, SizeOf(PJmp^), $90 {NOP} );
    FlushInstructionCache(GetCurrentProcess, PHook, SizeOf(PJmp^));
  finally
    Win32Check( VirtualProtect( PHook, SizeOf(PJmp^), OldProt, OldProt) );
  end;
  ContinueOpenClipboard := nil;

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

initialization
  GetThreadUILanguage :=
       GetProcAddress( LoadLibrary( kernel32 ), 'GetThreadUILanguage');
{$IfNDef HookAtWill}
   InstallHook;
finalization
   RemoveHook;
{$EndIf HookAtWill}

end.