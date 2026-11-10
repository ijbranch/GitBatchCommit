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
  File last update : 2026-01-04T05:22:04.276+11:00
  Signature : 088c1f35a610ad1c2e5dbdab33651bf2995e2d17
  ***************************************************************************
*)

(*
  uNewRepositoryDialog.pas - New Repository Creation Dialog

  Copyright (c) 2026 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.8.0

  Part of GitBatchCommit Application

  Description:
    Dialog form for entering repository details when creating a new
    GitHub repository.
*)

unit uNewRepositoryDialog;

interface

uses
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Buttons,
  System.Classes;

type
  /// <summary>
  ///   Dialog form for entering the details of a new GitHub repository.
  /// </summary>
  /// <remarks>
  ///   Shared by Initialise &amp; Push, by a folder dropped on the main window
  ///   and by migration.  The name is validated against GitHub's own rule
  ///   before the dialog will close, so a rejected name is corrected here and
  ///   never reaches the point where a repository has been half created.
  /// </remarks>
  TNewRepositoryForm = class( TForm )
    /// <summary>
    ///   The "Repository Name" label.
    /// </summary>
    lblRepoName: TLabel;
    /// <summary>
    ///   The "Description" label.
    /// </summary>
    lblDescription: TLabel;
    /// <summary>
    ///   Name of the repository to create.
    /// </summary>
    edtRepoName: TEdit;
    /// <summary>
    ///   Optional description of the repository.
    /// </summary>
    edtDescription: TEdit;
    /// <summary>
    ///   The "Private Repository" check box.
    /// </summary>
    chkPrivate: TCheckBox;
    /// <summary>
    ///   The "Project Type" label.
    /// </summary>
    lblProjectType: TLabel;
    /// <summary>
    ///   Project type whose .gitignore template is written.
    /// </summary>
    cbProjectType: TComboBox;
    /// <summary>
    ///   The "OK" button.
    /// </summary>
    btnOK: TBitBtn;
    /// <summary>
    ///   The "Cancel" button.
    /// </summary>
    btnCancel: TBitBtn;
    /// <summary>
    ///   Refuses OK while the repository name is blank or not acceptable to
    ///   GitHub.
    /// </summary>
    /// <remarks>
    ///   Validating after ShowModal returned meant a bad name produced a
    ///   warning and then a False result, which every caller reads as
    ///   "cancelled" — so a typo threw away the description and the private
    ///   flag the user had just filled in.
    /// </remarks>
    /// <param name="Sender">The form being closed.</param>
    /// <param name="CanClose">Set False to keep the dialog open.</param>
    procedure FormCloseQuery( Sender: TObject; var CanClose: Boolean );
  public
    const
      /// <summary>
      ///   The project type that writes no .gitignore.
      /// </summary>
      PROJECT_TYPE_NONE = '(None)';

      /// <summary>
      ///   The project type offered by default.
      /// </summary>
      PROJECT_TYPE_DELPHI = 'Delphi / Pascal';

    /// <summary>
    ///   Shows the dialog and returns the entered values.
    /// </summary>
    /// <param name="sRepoName">Pre-filled and returned repository name.</param>
    /// <param name="sDescription">Pre-filled and returned repository description.</param>
    /// <param name="bPrivate">Pre-set and returned private flag.</param>
    /// <param name="sProjectType">
    ///   Pre-selected and returned project type, which decides the .gitignore
    ///   written for a new repository.  Ignored, and returned unchanged, when
    ///   <paramref name="bAskProjectType"/> is False.
    /// </param>
    /// <param name="bAskProjectType">
    ///   True to offer the project type.  Migration passes False: the
    ///   repository already exists and has whatever .gitignore it has.
    /// </param>
    /// <returns>True if the user confirmed the dialog with a valid name.</returns>
    class function Execute( var sRepoName, sDescription: string; var bPrivate: Boolean; var sProjectType: string;
      const bAskProjectType: Boolean ): Boolean;
  end;

var
  /// <summary>
  ///   Unused design-time instance variable; the dialog is created by
  ///   <see cref="TNewRepositoryForm.Execute"/>.
  /// </summary>
  NewRepositoryForm : TNewRepositoryForm;

implementation

uses
  Vcl.Dialogs, Vcl.StyledTaskDialog,
  System.SysUtils, System.UITypes,
  uGitRepoManager;

{$R *.dfm}

procedure TNewRepositoryForm.FormCloseQuery( Sender: TObject; var CanClose: Boolean );
begin

  CanClose          := True;

  if ModalResult <> mrOk then
    Exit;

  var sName         := Trim( edtRepoName.Text );

  if IsValidRepoName( sName ) then
    Exit;

  if sName.IsEmpty then
    StyledMessageDlg( 'Repository name is required.', mtWarning, [ mbOK ], 0 )
  else
    StyledMessageDlg( Format( '"%s" is not a valid repository name.' + sLineBreak + sLineBreak +
      'Use letters, digits, "-", "_" and "." only, up to 100 characters.' + sLineBreak + sLineBreak +
      'Suggested: %s', [ sName, SanitiseRepoName( sName ) ] ), mtWarning, [ mbOK ], 0 );

  edtRepoName.SetFocus;
  CanClose          := False;

end;

class function TNewRepositoryForm.Execute( var sRepoName, sDescription: string; var bPrivate: Boolean;
  var sProjectType: string; const bAskProjectType: Boolean ): Boolean;
begin

  Result            := False;

  var oDialog       := TNewRepositoryForm.Create( nil );

  try
    oDialog.edtRepoName.Text := sRepoName;
    oDialog.edtDescription.Text := sDescription;
    oDialog.chkPrivate.Checked := bPrivate;

    if bAskProjectType then
    begin
      oDialog.cbProjectType.Items.AddStrings( [ PROJECT_TYPE_NONE, PROJECT_TYPE_DELPHI, 'C / C++', 'C#', 'Java',
        'Python', 'JavaScript / Node', 'TypeScript', 'Go', 'Rust', 'HTML / Web' ] );
      oDialog.cbProjectType.ItemIndex := oDialog.cbProjectType.Items.IndexOf( sProjectType );

      if oDialog.cbProjectType.ItemIndex < 0 then
        oDialog.cbProjectType.ItemIndex := 0;
    end
    else
    begin
      // No project type: hide the row and close the gap it leaves.  Measured
      // from the controls themselves, so the layout holds at any scaling.
      oDialog.lblProjectType.Visible := False;
      oDialog.cbProjectType.Visible := False;
      oDialog.btnOK.Top := oDialog.chkPrivate.Top + oDialog.chkPrivate.Height + oDialog.ScaleValue( 16 );
      oDialog.btnCancel.Top := oDialog.btnOK.Top;
      oDialog.ClientHeight := oDialog.btnOK.Top + oDialog.btnOK.Height + oDialog.ScaleValue( 15 );
    end;

    if oDialog.ShowModal = mrOk then
    begin
      // The name is guaranteed valid: FormCloseQuery refuses to let the dialog
      // close otherwise.
      sRepoName     := Trim( oDialog.edtRepoName.Text );
      sDescription  := Trim( oDialog.edtDescription.Text );
      bPrivate      := oDialog.chkPrivate.Checked;

      if bAskProjectType then
        sProjectType := oDialog.cbProjectType.Text;

      Result        := True;
    end;
  finally
    oDialog.Free;
  end;

end;

end.
