(* GITLAK Software
  ***************************************************************************

    © 2025 Ian Branch (GITLAK Software). All rights reserved.

    This Project, including all code, proprietary algorithms, and associated
  intellectual property and confidential information, is the exclusive
  property of Ian Branch (GITLAK Software).

    A licence is granted for the sole purpose of personal use only.

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

  Copyright (c) 2026 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.8.0

  Part of GitBatchCommit Application

  Description:
    Dialog form for configuring GitHub username and access token.
*)

unit uGitHubSettings;

interface

uses
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Buttons,
  System.Classes;

type
  /// <summary>
  ///   Dialog form for configuring GitHub credentials.
  /// </summary>
  TGitHubSettingsForm = class( TForm )
    /// <summary>
    ///   The "Username" label.
    /// </summary>
    lblUsername: TLabel;
    /// <summary>
    ///   The "Access Token" label.
    /// </summary>
    lblToken: TLabel;
    /// <summary>
    ///   The "Generate token at: github.com/settings/tokens" label.
    /// </summary>
    lblHelp: TLabel;
    /// <summary>
    ///   GitHub user name.
    /// </summary>
    edtUsername: TEdit;
    /// <summary>
    ///   GitHub personal access token; masked.
    /// </summary>
    edtToken: TEdit;
    /// <summary>
    ///   The "OK" button.
    /// </summary>
    btnOK: TBitBtn;
    /// <summary>
    ///   The "Cancel" button.
    /// </summary>
    btnCancel: TBitBtn;
    /// <summary>
    ///   Refuses OK when only one of the user name and the token is filled in.
    /// </summary>
    /// <remarks>
    ///   Half a credential was accepted and saved, and then every GitHub
    ///   command reported "credentials not configured" with nothing to say
    ///   which half was missing.  Both blank is allowed: it clears them.
    /// </remarks>
    /// <param name="Sender">The form being closed.</param>
    /// <param name="CanClose">Set False to keep the dialog open.</param>
    procedure FormCloseQuery( Sender: TObject; var CanClose: Boolean );
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
  /// <summary>
  ///   Unused design-time instance variable; the dialog is created by
  ///   <see cref="TGitHubSettingsForm.Execute"/>.
  /// </summary>
  GitHubSettingsForm: TGitHubSettingsForm;

implementation

uses
  Vcl.Dialogs, Vcl.StyledTaskDialog,
  System.SysUtils, System.UITypes;

{$R *.dfm}

procedure TGitHubSettingsForm.FormCloseQuery( Sender: TObject; var CanClose: Boolean );
begin

  CanClose          := True;

  if ModalResult <> mrOk then
    Exit;

  var bHasUser      := not Trim( edtUsername.Text ).IsEmpty;
  var bHasToken     := not Trim( edtToken.Text ).IsEmpty;

  if bHasUser = bHasToken then
    Exit;

  CanClose          := False;

  if bHasUser then
  begin
    StyledMessageDlg( 'Enter the access token as well, or clear the user name to remove the credentials.',
      mtWarning, [ mbOK ], 0 );
    edtToken.SetFocus;
  end
  else
  begin
    StyledMessageDlg( 'Enter the user name as well, or clear the access token to remove the credentials.',
      mtWarning, [ mbOK ], 0 );
    edtUsername.SetFocus;
  end;

end;

class function TGitHubSettingsForm.Execute( var sUsername, sToken: string ): Boolean;
begin

  Result            := False;

  var oDialog       := TGitHubSettingsForm.Create( nil );

  try
    oDialog.edtUsername.Text := sUsername;
    oDialog.edtToken.Text := sToken;

    if oDialog.ShowModal = mrOk then
    begin
      sUsername     := Trim( oDialog.edtUsername.Text );
      sToken        := Trim( oDialog.edtToken.Text );
      Result        := True;
    end;
  finally
    oDialog.Free;
  end;

end;

end.
