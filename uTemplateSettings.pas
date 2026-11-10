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
  File last update : 2026-01-04T05:22:04.297+11:00
  Signature : 00e2a5ab8555b189b195aa3a8d764b170e81efe1
  ***************************************************************************
*)

(*
  uTemplateSettings.pas - Commit Message Template Settings Dialog

  Copyright (c) 2026 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.8.0

  Part of GitBatchCommit Application

  Description:
    Dialog form for managing commit message templates.
    Allows adding, editing, and deleting predefined commit messages.
*)

unit uTemplateSettings;

interface

uses
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Buttons,
  System.Classes;

type
  /// <summary>
  ///   Dialog form for managing commit message templates.
  /// </summary>
  TTemplateSettingsForm = class( TForm )
    /// <summary>
    ///   The "Templates" label.
    /// </summary>
    lblTemplates: TLabel;
    /// <summary>
    ///   The templates as edited so far.
    /// </summary>
    lstTemplates: TListBox;
    /// <summary>
    ///   The "Add" button.
    /// </summary>
    btnAdd: TBitBtn;
    /// <summary>
    ///   The "Edit" button.
    /// </summary>
    btnEdit: TBitBtn;
    /// <summary>
    ///   The "Delete" button.
    /// </summary>
    btnDelete: TBitBtn;
    /// <summary>
    ///   The "OK" button.
    /// </summary>
    btnOK: TBitBtn;
    /// <summary>
    ///   The "Cancel" button.
    /// </summary>
    btnCancel: TBitBtn;
    /// <summary>
    ///   Prompts for a new template and appends it to the list.
    /// </summary>
    /// <param name="Sender">The Add button.</param>
    procedure btnAddClick( Sender: TObject );
    /// <summary>
    ///   Prompts for replacement text for the selected template.
    /// </summary>
    /// <param name="Sender">The Edit button.</param>
    procedure btnEditClick( Sender: TObject );
    /// <summary>
    ///   Removes the selected template after confirmation.
    /// </summary>
    /// <param name="Sender">The Delete button.</param>
    procedure btnDeleteClick( Sender: TObject );
    /// <summary>
    ///   Updates the Edit and Delete button states for the new selection.
    /// </summary>
    /// <param name="Sender">The template list.</param>
    procedure lstTemplatesClick( Sender: TObject );
  private
    /// <summary>
    ///   The templates as edited so far; returned to the caller on OK.
    /// </summary>
    FTemplates: TArray<string>;

    /// <summary>
    ///   Enables Edit and Delete only while a template is selected.
    /// </summary>
    procedure UpdateButtonStates;

    /// <summary>
    ///   Refills the list box from the current template array.
    /// </summary>
    procedure PopulateList;

    /// <summary>
    ///   Asks for template text until it is acceptable or the user cancels.
    /// </summary>
    /// <remarks>
    ///   A blank entry used to close the prompt and do nothing, with no word
    ///   of why, and a duplicate was added as a second identical menu item.
    ///   Both are now explained, and the prompt comes back with the text still
    ///   in it.
    /// </remarks>
    /// <param name="sCaption">Caption of the prompt.</param>
    /// <param name="sTemplate">Initial text, and the accepted text on return.</param>
    /// <param name="iOwnIndex">
    ///   Index of the template being edited, which may keep its own text; -1
    ///   when adding.
    /// </param>
    /// <returns>True when acceptable text was entered; False when cancelled.</returns>
    function PromptForTemplate( const sCaption: string; var sTemplate: string; const iOwnIndex: Integer ): Boolean;
  public
    /// <summary>
    ///   Shows the dialog and returns the modified templates.
    /// </summary>
    /// <param name="Templates">Pre-filled and returned template array.</param>
    /// <returns>True if user clicked OK, False if cancelled.</returns>
    class function Execute( var Templates: TArray<string> ): Boolean;
  end;

var
  /// <summary>
  ///   Unused design-time instance variable; the dialog is created by
  ///   <see cref="TTemplateSettingsForm.Execute"/>.
  /// </summary>
  TemplateSettingsForm: TTemplateSettingsForm;

implementation

