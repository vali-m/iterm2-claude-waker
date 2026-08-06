#!/usr/bin/env bash
#
# claude-waker test suite. Plain bash, no bats required.
#   ./test/run.sh            run everything
#   ./test/run.sh duration   run tests whose name matches "duration"

# File-wide, and deliberate:
#   SC2329  test_* / assert_* are dispatched indirectly via run_test
#   SC2034  OPT_* globals are set for the sourced claude-waker to read
#   SC2015  `cond && ok || no` is the intended assertion idiom here
#   SC2016  literal $(...) in single quotes is exactly what the quoting tests check
# shellcheck disable=SC2329,SC2034,SC2015,SC2016

set -uo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$TEST_DIR/.." && pwd)
WAKER="$ROOT/bin/claude-waker"

FILTER="${1:-}"
PASS=0
FAIL=0
FAILED_NAMES=""

FS=$'\037'
RS=$'\036'

# A fake session table: id, name, tty, busy, at-prompt
mk_sessions() {
  printf '%s' \
    "id-1${FS}⠐ dev3${FS}/dev/ttys001${FS}true${FS}false${RS}" \
    "id-2${FS}✳ dev4${FS}/dev/ttys003${FS}false${FS}false${RS}" \
    "id-3${FS}~ (-zsh)${FS}/dev/ttys004${FS}false${FS}true${RS}" \
    "id-4${FS}DEV3-upper${FS}/dev/ttys005${FS}false${FS}false${RS}"
}

setup_env() {
  SANDBOX=$(mktemp -d)
  BIN="$SANDBOX/bin"
  mkdir -p "$BIN"
  ln -sf "$TEST_DIR/fake-osascript" "$BIN/osascript"
  ln -sf "$TEST_DIR/fake-ps" "$BIN/ps"
  chmod +x "$TEST_DIR/fake-osascript" "$TEST_DIR/fake-ps"
  export PATH="$BIN:$PATH"
  export CW_TEST_SELF_TTY="??"
  export CW_TEST_SESSIONS="$(mk_sessions)"
  export CW_TEST_LOG="$SANDBOX/sends.log"
  export CW_TEST_SEND_MAP=""
  export XDG_STATE_HOME="$SANDBOX/state"
  export XDG_CONFIG_HOME="$SANDBOX/config"
  : >"$CW_TEST_LOG"
}

teardown_env() {
  [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

it() {
  CURRENT="$1"
}

ok() {
  PASS=$(( PASS + 1 ))
  printf '  \033[32m✓\033[0m %s\n' "$CURRENT"
}

no() {
  FAIL=$(( FAIL + 1 ))
  FAILED_NAMES="$FAILED_NAMES\n    - $CURRENT: $1"
  printf '  \033[31m✗\033[0m %s\n      %s\n' "$CURRENT" "$1"
}

assert_eq() {
  if [ "$1" = "$2" ]; then ok; else no "expected [$2] got [$1]"; fi
}

assert_contains() {
  case "$1" in
    *"$2"*) ok ;;
    *) no "expected output to contain [$2], got: $(printf '%s' "$1" | head -c 300)" ;;
  esac
}

# Runs a command and checks its exit status. Must be used instead of
# `cmd; it "..."; assert_eq "$?"` — `it` resets $? to 0.
assert_exit() {
  local want="$1"; shift
  local got
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then ok; else no "expected exit $want, got $got"; fi
}

assert_not_contains() {
  case "$1" in
    *"$2"*) no "expected output NOT to contain [$2]" ;;
    *) ok ;;
  esac
}

run_test() {
  local name="$1"; shift
  if [ -n "$FILTER" ]; then
    case "$name" in *"$FILTER"*) ;; *) return 0 ;; esac
  fi
  printf '\n\033[1m%s\033[0m\n' "$name"
  setup_env
  "$@"
  teardown_env
}

