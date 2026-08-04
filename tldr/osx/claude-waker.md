# claude-waker

> Keep Claude Code sessions in iTerm2 awake by typing a message into them on a schedule.
> More information: <https://github.com/vali-m/iterm2-claude-waker>.

- Start the interactive menu:

`claude-waker`

- List the current iTerm2 sessions and their state:

`claude-waker list`

- Show which sessions would be targeted, without sending anything:

`claude-waker status --match {{dev3}}`

- Send "continue" to matching sessions a number of times at a fixed interval:

`claude-waker run --match {{dev3}} --count {{16}} --every {{45m}}`

- Send a custom message to every session that is not mid-answer, indefinitely:

`claude-waker run --all --if-idle --forever --text "{{keep going}}"`

- Rehearse a run without sending anything:

`claude-waker run --match {{dev3}} --dry-run`

- Print the equivalent command line for the current settings:

`claude-waker run --match {{dev3}} --count {{16}} --print-cmd`

- Add a "Claude Waker" entry to iTerm2's Scripts menu:

`claude-waker install-plugin`
