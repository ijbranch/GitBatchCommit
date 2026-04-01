# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Ctrl+Enter keyboard shortcut for Commit & Push (2026-04-02) — `MainFrm.pas`

### Changed
- Commit and push operations now run in a background thread; UI remains responsive during batch commits (2026-04-02) — `MainFrm.pas`
- delphi-lookup reindexing simplified: every committed repo is reindexed automatically if delphi-indexer.exe is available; removed hardcoded directory lists (2026-04-02) — `MainFrm.pas`, `uGitRepoManager.pas`
- Deduplicated four near-identical HTTP API methods into a single `ExecuteApiRequest` core method (2026-04-02) — `uGitRepoManager.pas`
- Status colour values extracted to named constants (`clStatusClean`, `clStatusModified`, etc.) (2026-04-02) — `MainFrm.pas`
- Help menu now opens `Help.md` instead of `README.md` (2026-04-02) — `MainFrm.pas`
- `.gitignore` cleaned up: removed ~280 duplicate backup-file patterns (365 lines reduced to ~70) (2026-04-02) — `.gitignore`

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
