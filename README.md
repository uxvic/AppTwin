# AppTwin

Run any Mac app twice, signed into two different accounts — like Samsung's
"Dual Messenger" / App Cloner, but for macOS.

The motivating case: a personal Claude **and** a work Claude open at the same
time, instead of logging out of one to use the other. AppTwin clones the app
into its own isolated profile so each copy has its own login, settings, and
data. It works for any app, not just Claude.

## Download & install

1. Download the latest **AppTwin-x.y.z.dmg** from the
   [Releases page](https://github.com/uxvic/AppTwin/releases/latest).
2. Open the DMG and drag **AppTwin** to **Applications**.
3. First launch only: **right-click AppTwin → Open → Open**. (AppTwin isn't
   notarized by Apple yet, so macOS shows a one-time warning. After the first
   open it launches normally.)

AppTwin keeps itself up to date automatically (see *Updates* below) — you only
do this download once.

## How it works

A "second account" is really a **second data directory**. Mac apps keep their
login and settings outside the app bundle (`~/Library/Application Support`,
`~/Library/Preferences`, the Keychain). Point a clone at its own data directory
and it gets its own account. AppTwin picks the right technique per app:

| App type | Strategy | What you get |
|----------|----------|--------------|
| **Electron / Chromium** (Claude, Slack, Discord, VS Code, Chrome…) | **Launcher** | A new app that starts the original with its own profile. The original is never modified, so it survives updates. ✅ rock-solid |
| **Electron without integrity checks** | **Full clone** | A full copy with its own name, icon and Dock identity, plus an isolated profile. |
| **Native apps** (non-sandboxed) | **Native rewrite** | A copy with a new bundle id. Best-effort: data separates for apps that key storage off the bundle id. |
| **Sandboxed / Mac App Store apps** | **Unsupported** | Blocked by macOS — use a separate macOS user account or the app's own multi-account feature. |

Click **+**, pick an app, name the clone, **Create**. The clone lands in
`~/Applications/AppTwin/` and shows up in Spotlight, Launchpad, and the menu-bar
quick-launcher.

## Updates

AppTwin uses [Sparkle](https://sparkle-project.org). On launch it checks
`appcast.xml` in this repo; when a newer version is published it offers
**"A new version is available."** You can also trigger a check from the menu bar
or **AppTwin ▸ Check for Updates…**. Updates are verified with an EdDSA
signature before installing.

## Building from source

Requires Xcode / Swift 6 (macOS 13+).

```sh
./build.sh                 # universal AppTwin.app, ad-hoc signed, copied to dist/
open dist/AppTwin.app
```

The same engine is scriptable via `--cli` (`inspect`, `create`, `launch`,
`list`, `delete`, `resync`) — see `Sources/AppTwin/CLIRunner.swift`.

## Releasing a new version (maintainer)

```sh
./release.sh 1.1.0 --dry-run   # build DMG + zip + appcast locally, publish nothing
./release.sh 1.1.0             # build, publish a GitHub release, push appcast
```

`release.sh` builds a universal signed app, packages a DMG (download) + zip
(Sparkle), signs the update with the EdDSA key in your **login Keychain**,
regenerates `appcast.xml`, creates the GitHub release with `gh`, and pushes the
appcast. Existing users are offered the update within a day (or immediately via
Check for Updates).

> The EdDSA **private** key lives in your login Keychain and is never committed.
> Don't lose it — it's what proves an update is genuinely from you. Back it up
> with the Sparkle `generate_keys -x` export if you'll release from another Mac.

## Honest limitations

- **Modern Electron apps (Claude, etc.) can't get a separate Dock *icon* while
  running.** They enforce integrity checks that make a re-signed copy crash, so
  AppTwin uses Launcher mode — separate account and separate Launchpad entry,
  but the running window keeps the original icon. macOS/Electron limitation.
- **Native cloning is best-effort** — apps that hardcode their storage path
  still share data with the original.
- **Sandboxed / Mac App Store apps can't be cloned.** Use a separate macOS user.
- **Not notarized yet** — downloaders bypass a one-time Gatekeeper warning.
  Upgrading to a notarized build (Apple Developer ID) is a drop-in change later.
- **This doesn't bypass server-side limits** — per-account device/session caps
  and an app's terms of service still apply. AppTwin only separates local data.
