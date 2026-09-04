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
  File last update : 2026-01-04T05:22:04.284+11:00
  Signature : d86d22ed25221a39c076106f20c031fe3c33d65f
  ***************************************************************************
*)

(*
  uGitHubSettings.pas - GitHub Credentials Settings Dialog

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.6.0

  Part of GitBatchCommit Application

  Description:
    Dialog form for configuring GitHub username and access token.
*)

unit uGitHubSettings;

interface

uses
  Winapi.Windows, Winapi.Messages,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  System.SysUtils, System.Variants, System.Classes;

type
  /// <summary>
  ///   Dialog form for configuring GitHub credentials.
  /// </summary>
  TGitHubSettingsDialog = class( TForm )
    lblUsername: TLabel;
    lblToken: TLabel;
    lblHelp: TLabel;
    edtUsername: TEdit;
    edtToken: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
  private
  public
    /// <summary>
    ///   Shows the dialog and returns the entered credentials.
    /// </summary>
    /// <param name="sUsername">Pre-filled and returned username.</param>
    /// <param name="sToken">Pre-filled and returned access token.</param>
    /// <returns>True if user clicked OK, False if cancelled.</returns>
    class function Execute( var sUsername, sToken: string ): Boolean;
  end;

var
  GitHubSettingsDialog: TGitHubSettingsDialog;

implementation

{$R *.dfm}

class function TGitHubSettingsDialog.Execute( var sUsername, sToken: string ): Boolean;
var
  Dlg               : TGitHubSettingsDialog;
begin

  Result := False;
  Dlg := TGitHubSettingsDialog.Create( nil );

  try
    Dlg.edtUsername.Text := sUsername;
    Dlg.edtToken.Text := sToken;

    if Dlg.ShowModal = mrOK then
    begin
      sUsername := Trim( Dlg.edtUsername.Text );
      sToken := Trim( Dlg.edtToken.Text );
      Result := True;
    end;
  finally
    Dlg.Free;
  end;

end;

end.

