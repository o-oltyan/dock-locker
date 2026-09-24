# DockLocker

A tiny macOS menu-bar utility that keeps the Dock on the display you choose.

On multi-monitor Macs, the Dock jumps to whichever display the cursor lingers
against at the bottom edge. DockLocker prevents that: a CGEvent tap watches
mouse movement and, when the cursor touches the bottom ~3 px of any display
*other* than your chosen one, filters the events (moves are swallowed, drags
are clamped 5 px up) — so macOS never gets the sustained edge contact that
triggers Dock migration. Hold the bypass key (default: **Fn/Globe**) and the
Dock behaves normally, so you can still move it deliberately.

- Menu-bar only — no Dock icon, runs in the background (`LSUIElement`)
- **Follow the Dock** (default): the lock protects whichever display the Dock
  is currently on — move it deliberately with the bypass key and the lock
  follows it there. Or pin it to a **fixed display** instead, where the chosen
  display's own bottom edge always summons the Dock back.
- Pick the mode, display, and bypass key from the menu-bar menu or the
  **settings window** (shown when you launch DockLocker from Finder/Spotlight;
  also under **Settings…** in the menu)
- Don't like menu-bar clutter? Toggle **Show menu bar icon** off — the settings
  window stays reachable by opening the app again from Applications/Spotlight
- Optional **Start at Login** (`SMAppService`)
- Displays are remembered by hardware UUID, so the choice survives
  unplug/replug; if the chosen display is missing, DockLocker falls back to the
  main display and says so in the menu

## Install (from Releases)

1. Download `DockLocker-vX.Y.Z.zip` from the
   [Releases page](https://github.com/o-oltyan/dock-locker/releases), unzip,
   and move `DockLocker.app` to `/Applications` (or `~/Applications`).
2. First launch: macOS will block the app because it isn't notarized (there's
   no paid Apple Developer ID behind it). Open **System Settings → Privacy &
   Security**, scroll down, and click **Open Anyway**. Alternatively, from a
   terminal: `xattr -cr /Applications/DockLocker.app` and launch normally.
3. Grant the **Accessibility** permission when prompted — DockLocker needs it
   to filter mouse events. It picks the grant up automatically within seconds.
4. Click the menu-bar icon → **Lock Dock to** → pick your display.

The universal (Apple silicon + Intel) build is produced by CI from a tag; see
`.github/workflows/release.yml`.

## Build from source

```sh
make test      # unit tests (clamp-zone math, coordinate conversion, settings)
make app       # assemble build/DockLocker.app (universal; see signing below)
make run       # build + launch from build/
make install   # copy to ~/Applications and launch
make zip       # build/DockLocker.zip, the release artifact
```

Requires Xcode command line tools (Swift 6+). No third-party dependencies.

## Accessibility permission

Modifying mouse events requires the **Accessibility** permission
(System Settings → Privacy & Security → Accessibility). DockLocker prompts on
first launch and picks the permission up automatically once granted — no
relaunch needed.

DockLocker keeps checking the permission while it runs, so granting or
revoking it is picked up within a couple of seconds.

**Updates and the grant:** macOS ties the grant to the app's code signature.
Builds signed with the project's self-signed certificate share one signature
requirement, so the grant survives updates. An *ad-hoc* build (no certificate)
gets a new identity every time: after updating, the toggle in System Settings
still looks enabled but macOS no longer honours it. Turning the toggle off and
on again doesn't help, because macOS keeps the old signature requirement.
**Grant Access…** and **Reset & Re-grant…** (settings window) and their menu
counterparts clear the old entry before asking again, the same as:

```sh
make reset-tcc
```

Moving from an ad-hoc build (1.2.1 and earlier) to a certificate-signed one
needs that reset one last time. DockLocker can't tell that case apart from a
first install, so it shows **Grant Access…**, which handles both.

To sign your own builds, create the certificate once — `make` then picks it up
automatically:

```sh
scripts/make-signing-cert.sh            # adds "DockLocker Self-Signed" to your login keychain
make install
```

For release builds, run `scripts/make-signing-cert.sh --export` and store the
output as the `SIGNING_CERT_P12` repository secret, with the password as
`SIGNING_CERT_PASSWORD`.

## The Fn key on third-party keyboards

Many non-Apple keyboards handle Fn entirely in hardware, so macOS never sees
it. If holding Fn doesn't unlock the Dock, pick Control/Option/Command/Shift
under **Hold to Move Dock** instead.

## How it works

- `Sources/DockLockerCore` — pure, unit-tested logic: clamp-zone computation
  (including cut-outs where another display sits directly below, so stacked
  arrangements stay traversable), Cocoa⇄CG coordinate conversion, modifier-key
  mapping, settings.
- `Sources/DockLocker` — the AppKit shell: event tap, display tracking
  (debounced on configuration changes), status menu, login item, Accessibility
  flow.

Prior art: [DockAnchor](https://github.com/bwya77/DockAnchor) and
[docklock](https://github.com/marcusguttenplan/docklock) use the same
edge-clamping technique.

## License

[MIT](LICENSE). The app icon is generated by `scripts/make-icon.swift`.
