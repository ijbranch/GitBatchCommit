# Changelog

All notable changes to the GitBatchCommit test suite are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- (2026-11-19) `TTestApiRedirect`: a loopback HTTP server answers the API request with a 302 to a second one; the request must fail with 302 and a response naming the Location, and the second server must receive nothing (no token); a direct 200 remains a success carrying the token; a same-origin redirect is followed once with the same verb and the token; a second redirect is refused with a message.  Red before the fix (the cross-host redirect was followed), `test_mutate` 5 of 5 killed — `Test.GitRepoManager.Http.pas`, `GitBatchCommitTests.dpr`, `GitBatchCommitTests.dproj`
- (2026-11-10) **Status text keeps " - fetch failed" across a local-only refresh** — `Test.GitRepoManager.Git.pas`.  `ForcePushIsRefusedWhileTheLastFetchFailed` also asserts the text, so the row cannot read Clean while the push is refused.
- (2026-11-10) **First DUnitX suite for the engine unit, `uGitRepoManager.pas`** — `GitBatchCommitTests.dpr`, `GitBatchCommitTests.dproj`, `Test.Support.pas`, `Test.GitRepoManager.Pure.pas`, `Test.GitRepoManager.Config.pas`, `Test.GitRepoManager.Git.pas`, `Test.GitRepoManager.Parallel.pas`, `README.md`.  Covers repository names, paths and staging patterns, secret redaction, lenient UTF-8 decoding, the child-process runner ( exit code, both streams, a command that cannot start, the timeout ), configuration safety ( round trip, the unreadable file, the access token at rest ), the managed lists, status detection against local bare "origins", the build-artefact filter, the project version, Commit & Push, push, force push with its lease, pull, backup branch, the incoming preview, conflict resolution and the parallel refresh.  Every test works in its own temporary folder with a private Git configuration; none reads the user's configuration or repositories, and none contacts the network.  **Why:** the unit had just been reworked heavily and had no tests at all.

### Changed

- (2026-11-19) **Every test is checked for leaks under FastMM5** (Ian) — `GitBatchCommitTests.dpr`, `GitBatchCommitTests.dproj`, `Test.GitRepoManager.Parallel.pas`.  FastMM5 was already first; the runner is now `GllDUnitX.SuiteRunner.RunGllSuite` (a warm-up pass, a measured pass with a FastMM5 leak monitor on every test, a re-run of each flagged test), as in GITLAKLib and the DBiWorkflow suites, and `D:\gllDUnitX\Source\Gll` joins the unit search path.  Kept: both discovery mechanisms, `FailsOnNoAsserts`, strict strings, the `<exe>-results.xml` default and the estate exit codes (confirmed leaks now count as failures).  The first run flagged `TTestParallelRefresh`, whose `TearDown` kept the repository paths in `FRepos`; it now clears them.  137 of 137 pass with no leak.

