# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [semver](https://semver.org/).

## [0.1.1] — 2026-08-04

### Fixed

- `claude-waker list | head` no longer prints `printf: write error: Broken
  pipe`. Trapping SIGPIPE was not enough — bash's `printf` builtin reports the
  EPIPE itself before the trap runs — so output now goes through a small
  wrapper that exits quietly when the reader closes the pipe.

## [0.1.0] — 2026-08-04

First release. Grew out of a hardcoded `for i in {1..16}` shell loop that sent
`continue` to any iTerm2 session named `dev3` every 45 minutes.

### Added

- `claude-waker run` — the wake loop, with `--count`, `--every`, `--jitter`,
  `--delay`, `--at`, `--until` and `--deadline`.
- Interactive menu when run bare on a terminal, with a live session picker and a
  "show equivalent command" option that prints the flags for the current screen.
- Live countdown with single-key control while waiting: `s` send now, `p` pause,
  `+`/`-` shift by five minutes, `q` quit.
- Targeting by substring, exact name, glob, regex, session id or tty, plus
  `--all`, `--exclude`, `--first`, `--require-match` and `--max-targets`.
- `--if-idle` and `--if-prompt` guards, backed by iTerm2's `is processing` and
  `is at shell prompt`.
- `list`, `status`, `config` and `install-plugin` subcommands.
- Config file at `~/.config/claude-waker/config` with `[profile:name]` sections.
  Parsed against a whitelist — never sourced or evaluated.
- `--dry-run`, `--log`, `--notify`, `--print-cmd`.
- Man page, bash and zsh completions, Homebrew formula, `install.sh`, and an
  iTerm2 Scripts-menu entry.
- 133 tests that run without iTerm2 by putting a fake `osascript` on `PATH`.

### Fixed relative to the original script

- The original looped 16 times but only slept while `i < 8`, so iterations 8–16
  fired back to back. Sends are now evenly spaced, with no trailing sleep after
  the last one. `--legacy-timing` reproduces the old shape, and both schedules
  are pinned by tests.
- The message is passed to AppleScript as an argument instead of being spliced
  into the script text, so a quote in the message can no longer break out of it.
- iTerm2 is no longer launched as a side effect of `tell application "iTerm"`.
  If it is not running the tool says so and exits 3.
- Ctrl-C restores the cursor and reports how many wakes were delivered.
- `--jitter` draws from `/dev/urandom` rather than `$RANDOM`. Because the jitter
  is computed inside a command substitution and bash re-seeds `$RANDOM`
  identically in every subshell forked from the same parent state, a
  `$RANDOM`-based version returned the same offset on every wake — a constant
  shift rather than jitter.
- `-c/--config` and `-p/--profile` with no value spun `parse_args` forever:
  `shift 2` is a no-op when a single argument remains, so the loop never made
  progress. Both now report a usage error, and the parser fails loudly rather
  than hanging if any future branch consumes nothing.
- `--legacy-timing --forever` is rejected. Legacy timing derives its sleep
  cutoff from half the count, so a count of 0 meant "never sleep" and the loop
  ran flat out.
- `--until`/`--deadline` are checked before sleeping, not only before sending.
  Previously `--deadline 2s --every 45m` slept the full 45 minutes before
  noticing it should have stopped.
