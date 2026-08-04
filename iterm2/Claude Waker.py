#!/usr/bin/env python3
"""Claude Waker — iTerm2 Scripts-menu entry.

Opens a new iTerm2 window and starts the claude-waker interactive menu in it.

Install with `claude-waker install-plugin`, or copy this file to
    ~/Library/Application Support/iTerm2/Scripts/
then enable Settings > General > Magic > Enable Python API and restart iTerm2.
"""

import iterm2

WAKER = "claude-waker"


async def main(connection):
    app = await iterm2.async_get_app(connection)

    window = await iterm2.Window.async_create(connection)
    if window is None:
        # No profile available to open a window with; fall back to the
        # frontmost one so the menu still has somewhere to run.
        window = app.current_terminal_window
    if window is None:
        return

    session = window.current_tab.current_session
    await session.async_send_text(WAKER + " menu\n")


iterm2.run_until_complete(main)
