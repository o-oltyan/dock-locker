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
- Pick the anchor display and the bypass key from the menu
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
make app       # assemble build/DockLocker.app (universal, ad-hoc signed)
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

**Rebuild caveat:** the default build is *ad-hoc signed*, and macOS ties the
Accessibility grant to the exact signature. After rebuilding you may see the
toggle still enabled in System Settings while the app silently can't create
its event tap (the menu will say "Permission stale"). Fix:

```sh
make reset-tcc     # clears the stale grant; re-grant on next launch
```

To make the grant survive rebuilds, create a self-signed code-signing
certificate in Keychain Access (Certificate Assistant → Create a Certificate →
type "Code Signing", e.g. named `DockLocker Dev`) and build with:

```sh
make install CODESIGN_IDENTITY="DockLocker Dev"
```

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