# Run the CLI with test-safe defaults.
waker() {
  "$WAKER" --no-config --no-color "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Pure helper tests (source the script without running it)
# ---------------------------------------------------------------------------

test_durations() {
  # shellcheck disable=SC1090
  CLAUDE_WAKER_LIB_ONLY=1 . "$WAKER"

  it "parse_duration: plain seconds";        assert_eq "$(parse_duration 2700)" "2700"
  it "parse_duration: leading zero";         assert_eq "$(parse_duration 0090)" "90"
  it "parse_duration: 90s";                  assert_eq "$(parse_duration 90s)" "90"
  it "parse_duration: 45m";                  assert_eq "$(parse_duration 45m)" "2700"
  it "parse_duration: 2h";                   assert_eq "$(parse_duration 2h)" "7200"
  it "parse_duration: 1h30m";                assert_eq "$(parse_duration 1h30m)" "5400"
  it "parse_duration: 1d2h3m4s";             assert_eq "$(parse_duration 1d2h3m4s)" "93784"
  it "parse_duration: rejects garbage";      parse_duration "abc" >/dev/null 2>&1 && no "accepted 'abc'" || ok
  it "parse_duration: rejects empty";        parse_duration "" >/dev/null 2>&1 && no "accepted empty" || ok
  it "parse_duration: rejects 45x";          parse_duration "45x" >/dev/null 2>&1 && no "accepted '45x'" || ok
  it "parse_duration: rejects bare unit";    parse_duration "m" >/dev/null 2>&1 && no "accepted 'm'" || ok

  it "fmt_duration: 40500 -> 11h15m";        assert_eq "$(fmt_duration 40500)" "11h15m"
  it "fmt_duration: 2700 -> 45m";            assert_eq "$(fmt_duration 2700)" "45m"
  it "fmt_duration: 0 -> 0s";                assert_eq "$(fmt_duration 0)" "0s"
  it "fmt_duration: 90 -> 1m30s";            assert_eq "$(fmt_duration 90)" "1m30s"

  it "fmt_clock: 2678 -> 44:38";             assert_eq "$(fmt_clock 2678)" "44:38"
  it "fmt_clock: 3725 -> 1:02:05";           assert_eq "$(fmt_clock 3725)" "1:02:05"
  it "fmt_clock: 5 -> 0:05";                 assert_eq "$(fmt_clock 5)" "0:05"

  it "seconds_until_clock: rejects 25:00";   seconds_until_clock "25:00" >/dev/null 2>&1 && no "accepted 25:00" || ok
  it "seconds_until_clock: rejects 12:60";   seconds_until_clock "12:60" >/dev/null 2>&1 && no "accepted 12:60" || ok
  it "seconds_until_clock: rejects words";   seconds_until_clock "noon"  >/dev/null 2>&1 && no "accepted noon"  || ok
  it "seconds_until_clock: within a day"
  local secs; secs=$(seconds_until_clock "23:59")
  if [ "$secs" -gt 0 ] && [ "$secs" -le 86400 ]; then ok; else no "got $secs"; fi
}

test_jitter() {
  # shellcheck disable=SC1090
  CLAUDE_WAKER_LIB_ONLY=1 . "$WAKER"

  OPT_JITTER=""
  it "jitter: off is a no-op";               assert_eq "$(apply_jitter 600)" "600"

  # Regression: apply_jitter runs inside a command substitution, and bash
  # re-seeds $RANDOM identically per subshell, so a $RANDOM-based
  # implementation returned the same number on every single wake.
  OPT_JITTER="25%"
  local vals n_uniq i
  vals=""
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    vals="$vals$(apply_jitter 600)
"
  done
  n_uniq=$(printf '%s' "$vals" | sort -u | grep -c .)
  it "jitter: varies between calls"
  if [ "$n_uniq" -gt 1 ]; then ok; else no "all 12 draws identical ($(printf '%s' "$vals" | head -1))"; fi

  it "jitter: stays within +/- 25%"
  local out_of_range=0 v
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    { [ "$v" -lt 450 ] || [ "$v" -gt 750 ]; } && out_of_range=1
  done <<EOF
$vals
EOF
  if [ "$out_of_range" -eq 0 ]; then ok; else no "a draw fell outside 450..750"; fi

  OPT_JITTER="1m"
  it "jitter: absolute duration varies"
  vals=""
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    vals="$vals$(apply_jitter 600)
"
  done
  n_uniq=$(printf '%s' "$vals" | sort -u | grep -c .)
  if [ "$n_uniq" -gt 1 ]; then ok; else no "all 12 draws identical"; fi

  it "rand_below: stays in range"
  local bad=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    v=$(rand_below 10)
    { [ "$v" -lt 0 ] || [ "$v" -gt 9 ]; } && bad=1
  done
  if [ "$bad" -eq 0 ]; then ok; else no "rand_below 10 returned out of range"; fi

  it "rand_below: n=0 is safe";              assert_eq "$(rand_below 0)" "0"
  OPT_JITTER=""
}

test_matching() {
  # shellcheck disable=SC1090
  CLAUDE_WAKER_LIB_ONLY=1 . "$WAKER"

  OPT_MATCH_MODE="contains"; OPT_IGNORE_CASE=0
  it "contains: matches substring";     name_matches "⠐ dev3" "dev3" && ok || no "should match"
  it "contains: rejects non-substring"; name_matches "⠐ dev4" "dev3" && no "should not match" || ok
  it "contains: case sensitive";        name_matches "DEV3" "dev3" && no "should not match" || ok

  OPT_IGNORE_CASE=1
  it "contains: --ignore-case";         name_matches "DEV3" "dev3" && ok || no "should match"
  OPT_IGNORE_CASE=0

  OPT_MATCH_MODE="exact"
  it "exact: matches whole name";       name_matches "dev3" "dev3" && ok || no "should match"
  it "exact: rejects substring";        name_matches "⠐ dev3" "dev3" && no "should not match" || ok

  OPT_MATCH_MODE="glob"
  it "glob: '*dev?' matches";           name_matches "⠐ dev3" '*dev?' && ok || no "should match"
  it "glob: 'dev*' rejects prefixed";   name_matches "⠐ dev3" 'dev*' && no "should not match" || ok

  OPT_MATCH_MODE="regex"
  it "regex: 'dev[0-9]' matches";       name_matches "⠐ dev3" 'dev[0-9]' && ok || no "should match"
  it "regex: 'dev[0-9]$' anchors";      name_matches "dev3x" 'dev[0-9]$' && no "should not match" || ok
}

test_config() {
  # shellcheck disable=SC1090
  CLAUDE_WAKER_LIB_ONLY=1 . "$WAKER"

  local cfg="$SANDBOX/config"
  cat >"$cfg" <<'EOF'
# a comment
match = staging
text  = "keep going"
count = 4
every = 10m

[profile:night]
every = 2h
text  = zzz
EOF

  OPT_CONFIG="$cfg"; OPT_NO_CONFIG=0; OPT_PROFILE=""
  MATCHES=(); OPT_TEXT=""; OPT_COUNT=""; OPT_EVERY=""
  load_config
  it "config: reads match";              assert_eq "${MATCHES[0]:-}" "staging"
  it "config: strips quotes";            assert_eq "$OPT_TEXT" "keep going"
  it "config: reads count";              assert_eq "$OPT_COUNT" "4"
  it "config: ignores profile sections"; assert_eq "$OPT_EVERY" "10m"

  # A profile layers on top of the global keys rather than replacing them.
  OPT_PROFILE="night"; OPT_EVERY=""; OPT_TEXT=""; MATCHES=()
  load_config
  it "config: profile overrides every";  assert_eq "$OPT_EVERY" "2h"
  it "config: profile overrides text";   assert_eq "$OPT_TEXT" "zzz"
  it "config: profile inherits global";  assert_eq "${MATCHES[0]:-}" "staging"

  it "config: never evaluates values"
  cat >"$cfg" <<'EOF'
text = $(touch /tmp/cw-pwned-$$)
EOF
  OPT_PROFILE=""; OPT_TEXT=""
  load_config
  assert_eq "$OPT_TEXT" '$(touch /tmp/cw-pwned-$$)'
}

# ---------------------------------------------------------------------------
# End-to-end tests through the fake osascript
# ---------------------------------------------------------------------------

test_list_and_status() {
  local out
  out=$(waker list)
  it "list: shows all sessions";     assert_contains "$out" "dev3"
  it "list: shows busy state";       assert_contains "$out" "busy"
  it "list: shows prompt state";     assert_contains "$out" "prompt"
  it "list: strips /dev/ from tty";  assert_contains "$out" "ttys001"

  out=$(waker status -m dev3)
  it "status: matches only dev3";    assert_contains "$out" "Matches (1)"
  it "status: names the session";    assert_contains "$out" "⠐ dev3"
  it "status: sends nothing";        assert_eq "$(wc -l <"$CW_TEST_LOG" | tr -d ' ')" "0"

  out=$(waker status -m dev3 -i)
  it "status: -i widens the match";  assert_contains "$out" "Matches (2)"

  out=$(waker status -m nope)
  it "status: reports no match";     assert_contains "$out" "No sessions match"

  it "status: --require-match exits 4"
  assert_exit 4 waker status -m nope --require-match

  out=$(waker status -a)
  it "status: --all matches all 4";  assert_contains "$out" "Matches (4)"

  out=$(waker status -a --exclude zsh)
  it "status: --exclude drops one";  assert_contains "$out" "Matches (3)"

  out=$(waker status -a --first)
  it "status: --first keeps one";    assert_contains "$out" "Matches (1)"
}

test_schedule() {
  local out sends started elapsed

  # dry-run is gone, so the schedule shape is measured for real: N sends land in
  # the fake osascript log and N-1 one-second waits show up as elapsed time.
  : >"$CW_TEST_LOG"
  started=$(date +%s)
  waker run -m dev3 -n 5 -e 1s --no-countdown >/dev/null
  elapsed=$(( $(date +%s) - started ))
  sends=$(grep -c '^SEND' "$CW_TEST_LOG")
  it "schedule: 5 sends";                  assert_eq "$sends" "5"
  it "schedule: 4 waits (no trailing)"
  if [ "$elapsed" -ge 3 ] && [ "$elapsed" -le 9 ]; then ok; else no "elapsed ${elapsed}s, expected ~4"; fi

  : >"$CW_TEST_LOG"
  started=$(date +%s)
  waker run -m dev3 -n 5 -e 1s --legacy-timing --no-countdown >/dev/null
  elapsed=$(( $(date +%s) - started ))
  sends=$(grep -c '^SEND' "$CW_TEST_LOG")
  it "legacy: still 5 sends";              assert_eq "$sends" "5"
  it "legacy: only 1 wait (the old bug)"
  if [ "$elapsed" -le 3 ]; then ok; else no "elapsed ${elapsed}s, expected ~1"; fi

  : >"$CW_TEST_LOG"
  started=$(date +%s)
  waker run -m dev3 -n 1 -e 45m --no-countdown >/dev/null
  elapsed=$(( $(date +%s) - started ))
  it "schedule: count=1 never waits"
  if [ "$elapsed" -le 2 ]; then ok; else no "elapsed ${elapsed}s, expected 0"; fi

  out=$(waker run -m dev3 -n 1 -e 1s --no-countdown --delay 1s)
  it "schedule: --delay waits first";      assert_contains "$out" "First send at"

  it "schedule: --dry-run is gone";        assert_exit 2 waker run -m dev3 --dry-run
  it "schedule: -d is gone";               assert_exit 2 waker run -m dev3 -d
}

test_sending() {
  local log

  waker run -m dev3 -n 1 --no-countdown >/dev/null
  log=$(cat "$CW_TEST_LOG")
  it "send: reaches osascript";       assert_contains "$log" "SEND"
  it "send: default message";         assert_contains "$log" "msg=continue"
  it "send: newline on by default";   assert_contains "$log" "nl=1"
  it "send: targets only dev3";       assert_contains "$log" "ids=id-1"

  : >"$CW_TEST_LOG"
  waker run -m dev3 -n 1 --no-newline --esc-first --if-idle --no-countdown >/dev/null
  log=$(cat "$CW_TEST_LOG")
  it "send: --no-newline";            assert_contains "$log" "nl=0"
  it "send: --esc-first";             assert_contains "$log" "esc=1"
  it "send: --if-idle";               assert_contains "$log" "idle=1"

  : >"$CW_TEST_LOG"
  waker run -a -n 1 --no-countdown >/dev/null
  log=$(cat "$CW_TEST_LOG")
  it "send: --all targets everything"; assert_contains "$log" "ids=id-1 id-2 id-3 id-4"

  : >"$CW_TEST_LOG"
  local out
  out=$(waker run --session-id id-2 -n 1 --no-countdown)
  log=$(cat "$CW_TEST_LOG")
  it "send: --session-id is exact";   assert_contains "$log" "ids=id-2"

  : >"$CW_TEST_LOG"
  CW_TEST_SEND_MAP="id-1=skipped-busy" out=$(waker run -m dev3 -n 1 --if-idle --no-countdown)
  it "send: reports skipped-busy";    assert_contains "$out" "busy, skipped"

  : >"$CW_TEST_LOG"
  out=$(waker run -m nope -n 1 --no-countdown)
  it "send: warns when nothing matches"; assert_contains "$out" "no sessions match"
  it "send: nothing sent on no match";   assert_eq "$(wc -l <"$CW_TEST_LOG" | tr -d ' ')" "0"

  : >"$CW_TEST_LOG"
  it "send: --max-targets refuses"
  assert_exit 4 waker run -a -n 1 --max-targets 2 --no-countdown

  : >"$CW_TEST_LOG"
  waker run -m dev3 -n 4 -e 1s --no-countdown -t one -t two >/dev/null
  log=$(cat "$CW_TEST_LOG")
  it "send: rotates messages";        assert_eq "$(printf '%s\n' "$log" | grep -c 'msg=one')" "2"
}

test_quoting() {
  local nasty log
  nasty='he said "hi" \back $(whoami) `id` '"'"'q'"'"''

  : >"$CW_TEST_LOG"
  waker run -m dev3 -n 1 --no-countdown -t "$nasty" >/dev/null
  log=$(grep '^SEND' "$CW_TEST_LOG" | head -1)
  it "quoting: message survives verbatim"
  case "$log" in
    *"msg=$nasty"*) ok ;;
    *) no "mangled: $log" ;;
  esac

  it "quoting: no shell expansion of \$(whoami)"
  assert_not_contains "$log" "$(whoami)@"

  it "quoting: no command substitution ran"
  case "$log" in
    *'$(whoami)'*) ok ;;
    *) no "\$(whoami) was expanded: $log" ;;
  esac
}

