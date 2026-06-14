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
  File last update : 2026-01-04T05:22:04.276+11:00
  Signature : 088c1f35a610ad1c2e5dbdab33651bf2995e2d17
  ***************************************************************************
*)

(*
  uCodebergDialog.pas - Codeberg Repository Creation Dialog

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

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
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  System.SysUtils, System.Variants, System.Classes, System.UITypes;

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
    lblProjectType: TLabel;
    cboProjectType: TComboBox;
    btnOK: TButton;
    btnCancel: TButton;
  private
  public
    /// <summary>
    ///   Shows the dialog and returns the entered values.
    /// </summary>
    /// <param name="sRepoName">Pre-filled and returned repository name.</param>
    /// <param name="sDescription">Returned repository description.</param>
    /// <param name="lPrivate">Returned private flag.</param>
    /// <returns>True if user clicked OK, False if cancelled.</returns>
    class function Execute( var sRepoName, sDescription: string; var lPrivate: Boolean ): Boolean; overload;

    /// <summary>
    ///   Shows the dialog with project type selection and returns the entered values.
    /// </summary>
    class function Execute( var sRepoName, sDescription: string; var lPrivate: Boolean;
      var sProjectType: string ): Boolean; overload;
  end;

var
  CodebergDialog    : TCodebergDialog;

implementation

{$R *.dfm}

class function TCodebergDialog.Execute( var sRepoName, sDescription: string; var lPrivate: Boolean ): Boolean;
var
  Dlg               : TCodebergDialog;
begin

  Result := False;
  Dlg := TCodebergDialog.Create( nil );

  try
    Dlg.edtRepoName.Text := sRepoName;
    Dlg.edtDescription.Text := sDescription;
    Dlg.chkPrivate.Checked := lPrivate;

    // Shrink form — project type hidden by default in DFM. Move buttons up to fill the gap.
    // Position relative to the (already DPI-scaled) checkbox and use ScaleValue for the gaps,
    // so the layout stays correct on high-DPI displays instead of overlapping the checkbox.
    Dlg.btnOK.Top := Dlg.chkPrivate.Top + Dlg.chkPrivate.Height + Dlg.ScaleValue( 16 );
    Dlg.btnCancel.Top := Dlg.btnOK.Top;
    Dlg.ClientHeight := Dlg.btnOK.Top + Dlg.btnOK.Height + Dlg.ScaleValue( 15 );

    if Dlg.ShowModal = mrOK then
    begin
      sRepoName := Trim( Dlg.edtRepoName.Text );
      sDescription := Trim( Dlg.edtDescription.Text );
      lPrivate := Dlg.chkPrivate.Checked;

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

class function TCodebergDialog.Execute( var sRepoName, sDescription: string; var lPrivate: Boolean;
  var sProjectType: string ): Boolean;
var
  Dlg               : TCodebergDialog;
begin

  Result := False;
  Dlg := TCodebergDialog.Create( nil );

  try
    Dlg.edtRepoName.Text := sRepoName;
    Dlg.edtDescription.Text := sDescription;
    Dlg.chkPrivate.Checked := lPrivate;

    // Populate project types
    Dlg.cboProjectType.Items.Add( '(None)' );
    Dlg.cboProjectType.Items.Add( 'Delphi / Pascal' );
    Dlg.cboProjectType.Items.Add( 'C / C++' );
    Dlg.cboProjectType.Items.Add( 'C#' );
    Dlg.cboProjectType.Items.Add( 'Java' );
    Dlg.cboProjectType.Items.Add( 'Python' );
    Dlg.cboProjectType.Items.Add( 'JavaScript / Node' );
    Dlg.cboProjectType.Items.Add( 'TypeScript' );
    Dlg.cboProjectType.Items.Add( 'Go' );
    Dlg.cboProjectType.Items.Add( 'Rust' );
    Dlg.cboProjectType.Items.Add( 'HTML / Web' );

    // Default to Delphi
    if sProjectType.IsEmpty then
      Dlg.cboProjectType.ItemIndex := 1
    else
      Dlg.cboProjectType.ItemIndex := Dlg.cboProjectType.Items.IndexOf( sProjectType );

    if Dlg.cboProjectType.ItemIndex < 0 then
      Dlg.cboProjectType.ItemIndex := 0;

    // Show/hide project type based on whether caller provided the param
    Dlg.lblProjectType.Visible := True;
    Dlg.cboProjectType.Visible := True;

    if Dlg.ShowModal = mrOK then
    begin
      sRepoName := Trim( Dlg.edtRepoName.Text );
      sDescription := Trim( Dlg.edtDescription.Text );
      lPrivate := Dlg.chkPrivate.Checked;
      sProjectType := Dlg.cboProjectType.Text;

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

