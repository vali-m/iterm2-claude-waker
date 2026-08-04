# bash completion for claude-waker

_claude_waker() {
  local cur prev cmds opts modes
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  cmds="run menu list status install-plugin config forget version help"
  modes="contains exact glob regex"
  opts="--match --match-mode --ignore-case --session-id --tty --all --exclude
        --first --require-match --max-targets --text --message --text-file
        --no-newline --newline --esc-first --count --forever --every --interval
        --jitter --delay --start-in --at --until --deadline --legacy-timing
        --if-idle --if-prompt --stop-if-gone --quiet --verbose --log
        --notify --countdown --no-countdown --no-color --color --print-cmd
        --yes --no-remember --menu --config --no-config --profile --help --version"

  case "$prev" in
    -M|--match-mode)
      COMPREPLY=( $(compgen -W "$modes" -- "$cur") ); return 0 ;;
    --text-file|--log|-c|--config)
      COMPREPLY=( $(compgen -f -- "$cur") ); return 0 ;;
    -e|--every|--interval|--delay|--start-in|--deadline)
      COMPREPLY=( $(compgen -W "30s 5m 15m 30m 45m 1h 1h30m 2h" -- "$cur") ); return 0 ;;
    -n|--count)
      COMPREPLY=( $(compgen -W "1 4 8 16 32 0" -- "$cur") ); return 0 ;;
    --jitter)
      COMPREPLY=( $(compgen -W "5% 10% 25% 1m 5m" -- "$cur") ); return 0 ;;
    -m|--match|-t|--text|--message|--exclude|--session-id|--tty|-p|--profile|--max-targets|--at|--until)
      return 0 ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
  else
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
  fi
  return 0
}

complete -F _claude_waker claude-waker
