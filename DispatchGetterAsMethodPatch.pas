unit DispatchGetterAsMethodPatch;
{$D-,L-}
{
  Calling indexed properties like Microsoft Word's .CentimetersToPoint - COM exception is thrown 
  due to broken DispatchInvoke routine in ComObj.pas ( System.Win.ComObj.pas in newer Delphi )
  
  To quote IDispatch original documentation from
           http://msdn.microsoft.com/en-us/library/windows/desktop/ms221486.aspx

  " Some languages cannot distinguish between retrieving a property and calling a method.
    In this case, you should set the flags DISPATCH_PROPERTYGET and DISPATCH_METHOD."

  And erroneous check for non-zero ArgCount is breaking correct behavior instead.
  
  Bug is reported to EMBT as http://qc.embarcadero.com/wc/qcmain.aspx?d=115373
  Bug is reported to FPC team as http://bugs.freepascal.org/view.php?id=24352
  
  More low-level info:
    *  http://stackoverflow.com/questions/16279098/
    *  http://stackoverflow.com/questions/16285138/
}

interface

implementation

uses
  Windows, SysConst, SysUtils, ComObj;

//var
//  _EmptyBSTR: PWideChar = nil;

(**** patch target:

XE2 Upd4 Hotfix 1 Win32:


 Call Invoke method on the given IDispatch interface using the given
  call descriptor, dispatch IDs, parameters, and result

procedure DispatchInvoke(const Dispatch: IDispatch; CallDesc: PCallDesc;
  DispIDs: PDispIDList; Params: Pointer; Result: PVariant);

System.Win.ComObj.pas.1764: begin
004A1FA0 55               push ebp
004A1FA1 8BEC             mov ebp,esp
004A1FA3 81C4C4FCFFFF     add esp,$fffffcc4
....
System.Win.ComObj.pas.1784: InvKind := DISPATCH_PROPERTYPUTREF;
004A2083 BE08000000       mov esi,$00000008
System.Win.ComObj.pas.1785: DispIDs[0] := DISPID_PROPERTYPUT;
004A2088 C707FDFFFFFF     mov [edi],$fffffffd
System.Win.ComObj.pas.1786: DispParams.rgdispidNamedArgs := @DispIDs[0];
004A208E 89BDC8FCFFFF     mov [ebp-$00000338],edi
System.Win.ComObj.pas.1787: Inc(DispParams.cNamedArgs);
004A2094 FF85D0FCFFFF     inc dword ptr [ebp-$00000330]
004A209A EB16             jmp $004a20b2      -- jump short - relative
System.Win.ComObj.pas.1789: else if (InvKind = DISPATCH_METHOD) and (CallDesc^.ArgCount = 0) and (Result <> nil) then
004A209C 83FE01           cmp esi,$01
004A209F 7511             jnz $004a20b2      -- jump conditional: relative
004A20A1 807B0100         cmp byte ptr [ebx+$01],$00                          *** WIPE !!! ***
004A20A5 750B             jnz $004a20b2      -- jump conditional: relative    *** WIPE !!! ***
004A20A7 837D0800         cmp dword ptr [ebp+$08],$00
004A20AB 7405             jz $004a20b2       -- jump conditional: relative
System.Win.ComObj.pas.1790: InvKind := DISPATCH_METHOD or DISPATCH_PROPERTYGET;
004A20AD BE03000000       mov esi,$00000003
System.Win.ComObj.pas.1792: FillChar(ExcepInfo, SizeOf(ExcepInfo), 0);
004A20B2 8D45DC           lea eax,[ebp-$24]
004A20B5 33C9             xor ecx,ecx
004A20B7 BA20000000       mov edx,$00000020
004A20BC E8532AF6FF       call @FillChar       -- 0xE8 - relative offset, yet SmartLinker can change it per-project
System.Win.ComObj.pas.1793: Status := Dispatch.Invoke(DispID, GUID_NULL, 0, InvKind, DispParams,
004A20C1 6A00             push $00
004A20C3 8D45DC           lea eax,[ebp-$24]
004A20C6 50               push eax
004A20C7 8B4508           mov eax,[ebp+$08]
004A20CA 50               push eax
004A20CB 8D85C4FCFFFF     lea eax,[ebp-$0000033c]
004A20D1 50               push eax
004A20D2 56               push esi
004A20D3 6A00             push $00
004A20D5 A1CC985300       mov eax,[$005398cc]   -- !!! kill abs. reloc. offset !!!
004A20DA 50               push eax
004A20DB 8B85D4FCFFFF     mov eax,[ebp-$0000032c]
004A20E1 50               push eax
004A20E2 8B85D8FCFFFF     mov eax,[ebp-$00000328]
004A20E8 50               push eax
004A20E9 8B00             mov eax,[eax]
004A20EB FF5018           call dword ptr [eax+$18] -- call v-table method - relative
System.Win.ComObj.pas.1795: if Status <> 0 then
004A20EE 85C0             test eax,eax
004A20F0 7408             jz $004a20fa    -- jump conditional: relative

***)

Const
   patch_maybe_proc_base  = $004A1FA0;

   patch_pattern_start = $004A2083      - patch_maybe_proc_base;
   patch_pattern_end   = $004A20F0 + 2  - patch_maybe_proc_base;
   patch_pattern_len = patch_pattern_end - patch_pattern_start;

   patch_target_start  = $004A20A1      - patch_maybe_proc_base;
   patch_target_end    = $004A20A7      - patch_maybe_proc_base;
   patch_target_len = patch_target_end - patch_target_start;

   patch_target_ignore_dword_1 = $004A20D5 + 1 - patch_maybe_proc_base;
   patch_target_ignore_dword_2 = $004A20BC + 1 - patch_maybe_proc_base;

   patch_x86_NOP = $90;


   TargetPattern : array [ 0 .. patch_pattern_len - 1] of byte = (
$BE, $08, $00, $00, $00,      //     mov esi,$00000008
$C7, $07, $FD, $FF, $FF, $FF, //     mov [edi],$fffffffd
$89, $BD, $C8, $FC, $FF, $FF, //     mov [ebp-$00000338],edi
$FF, $85, $D0, $FC, $FF, $FF, //     inc dword ptr [ebp-$00000330]
$EB, $16,                     //     jmp $004a20b2      -- jump short - relative
$83, $FE, $01,                //     cmp esi,$01
$75, $11,                     //     jnz $004a20b2      -- jump conditional: relative
$80, $7B, $01, $00,           //     cmp byte ptr [ebx+$01],$00                          *** WIPE !!! ***
$75, $0B,                     //     jnz $004a20b2      -- jump conditional: relative    *** WIPE !!! ***
$83, $7D, $08, $00,           //     cmp dword ptr [ebp+$08],$00
$74, $05,                     //     jz $004a20b2       -- jump conditional: relative
$BE, $03, $00, $00, $00,      //     mov esi,$00000003
$8D, $45, $DC,                //     lea eax,[ebp-$24]
$33, $C9,                     //     xor ecx,ecx
$BA, $20, $00, $00, $00,      //     mov edx,$00000020
$E8, 0*$53, 0*$2A, 0*$F6, 0*$FF, //  call @FillChar       -- !!! kill outer offset !!!
$6A, $00,                     //     push $00
$8D, $45, $DC,                //     lea eax,[ebp-$24]
$50,                          //     push eax
$8B, $45, $08,                //     mov eax,[ebp+$08]
$50,                          //     push eax
$8D, $85, $C4, $FC, $FF, $FF, //     lea eax,[ebp-$0000033c]
$50,                          //     push eax
$56,                          //     push esi
$6A, $00,                     //     push $00
$A1, 0*$CC, 0*$98, 0*$53, 0*$00, //  mov eax,[$005398cc]   -- !!! kill abs. reloc. offset !!!
$50,                          //     push eax
$8B, $85, $D4, $FC, $FF, $FF, //     mov eax,[ebp-$0000032c]
$50,                          //     push eax
$8B, $85, $D8, $FC, $FF, $FF, //     mov eax,[ebp-$00000328]
$50,                          //     push eax
$8B, $00,                     //     mov eax,[eax]
$FF, $50, $18,                //     call dword ptr [eax+$18] -- call v-table method - relative
$85, $C0,                     //     test eax,eax
$74, $08                      //     jz $004a20fa    -- jump conditional: relative
);

Var Patched: boolean = False;
function GetActualAddr(Proc: Pointer): Pointer; forward;

procedure Init;
var
  Base, Pad, Target: PByte;
  PDW: PDWORD;

  n: SIZE_T;
  Success: Boolean;

  PadBuff: array [ 0 .. patch_pattern_len - 1] of byte;
  NopBuff: array [ 0 .. patch_target_len - 1]  of byte;
begin
  Base := GetActualAddr( @ComObj.DispatchInvoke );
  Pad  := Base + patch_pattern_start;

  Move(Pad^, PadBuff[0], patch_pattern_len);

  PDW := @PadBuff[patch_target_ignore_dword_1 - patch_pattern_start];
  PDW^ := 0;

  PDW := @PadBuff[patch_target_ignore_dword_2 - patch_pattern_start];
  PDW^ := 0;

  Success := CompareMem(@TargetPattern[0], @PadBuff[0], patch_pattern_len);

  if Success then begin
     Target := Base + patch_target_start;
     FillChar(NopBuff[0], patch_target_len, patch_x86_NOP);

     Success := WriteProcessMemory(GetCurrentProcess,
                   Target, @NopBuff[0], patch_target_len, n) and (n = SizeOf(NopBuff));
  end;

  if not Success then
    raise EOleError.Create('ComObj.DispatchInvoke patching failed');

  Patched := True;
//  _EmptyBSTR := StringToOleStr(''); // leaks memory
end;


procedure Fini;
var
  Base, Pad, Target: PByte;
  n: SIZE_T;
begin
  // Restore original opcodes
  if not Patched then exit;

  Base := GetActualAddr( @ComObj.DispatchInvoke );

  Target := Base + patch_target_start;
  Pad := @TargetPattern[patch_target_start - patch_pattern_start];
  WriteProcessMemory(GetCurrentProcess, Target, Pad, patch_target_len, n);

  Patched := False;
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

initialization
  Init;

finalization
  Fini;

end.





