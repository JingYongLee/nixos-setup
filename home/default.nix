# jingyonglee's home: ghostty (ported config), LazyVim hybrid (Nix supplies
# every tool/LSP, lua stays portable), and the nixarchy home module with
# the plugin trim set from the adoption decision record.
{
  config,
  lib,
  pkgs,
  opencodeV2,
  t3code,
  nvimConfigPath,
  ...
}:
{
  home.username = "jingyonglee";
  home.homeDirectory = "/home/jingyonglee";
  # First install runs nixos-unstable 26.11; set at install, never after.
  home.stateVersion = "26.11";

  # --- Omarchy desktop (nixarchy home module) ---------------------------------
  programs.nixarchy = {
    enable = true;
    defaultTheme = "tokyo-night";

    # Trim set (decision record, 2026-10). Keys are verified against
    # nixarchy's defaultPluginSet — the option type accepts unknown keys
    # silently, so a typo here would be a silent no-op.
    defaultPlugins = {
      # kept
      pkg = true; # install menu panel (writes declarations)
      rebuild = true; # rebuild progress panel
      github = true; # GitHub Actions panel (gh)
      gliff-manager = true; # bar widget for gliff remote desktop
      omatheme = true; # runtime theme switching
      hyprforge = true; # live Hyprland settings editor — trial; drop if unused
      # off
      gitlab = false; # no GitLab
      herdr = false; # no herdr sessions
      podman = false; # no podman
      distrobox = false; # no boxes
      microvm = false; # no sandbox VMs (libvirt covers it)
      devenv = false; # project envs via devShells, not devenv
      flatsnap = false; # no Flatpak/Snap
      plugin-browser = false; # no runtime plugin marketplace
      ai-mirror = false; # nixarchy-specific desktop control, not upstream
    };
  };

  # --- Terminal ------------------------------------------------------------------
  xdg.configFile."ghostty/config".source = ../config/ghostty/config;

  # --- Browser default: Helium ---------------------------------------------------
  # Omarchy's default-browser menu hard-codes its seven browsers; Helium
  # isn't one. Owning mimeapps.list declaratively sets the handlers once
  # and survives rebuilds. Consequence (documented upstream): the file
  # becomes a store symlink, so Setup > Default browser can no longer
  # change it — browser choice lives here now.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
      "x-scheme-handler/about" = "helium.desktop";
      "x-scheme-handler/unknown" = "helium.desktop";
      "text/html" = "helium.desktop";
      "application/x-extension-htm" = "helium.desktop";
      "application/x-extension-html" = "helium.desktop";
      "application/x-extension-shtml" = "helium.desktop";
      "application/x-extension-xht" = "helium.desktop";
      "application/x-extension-xhtml" = "helium.desktop";
      "application/xhtml+xml" = "helium.desktop";
    };
  };

  # --- Editor: LazyVim hybrid -----------------------------------------------------
  # Plain lua starter symlinked out-of-store so lazy.nvim can write
  # lazy-lock.json back into the repo. Per-host path (extraSpecialArgs):
  # /nixos virtiofs share in the vm, the workspace checkout on the laptop.
  # colorscheme.lua pin replaced by the theme.lua symlink: nvim follows the
  # active Omarchy theme across all 22 themes (decision record).
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${nvimConfigPath}/config/nvim";

  home.packages = with pkgs; [
    # core cli
    ghostty
    git
    ripgrep
    fd
    gcc # runtime treesitter parser compilation
    lazygit
    btop
    jq
    yq-go # mikefarah yq v4; nixpkgs 'yq' is the unmaintained v3 python wrapper

    # capture/OCR toolbelt — kept through the trial; trim to tesseract
    # after the gate proves Omarchy's capture and clipboard cover the rest
    grim
    slurp
    hyprpicker
    wl-clipboard
    tesseract # OCR region-to-clipboard
    cliphist
    wl-clip-persist
    fuzzel

    # GUI apps. Nautilus (file manager, SUPER+SHIFT+F) comes with the
    # Omarchy base — Thunar dropped from the record after the trial
    # showed Nautilus arrives upstream-integrated.
    localsend

    # editor: nvim itself + every tool/LSP the LazyVim extras expect
    # (mason is disabled; see config/nvim/lua/plugins/nixos.lua).
    # nil was replaced by nixd (config/nvim/lua/plugins/nixd.lua) —
    # nixd completes NixOS/HM option names, nil does not.
    neovim
    tree-sitter # nvim-treesitter main-branch CLI requirement
    nixd
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer # extras.lang.rust
    nixfmt # extras.lang.nix formatter (conform)
    statix # extras.lang.nix linter (nvim-lint)
    vtsls # extras.lang.typescript server
    nodejs # vtsls runtime
    vscode-langservers-extracted # extras.lang.json -> jsonls

    # AI stack. claude-code + codex come straight from the unstable base
    # now (the old nixpkgs-unstable side-input collapsed into it).
    claude-code
    codex
    opencodeV2.packages.${pkgs.stdenv.hostPlatform.system}.default
    t3code.packages.${pkgs.stdenv.hostPlatform.system}.t3-code
  ];

  # --- Shell: oh-my-zsh ---------------------------------------------------------
  # Omarchy's shell function chain (eza/zoxide aliases, 20 helpers) loads
  # before this via /etc/bashrc + zsh rc chain; own definitions win here.
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
