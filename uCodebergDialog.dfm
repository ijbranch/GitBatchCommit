object CodebergDialog: TCodebergDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Create Codeberg Repository'
  ClientHeight = 212
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
  object lblProjectType: TLabel
    Left = 16
    Top = 124
    Width = 71
    Height = 15
    Caption = 'Project Type:'
    Visible = False
  end
  object cboProjectType: TComboBox
    Left = 130
    Top = 121
    Width = 250
    Height = 23
    Style = csDropDownList
    TabOrder = 3
    Visible = False
  end
  object btnOK: TButton
    Left = 216
    Top = 172
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 4
  end
  object btnCancel: TButton
    Left = 305
    Top = 172
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
end
