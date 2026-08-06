# claude-waker

Keep Claude Code sessions in iTerm2 awake on a schedule.

Claude Code stops and waits. If you want it to keep going while you're away, something
has to type `continue` for you. This does that — on a timer, into whichever iTerm2
sessions you point it at.

```
$ claude-waker run -m dev3 -n 16 -e 45m
[1/16] 14:24:00  sending "continue"
  → ⠐ dev3
       next 15:09:00 · 44:38 left   [s send now · p pause · +/- 5m · q quit]
```

No dependencies. One bash script and `osascript`. macOS only, because iTerm2 is.

## Install

```sh
brew install vali-m/tap/claude-waker
```

Homebrew is rolling out [tap trust](https://docs.brew.sh/Tap-Trust) for third-party
taps. If it refuses to load the formula, trust the tap once:

```sh
brew trust --tap vali-m/tap
```

or

```sh
curl -fsSL https://raw.githubusercontent.com/vali-m/iterm2-claude-waker/main/install.sh | bash
```

or just drop `bin/claude-waker` anywhere on your `PATH` — it's a single self-contained file.

## Use it

Run it with no arguments and it asks which session to wake, listing what is actually
open in iTerm2:

```
Pick the session(s) to wake

   1) busy      ⠐ dev3
   2) idle      ✳ dev4
   3) prompt    ~ (-zsh)
   4) busy      ⠂ Refactor the parser (node)

  Enter numbers (2, 1,3, 1-4), a pattern, "all", or blank to cancel.
> 1

  will match any session whose name contains dev3
  Enter to accept, or type a pattern or other numbers: [dev3]
```

The session you launched `claude-waker` from is not on the list, and no pattern will
ever match it: writing into it would type the message at the waker rather than at
Claude. `--session-id` or `--tty` still target it if you really mean to.

Then the menu:

```
╭─ claude-waker 0.2.2 ───────────────────────────╮
  Target     contains "dev3"  → 1 session
               ⠐ dev3
  Message    "continue"
  Repeats    16
  Interval   45m  ≈ 11h15m
  Guards     —
╰────────────────────────────────────────────────╯

 1) target   2) message   3) repeats   4) interval
 5) guards   6) show equivalent command
 s) start    q) quit
```

Option `6` prints the exact command line for whatever is on screen, so you can graduate
from the menu to a script or a cron entry without reading the flag list.

Next time it remembers, so a bare `claude-waker` comes straight back with the same
target, message and interval ready to go.

While it's running: `s` sends now, `p` pauses, `+`/`-` shift the next wake by 5 minutes,
`q` quits. Ctrl-C is clean.

### Common commands

```sh
claude-waker                                  # pick a session, then the menu
claude-waker run                              # repeat whatever you last did
claude-waker list                             # what sessions exist right now
claude-waker status -m dev3                   # what would be targeted, send nothing
claude-waker run -m dev3 -n 16 -e 45m         # explicit
claude-waker run -m dev3 -m dev4              # either session
claude-waker run -a --if-idle                 # every session that isn't mid-answer
claude-waker run -m dev --forever -e 30m --jitter 10%
claude-waker forget                           # drop the remembered choices
```

Anything you can do with flags you can do without them, and vice versa. The subcommand
can go before or after the flags.

## Targeting

There is no default target. With nothing specified, `claude-waker` shows you the
sessions currently open in iTerm2 and asks which to wake — so it never guesses, and
never types into a session you did not choose.

When you pick one it does **not** store the exact title or the session id. Claude Code
rewrites the title constantly (`⠐ dev3` while working, `✳ dev3` while waiting) and ids
die with the tab. It derives a stable substring instead — `⠐ dev3` becomes `dev3`,
`⠂ Refactor the parser (node)` becomes `Refactor the parser` — shows you what it worked
out, and lets you edit it before going ahead.

| Flag | What it does |
|---|---|
| `-m, --match PATTERN` | substring of the session name. Repeatable — any may match |
| `-M, --match-mode MODE` | `contains` (default), `exact`, `glob`, `regex` |
| `-i, --ignore-case` | case-insensitive |
| `--session-id UUID` | one exact session; repeatable. Survives renames |
| `--tty DEV` | target by tty; repeatable |
| `-a, --all` | every session |
| `--exclude PATTERN` | skip matches containing PATTERN; repeatable |
| `--first` | only the first match |
| `--require-match` | exit non-zero instead of warning when nothing matches |
| `--max-targets N` | refuse to run if more than N sessions match |

`claude-waker list` shows ids with `-v`.

Without a terminal to ask on — a cron entry, a pipe, or `--yes` — a run with no target
is an error rather than a guess:

```
$ claude-waker run </dev/null
claude-waker: no target chosen. Pass --match PATTERN, --session-id ID, --tty DEV or --all,
claude-waker: or run claude-waker on a terminal to pick from the open sessions.
```

## Message

| Flag | What it does |
|---|---|
| `-t, --text STR` | what to type (default `continue`). Repeat it to rotate between messages |
| `--text-file FILE` | read the message from a file |
| `--no-newline` | type it but don't press Enter |
| `--esc-first` | send Escape first, to clear a half-typed line |

There is no rehearsal mode. `claude-waker status` already shows exactly which sessions
would be hit without sending anything, and `list` shows what is open — a separate
dry-run flag was just a second way to ask the same question.

The message is handed to AppleScript as an argument, never spliced into the script
source, so quotes, backslashes and `$(...)` all arrive verbatim and nothing gets
evaluated on the way.

## Schedule

| Flag | What it does |
|---|---|
| `-n, --count N` | how many sends (default 16). `0` or `--forever` for no limit |
| `-e, --every DUR` | gap between sends (default `45m`) |
| `--jitter DUR\|N%` | randomise each gap by ± that much |
| `--delay DUR` | wait before the first send |
| `--at HH:MM` | first send at a wall-clock time |
| `--until HH:MM` | stop sending after this time |
| `--deadline DUR` | stop after this much elapsed time |

Durations are plain seconds (`2700`) or units: `90s`, `45m`, `1h30m`, `2d`.

There are `N-1` waits for `N` sends — nothing sleeps after the last one.

## Guards

`--if-idle` skips sessions that are streaming output at that moment. That maps onto
iTerm2's `is processing`, which is true while Claude is producing an answer and false
while it sits waiting for you. Worth knowing: a session blocked on a *silent* command —
`sleep 30`, a `read` prompt — reads as idle, because nothing is being written to the
terminal.

`--if-prompt` only sends when the session is sitting at a shell prompt. Needs
[iTerm2 shell integration](https://iterm2.com/documentation-shell-integration.html);
without it every session looks like it isn't at a prompt.

`--stop-if-gone` exits when a targeted session disappears instead of carrying on.

## Remembering

Whatever you last ran with — target, message, count, interval, guards — is written to

```
${XDG_STATE_HOME:-~/.local/state}/claude-waker/state
```

and used as the default next time, so a bare `claude-waker` picks up where you left off.

```sh
claude-waker forget              # drop it and be asked again
claude-waker run --no-remember   # run without saving over it
claude-waker config              # show both paths and what is in effect
```

A config file beats the remembered state, and flags beat both — so a hand-written config
is never quietly overwritten by whatever you last happened to do.

If the session you used last time has since been closed, `claude-waker` says so and asks
you to pick again rather than sitting on a target that matches nothing.

## Config

`~/.config/claude-waker/config`:

```ini
match = dev3
text  = continue
count = 16
every = 45m
if_idle = true

[profile:overnight]
every = 2h
count = 0
```

```sh
claude-waker run -p overnight
```

Profiles layer on top of the top-level keys. Flags beat profiles beat config beat
defaults. The file is parsed against a whitelist — never sourced, never `eval`'d — so a
config file can't run code.

## iTerm2 Scripts menu

iTerm2 has no plugin store, so the closest thing to installing this as a plugin is
putting an entry in its Scripts menu:

```sh
claude-waker install-plugin
```

Then enable **Settings → General → Magic → Enable Python API**, restart iTerm2, and
**Scripts → Claude Waker** opens a window with the menu running.

## About the original script

This started life as:

```sh
for i in {1..16}; do
  osascript -e '... if name of s contains "dev3" then tell s to write text "continue" ...'
  if [ $i -lt 8 ]; then sleep 2700; fi
done
```

That loops 16 times but only sleeps while `i < 8`, so iterations 8–16 fire back to back
with no delay — almost certainly left over from when the count was 8. `claude-waker run`
sleeps between every send. If you actually want the old behaviour, `--legacy-timing`
reproduces it exactly, and there's a test pinning both schedules.

The hardcoded `dev3` is gone too — it was one person's tab name. You pick a session once
and it is remembered, which gets you the same thing without the tool assuming anything.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | fine |
| 1 | runtime error |
| 2 | bad usage |
| 3 | iTerm2 isn't running |
| 4 | nothing matched, or a guard stopped the run |

It will not launch iTerm2 for you. If iTerm2 is closed it says so and exits 3.

## tldr page

A [tldr-pages](https://github.com/tldr-pages/tldr) page lives at
`tldr/osx/claude-waker.md`, in upstream's format and directory layout.

It is not in the upstream repo: tldr-pages requires a project to have been maintained
for at least a year unless it is notable, and this one is new. Until then, install it
into your local cache:

```sh
cp tldr/osx/claude-waker.md ~/.tldrc/tldr/pages/osx/    # tldr-c-client
```

`tldr --update` re-clones the cache and will remove it, so re-copy after updating.

## Development

```sh
./test/run.sh              # 201 tests, no iTerm2 required
./test/run.sh duration     # just the ones matching "duration"
shellcheck bin/claude-waker
```

Tests put a fake `osascript` on `PATH`, so the whole send path — targeting, guards,
quoting, schedule shape — runs without touching a real terminal.

## Licence

MIT