test_cli_surface() {
  local out

  out=$(waker --version)
  it "cli: --version";               assert_contains "$out" "claude-waker"

  out=$(waker --help)
  it "cli: --help lists commands";   assert_contains "$out" "install-plugin"
  it "cli: --help drops the dev3 default"
  assert_not_contains "$out" "default: dev3"
  it "cli: --help explains picking"; assert_contains "$out" "asks you to pick"
  it "cli: --help documents forget"; assert_contains "$out" "forget"

  it "cli: unknown flag exits 2";   assert_exit 2 waker --bogus-flag
  it "cli: bad match-mode exits 2"; assert_exit 2 waker run -M sideways
  it "cli: bad duration exits 2";   assert_exit 2 waker run -e nonsense
  it "cli: negative count exits 2"; assert_exit 2 waker run -n -3
  it "cli: bad jitter exits 2";     assert_exit 2 waker run --jitter blah
  it "cli: missing value exits 2";  assert_exit 2 waker run -m
  it "cli: --help exits 0";         assert_exit 0 waker --help

  out=$(waker run -m dev3 -n 16 -e 45m --print-cmd)
  it "cli: --print-cmd round-trips"; assert_eq "$out" "claude-waker run -m dev3 -t continue -n 16 -e 45m"

  out=$(waker run -a --if-idle -t 'go go' --print-cmd)
  it "cli: --print-cmd quotes text"; assert_contains "$out" "-t 'go go'"
  it "cli: --print-cmd keeps --all"; assert_contains "$out" "--all"

  out=$(waker config)
  it "cli: config shows path";       assert_contains "$out" "claude-waker/config"
}

