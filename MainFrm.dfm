object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Git Batch Commit'
  ClientHeight = 600
  ClientWidth = 1097
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
  object splitter: TSplitter
    Left = 0
    Top = 325
    Width = 1097
    Height = 5
    Cursor = crVSplit
    Align = alBottom
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1097
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblGroupFilter: TLabel
      Left = 296
      Top = 12
      Width = 36
      Height = 15
      Caption = 'Group:'
    end
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
    object cboGroupFilter: TComboBox
      Left = 336
      Top = 8
      Width = 145
      Height = 23
      Style = csDropDownList
      TabOrder = 3
      OnChange = cboGroupFilterChange
    end
    object btnPullSelected: TButton
      Left = 496
      Top = 8
      Width = 90
      Height = 25
      Caption = 'Pull Selected'
      TabOrder = 4
      OnClick = btnPullSelectedClick
    end
    object btnResolveConflicts: TButton
      Left = 594
      Top = 8
      Width = 110
      Height = 25
      Caption = 'Resolve Conflicts'
      TabOrder = 5
      OnClick = btnResolveConflictsClick
    end
    object btnPushOnly: TButton
      Left = 712
      Top = 8
      Width = 80
      Height = 25
      Caption = 'Push Only'
      TabOrder = 6
      OnClick = btnPushOnlyClick
    end
    object btnForcePush: TButton
      Left = 800
      Top = 8
      Width = 90
      Height = 25
      Caption = 'Force Push'
      TabOrder = 7
      OnClick = btnForcePushClick
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 555
    Width = 1097
    Height = 45
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
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
      Width = 541
      Height = 23
      TabOrder = 4
      OnChange = edtCommitMessageChange
    end
    object btnDetails: TButton
      Left = 659
      Top = 10
      Width = 25
      Height = 25
      Hint = 'Show/hide commit details'
      Caption = '...'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = btnDetailsClick
    end
    object btnHistory: TButton
      Left = 690
      Top = 10
      Width = 25
      Height = 25
      Hint = 'Commit message history'
      Caption = #9660
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnClick = btnHistoryClick
    end
    object btnTemplates: TButton
      Left = 721
      Top = 10
      Width = 25
      Height = 25
      Hint = 'Commit message templates'
      Caption = #9661
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnClick = btnTemplatesClick
    end
    object btnCommitPush: TButton
      Left = 752
      Top = 10
      Width = 170
      Height = 25
      Caption = 'Commit && Push Selected'
      TabOrder = 3
      OnClick = btnCommitPushClick
    end
  end
  object pnlDetails: TPanel
    Left = 0
    Top = 330
    Width = 1097
    Height = 75
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    Visible = False
    object lblDetails: TLabel
      Left = 8
      Top = 4
      Width = 38
      Height = 15
      Caption = 'Details:'
    end
    object mmoDetails: TMemo
      Left = 112
      Top = -1
      Width = 810
      Height = 70
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object pnlClient: TPanel
    Left = 0
    Top = 41
    Width = 1097
    Height = 284
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lvRepos: TListView
      Left = 0
      Top = 0
      Width = 1097
      Height = 284
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
        end
        item
          Alignment = taCenter
          Caption = 'Version'
          Width = 80
        end>
      ReadOnly = True
      RowSelect = True
      ParentShowHint = False
      PopupMenu = pmRepos
      ShowHint = True
      TabOrder = 0
      ViewStyle = vsReport
      OnClick = lvReposClick
      OnCustomDrawItem = lvReposCustomDrawItem
      OnItemChecked = lvReposItemChecked
    end
  end
  object mmoLog: TMemo
    Left = 0
    Top = 405
    Width = 1097
    Height = 150
    Align = alBottom
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 3
    OnKeyDown = mmoLogKeyDown
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
      object mnuSettings: TMenuItem
        Caption = '&Settings...'
        OnClick = mnuSettingsClick
      end
      object mnuTemplateSettings: TMenuItem
        Caption = '&Templates...'
        OnClick = mnuTemplateSettingsClick
      end
      object mnuFileSep3: TMenuItem
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
      object mnuMigrateToCodeberg: TMenuItem
        Caption = '&Migrate Selected Repository to Codeberg...'
        OnClick = mnuMigrateToCodebergClick
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
      object mnuMigrateToGitHub: TMenuItem
        Caption = '&Migrate Selected Repository to GitHub...'
        OnClick = mnuMigrateToGitHubClick
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
    object mnuHelp: TMenuItem
      Caption = '&Help'
      object mnuHelpContents: TMenuItem
        Caption = '&Help Contents'
        ShortCut = 112
        OnClick = mnuHelpContentsClick
      end
      object mnuHelpSep1: TMenuItem
        Caption = '-'
      end
      object mnuAbout: TMenuItem
        Caption = '&About...'
        OnClick = mnuAboutClick
      end
    end
  end
  object pmRepos: TPopupMenu
    OnPopup = pmReposPopup
    Left = 450
    Top = 200
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
    object pmFixGitignore: TMenuItem
      Caption = '&Fix .gitignore (Add Delphi Patterns)'
      OnClick = pmFixGitignoreClick
    end
    object pmSep2: TMenuItem
      Caption = '-'
    end
    object pmOpenInExplorer: TMenuItem
      Caption = 'Open in &Explorer'
      OnClick = pmOpenInExplorerClick
    end
    object pmOpenInGitClient: TMenuItem
      Caption = 'Open in &Git Client'
      OnClick = pmOpenInGitClientClick
    end
    object pmSep3: TMenuItem
      Caption = '-'
    end
    object pmPull: TMenuItem
      Caption = 'Pu&ll'
      OnClick = pmPullClick
    end
    object pmSep4: TMenuItem
      Caption = '-'
    end
    object pmSetGroup: TMenuItem
      Caption = 'Set &Group'
    end
  end
  object pmHistory: TPopupMenu
    Left = 500
    Top = 200
  end
  object pmTemplates: TPopupMenu
    Left = 550
    Top = 200
  end
end
