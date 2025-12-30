# GitBatchCommit

A Delphi VCL application for committing and pushing changes to multiple Git repositories simultaneously with a single commit message.

## Overview

GitBatchCommit simplifies the workflow of updating multiple projects when a shared library or component is modified. Rather than opening each repository individually in a Git client, this tool allows you to select multiple repositories, enter a single commit message, and push all changes in one operation.

## Features

- **Repository Management** - Add and remove Git repositories from a persistent list
- **Drag and Drop** - Drag repository folders from Windows Explorer directly onto the application
- **Status Detection** - Automatically detects repository status:
  - **Clean** - No local changes, up to date with remote
  - **Modified** - Local uncommitted changes present (modified, staged, untracked, or deleted files)
  - **Pull Required** - Remote has updates that need pulling
  - **Error** - Repository not accessible or not a valid Git repo

  Status is determined by running `git status --porcelain`. Any output indicates modifications.
- **Branch Display** - Shows the current branch for each repository
- **Batch Operations** - Commit and push to multiple repositories with one click
- **Quick Selection** - Buttons to select all, none, or only modified repositories
- **Column Sorting** - Click any column header to sort; click again to reverse order
- **Status Filtering** - Filter dropdown to show only repositories with specific status
- **Operation Log** - Detailed log of all Git operations performed

## Requirements

- Delphi 12 or higher
- Git installed and available in system PATH
- Windows operating system

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

**Method 2: Browse**

1. Click **Add Repository**
2. Browse to a folder containing a Git repository (must have a `.git` subfolder)
3. The repository is added to the list and its status is refreshed

### Removing Repositories

1. Select a repository in the list
2. Click **Remove Selected**
3. Confirm the removal

Note: This only removes the repository from the list - it does not delete any files.

### Refreshing Status

Click **Refresh Status** to update the branch and status information for all repositories. This operation:

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

Repositories flagged as **Pull Required** should be updated manually using your preferred Git client (e.g., Fork) before committing new changes. This prevents potential merge conflicts and ensures you're working with the latest code.

## Configuration

Repository paths are stored in a JSON file located at:

```
%USERPROFILE%\GitBatchCommit\repositories.json
```

The file is created automatically when you first add a repository.

## Project Structure

| File | Description |
|------|-------------|
| `GitBatchCommit.dpr` | Main project file |
| `MainFrm.pas` | Main form unit - UI and user interaction |
| `MainFrm.dfm` | Main form design file |
| `uGitRepoManager.pas` | Git repository manager class - handles all Git operations |

## Limitations

- Windows only (uses Windows API for process creation)
- Requires Git to be installed and in the system PATH
- Does not handle merge conflicts - repositories requiring a pull should be handled manually
- Single commit message for all repositories (by design)

## Future Enhancements

Potential features for future versions:

- Colour-coded status indicators in the list
- Context menu to open repository in external Git client
- File pattern filtering (e.g., only stage `*.pas` files)
- Parallel status refresh for improved performance
- Commit message history/templates
- Pull operation for clean repositories

## Licence

This project is provided as-is for personal and commercial use.

## Version History

### 1.3.0

- **Column Sorting:** Click column headers to sort by Name, Path, Branch, or Status
- **Sort Indicators:** Visual arrows show current sort column and direction
- **Status Filter:** Dropdown to filter list by status (All, Clean, Modified, Pull Required, Error)

### 1.2.0

- **Drag and Drop:** Added support for dragging repository folders from Windows Explorer onto the application
- **Multi-select:** Multiple folders can be dropped at once; invalid folders are automatically skipped

### 1.1.0

- **Security:** Fixed command injection vulnerability in commit messages (now uses temp file)
- **Reliability:** Git commands now check exit codes to properly detect success/failure
- **Encoding:** Fixed UTF-8 handling for Git output (supports non-ASCII characters)
- **Robustness:** Added 60-second timeout to prevent hanging on unresponsive Git operations
- **Error Handling:** Added proper error handling for file and JSON operations
- **Persistence:** Selection state now saved and restored between sessions
- **UI:** Fixed log scroll behaviour to reliably scroll to end

### 1.0.0

- Initial release
- Basic repository management
- Status detection with pull required flag
- Batch commit and push functionality

---
*Version: 1.0 – 31 December 2025 05:15*
*Version: 1.1 – 31 December 2025 05:30 – Renamed uMain to MainFrm*
*Version: 1.2 – 31 December 2025 06:21 – Added v1.1.0 security and reliability fixes*
*Version: 1.3 – 31 December 2025 06:31 – Added v1.2.0 drag-and-drop support*
*Version: 1.4 – 31 December 2025 06:40 – Added v1.3.0 column sorting and status filtering*
*Version: 1.5 – 31 December 2025 06:41 – Documented status detection criteria*