test_iterm_absent() {
  export CW_TEST_RUNNING="false"

  local out
  out=$(waker run -m dev3 -n 1 2>&1)
  it "guard: exits 3 when iTerm2 is down"
  assert_exit 3 waker run -m dev3 -n 1

  it "guard: explains why";           assert_contains "$out" "not running"
  it "guard: will not launch iTerm2"; assert_contains "$out" "will not launch it"

  it "guard: list also refuses"
  assert_exit 3 waker list

  unset CW_TEST_RUNNING
}

# Run a command under a hard time limit. 142 = killed by SIGALRM.
with_timeout() {
  local secs="$1"; shift
  perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
}

assert_no_hang() {
  local secs="$1" want="$2"; shift 2
  local got
  with_timeout "$secs" "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq 142 ]; then
    no "hung (killed after ${secs}s)"
  elif [ "$got" = "$want" ]; then
    ok
  else
    no "expected exit $want, got $got"
  fi
}

test_no_hangs() {
  # Regression: -c/--config and -p/--profile used a bare `shift 2`, which is a
  # no-op when only one argument remains, so parse_args spun forever instead of
  # reporting a usage error.
  local f
  for f in -c --config -p --profile; do
    it "no-hang: '$f' with no value exits 2"
    assert_no_hang 5 2 "$WAKER" run --no-config "$f"
  done

  # Every other value-taking flag goes through need_val; check they agree.
  for f in -m --match -M --match-mode --session-id --tty --exclude --max-targets \
           -t --text --text-file -n --count -e --every --jitter --delay \
           --at --until --deadline --log; do
    it "no-hang: '$f' with no value exits 2"
    assert_no_hang 5 2 "$WAKER" run --no-config "$f"
  done

  # Regression: --legacy-timing halves the count to find its sleep cutoff, so a
  # count of 0 meant "never sleep" and the loop ran flat out.
  it "no-hang: --legacy-timing --forever is rejected"
  assert_no_hang 5 2 "$WAKER" run --no-config --legacy-timing --forever

  # Regression: the deadline was only checked before a send, so an interval
  # longer than the deadline slept the whole interval first.
  it "no-hang: --forever --deadline cuts the wait short"
  assert_no_hang 20 0 "$WAKER" run --no-config --no-color -m dev3 \
    --forever -e 45m --deadline 2s --no-countdown

  it "no-hang: --until in the past stops promptly"
  assert_no_hang 20 0 "$WAKER" run --no-config --no-color -m dev3 \
    -n 5 -e 45m --deadline 2s --no-countdown
}

