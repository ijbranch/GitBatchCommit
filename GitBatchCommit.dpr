(* GITLAK Software
  ***************************************************************************

    © 2025 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use. only.

    THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED.
    IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DAMAGES ARISING IN
  CONNECTION WITH THE USE OF THIS SOFTWARE.

  ***************************************************************************

  This code Unit is part of the GitBatchCommit Application/project.
  This project was developed jointly by the Author and Claude Code.

  ***************************************************************************

  Author(s) :
  Ian Branch - GITLAK Software.    Claude Code.

  ***************************************************************************
  File last update : 2026-01-04T05:22:04.262+11:00
  Signature : c6d4a668a9999fbdb947bb926d6f2962f6364362
  ***************************************************************************
*)

(*
  GitBatchCommit - Batch Git Repository Commit Tool

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.5.0

  Description:
    A Delphi VCL application for committing and pushing changes to multiple
    Git repositories simultaneously with a single commit message.
*)

program GitBatchCommit;

uses
  FastMM5,
  {$IFDEF EurekaLog}
  EMemLeaks,
  EResLeaks,
  EFastMM5Support,
  EResourceStrings,
  EMapWin32,
  EAppVCL,
  EDialogWinAPIMSClassic,
  EDialogWinAPIEurekaLogDetailed,
  EDialogWinAPIStepsToReproduce,
  EBase,
  EExtraExceptionInfo,
  ExceptionLog7,
  {$ENDIF EurekaLog}
  ELExtraPlugIns in 'E:\DBiWorkflow Development v 5\DBiCommonFiles\ELExtraPlugIns.pas',
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  MainFrm in 'MainFrm.pas' {MainForm},
  uGitRepoManager in 'uGitRepoManager.pas',
  uCodebergDialog in 'uCodebergDialog.pas' {CodebergDialog},
  uCodebergSettings in 'uCodebergSettings.pas' {CodebergSettingsDialog},
  uGitHubSettings in 'uGitHubSettings.pas' {GitHubSettingsDialog},
  uTemplateSettings in 'uTemplateSettings.pas' {TemplateSettingsDialog};

{$R *.res}

begin

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle( 'Aqua Light Slate' );
  Application.Title := 'Git Batch Processor';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;

end.


