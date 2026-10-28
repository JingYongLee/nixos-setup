# vm — NixOS guest under libvirt/QEMU, trialing the Omarchy desktop on a
# fresh domain/disk (the predecessor nixvm domain stays untouched as the
# known-good baseline). The config repo reaches the guest through a
# virtiofs share mounted at /nixos: rebuild with
#   nixos-rebuild switch --flake /nixos#vm
{
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    ../common
    ./disko.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # --- Boot / firmware ----------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Virtual devices ------------------------------------------------------------
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true; # clipboard + dynamic resolution

  # Host repo shared in by libvirt (filesystem target: nixos-setup).
  # nofail + automount: a missing share must not block boot.
  fileSystems."/nixos" = {
    device = "nixos-setup";
    fsType = "virtiofs";
    options = [
      "rw"
      "nofail"
      "x-systemd.automount"
    ];
  };

  # --- Base system -------------------------------------------------------------------
  networking.hostName = "vm";
  time.timeZone = "Asia/Kuala_Lumpur";

  # First install runs nixos-unstable 26.11; set at install, never after.
  system.stateVersion = "26.11";

  # The repo is shared into the guest at /nixos (virtiofs); LazyVim
  # symlinks out-of-store from there, and nixarchy-apply / nh rebuild
  # from the same checkout.
  home-manager.extraSpecialArgs.nvimConfigPath = "/nixos";
  programs.nixarchy.flake = "/nixos";
  programs.nh.flake = "/nixos";

  # Host-side dev loop reaches the VM over SSH. The VM sits on libvirt's
  # NAT'd 192.168.122.0/24 and sshd is keys-only, so exposure is limited
  # to the host.
  networking.firewall.allowedTCPPorts = [ 22 ];

  # --- Browser: disable GPU (QXL/llvmpipe guest) -------------------------------------
  programs.helium.flags = [ "--disable-gpu" ];

  # --- Boot straight into the session (VM trial) ---------------------------------------
  services.displayManager.autoLogin = {
    enable = true;
    user = "jingyonglee";
  };
  # Autologin must land in the Omarchy session, not whichever entry SDDM
  # would pick alphabetically. The desktop file is omarchy.desktop
  # (nixarchy keeps the upstream session id).
  services.displayManager.defaultSession = "omarchy";
}