test_install_plugin() {
  local home="$SANDBOX/home"
  local dest="$home/Library/Application Support/iTerm2/Scripts/Claude Waker.py"
  mkdir -p "$home"

  it "install-plugin: writes the entry"
  HOME="$home" waker install-plugin >/dev/null 2>&1
  [ -f "$dest" ] && ok || no "no file at $dest"

  it "install-plugin: uses the repo's bundled copy, not the fallback"
  if cmp -s "$ROOT/iterm2/Claude Waker.py" "$dest"; then ok; else
    no "installed copy differs from iterm2/Claude Waker.py"
  fi

  # Homebrew lays the file out as bin/../share/claude-waker/iterm2/...
  it "install-plugin: finds the Homebrew pkgshare layout"
  local prefix="$SANDBOX/brew"
  mkdir -p "$prefix/bin" "$prefix/share/claude-waker/iterm2"
  cp "$WAKER" "$prefix/bin/claude-waker"
  printf '# homebrew copy\n' > "$prefix/share/claude-waker/iterm2/Claude Waker.py"
  rm -f "$dest"
  HOME="$home" "$prefix/bin/claude-waker" --no-config --no-color install-plugin >/dev/null 2>&1
  if grep -q '# homebrew copy' "$dest" 2>/dev/null; then ok; else
    no "did not pick up the pkgshare copy"
  fi

  it "install-plugin: falls back when nothing is bundled"
  local bare="$SANDBOX/bare"
  mkdir -p "$bare/bin"
  cp "$WAKER" "$bare/bin/claude-waker"
  rm -f "$dest"
  HOME="$home" "$bare/bin/claude-waker" --no-config --no-color install-plugin >/dev/null 2>&1
  if grep -q 'iterm2.run_until_complete' "$dest" 2>/dev/null; then ok; else
    no "fallback script missing or malformed"
  fi

  it "install-plugin: fallback is valid python"
  python3 -m py_compile "$dest" 2>/dev/null && ok || no "fallback does not compile"
  rm -rf "$SANDBOX/__pycache__"
}

