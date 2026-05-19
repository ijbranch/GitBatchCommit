# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Custom application icon — multi-resolution `.ico` (16/24/32/48/64/128/256 px) depicting a git-branch glyph (white main branch with two commit nodes, git-orange feature branch merging in) on a slate gradient tile, themed to match the app's Aqua Light Slate VCL style. Replaces the stock `delphi_PROJECTICON.ico` across the Base, Win32, and Win64 build configurations; embedded as `MAINICON` in the regenerated project resource (2026-05-19) — `GitBatchCommit.ico`, `GitBatchCommit.dproj`, `GitBatchCommit.res`
- Migrate Selected Repository to Codeberg / GitHub — moves a repository's remote between the two hosts (and back again) in a single operation. Creates the target repo, preserves the previous origin as a provider-named secondary remote (`codeberg` / `github`), swaps `origin`, and pushes all branches and tags. **Why:** avoids the manual sequence of creating the remote, renaming remotes by hand, and running `git push --all` / `--tags` separately (2026-04-18) — `uGitRepoManager.pas`, `MainFrm.pas`, `MainFrm.dfm`
- Single `APP_VERSION` constant in `uGitRepoManager.pas` — surfaces in About dialog and HTTP User-Agent; replaces scattered literal version strings (2026-04-18) — `uGitRepoManager.pas`, `MainFrm.pas`
- `IsSafeFilePattern` validator rejecting shell metacharacters in the File Pattern setting; rejected on both Settings dialog input and config-file load (2026-04-18) — `uGitRepoManager.pas`, `MainFrm.pas`
- `GetCurrentBranch` / `HasAnyCommit` / `IsWorkingTreeClean` helpers for safer Git flow decisions (2026-04-18) — `uGitRepoManager.pas`

### Changed
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

### Fixed
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

### Changed
- Commit and push operations now run in a background thread; UI remains responsive during batch commits (2026-04-02) — `MainFrm.pas`
- delphi-lookup reindexing simplified: every committed repo is reindexed automatically if delphi-indexer.exe is available; removed hardcoded directory lists (2026-04-02) — `MainFrm.pas`, `uGitRepoManager.pas`
- Deduplicated four near-identical HTTP API methods into a single `ExecuteApiRequest` core method (2026-04-02) — `uGitRepoManager.pas`
- Status colour values extracted to named constants (`clStatusClean`, `clStatusModified`, etc.) (2026-04-02) — `MainFrm.pas`
- Help menu now opens Users Guide instead of README.md (2026-04-02) — `MainFrm.pas`
- `.gitignore` cleaned up: removed ~280 duplicate backup-file patterns (365 lines reduced to ~70) (2026-04-02) — `.gitignore`
- SaveConfig guard prevents overwriting config file with empty repo list (2026-04-02) — `uGitRepoManager.pas`

### Fixed
- `.res` files incorrectly classified as build artefacts, hiding `.res`-only changes from the user (2026-04-02) — `uGitRepoManager.pas`
- Crash-on-close when async refresh is running; added cancellation flag and wait-for-completion in FormDestroy (2026-04-02) — `MainFrm.pas`
- "Clode Code" typo corrected to "Claude Code" in all file headers (2026-04-02) — `GitBatchCommit.dpr`, `MainFrm.pas`, `uGitRepoManager.pas`, `uCodebergDialog.pas`, `uCodebergSettings.pas`, `uGitHubSettings.pas`, `uTemplateSettings.pas`
- Version number mismatches unified to 1.5.0 across .dpr header, About dialog, and unit headers (2026-04-02) — `GitBatchCommit.dpr`, `MainFrm.pas`, `uGitRepoManager.pas`
- `uTemplateSettings` missing from .dpr uses clause (2026-04-02) — `GitBatchCommit.dpr`
- Temp file name collision risk in `CreateCommitMessageFile`; replaced `GetTickCount` with GUID-based naming (2026-04-02) — `uGitRepoManager.pas`
- MAX_PATH buffer overflow risk in drag-and-drop; now uses dynamic allocation (2026-04-02) — `MainFrm.pas`
- Version comparison edge case when version strings have different part counts (e.g. "1.5.0" vs "1.5.0.38") (2026-04-02) — `uGitRepoManager.pas`

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
