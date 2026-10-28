-- Written by nixarchy (programs.nixarchy.languageServer).
-- Delete this file to be rid of it; nothing here rewrites it.
return {
  -- The grammar. nvim-treesitter compiles it with the tree-sitter CLI
  -- and the C compiler programs.nixarchy.languageServer puts on PATH.
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "nix" } } },
  -- Format on save with the tool `nix fmt` runs, so the editor and CI
  -- agree by construction. `optional`: extends conform if LazyVim
  -- loaded it, and does nothing if you removed it.
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = { formatters_by_ft = { nix = { "nixfmt" } } },
  },
}
