{
  description = "vm + laptop — NixOS with the Omarchy desktop, vendored by nixarchy";

  inputs = {
    # Unstable base, deliberately: nixarchy develops and CI-checks against
    # unstable (stable gets an eval check plus a weekly VM boot), and this
    # repo's trust rule already auto-updated Hydra-built unstable daily for
    # the AI CLIs. The old stable/nixpkgs-unstable split collapsed into this
    # one input.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The Omarchy desktop, vendored. Pinned to an exact release tag: the
    # pin is the release channel, moved by `nix flake update nixarchy`
    # and reviewed like any other input.
    nixarchy = {
      url = "github:olafkfreund/nixarchy/v4.5.0-rc1-1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium browser (Chromium-based, not in nixpkgs): deb repack with a
    # NixOS module. git+https avoids the GitHub REST API (rate-limited on
    # this connection).
    helium-flake = {
      url = "git+https://github.com/oxcl/nix-flake-helium-browser?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Desktop (official Linux beta, proprietary): FHS repack of
    # Anthropic's apt .deb with the vendor Electron kept. Laptop-only;
    # bumped manually and reviewed (binary-repack trust tier).
    claude-desktop = {
      url = "git+https://github.com/ilqqy/claude-desktop-flake?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # T3 Code (agent orchestrator): desktop app + t3 CLI from upstream
    # AppImage release repacks. Binary-repack trust tier, like
    # claude-desktop. git+https: GitHub API is rate-limited here.
    t3code = {
      url = "git+https://github.com/omarcresp/t3code-flake?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixarchy,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      # One host = one directory under hosts/. The module list every host
      # shares: nixarchy (desktop + its own home-manager and disko, which
      # follow this flake's nixpkgs) plus the Helium module.
      #
      # specialArgs follows nixarchy's template: the module reads
      # `inputs` and expects `inputs.self` to be nixarchy, so hosts get
      # this flake's inputs layered under nixarchy's.
      mkHost =
        path:
        lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inputs = self.inputs // nixarchy.inputs // { self = nixarchy; };
          };
          modules = [
            nixarchy.nixosModules.nixarchy
            nixarchy.inputs.home-manager.nixosModules.home-manager
            nixarchy.inputs.disko.nixosModules.disko
            inputs.helium-flake.nixosModules.default
            path
          ];
        };
    in
    {
      nixosConfigurations = {
        vm = mkHost ./hosts/vm;
        laptop = mkHost ./hosts/laptop;
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
