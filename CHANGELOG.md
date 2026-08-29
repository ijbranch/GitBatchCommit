# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Repository status now distinguishes **Conflicted**, **Push Required** and **Diverged** alongside Clean / Modified / Pull Required / Error, each with its own row colour and View > Filter entry. **Why:** two states were previously invisible. A repository with unmerged paths reported as ordinary *Modified*, so Commit & Push would `git add -A` the conflict markers and push them — `CommitAndPush` now refuses outright while any path is unmerged or a merge/rebase/cherry-pick/revert/bisect is unfinished. And a repository whose work was committed but never pushed reported as *Clean*, with nothing anywhere in the UI saying the remote was out of date (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`, `MainFrm.dfm`
- Ahead/behind commit counts are surfaced in the status text — "Push Required (3)", "Pull Required (2)", "Diverged (+2/-5)" (2026-08-30) — `uGitRepoManager.pas`
- Full DocInsight coverage: every interface declaration across all six units now carries a `/// <summary>`, with `/// <param>` and `/// <returns>` on everything that takes parameters or returns a value — 63 new doc blocks and 50 completed ones. Plain `Sender: TObject` on DFM-wired event handlers is deliberately left undocumented, matching the existing convention; parameters that carry meaning (`Item`, `Key`, `Shift`, dispatching `Sender`) are documented (2026-08-30) — all units
- `.gitattributes` — pin CRLF checkout for all text file types, independent of each clone's `core.autocrlf`; binaries marked explicitly, Pascal linguist hints included. (2026-07-28) — `.gitattributes`
- Custom application icon — multi-resolution `.ico` (16/24/32/48/64/128/256 px) depicting a git-branch glyph (white main branch with two commit nodes, git-orange feature branch merging in) on a slate gradient tile, themed to match the app's Aqua Light Slate VCL style. Replaces the stock `delphi_PROJECTICON.ico` across the Base, Win32, and Win64 build configurations; embedded as `MAINICON` in the regenerated project resource (2026-05-19) — `GitBatchCommit.ico`, `GitBatchCommit.dproj`, `GitBatchCommit.res`
- Icon generator script — reproducible GDI+ renderer for the application icon (vector "git-branch on slate" design, all sizes, repo-portable via `$PSScriptRoot`); regenerates `GitBatchCommit.ico` byte-identically (2026-05-19) — `tools/generate-icon.ps1`
- Migrate Selected Repository to Codeberg / GitHub — moves a repository's remote between the two hosts (and back again) in a single operation. Creates the target repo, preserves the previous origin as a provider-named secondary remote (`codeberg` / `github`), swaps `origin`, and pushes all branches and tags. **Why:** avoids the manual sequence of creating the remote, renaming remotes by hand, and running `git push --all` / `--tags` separately (2026-04-18) — `uGitRepoManager.pas`, `MainFrm.pas`, `MainFrm.dfm`
- Single `APP_VERSION` constant in `uGitRepoManager.pas` — surfaces in About dialog and HTTP User-Agent; replaces scattered literal version strings (2026-04-18) — `uGitRepoManager.pas`, `MainFrm.pas`
- `IsSafeFilePattern` validator rejecting shell metacharacters in the File Pattern setting; rejected on both Settings dialog input and config-file load (2026-04-18) — `uGitRepoManager.pas`, `MainFrm.pas`
- `GetCurrentBranch` / `HasAnyCommit` / `IsWorkingTreeClean` helpers for safer Git flow decisions (2026-04-18) — `uGitRepoManager.pas`

