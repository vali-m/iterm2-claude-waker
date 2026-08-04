# Reference copy. The formula Homebrew actually installs from lives in
# https://github.com/vali-m/homebrew-tap as Formula/claude-waker.rb
#
# Keep the two in sync when releasing — see RELEASING.md.
class ClaudeWaker < Formula
  desc "Keep Claude Code sessions in iTerm2 awake on a schedule"
  homepage "https://github.com/vali-m/iterm2-claude-waker"
  url "https://github.com/vali-m/iterm2-claude-waker/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "21cab64067c26f1fc13db6b3817a4c0e47c22e9a6de8ec4f9bb11c0c48c04f25"
  license "MIT"
  head "https://github.com/vali-m/iterm2-claude-waker.git", branch: "main"

  depends_on :macos

  def install
    bin.install "bin/claude-waker"
    man1.install "man/claude-waker.1"
    bash_completion.install "completions/claude-waker.bash"
    zsh_completion.install "completions/_claude-waker"
    pkgshare.install "iterm2"
  end

  def caveats
    <<~EOS
      claude-waker drives iTerm2 through AppleScript. The first run will ask for
      permission to control iTerm2; approve it in
        System Settings > Privacy & Security > Automation.

      To add "Claude Waker" to iTerm2's Scripts menu:
        claude-waker install-plugin
      then enable iTerm2 > Settings > General > Magic > Enable Python API.
    EOS
  end

  test do
    assert_match "claude-waker #{version}", shell_output("#{bin}/claude-waker --version")

    # Usage errors are reported rather than silently accepted.
    assert_match "unknown option", shell_output("#{bin}/claude-waker --nope 2>&1", 2)

    # Durations parse and the schedule is described without touching iTerm2.
    assert_match "-e 45m", shell_output("#{bin}/claude-waker run -n 16 -e 45m --print-cmd")
  end
end
