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
*)

(*
  uDeleteRepositoryDialog.pas - Delete Repositories Confirmation Dialog

  Copyright (c) 2025 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.6.0

  Part of GitBatchCommit Application

  Description:
    Dialog that names the repositories about to be deleted, asks which of
    the three things to delete - the list entry, the remote repository and
    the local folder - and takes a typed confirmation before allowing the
    two irreversible ones.
*)

unit uDeleteRepositoryDialog;

interface

uses
  Winapi.Windows, Winapi.Messages,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  System.SysUtils, System.Classes, System.UITypes;

type
  /// <summary>
  ///   What the user chose to delete.
  /// </summary>
  /// <remarks>
  ///   The three are independent in intent but not quite in effect:
  ///   <c>DeleteLocal</c> forces <c>RemoveEntry</c>, because an entry whose
  ///   folder has gone can only ever paint as Error and can never be acted on
  ///   again.
  /// </remarks>
  TDeleteRepositoryOptions = record
    /// <summary>True to remove the repository from the managed list.</summary>
    RemoveEntry: Boolean;
    /// <summary>True to delete the repository on its remote host, through the provider's API.</summary>
    DeleteRemote: Boolean;
    /// <summary>True to send the local working-tree folder to the Recycle Bin.</summary>
    DeleteLocal: Boolean;
  end;

  /// <summary>
  ///   Confirmation dialog for the Delete Selected command.
  /// </summary>
  /// <remarks>
  ///   Two of the three options cannot be undone from inside this application,
  ///   so the dialog lists every repository by name, path and resolved remote
  ///   target before asking, and requires the word DELETE to be typed before it
  ///   will enable its own Delete button. Removing list entries alone is
  ///   harmless and needs no typed confirmation.
  /// </remarks>
  TDeleteRepositoryDialog = class( TForm )
    lblIntro: TLabel;
    lstRepos: TListBox;
    gbWhatToDelete: TGroupBox;
    chkRemoveEntry: TCheckBox;
    chkDeleteRemote: TCheckBox;
    chkDeleteLocal: TCheckBox;
    lblWarning: TLabel;
    lblConfirm: TLabel;
    edtConfirm: TEdit;
    btnDelete: TButton;
    btnCancel: TButton;
    /// <summary>
    ///   Re-applies the option coupling and the button state after any option
    ///   changes.
    /// </summary>
    /// <param name="Sender">The check box that changed.</param>
    procedure OptionClick( Sender: TObject );
    /// <summary>
    ///   Re-tests the typed confirmation as it is entered.
    /// </summary>
    /// <param name="Sender">The confirmation edit.</param>
    procedure edtConfirmChange( Sender: TObject );
  private
    const
      /// <summary>
      ///   The word that must be typed before either irreversible option is
      ///   allowed to proceed. Compared case-sensitively.
      /// </summary>
      CONFIRM_WORD = 'DELETE';

    /// <summary>
    ///   Applies the local-delete coupling, the warning text and the enabled
    ///   state of the Delete button to the current option selection.
    /// </summary>
    procedure UpdateState;
  public
    /// <summary>
    ///   Shows the dialog for a set of repositories and returns what to delete.
    /// </summary>
    /// <param name="aRepoLines">
    ///   One display line per repository, already formatted by the caller as
    ///   name, path and remote target. These are what the user is authorising,
    ///   so they must name the remote exactly rather than just its provider.
    /// </param>
    /// <param name="AOptions">Receives the chosen options when the result is True.</param>
    /// <returns>True when the user confirmed the deletion.</returns>
    class function Execute( const aRepoLines: TArray<string>;
      out AOptions: TDeleteRepositoryOptions ): Boolean;
  end;

var
  DeleteRepositoryDialog : TDeleteRepositoryDialog;

implementation

{$R *.dfm}

procedure TDeleteRepositoryDialog.UpdateState;
var
  lDestructive      : Boolean;
begin

  // Deleting the folder makes the entry meaningless - it can only ever paint
  // as Error afterwards - so the entry goes with it and the user is not
  // offered the choice of leaving a dead row behind.
  if chkDeleteLocal.Checked then
  begin
    chkRemoveEntry.Checked := True;
    chkRemoveEntry.Enabled := False;
  end
  else
    chkRemoveEntry.Enabled := True;

  lDestructive      := chkDeleteRemote.Checked or chkDeleteLocal.Checked;

  lblConfirm.Enabled := lDestructive;
  edtConfirm.Enabled := lDestructive;

  if ( not lDestructive ) then
    lblWarning.Caption := 'Nothing on disk or on the remote host will be touched - only the ' +
      'entries are removed from this list. The repositories can be added back at any time.'
  else if chkDeleteRemote.Checked and chkDeleteLocal.Checked then
    lblWarning.Caption := 'The remote repository will be deleted PERMANENTLY, with its issues, ' +
      'releases and history. The local folder goes to the Recycle Bin. After this there is no ' +
      'copy of the repository left anywhere.'
  else if chkDeleteRemote.Checked then
    lblWarning.Caption := 'The remote repository will be deleted PERMANENTLY, with its issues, ' +
      'releases and history. This cannot be undone. The local folder is left alone.'
  else
    lblWarning.Caption := 'The local folder will be sent to the Recycle Bin, so it can be ' +
      'restored from there. The remote repository is left alone.';

  btnDelete.Enabled := ( chkRemoveEntry.Checked or lDestructive ) and
    ( ( not lDestructive ) or SameStr( Trim( edtConfirm.Text ), CONFIRM_WORD ) );

end;

procedure TDeleteRepositoryDialog.OptionClick( Sender: TObject );
begin

  UpdateState;

end;

procedure TDeleteRepositoryDialog.edtConfirmChange( Sender: TObject );
begin

  UpdateState;

end;

class function TDeleteRepositoryDialog.Execute( const aRepoLines: TArray<string>;
  out AOptions: TDeleteRepositoryOptions ): Boolean;
var
  Dlg               : TDeleteRepositoryDialog;
begin

  Result            := False;
  AOptions          := Default( TDeleteRepositoryOptions );

  Dlg               := TDeleteRepositoryDialog.Create( nil );

  try
    Dlg.lblIntro.Caption := Format( 'These %d repository(ies) are about to be deleted:',
      [ Length( aRepoLines ) ] );

    for var sLine in aRepoLines do
      Dlg.lstRepos.Items.Add( sLine );

    // Entry removal alone is the harmless default; both irreversible options
    // start unticked so that neither can be taken by pressing Enter.
    Dlg.chkRemoveEntry.Checked := True;
    Dlg.UpdateState;

    if Dlg.ShowModal = mrOk then
    begin
      AOptions.RemoveEntry  := Dlg.chkRemoveEntry.Checked;
      AOptions.DeleteRemote := Dlg.chkDeleteRemote.Checked;
      AOptions.DeleteLocal  := Dlg.chkDeleteLocal.Checked;
      Result                := True;
    end;
  finally
    Dlg.Free;
  end;

end;

end.
