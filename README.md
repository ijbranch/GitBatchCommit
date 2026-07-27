# GitBatchCommit

A Delphi VCL application for committing and pushing changes to multiple Git repositories simultaneously with a single commit message.

## Overview

GitBatchCommit simplifies the workflow of updating multiple projects when a shared library or component is modified. Rather than opening each repository individually in a Git client, this tool allows you to select multiple repositories, enter a single commit message, and push all changes in one operation.

## Features

- **Repository Management** - Add and remove Git repositories from a persistent list
- **Drag and Drop** - Drag repository folders from Windows Explorer directly onto the application. Dropping a non-Git folder offers to initialise it, create a remote repo, and push in one step
- **New Repository Initialisation** - Automatic project type detection with `.gitignore` generation for Delphi, C/C++, C#, Java, Python, JavaScript, TypeScript, Go, Rust, and HTML
- **Codeberg Integration** - Create new Codeberg repositories and push directly from the application
- **GitHub Integration** - Create new GitHub repositories and push directly from the application
- **Migrate Between Hosts** - Move a repository's remote from Codeberg to GitHub (or back) via the Codeberg/GitHub menus. Creates the new repo on the target host, preserves the previous origin as a secondary remote for safety, swaps `origin`, and pushes all branches and tags
- **Visibility Management** - Change repository visibility (public/private) via right-click context menu
- **Parallel Status Refresh** - Repository status checks run in parallel on background threads, keeping the UI responsive
- **Status Detection** - Automatically detects repository status:
  - **Clean** - No local changes, up to date with remote
  - **Modified** - Local uncommitted changes present (modified, staged, untracked, or deleted files)
  - **Pull Required** - Remote has updates that need pulling
  - **Error** - Repository not accessible or not a valid Git repo

  Status is determined by running `git status --porcelain`. Any output indicates modifications.
- **Branch Display** - Shows the current branch for each repository
- **Remote Provider Display** - Shows the remote provider (GitHub, Codeberg, Other, None) for each repository
- **Version Display** - Shows the project version extracted from Delphi `.dproj` files (searches repository and subdirectories)
- **Automatic Version Tagging** - For Delphi projects, automatically creates and pushes Git tags based on the version number in the `.dproj` file when committing
- **Batch Operations** - Commit and push to multiple repositories with one click
- **Quick Selection** - Buttons to select all, none, or only modified repositories
- **Shift-Click Selection** - Hold Shift and click to select/deselect a range of repositories
- **Edit .gitignore** - Right-click a repository to edit its .gitignore file
- **Column Sorting** - Click any column header to sort; click again to reverse order
- **Status Filtering** - Use View > Filter menu to show only repositories with specific status
- **Smart Button State** - Commit & Push button only enabled when repositories are selected and commit message is entered
- **Operation Log** - Detailed log of all Git operations performed
- **Help System** - Press F1 to view README documentation; Help > About for version info
- **Colour-Coded Status** - Repository rows are colour-coded by status (green=Clean, yellow=Modified, orange=Pull Required, red=Error)
- **Open in Git Client** - Right-click to open repository in configured external Git client (e.g., Fork)
- **Open in Explorer** - Right-click to open repository folder in Windows Explorer
- **Pull Operation** - Right-click to pull changes from remote for a single repository (fast-forward only — refuses to create a merge commit on diverged history)
- **Commit Message History** - Click the dropdown button next to the commit message to select from recent messages (up to 20 stored)
- **Commit Message Templates** - Define reusable commit message templates via File > Templates; select from the templates dropdown (▽) next to the commit message
- **Commit Details** - Click the "..." button to add a detailed description below the summary line (standard Git commit format)
- **Repository Groups** - Assign repositories to groups for easy filtering; use the Group dropdown in the toolbar to filter by group
- **File Pattern Filtering** - Optionally stage only files matching a pattern (e.g., `*.pas`) via File > Settings
- **delphi-lookup Integration** - Automatically triggers incremental reindexing of committed repositories for delphi-lookup symbol search (optional, auto-detected)
- **Pull Selected** - Pull changes from remote for multiple selected repositories at once (with safeguards)
- **Resolve Conflicts** - Automatically resolve merge conflicts by keeping local versions for all selected repositories
- **Push Only** - Push already-committed changes without creating a new commit (useful when local branch is ahead of remote)
- **Force Push** - Force push to overwrite remote history when local code is the source of truth
- **Pull Safeguards** - Multiple safety features protect your local code when pulling:
  - Warning dialog clearly explains that local files may be modified
  - Preview of incoming changes before pulling
  - Automatic backup branch creation before any pull operation