### Changed
- `ELExtraPlugIns` now sits in its **own** `{$IFDEF EurekaLog} … {$ENDIF EurekaLog}` block, placed immediately after the main EurekaLog block, matching the DBiWorkflow suite. Moving it inside the *main* block did not survive — the EL IDE expert rewrites the block it owns and pushed the reference back out on the next IDE build — but a separate block of its own is left alone, which is how 26 of the 30 suite projects handle it (the other four keep it in the main block with a note to put it back when the expert moves it). Previously it sat outside any conditional, so a non-EurekaLog build still referenced it (2026-08-30) — `GitBatchCommit.dpr`
- Version aligned at **1.6.0** across `APP_VERSION`, the `.dpr` header and the `.dproj` version info, which had drifted to 1.5.0.x; `README.md`, `Help.md` and `Users Guide.md` updated for the new statuses, `--force-with-lease`, the conflict semantics, DPAPI token storage and the Git-client-path change, and their version footers brought forward (2026-08-30) — `GitBatchCommit.dproj`, `GitBatchCommit.dpr`, `README.md`, `Help.md`, `Users Guide.md`
- `NeedsPull` replaced by `GetAheadBehind`, which answers both directions from a single `rev-list --left-right --count`. `GetRepoStatus` removed — it was a second, drifting copy of `RefreshStatus`'s logic with no remaining callers (2026-08-30) — `uGitRepoManager.pas`
- The Git client path setting is now actually used. It was loaded, saved and settable from the Settings dialog, but `ExecuteGitCommand` hard-coded `git` and resolved it from `PATH`, so the setting did nothing. Git is also invoked with `-c core.quotepath=false` so non-ASCII paths come back readable (2026-08-30) — `uGitRepoManager.pas`
- `ExecuteGitCommand` and `TMainForm.ExecuteCommand` now share one process runner, `RunProcessCaptureOutput`. They were near-duplicates carrying identical defects, fixed once each in two places (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`
- `GetProjectVersion` prefers a `.dproj` in the repository root and only falls back to the recursive scan when there is none. **Why:** taking the highest version found anywhere in the tree let a vendored third-party project decide the repository's version — which `CommitAndPush` then turned into a pushed Git tag. A 30-second scan window also stops the full recursive walk being repeated for every repository on every refresh (2026-08-30) — `uGitRepoManager.pas`
- `RefreshStatus` now snapshots the repository path under the lock, runs its Git calls outside it and publishes results by matching on path, so it is safe to call concurrently. The form's hand-rolled `TParallel.For` has been replaced by the manager's own `RefreshAllStatusParallel`, which was already written correctly but had no callers — the form's version indexed `FRepos` while add/remove could `SetLength` it from the UI thread (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`
- Remaining `FRepos[index]` reads in `CommitAndPush`, `PullRepository`, `PushRepository`, `ForcePushRepository`, `CreateBackupBranch`, `GetRepoProvider`, `SetRepositoryVisibility`, `GetIncomingChanges`, `MigrateRepository`, `SetRepoGroup` and `GetAllGroups` now go through the lock, via `GetRepoSnapshot` or an explicit critical section (2026-08-30) — `uGitRepoManager.pas`
- `ScrollLogToEnd` uses `EM_LINESCROLL` instead of reading `mmoLog.Text` to place the caret, which concatenated every line in the memo on every log call; the log is also capped at 5000 lines (2026-08-30) — `MainFrm.pas`
- Version in the `.dpr` header brought up to 1.6.0, matching `APP_VERSION` (2026-08-30) — `GitBatchCommit.dpr`
- The post-commit reindex fell back to `D:\delphi-lookup\delphi-indexer.exe`, a folder that no longer exists — delphi-lookup was relocated to `D:\glldelphi-lookup` when it was forked into GITLAK. `DEFAULT_INSTALL_PATH` repointed at the new folder, so the reindex still runs when `delphi-indexer.exe` is not on `PATH` (2026-08-27) — `MainFrm.pas`
- Repointed the `ELExtraPlugIns` reference and unit search path at `E:\DBiWorkflow Development` — the shared-suite folder dropped its `v 5` suffix on 2026-07-30, reverting the 2026-07-28 repoint below (2026-07-30) — `GitBatchCommit.dpr`, `GitBatchCommit.dproj`
- All MainFrm message dialogs migrated from `MessageDlg` to `StyledMessageDlg` (`VCL.StyledTaskDialog`) — 76 call sites — so dialogs render consistently with the app's Aqua Light Slate VCL style; `uses` clause tidied (2026-05-19) — `MainFrm.pas`
- Migration now runs off the UI thread — the app stays responsive during `push --all` (2026-04-18) — `MainFrm.pas`
- Migration aborts if the working tree is dirty or the repo has no commits, instead of leaving a half-migrated state (2026-04-18) — `uGitRepoManager.pas`
- `CreateCodebergRepository` / `CreateGitHubRepository` now delegate to a shared `CreateRemoteRepository` that builds request bodies with `TJSONObject` (safe escaping) and surfaces the API-returned clone URL verbatim (2026-04-18) — `uGitRepoManager.pas`
- `ExecuteGitCommand` runs `git.exe` directly via `CreateProcess` with `lpCurrentDirectory`, dropping the `cmd.exe /c cd /d …` wrapper — removes a command-injection surface and fragile quoting (2026-04-18) — `uGitRepoManager.pas`
- `FRepos` mutations and parallel-refresh reads are now guarded by a `TCriticalSection`; parallel refresh snapshots paths and writes back under the lock (2026-04-18) — `uGitRepoManager.pas`
- Initial push no longer hard-codes `main`; detects the current branch via `rev-parse --abbrev-ref HEAD` and falls back to `symbolic-ref` (2026-04-18) — `uGitRepoManager.pas`
- HTTP client sets explicit `UserAgent`, `ConnectionTimeout` (15 s), `ResponseTimeout` (30 s); GitHub no longer sporadically returns 403 for missing User-Agent (2026-04-18) — `uGitRepoManager.pas`
- `PullRepository` uses `pull --ff-only` to avoid surprise merge commits on diverged branches (2026-04-18) — `uGitRepoManager.pas`
- `GetProjectVersion` caches per-path results keyed on the newest `.dproj` mtime — subsequent refreshes skip the recursive scan if nothing changed (2026-04-18) — `uGitRepoManager.pas`
- Backup-branch names now include millisecond precision; two backups inside the same second no longer collide (2026-04-18) — `uGitRepoManager.pas`
- Popup and main menu items that act on a selection (Migrate, Remove Selected, Pull, Set Public/Private, Open in …) are disabled when no repository is selected (2026-04-18) — `MainFrm.pas`
- `MigrateSelectedTo` displays the authoritative clone URL returned by the API instead of reconstructing one from name + host (2026-04-18) — `MainFrm.pas`
- Commit and push operations now run in a background thread; UI remains responsive during batch commits (2026-04-02) — `MainFrm.pas`
- delphi-lookup reindexing simplified: every committed repo is reindexed automatically if delphi-indexer.exe is available; removed hardcoded directory lists (2026-04-02) — `MainFrm.pas`, `uGitRepoManager.pas`
- Deduplicated four near-identical HTTP API methods into a single `ExecuteApiRequest` core method (2026-04-02) — `uGitRepoManager.pas`
- Status colour values extracted to named constants (`clStatusClean`, `clStatusModified`, etc.) (2026-04-02) — `MainFrm.pas`
- Help menu now opens Users Guide instead of README.md (2026-04-02) — `MainFrm.pas`
- `.gitignore` cleaned up: removed ~280 duplicate backup-file patterns (365 lines reduced to ~70) (2026-04-02) — `.gitignore`
- SaveConfig guard prevents overwriting config file with empty repo list (2026-04-02) — `uGitRepoManager.pas`

### Removed
- Per-project copy of the EurekaLog Extras unit `EExtraExceptionInfo.pas` (an outdated revision predating the `E_*_INFO` define rename). **Why:** from EurekaLog 7.16 the `Source\Extras` folder is compiled directly off the library search path, so a local copy only shadows the installed version and re-creates the stale-unit failure above (2026-07-28) — `EExtraExceptionInfo.pas`

### Fixed
- A commit/push batch aborted after the first repository with `No mapping for the Unicode character exists in the target multi-byte code page`, losing the remaining reindexes and the completion dialog. Captured child-process output was decoded one 4096-byte pipe read at a time, so a multi-byte UTF-8 character straddling a read boundary left an invalid sequence — and `TEncoding.UTF8` is constructed with `MB_ERR_INVALID_CHARS`, so `GetCharCount` returns 0 and `TEncoding.GetString` **raises** instead of substituting U+FFFD. Output is now accumulated as raw bytes and decoded once, through a lenient UTF-8 encoding. **Why:** the failure was intermittent by nature — it only fired when a multi-byte character happened to land on a 4096-byte boundary — so it read as random flakiness (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`
- Every commit message written by the tool began with an invisible UTF-8 BOM, which Git does not strip from a `-F` message file, so every commit subject started with U+FEFF. `CreateCommitMessageFile` now uses the single-argument `TFile.WriteAllText` overload, which writes UTF-8 without a preamble (2026-08-30) — `uGitRepoManager.pas`
- Commit log blocks were attributed to the wrong repository, the first repository never appeared at all, and `UpdateListItem` refreshed the wrong row. Delphi allocates one closure capture frame per **routine**, not per loop iteration, so all the `TThread.Queue` closures created inline in the commit loop shared a single `sCommitLog`/`iRI`, which the worker then overwrote before the UI thread read them. Queuing now goes through a per-iteration method call, `QueueCommitLog` (2026-08-30) — `MainFrm.pas`
- Fix .gitignore added `*.res` to the ignore list, which would silently stop `git add` staging every project's compiled resource (manifest, icon, version info). Removed; `WriteGitIgnoreForProjectType` had never listed it, so the two generators now agree (2026-08-30) — `MainFrm.pas`
- Force Push used a bare `push --force`, with no check that the remote was still where this clone last saw it. Now `--force-with-lease`, with an explicit message when the lease is stale (2026-08-30) — `uGitRepoManager.pas`
- "Backup branch … was created" was logged after a pull even when `CreateBackupBranch` had failed, printing an empty branch name and a `git branch -d` with no argument. The single-repository pull now offers to abort when no backup could be made, and the batch pull reports honestly whether any were created (2026-08-30) — `MainFrm.pas`
- Select All / Select None / Select Modified and shift-click range selection never reached the repository records: they suppress `lvReposItemChecked` — the only writer of `Repos[].Selected` — via `FUpdatingList`, so the next repopulate silently cleared every tick. A new `SyncCheckedStateToManager` is called after each bulk change (2026-08-30) — `MainFrm.pas`
- Shift-clicking a row after any filter, sort or group change raised `EListError: List index out of bounds`. `FLastClickedIndex` is a **row** index and was never reset when the list was rebuilt; `PopulateListView` now clears it (2026-08-30) — `MainFrm.pas`
- Closing the window during a commit/push or a migrate freed `TGitRepoManager` out from under the running worker thread, and left queued UI callbacks pointing at a destroyed form. `FormDestroy` waited only on `FRefreshing`, which neither of those threads ever set. All background workers are now tracked with an interlocked counter, waited for via `CheckSynchronize`, and their queued events removed (2026-08-30) — `MainFrm.pas`
- Post-commit reindexing ran inside a `TThread.Synchronize` block, freezing the UI for up to the command timeout per repository — potentially minutes across a large batch. It now runs on the worker thread and marshals only its log lines (2026-08-30) — `MainFrm.pas`
- `slReindexDirs` was freed inside the synchronised completion block **and** again in the enclosing exception handler, so anything raising after the first free double-freed it. Ownership is now a single `try..finally` (2026-08-30) — `MainFrm.pas`
- Removing the last repository was never persisted — `SaveConfig` refused to write an empty list, so it reappeared on the next start. The guard now only applies before a successful `LoadConfig`, which is the case it was actually meant to protect against (2026-08-30) — `uGitRepoManager.pas`
- The build-artifact heuristic matched any path containing `/debug/` or `/release/`, so a repository whose only change was, say, `docs/release/notes.md` displayed as Clean and was never committed. Delphi build output always sits under a platform folder, which the remaining tests cover (2026-08-30) — `uGitRepoManager.pas`
- `GetIncomingChanges` fed the `(unknown)` **display** string to Git as a branch name, producing `diff --stat HEAD..origin/(unknown)`; the resulting failure was reported to the user as "no incoming changes". It now resolves the branch afresh and distinguishes "no upstream" from "up to date". A failed preview in the pull paths is no longer silently swallowed (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`
- `NeedsPull` decided by scraping the English string `Your branch is behind` out of `git status`, which fails under a localised Git. It now uses `rev-list --count HEAD..@{upstream}` (2026-08-30) — `uGitRepoManager.pas`
- The migration worker had no exception handler, so a dropped connection vanished into `TThread.FatalException`: no dialog, no log line, and `Screen.Cursor` stuck as `crHourGlass` for the rest of the session (2026-08-30) — `MainFrm.pas`
- Typing in the commit-message box while a commit batch was running re-enabled the Commit & Push button and allowed a second concurrent batch over the same repositories (2026-08-30) — `MainFrm.pas`
- `ExecuteGitCommand`/`ExecuteCommand` could spin forever at 100% CPU: the poll loop exited only on `WAIT_OBJECT_0` and decremented its timeout only on `WAIT_TIMEOUT`, so `WAIT_FAILED` satisfied neither. Process and thread handles were also closed only on the straight-line success path. Both are fixed in the shared runner (2026-08-30) — `uGitRepoManager.pas`
- `SearchPath` returns the **required** buffer size when the result does not fit, without writing the buffer; a non-zero return was taken as success, so uninitialised stack could be persisted as the indexer path. A transient absence of the indexer (network share, removable drive) also permanently erased the configured path — it is now left alone (2026-08-30) — `MainFrm.pas`
- Generated `.gitignore` files were written with a UTF-8 BOM, corrupting the first rule of every non-Delphi template — `node_modules/`, `target/`, `bin/`, `__pycache__/` and `*.o` simply stopped being ignored. Fix .gitignore also round-tripped a BOM-less UTF-8 file through the ANSI code page via `TStrings.SaveToFile`, and tested for existing rules by substring containment, so `*.o` could never be added once `*.obj` was present. All three fixed (2026-08-30) — `MainFrm.pas`
- The group filter drifted out of step with its combo box: when the filtered group's last member was re-grouped the combo snapped back to "(All Groups)" while `FGroupFilter` kept the old name, showing an empty list. Group matching is also now case-insensitive (2026-08-30) — `MainFrm.pas`
- Set Group was enabled by row **selection** but acted on **checked** rows, so on a highlighted-but-unticked row the menu was enabled and did nothing. It now falls back to the selected row, and repopulates so the change is visible (2026-08-30) — `MainFrm.pas`
- Resolve Conflicts ran `checkout --ours .` with no check that a merge was in progress, then committed and pushed whatever it found. It now requires `MERGE_HEAD`, and the confirmation states plainly that the remote side of each conflicted file is discarded (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`
- Synchronous batch loops (Pull, Resolve Conflicts, Push, Force Push) walked `lvRepos.Items` live while pumping the message queue via `Log`, so a filter or sort change mid-batch could leave the loop indexing past the end of a rebuilt list, and nothing stopped the user re-entering the same handler. Each now resolves its repository indices once up front and takes a batch guard (2026-08-30) — `MainFrm.pas`
- The selected list row was drawn with `clWindowText` on a `clHighlight` background, making it effectively unreadable; `ShellExecute` failures (no handler registered for `.md` or `.gitignore`) were silent; and Ctrl+Enter fired Commit & Push even while editing the multi-line details memo (2026-08-30) — `MainFrm.pas`
- `slPreview` leaked whenever the incoming-changes preview or its dialog raised, being freed at two separate exit points rather than in a `try..finally` (2026-08-30) — `MainFrm.pas`
- `AppDPIAwarenessMode` was `PerMonitorV2` for Debug/Win64 and Release/Win32 while everything else was `unaware`, so layout bugs reproduced under the debugger but not in the shipped build. All configurations are now `unaware`; verified in the binary manifest (2026-08-30) — `GitBatchCommit.dproj`
- Orphaned private method `GetModifiedFileCount` removed (its last caller went with the old duplicate status routine), and `slExistingRules` in Fix .gitignore was constructed twice and freed never — a leak on every use of that menu item. Both surfaced as compiler hints (`H2219`, `H2077`) that the MSBuild wrapper had not been reporting (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`
- Build failed with `F2051 Unit EFastMM5Support was compiled with a different version of ETypes.TLeaksOption`, and then with `F1026 File not found: E:\DBiWorkflow Development\DBiCommonFiles\ELExtraPlugIns.pas`. Two causes: stale EurekaLog `.dcu` files left in the project root (built 2026-06-18) shadowed the current EurekaLog 7.16+ library units, and the shared `DBiCommonFiles` folder had since been renamed to `DBiWorkflow Development v 5`. Removed the stale root `.dcu` files and repointed the `ELExtraPlugIns` reference and unit search path at the current folder (2026-07-28) — `GitBatchCommit.dpr`, `GitBatchCommit.dproj`

- Folder names with spaces (or other characters invalid for a Git host) produced a repo name that Codeberg/GitHub rejected. The default repo name is now passed through a new `SanitizeRepoName` (drops whitespace so a "Title Case" folder becomes "TitleCase", replaces other invalid characters with `-`, collapses/trims separators) at all three Initialize & Push pre-fill sites (Codeberg, GitHub, and the generic init). The field remains editable (2026-06-18) — `uGitRepoManager.pas`, `MainFrm.pas`
- Documentation corrections in `Help.md`: config file path was `%USERPROFILE%\GitBatchCommit\repositories.json`, corrected to `%APPDATA%\GitBatchCommit\repositories.json` to match the code's `TPath.GetHomePath`; F1/Help shortcut listed as opening `README.md`, corrected to `Users Guide.md` (the actual `Help > Help Contents` target). Footer dates refreshed on both `Help.md` and `Users Guide.md` (2026-06-14) — `Help.md`, `Users Guide.md`
- Create Codeberg Repository dialog (no project-type variant) overlapped its OK/Cancel buttons with the "Private Repository" checkbox on high-DPI displays: the runtime layout used hard-coded pixel positions (`125`, `165`) that were not DPI-scaled, while the DFM-placed checkbox was — so the two collided and OK painted over the caption. Buttons are now positioned relative to the already-scaled checkbox with `ScaleValue` gaps (2026-06-14) — `uCodebergDialog.pas`
- Build broke (`F2613: Unit 'LoggerPro' not found`, preceded by an `F2051` version mismatch) after the suite-wide `LoggerPro` → `gllLoggerPro` migration: GitBatchCommit had no unit search path to the replacement library and was only resolving it via a stale shared `.dcu`. Added `D:\gllLoggerPro` to `DCC_UnitSearchPath`. **Why:** the gllLoggerPro replacement was wired into the Win64 global library path but not Win32, so the per-project path makes resolution deterministic for both platforms (2026-05-19) — `GitBatchCommit.dproj`
- Create Codeberg Repository dialog (no project-type variant) clipped its OK/Cancel buttons: `ClientHeight` was set to 180 but buttons sat at Y=172â€“197. Buttons now move up and `ClientHeight` shrinks to 165 when project type is hidden (2026-05-10) â€” `uCodebergDialog.pas`
- JSON injection risk in repo-creation API calls: name and description were `Format`'d into the request body; now built with `TJSONObject` so quotes/newlines/backslashes are properly escaped (2026-04-18) — `uGitRepoManager.pas`
- Potential AV when `AddRepository` / `RemoveRepository` ran while `RefreshAllStatusParallel` was indexing `FRepos` — both now hold a critical section (2026-04-18) — `uGitRepoManager.pas`
- `SaveConfig` failures (read-only filesystem, locked file) previously silently lost configuration; now emit `OutputDebugString` diagnostics (2026-04-18) — `uGitRepoManager.pas`

- Drag-and-drop initialisation: dropping a non-git folder offers to initialise it, create a remote repo (Codeberg or GitHub), and push — all in one step (2026-04-02) — `MainFrm.pas`
- Project type selection when initialising new repos; generates appropriate `.gitignore` for Delphi, C/C++, C#, Java, Python, JavaScript, TypeScript, Go, Rust, or HTML (2026-04-02) — `MainFrm.pas`, `uCodebergDialog.pas`, `uCodebergDialog.dfm`
- Ctrl+Enter keyboard shortcut for Commit & Push (2026-04-02) — `MainFrm.pas`
- Users Guide.md — narrative user documentation (2026-04-02) — `Users Guide.md`
- CHANGELOG.md — project change log in Keep a Changelog format (2026-04-02) — `CHANGELOG.md`
- `.res` files incorrectly classified as build artefacts, hiding `.res`-only changes from the user (2026-04-02) — `uGitRepoManager.pas`
- Crash-on-close when async refresh is running; added cancellation flag and wait-for-completion in FormDestroy (2026-04-02) — `MainFrm.pas`
- "Clode Code" typo corrected to "Claude Code" in all file headers (2026-04-02) — `GitBatchCommit.dpr`, `MainFrm.pas`, `uGitRepoManager.pas`, `uCodebergDialog.pas`, `uCodebergSettings.pas`, `uGitHubSettings.pas`, `uTemplateSettings.pas`
- Version number mismatches unified to 1.5.0 across .dpr header, About dialog, and unit headers (2026-04-02) — `GitBatchCommit.dpr`, `MainFrm.pas`, `uGitRepoManager.pas`
- `uTemplateSettings` missing from .dpr uses clause (2026-04-02) — `GitBatchCommit.dpr`
- Temp file name collision risk in `CreateCommitMessageFile`; replaced `GetTickCount` with GUID-based naming (2026-04-02) — `uGitRepoManager.pas`
- MAX_PATH buffer overflow risk in drag-and-drop; now uses dynamic allocation (2026-04-02) — `MainFrm.pas`
- Version comparison edge case when version strings have different part counts (e.g. "1.5.0" vs "1.5.0.38") (2026-04-02) — `uGitRepoManager.pas`

### Security
- Codeberg and GitHub personal access tokens are now encrypted at rest with DPAPI (current-user scope) before being written to `repositories.json`, and decrypted transparently on load. A token stored in plain text by an earlier build is still read and is re-written protected on the next save. **Why:** the config file previously held usable credentials in clear text under `%APPDATA%`, readable by any process running as the user and carried into every backup and roaming-profile sync (2026-08-30) — `uGitRepoManager.pas`
- Log output is passed through a new `RedactSecrets`, masking the userinfo section of URLs and bare provider token literals. **Why:** Git echoes the remote URL verbatim in most push/fetch errors, so a remote of the form `https://user:token@host` put a live credential into a log the user routinely selects and pastes (2026-08-30) — `uGitRepoManager.pas`, `MainFrm.pas`
- Child processes are launched with an explicit environment setting `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=Never` and empty askpass variables, and with a real (empty) stdin. **Why:** with `STARTF_USESTDHANDLES` set and no stdin handle, a Git operation needing credentials could stall on an invalid handle or raise an interactive Credential Manager dialog behind a hidden window (2026-08-30) — `uGitRepoManager.pas`
## [1.5.0] - 2026-01-26

### Added
- delphi-lookup integration — automatically triggers incremental reindexing after commits (2026-01-26) — `MainFrm.pas`, `uGitRepoManager.pas`
- Auto-detects delphi-indexer.exe from PATH or default location
- Manual path configuration via File > Settings if auto-detection fails
- 30-second timeout with automatic termination if indexing hangs

## [1.4.0] - 2026-01-15

### Added
- Version column in repository list — displays version extracted from Delphi `.dproj` files (2026-01-15) — `MainFrm.pas`, `uGitRepoManager.pas`
- Automatic version tagging for Delphi projects — creates Git tags (e.g., `v3.9.1.719`) on commit (2026-01-15) — `uGitRepoManager.pas`
- Pull Selected button — pull changes for multiple repositories at once (2026-01-15) — `MainFrm.pas`
- Resolve Conflicts button — resolve merge conflicts by keeping local versions (2026-01-15) — `MainFrm.pas`
- Push Only button — push without committing for repos ahead of remote (2026-01-15) — `MainFrm.pas`
- Force Push button — overwrite remote with local code, with double confirmation (2026-01-15) — `MainFrm.pas`
- Pull safeguards: warning dialog, incoming change preview, automatic backup branch creation (2026-01-15) — `MainFrm.pas`, `uGitRepoManager.pas`
- Ctrl+A support in log panel to select all text (2026-01-15) — `MainFrm.pas`

## [1.3.0] - 2026-01-01

### Added
- Commit message templates — create and manage reusable commit messages via File > Templates (2026-01-01) — `uTemplateSettings.pas`, `uTemplateSettings.dfm`, `MainFrm.pas`
- Commit details panel — click "..." to add detailed description in standard Git format (2026-01-01) — `MainFrm.pas`, `MainFrm.dfm`
- Repository groups — organise repositories into groups for filtering (2026-01-01) — `MainFrm.pas`, `uGitRepoManager.pas`
- Group filter dropdown in toolbar (2026-01-01) — `MainFrm.pas`, `MainFrm.dfm`
- Set Group context menu item (2026-01-01) — `MainFrm.pas`

### Fixed
- Shift-click range selection for checking/unchecking repositories (2026-01-01) — `MainFrm.pas`

## [1.2.0] - 2026-01-01

### Changed
- Parallel status refresh — repositories checked concurrently for faster performance (2026-01-01) — `MainFrm.pas`
- UI remains responsive during status refresh operations (2026-01-01) — `MainFrm.pas`
- Optimised git command execution — reduced redundant calls (2026-01-01) — `uGitRepoManager.pas`
- Real-time list updates as each repository status completes (2026-01-01) — `MainFrm.pas`

## [1.1.0] - 2025-12-31

### Added
- Colour-coded status indicators: green=Clean, yellow=Modified, orange=Pull Required, red=Error (2025-12-31) — `MainFrm.pas`
- Context menu options: Open in Explorer, Open in Git Client, Pull (2025-12-31) — `MainFrm.pas`, `MainFrm.dfm`
- Commit message history — up to 20 messages, accessible via dropdown (2025-12-31) — `MainFrm.pas`, `uGitRepoManager.pas`
- Settings dialog for Git client path and file pattern filtering (2025-12-31) — `MainFrm.pas`
- File pattern filtering for selective staging (2025-12-31) — `uGitRepoManager.pas`

## [1.0.0] - 2025-12-31

### Added
- Initial release — batch commit and push to multiple Git repositories with a single commit message (2025-12-31) — `MainFrm.pas`, `uGitRepoManager.pas`, `GitBatchCommit.dpr`
- Repository management with drag-and-drop support (2025-12-31) — `MainFrm.pas`
- Status detection: Clean, Modified, Pull Required, Error (2025-12-31) — `uGitRepoManager.pas`
- Codeberg and GitHub integration — create remote repositories and push (2025-12-31) — `uGitRepoManager.pas`, `uCodebergDialog.pas`, `uCodebergSettings.pas`, `uGitHubSettings.pas`
