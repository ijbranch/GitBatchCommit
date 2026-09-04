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
  Version: 1.6.0

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
  Vcl.StyledTaskDialog,
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
    /// <param name="sHostName">
    ///   Name of the host the repository will be created on, used for the
    ///   dialog caption. This dialog is shared by the Codeberg and GitHub
    ///   flows and by migration in both directions, and its DFM caption said
    ///   "Create Codeberg Repository" in every one of them — so creating a
    ///   GitHub repository announced itself as a Codeberg one.
    /// </param>
    /// <returns>True if the user confirmed the dialog.</returns>
    class function Execute( var sRepoName, sDescription: string; var lPrivate: Boolean;
      const sHostName: string ): Boolean; overload;

    /// <summary>
    ///   Shows the dialog with project type selection and returns the entered values.
    /// </summary>
    /// <param name="sRepoName">Pre-filled and returned repository name.</param>
    /// <param name="sDescription">Returned repository description.</param>
    /// <param name="lPrivate">Returned private flag.</param>
    /// <param name="sProjectType">Pre-selected and returned project type.</param>
    /// <param name="sHostName">Name of the host, used for the dialog caption.</param>
    /// <returns>True if the user confirmed the dialog.</returns>
    class function Execute( var sRepoName, sDescription: string; var lPrivate: Boolean;
      var sProjectType: string; const sHostName: string ): Boolean; overload;
  private
    /// <summary>
    ///   Blocks OK while the repository name is blank.
    /// </summary>
    /// <remarks>
    ///   Validating after ShowModal returned meant a blank name produced a
    ///   warning and then a False result, which every caller reads as
    ///   "cancelled" — so a typo silently threw away the description and the
    ///   private flag the user had just filled in, and dropped them out of the
    ///   whole flow.
    /// </remarks>
    /// <param name="Sender">The form being closed.</param>
    /// <param name="CanClose">Set False to keep the dialog open.</param>
    procedure DialogCloseQuery( Sender: TObject; var CanClose: Boolean );
  end;

var
  CodebergDialog    : TCodebergDialog;

implementation

{$R *.dfm}

procedure TCodebergDialog.DialogCloseQuery( Sender: TObject; var CanClose: Boolean );
begin

  CanClose := True;

  if ModalResult <> mrOK then
    Exit;

  if Trim( edtRepoName.Text ).IsEmpty then
  begin
    StyledMessageDlg( 'Repository name is required.', mtWarning, [ mbOK ], 0 );
    edtRepoName.SetFocus;
    CanClose := False;
  end;

end;

class function TCodebergDialog.Execute( var sRepoName, sDescription: string; var lPrivate: Boolean;
  const sHostName: string ): Boolean;
var
  Dlg               : TCodebergDialog;
begin

  Result := False;
  Dlg := TCodebergDialog.Create( nil );

  try
    Dlg.Caption := Format( 'Create %s Repository', [ sHostName ] );
    Dlg.OnCloseQuery := Dlg.DialogCloseQuery;
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
      // The name is guaranteed non-blank: OnCloseQuery refuses to let the
      // dialog close otherwise.
      sRepoName := Trim( Dlg.edtRepoName.Text );
      sDescription := Trim( Dlg.edtDescription.Text );
      lPrivate := Dlg.chkPrivate.Checked;
      Result := True;
    end;
  finally
    Dlg.Free;
  end;

end;

class function TCodebergDialog.Execute( var sRepoName, sDescription: string; var lPrivate: Boolean;
  var sProjectType: string; const sHostName: string ): Boolean;
var
  Dlg               : TCodebergDialog;
begin

  Result := False;
  Dlg := TCodebergDialog.Create( nil );

  try
    Dlg.Caption := Format( 'Create %s Repository', [ sHostName ] );
    Dlg.OnCloseQuery := Dlg.DialogCloseQuery;
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
      Result := True;
    end;
  finally
    Dlg.Free;
  end;

end;

end.

