# Changelog

All notable changes to the GitBatchCommit test suite are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- (2026-11-10) **Status text keeps " - fetch failed" across a local-only refresh** — `Test.GitRepoManager.Git.pas`.  `ForcePushIsRefusedWhileTheLastFetchFailed` also asserts the text, so the row cannot read Clean while the push is refused.
- (2026-11-10) **First DUnitX suite for the engine unit, `uGitRepoManager.pas`** — `GitBatchCommitTests.dpr`, `GitBatchCommitTests.dproj`, `Test.Support.pas`, `Test.GitRepoManager.Pure.pas`, `Test.GitRepoManager.Config.pas`, `Test.GitRepoManager.Git.pas`, `Test.GitRepoManager.Parallel.pas`, `README.md`.  Covers repository names, paths and staging patterns, secret redaction, lenient UTF-8 decoding, the child-process runner ( exit code, both streams, a command that cannot start, the timeout ), configuration safety ( round trip, the unreadable file, the access token at rest ), the managed lists, status detection against local bare "origins", the build-artefact filter, the project version, Commit & Push, push, force push with its lease, pull, backup branch, the incoming preview, conflict resolution and the parallel refresh.  Every test works in its own temporary folder with a private Git configuration; none reads the user's configuration or repositories, and none contacts the network.  **Why:** the unit had just been reworked heavily and had no tests at all.
