object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Git Batch Commit'
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object splitter: TSplitter
    Left = 0
    Top = 400
    Width = 900
    Height = 5
    Cursor = crVSplit
    Align = alBottom
    ExplicitTop = 350
    ExplicitWidth = 800
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnAddRepo: TButton
      Left = 8
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Add Repository'
      TabOrder = 0
      OnClick = btnAddRepoClick
    end
    object btnRemoveRepo: TButton
      Left = 114
      Top = 8
      Width = 115
      Height = 25
      Caption = 'Remove Selected'
      TabOrder = 1
      OnClick = btnRemoveRepoClick
    end
    object btnRefresh: TButton
      Left = 235
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Refresh Status'
      TabOrder = 2
      OnClick = btnRefreshClick
    end
    object pnlButtons: TPanel
      Left = 360
      Top = 4
      Width = 330
      Height = 33
      BevelOuter = bvNone
      TabOrder = 3
      object btnSelectModified: TButton
        Left = 5
        Top = 4
        Width = 100
        Height = 25
        Caption = 'Select Modified'
        TabOrder = 0
        OnClick = btnSelectModifiedClick
      end
      object btnSelectAll: TButton
        Left = 111
        Top = 4
        Width = 75
        Height = 25
        Caption = 'Select All'
        TabOrder = 1
        OnClick = btnSelectAllClick
      end
      object btnSelectNone: TButton
        Left = 192
        Top = 4
        Width = 75
        Height = 25
        Caption = 'Select None'
        TabOrder = 2
        OnClick = btnSelectNoneClick
      end
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 555
    Width = 900
    Height = 45
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object lblCommitMessage: TLabel
      Left = 8
      Top = 14
      Width = 95
      Height = 15
      Caption = 'Commit Message:'
    end
    object edtCommitMessage: TEdit
      Left = 112
      Top = 11
      Width = 600
      Height = 23
      TabOrder = 0
    end
    object btnCommitPush: TButton
      Left = 720
      Top = 10
      Width = 170
      Height = 25
      Caption = 'Commit && Push Selected'
      TabOrder = 1
      OnClick = btnCommitPushClick
    end
  end
  object pnlClient: TPanel
    Left = 0
    Top = 41
    Width = 900
    Height = 359
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object lvRepos: TListView
      Left = 0
      Top = 0
      Width = 900
      Height = 359
      Align = alClient
      Checkboxes = True
      Columns = <
        item
          Caption = 'Name'
          Width = 180
        end
        item
          Alignment = taCenter
          Caption = 'Path'
          Width = 400
        end
        item
          Alignment = taCenter
          Caption = 'Branch'
          Width = 120
        end
        item
          Alignment = taCenter
          Caption = 'Status'
          Width = 120
        end>
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnItemChecked = lvReposItemChecked
    end
  end
  object mmoLog: TMemo
    Left = 0
    Top = 405
    Width = 900
    Height = 150
    Align = alBottom
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 3
  end
end
