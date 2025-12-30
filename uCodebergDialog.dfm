object CodebergDialog: TCodebergDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Create Codeberg Repository'
  ClientHeight = 180
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  TextHeight = 15
  object lblRepoName: TLabel
    Left = 16
    Top = 20
    Width = 94
    Height = 15
    Caption = 'Repository Name:'
  end
  object lblDescription: TLabel
    Left = 16
    Top = 56
    Width = 63
    Height = 15
    Caption = 'Description:'
  end
  object edtRepoName: TEdit
    Left = 130
    Top = 17
    Width = 250
    Height = 23
    TabOrder = 0
  end
  object edtDescription: TEdit
    Left = 130
    Top = 53
    Width = 250
    Height = 23
    TabOrder = 1
  end
  object chkPrivate: TCheckBox
    Left = 130
    Top = 92
    Width = 150
    Height = 17
    Caption = 'Private Repository'
    TabOrder = 2
  end
  object btnOK: TButton
    Left = 216
    Top = 140
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 3
  end
  object btnCancel: TButton
    Left = 305
    Top = 140
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 4
  end
end
