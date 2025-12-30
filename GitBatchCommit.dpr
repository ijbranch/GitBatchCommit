(*
  GitBatchCommit - Batch Git Repository Commit Tool

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal and commercial use

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
