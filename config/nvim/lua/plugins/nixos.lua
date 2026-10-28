-- NixOS adjustments for LazyVim.
-- Mason downloads prebuilt FHS binaries, which do not run on NixOS; every
-- tool and LSP server is supplied by home-manager instead and must be in
-- PATH (see home/jingyonglee.nix, home.packages).
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
}
