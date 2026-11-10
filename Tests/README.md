# GitBatchCommitTests

DUnitX suite for `..\uGitRepoManager.pas` (`TGitRepoManager` and the unit's standalone routines).  131 tests in 13 fixtures.

## Running

- Project: `GitBatchCommitTests.dproj` (Delphi 13, Win64 only).  The executable is written to `Win64\<Config>\GitBatchCommitTests.exe`.
- Registered with GITLAKMCP as the `GitBatchCommitTests` test target, so `test_run` builds and runs it.
- By hand: `Win64\Release\GitBatchCommitTests.exe`, or one test with `--run:Test.GitRepoManager.Git.TTestCommitAndPush.CommitLandsOnTheOrigin`.
- Exit code 0 = all passed; an NUnit results file `GitBatchCommitTests.exe-results.xml` is written beside the executable.
- A full run takes a minute or two: most tests start real `git.exe` processes.

`git.exe` must be on the `PATH`.  OmniThreadLibrary is not on the IDE library path, so the project names its DCU folder itself.

## Isolation

The suite never touches the real configuration, a real repository or the network.

- Every test builds its own `TGitSandbox` (`Test.Support.pas`): a unique `%TEMP%\GBCTests-<guid>` folder, removed again when the test ends.
- The manager is always created with a configuration file inside that folder, never the per-user default.
- Every repository is created there with `git init`; a local bare repository stands in for `origin`, so push, pull, fetch and the ahead and
  behind counts are tested without contacting any server.
- Each repository sets `user.name`, `user.email` and `commit.gpgsign false` locally.
- The test process points `GIT_CONFIG_GLOBAL` at a private file, sets `GIT_CONFIG_NOSYSTEM` and `GIT_CEILING_DIRECTORIES`, and clears
  `GIT_DIR`, `GIT_WORK_TREE` and `GIT_INDEX_FILE`, so the machine's own Git configuration cannot change a result.
- The arrangement steps use the sandbox's own process runner, not the product's `RunProcess`, so a defect in the product's runner cannot hide
  behind a matching defect in the arrangement.

## Coverage

| Unit | Fixture | Tests | What it proves |
|---|---|---|---|
| `Test.GitRepoManager.Pure.pas` | `TTestNamesAndPaths` | 14 | name sanitising and validation, safe file patterns, path normalising, recognising a `.git` entry |
| | `TTestTextHelpers` | 12 | masking of tokens and credentials in log text, status and provider labels, tolerant UTF-8 decoding |
| | `TTestRunProcess` | 10 | the process runner: exit code, both streams or standard output only, missing executable or folder, time-out, UTF-8, end of file on standard input |
| `Test.GitRepoManager.Config.pas` | `TTestConfigSafety` | 14 | load and save round trip, the token is never saved in clear, a corrupt or unreadable file is never lost |
| | `TTestManagedLists` | 12 | the repository list, selection, groups, snapshots, the commit-message history and the templates |
| `Test.GitRepoManager.Git.pas` | `TTestRefreshStatus` | 15 | clean, modified, push required, pull required, diverged, fetch failure, linked worktree, provider |
| | `TTestArtefactFilter` | 9 | changes that are build output only are reported clean |
| | `TTestProjectVersion` | 7 | the project version: active configuration, layering by rank, fallbacks, root before vendored project, rescan |
| | `TTestCommitAndPush` | 10 | the commit reaches the origin, refusals (not listed, behind, detached head), file patterns, a failed push, version tag |
| | `TTestRemoteOperations` | 12 | push, guarded force push (also refused after a failed fetch), fast-forward pull, backup branch, incoming changes |
| | `TTestResolveConflicts` | 6 | keep-local conflict resolution: local content and deletions kept, other files left alone, rebase refused |
| | `TTestNewRepository` | 5 | `InitialiseRepository`, `AddRemoteOrigin`, `InitialCommitAndPush` |
| `Test.GitRepoManager.Parallel.pas` | `TTestParallelRefresh` | 5 | the parallel refresh: every repository once, optional callbacks, cancellation, started from a pooled worker without deadlock |

## Known product bugs

None open.  Three were found while the suite was written and are fixed in `uGitRepoManager.pas`; the tests that found them stay as
regression tests:

- the child environment set `GIT_DIR`, `GIT_WORK_TREE` and `GIT_INDEX_FILE` to empty values, which made every Git command fail;
- `IsValidRepoName` accepted a name ending in a line feed (`TTestNamesAndPaths.NameEndingInLineFeedIsRefused`);
- an untracked build-output folder was reported Modified (`TTestArtefactFilter.UntrackedPlatformFolderIsBuildOutput`).

## Not covered

- The GitHub API routines (`CreateGitHubRepository`, `CreateAndPushRepository`, `SetRepositoryVisibility`, `DeleteRemoteRepository`,
  `MigrateRepository`, `DescribeRemoteDeleteTarget`): they need the network and a real account.
- `DeleteLocalRepository`: it sends the folder to the Recycle Bin through the shell.
- The 8 MB output truncation in the process runner: too slow for a unit suite.
- The DPAPI failure path when protecting a token, and `IsDefectException` directly.
- Private helpers are tested only through the public behaviour that uses them.

---

*Version: 1.0 – 10 November 2026 11:02*
