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
  File last update : 2025-12-31T09:32:20.157+11:00
  Signature : c6d4a668a9999fbdb947bb926d6f2962f6364362
  ***************************************************************************
*)

(*
  GitBatchCommit - Batch Git Repository Commit Tool

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.0.0

  Description:
    A Delphi VCL application for committing and pushing changes to multiple
    Git repositories simultaneously with a single commit message.
*)

program GitBatchCommit;

uses
  FastMM5,
  Vcl.Forms,
  MainFrm in 'MainFrm.pas' {MainForm},
  uGitRepoManager in 'uGitRepoManager.pas',
  uCodebergDialog in 'uCodebergDialog.pas' {CodebergDialog},
  uCodebergSettings in 'uCodebergSettings.pas' {CodebergSettingsDialog},
  uGitHubSettings in 'uGitHubSettings.pas' {GitHubSettingsDialog},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle( 'Aqua Light Slate' );
  Application.Title := 'Git Batch Commit';
  Application.CreateForm( TMainForm, MainForm );
  Application.Run;

end.