## Requirements

- Delphi 10.3 Rio or higher (uses inline variable declarations)
- Git installed and available in system PATH
- Windows operating system

### Third-Party Dependencies

| Component | Description | Source |
|-----------|-------------|--------|
| FastMM5 | High-performance memory manager | https://github.com/pleriche/FastMM5 |
| Aqua Light Slate | VCL visual style (optional - falls back to default if unavailable) | Included with RAD Studio Premium Styles |
| delphi-lookup | Optional: Delphi symbol indexer for auto-reindex after commits | https://github.com/JavierusTk/delphi-lookup |
| EurekaLog 7 | Exception reporting; compiled in under the `EurekaLog` conditional define | https://www.eurekalog.com |
| ELExtraPlugIns | GITLAK EurekaLog plug-in aggregator, referenced by absolute path from `GitBatchCommit.dpr` | `E:\DBiWorkflow Development v 5\DBiCommonFiles` |

**Notes:**
- To remove the FastMM5 dependency, remove `FastMM5` from the uses clause in `GitBatchCommit.dpr`. The project will then use Delphi's default memory manager.
- delphi-lookup integration is completely optional. GitBatchCommit works normally without it installed.
- The EurekaLog units are compiled from the EurekaLog installation (`Lib\` and `Source\Extras\`, both on the IDE's Win64 library path). Do **not** keep local copies of EurekaLog source or `.dcu` files in the project folder — the project directory is searched first, so a stale copy shadows the installed version and the build fails with `F2051 Unit … was compiled with a different version of …`. The cure is to delete the offending `.dcu`/`.pas` from the project root and rebuild.
- `ELExtraPlugIns` is referenced by an absolute path in both `GitBatchCommit.dpr` and the project's unit search path. If the shared `DBiCommonFiles` folder is moved or renamed, update both or the build fails with `F1026 File not found`.

## Installation

1. Download or clone the source files
2. Open `GitBatchCommit.dpr` in Delphi
3. Build the project (Ctrl+F9) or Run (F9)

## Usage

### Adding Repositories

**Method 1: Drag and Drop (Recommended)**

1. Open Windows Explorer and navigate to your Git repositories
2. Select one or more repository folders
3. Drag and drop them onto the GitBatchCommit window
4. Valid repositories are added automatically; non-repository folders are skipped

**Method 2: Menu**

1. Select **File > Add Repository**
2. Browse to a folder containing a Git repository (must have a `.git` subfolder)
3. The repository is added to the list and its status is refreshed

### Removing Repositories

1. Select a repository in the list
2. Select **File > Remove Selected**
3. Confirm the removal

Note: This only removes the repository from the list - it does not delete any files.

### Refreshing Status

Select **File > Refresh Status** (or press **F5**) to update the branch and status information for all repositories. This operation:

- Runs `git fetch` to check for remote updates
- Runs `git status` to detect local modifications
- Updates the display accordingly

### Committing and Pushing

1. Tick the checkboxes next to the repositories you want to update
2. Use the quick selection buttons if needed:
   - **Select Modified** - Selects only repositories with local changes
   - **Select All** - Selects all repositories
   - **Select None** - Clears all selections
3. Enter your commit message in the text field
4. Click **Commit & Push Selected**
5. Confirm the operation
6. Monitor progress in the log panel

The application performs the following Git commands for each selected repository:

```
git add -A
git commit -m "Your message"
git push
```

**Automatic Version Tagging (Delphi Projects):**

If the repository contains a Delphi project file (`.dproj`) with version information, GitBatchCommit will automatically:

1. Extract the `FileVersion` from the `.dproj` file (e.g., `1.0.1.25`)
2. Create an annotated Git tag with `v` prefix (e.g., `v1.0.1.25`)
3. Push the tag to the remote repository

Tags are only created if they don't already exist. This means:
- First commit with version `1.0.1.25` → creates tag `v1.0.1.25`
- Subsequent commits with same version → no new tag (already exists)
- Commit after incrementing version to `1.0.1.26` → creates tag `v1.0.1.26`

The tags appear in your repository's **Tags** or **Releases** section on GitHub/Codeberg.

### Handling Pull Required Status

Repositories flagged as **Pull Required** can be updated in several ways:

**Single Repository (Right-Click):**

1. Right-click on a repository with **Pull Required** status
2. Select **Pull**
3. Confirm the operation
4. The repository status will be refreshed after the pull completes

**Multiple Repositories (Pull Selected Button):**

1. Tick the checkboxes next to the repositories you want to pull
2. Click **Pull Selected** in the toolbar
3. Review the warning about local files being modified
4. Review the preview of files that will change
5. Confirm to proceed - backup branches are created automatically
6. All selected repositories will be pulled and their status refreshed

**Pull Safeguards:**

The Pull operation includes multiple safety features to protect your local code:

- **Warning Dialog** - Clear warning that local files may be modified
- **Change Preview** - Shows exactly which files will be modified before pulling
- **Automatic Backup** - Creates a timestamped backup branch (e.g., `backup-2026-01-15-143022`) before pulling
- **Recovery Option** - If something goes wrong, reset to the backup branch with: `git reset --hard backup-YYYY-MM-DD-HHMMSS`

To delete backup branches after confirming everything is OK: `git branch -d backup-YYYY-MM-DD-HHMMSS`

### Resolving Merge Conflicts

If pulling results in merge conflicts (shown in the log), you can resolve them automatically:

1. Tick the checkboxes next to repositories with conflicts
2. Click **Resolve Conflicts** in the toolbar
3. Confirm the operation
4. All conflicts are resolved by keeping your local versions
5. The resolution is committed and pushed automatically

This is a "keep local" strategy - your local file versions take precedence over remote changes. Use this when you want to ensure your local code is preserved.

### Push Only

For repositories where you have committed changes locally but haven't pushed them yet (branch is "ahead" of remote):

1. Tick the checkboxes next to the repositories you want to push
2. Click **Push Only** in the toolbar
3. Confirm the operation
4. Changes are pushed without creating a new commit

This is useful when:
- You've already committed manually in another Git client
- You resolved conflicts and just need to push the result
- Your local branch is ahead of remote and needs syncing

### Force Push

When your local code is the "source of truth" and you need to overwrite the remote:

1. Tick the checkboxes next to the repositories you want to force push
2. Click **Force Push** in the toolbar
3. Read the warning carefully - remote history will be overwritten
4. Confirm twice (two confirmation dialogs for safety)
5. Remote repositories are updated to match your local code exactly

**When to use Force Push:**
- Your local code is the definitive version and remote has diverged
- Push fails because remote is "ahead" but you don't want to pull those changes
- You want to ensure remote exactly matches your local state

**Warning:** Force push overwrites remote history. Any commits on the remote that are not in your local repository will be permanently lost. Use with caution.

### Creating a New Codeberg Repository

GitBatchCommit can initialize a local folder as a Git repository, create a corresponding repository on Codeberg, and push the initial commit - all in one operation.

**First-time Setup:**

1. Select **Codeberg > Settings**
2. Enter your Codeberg username
3. Enter a personal access token (generate at codeberg.org/user/settings/applications)
4. Click **OK** - credentials are saved for future use

**Creating a Repository:**

1. Select **Codeberg > Initialize & Push to Codeberg**
2. Select the folder you want to initialize
3. Enter the repository name (pre-filled from folder name)
4. Optionally add a description
5. Choose whether the repository should be private
6. Confirm the operation

The application will:
- Initialize a Git repository in the folder
- Create the repository on Codeberg
- Add the remote origin
- Commit all files
- Push to Codeberg
- Add the repository to your managed list

### Creating a New GitHub Repository

GitBatchCommit can also initialize a local folder and push to GitHub.

**First-time Setup:**

1. Select **GitHub > Settings**
2. Enter your GitHub username
3. Enter a personal access token (generate at github.com/settings/tokens with `repo` scope)
4. Click **OK** - credentials are saved for future use

**Creating a Repository:**

1. Select **GitHub > Initialize & Push to GitHub**
2. Select the folder you want to initialize
3. Enter the repository name (pre-filled from folder name)
4. Optionally add a description
5. Choose whether the repository should be private
6. Confirm the operation

The process is identical to Codeberg - the application initializes the repository, creates it on GitHub, and pushes the initial commit.

### Migrating a Repository Between Codeberg and GitHub

GitBatchCommit can move a repository's remote from one host to the other in a single operation. This works in both directions (Codeberg → GitHub and GitHub → Codeberg).

**Steps:**

1. Select the repository in the list
2. Choose **Codeberg > Migrate Selected Repository to Codeberg...** or **GitHub > Migrate Selected Repository to GitHub...** depending on the destination
3. Confirm/adjust the target repository name, description, and visibility in the dialog
4. Review the confirmation summary and click **Yes**

**What happens:**

- The target repository is created on the destination host using your configured credentials
- The existing `origin` remote is renamed to a provider-named alias (`codeberg` or `github`) so the old URL is preserved locally and can be restored if needed
- `origin` is repointed to the new host
- `git push -u origin --all` pushes every branch to the new host and sets upstream tracking
- `git push origin --tags` pushes every tag

**Important:**

- The old remote repository is **not** deleted. Once you have confirmed the migration succeeded, remove it manually via the web interface on the source host.
- Target-host credentials must be configured first (File > Settings for Codeberg/GitHub). If missing, the settings dialog opens automatically.
- If a remote named `codeberg` or `github` already exists locally, it is removed first so the rename can proceed.

### Changing Repository Visibility

You can change the visibility of GitHub and Codeberg repositories directly from the application:

1. Right-click on a repository in the list
2. Select **Set Public** or **Set Private**
3. Confirm the operation

**Requirements:**
- The repository must be hosted on GitHub or Codeberg
- You must have the appropriate credentials configured
- You must have permission to modify the repository settings

### Editing .gitignore

You can view and edit a repository's .gitignore file directly from the application:

1. Right-click on a repository in the list
2. Select **Edit .gitignore...**
3. If no .gitignore file exists, you'll be prompted to create one
4. The file opens in your system's default text editor

### Shift-Click Selection

To quickly check or uncheck multiple consecutive repositories:

1. Click on a repository to set the anchor point
2. Hold **Shift** and click on another repository
3. All repositories between the two clicks will be toggled (if anchor was unchecked, all become checked; if anchor was checked, all become unchecked)

### Configuring Settings

Select **File > Settings** to configure:

- **Git Client Path** - Full path to your external Git client executable (e.g., `C:\Program Files\Fork\Fork.exe`)
- **File Pattern** - Optional pattern for staging files (e.g., `*.pas`). Leave empty to stage all files. Shell metacharacters are rejected for safety.
- **delphi-indexer.exe Path** - Optional path to delphi-indexer.exe for automatic symbol reindexing after commits (auto-detected if not configured)

These settings are saved to the configuration file and persist between sessions.

#### delphi-lookup Integration

GitBatchCommit includes optional integration with [delphi-lookup](https://github.com/JavierusTk/delphi-lookup), a high-performance Delphi symbol search tool. When enabled, GitBatchCommit automatically triggers incremental reindexing of committed repositories, keeping your symbol database up-to-date.

**How it works:**

1. After successfully pushing changes (Commit & Push, Push Only, Force Push, or Resolve Conflicts), GitBatchCommit checks if the repository path matches (or is a subdirectory of) any delphi-lookup indexed directories
2. If a match is found, incremental reindexing runs in the background (non-blocking, typically 100-500ms)
3. The parent indexed directory gets reindexed - no unnecessary processing of other indexed directories

**Example:** If you have `E:\DBiWorkflow Development v 5` indexed and commit to `E:\DBiWorkflow Development v 5\DBiFoneology`, the entire `E:\DBiWorkflow Development v 5` directory is reindexed (including DBiFoneology's changes). Other indexed directories are skipped.

**Confirmation:** When reindexing is triggered, you'll see log messages:
```
Triggering delphi-lookup reindex: E:\DBiWorkflow Development v 5
delphi-lookup reindex completed successfully
```

If reindexing fails, you'll see:
```
Triggering delphi-lookup reindex: E:\DBiWorkflow Development v 5
delphi-lookup reindex FAILED
Error: [error details from delphi-indexer]
```

**Setup:**

- **Automatic Detection**: GitBatchCommit automatically finds delphi-indexer.exe if:
  - It's in your system PATH environment variable, or
  - It's installed at the default location: `D:\delphi-lookup\delphi-indexer.exe`
  - The discovered path is saved to configuration for faster future lookups

- **Manual Configuration**: If auto-detection fails, configure the path via File > Settings:
  1. Select **File > Settings**
  2. When prompted "Configure delphi-indexer.exe path?", click **Yes**
  3. Browse to your delphi-indexer.exe location
  4. Click **OK** to save

**Requirements:**

- delphi-lookup installed (from https://github.com/JavierusTk/delphi-lookup)
- Repository must be configured as an indexed directory in delphi-lookup

**Note:** If delphi-indexer.exe is not found, GitBatchCommit silently skips reindexing - all other functionality works normally. The integration is completely optional and non-intrusive.

**Attribution:** delphi-lookup integration uses [delphi-indexer](https://github.com/JavierusTk/delphi-lookup) by JavierusTk for symbol indexing.

### Using Commit Message History

The application remembers your last 20 commit messages:

1. Click the dropdown button (▼) next to the commit message field
2. Select a previous message from the list
3. The message is inserted into the commit field

Messages are automatically added to history when you successfully commit and push.

### Using Commit Details

For more detailed commit messages, you can add a description below the summary line:

1. Enter your summary in the main commit message field
2. Click the **...** button to reveal the details panel
3. Enter your detailed description in the memo field
4. Click **Commit & Push Selected**

The commit message will be formatted as:

```
Summary line

Detailed description explaining the changes,
which can span multiple lines.
```

After a successful commit, the details panel is automatically cleared and hidden.

### Using Commit Message Templates

Create reusable commit message templates for common operations:

**Managing Templates:**

1. Select **File > Templates...**
2. Use **Add...** to create a new template
3. Use **Edit...** to modify an existing template
4. Use **Delete** to remove a template
5. Click **OK** to save changes

**Using Templates:**

1. Click the templates dropdown button (▽) next to the commit message field (second button)
2. Select a template from the list
3. The template text is inserted into the commit field

Templates are saved to the configuration file and persist between sessions.

### Using Repository Groups

Organise your repositories into groups for easier management:

**Assigning a Group:**

1. Tick the checkboxes next to the repositories you want to group
2. Right-click on the list
3. Select **Set Group**
4. If no groups exist yet, you'll be prompted to enter a new group name
5. If groups exist, choose from the submenu:
   - Select an existing group name
   - Select **New Group...** to create a new group
   - Select **(Clear Group)** to remove the group assignment

The group is applied to all checked repositories.

**Filtering by Group:**

1. Use the **Group** dropdown in the toolbar
2. Select a group name to show only repositories in that group
3. Select **(All Groups)** to show all repositories

Groups are saved to the configuration file and persist between sessions.

### Opening Repositories Externally

Right-click on a repository to access quick actions:

- **Open in Explorer** - Opens the repository folder in Windows Explorer
- **Open in Git Client** - Opens the repository in your configured Git client (requires Git Client Path in Settings)
- **Pull** - Pulls changes from the remote repository

### Getting Help

- Press **F1** or select **Help > Help Contents** to open the README.md documentation
- Select **Help > About** to view version information and application details

## Configuration

Repository paths and credentials are stored in a JSON file located at:

```
%USERPROFILE%\GitBatchCommit\repositories.json
```

The file is created automatically when you first add a repository or configure credentials.

**Note:** Access tokens for Codeberg and GitHub are stored in plain text in this file. Ensure appropriate file system permissions if security is a concern.

## Project Structure

| File | Description |
|------|-------------|
| `GitBatchCommit.dpr` | Main project file |
| `MainFrm.pas` | Main form unit - UI and user interaction |
| `MainFrm.dfm` | Main form design file |
| `uGitRepoManager.pas` | Git repository manager class - handles all Git, Codeberg, and GitHub operations |
| `uCodebergDialog.pas` | Dialog for entering new repository details |
| `uCodebergSettings.pas` | Dialog for configuring Codeberg credentials |
| `uGitHubSettings.pas` | Dialog for configuring GitHub credentials |
| `uTemplateSettings.pas` | Dialog for managing commit message templates |

## Limitations

- Windows only (uses Windows API for process creation)
- Requires Git to be installed and in the system PATH
- Merge conflict resolution uses "keep local" strategy only - for complex merges, use an external Git client
- Single commit message for all repositories (by design)
- Cannot delete remote repositories - must be done manually via GitHub/Codeberg web interface

## Future Enhancements

Potential features for future versions:

- Support for additional Git hosting providers (GitLab, Bitbucket)

## Licence

This project is provided as-is for personal use only.

## Version History

### 1.5.0

- Added **delphi-lookup Integration** - automatically triggers incremental reindexing after commits
  - Auto-detects delphi-indexer.exe from PATH or default location
  - Reindexes parent indexed directory when committing to exact match or subdirectory
  - Captures output and reports success/failure with error details in log
  - 30-second timeout with automatic termination if indexing hangs
  - Manual path configuration via File > Settings if auto-detection fails
  - Path verification with automatic fallback if configured path becomes invalid
  - Completely optional - gracefully skips if delphi-indexer.exe not found
- Attribution: Integration uses [delphi-indexer](https://github.com/JavierusTk/delphi-lookup) by JavierusTk

### 1.4.0

- Added Version column to repository list - displays version extracted from Delphi `.dproj` files
- Searches repository root and all subdirectories for `.dproj` files
- Added automatic version tagging for Delphi projects - creates Git tags (e.g., `v3.9.1.719`) on commit
- Tags are automatically pushed to remote (GitHub/Codeberg) and appear in Releases section
- Added **Pull Selected** button - pull changes for multiple repositories at once
- Added **Resolve Conflicts** button - resolve merge conflicts by keeping local versions
- Added **Push Only** button - push without committing (for repos that are ahead of remote)
- Added **Force Push** button - overwrite remote with local code (with double confirmation)
- Added **Pull Safeguards** to protect local code:
  - Warning dialog about local files being modified
  - Preview of incoming changes before pulling
  - Automatic backup branch creation before any pull
- Added Ctrl+A support in log panel to select all text

### 1.3.0

- Added commit message templates - create and manage reusable commit messages via File > Templates
- Added commit details panel - click "..." to add detailed description (standard Git format)
- Added repository groups - organise repositories into groups for filtering
- Added Group filter dropdown in toolbar
- Added Set Group context menu item
- Fixed shift-click range selection for checking/unchecking repositories

### 1.2.0

- Added parallel status refresh - repositories are now checked concurrently for faster performance
- UI remains responsive during status refresh operations
- Optimized git command execution (reduced redundant calls)
- Real-time list updates as each repository status completes

### 1.1.0

- Added colour-coded status indicators (green=Clean, yellow=Modified, orange=Pull Required, red=Error)
- Added context menu options: Open in Explorer, Open in Git Client, Pull
- Added commit message history (up to 20 messages, accessible via dropdown)
- Added Settings dialog for Git client path and file pattern filtering
- Added file pattern filtering for selective staging

### 1.0.0

- Initial release

---
*Version: 1.0 – 31 December 2025 09:00*
*Version: 1.1 – 31 December 2025 09:30*
*Version: 1.2 – 1 January 2026 14:40*
*Version: 1.3 – 1 January 2026 15:00*
*Version: 1.4 – 15 January 2026*
*Version: 1.5 – 26 January 2026*
*Version: 1.5.1 – 28 July 2026*
