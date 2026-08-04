# Releasing

## Cut a release

1. Bump `CW_VERSION` in `bin/claude-waker`, the `.TH` line in `man/claude-waker.1`,
   and the version in `Formula/claude-waker.rb`.
2. Add a `CHANGELOG.md` entry.
3. `./test/run.sh` and `shellcheck bin/claude-waker`.
4. Tag and push:

   ```sh
   git tag -a v0.2.0 -m "v0.2.0"
   git push origin v0.2.0
   ```

The release workflow checks that `CW_VERSION` matches the tag (it fails the build if
not), runs the tests, creates the GitHub release, and prints the tarball `sha256` into
the job summary.

## The Homebrew tap

The tap is a **separate repo**, `vali-m/homebrew-tap`, laid out as:

```
homebrew-tap/
└── Formula/
    └── claude-waker.rb
```

That name is what makes `brew install vali-m/tap/claude-waker` work — Homebrew expands
`vali-m/tap` to `github.com/vali-m/homebrew-tap`.

The tap now exists and carries `claude-waker`. What follows is for reference or a
rebuild.

Homebrew is rolling out [tap trust](https://docs.brew.sh/Tap-Trust); a third-party tap
reads as `Untrusted` in `brew tap-info` until the user runs `brew trust --tap vali-m/tap`.
Mention that anywhere the install command is documented.

### First-time setup

```sh
gh repo create vali-m/homebrew-tap --public --description "Homebrew formulae"
git clone https://github.com/vali-m/homebrew-tap && cd homebrew-tap
mkdir -p Formula
cp ../iterm2-claude-waker/Formula/claude-waker.rb Formula/
# set url + sha256 for the tagged release, then:
git add . && git commit -m "claude-waker <version>" && git push
```

Verify before announcing it:

```sh
brew tap vali-m/tap
brew install --build-from-source vali-m/tap/claude-waker
brew test claude-waker
brew audit --strict --online vali-m/tap/claude-waker
```

### Automating the bump

The `bump-tap` job in `.github/workflows/release.yml` opens a PR against the tap on every
release, but only if a `TAP_TOKEN` secret exists — a fine-grained PAT with
**Contents: read/write** and **Pull requests: read/write** on `vali-m/homebrew-tap`.
Add it under Settings → Secrets and variables → Actions.

Without that secret the job no-ops and you apply the two lines from the job summary by
hand.

## homebrew-core

Not yet, and not worth attempting until the project is popular. `homebrew-core` requires
a project to be *notable*: **75+ stars, 30+ forks, or 30+ watchers**. Homebrew also
[discourages authors from submitting their own work](https://docs.brew.sh/Acceptable-Formulae)
unless it is already widely used.

When that bar is cleared:

- Drop the `head` stanza and the `pkgshare.install "iterm2"` line — core prefers a
  minimal install.
- Keep `depends_on :macos`; the tool is macOS-only by nature.
- The `test do` block must work with no network and no iTerm2 running. The current one
  does: it only exercises `--version`, a usage error, and `--print-cmd`.
- Submit with `brew bump-formula-pr` rather than a hand-written PR.

## Version checklist

Files carrying the version number:

| File | Where |
|---|---|
| `bin/claude-waker` | `CW_VERSION="..."` |
| `man/claude-waker.1` | the `.TH` header |
| `Formula/claude-waker.rb` | `url` tag and `sha256` |
| `CHANGELOG.md` | new section |

CI fails the release if the script and the tag disagree, which catches the one that
matters most.

## tldr page

`tldr/osx/claude-waker.md` is kept in upstream tldr-pages format so submitting it is a
straight copy into `pages/osx/` of a tldr-pages fork.

Do not submit yet. tldr-pages requires a project to have been maintained for **at least
a year** unless the maintainers deem it notable. Revisit once the project clears that,
and re-check the examples still match the CLI first.
