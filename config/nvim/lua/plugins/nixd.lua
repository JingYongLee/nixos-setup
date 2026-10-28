-- nixd LSP (replaces nil): links the real evaluator, so it completes
-- NixOS and Home Manager option names against the actual configuration.
-- Owned here rather than seeded by nixarchy's languageServer, so the
-- shared out-of-store tree stays clean in git.
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = { nixd = {} },
  },
}
