object DeleteRepositoryDialog: TDeleteRepositoryDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Delete Repositories'
  ClientHeight = 437
  ClientWidth = 490
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  TextHeight = 15
  object lblIntro: TLabel
    Left = 16
    Top = 12
    Width = 458
    Height = 30
    AutoSize = False
    Caption = 'These repositories are about to be deleted:'
    WordWrap = True
  end
  object lblWarning: TLabel
    Left = 16
    Top = 318
    Width = 458
    Height = 40
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clMaroon
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    WordWrap = True
  end
  object lblConfirm: TLabel
    Left = 16
    Top = 364
    Width = 122
    Height = 15
    Caption = 'Type DELETE to confirm:'
  end
  object lstRepos: TListBox
    Left = 16
    Top = 48
    Width = 458
    Height = 130
    ItemHeight = 15
    TabOrder = 0
  end
  object gbWhatToDelete: TGroupBox
    Left = 16
    Top = 190
    Width = 458
    Height = 116
    Caption = ' What to delete '
    TabOrder = 1
    object chkRemoveEntry: TCheckBox
      Left = 16
      Top = 26
      Width = 426
      Height = 17
      Caption = 'Remove the &entry from this list (nothing is deleted)'
      TabOrder = 0
      OnClick = OptionClick
    end
    object chkDeleteRemote: TCheckBox
      Left = 16
      Top = 54
      Width = 426
      Height = 17
      Caption = 'Delete the &remote repository on its host (permanent)'
      TabOrder = 1
      OnClick = OptionClick
    end
    object chkDeleteLocal: TCheckBox
      Left = 16
      Top = 82
      Width = 426
      Height = 17
      Caption = 'Delete the &local folder (sent to the Recycle Bin)'
      TabOrder = 2
      OnClick = OptionClick
    end
  end
  object edtConfirm: TEdit
    Left = 150
    Top = 361
    Width = 120
    Height = 23
    TabOrder = 2
    OnChange = edtConfirmChange
  end
  object btnDelete: TButton
    Left = 296
    Top = 396
    Width = 85
    Height = 25
    Caption = 'Delete'
    Enabled = False
    ModalResult = 1
    TabOrder = 3
  end
  object btnCancel: TButton
    Left = 389
    Top = 396
    Width = 85
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 4
  end
end
