object Form31: TForm31
  Left = 0
  Top = 0
  Caption = 'Clipboard API test'
  ClientHeight = 485
  ClientWidth = 756
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnHide = FormHide
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    AlignWithMargins = True
    Left = 240
    Top = 3
    Width = 513
    Height = 479
    Margins.Left = 240
    Align = alClient
    Lines.Strings = (
      'Memo1')
    TabOrder = 0
  end
  object btnA2U: TButton
    Left = 24
    Top = 32
    Width = 185
    Height = 41
    Caption = 'ANSI -> Unicode'
    TabOrder = 1
    OnClick = btnA2UClick
  end
  object btnU2A: TButton
    Left = 24
    Top = 104
    Width = 185
    Height = 41
    Caption = 'Unicode -> ANSI'
    TabOrder = 2
    OnClick = btnU2AClick
  end
  object btnCOC: TButton
    Left = 24
    Top = 344
    Width = 185
    Height = 41
    Caption = 'call OC'
    TabOrder = 3
    OnClick = btnCOCClick
  end
  object btnCSD: TButton
    Left = 24
    Top = 391
    Width = 185
    Height = 41
    Caption = 'call SD'
    TabOrder = 4
    OnClick = btnCSDClick
  end
  object btnCCC: TButton
    Left = 24
    Top = 436
    Width = 185
    Height = 41
    Caption = 'call CC'
    TabOrder = 5
    OnClick = btnCCCClick
  end
  object btnCEC: TButton
    Left = 24
    Top = 297
    Width = 185
    Height = 41
    Caption = 'call EC'
    TabOrder = 6
    OnClick = btnCECClick
  end
  object chkLoc: TCheckBox
    Left = 8
    Top = 176
    Width = 97
    Height = 17
    Caption = 'Force LOCALE'
    TabOrder = 7
    OnClick = chkLocClick
  end
  object chkPatchOut: TCheckBox
    Left = 111
    Top = 176
    Width = 113
    Height = 17
    Alignment = taLeftJustify
    Caption = 'Patch Copy(Out)'
    TabOrder = 8
    OnClick = chkPatchOutClick
  end
  object chkPatchIn: TCheckBox
    Left = 112
    Top = 199
    Width = 113
    Height = 17
    Alignment = taLeftJustify
    Caption = 'Patch Paste(In)'
    TabOrder = 9
    OnClick = chkPatchInClick
  end
  object btnGetLCID: TButton
    Left = 48
    Top = 239
    Width = 129
    Height = 41
    Caption = 'Paste Locale'
    TabOrder = 10
    OnClick = btnGetLCIDClick
  end
  object chkLocEu: TCheckBox
    Left = 8
    Top = 199
    Width = 97
    Height = 17
    Caption = 'Guess LOCALE'
    Enabled = False
    TabOrder = 11
    OnClick = chkLocEuClick
  end
end