test_stable_pattern() {
  # shellcheck disable=SC1090
  CLAUDE_WAKER_LIB_ONLY=1 . "$WAKER"

  # Claude Code rewrites the title constantly, so a pick has to become a pattern
  # that outlives the exact name that was on screen.
  it "pattern: strips the busy spinner glyph"
  assert_eq "$(stable_pattern_from_name "⠐ dev3")" "dev3"
  it "pattern: strips the idle marker"
  assert_eq "$(stable_pattern_from_name "✳ dev4")" "dev4"
  it "pattern: strips the trailing job name"
  assert_eq "$(stable_pattern_from_name "⠂ Some long task (node)")" "Some long task"
  it "pattern: keeps a plain name"
  assert_eq "$(stable_pattern_from_name "dev3")" "dev3"
  it "pattern: keeps a leading real word"
  assert_eq "$(stable_pattern_from_name "bash (sleep)")" "bash"
  it "pattern: trims surrounding space"
  assert_eq "$(stable_pattern_from_name "  ⠋  spaced  ")" "spaced"
  it "pattern: never returns empty"
  assert_eq "$(stable_pattern_from_name "⠋")" "⠋"

  # Both title states of the same session must derive to the same pattern.
  it "pattern: busy and idle titles agree"
  assert_eq "$(stable_pattern_from_name "⠐ dev3")" "$(stable_pattern_from_name "✳ dev3")"
}

test_multi_match() {
  local out
  out=$(waker status -m dev3 -m dev4)
  it "multi-match: either pattern matches"; assert_contains "$out" "Matches (2)"
  it "multi-match: described as an or";     assert_contains "$out" 'or'

  out=$(waker run -m dev3 -m dev4 -n 1 --no-countdown --print-cmd)
  it "multi-match: --print-cmd keeps both"; assert_contains "$out" "-m dev3 -m dev4"

  : >"$CW_TEST_LOG"
  waker run -m dev3 -m zsh -n 1 --no-countdown >/dev/null
  it "multi-match: sends to both"; assert_contains "$(cat "$CW_TEST_LOG")" "ids=id-1 id-3"
}

test_no_default_target() {
  # dev3 is no longer baked in as a default.
  it "no-default: help does not promise dev3"
  assert_not_contains "$(waker --help)" "default: dev3"

  it "no-default: non-interactive run without a target exits 2"
  assert_exit 2 waker run --no-remember

  local out
  out=$(waker run --no-remember 2>&1)
  it "no-default: explains how to choose";  assert_contains "$out" "no target chosen"
  it "no-default: names the flags";         assert_contains "$out" "--match"
  it "no-default: points at the picker";    assert_contains "$out" "pick from the open sessions"

  it "no-default: nothing was sent";        assert_eq "$(wc -l <"$CW_TEST_LOG" | tr -d ' ')" "0"

  it "no-default: status with no target is not an error"
  assert_exit 0 waker status
  out=$(waker status)
  it "no-default: status says nothing chosen"; assert_contains "$out" "nothing chosen yet"
}

