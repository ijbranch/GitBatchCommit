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
*)

(*
  uDeleteRepositoryDialog.pas - Delete Repositories Confirmation Dialog

  Copyright (c) 2026 GITLAK Software
  All Rights Reserved

  Licence: Provided as-is for personal use only.

  Author:  GITLAK Software
  Version: 1.8.0

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
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Buttons,
  System.Classes;

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
  TDeleteRepositoryForm = class( TForm )
    /// <summary>
    ///   The "These repositories are about to be deleted" label.
    /// </summary>
    lblIntro: TLabel;
    /// <summary>
    ///   The repositories about to be acted on, one line each.
    /// </summary>
    lstRepos: TListBox;
    /// <summary>
    ///   The " What to delete " group box.
    /// </summary>
    gbWhatToDelete: TGroupBox;
    /// <summary>
    ///   The "Remove the entry from this list (nothing is deleted)" check box.
    /// </summary>
    chkRemoveEntry: TCheckBox;
    /// <summary>
    ///   The "Delete the remote repository on its host (permanent)" check box.
    /// </summary>
    chkDeleteRemote: TCheckBox;
    /// <summary>
    ///   The "Delete the local folder (sent to the Recycle Bin)" check box.
    /// </summary>
    chkDeleteLocal: TCheckBox;
    /// <summary>
    ///   States what the chosen options will destroy.
    /// </summary>
    lblWarning: TLabel;
    /// <summary>
    ///   The "Type DELETE to confirm" label.
    /// </summary>
    lblConfirm: TLabel;
    /// <summary>
    ///   Where the user types DELETE to authorise a destructive option.
    /// </summary>
    edtConfirm: TEdit;
    /// <summary>
    ///   The "Delete" button.
    /// </summary>
    btnDelete: TBitBtn;
    /// <summary>
    ///   The "Cancel" button.
    /// </summary>
    btnCancel: TBitBtn;
    /// <summary>
    ///   Re-applies the option coupling and the button state after any option
    ///   changes, and withdraws a confirmation typed for a different choice.
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
      CONFIRM_WORD  = 'DELETE';

      /// <summary>
      ///   Applies the local-delete coupling, the warning text and the enabled
      ///   state of the Delete button to the current option selection.
      /// </summary>
    procedure UpdateState;

    /// <summary>
    ///   Gives the list a horizontal scroll bar wide enough for its longest
    ///   entry.
    /// </summary>
    /// <remarks>
    ///   A <c>TListBox</c> silently CLIPS text wider than its client area, and
    ///   these lines carry a full working-tree path, so the tail of every line
    ///   was being cut off - taking the resolved remote with it. That is the
    ///   one detail the user most needs before authorising an irreversible
    ///   deletion, so it cannot be allowed to fall off the right-hand edge with
    ///   nothing to say it had.
    /// </remarks>
    procedure SizeListToContent;
  public
    /// <summary>
    ///   Shows the dialog for a set of repositories and returns what to delete.
    /// </summary>
    /// <param name="aRepoLines">
    ///   One display line per repository, already formatted by the caller as
    ///   name, path and remote target. These are what the user is authorising,
    ///   so they must name the remote exactly rather than just its provider.
    /// </param>
    /// <param name="bAnyRemoteDeletable">
    ///   False when not one of the repositories has a remote this application
    ///   can delete. The remote option is then disabled rather than left to be
    ///   ticked, confirmed and then fail for every repository in the batch.
    /// </param>
    /// <param name="AOptions">Receives the chosen options when the result is True.</param>
    /// <returns>True when the user confirmed the deletion.</returns>
    class function Execute( const aRepoLines: TArray<string>; const bAnyRemoteDeletable: Boolean;
      out AOptions: TDeleteRepositoryOptions ): Boolean;
  end;

var
  /// <summary>
  ///   Unused design-time instance variable; the dialog is created by
  ///   <see cref="TDeleteRepositoryForm.Execute"/>.
  /// </summary>
  DeleteRepositoryForm: TDeleteRepositoryForm;

implementation

uses
  System.SysUtils, System.UITypes, System.Math;

{$R *.dfm}

procedure TDeleteRepositoryForm.UpdateState;
var
  bDestructive      : Boolean;
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

  bDestructive      := chkDeleteRemote.Checked or chkDeleteLocal.Checked;

  lblConfirm.Enabled := bDestructive;
  edtConfirm.Enabled := bDestructive;

  if ( not bDestructive ) then
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

  // The greyed check box says the option is unavailable; this says why.
  if ( not chkDeleteRemote.Enabled ) then
    lblWarning.Caption := lblWarning.Caption + ' None of these has a remote on GitHub that this ' +
      'application can delete.';

  btnDelete.Enabled := ( chkRemoveEntry.Checked or bDestructive ) and
    ( ( not bDestructive ) or SameStr( Trim( edtConfirm.Text ), CONFIRM_WORD ) );

end;

procedure TDeleteRepositoryForm.SizeListToContent;
var
  iWidest           : Integer;
begin

  iWidest           := 0;

  lstRepos.Canvas.Font := lstRepos.Font;

  for var i := 0 to lstRepos.Items.Count - 1 do
    iWidest         := Max( iWidest, lstRepos.Canvas.TextWidth( lstRepos.Items[ i ] ) );

  // ScrollWidth sends LB_SETHORIZONTALEXTENT. Zero - the default - means no
  // horizontal scroll bar at all, which is why the clipped text had no way of
  // being read.
  if iWidest > 0 then
    lstRepos.ScrollWidth := iWidest + ScaleValue( 12 );

end;

procedure TDeleteRepositoryForm.OptionClick( Sender: TObject );
begin

  // The typed word authorises the options as they stood when it was typed.
  // It used to survive a change: type DELETE for "local folder", then tick
  // "remote repository" as well, and the Delete button was already live for a
  // permanent deletion that had never been confirmed.
  if ( Sender = chkDeleteRemote ) or ( Sender = chkDeleteLocal ) then
    edtConfirm.Clear;

  UpdateState;

end;

procedure TDeleteRepositoryForm.edtConfirmChange( Sender: TObject );
begin

  UpdateState;

end;

class function TDeleteRepositoryForm.Execute( const aRepoLines: TArray<string>;
  const bAnyRemoteDeletable: Boolean; out AOptions: TDeleteRepositoryOptions ): Boolean;
var
  Dlg               : TDeleteRepositoryForm;
begin

  Result            := False;
  AOptions          := Default( TDeleteRepositoryOptions );

  Dlg               := TDeleteRepositoryForm.Create( nil );

  try
    if Length( aRepoLines ) = 1 then
      Dlg.lblIntro.Caption := 'This repository is about to be deleted:'
    else
      Dlg.lblIntro.Caption := Format( 'These %d repositories are about to be deleted:',
        [ Length( aRepoLines ) ] );

    for var sLine in aRepoLines do
      Dlg.lstRepos.Items.Add( sLine );

    Dlg.SizeListToContent;

    // Offering an option that cannot do anything is worse than not offering
    // it: the user would tick it, type the confirmation word, and get nothing
    // but a failure per repository.
    if ( not bAnyRemoteDeletable ) then
    begin
      Dlg.chkDeleteRemote.Enabled := False;

      // Short enough to leave real margin. A check box CLIPS its caption
      // silently, exactly as the list clipped its items, and the full
      // explanation at this width overflows - so that goes in the warning
      // label below, which word-wraps and therefore cannot clip at any DPI.
      Dlg.chkDeleteRemote.Caption := 'Delete the &remote repository on its host (no deletable remote)';
    end;

    // Entry removal alone is the harmless default; both irreversible options
    // start unticked so that neither can be taken by pressing Enter.
    Dlg.chkRemoveEntry.Checked := True;
    Dlg.UpdateState;

    if Dlg.ShowModal = mrOk then
    begin
      AOptions.RemoveEntry := Dlg.chkRemoveEntry.Checked;
      AOptions.DeleteRemote := Dlg.chkDeleteRemote.Checked;
      AOptions.DeleteLocal := Dlg.chkDeleteLocal.Checked;
      Result        := True;
    end;
  finally
    Dlg.Free;
  end;

end;

end.

