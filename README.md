# nixos-setup

NixOS with the Omarchy desktop, vendored for NixOS by
[nixarchy](https://github.com/olafkfreund/nixarchy) and pinned to a release
tag. Two hosts:

- **vm** — trial VM under libvirt/QEMU; the Omarchy session trial runs here
  on a fresh disk before the laptop is touched
- **laptop** — the ThinkPad (LUKS2 + btrfs, NVIDIA offload, Windows
  dual-boot preserved, hardened); ported after the vm gate passes

Predecessor: `nixos-setup-legacy` (Hyprland + Caelestia, hand-ported Omarchy
binds). The adoption decision record lives in the grilling session that
produced this repo; `docs/research/` carries the older decision notes.

## Architecture

```
flake.nix              nixos-unstable base; nixarchy pinned to a release tag
hosts/common/          desktop + trim set, user, ssh, nix, home-manager wiring
hosts/vm/              trial VM (hardware lands with unit 2)
home/                  jingyonglee's home: ghostty, LazyVim, AI stack, plugin trim
config/nvim/           LazyVim starter; theme.lua follows the Omarchy theme
config/ghostty/        terminal config, ported from the EndeavourOS host
keys/                  SSH public keys
docs/research/         decision research notes
```

## Decisions that shaped this repo

- **Vendored, not reimplemented.** The desktop is upstream Omarchy; tracking
  a release is a source bump, not a re-port of the binds.
- **Unstable base.** nixarchy is developed and CI-tested against unstable;
  the old stable + unstable side-input split collapsed into one input.
- **Upstream desktop, trimmed extras.** omatheme, hyprforge (trial), the pkg
  and rebuild panels and the GitHub panel stay; GitLab/herdr/podman/
  distrobox/microvm/devenv/flatsnap/plugin-browser/ai-mirror/nixi and the
  agent-skills symlinking are off (`home/default.nix`,
  `hosts/common/default.nix`).
- **The 69-app catalog stays commented out.** Apps we run are declared in
  this repo; the menu is a picker, not a bundle.
- **Docker rootless.** The docker group is passwordless-root-equivalent.
- **nh clean stays off.** Generations are the rollback story; pruning them
  is a policy still to be decided.

## Workflow

```
nix fmt                                   # nixfmt-rfc-style
nix flake update nixarchy                # move the desktop pin, reviewed
nixos-rebuild switch --flake .#vm        # apply (in the guest: /nixos#vm)
```

`nixarchy-apply` (from the desktop's Install menu) copies the selection into
`nixarchy-apps.nix` at the flake root and rebuilds via nh.
