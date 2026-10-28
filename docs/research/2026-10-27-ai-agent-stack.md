# AI coding agent stack (2026-10-27)

Decision record for the agent tooling installed this week: Claude Code
(CLI + Desktop), OpenAI Codex CLI, T3 Code orchestrator, and the
auto-update policy around them.

## Requirements

- Latest **stable** versions only (no nightlies, nothing weeks stale).
- Declarative: everything flows through the flake, nothing imperatively
  installed.
- Auto-update where the trust model allows it.

## Decisions

### CLIs: claude-code + codex from a nixpkgs-unstable input

Stable 26.05 shipped claude-code 2.1.223 (upstream: 2.1.310) and codex
0.146.0 (upstream: 0.164.0) — weeks behind, because stable only moves on
channel bumps and AI CLIs release near-daily. A locked
`nixpkgs-unstable` input tracks upstream within days. Trust tier:
codex is compiled from source by Hydra (best case — verified a
`cache.nixos.org-1` signature on the store path); claude-code is
Anthropic's official binary hash-pinned inside nixpkgs (unfree →
`allowUnfree` hoisted to hosts/common since the home config is shared
with nixvm).

### Claude Desktop: ilqqy/claude-desktop-flake, -cowork variant

- First candidate, poeck/claude-desktop-nix-flake, was dropped: its
  hourly update bot stalled 2026-09-28 while upstream shipped a major.
- k3d3/claude-desktop-linux-flake (377 ⭐) predates the official Linux
  build — it repacks the Windows/macOS app with stubbed native modules;
  rejected as a downgrade from the real Linux .deb.
- heytcass/claude-for-linux patches the macOS DMG with WIP Cowork;
  rejected for the same reason.
- ilqqy keeps the **vendor Electron inside an FHS env** — this is what
  makes the Code tab work on NixOS (Desktop shells out to /bin/bash,
  /usr/bin/* by absolute path). app.asar is not modified. The -cowork
  variant bundles QEMU/OVMF/virtiofsd.

Host wiring (x1e): `kvm` group + `vhost_vsock` kernel module (Cowork),
gnome-keyring + `security.pam.services.sddm.enableGnomeKeyring`
(persistent sign-in; the setup previously had no Secret Service at all).

### T3 Code: omarcresp/t3code-flake

nixpkgs 26.05's t3code 0.0.24 hardcodes electron_40 — EOL and marked
insecure by nixpkgs, no clean override — and permitting an EOL Chromium
for a credential-holding app is a bad trade. The flake repacks current
upstream AppImage releases (desktop `t3code` + CLI `t3`, one package).
Unstable's t3code (0.1.0) was older than the flake's 0.1.2, so the flake
stays even after the unstable input exists.

### Security finding that motivated "latest stable"

The then-running Claude Desktop 2.9939.4 bundled **Electron 44.4.3**,
predating 44.9.3 — the release that distrusted **compromised eMudhra CA
keys** (confirmed via binary inspection; T3 Code's v0.1.2 bump to
44.9.3 documents the event). Vendor-bundled Electrons bypass nixpkgs'
insecure marking, so version recency is the only control for these
apps. Verified after the update: claude-desktop 3.6556.2 → Chromium
152.0.7977.167 (current patch level), t3-code 0.1.2 → Electron 44.9.3.

### Auto-update: Hydra tier only

`system.autoUpgrade` (daily, 45 min jitter, persistent, no auto-reboot)
refreshes `nixpkgs` + `nixpkgs-unstable` only. The binary-repack flakes
(claude-desktop, t3code) are bumped manually — a compromised maintainer
account must not be able to push code onto this machine while we sleep.
Timer lock bumps land uncommitted for review; `--rollback` is the
escape hatch.

## Alternatives considered

- `permittedInsecurePackages = [ "electron-40.10.5" ]` for nixpkgs
  t3code — rejected: knowingly running an EOL Chromium.
- Anthropic's native installer for claude (self-updating) — rejected:
  imperative, outside the flake, defeats reproducibility.
- Following unstable for *everything* — rejected: stable base + pinned
  per-package inputs is the repo's established pattern (caelestia,
  opencodeV2).