uses
  Vcl.Dialogs, Vcl.StyledTaskDialog,
  System.SysUtils, System.UITypes;

{$R *.dfm}

class function TTemplateSettingsForm.Execute( var Templates: TArray<string> ): Boolean;
begin

  Result            := False;

  var oDialog       := TTemplateSettingsForm.Create( nil );

  try
    oDialog.FTemplates := Copy( Templates );
    oDialog.PopulateList;
    oDialog.UpdateButtonStates;

    if oDialog.ShowModal = mrOk then
    begin
      Templates     := Copy( oDialog.FTemplates );
      Result        := True;
    end;
  finally
    oDialog.Free;
  end;

end;

procedure TTemplateSettingsForm.PopulateList;
begin

  lstTemplates.Items.BeginUpdate;

  try
    lstTemplates.Items.Clear;

    for var sTemplate in FTemplates do
      lstTemplates.Items.Add( sTemplate );
  finally
    lstTemplates.Items.EndUpdate;
  end;

end;

procedure TTemplateSettingsForm.UpdateButtonStates;
begin

  btnEdit.Enabled   := ( lstTemplates.ItemIndex >= 0 );
  btnDelete.Enabled := ( lstTemplates.ItemIndex >= 0 );

end;

procedure TTemplateSettingsForm.lstTemplatesClick( Sender: TObject );
begin

  UpdateButtonStates;

end;

function TTemplateSettingsForm.PromptForTemplate( const sCaption: string; var sTemplate: string;
  const iOwnIndex: Integer ): Boolean;
begin

  Result            := False;

  var sText         := sTemplate;

  while InputQuery( sCaption, 'Enter commit message template:', sText ) do
  begin
    sText           := Trim( sText );

    if sText.IsEmpty then
    begin
      StyledMessageDlg( 'A template cannot be blank.', mtWarning, [ mbOK ], 0 );
      Continue;
    end;

    var bDuplicate  := False;

    for var iI := 0 to High( FTemplates ) do
    begin
      if ( iI <> iOwnIndex ) and SameText( FTemplates[ iI ], sText ) then
        bDuplicate  := True;
    end;

    if bDuplicate then
    begin
      StyledMessageDlg( 'That template is already in the list.', mtWarning, [ mbOK ], 0 );
      Continue;
    end;

    sTemplate       := sText;
    Exit( True );
  end;

end;

procedure TTemplateSettingsForm.btnAddClick( Sender: TObject );
begin

  var sTemplate     := '';

  if ( not PromptForTemplate( 'Add Template', sTemplate, -1 ) ) then
    Exit;

  FTemplates        := FTemplates + [ sTemplate ];
  PopulateList;
  lstTemplates.ItemIndex := High( FTemplates );
  UpdateButtonStates;

end;

procedure TTemplateSettingsForm.btnEditClick( Sender: TObject );
begin

  var iIndex        := lstTemplates.ItemIndex;

  if ( iIndex < 0 ) or ( iIndex > High( FTemplates ) ) then
    Exit;

  var sTemplate     := FTemplates[ iIndex ];

  if ( not PromptForTemplate( 'Edit Template', sTemplate, iIndex ) ) then
    Exit;

  FTemplates[ iIndex ] := sTemplate;
  PopulateList;
  lstTemplates.ItemIndex := iIndex;
  UpdateButtonStates;

end;

procedure TTemplateSettingsForm.btnDeleteClick( Sender: TObject );
begin

  var iIndex        := lstTemplates.ItemIndex;

  if ( iIndex < 0 ) or ( iIndex > High( FTemplates ) ) then
    Exit;

  if StyledMessageDlg( Format( 'Delete template "%s"?', [ FTemplates[ iIndex ] ] ), mtConfirmation, [ mbYes, mbNo ],
    0 ) <> mrYes then
    Exit;

  Delete( FTemplates, iIndex, 1 );
  PopulateList;

  if lstTemplates.Items.Count > 0 then
    lstTemplates.ItemIndex := if iIndex >= lstTemplates.Items.Count then lstTemplates.Items.Count - 1 else iIndex;

  UpdateButtonStates;

end;

end.
