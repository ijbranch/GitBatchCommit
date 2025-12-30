object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Git Batch Commit'
  ClientHeight = 600
  ClientWidth = 946
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object splitter: TSplitter
    Left = 0
    Top = 400
    Width = 946
    Height = 5
    Cursor = crVSplit
    Align = alBottom
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 946
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnSelectModified: TButton
      Left = 8
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Select Modified'
      TabOrder = 0
      OnClick = btnSelectModifiedClick
    end
    object btnSelectAll: TButton
      Left = 114
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Select All'
      TabOrder = 1
      OnClick = btnSelectAllClick
    end
    object btnSelectNone: TButton
      Left = 195
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Select None'
      TabOrder = 2
      OnClick = btnSelectNoneClick
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 555
    Width = 946
    Height = 45
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object lblCommitMessage: TLabel
      Left = 8
      Top = 14
      Width = 96
      Height = 15
      Caption = 'Commit Message:'
    end
    object edtCommitMessage: TEdit
      Left = 112
      Top = 11
      Width = 600
      Height = 23
      TabOrder = 1
    end
    object btnCommitPush: TButton
      Left = 720
      Top = 10
      Width = 170
      Height = 25
      Caption = 'Commit && Push Selected'
      TabOrder = 0
      OnClick = btnCommitPushClick
    end
  end
  object pnlClient: TPanel
    Left = 0
    Top = 41
    Width = 946
    Height = 359
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lvRepos: TListView
      Left = 0
      Top = 0
      Width = 946
      Height = 359
      Hint = 
        'Ready. Drag and drop repository folders to add them. Click colum' +
        'n headers to sort. Use View > Filter to filter by status.'
      Align = alClient
      Checkboxes = True
      Columns = <
        item
          Caption = 'Name'
          Width = 180
        end
        item
          Caption = 'Path'
          Width = 400
        end
        item
          Alignment = taCenter
          Caption = 'Branch'
          Width = 100
        end
        item
          Alignment = taCenter
          Caption = 'Remote'
          Width = 70
        end
        item
          Alignment = taCenter
          Caption = 'Tracked Files'
          Width = 80
        end
        item
          Alignment = taCenter
          Caption = 'Modified'
          Width = 60
        end
        item
          Alignment = taCenter
          Caption = 'Status'
          Width = 100
        end>
      ReadOnly = True
      RowSelect = True
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      ViewStyle = vsReport
      OnItemChecked = lvReposItemChecked
      PopupMenu = pmRepos
    end
  end
  object mmoLog: TMemo
    Left = 0
    Top = 405
    Width = 946
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
    TabOrder = 2
  end
  object MainMenu: TMainMenu
    Left = 400
    Top = 200
    object mnuFile: TMenuItem
      Caption = '&File'
      object mnuAddRepository: TMenuItem
        Caption = '&Add Repository...'
        OnClick = mnuAddRepositoryClick
      end
      object mnuRemoveSelected: TMenuItem
        Caption = '&Remove Selected'
        OnClick = mnuRemoveSelectedClick
      end
      object mnuFileSep1: TMenuItem
        Caption = '-'
      end
      object mnuRefreshStatus: TMenuItem
        Caption = 'Re&fresh Status'
        ShortCut = 116
        OnClick = mnuRefreshStatusClick
      end
      object mnuFileSep2: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        Caption = 'E&xit'
        OnClick = mnuExitClick
      end
    end
    object mnuCodeberg: TMenuItem
      Caption = '&Codeberg'
      object mnuInitPushCodeberg: TMenuItem
        Caption = '&Initialize && Push to Codeberg...'
        OnClick = mnuInitPushCodebergClick
      end
      object mnuCodebergSep1: TMenuItem
        Caption = '-'
      end
      object mnuCodebergSettings: TMenuItem
        Caption = '&Settings...'
        OnClick = mnuCodebergSettingsClick
      end
    end
    object mnuGitHub: TMenuItem
      Caption = '&GitHub'
      object mnuInitPushGitHub: TMenuItem
        Caption = '&Initialize && Push to GitHub...'
        OnClick = mnuInitPushGitHubClick
      end
      object mnuGitHubSep1: TMenuItem
        Caption = '-'
      end
      object mnuGitHubSettings: TMenuItem
        Caption = '&Settings...'
        OnClick = mnuGitHubSettingsClick
      end
    end
    object mnuView: TMenuItem
      Caption = '&View'
      object mnuFilter: TMenuItem
        Caption = '&Filter'
        object mnuFilterAll: TMenuItem
          Caption = '&All'
          RadioItem = True
          OnClick = mnuFilterClick
        end
        object mnuFilterClean: TMenuItem
          Caption = '&Clean'
          RadioItem = True
          OnClick = mnuFilterClick
        end
        object mnuFilterModified: TMenuItem
          Caption = '&Modified'
          RadioItem = True
          OnClick = mnuFilterClick
        end
        object mnuFilterPullRequired: TMenuItem
          Caption = '&Pull Required'
          RadioItem = True
          OnClick = mnuFilterClick
        end
        object mnuFilterError: TMenuItem
          Caption = '&Error'
          RadioItem = True
          OnClick = mnuFilterClick
        end
      end
    end
  end
  object pmRepos: TPopupMenu
    Left = 450
    Top = 200
    OnPopup = pmReposPopup
    object pmSetPublic: TMenuItem
      Caption = 'Set &Public'
      OnClick = pmSetPublicClick
    end
    object pmSetPrivate: TMenuItem
      Caption = 'Set Pri&vate'
      OnClick = pmSetPrivateClick
    end
    object pmSep1: TMenuItem
      Caption = '-'
    end
    object pmEditGitignore: TMenuItem
      Caption = 'Edit .&gitignore...'
      OnClick = pmEditGitignoreClick
    end
  end
end
