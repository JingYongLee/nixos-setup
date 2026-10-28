# vm — the trial VM under libvirt/QEMU. Hosts the Omarchy session trial
# on a fresh disk; the laptop host is ported only after the gate passes.
# Unit 1 (skeleton) carries identity + home wiring only; QEMU hardware,
# disko, autologin and the virtiofs share land in unit 2.
{ ... }:
{
  imports = [ ../common ];

  networking.hostName = "vm";

  # Trial VM password; the real machine uses a hashed file.
  users.users.jingyonglee.initialPassword = "changeme";

  # The repo is shared into the guest at /nixos (virtiofs); LazyVim
  # symlinks out-of-store from there.
  home-manager.extraSpecialArgs.nvimConfigPath = "/nixos";
  programs.nixarchy.flake = "/nixos";
  programs.nh.flake = "/nixos";

  # This value does not affect fingerprinting; do not change it after install.
  system.stateVersion = "26.05";
}
