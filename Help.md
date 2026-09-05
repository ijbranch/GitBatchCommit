# GitBatchCommit Help Guide

A comprehensive reference for all GitBatchCommit capabilities.

---

## Table of Contents

1. [Repository Management](#repository-management)
2. [Selection Tools](#selection-tools)
3. [Commit Operations](#commit-operations)
4. [Push Operations](#push-operations)
5. [Pull Operations](#pull-operations)
6. [Conflict Resolution](#conflict-resolution)
7. [Commit Messages](#commit-messages)
8. [Repository Groups](#repository-groups)
9. [Remote Providers](#remote-providers)
10. [Status and Display](#status-and-display)
11. [Settings and Configuration](#settings-and-configuration)
12. [Keyboard Shortcuts](#keyboard-shortcuts)
13. [Troubleshooting](#troubleshooting)

**Integration:** Uses [delphi-lookup](https://github.com/JavierusTk/delphi-lookup) by JavierusTk for optional symbol indexing

---

## Repository Management

### Add Repository

| Aspect | Details |
|--------|---------|
| **What** | Adds a Git repository to the managed list for batch operations |
| **Where** | File > Add Repository, or drag-and-drop onto main window |
| **When** | When you want to include a new repository in batch operations |
| **Why** | To manage multiple repositories from a single interface |
| **How** | Menu: File > Add Repository > Browse to folder with `.git` subfolder. Drag-drop: Select folders in Explorer, drag onto GitBatchCommit window |
| **Caveats** | Folder must contain a `.git` subfolder (valid Git repository). Non-repository folders are silently skipped when drag-dropping |
| **Linkages** | Added repositories appear in main list, are saved to configuration file, and persist between sessions |

### Remove Repository

| Aspect | Details |
|--------|---------|
| **What** | Removes a repository from the managed list |
| **Where** | File > Remove Selected |
| **When** | When you no longer want to manage a repository through this application |
| **Why** | To declutter the list or remove repositories you no longer work with |
| **How** | Select repository in list > File > Remove Selected > Confirm |
| **Caveats** | Only removes from the list - does NOT delete any files on disk. The repository and all its contents remain intact |
| **Linkages** | Removal is saved to configuration file immediately |

### Refresh Status

| Aspect | Details |
|--------|---------|
| **What** | Updates status information for all repositories |
| **Where** | File > Refresh Status, or press F5 |
| **When** | Automatically once at startup, then on demand - after making changes outside GitBatchCommit, or to check for remote updates |
| **Why** | To see current state of all repositories (modified files, remote changes, etc.) |
| **How** | Runs by itself when the application starts; otherwise press F5 or select File > Refresh Status. Runs in parallel for fast completion |
| **Caveats** | Performs `git fetch` which contacts remote servers - requires internet connection. May take time with many repositories |
| **Linkages** | Updates Status column, Branch column, Version column, and row colours |

---

## Selection Tools

### Select Modified

| Aspect | Details |
|--------|---------|
| **What** | Checks only repositories with local changes |
| **Where** | Toolbar button: "Select Modified" |
| **When** | Before committing - to select only repos that have changes to commit |
| **Why** | Saves time by automatically selecting relevant repositories |
| **How** | Click "Select Modified" button. All repos with "Modified" status become checked |
| **Caveats** | Selects only "Modified" repos - not Conflicted, Pull Required, Push Required, Diverged or Error. Only selects visible repos (respects current filter) |
| **Linkages** | Works with Group filter and Status filter |

### Select All

| Aspect | Details |
|--------|---------|
| **What** | Checks all repositories in the current view |
| **Where** | Toolbar button: "Select All" |
| **When** | When you want to perform an operation on all repositories |
| **Why** | Quick way to select everything without clicking each checkbox |
| **How** | Click "Select All" button |
| **Caveats** | Only selects visible repos (respects current Group and Status filters) |
| **Linkages** | Affected by View > Filter menu and Group dropdown |

### Select None

| Aspect | Details |
|--------|---------|
| **What** | Unchecks all repositories |
| **Where** | Toolbar button: "Select None" |
| **When** | To clear selection and start fresh |
| **Why** | Quick way to deselect everything |
| **How** | Click "Select None" button |
| **Caveats** | Clears all checkboxes regardless of filter |
| **Linkages** | None |

### Shift-Click Selection

| Aspect | Details |
|--------|---------|
| **What** | Select or deselect a range of consecutive repositories |
| **Where** | Main repository list |
| **When** | When you want to quickly check/uncheck multiple adjacent repos |
| **Why** | Faster than clicking each checkbox individually |
| **How** | Click one repo (sets anchor), hold Shift, click another repo. All repos between are toggled to match the anchor's state |
| **Caveats** | The anchor repo's checked state determines whether the range becomes checked or unchecked |
| **Linkages** | Works with sorted and filtered lists |

---

## Commit Operations

### Commit & Push Selected

| Aspect | Details |
|--------|---------|
| **What** | Stages all changes, commits with your message, and pushes to remote |
| **Where** | Bottom panel: "Commit & Push Selected" button |
| **When** | When you have local changes to share with the remote repository |
| **Why** | Core function - batch commit and push multiple repos with one click |
| **How** | 1) Check desired repos, 2) Enter commit message, 3) Optionally add details, 4) Click "Commit & Push Selected", 5) Confirm |
| **Caveats** | Button disabled until repos are selected AND commit message is entered. Same message used for all repos. Will fail if remote is ahead (use Pull first or Force Push) |
| **Linkages** | Uses File Pattern from Settings if configured. Creates version tags for Delphi projects. Adds message to history |

**Git Commands Executed:**
```
git add -A                    (or pattern-based if configured)
git commit -F <temp message file>
git push
git tag -a vX.X.X.X -m "..."  (if Delphi project with version)
git push origin vX.X.X.X      (pushes the tag)
```

### Automatic Version Tagging

| Aspect | Details |
|--------|---------|
| **What** | Automatically creates Git tags based on Delphi project version numbers |
| **Where** | Happens automatically during Commit & Push |
| **When** | When committing a repository containing a `.dproj` file with FileVersion |
| **Why** | Creates release markers visible in GitHub/Codeberg Releases section |
| **How** | Automatic - extracts version from `.dproj`, creates tag like `v1.0.0.123`, pushes tag |
| **Caveats** | Only creates tag if it doesn't already exist. Prefers the root `.dproj`, scanning subdirectories only when there is none. Only works with Delphi projects |
| **Linkages** | Version displayed in Version column. Tags appear in remote's Tags/Releases |

---

## Push Operations

### Push Only

| Aspect | Details |
|--------|---------|
| **What** | Pushes existing commits without creating a new commit |
| **Where** | Toolbar button: "Push Only" |
| **When** | When local branch is ahead of remote (commits exist but not pushed) |
| **Why** | To sync already-committed changes without adding a new commit |
| **How** | Check repos > Click "Push Only" > Confirm |
| **Caveats** | Does nothing if there are no unpushed commits. Will fail if remote is ahead |
| **Linkages** | Use after manual commits in external Git client, or after Resolve Conflicts |

**Git Commands Executed:**
```
git push
```

### Force Push

| Aspect | Details |
|--------|---------|
| **What** | Overwrites remote history with local state |
| **Where** | Toolbar button: "Force Push" |
| **When** | When local code is the "source of truth" and remote has diverged |
| **Why** | To make remote match local exactly, discarding any remote-only commits |
| **How** | Check repos > Click "Force Push" > Confirm first warning > Confirm second warning |
| **Caveats** | **DESTRUCTIVE** - permanently loses any commits on remote that aren't in local. Requires double confirmation. Cannot be undone |
| **Linkages** | Use after resetting local to undo a pull, or when you're certain local should overwrite remote |

**Git Commands Executed:**
```
git push --force-with-lease=<branch>:<commit shown at last refresh> origin -- <branch>
```

---

## Pull Operations

### Pull (Single Repository)

| Aspect | Details |
|--------|---------|
| **What** | Fast-forwards one repository to its upstream (`git pull --ff-only`) |
| **Where** | Right-click context menu > Pull |
| **When** | When a single repo shows "Pull Required" status |
| **Why** | To incorporate remote changes into local repository |
| **How** | Right-click repo > Pull > Review warnings > Review changes > Confirm |
| **Caveats** | **WARNING: Modifies local files!** Creates a backup branch first - which captures COMMITTED history only, not uncommitted work. Cannot merge, so a non-fast-forward pull is refused rather than producing a conflict |
| **Linkages** | A non-fast-forward pull is refused, so this cannot leave the tree conflicted. Resolve Conflicts is for conflicts created OUTSIDE this application |

### Pull Selected

| Aspect | Details |
|--------|---------|
| **What** | Pulls remote changes for multiple selected repositories |
| **Where** | Toolbar button: "Pull Selected" |
| **When** | When multiple repos show "Pull Required" status |
| **Why** | Batch pull operation instead of pulling one at a time |
| **How** | Check repos > Click "Pull Selected" > Review warning > Review file changes > Confirm |
| **Caveats** | **WARNING: Modifies local files!** Creates backup branches, which capture COMMITTED history only. Cannot merge, so a non-fast-forward pull is refused rather than producing a conflict |
| **Linkages** | A non-fast-forward pull is refused, so this cannot leave the tree conflicted. Resolve Conflicts is for conflicts created OUTSIDE this application |

### Pull Safeguards

| Aspect | Details |
|--------|---------|
| **What** | Safety features that protect local code during pull operations |
| **Where** | Automatically applied to all Pull operations |
| **When** | Every time you pull |
| **Why** | To prevent accidental loss of local work |
| **How** | Automatic - warning shown, changes previewed, backup created |
| **Caveats** | Backup branches accumulate - delete manually when no longer needed |
| **Linkages** | Backup branch named `backup-YYYY-MM-DD-HHMMSS-zzz`. Recovery: `git reset --hard backup-...` |

**Safeguard Details:**

1. **Warning Dialog** - Explicitly states local files may be modified
2. **Change Preview** - Shows exactly which files will change before you commit
3. **Backup Branch** - Creates timestamped backup before any changes

**Recovery from Bad Pull:**
```
git reset --hard backup-2026-01-15-143022-517
```

**Cleanup After Successful Pull:**
```
git branch -d backup-2026-01-15-143022-517
```

---

## Conflict Resolution

### Resolve Conflicts

| Aspect | Details |
|--------|---------|
| **What** | Automatically resolves merge conflicts by keeping local versions |
| **Where** | Toolbar button: "Resolve Conflicts" |
| **When** | After a merge performed OUTSIDE this application has left conflicts |
| **Why** | Quick resolution when you want local code to take precedence |
| **How** | Check repos with conflicts > Click "Resolve Conflicts" > Confirm |
| **Caveats** | Uses "keep local" strategy ONLY - remote changes are discarded. For complex merges requiring manual review, use external Git client |
| **Linkages** | After resolving, changes are committed and pushed automatically |

**Git Commands Executed:**
```
git checkout --ours .
git add .
git commit -m "Resolved merge conflicts - kept local version"
git push
```

---

## Commit Messages

### Commit Message Field

| Aspect | Details |
|--------|---------|
| **What** | Single-line summary for your commit |
| **Where** | Bottom panel: text field next to "Commit Message:" label |
| **When** | Before every commit |
| **Why** | Git requires a commit message |
| **How** | Type your message. Same message used for all selected repos |
| **Caveats** | Keep it concise - this is the summary line. Use Details for longer explanations |
| **Linkages** | Combined with Details if provided. Saved to history after successful commit |

### Commit Details

| Aspect | Details |
|--------|---------|
| **What** | Multi-line detailed description for commits |
| **Where** | Bottom panel: Click "..." button to reveal details memo |
| **When** | When commit needs more explanation than a single line |
| **Why** | Standard Git format allows summary + detailed body |
| **How** | Click "..." > Enter details in memo > Commit as normal |
| **Caveats** | Details panel auto-hides after successful commit |
| **Linkages** | Combined with summary as: `Summary\n\nDetails` |

### Commit Message History

| Aspect | Details |
|--------|---------|
| **What** | Dropdown list of your last 20 commit messages |
| **Where** | Bottom panel: Click "▼" button next to commit message field |
| **When** | When you want to reuse a previous commit message |
| **Why** | Saves typing for repeated operations |
| **How** | Click "▼" > Select message from list > Message inserted into field |
| **Caveats** | Stores last 20 messages only. Oldest removed when limit exceeded |
| **Linkages** | Saved to configuration file. Persists between sessions |

### Commit Message Templates

| Aspect | Details |
|--------|---------|
| **What** | Predefined reusable commit messages |
| **Where** | File > Templates (manage), or "▽" button (use) |
| **When** | For standardised commit messages across projects |
| **Why** | Ensures consistency, saves typing |
| **How** | Create: File > Templates > Add. Use: Click "▽" > Select template |
| **Caveats** | Templates are plain text - no variables or placeholders |
| **Linkages** | Saved to configuration file. Persists between sessions |

---

## Repository Groups

### Assigning Groups

| Aspect | Details |
|--------|---------|
| **What** | Organise repositories into named groups |
| **Where** | Right-click context menu > Set Group |
| **When** | When you want to categorise repos (by project, client, type, etc.) |
| **Why** | Makes filtering and batch operations easier |
| **How** | Check repos > Right-click > Set Group > Select existing or create new |
| **Caveats** | Each repo can only belong to one group. Group applied to all checked repos |
| **Linkages** | Groups appear in toolbar dropdown. Saved to configuration file |

### Filtering by Group

| Aspect | Details |
|--------|---------|
| **What** | Show only repositories in a specific group |
| **Where** | Toolbar: "Group:" dropdown |
| **When** | When you want to focus on a subset of repositories |
| **Why** | Reduces clutter, allows targeted batch operations |
| **How** | Select group name from dropdown. Select "(All Groups)" to show all |
| **Caveats** | Selection buttons (Select All, etc.) only affect visible repos |
| **Linkages** | Works with View > Filter status filter |

### Clearing Groups

| Aspect | Details |
|--------|---------|
| **What** | Remove group assignment from repositories |
| **Where** | Right-click > Set Group > (Clear Group) |
| **When** | When repo no longer belongs to a group |
| **Why** | To reorganise or declutter groups |
| **How** | Check repos > Right-click > Set Group > (Clear Group) |
| **Caveats** | Repos without groups appear in all group views |
| **Linkages** | Empty groups are automatically removed from dropdown |

---

## Remote Providers

### GitHub Integration

| Aspect | Details |
|--------|---------|
| **What** | Create and manage repositories on GitHub |
| **Where** | GitHub menu |
| **When** | When you want to create new GitHub repos or manage existing ones |
| **Why** | Direct integration without leaving the application |
| **How** | First: GitHub > Settings (enter credentials). Then: GitHub > Initialize & Push |
| **Caveats** | Requires personal access token with `repo` scope from github.com/settings/tokens. Token encrypted at rest with DPAPI (current user, this machine) |
| **Linkages** | Created repos automatically added to managed list |

### Codeberg Integration

| Aspect | Details |
|--------|---------|
| **What** | Create and manage repositories on Codeberg |
| **Where** | Codeberg menu |
| **When** | When you want to create new Codeberg repos or manage existing ones |
| **Why** | Direct integration without leaving the application |
| **How** | First: Codeberg > Settings (enter credentials). Then: Codeberg > Initialize & Push |
| **Caveats** | Requires personal access token from codeberg.org/user/settings/applications. Token encrypted at rest with DPAPI (current user, this machine) |
| **Linkages** | Created repos automatically added to managed list |

### Change Visibility (Public/Private)

| Aspect | Details |
|--------|---------|
| **What** | Change repository visibility on GitHub or Codeberg |
| **Where** | Right-click context menu > Set Public / Set Private |
| **When** | When you need to change who can see a repository |
| **Why** | Manage access without visiting the web interface |
| **How** | Right-click repo > Set Public or Set Private > Confirm |
| **Caveats** | Only works for GitHub and Codeberg repos. Requires valid credentials. Must have permission to modify settings |
| **Linkages** | Uses stored credentials from respective Settings |

### Migrate Between GitHub and Codeberg

| Aspect | Details |
|--------|---------|
| **What** | Move a repository's remote from Codeberg to GitHub, or GitHub to Codeberg |
| **Where** | Codeberg menu > Migrate Selected Repository to Codeberg... / GitHub menu > Migrate Selected Repository to GitHub... |
| **When** | When you want to change which host a repository lives on — works in both directions |
| **Why** | One-click migration instead of creating the remote, renaming, and re-pushing manually |
| **How** | Select repo > choose destination menu > confirm name/description/visibility > confirm summary. The target repo is created; the previous origin is preserved locally as a `codeberg` / `github` secondary remote; `origin` is swapped; branches that existed only on the old remote are recovered locally first, then all branches (`git push -u origin --all`) and tags (`git push origin --tags`) are pushed |
| **Caveats** | The old remote repository is NOT deleted — remove it manually via the web UI once you have verified the migration. Target host credentials must be configured first (settings dialog opens automatically if missing). An existing local remote of the alias name is **left alone** — a numbered suffix is used instead, so a mirror remote you already had is never destroyed. If any step fails, the original remotes are restored |
| **Linkages** | Uses stored credentials from GitHub/Codeberg Settings. Provider column updates after migration |

---

## Status and Display

### Status Column

| Aspect | Details |
|--------|---------|
| **What** | Current state of each repository |
| **Where** | Main list: "Status" column |
| **When** | Always visible |
| **Why** | Quick overview of which repos need attention |
| **How** | Automatic - updated on refresh |
| **Caveats** | Status is a snapshot - may become stale if changes made outside app |
| **Linkages** | Determines row colour. Can filter by status via View > Filter |

**Status Values:**

| Status | Meaning | Row Colour |
|--------|---------|------------|
| Clean | No local changes, and level with the upstream | Light green |
| Modified | Local uncommitted changes present | Light yellow |
| Conflicted | Unmerged paths, or an unfinished merge/rebase/cherry-pick/revert/bisect | Strong red |
| Pull Required (n) | Upstream has n commits this clone lacks | Light orange |
| Push Required (n) | This clone has n commits the upstream lacks | Pale green |
| Diverged (+a/-b) | a commits ahead and b behind at the same time | Light purple |
| Error | Repository not accessible or invalid | Light red |

**How each is determined:**

| Check | Command | Notes |
|-------|---------|-------|
| Working tree | `git status --porcelain` | Covers modified, staged, untracked, deleted and renamed files, and dirty submodules |
| Conflicts | porcelain `XY` codes `DD` `AU` `UD` `UA` `DU` `AA` `UU` | Outranks everything else - Commit & Push refuses while any are present |
| Unfinished operation | `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`, `sequencer/todo`, `rebase-merge/`, `rebase-apply/` - located via `git rev-parse --absolute-git-dir`, so worktrees and submodules are handled | Reported as Conflicted |
| Build-output-only change | extension and platform-folder match | The status text gains **" - build output only"**, so the repository is visibly excluded from Commit & Push rather than silently omitted. `debug/` and `release/` alone are NOT treated as build output, so `docs/release/notes.md` still counts as a real change |
| Ahead / behind | `git rev-list --left-right --count @{upstream}...HEAD` | Locale-independent, both directions in one call; zero/zero when the branch has no upstream |

**Not detected:** stashed work, and changes to files marked `assume-unchanged` or `skip-worktree`. Neither appears in `git status`.

### When an operation refuses to run

GitBatchCommit declines rather than guessing whenever it cannot establish the repository's state. Each of these is reported per repository in the log, and the rest of the batch continues.

| Refusal | Why |
|---|---|
| "unfinished merge, rebase, cherry-pick, revert or bisect" | `git add -A` would stage files still containing conflict markers, and the commit would push them |
| "could not determine the repository state" | `git status` failed or timed out. An indeterminate state is treated as a refusal, never as permission |
| "unresolved conflicts" | Unmerged paths are present |
| "HEAD is detached or the branch is unborn" | Commit and push both appear to succeed on a detached HEAD, leaving the work reachable only from the reflog |
| Force push: "the remote has moved since this repository's status was last refreshed" | The lease is pinned to the upstream commit shown in the list when it was last refreshed. Refresh and review the incoming commits before retrying |

### Closing while work is running

Closing the window during a Git operation asks whether to cancel it. Cancellation is checked between repositories, so the window normally closes within a second or two of answering **Yes**. Answering **No** leaves the window open and the batch running.

If a Git call is stuck on a network timeout, the drain gives up after 90 seconds, the window stays open, and you are told to try closing again in a moment. The manager is never freed while a worker is still inside it.

### Status Filter

| Aspect | Details |
|--------|---------|
| **What** | Show only repositories with specific status |
| **Where** | View > Filter menu |
| **When** | When you want to focus on repos needing specific action |
| **Why** | Reduces clutter, targeted batch operations |
| **How** | View > Filter > Select status (All, Clean, Modified, Conflicted, Pull Required, Push Required, Diverged, Error) |
| **Caveats** | Selection buttons only affect visible repos |
| **Linkages** | Works with Group filter |

### Column Sorting

| Aspect | Details |
|--------|---------|
| **What** | Sort repository list by any column |
| **Where** | Main list: Click column headers |
| **When** | To organise the list in a meaningful order |
| **Why** | Find repos faster, group similar items |
| **How** | Click column header to sort ascending. Click again for descending |
| **Caveats** | Sort state not persisted between sessions |
| **Linkages** | None |

### Version Column

| Aspect | Details |
|--------|---------|
| **What** | Project version from Delphi `.dproj` files |
| **Where** | Main list: "Version" column |
| **When** | For Delphi projects with version information |
| **Why** | Quick reference for project versions without opening IDE |
| **How** | Automatic - reads the root `.dproj`, scanning subdirectories only when there is none; the highest version wins |
| **Caveats** | Only works for Delphi projects. Where several are found, the highest version wins |
| **Linkages** | Used for automatic version tagging during commit |

---

## Settings and Configuration

### Application Settings

| Aspect | Details |
|--------|---------|
| **What** | Configure application behaviour |
| **Where** | File > Settings |
| **When** | To customize Git client path or file patterns |
| **Why** | Personalise the application to your workflow |
| **How** | File > Settings > Modify values > OK |
| **Caveats** | Settings saved immediately |
| **Linkages** | Git Client Path used by "Open in Git Client". File Pattern used by Commit & Push |

**Available Settings:**

| Setting | Purpose | Example |
|---------|---------|---------|
| Git Client Path | External Git client executable; used for GitBatchCommit's own Git calls only when its filename is `git.exe` | `C:\Program Files\Fork\Fork.exe` |
| File Pattern | Only stage files matching pattern | `*.pas` (empty = all files) |
| delphi-indexer.exe Path | Optional symbol indexer for auto-reindex | Auto-detected or custom path |

### Configuration File

| Aspect | Details |
|--------|---------|
| **What** | JSON file storing all persistent data |
| **Where** | `%APPDATA%\GitBatchCommit\repositories.json` (i.e. `…\AppData\Roaming\GitBatchCommit`) |
| **When** | Created automatically on first use |
| **Why** | Persist settings, repos, credentials between sessions |
| **How** | Automatic - no manual editing required |
| **Caveats** | Credentials are DPAPI-encrypted (current user, this machine) and appear as opaque `dpapi:` values; the rest of the file is plain JSON |
| **Linkages** | Stores: Repository list, groups, credentials, settings, history, templates |

### Edit .gitignore

| Aspect | Details |
|--------|---------|
| **What** | View or edit a repository's .gitignore file |
| **Where** | Right-click context menu > Edit .gitignore |
| **When** | To exclude files from Git tracking |
| **Why** | Quick access without navigating file system |
| **How** | Right-click repo > Edit .gitignore > Edit in default text editor |
| **Caveats** | Creates new file if doesn't exist (with confirmation). Opens in system default editor |
| **Linkages** | None |

### delphi-lookup Integration

| Aspect | Details |
|--------|---------|
| **What** | Automatic symbol reindexing after push operations using delphi-indexer |
| **Where** | Automatic after Commit & Push, Push Only, Force Push, or Resolve Conflicts; configurable via File > Settings |
| **When** | After successfully pushing changes to a repository |
| **Why** | Keeps delphi-lookup symbol database current with latest code changes |
| **How** | Automatic - reindexes each repository it has just pushed, in the background. Configure path via File > Settings if needed |
| **Caveats** | Requires delphi-lookup installed. Only reindexes if repository is (or is within) a delphi-lookup indexed directory. Silently skips if not found |
| **Linkages** | Uses [delphi-indexer](https://github.com/JavierusTk/delphi-lookup) by JavierusTk. Non-blocking (~100-500ms). Auto-detects from PATH or default location |

**How Auto-Detection Works:**

1. Checks user-configured custom path (if configured via Settings)
2. Checks PATH environment variable for delphi-indexer.exe
3. Checks default location: `D:\glldelphi-lookup\delphi-indexer.exe`
4. Saves discovered path to configuration for faster future lookups
5. Silently skips reindexing if not found

**Path Verification:**

- Configured paths are verified before each use
- If configured path no longer exists (file moved/deleted), auto-detection runs again
- Configuration self-heals automatically

**Manual Configuration:**

- File > Settings > "Configure delphi-indexer.exe path?" > Yes
- Browse to delphi-indexer.exe location
- Saved to configuration file immediately

**Confirmation:**

When reindexing is triggered after a commit, log messages appear:

**Success:**
```
Triggering delphi-lookup reindex: E:\DBiWorkflow Development
delphi-lookup reindex completed successfully
```

**Failure:**
```
Triggering delphi-lookup reindex: E:\DBiWorkflow Development
delphi-lookup reindex FAILED
Error: [error details from delphi-indexer]
```

This confirms which indexed directory is being updated and whether the operation succeeded.

---

## Keyboard Shortcuts

| Shortcut | Action | Where |
|----------|--------|-------|
| F1 | Open Help (Users Guide.md) | Anywhere |
| F5 | Refresh Status | Anywhere |
| Ctrl+A | Select All Text | Log panel |
| Ctrl+C | Copy Selected Text | Log panel |
| Shift+Click | Range Selection | Repository list |

---

## Troubleshooting

### Push Fails - Remote Ahead

| Problem | Remote has commits not in local |
|---------|--------------------------------|
| **Symptom** | Push fails with "rejected" or "non-fast-forward" error |
| **Cause** | Someone else pushed, or you pushed from another machine |
| **Solutions** | 1) Pull Selected (fast-forwards to the remote), or 2) Force Push (overwrites remote) |
| **Recommendation** | Use Pull if you want remote changes. Use Force Push if local is source of truth |

### Pull Overwrote My Code

| Problem | Pull merged unwanted remote changes into local |
|---------|----------------------------------------------|
| **Symptom** | Local files changed unexpectedly after pull |
| **Cause** | The remote has commits this clone lacks; the fast-forward-only pull cannot apply them over local commits |
| **Solutions** | Reset to backup branch: `git reset --hard backup-YYYY-MM-DD-HHMMSS-zzz` |
| **Prevention** | Review change preview before confirming pull. Use Force Push if local is source of truth |

### Repository Shows Error Status

| Problem | Repository status shows "Error" |
|---------|---------------------------------|
| **Symptom** | Red row, "Error" in Status column |
| **Cause** | Path doesn't exist, not a Git repo, or Git command failed |
| **Solutions** | 1) Check path exists, 2) Verify `.git` folder present, 3) Check Git is in PATH |
| **Recommendation** | Remove and re-add repository if path changed |

### Merge Conflicts After Pull

| Problem | Pull resulted in merge conflicts |
|---------|----------------------------------|
| **Symptom** | Log shows conflict messages, files have conflict markers |
| **Solutions** | 1) Click "Resolve Conflicts" (keeps local), or 2) Use external Git client for manual merge |
| **Recommendation** | Use Resolve Conflicts for simple cases. Use external client for complex merges requiring review |

### Version Not Showing

| Problem | Version column is empty for Delphi project |
|---------|-------------------------------------------|
| **Symptom** | Blank Version column despite having .dproj file |
| **Cause** | .dproj not found, or doesn't contain FileVersion |
| **Solutions** | Ensure .dproj has `<FileVersion>` in VerInfo_Keys section |
| **Recommendation** | Set version in Project > Options > Version Info in Delphi IDE |

### Credentials Not Working

| Problem | GitHub or Codeberg operations fail with auth error |
|---------|---------------------------------------------------|
| **Symptom** | API calls fail, "unauthorized" errors |
| **Cause** | Invalid or expired access token |
| **Solutions** | 1) Generate new token, 2) Update in respective Settings dialog |
| **Recommendation** | Ensure token has required scopes (GitHub needs `repo` scope) |

---

## Quick Reference - Operation Flow

### Typical Commit Workflow
```
1. Make changes in your projects
2. Open GitBatchCommit
3. Press F5 to refresh status
4. Click "Select Modified"
5. Enter commit message
6. Click "Commit & Push Selected"
7. Confirm
```

### When Push Fails (Remote Ahead)
```
Option A - Accept Remote Changes:
1. Click "Pull Selected"
2. Review warnings and changes
3. Confirm pull
4. If conflicts: Click "Resolve Conflicts"
5. Click "Push Only"

Option B - Overwrite Remote:
1. Click "Force Push"
2. Confirm both warnings
```

### Recovery from Bad Pull
```
1. Note the backup branch name from log (backup-YYYY-MM-DD-HHMMSS-zzz)
2. Open command prompt in repo folder
3. Run: git reset --hard backup-YYYY-MM-DD-HHMMSS-zzz
4. Use "Force Push" to sync remote
```

---

*GitBatchCommit Help Guide - Version 1.6.0*
*Last Updated: 5 September 2026*
