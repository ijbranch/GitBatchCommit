object GitHubSettingsDialog: TGitHubSettingsDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'GitHub Settings'
  ClientHeight = 150
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  object lblUsername: TLabel
    Left = 16
    Top = 20
    Width = 58
    Height = 15
    Caption = 'Username:'
  end
  object lblToken: TLabel
    Left = 16
    Top = 60
    Width = 80
    Height = 15
    Caption = 'Access Token:'
  end
  object lblHelp: TLabel
    Left = 16
    Top = 93
    Width = 310
    Height = 15
    Caption = 'Generate token at: github.com/settings/tokens'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGray
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object edtUsername: TEdit
    Left = 110
    Top = 17
    Width = 270
    Height = 23
    TabOrder = 0
  end
  object edtToken: TEdit
    Left = 110
    Top = 57
    Width = 270
    Height = 23
    PasswordChar = '*'
    TabOrder = 1
  end
  object btnOK: TButton
    Left = 216
    Top = 115
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 2
  end
  object btnCancel: TButton
    Left = 305
    Top = 115
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 3
  end
end
