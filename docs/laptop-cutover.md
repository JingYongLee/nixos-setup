# Laptop cutover runbook (unit 5)

The `laptop` host (ported x1e) builds and evaluates from this repo.
Nothing on the running laptop changes until the switch step. Every step
below is reversible: the previous system stays one boot-menu entry away
(`nixos-rebuild --rollback` or the systemd-boot menu).

## Pre-flight (already verified)

- [x] `nixosConfigurations.laptop` evaluates; per-host stateVersions
      correct (vm 26.11 / laptop 26.05, home and system)
- [x] autoUpgrade points at `path:~/workspace/nixos-setup#laptop`,
      refreshes only `nixpkgs` (Hydra-built); everything else is a
      manual, reviewed bump
- [x] hashedPasswordFile on /persist; hardening tier, usbguard
      allowlist, NVIDIA offload + RTD3, dual-boot bootloader entries
      ported verbatim from the legacy repo
- [x] Full toplevel build green on this machine (store pre-warmed)
      (2026-10-29, BUILD_RC=0)

## Cutover steps

1. **Directory swap** (do together with step 3, same sitting — the old
   system's autoUpgrade points at `~/workspace/nixos-setup#x1e`, which
   stops existing after the swap):

   ```
   mv ~/workspace/nixos-setup ~/workspace/nixos-setup-legacy
   mv ~/workspace/nixos-setup-next ~/workspace/nixos-setup
   ```

2. **mimeapps check**: `cat ~/.config/mimeapps.list` — if it holds
   associations beyond browser schemes, note them; the declarative
   file force-replaces it (browser entries are identical).

3. **Switch**:

   ```
   sudo nixos-rebuild switch --flake ~/workspace/nixos-setup#laptop
   ```

4. **Reboot** (clean module state: NVIDIA, vhost_vsock; new hostname,
   Omarchy greeter at SDDM).

5. **First login**: pick the **Omarchy** session (the greeter offers it;
   the old Hyprland session entry also remains — coexistence is
   upstream-designed). Machine-local state to set once, in session:
   Setup ▸ Defaults → terminal `ghostty`, editor `nvim` (browser comes
   from the repo's mimeapps). `~/.config/hypr/monitors.lua` seeds as a
   template — set the panel's scale/mode there if `preferred` is wrong.

6. **Laptop-only gate items** (were SP-reserved in the vm trial):
   physical media keys, suspend/resume lock cycle, fingerprint auth
   (sudo + greeter), `nvidia-offload` smoke test, usbguard accepting
   the built-ins.

## After the stability window

- Archive the legacy repo: `gh repo edit JingYongLee/nixos-setup-legacy --archived`
- The `nixvm` domain (old baseline) and the `vm` trial domain both live
  in this laptop's libvirt; keep both until confidence, then
  `virsh undefine nixvm --nvram`.
- Inert leftovers from the old setup: `~/.config/caelestia`,
  `~/.local/state/caelestia` — delete when sure.
