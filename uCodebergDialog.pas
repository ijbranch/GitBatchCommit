(*
  uCodebergDialog.pas - Codeberg Repository Creation Dialog

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal and commercial use

  Author:  GITLAK Software
  Version: 1.0.0

  Part of GitBatchCommit Application

  Description:
    Dialog form for entering repository details when creating a new
    Codeberg repository.
*)

unit uCodebergDialog;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  /// <summary>
  ///   Dialog form for creating a new Codeberg repository.
  /// </summary>
  TCodebergDialog = class( TForm )
    lblRepoName: TLabel;
    lblDescription: TLabel;
    edtRepoName: TEdit;
    edtDescription: TEdit;
    chkPrivate: TCheckBox;
    btnOK: TButton;
    btnCancel: TButton;
  private
  public
    /// <summary>
    ///   Shows the dialog and returns the entered values.
    /// </summary>
    /// <param name="sRepoName">Pre-filled and returned repository name.</param>
    /// <param name="sDescription">Returned repository description.</param>
    /// <param name="bPrivate">Returned private flag.</param>
    /// <returns>True if user clicked OK, False if cancelled.</returns>
    class function Execute( var sRepoName, sDescription: string; var bPrivate: Boolean ): Boolean;
  end;

var
  CodebergDialog: TCodebergDialog;

implementation

{$R *.dfm}

class function TCodebergDialog.Execute( var sRepoName, sDescription: string; var bPrivate: Boolean ): Boolean;
var
  Dlg: TCodebergDialog;
begin

  Result := False;
  Dlg    := TCodebergDialog.Create( nil );

  try
    Dlg.edtRepoName.Text    := sRepoName;
    Dlg.edtDescription.Text := sDescription;
    Dlg.chkPrivate.Checked  := bPrivate;

    if Dlg.ShowModal = mrOK then
    begin
      sRepoName    := Trim( Dlg.edtRepoName.Text );
      sDescription := Trim( Dlg.edtDescription.Text );
      bPrivate     := Dlg.chkPrivate.Checked;

      if sRepoName.IsEmpty then
      begin
        MessageDlg( 'Repository name is required.', mtWarning, [ mbOK ], 0 );
        Exit;
      end;

      Result := True;
    end;
  finally
    Dlg.Free;
  end;

end;

end.
