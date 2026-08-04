# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [semver](https://semver.org/).

## [0.2.0] — 2026-08-04

Breaking: `--dry-run` is gone and `dev3` is no longer a default target.

### Removed

- **`-d` / `--dry-run`.** It was a second way to ask a question `status` and
  `list` already answered, and its output ("would send", "would wait") read
  enough like a real run to be genuinely confusing. Use
  `claude-waker status` to see exactly what would be targeted without sending.
- The **dry run** entry in the menu; "show equivalent command" is now option 6.

### Changed

- **No default target.** `dev3` was one person's tab name baked into the tool.
  With no target specified, `claude-waker` now lists the sessions open in
  iTerm2 and asks which to wake. Without a terminal to ask on — cron, a pipe,
  `--yes` — a run with no target is an error rather than a guess.
- **A pick becomes a pattern, not a name or an id.** Claude Code rewrites the
  session title constantly and ids die with the tab, so the picker derives a
  stable substring: `⠐ dev3` → `dev3`, `⠂ Refactor the parser (node)` →
  `Refactor the parser`. The derived pattern is shown and can be edited.
- **`-m` / `--match` is repeatable**; a session matches if any pattern does.

### Added

- **Choices are remembered.** Target, message, count, interval and guards are
  saved to `${XDG_STATE_HOME:-~/.local/state}/claude-waker/state` and reused, so
  a bare `claude-waker` resumes the previous setup.
- `claude-waker forget` to clear the remembered choices, and `--no-remember` to
  run without saving over them.
- `claude-waker config` now shows the state path alongside the config path.

### Fixed

- Command-line values now **replace** remembered and configured ones instead of
  being ORed with them. `-m dev3` after a run against `dev4` targeted both, and
  `-t other` after a remembered message rotated between the two.

## [0.1.2] — 2026-08-04

### Fixed

- `install-plugin` now finds the bundled `Claude Waker.py` when installed via
  Homebrew. It only looked for `bin/../iterm2/`, which exists in a git checkout
  but not in a Homebrew prefix, where the formula puts the file under
  `share/claude-waker/`. Brew users silently got the smaller inline fallback
  instead of the maintained copy.

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
