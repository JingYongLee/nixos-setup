# Trial gate: vm host

The Omarchy session must pass every item before the laptop is ported
(unit 5). Checked items carry the date and how they were proven.

## Machine

- [x] Boots from disk, hostname `vm`, display-manager active (2026-10-28, SSH)
- [x] `omarchy.desktop` session registered; autologin lands in it (2026-10-28)
- [x] `omarchy` + `nixarchy` CLIs on PATH; omarchy-shell healthy in the
      journal (2026-10-28, SSH)
- [x] Daily tools: ghostty 1.3.1, NVIM 0.12.6 (LazyVim via out-of-store
      symlink), opencode 2.1.4, `make verify` smoke green (2026-10-28)

## Session (eyes and hands, in virt-viewer)

- [ ] Bind parity: universal clipboard incl. the ghostty CTRL+SHIFT
      variant, resize family (SUPER+MINUS/EQUAL ± SHIFT/CTRL/ALT),
      scratchpad (SUPER+S / SUPER+grave), alt-tab cycling
- [ ] Tokyo Night across bar, launcher, greeter, ghostty, nvim
- [ ] Notifications; volume from the bar (physical media keys are proven
      on the laptop, not over SPICE)
- [ ] Lock + wake cycle (idle lock or menu lock; `changeme` unlocks)
- [ ] No visible llvmpipe regression vs the old nixvm
- [ ] Theme round-trip: another theme and back, whole desktop + nvim
      follow (theme.lua link + hyprchroma bridge)

## Trial fixes so far

- Password: `initialPassword` never landed at creation; reset via
  installer-ISO chroot shadow edit (2026-10-29)
- Resolution: QXL prefers 1024x768; forced 1920x1080@60 in the session's
  own `~/.config/hypr/monitors.lua` (Omarchy user template, edited in
  place by design — not HM-managed)
- Browser: Helium owns `mimeapps.list` declaratively; Setup ▸ Default
  browser is inert for it by upstream design
- File manager: Nautilus (upstream base) keeps SUPER+SHIFT+F; Thunar
  dropped from the record
- ghostty: hyprchroma theme-bridge include carried into the repo config

## After the gate

A few days of daily use, then unit 5: port x1e as `hosts/laptop` and
cut over. The old repo archives once the laptop runs this setup.
