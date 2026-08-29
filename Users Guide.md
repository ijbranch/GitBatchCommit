# GitBatchCommit Users Guide

## What Is GitBatchCommit?

GitBatchCommit lets you commit and push changes to multiple Git repositories at once with a single commit message. This is particularly useful when a shared library change affects many projects — rather than opening each repository individually, you select the modified ones, type your message, and push them all in one operation.

## Getting Started

### Requirements

- **Git** must be installed and available on your system PATH
- **Windows** 7 SP1 or later
- An internet connection for push/pull operations

### First Launch

When you first start the application, the repository list will be empty. You need to add your Git repositories.

### Adding Repositories

**Drag and drop** is the easiest method:

1. Open Windows Explorer alongside GitBatchCommit
2. Select one or more folders that contain Git repositories (folders with a `.git` subfolder)
3. Drag them onto the GitBatchCommit window
4. They appear in the list and their status is checked automatically

You can drag multiple folders at once.

You can also use **File > Add Repository** to browse for a single folder.

Repositories are saved automatically — they persist between sessions.

### Initialising a New Repository

If you drop a folder that is **not** already a Git repository, the app offers to set it up for you:

1. A dialog asks which remote provider: **Codeberg**, **GitHub**, or **Cancel** to skip
2. You enter the repository name, description, and choose public or private
3. You select the **project type** (Delphi, Python, C#, etc.) — this generates an appropriate `.gitignore`
4. The app initialises Git, creates the remote repository, commits all files, and pushes

This is the quickest way to get a new project under version control and hosted remotely.

### Removing Repositories

Select repositories in the list, then use **File > Remove Selected**. This only removes them from the app's list. No files are deleted from disk.

## Understanding the Display

### The Repository List

Each row shows:

| Column | What It Shows |
|--------|---------------|
| **Name** | Repository folder name |
| **Path** | Full path on disk |
| **Branch** | Current Git branch (usually `main`) |
| **Remote** | Hosting provider: Codeberg, GitHub, Other, or None |
| **Tracked Files** | Number of files Git is tracking |
| **Modified** | Number of changed/new/deleted files |
| **Status** | Current state (see below) |
| **Version** | Version from Delphi `.dproj` file, if present |

Click any column header to sort. Click again to reverse the order.

### Status Colours

Rows are colour-coded:

| Colour | Status | Meaning |
|--------|--------|---------|
| Green | Clean | No local changes, up to date with remote |
| Yellow | Modified | You have uncommitted changes |
| Orange | Pull Required | The remote has new commits you don't have locally |
| Red | Error | Path doesn't exist, or Git command failed |

### Refreshing Status

Press **F5** or use **File > Refresh Status**. This runs in the background — the UI stays responsive while repositories are checked in parallel.

## Daily Workflow

### The Typical Commit Cycle

This is what you'll do most often:

1. Make changes to your projects in the Delphi IDE
2. Switch to GitBatchCommit
3. Press **F5** to refresh (modified repos turn yellow)
4. Click **Select Modified** to tick all changed repos
5. Type your commit message in the text field at the bottom
6. Press **Ctrl+Enter** or click **Commit & Push Selected**
7. Confirm the dialog

All selected repositories are staged (`git add -A`), committed with your message, and pushed to their remote. The operation runs in the background — you can watch progress in the log panel.

### Adding Details to Your Commit

For a more detailed commit message (like the standard Git summary + body format):

1. Click the **...** button next to the commit message field
2. A details panel expands below the list
3. Type your extended description there
4. The commit message will be: your summary line, a blank line, then the details

### Reusing Previous Messages

- Click the **down arrow** button to see your last 20 commit messages
- Click the **triangle** button to pick from saved templates
- Manage templates via **File > Templates**

## Selection Tools

| Button/Action | What It Does |
|---------------|--------------|
| **Select Modified** | Ticks only repos with changes (yellow rows) |
| **Select All** | Ticks all visible repos |
| **Select None** | Unticks everything |
| **Shift+Click** | Ticks or unticks a range of consecutive repos |

## Filtering

### By Status

Use **View > Filter** to show only repos with a specific status (All, Clean, Modified, Pull Required, Error).

### By Group

Use the **Group** dropdown in the toolbar. Groups let you organise repos into categories (e.g., "DBiWorkflow", "Libraries", "Tools").

To assign a group: right-click a repository and choose **Set Group**.

## Pull Operations

### Pulling Changes

When a repository shows "Pull Required" (orange):

- **Right-click > Pull** for a single repo
- **Pull Selected** button for multiple repos at once

Before pulling, the app shows:
1. A warning that local files may be modified
2. A preview of incoming changes
3. An automatic backup branch is created (named `backup-YYYY-MM-DD-HHMMSS`)

### Resolving Conflicts

If a pull results in merge conflicts:

1. Click **Resolve Conflicts** — this keeps your local version of conflicted files and **discards the incoming remote version of those files**. It only acts on a repository with a merge actually in progress; others are skipped
2. Then click **Push Only** to send the resolution to the remote

For complex merges requiring manual review, use an external Git client instead.

## Push Operations

| Button | When to Use |
|--------|-------------|
| **Commit & Push Selected** | Normal workflow — stages, commits, and pushes |
| **Push Only** | When you've already committed locally but haven't pushed yet |
| **Force Push** | When you need to overwrite the remote with your local code (use with care — requires double confirmation). Uses `--force-with-lease`, so it aborts rather than overwriting if someone else has pushed since your last fetch |

**Reading the Status column**

| Status | What it means | What to do |
|--------|---------------|------------|
| Clean | Nothing to do | — |
| Modified | Uncommitted local changes | Commit & Push |
| Conflicted | Unmerged files, or a half-finished merge/rebase | Resolve Conflicts, or finish the operation in your Git client. Commit & Push will refuse until you do |
| Pull Required (n) | The remote has n commits you do not | Pull Selected |
| Push Required (n) | You have n commits the remote does not | Push Only |
| Diverged (+a/-b) | Both — you and the remote have moved on separately | Pull first, then push; or Force Push if your copy is authoritative |
| Error | Not a valid or reachable repository | Check the path exists and contains `.git` |

## Remote Provider Integration

### Codeberg

- **Codeberg > Settings** — enter your username and API token (generate at codeberg.org/user/settings/applications)
- **Codeberg > Initialize & Push** — creates a new Codeberg repo and pushes your local code to it
- **Codeberg > Migrate Selected Repository to Codeberg** — moves the selected repository from GitHub (or another host) onto Codeberg

### GitHub

- **GitHub > Settings** — enter your username and personal access token (generate at github.com/settings/tokens, needs `repo` scope)
- **GitHub > Initialize & Push** — creates a new GitHub repo and pushes your local code to it
- **GitHub > Migrate Selected Repository to GitHub** — moves the selected repository from Codeberg (or another host) onto GitHub

### Migrating Between Hosts

Select a repository, then pick **Migrate Selected Repository to Codeberg** (under the Codeberg menu) or **Migrate Selected Repository to GitHub** (under the GitHub menu). The target repo is created, `origin` is repointed to it, and all branches and tags are pushed. The previous origin URL is kept as a secondary remote (named `codeberg` or `github`) so it can be restored. The old remote repository is not deleted — remove it via the web UI once you are satisfied with the migration.

### Changing Visibility

Right-click a repository and choose **Set Public** or **Set Private** to change its visibility on Codeberg or GitHub.

## Context Menu (Right-Click)

Right-click any repository in the list for:

| Option | What It Does |
|--------|--------------|
| **Set Public / Set Private** | Changes remote visibility |
| **Edit .gitignore** | Opens the repo's `.gitignore` in your default editor |
| **Fix .gitignore** | Adds standard Delphi ignore patterns to the `.gitignore` |
| **Open in Explorer** | Opens the repo folder in Windows Explorer |
| **Open in Git Client** | Opens in your configured external Git client |
| **Pull** | Pulls changes from remote |
| **Set Group** | Assigns the repo to a group for filtering |

## Delphi-Specific Features

### Version Display

For Delphi projects, the Version column shows the `FileVersion` from the `.dproj` file. The app searches the repository root and subdirectories for `.dproj` files.

### Automatic Version Tagging

When you commit a Delphi project, the app automatically:
1. Reads the version from the `.dproj` file
2. Creates an annotated Git tag (e.g., `v1.5.0.38`)
3. Pushes the tag to the remote

Tags appear in your Codeberg/GitHub Releases section.

### delphi-lookup Integration

If [delphi-indexer](https://github.com/JavierusTk/delphi-lookup) is installed, the app automatically triggers a reindex after each batch of commits. This keeps your delphi-lookup symbol database up to date. If delphi-indexer is not installed, this step is silently skipped.

## Settings

### Application Settings (File > Settings)

- **Git Client Path** — path to an external Git client (e.g., Fork, SourceTree) for "Open in Git Client". Point it at `git.exe` to make GitBatchCommit use that executable for its own Git calls too
- **File Pattern** — optional pattern for selective staging (e.g., `*.pas *.dfm`). When empty, `git add -A` stages everything
- **delphi-indexer Path** — auto-detected; override here if needed

### Configuration File

Settings, credentials, repositories, commit history, and templates are stored in:

```
%APPDATA%\GitBatchCommit\repositories.json
```

This file is outside the project directory and is never committed to Git.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **F1** | Open this help guide |
| **F5** | Refresh all repository statuses |
| **Ctrl+Enter** | Commit & Push Selected |
| **Ctrl+A** | Select all text (in log panel) |
| **Shift+Click** | Range selection in repository list |

## Troubleshooting

### No Repositories After Startup

If your repository list is empty after restarting, the configuration file may have been reset. Re-add your repositories via drag-and-drop.

### Push Fails — "Rejected" or "Non-Fast-Forward"

The remote has commits you don't have locally. Either:
- **Pull Selected** first to merge the remote changes, then push again
- **Force Push** to overwrite the remote (if your local code is the source of truth)

### Repository Shows Error (Red)

- Check the folder path still exists
- Verify the `.git` subfolder is present
- Check Git is installed and on your PATH

### Version Column Is Empty

The `.dproj` file either doesn't exist or doesn't contain a `FileVersion` entry. Set the version in Delphi IDE via **Project > Options > Version Info**.

### Credentials Not Working

Generate a new token and update it via the respective Settings dialog (**Codeberg > Settings** or **GitHub > Settings**).

---

*GitBatchCommit Users Guide - Version 1.6.0*
*Last Updated: 14 June 2026*
