# Shared system config for all hosts (vm, laptop): the Omarchy desktop via
# nixarchy with the trim set from the adoption decision record, the user,
# ssh, nix. Hardware (disko, GPU, security posture) lives in hosts/<name>.
{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
{
  # --- Omarchy desktop (nixarchy) --------------------------------------------
  programs.nixarchy = {
    enable = true;
    user = "jingyonglee"; # input group for controllers/dictation

    # Where nixarchy-apply copies the app selection (apps.nix) before a
    # rebuild. The repo checkout is per-host: the /nixos virtiofs share in
    # the vm, the workspace checkout on the laptop.
    flake = lib.mkDefault "/nixos";

    # Trim (decision record, 2026-10): keep the upstream desktop, drop the
    # port author's extras. nixSkills symlinks ~17 agent skills into
    # ~/.claude/skills and friends — off; our own skills setup stays
    # authoritative, useful ones get vendored deliberately.
    nixSkills = false;

    # No Plymouth splash: minimal text boot, as before. Omarchy's SDDM
    # greeter theme is kept (displayManager default) and follows all 22
    # themes.
    bootSplash = "off";
  };

  # --- User --------------------------------------------------------------------
  users.users.jingyonglee = {
    isNormalUser = true;
    # No docker group: Docker runs rootless as a user service (nixarchy
    # default). The group is passwordless-root-equivalent.
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "i2c"
    ];
    # Password set per host: trial VM uses initialPassword, the laptop
    # keeps its hashedPasswordFile on /persist.
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../keys/jingyonglee.pub)
    ];
  };

  programs.zsh.enable = true;

  # Unfree: claude-code CLI, NVIDIA userspace (laptop), claude-desktop.
  nixpkgs.config.allowUnfree = true;

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # --- Browser -----------------------------------------------------------------
  programs.helium.enable = true;

  # --- home-manager --------------------------------------------------------------
  # HM comes from nixarchy's inputs (follows our nixpkgs). The nixarchy HM
  # module is a shared module so it lands in the user's config once.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [ inputs.self.homeManagerModules.nixarchy ];
    users.jingyonglee = {
      imports = [ ../../home ];
      programs.nixarchy.enable = true;
      # The desktop guide + agent tutor. Off (decision record). A
      # home-manager option, not a NixOS one.
      services.nixi.enable = false;
      home.stateVersion = "26.05";
    };
    extraSpecialArgs = {
      inherit (inputs) opencodeV2 t3code;
      # LazyVim out-of-store symlink source, per host (see home/default.nix).
      nvimConfigPath = lib.mkDefault "/nixos";
    };
  };

  # nixarchy-apply drives `nh os switch <flake>`, so nh is enabled and
  # pointed at the same per-host checkout. Generation cleanup stays off:
  # generations are the rollback story, and pruning them is a policy this
  # repo has not decided on.
  programs.nh = {
    enable = true;
    flake = lib.mkDefault "/nixos";
    clean.enable = false;
  };

  # --- sshd: keys only, not exposed to the network ---------------------------
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- Nix --------------------------------------------------------------------
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    allowed-users = [ "@users" ]; # hardening tier 0
  };
}