test_remember() {
  local home="$SANDBOX/rhome" state
  mkdir -p "$home"
  state="$home/state/claude-waker/state"

  rwaker() { HOME="$home" XDG_STATE_HOME="$home/state" "$WAKER" --no-color "$@" 2>&1; }

  it "remember: a run writes the state file"
  rwaker run -m dev4 -t "keep going" -n 2 -e 1s --no-countdown >/dev/null
  [ -f "$state" ] && ok || no "no state at $state"

  it "remember: stores the target";   assert_contains "$(cat "$state")" "match=dev4"
  it "remember: stores the message";  assert_contains "$(cat "$state")" "text=keep going"
  it "remember: stores the count";    assert_contains "$(cat "$state")" "count=2"
  it "remember: stores the interval"; assert_contains "$(cat "$state")" "every=1s"

  it "remember: a later bare run reuses it"
  : >"$CW_TEST_LOG"
  rwaker run --no-countdown >/dev/null 2>&1
  assert_contains "$(cat "$CW_TEST_LOG")" "msg=keep going"

  it "remember: reused run targets the remembered session"
  assert_contains "$(cat "$CW_TEST_LOG")" "ids=id-2"

  it "remember: flags still win over it"
  : >"$CW_TEST_LOG"
  rwaker run -m dev3 -t other -n 1 -e 1s --no-countdown >/dev/null
  assert_contains "$(cat "$CW_TEST_LOG")" "msg=other"

  it "remember: --no-remember does not overwrite"
  rwaker run -m zsh -t untracked -n 1 --no-remember --no-countdown >/dev/null 2>&1
  assert_not_contains "$(cat "$state")" "untracked"

  it "remember: config shows the state path"
  assert_contains "$(rwaker config)" "claude-waker/state"

  it "remember: forget clears it"
  rwaker forget >/dev/null
  [ -f "$state" ] && no "state still present" || ok

  it "remember: forget on a clean slate is fine"
  assert_contains "$(rwaker forget)" "Nothing remembered"

  it "remember: after forget a bare run has no target again"
  assert_exit 2 env HOME="$home" XDG_STATE_HOME="$home/state" "$WAKER" --no-color run
}

test_stale_target() {
  local home="$SANDBOX/shome" out
  mkdir -p "$home"
  swaker() { HOME="$home" XDG_STATE_HOME="$home/state" "$WAKER" --no-color "$@" 2>&1; }

  swaker run -m dev3 -n 1 -e 1s --no-countdown >/dev/null

  # The tab you remembered has since been closed.
  export CW_TEST_SESSIONS="$(printf 'id-9%ssomething-else%s/dev/ttys009%sfalse%sfalse%s' \
    "$FS" "$FS" "$FS" "$FS" "$RS")"

  out=$(printf 'q\n' | swaker menu)
  it "stale: says the remembered session is gone"
  assert_contains "$out" "no longer matches any open session"
  it "stale: re-opens the picker";  assert_contains "$out" "Pick the session(s) to wake"

  # An explicit --match that matches nothing is the user's business.
  out=$(printf 'q\n' | swaker menu -m nomatch)
  it "stale: an explicit --match is not second-guessed"
  assert_not_contains "$out" "no longer matches any open session"

  # A remembered target that still matches goes straight through.
  export CW_TEST_SESSIONS="$(mk_sessions)"
  out=$(printf 'q\n' | swaker menu)
  it "stale: a live remembered target is left alone"
  assert_not_contains "$out" "Pick the session(s) to wake"

  export CW_TEST_SESSIONS="$(mk_sessions)"
}

# The session claude-waker itself runs in is never offered and never targeted:
# writing into it types the message at the waker, not at Claude.
test_self_session() {
  local out
  export CW_TEST_SELF_TTY="ttys001"     # "⠐ dev3", the first fake session

  out=$(printf 'q\n' | waker menu)
  it "self: not offered in the picker";  assert_not_contains "$out" "⠐ dev3"
  it "self: the others still are";       assert_contains "$out" "✳ dev4"

  it "self: --all skips it"
  : >"$CW_TEST_LOG"
  waker run --all -n 1 -e 1s --no-countdown --no-remember >/dev/null
  assert_contains "$(cat "$CW_TEST_LOG")" "ids=id-2 id-3 id-4"

  it "self: a pattern that would match it skips it"
  : >"$CW_TEST_LOG"
  export CW_TEST_SELF_TTY="ttys005"     # "DEV3-upper"
  waker run -i -m dev3 -n 1 -e 1s --no-countdown --no-remember >/dev/null
  assert_contains "$(cat "$CW_TEST_LOG")" "ids=id-1"

  # Naming it outright is a deliberate act, so it is honoured.
  it "self: --tty targets it anyway"
  : >"$CW_TEST_LOG"
  export CW_TEST_SELF_TTY="ttys001"
  waker run --tty /dev/ttys001 -n 1 -e 1s --no-countdown --no-remember >/dev/null
  assert_contains "$(cat "$CW_TEST_LOG")" "ids=id-1"

  it "self: --session-id targets it anyway"
  : >"$CW_TEST_LOG"
  waker run --session-id id-1 -n 1 -e 1s --no-countdown --no-remember >/dev/null
  assert_contains "$(cat "$CW_TEST_LOG")" "ids=id-1"

  it "self: list still shows it, marked"
  assert_contains "$(waker list)" "(this session"

  it "self: off a terminal nothing is excluded"
  : >"$CW_TEST_LOG"
  export CW_TEST_SELF_TTY="??"
  waker run --all -n 1 -e 1s --no-countdown --no-remember >/dev/null
  assert_contains "$(cat "$CW_TEST_LOG")" "ids=id-1 id-2 id-3 id-4"

  it "self: when it is the only session, say so"
  export CW_TEST_SELF_TTY="ttys001"
  export CW_TEST_SESSIONS="$(printf '%s' \
    "id-1${FS}⠐ dev3${FS}/dev/ttys001${FS}true${FS}false${RS}")"
  out=$(printf 'q\n' | waker menu)
  assert_contains "$out" "only session open is this one"

  export CW_TEST_SESSIONS="$(mk_sessions)"
  export CW_TEST_SELF_TTY="??"
}

