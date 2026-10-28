# LazyVim on NixOS: approach comparison (research, Oct 2026)

Question: for a NixOS user who wants nvim as their editor, compare (1) pure/standalone LazyVim via the starter clone, (2) nixvim, (3) home-manager hybrid (Nix supplies binary + tools, LazyVim config stays lua), and recommend for a systems engineer wanting low friction + reproducibility.

Verification key: **[V]** = read at the primary source this session. **[I]** = inference/synthesis by me. Third-party aggregators are named as such.

## 1. What LazyVim officially requires and says about NixOS

- Current requirements (lazyvim.org, Getting Started, read Oct 2026) **[V]**:
  - Neovim >= **0.11.2**, built with LuaJIT
  - Git >= 2.19.0 (partial clones)
  - **tree-sitter-cli and a C compiler** for nvim-treesitter
  - curl for blink.cmp (current completion engine)
  - Optional: lazygit, fzf >= 0.25.1, **ripgrep** (live grep), **fd** (find files), Nerd Font v3+, true-color terminal
  - Source: https://www.lazyvim.org/
- The Installation page has **no NixOS-specific section** — only Linux/MacOS, Windows, Docker **[V]**. https://lazyvim.github.io/installation
- The only Nix-related LazyVim doc is `extras/lang/nix` (editing Nix files: nil_ls, nixfmt, statix) — not about installing on NixOS **[V]**. https://lazyvim.github.io/extras/lang/nix
- The de-facto official NixOS thread is LazyVim discussion #1972 "Setup LazyVim using Nix and home-manager" (azuwis, Nov 2023), still updated Feb 27, 2026 **[V]**. https://github.com/LazyVim/LazyVim/discussions/1972

## 2. Approach 1 — pure LazyVim (git clone starter into ~/.config/nvim)

It runs: LazyVim is plain lua + lazy.nvim, which self-bootstraps via git. Nothing in it needs Nix. The friction is environmental **[V]** (all items below verified at their sources):

