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
  File last update : 2026-01-04T05:22:04.297+11:00
  Signature : 00e2a5ab8555b189b195aa3a8d764b170e81efe1
  ***************************************************************************
*)

(*  GITLAK Software
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
*)

(*
  uTemplateSettings.pas - Commit Message Template Settings Dialog

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.3.0

  Part of GitBatchCommit Application

  Description:
    Dialog form for managing commit message templates.
    Allows adding, editing, and deleting predefined commit messages.
*)

unit uTemplateSettings;

interface

uses
  Winapi.Windows, Winapi.Messages,

  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,

  System.SysUtils, System.Variants, System.Classes, System.UITypes;

type
  /// <summary>
  ///   Dialog form for managing commit message templates.
  /// </summary>
  TTemplateSettingsDialog = class( TForm )
    lblTemplates: TLabel;
    lstTemplates: TListBox;
    btnAdd: TButton;
    btnEdit: TButton;
    btnDelete: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    /// <summary>
    ///   Initialises the dialog and prepares the template list.
    /// </summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>
    ///   Prompts for a new template and appends it to the list.
    /// </summary>
    procedure btnAddClick( Sender: TObject );
    /// <summary>
    ///   Prompts for replacement text for the selected template.
    /// </summary>
    procedure btnEditClick( Sender: TObject );
    /// <summary>
    ///   Removes the selected template after confirmation.
    /// </summary>
    procedure btnDeleteClick( Sender: TObject );
    /// <summary>
    ///   Updates the Edit and Delete button states for the new selection.
    /// </summary>
    procedure lstTemplatesClick( Sender: TObject );
  private
    FTemplates        : TArray<string>;

    /// <summary>
    ///   Enables Edit and Delete only while a template is selected.
    /// </summary>
    procedure UpdateButtonStates;
    /// <summary>
    ///   Refills the list box from the current template array.
    /// </summary>
    procedure PopulateList;
  public
    /// <summary>
    ///   Shows the dialog and returns the modified templates.
    /// </summary>
    /// <param name="Templates">Pre-filled and returned template array.</param>
    /// <returns>True if user clicked OK, False if cancelled.</returns>
    class function Execute( var Templates: TArray<string> ): Boolean;
  end;

var
  TemplateSettingsDialog: TTemplateSettingsDialog;

implementation

{$R *.dfm}

class function TTemplateSettingsDialog.Execute( var Templates: TArray<string> ): Boolean;
var
  Dlg               : TTemplateSettingsDialog;
begin

  Result := False;
  Dlg := TTemplateSettingsDialog.Create( nil );

  try
    Dlg.FTemplates := Copy( Templates );
    Dlg.PopulateList;
    Dlg.UpdateButtonStates;

    if Dlg.ShowModal = mrOK then
    begin
      Templates := Copy( Dlg.FTemplates );
      Result := True;
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TTemplateSettingsDialog.FormCreate( Sender: TObject );
begin

  SetLength( FTemplates, 0 );

end;

procedure TTemplateSettingsDialog.PopulateList;
begin

  lstTemplates.Items.Clear;

  for var i := 0 to High( FTemplates ) do
    lstTemplates.Items.Add( FTemplates[ i ] );

end;

procedure TTemplateSettingsDialog.UpdateButtonStates;
begin

  btnEdit.Enabled := ( lstTemplates.ItemIndex >= 0 );
  btnDelete.Enabled := ( lstTemplates.ItemIndex >= 0 );

end;

procedure TTemplateSettingsDialog.lstTemplatesClick( Sender: TObject );
begin

  UpdateButtonStates;

end;

procedure TTemplateSettingsDialog.btnAddClick( Sender: TObject );
var
  sTemplate         : string;
  iLen              : Integer;
begin

  sTemplate := '';

  if InputQuery( 'Add Template', 'Enter commit message template:', sTemplate ) then
  begin
    sTemplate := Trim( sTemplate );

    if ( not sTemplate.IsEmpty ) then
    begin
      iLen := Length( FTemplates );
      SetLength( FTemplates, iLen + 1 );
      FTemplates[ iLen ] := sTemplate;
      PopulateList;
      lstTemplates.ItemIndex := iLen;
      UpdateButtonStates;
    end;
  end;

end;

procedure TTemplateSettingsDialog.btnEditClick( Sender: TObject );
var
  iIndex            : Integer;
  sTemplate         : string;
begin

  iIndex := lstTemplates.ItemIndex;

  if iIndex < 0 then
    Exit;

  sTemplate := FTemplates[ iIndex ];

  if InputQuery( 'Edit Template', 'Enter commit message template:', sTemplate ) then
  begin
    sTemplate := Trim( sTemplate );

    if ( not sTemplate.IsEmpty ) then
    begin
      FTemplates[ iIndex ] := sTemplate;
      PopulateList;
      lstTemplates.ItemIndex := iIndex;
      UpdateButtonStates;
    end;
  end;

end;

procedure TTemplateSettingsDialog.btnDeleteClick( Sender: TObject );
var
  iIndex            : Integer;
begin

  iIndex := lstTemplates.ItemIndex;

  if iIndex < 0 then
    Exit;

  if MessageDlg( Format( 'Delete template "%s"?', [ FTemplates[ iIndex ] ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) = mrYes then
  begin
    for var i := iIndex to High( FTemplates ) - 1 do
      FTemplates[ i ] := FTemplates[ i + 1 ];

    SetLength( FTemplates, Length( FTemplates ) - 1 );
    PopulateList;

    if lstTemplates.Items.Count > 0 then
    begin
      if iIndex >= lstTemplates.Items.Count then
        lstTemplates.ItemIndex := lstTemplates.Items.Count - 1
      else
        lstTemplates.ItemIndex := iIndex;
    end;

    UpdateButtonStates;
  end;

end;

end.
