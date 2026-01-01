# GitBatchCommit

A Delphi VCL application for committing and pushing changes to multiple Git repositories simultaneously with a single commit message.

## Overview

GitBatchCommit simplifies the workflow of updating multiple projects when a shared library or component is modified. Rather than opening each repository individually in a Git client, this tool allows you to select multiple repositories, enter a single commit message, and push all changes in one operation.

## Features

- **Repository Management** - Add and remove Git repositories from a persistent list
- **Drag and Drop** - Drag repository folders from Windows Explorer directly onto the application
- **Codeberg Integration** - Create new Codeberg repositories and push directly from the application
- **GitHub Integration** - Create new GitHub repositories and push directly from the application
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
- **Pull Operation** - Right-click to pull changes from remote for a single repository
- **Commit Message History** - Click the dropdown button next to the commit message to select from recent messages (up to 20 stored)
- **Commit Message Templates** - Define reusable commit message templates via File > Templates; select from the templates dropdown (▽) next to the commit message
- **Repository Groups** - Assign repositories to groups for easy filtering; use the Group dropdown in the toolbar to filter by group
- **File Pattern Filtering** - Optionally stage only files matching a pattern (e.g., `*.pas`) via File > Settings

## Requirements

- Delphi 10.3 Rio or higher (uses inline variable declarations)
- Git installed and available in system PATH
- Windows operating system

### Third-Party Dependencies

| Component | Description | Source |
|-----------|-------------|--------|
| FastMM5 | High-performance memory manager | https://github.com/pleriche/FastMM5 |
| Aqua Light Slate | VCL visual style (optional - falls back to default if unavailable) | Included with RAD Studio Premium Styles |

**Note:** To remove the FastMM5 dependency, remove `FastMM5` from the uses clause in `GitBatchCommit.dpr`. The project will then use Delphi's default memory manager.

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

### Handling Pull Required Status

Repositories flagged as **Pull Required** can be updated using the right-click context menu:

1. Right-click on a repository with **Pull Required** status
2. Select **Pull**
3. Confirm the operation
4. The repository status will be refreshed after the pull completes

Alternatively, use your preferred external Git client for more complex merge scenarios.

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
- **File Pattern** - Optional pattern for staging files (e.g., `*.pas`). Leave empty to stage all files.

These settings are saved to the configuration file and persist between sessions.

### Using Commit Message History

The application remembers your last 20 commit messages:

1. Click the dropdown button (▼) next to the commit message field
2. Select a previous message from the list
3. The message is inserted into the commit field

Messages are automatically added to history when you successfully commit and push.

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
- Does not handle merge conflicts - repositories requiring a pull should be handled manually
- Single commit message for all repositories (by design)
- Cannot delete remote repositories - must be done manually via GitHub/Codeberg web interface

## Future Enhancements

Potential features for future versions:

- Support for additional Git hosting providers (GitLab, Bitbucket)

## Licence

This project is provided as-is for personal use only.

## Version History

### 1.3.0

- Added commit message templates - create and manage reusable commit messages via File > Templates
- Added repository groups - organise repositories into groups for filtering
- Added Group filter dropdown in toolbar
- Added Set Group context menu item

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