- **Treesitter**: `:TSInstall` compiles parsers at runtime, needing gcc/cc + tree-sitter-cli + writable parser dir. NixOS wiki: "Installing grammar packages through the built-in command can lead to errors"; recommends Nix-provided grammars instead. https://nixos.wiki/wiki/Treesitter **[V]**
- **Mason**: downloads prebuilt FHS binaries; breaks on NixOS (empty registry / download failures). https://github.com/williamboman/mason.nvim/issues/1396 (Jul 2023) **[V]**. Three known fixes:
  - `programs.nix-ld.enable = true` + `libraries = [ stdenv.cc.cc ]` — Reddit r/NixOS "Run Neovim distributions in NixOS" (May 2025, u/kevin8tr, 8 pts) **[V]**
  - disable mason, supply LSPs via `programs.neovim.extraPackages` (discussion #1972) **[V]**
  - keep mason but set `programs.neovim.extraWrapperArgs` with LIBRARY_PATH / PK_CONFIG_PATH — home-manager's option docs explicitly cite mason.nvim as the reason for the option **[V]** (see §4)
- **External tools** (rg, fd, fzf, lazygit, git, curl) are just PATH deps; supply via nixpkgs (home.packages or extraPackages) **[V, requirements page]**
- **Neovim version**: LazyVim needs >= 0.11.2. nixpkgs unstable currently ships 0.12.4+ (by-name/package.nix on nixos-unstable branch, read this session) **[V]**; 26.05 stable gets 0.12.x backports (nixpkgs PR #530655, June 2026, label "backport release-26.05") **[V]**. Version pain was real in the 25.05 era (0.10.4); both current channels satisfy LazyVim today **[I]**. Timeline cross-check via nixpkgs-multiverse.com (third-party aggregator of cache.nixos.org): 0.11.2 shipping since Jul 2025, 0.12.x since Apr 2026, 0.12.6 as of 2026-10-20 **[V-read, aggregator]**
- Failure mode in the wild: r/NixOS "lazyvim on nixos" (Nov 1, 2025) — fresh user with starter got "only 4 out of 32 plugins were running"; replies: "Try nixvim" vs "I use home manager to install my lua files… don't see why it would be hard" **[V]**. https://www.reddit.com/r/NixOS/comments/1ollzym/lazyvim_on_nixos/
- Read-only-store errors appear when treesitter tries to write parsers into a store path (e.g. when nvim-treesitter came from HM plugins): "Cannot create parser dir /nix/store/.../parser: read-only file system" — fix by pointing `parser_install_dir`/`install_dir` at `stdpath("data")`. https://discourse.nixos.org/t/cant-get-neovim-treesitter-to-work/66411 (Jul 2025) **[V]**

## 3. Approach 2 — nixvim

- Actively maintained in 2026: ~3.0k stars, 4,779 commits, maintainers GaetanLepage/traxys/MattSturgeon/khaneliman; HM, NixOS, nix-darwin, and standalone (`makeNixvim`) interfaces **[V]**. https://github.com/nix-community/nixvim
- **Does not support LazyVim and has declined to**: issue #3071 "Feature Request: Full LazyVim Distribution in NixVim" (Mar 2025) closed as *not planned*. Maintainer GaetanLepage: "Nixvim does not aim to be a neovim distribution. So this is out of scope." traxys: "more appropriate as a project over nixvim, like something like `lazynixvim`." **[V]**. https://github.com/nix-community/nixvim/issues/3071
- The old `examples/lazyvim` is gone: https://github.com/nix-community/nixvim/tree/main/examples/lazyvim returns 404 and the repo root has no `examples/` directory at all (only `templates/` with the default standalone template) **[V]**. Removal date not pinned down; it existed in the 2023–2024 era (referenced from discussion #1972, Feb 2024) **[I]**. Its technique survives out-of-tree as azuwis/lazyvim-nixvim **[V]**.
- What nixvim does offer: a `plugins.lazy` module for lazy.nvim itself, with `settings` passed "to `require('lazy').setup()` without any alteration" (GaetanLepage, Oct 2025) **[V]** — so you *can* hand-build a LazyVim spec inside nixvim (the #3071 issue body shows the whole linkFarm + dev.path recipe), but you own the translation. Ergonomic gap is real: declaring inter-plugin `dependencies` under nixvim's lazy module is not straightforward (discourse, Jul 2025) **[V]**. https://discourse.nixos.org/t/how-to-declare-dependency-in-nixvims-lazy-plugin/66971
- Version coupling: "the `main` branch of Nixvim requires to be installed with `nixpkgs-unstable`… If you want to use Nixvim with nixpkgs 26.05 you should use the `nixos-26.05` branch." **[V]** (README)
- Nix-native LazyVim-*shaped* alternatives that community users land on instead: **nvf** (NotAShelf/nvf) and **nixCats-nvim** (has a LazyVim template) **[V, discourse Oct 2024 + Jul 2025]**. https://discourse.nixos.org/t/cross-platform-lazyvim-setup-nixos-integration-without-home-manager/55266

## 4. Approach 3 — home-manager hybrid

Verified from home-manager source (modules/programs/neovim.nix, master) and the manual **[V]**:

- `extraPackages` — "Extra packages available to nvim", wrapped with `--suffix PATH` (so anything already in the user's PATH wins; use `extraWrapperArgs` + `--prefix` for the opposite — documented in the HM wiki Neovim page)
- `plugins` — list from `pkgs.vimPlugins`
- `extraWrapperArgs` — docs state: "sets environment variables required for building and running binaries with external package managers **like mason.nvim**"; example suffixes LIBRARY_PATH / PKG_CONFIG_PATH with stdenv.cc.cc + zlib
- `autowrapRuntimeDeps` (default true) — auto-wraps plugin runtime deps
- **Rename warning**: `extraLuaConfig` → `initLua` on master (mkRenamedOptionModule); older blog posts/snippets (incl. discussion #1972's original) use the old name **[V]**
- HM wiki Neovim page: https://github.com/nix-community/home-manager/wiki/Neovim **[V]**

`makeNeovimConfig` is **deprecated** in current nixpkgs: `lib.warn "neovimUtils.makeNeovimConfig is deprecated. Use wrapNeovim or wrapNeovimUnstable directly."` (pkgs/applications/editors/neovim/utils.nix, master, read this session) **[V]**. Also in that file: grammars now ship as individual derivations (`vimPlugins.nvim-treesitter-parsers.*`), with `neovimUtils.grammarToPlugin` for niche ones **[V]**.

Documented hybrid patterns (all verified at source):

1. **azuwis / discussion #1972** (canonical; updated Feb 27, 2026 for the treesitter rewrite): plugins from `pkgs.vimPlugins` exposed to lazy.nvim via a `linkFarm` + `dev.path` + `patterns = { "" }` + `fallback = true`; mason disabled; treesitter grammars via `nvim-treesitter.withAllGrammars` + `symlinkJoin` over `.dependencies`, pointed at by `install_dir` (post-rewrite) or `xdg.configFile."nvim/parser"` (pre-rewrite); user lua via `xdg.configFile` / `mkOutOfStoreSymlink`. https://github.com/LazyVim/LazyVim/discussions/1972 **[V]**
2. **matadaniel/LazyVim-module** (47 stars): `programs.lazyvim.enable = true`, per-extra toggles in Nix (`extras.lang.nix.enable`), plugins from nixpkgs, custom specs via `pluginsFile."editor.lua".source = ./editor.lua`. Requires unstable-channel-era nixpkgs. https://github.com/matadaniel/LazyVim-module **[V]**
3. **pfassina/lazyvim-nix** (20+ stars, actively maintained — PR #96 "Stop LazyVim runtime treesitter installs under Nix" merged June 2026): `programs.lazyvim.enable`, tracks each LazyVim release and pins plugin versions at that release ("bleeding edge by default, nixpkgs versions on request"), `treesitterParsers` option, `installCoreDependencies` (git/rg/fd), per-language `installDependencies`. https://github.com/pfassina/lazyvim-nix **[V]**
4. **nix-ld + vanilla LazyVim**: enable nix-ld with `stdenv.cc.cc` (+ nodejs, unzip, etc. as needed) and use the stock starter as-is. (Reddit May 2025; discussion #1972 comment: "just add nix-ld … I think this is the easiest way") **[V]**
5. **Mic92's dotfiles** (discourse, Nov 2024): runs with `nix run`, mason configured to not pull random binaries, treesitter grammars from nixpkgs, also integrated into HM. **[V]**
6. **breuer.dev pattern** (Nov 2024, not LazyVim but relevant): lazy.nvim as the only HM plugin with `pkg/install/change_detection` disabled, specs using `dir = "${pkgs.vimPlugins.x}"` — Nix supplies sources, lazy.nvim does lazy-loading. https://breuer.dev/blog/nix-lazy-neovim **[V]**
7. Home-manager itself declined a built-in LazyVim module: #6625 closed Jan 23, 2026. teto (collaborator, Mar 2025): "With nix, you dont need a plugin manager such as lazy.nvim. I prefer to keep the home-manager module simple… For more elaborate setup you have nixvim & co." Close comment: "Seems like matadaniel/LazyVim-module has a home manager module which is IMHO the best design." https://github.com/nix-community/home-manager/issues/6625 **[V]**

Known trap for hybrids that mix HM-supplied plugins with lazy.nvim: lazy.nvim resets packpath by default, which hides the wrapper's store grammars; `performance.reset_packpath = false` restores them at a startup cost (~80ms → ~260ms in the reporter's test), which is why current patterns put grammars in the config dir (`nvim/parser`) or `install_dir` instead. discourse "Bundling all treesitter grammar in neovim while using lazy.nvim" (Dec 2025) **[V]**.

## 5. Community consensus (2025–2026)

- The recurring thesis from Nix users who run LazyVim: keep the lua config as portable dotfiles, let Nix own the toolchain. Quote (multi-year user in #1972): "I really like the idea that you can keep your declarative Lua config in separate files while letting Nix + Home Manager handle all the package management." **[V]**
- The nixvim camp: "Highly recommend setting up nixvim. Saves a lot of [time]" (r/NixOS, May 2025, 13 pts); "Try nixvim and install everything you Need over it" (r/NixOS, Nov 2025) **[V]**. But note nixvim users who wanted LazyVim ergonomics report porting effort (chek1337's dotfiles commit trail: "port more features from LazyVim") **[V, commit titles]**.
- The distro-author data point: pfassina (lazyvim-nix): "Getting Neovim to work on my config was the most complicated part of switching to NixOS back when I moved 3 years ago." (r/neovim, Oct 2025) **[V]**
- Middle-path camp: nvf users in the Oct 2024 discourse thread ("I've settled on nvf… It is really excellent"); nixCats recommended for cross-platform Nix/non-Nix sharing (discourse Jul 2025) **[V]**
- LSP servers: consensus is do NOT let mason build them; provide via nix (extraPackages) or per-project devshells (discourse "Neovim in NixOS", Jun 2025: "I consider it the best, if the LSP-server is provided by the devshell") **[V]**
- Treesitter was the 2025–2026 breakage vector across every approach (nvim-treesitter main-branch rewrite; per-grammar derivations in nixpkgs): #1972 Feb 2026 update, lazyvim-nix PR #96 June 2026, discourse Dec 2025 packpath thread all exist because of it **[V]**

Consensus tradeoff, stated plainly **[I, synthesized from the above]**:
- Nix side gives: hash-pinned plugins/binary/tools, offline/air-gapped builds, shared binary cache, rollback.
- LazyVim-native gives: same-day plugin ecosystem velocity, LazyExtras one-keystroke toggles, zero translation layer, config identical on non-Nix machines; pinning via lazy-lock.json is commit-level, not hash-level, and first bootstrap needs network + toolchain.
- The hybrid splits the difference: Nix pins the toolchain (nvim, gcc, rg, fd, lazygit, LSPs, grammars), LazyVim manages only itself. Cost: you re-verify the integration seams whenever nvim-treesitter or lazy.nvim change behavior under Nix.

## 6. Comparison

| Dimension | Pure LazyVim (starter clone; nix-ld if mason) | nixvim (LazyVim not supported) | HM hybrid (Nix tools + vanilla LazyVim as dotfiles) | HM + LazyVim-module / lazyvim-nix (declarative distro) |
|---|---|---|---|---|
| Bootstrap friction on NixOS | Low if tools present; first-run failures without gcc/git (verified reports of total failure) | Medium–high: rewrite config as Nix modules | Low: enable programs.neovim + extraPackages, symlink config | Low: one import + `programs.lazyvim.enable` |
| LazyVim support | Native, full | None (maintainers declined, #3071) | Full; LazyExtras work as lua | Full-ish; extras as Nix options (module coverage varies) |
| Plugin updates | `:Lazy update` same-day upstream | Channel-bound; nixvim main needs nixpkgs-unstable | `:Lazy update` same-day | Flake update; lazyvim-nix tracks each LazyVim release; module tracks nixpkgs |
| Reproducibility | lazy-lock.json (commits) only; tools unpinned unless Nix-supplied | Hash-level, everything pinned | Hash-level for tools/LSPs/grammars; lazy-lock for plugins | Hash-level for everything |
| Treesitter | Compiles at runtime; needs gcc; nix grammars recommended by wiki | Nix grammars, first-class | Nix grammars via symlinkJoin + install_dir (post-2025 recipe) | Handled by module (lazyvim-nix PR #96) |
| Mason | Broken without nix-ld/extraWrapperArgs | N/A (no mason) | Disable; LSPs via extraPackages | Disabled; LSPs via module options |
| Config portability to non-Nix machines | Identical | None (pure Nix) | Identical (lua is plain dotfiles) | None (options are Nix) |
| Maintenance risk | Upstream changes; NixOS env quirks | Translation lag per plugin | Integration seams on treesitter/lazy.nvim changes; seams broke once already in 2025–26 | Module lag behind LazyVim releases; small-maintainer bus factor (47 / ~20 stars) |
| Endorsed by | LazyVim docs (no Nix notes though) | nixvim maintainers ("not a distribution") | HM maintainer points here for simplicity; multi-year users | HM collaborator: matadaniel module "IMHO the best design" |

## 7. Recommendation (systems engineer, low friction + reproducibility)

**Primary: HM hybrid — Nix owns the toolchain, LazyVim owns itself.**

```nix
programs.neovim = {
  enable = true;
  defaultEditor = true;
  extraPackages = with pkgs; [
    gcc tree-sitter  # runtime parser builds, if not shipping grammars via nix
    ripgrep fd lazygit fzf curl git
    lua-language-server nil nixfmt-rfc-style stylua  # LSP/formatters; mason off
  ];
};
# ~/.config/nvim = LazyVim starter as plain dotfiles
# (git clone, or xdg.configFile."nvim".source = mkOutOfStoreSymlink ~/dots/nvim)
```

Why, for this user profile **[I]**:
- Reproducibility where it pays: nvim, compiler, tools, LSPs all hash-pinned and rolled back with the system; plugins pinned by lazy-lock.json. Editor plugin set is the part you *want* moving at ecosystem velocity.
- Low friction: LazyExtras, `:Lazy update`, and every LazyVim doc/keypress work unmodified; config stays byte-identical on any non-Nix box.
- The alternative extremes both fail the brief: pure LazyVim is friction-min but leaves the toolchain unpinned (and first-boot breakage is a documented rite of passage); nixvim is reproducibility-max but LazyVim is explicitly out of scope, so you'd be hand-maintaining a translation of a distribution that updates weekly.
- If you want the declarative version anyway: lazyvim-nix (tracks LazyVim releases, actively maintained through the 2026 treesitter changes) over hand-rolling the #1972 linkFarm recipe; matadaniel/LazyVim-module if you prefer nixpkgs-pinned plugins and are fine lagging upstream.
- Skip mason; supply LSPs from extraPackages (or devshells, per the Jun 2025 discourse consensus). If you truly need mason, add nix-ld — but then you're back to unpinned binaries.

## Source index (all read this session)

- LazyVim: https://www.lazyvim.org/ , https://lazyvim.github.io/installation , https://lazyvim.github.io/extras/lang/nix
- LazyVim discussion #1972: https://github.com/LazyVim/LazyVim/discussions/1972
- nixvim: repo README; issue #3071; discussion #1455; examples/lazyvim (404)
- home-manager: neovim.nix (master); issue #6625; wiki/Neovim; manual options page
- nixpkgs: pkgs/applications/editors/neovim/utils.nix (master); PR #504078; PR #530655; by-name/ne/neovim-unwrapped/package.nix (nixos-unstable)
- NixOS wiki: https://nixos.wiki/wiki/Treesitter
- Discourse: 55266 (cross-platform, Oct 2024), 65362 (Neovim in NixOS, Jun 2025), 66411 (treesitter, Jul 2025), 66971 (nixvim lazy deps, Jul 2025), 74375 (treesitter + lazy.nvim packpath, Dec 2025)
- Reddit: r/NixOS 1o8mb8t (Oct 2025), 1ollzym (Nov 2025), 1hhc99m (Dec 2024), 1km0nu0 (May 2025), 1fusa0c (Oct 2024), 1kgoxyb (May 2025); r/neovim 1oabtjv (Oct 2025)
- Modules: https://github.com/matadaniel/LazyVim-module , https://github.com/pfassina/lazyvim-nix (+ PR #96), https://github.com/azuwis/lazyvim-nixvim , https://breuer.dev/blog/nix-lazy-neovim
- Third-party aggregate (version timeline only): nixpkgs-multiverse.com, nixhub.io
