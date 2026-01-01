object TemplateSettingsDialog: TTemplateSettingsDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Commit Message Templates'
  ClientHeight = 320
  ClientWidth = 450
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblTemplates: TLabel
    Left = 16
    Top = 16
    Width = 57
    Height = 15
    Caption = 'Templates:'
  end
  object lstTemplates: TListBox
    Left = 16
    Top = 37
    Width = 329
    Height = 233
    ItemHeight = 15
    TabOrder = 0
    OnClick = lstTemplatesClick
  end
  object btnAdd: TButton
    Left = 359
    Top = 37
    Width = 75
    Height = 25
    Caption = 'Add...'
    TabOrder = 1
    OnClick = btnAddClick
  end
  object btnEdit: TButton
    Left = 359
    Top = 68
    Width = 75
    Height = 25
    Caption = 'Edit...'
    Enabled = False
    TabOrder = 2
    OnClick = btnEditClick
  end
  object btnDelete: TButton
    Left = 359
    Top = 99
    Width = 75
    Height = 25
    Caption = 'Delete'
    Enabled = False
    TabOrder = 3
    OnClick = btnDeleteClick
  end
  object btnOK: TButton
    Left = 278
    Top = 284
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 4
  end
  object btnCancel: TButton
    Left = 359
    Top = 284
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
end
