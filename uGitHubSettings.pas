(*
  uGitHubSettings.pas - GitHub Credentials Settings Dialog

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal and commercial use

  Author:  GITLAK Software
  Version: 1.0.0

  Part of GitBatchCommit Application

  Description:
    Dialog form for configuring GitHub username and access token.
*)

unit uGitHubSettings;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

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
  Dlg: TGitHubSettingsDialog;
begin

  Result := False;
  Dlg    := TGitHubSettingsDialog.Create( nil );

  try
    Dlg.edtUsername.Text := sUsername;
    Dlg.edtToken.Text    := sToken;

    if Dlg.ShowModal = mrOK then
    begin
      sUsername := Trim( Dlg.edtUsername.Text );
      sToken    := Trim( Dlg.edtToken.Text );
      Result    := True;
    end;
  finally
    Dlg.Free;
  end;

end;

end.