test_picker() {
  local out
  # 1) ✳ dev4   2) ~ (-zsh)   3) DEV3-upper   -- ⠐ dev3 is this session
  export CW_TEST_SELF_TTY="ttys001"

  out=$(printf '1\n\nq\n' | waker menu)
  it "picker: a number picks the session shown at that number"
  assert_contains "$out" 'contains "dev4"'

  # Typing numbers at the confirm prompt means "those ones after all" -- it
  # used to be taken as a literal pattern named "2,3".
  out=$(printf '1\n2,3\nq\n' | waker menu)
  it "picker: numbers at the confirm prompt re-pick"
  assert_contains "$out" 'contains "(-zsh)" or "DEV3-upper"'
  it "picker: and are not taken as a pattern"
  assert_not_contains "$out" 'contains "2,3"'

  out=$(printf '1\nall\nq\n' | waker menu)
  it "picker: \"all\" at the confirm prompt works too"
  assert_contains "$out" "all sessions"

  out=$(printf '1\ndev\nq\n' | waker menu)
  it "picker: a real pattern at the confirm prompt is still a pattern"
  assert_contains "$out" 'contains "dev"'

  out=$(printf '1-3\nq\n' | waker menu)
  it "picker: a range picks each session in it"
  assert_contains "$out" 'contains "dev4" or "(-zsh)" or "DEV3-upper"'

  out=$(printf '1-99\nq\n' | waker menu)
  it "picker: a range past the end stops at the end"
  assert_contains "$out" 'contains "dev4" or "(-zsh)" or "DEV3-upper"'

  out=$(printf '1,1\n\nq\n' | waker menu)
  it "picker: the same session twice is one pattern"
  assert_contains "$out" 'contains "dev4"'
  it "picker: not two"
  assert_not_contains "$out" 'or "dev4"'

  out=$(printf '9\n1\n\nq\n' | waker menu)
  it "picker: an out-of-range number is reported"
  assert_contains "$out" "out-of-range selection: 9"
  it "picker: and it asks again rather than giving up"
  assert_contains "$out" 'contains "dev4"'

  out=$(printf 'my-tab\nq\n' | waker menu)
  it "picker: text is a pattern"; assert_contains "$out" 'contains "my-tab"'

  out=$(printf 'all\nq\n' | waker menu)
  it "picker: \"all\" targets everything";  assert_contains "$out" "all sessions"
  it "picker: without also carrying a pattern"
  assert_not_contains "$(printf 'all\n6\n\nq\n' | waker menu)" '-m all'

  export CW_TEST_SELF_TTY="??"
}

test_flag_order() {
  local out
  out=$(waker list)
  it "order: subcommand after global flags"; assert_contains "$out" "dev3"

  out=$("$WAKER" list --no-config --no-color 2>&1)
  it "order: subcommand before flags";       assert_contains "$out" "dev3"

  # A subcommand word used as an option value must not be eaten as the command.
  : >"$CW_TEST_LOG"
  waker run -m dev3 -n 1 --no-countdown -t status >/dev/null
  it "order: '-t status' stays a message";   assert_contains "$(cat "$CW_TEST_LOG")" "msg=status"

  out=$(waker run -m list -n 1 --no-countdown --print-cmd)
  it "order: '-m list' stays a pattern";     assert_contains "$out" "-m list"
}

# ---------------------------------------------------------------------------

printf '\033[1mclaude-waker test suite\033[0m\n'
printf 'bash %s\n' "${BASH_VERSION}"

run_test "durations"        test_durations
run_test "jitter"           test_jitter
run_test "stable pattern"   test_stable_pattern
run_test "matching"         test_matching
run_test "config"           test_config
run_test "list and status"  test_list_and_status
run_test "schedule"         test_schedule
run_test "sending"          test_sending
run_test "quoting"          test_quoting
run_test "cli surface"      test_cli_surface
run_test "multi match"      test_multi_match
run_test "no default target" test_no_default_target
run_test "remember"         test_remember
run_test "stale target"     test_stale_target
run_test "self session"     test_self_session
run_test "picker"           test_picker
run_test "no hangs"         test_no_hangs
run_test "install plugin"   test_install_plugin
run_test "flag order"       test_flag_order
run_test "iterm absent"     test_iterm_absent

printf '\n────────────────────────────────\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m%d passed\033[0m, 0 failed\n' "$PASS"
  exit 0
else
  printf '\033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n' "$PASS" "$FAIL"
  printf '%b\n' "$FAILED_NAMES"
  exit 1
fi
