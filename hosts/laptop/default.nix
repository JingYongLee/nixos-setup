# laptop — NixOS on the ThinkPad X1 Extreme Gen 4i (Tiger Lake i7 +
# RTX 3050 Ti), the daily driver. LUKS2 + btrfs over the old EndeavourOS
# partition with the Windows side of the disk untouched. Ported from the
# predecessor repo's x1e host; install history in the legacy repo's
# docs/host-install-runbook.md.
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common
    ./disko.nix
  ];

  # --- Base system -------------------------------------------------------------
  networking.hostName = "laptop";
  time.hardwareClockInLocalTime = true; # dual-boot with Windows
  time.timeZone = "Asia/Kuala_Lumpur"; # without this the clock runs UTC
  networking.networkmanager.enable = true;
  # LocalSend (LAN file transfer) discovery + transfer port.
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];
  # AX210 iwlwifi, Intel graphics DMC and SOF audio require firmware blobs.
  # Without this, iwlwifi fails to load ty-a0-gf-a0-89.ucode and no Wi-Fi
  # interface appears in NetworkManager.
  hardware.enableRedistributableFirmware = true;

  # /persist must be available during early activation so that
  # users.users.jingyonglee.hashedPasswordFile can be read at boot.
  fileSystems."/persist".neededForBoot = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50; # ~8G on 16G RAM, matches the old EOS setup
  };

  # This machine's home state predates this repo (installed 2026-10 at
  # 26.05): keep that release. The vm host, installed fresh from
  # unstable, pins 26.11. Set at install, never after.
  home-manager.users.jingyonglee.home.stateVersion = "26.05";

  # --- Graphics: Intel iGPU display + NVIDIA 3050 Ti on demand ----------------
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];
  hardware.nvidia = {
    open = true; # Turing+, the upstream direction
    modesetting.enable = true; # Wayland
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # nvidia-offload wrapper
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
    powerManagement.enable = true; # VRAM save/restore across suspend
    powerManagement.finegrained = true; # RTD3: dGPU powers off when idle
  };

  # --- Laptop hardware ----------------------------------------------------------
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false; # hardening tier 1

  services.power-profiles-daemon.enable = true; # the shell's power widget
  services.thermald.enable = true;

  # Fingerprint reader (Synaptics match-on-sensor; libfprint covers it)
  services.fprintd.enable = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.polkit-1.fprintAuth = true;
  security.pam.services.sddm.fprintAuth = true; # the login screen too

  # --- Virtualization: the vm trial VM (libvirt + virt-manager) --------------
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
      # virtiofsd for the vm virtiofs share (repo -> /nixos in the guest).
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };
  programs.virt-manager.enable = true;
  users.users.jingyonglee.extraGroups = [
    "libvirtd"
    "kvm" # Claude Desktop Cowork VMs: /dev/kvm + /dev/vhost-vsock access
  ];

  # --- Claude Desktop (official Linux beta, via the claude-desktop flake) ---
  # The -cowork variant bundles QEMU + OVMF + virtiofsd for Cowork VMs;
  # Cowork still needs the kvm group + vhost_vsock below. The FHS env keeps
  # the vendor Electron, which is what makes the Code tab work. Binary-repack
  # trust tier: bumped manually, reviewed.
  # --- Android app development (2026-10 decision: Kotlin + Compose) ----------
  # android-studio: DEV channel (2026.2.3.x, unfree) — AGP 9.5 (droidchess) needs Studio
  # 2026.2.2+; nixpkgs stable is still 2026.2.1. Revert to
  # pkgs.android-studio once stable carries 2026.2.2+. Ships the Compose
  # toolchain; the SDK itself is Studio-managed in ~/Android/Sdk — the
  # project pins what matters (gradle wrapper, AGP, compileSdk) in git.
  # android-tools: adb/fastboot on PATH (NOT programs.adb.enable, which is
  # inert on current nixpkgs — systemd 258 uaccess covers USB perms).
  # Emulator runs on /dev/kvm (kvm group already assigned above).
  # scrcpy: app-catalogue row (NixOS-level option — apps.* is not a home
  # option), mirrors/controls a real phone over USB or Wi-Fi.
  # omawrite: Omarchy's own focused writing app, packaged by the port.
  programs.nixarchy.apps.scrcpy.enable = true;
  programs.nixarchy.apps.omawrite.enable = true;
  environment.systemPackages = [
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-cowork
    pkgs.androidStudioPackages.dev
    pkgs.android-tools
  ];
  boot.kernelModules = [ "vhost_vsock" ];
  # Sign-in persistence: the app stores credentials through libsecret
  # (Secret Service). gnome-keyring provides it; PAM unlocks the login
  # keyring at SDDM so Claude stays signed in across reboots.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # --- Auto-update: daily rebuild from this repo with refreshed inputs -----
  # Runs as root on a timer (nixos-upgrade.service). Only Hydra-built
  # inputs auto-move (nixpkgs, the unstable base); everything else —
  # the nixarchy release tag, opencode rev pin, and the binary-repack
  # flakes (claude-desktop, t3code) — is bumped manually:
  #   nix flake update <input>; git diff flake.lock; rebuild
  # so daily runs don't extend trust to individual maintainers' repos.
  # Lock bumps land uncommitted in the working tree; commit them
  # periodically. Kernels activate but never auto-reboot; roll back with
  # nixos-rebuild --rollback.
  system.autoUpgrade = {
    enable = true;
    dates = "daily";
    randomizedDelaySec = "45min";
    persistent = true; # catch up after the laptop was powered off
    flake = "path:/home/jingyonglee/workspace/nixos-setup#laptop";
    upgrade = false; # no channel; inputs move via the explicit flag below
    flags = [
      "--update-input"
      "nixpkgs"
    ];
    allowReboot = false;
  };

  # --- Hardening: tier 0+1, Docker-compatible -----------------------------------
  # (nftables skipped: Docker's iptables backend conflicts with it.)
  systemd.coredump.enable = false;
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
  };
  security.sudo.execWheelOnly = true;
  users.mutableUsers = false;
  # Password is managed declaratively from a root-only hash on the
  # encrypted /persist subvolume. Do not put passwords or hashes in Git.
  users.users.jingyonglee.hashedPasswordFile = "/persist/secrets/jingyonglee-password-hash";
  services.fwupd.enable = true;

  services.usbguard = {
    enable = true;
    IPCAllowedUsers = [ "jingyonglee" ];
    rules = ''
      # Built-in devices of the X1 Extreme Gen 4i (policy generated from
      # live hardware before install): root hubs, camera, fingerprint
      # reader, Bluetooth.
      allow id 1d6b:0002
      allow id 1d6b:0003
      allow id 30c9:0032
      allow id 06cb:00f9
      allow id 8087:0032
      block
    '';
  };

  # --- Bootloader: systemd-boot on the Linux ESP ----------------------------------
  # Windows Boot Manager lives on the separate Windows ESP (p1) and is
  # offered as a menu entry via the EDK2-shell chainload (the wiki pattern
  # for cross-ESP dual boot).
  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
      configurationLimit = 20;
      # Confirmed via EDK2 Shell `map -c` on this firmware (2026-10-24):
      # the Windows ESP (nvme0n1p1) maps to HD0b / FS0, the Linux ESP
      # (nvme0n1p4) to HD0e / FS1.
      windows."win11".efiDeviceHandle = "HD0b"; # nvme0n1p1: Windows ESP
      edk2-uefi-shell.enable = true;
      edk2-uefi-shell.sortKey = "z_edk2";
    };
  };

  # --- This machine's repo checkout (final path after cutover) ---------------
  home-manager.extraSpecialArgs.nvimConfigPath = "/home/jingyonglee/workspace/nixos-setup";
  programs.nixarchy.flake = "/home/jingyonglee/workspace/nixos-setup";
  programs.nh.flake = "/home/jingyonglee/workspace/nixos-setup";

  # First install was 26.05 (predecessor repo); never change after install.
  system.stateVersion = "26.05";
}
