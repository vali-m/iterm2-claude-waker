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

Run it with no arguments and you get a menu:

```
╭─ claude-waker 0.1.0 ─────────────────────────────╮
  Target     contains "dev3"  → 1 session
               ⠐ dev3
  Message    "continue"
  Repeats    16
  Interval   45m  ≈ 11h15m
  Guards     —
╰──────────────────────────────────────────────────╯

 1) target   2) message   3) repeats   4) interval
 5) guards   6) dry run   7) show equivalent command
 s) start    q) quit
```

Option `7` prints the exact command line for whatever is on screen, so you can graduate
from the menu to a script or a cron entry without reading the flag list.

While it's running: `s` sends now, `p` pauses, `+`/`-` shift the next wake by 5 minutes,
`q` quits. Ctrl-C is clean.

### Common commands

```sh
claude-waker                                  # menu
claude-waker run                              # dev3, "continue", 16 times, every 45m
claude-waker list                             # what sessions exist right now
claude-waker status -m dev3                   # what would be targeted, send nothing
claude-waker run -m dev3 -n 16 -e 45m         # explicit
claude-waker run -a --if-idle                 # every session that isn't mid-answer
claude-waker run -m dev --forever -e 30m --jitter 10%
claude-waker run -m dev3 --dry-run            # rehearse
```

Anything you can do with flags you can do without them, and vice versa. The subcommand
can go before or after the flags.

## Targeting

`--match` does a substring match on the session name, which is why the default `dev3`
keeps working even though Claude Code rewrites the title constantly (`⠐ dev3`, `✳ dev3`).

| Flag | What it does |
|---|---|
| `-m, --match PATTERN` | substring of the session name (default `dev3`) |
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

## Message

| Flag | What it does |
|---|---|
| `-t, --text STR` | what to type (default `continue`). Repeat it to rotate between messages |
| `--text-file FILE` | read the message from a file |
| `--no-newline` | type it but don't press Enter |
| `--esc-first` | send Escape first, to clear a half-typed line |

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
./test/run.sh              # 133 tests, no iTerm2 required
./test/run.sh duration     # just the ones matching "duration"
shellcheck bin/claude-waker
```

Tests put a fake `osascript` on `PATH`, so the whole send path — targeting, guards,
quoting, schedule shape — runs without touching a real terminal.

## Licence

MIT
