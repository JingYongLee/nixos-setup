# NixOS 26.05 hardening for a personal laptop (research, Oct 2026)

Question: what hardening should a flake-based NixOS 26.05 install use on a personal dev laptop (dual-boot with Windows/BitLocker, LUKS2 planned, home-manager already prototyped)? Deliverable: tiered checklist (baseline / recommended / paranoid-with-costs) with exact option names, tradeoffs, and sources. Not a server: no inbound services, single trusted user.

Verification key: **[V]** = read at the primary source this session (nixpkgs files read at branch `nixos-26.05`, upstream docs/repos/man pages). **[I]** = inference/synthesis. Third-party aggregators named as such. All URLs read 2026-10-24.

## 0. Headline changes that reshape 2026 advice

Two things people copy from older guides are **gone in 26.05**:

1. **`profiles/hardened.nix` was removed from nixpkgs** (PR #501199, merged 2026-03-22). The stated reasons: no consistent baseline, "may introduce unexpected breakage or degrade performance without clear benefit", "grab bag of settings". [V] https://github.com/NixOS/nixpkgs/pull/501199
2. **`linuxPackages_hardened` was removed from nixpkgs** (PR #502342, merged 2026-04-04; 26.05 release note: "`linux_hardened` kernel has been removed due to a lack of maintenance"; `linux-rt` also removed). The aliases now `throw`. If you want linux-hardened you build it yourself via the wiki's overlay recipe (see §4). [V] https://github.com/NixOS/nixpkgs/pull/502342

And the single most important maintainer statement on desktop hardening (emilazy, hardened-profile maintainer, in the removal discussion — this is the userns tradeoff in one quote): disabling unprivileged user namespaces "almost certainly significantly lowers the security of the average desktop system because it disables unprivileged user namespaces which … breaks browser sandboxing … On a server it's more likely to be net positive". [V] https://discourse.nixos.org/t/proposal-to-deprecate-the-hardened-profile/63081

## 1. Ecosystem: what exists and what practitioners actually use

- **nix-mineral** (cynicsketch, ~538 stars, GPL, active, Nix-only) — the maintained "convenient hardening" module in 2026: sysctl set, boot params, kernel-module blacklist, tmpfiles/fs hardening, entropy. Self-described **alpha software**; tiered options you switch on/off. This is the practical successor to copy-paste hardening configs. [V] https://github.com/cynicsketch/nix-mineral
- **"nixos-hardened" flake**: no maintained repo by that name surfaced in Oct 2026 searches; the old references are dead/stale. Use nix-mineral + the wiki pages instead. [I]
- **NixOS wiki** (the current canonical texts, all actively edited in 2026):
  - Security (overview/hub, edited 2026-05-01) [V] https://wiki.nixos.org/wiki/Security
  - **NixOS Hardening** — the page explicitly created after the profile removal (a contributor in PR #501199 said they'd write it); edited 2026-09-23; contains the sysctl/kernel-param/module-blacklist sets people copy. [V] https://wiki.nixos.org/wiki/NixOS_Hardening
  - Systemd/Hardening (annotated `serviceConfig` example, edited 2026-08-15) [V] https://wiki.nixos.org/wiki/Systemd/Hardening
  - Secure Boot, Lanzaboote [V]
- **Official manual**: release notes for 26.05 carry the load-bearing facts — systemd stage 1 now **default** (scripted initrd deprecated, removal in 26.11), default kernel 6.18, `networking.firewall` gained a `backend` option, new `services.reaction` module ("a modern alternative to fail2ban"). [V] https://nixos.org/manual/nixos/stable/release-notes and https://nixos.org/blog/announcements/2026/nixos-2605/
- **Practitioner split, personal vs server** [I, consistent with sources above]: on personal machines people enable firewall hygiene, FDE + TPM2, Secure Boot, usbguard, sysctl subset, and per-service systemd sandboxing. They avoid: disabling unprivileged userns (breaks browsers/flatpak/podman), SMT-off (perf), hardened kernels (maintenance lag — now forcibly, since nixpkgs dropped it). fail2ban is server-oriented; on a laptop with no listening sshd it is dead weight. Servers flip several of those.

## 2. Option inventory (names verified against `nixos-26.05`)

### Firewall / network

| Option | Default | Notes | |
|---|---|---|---|
| `networking.firewall.enable` | `true` | Simple stateful firewall, blocks unsolicited inbound. Already on by default. | [V] |
| `networking.firewall.backend` | `iptables` (or `nftables` if `networking.nftables.enable`, `firewalld` if `services.firewalld.enable`) | New enum option (`iptables\|nftables\|firewalld`). Set `networking.nftables.enable = true` to move the whole firewall to nftables. | [V] |
| `networking.nftables.enable` | `false` | Option description warns: **Docker enabled → cannot use nftables** (the classic conflict). | [V] |
| `networking.firewall.rejectPackets` | `false` | DROP (default) vs REJECT; rejecting makes scanning easier. Keep default. | [V] |
| `networking.firewall.checkReversePath` | `true` | rp_filter; note WiFi captive portals/async routing can need `loose` or `false`. | [V] |
| `networking.firewall.allowPing` | `true` | Cosmetic hardening to disable. | [V] |

Source: `nixos/modules/services/networking/firewall.nix`, `.../nftables.nix` at https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/networking/firewall.nix [V]

### SSH (you're key-only already)

| Option | Default | Notes | |
|---|---|---|---|
| `services.openssh.settings.PasswordAuthentication` | **false** (module sets it false; raw option default is `true`) | Key-only out of the box on NixOS. PAM `unixAuth` is wired to this setting, so password logins via PAM die with it. | [V] |
| `services.openssh.settings.KbdInteractiveAuthentication` | `true` | With `UsePAM`, keeps a PAM prompt channel open. Set `false` unless you run PAM 2FA. (Nuance documented by a 2026 hardened-ssh module: "PasswordAuthentication no alone is not keys-only" under PAM.) | [V option, I rec] https://github.com/LarsArtmann/nix-ssh-config |
| `services.openssh.settings.PermitRootLogin` | `"prohibit-password"` | Tighten to `"no"` if you have no root-over-ssh tooling. | [V] |
| `services.openssh.openFirewall` | `true` | On a laptop: `false` (or don't enable sshd at all). | [V] |
| `services.openssh.settings.X11Forwarding` | `false` | Already off. | [V] |

- **fail2ban on a laptop**: upstream is alive again (1.1.0 → 1.1.1, 2026-08-15; nixpkgs module maintained; `banaction` auto-switches to nftables actions when `networking.nftables.enable`). It only makes sense if sshd is reachable from beyond your LAN. 26.05 also ships `services.reaction` — "a modern alternative to fail2ban" (official release note wording). Recommendation for this machine: neither; keep sshd off the firewall. [V facts, I verdict] https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/security/fail2ban.nix, release notes [V]

### Privilege escalation: sudo vs doas in 2026

All three modules exist side by side in 26.05 (`nixos/modules/security/{sudo,doas,sudo-rs}.nix`), plus a `run0` module [V]:

- `security.sudo.enable` = `true` by default; `security.sudo.execWheelOnly` (only wheel can execute the binary — option doc cites CVE-2021-3156); `security.sudo.wheelNeedsPassword` = `true`; `extraRules` / `extraConfig`. [V]
- `security.sudo-rs.enable` — memory-safe Rust sudo; enabling it sets `security.sudo.enable = mkDefault false`. Same options family. [V]
- `security.doas.enable` = `false`; module still present but the community center of gravity moved to sudo-rs/run0. [V presence, I verdict]
- `security.run0` — configures systemd's polkit-based `run0`; `security.run0.enableSudoAlias` makes `sudo` exec `run0` (asserts sudo/sudo-rs disabled), `wheelNeedsPassword` writes a polkit rule. [V]

**Recommendation for this user**: stay on stock `sudo` (ecosystem compatibility, nothing you run expects otherwise) + `execWheelOnly = true`; or `sudo-rs` if you want the memory-safety story. Doas buys nothing in 2026. [I]

### Kernel

- **No `linuxPackages_hardened` in 26.05** (removed, §0). Stock kernel is 6.18. The wiki replacement is a DIY overlay (`linux-hardened.nix` with `buildLinux version = "6.18.44-hardened1"` + `structuredExtraConfig`): `INIT_ON_FREE_DEFAULT_ON`, `INIT_STACK_ALL_ZERO`, `ZERO_CALL_USED_REGS`, `PROC_KCORE=n`, `INET_DIAG=n`, `LEGACY_VSYSCALL_NONE`, `PANIC_TIMEOUT=-1`, `UBSAN`, IOMMU strict. [V] https://wiki.nixos.org/wiki/NixOS_Hardening
  - What the hardened set costs you [I, from those config choices + historical issues]: `INIT_ON_FREE`/`INIT_STACK_ALL_ZERO` = measurable memory/perf overhead; `INET_DIAG=n` degrades `ss`/`netstat` socket introspection; `LEGACY_VSYSCALL_NONE` breaks ancient static binaries; the patchset historically enforces module signature verification (unsigned out-of-tree modules refuse to load) and **ships `kernel.unprivileged_userns_clone=0` as its default** — i.e. browser/flatpak/podman sandboxes break unless you flip the sysctl back. Old profile-vs-patchset collisions (`page_poison=1` conflicting with the patchset, one report of a VM failing to boot) are exactly why nixpkgs dropped it. [V] https://github.com/NixOS/nixpkgs/issues/90704
- `security.protectKernelImage = true` → adds **`nohibernate`** kernel param + `kernel.kexec_load_disabled=1`. If you want hibernate on this laptop, this option is mutually exclusive with it. [V] `nixos/modules/security/misc.nix`
- `security.lockKernelModules = true` → sets `modules_disabled=1` after boot; anything that lazy-loads modules later breaks (some VPNs, exotic filesystems, new USB devices needing drivers) unless pre-listed in `boot.kernelModules`. The module auto-adds fs modules for mounted filesystems. Wiki shows the companion `boot.kernelModules` list people copy (usb_storage, gpu, nft/conntrack modules, …). [V] misc/lock-kernel-modules.nix + wiki
- `security.allowSimultaneousMultithreading = false` → `nosmt`; option doc itself says "potentially at significant performance cost" and calls the attack vector "unproven". [V]
- `security.forcePageTableIsolation = true` → `pti=on` even on Meltdown-safe CPUs. Small perf cost. [V]
- `security.virtualisation.flushL1DataCache = "always"` → `kvm-intel.vmentry_l1d_flush=always`; only matters for KVM guests, "may incur significant performance cost" (option doc). [V]
- Kernel lockdown (`boot.kernelParams = [ "lockdown=confidentiality" ]`): NixOS has no dedicated option [V absence]; the kernel's lockdown reason list includes `LOCKDOWN_HIBERNATION` (in the *integrity* section, so any lockdown mode blocks hibernation), plus kexec, /dev/mem, kprobes/perf/tracefs restrictions in confidentiality mode. Same hibernate conflict as `protectKernelImage`. [V for reason list] https://github.com/torvalds/linux/blob/master/include/linux/security.h
- **Sysctl set commonly recommended** (wiki NixOS_Hardening, verbatim source for each) [V]:
  - `kernel.kptr_restrict = 2` (hide pointers even from CAP_SYSLOG)
  - `kernel.ftrace_enabled = false`, `net.core.bpf_jit_enable = false`
  - `kernel.io_uring_disabled = 2` — cited by the wiki to the Google kCTF learnings post. **Dev caveat** [I]: any tool you use that adopts io_uring (modern DBs, some Rust/async runtimes) silently falls back or breaks; this is the one item in the list with real daily-driver risk.
  - `net.ipv4.conf.{all,default}.{rp_filter,log_martians}`, `icmp_echo_ignore_broadcasts`, `accept_redirects/secure_redirects = false` (v4+v6), `send_redirects = false`
  - Plus `boot.kernelParams = [ "slab_nomerge" "page_poison=1" "page_alloc.shuffle=1" "debugfs=off" ]` and a `boot.blacklistedKernelModules` list (rare protocols/fs). Note `page_poison=1` is for **vanilla** kernels only — collides with the hardened patchset (see above). [V]
  - `kernel.yama.ptrace_scope` (1 or 2): not on the wiki page; standard yama tradeoff — 1 blocks `gdb attach`/`strace -p` on non-child processes (annoying for a dev), 2 admin-only, 3 kills ptrace entirely. Suggest 1 if you ever attach debuggers. [I]
- `boot.blacklistedKernelModules` [V wiki], `boot.kernelModules` [V].

### User namespaces (the big NixOS-specific tradeoff)

- `security.allowUserNamespaces = false` → `user.max_user_namespaces = 0`. The module **asserts** that this conflicts with `nix.settings.sandbox = true` — i.e. NixOS itself forbids "no userns" together with a sandboxed Nix build daemon, because the Nix build sandbox uses user namespaces. Disabling userns also breaks: Chromium/Electron browser sandboxes, Flatpak/bubblewrap, rootless podman, distrobox/toolbox. This is why the hardened profile was judged net-negative on desktops (§0 quote). **Verdict for a dev laptop: keep userns on.** [V misc.nix assertion + discourse quote]
- `security.unprivilegedUsernsClone` (default `false`): only meaningful on kernels carrying the Debian/hardened `kernel.unprivileged_userns_clone` patch — option doc says "This option only works in a hardened profile". Irrelevant on stock 26.05 kernels; it's the escape hatch if you build the DIY linux-hardened overlay. [V]

### USB / Bluetooth

- `services.usbguard.enable` + friends (all [V], `nixos/modules/services/security/usbguard.nix`):
  - `services.usbguard.rules` (declarative, immutable policy — preferred over `ruleFile = "/var/lib/usbguard/rules.conf"`)
  - `services.usbguard.implicitPolicyTarget = "block"` (default), `presentDevicePolicy = "apply-policy"`, `presentControllerPolicy = "keep"` (default — important, blocking your USB controller at boot is how you brick your console)
  - `services.usbguard.IPCAllowedUsers = [ "root" ]` — add your user to control it at runtime (`usbguard list-devices`/`allow-device`)
  - `services.usbguard.deviceRulesWithPort`, `services.usbguard.dbus.enable`
  - Usage pattern [I, standard]: generate the initial policy *with all your devices attached* (`usbguard generate-policy`) so keyboard/trackpoint/receiver hashes are allowlisted, then manage new devices interactively. Classic failure: generating policy without the keyboard attached.
- `hardware.bluetooth.powerOnBoot = false` (option maps to BlueZ `Policy.AutoEnable`) — radio stays off at boot; `hardware.bluetooth.settings` for profile restrictions. Bluetooth isn't IP-firewallable; the lockdown lever is "off by default + explicit pairing". Options [V] `nixos/modules/services/hardware/bluetooth.nix`; framing [I].

### MAC: AppArmor / SELinux on a personal machine

- AppArmor: module present (`security.apparmor.{policies,includes,packages,enableCache}`, `killUnconfinedConfinables` per wiki), but wiki Security page (2026-04): "available for NixOS but … not yet been properly integrated" (links the AppArmor roadmap discourse thread). Path-based profiles fight the Nix store. **Verdict: not worth it for this desktop** beyond what services already ship. [V]
- SELinux: "possible … but proper integration does not exist"; some revived 2025 work, nothing landed. Not an option for this machine. [V] https://wiki.nixos.org/wiki/Security#SELinux

### systemd service sandboxing (system + user services)

- Convention: `systemd.services.<name>.serviceConfig = { … }` (and `systemd.user.services.<name>.serviceConfig` for user units — same keys, verified pattern in wiki examples). [V]
- The wiki's annotated baseline (all keys verified in the page, edited Aug 2026): `NoNewPrivileges`, `ProtectSystem = "strict"`, `RootDirectory = "/run/<svc>"` (pivot into tmpfs) + `BindReadOnlyPaths` (store, CA bundle, resolv.conf), `PrivateTmp/PrivateDevices/PrivateIPC/PrivateUsers`, `ProtectProc = "invisible"`, `ProtectKernel{Tunables,Logs,Modules}`, `ProtectClock/ProtectHostname/ProtectControlGroups/ProtectHome`, `RestrictAddressFamilies`, `RestrictNamespaces`, `RestrictRealtime`, `RestrictSUIDSGID`, `SystemCallFilter = [ "@system-service" ]`, `SystemCallArchitectures = "native"`, `SystemCallErrorNumber = "EPERM"`, `CapabilityBoundingSet = ""`, `SocketBindDeny = "any"` + `SocketBindAllow`, `MemoryDenyWriteExecute` (**breaks JITs: JVM, .NET, some Rust runtimes — the wiki explicitly calls this out**), `UMask`, `DevicePolicy`/`DeviceAllow`. [V] https://wiki.nixos.org/wiki/Systemd/Hardening
- Workflow tools: `systemd-analyze security <unit>` (exposure score), `systemd-analyze unit-shell <svc>` (shell inside a running service's sandbox, systemd ≥ 258), Synacktiv's `shh` helper. Upstream reference: `man systemd.exec`, `man systemd.resource-control`. [V]
- No global enforcer exists in NixOS; upstream hardening is per-module (there's also `security/systemd-confinement.nix` for wrapping units). Per-service opt-in is the honest state. [V presence, I framing]

### Polkit hygiene

- `security.polkit.adminIdentities` default `[ "unix-group:wheel" ]`; `security.polkit.extraConfig` for rules. Hygiene for a single-user laptop: leave the password prompt requirement alone (no `auth_admin` bypasses), don't accumulate NOPASSWD-style rules, remember `run0` also goes through polkit. `soteria.nix` (alternative polkit daemon) exists in tree. [V options; hygiene rules I]

### Core dumps / ptrace / misc

- `systemd.coredump.enable = false` (default `true`) — kills systemd-coredump; alternatively `systemd.coredump.settings.Coredump.Storage = "none"`. Rationale: coredumps can capture secrets from process memory into the journal. [V option] `nixos/modules/system/boot/systemd/coredump.nix`
- `boot.kernel.sysctl."fs.suid_dumpable" = 0` — kernel default already 0; belt-and-braces. [I]
- ptrace: see `kernel.yama.ptrace_scope` above. [I]
- `nix.settings.trusted-users` default `[ "root" ]` (already tight — resist adding `@wheel` casually: trusted-users can read the store and inject settings). `nix.settings.allowed-users = [ "@users" ]` is the wiki's tightening of the default `["*"]`. Tradeoff: any other account building things needs an explicit entry. [V defaults in `nixos/modules/config/nix.nix` + wiki]
- `environment.memoryAllocator.provider = "scudo" | "graphene-hardened"` — wiki-suggested hardened allocators; "some programs may not work". [V wiki, rec I]
- `services.fwupd` for firmware updates (module present in 26.05; relevant to the "keep firmware updated" precondition for Secure Boot below). [V presence, I rec]

## 3. Full-disk encryption on 26.05

- **LUKS2 + argon2id is the cryptsetup default since 2.4.0 (2021)** — nothing to configure for new volumes; verify per-volume with `cryptsetup luksDump` (KDF: argon2id). [V] https://www.kernel.org/pub/linux/utils/cryptsetup/v2.4/v2.4.0-rc0-ReleaseNotes
- **systemd stage 1 is the default in 26.05** (scripted initrd deprecated, removed in 26.11). This is what makes the systemd-cryptenroll path first-class. Migration note from release notes: with LUKS, make sure `fileSystems."/".device` is `/dev/mapper/<name>` matching your `boot.initrd.luks.devices` entry, or add `x-systemd.device-timeout=infinity`. [V]
- **TPM2 auto-unlock**: enroll at runtime, no NixOS option needed for the key itself:
  ```
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2
  ```
  Default PCR binding when unspecified is PCR 7 (secure-boot policy state) per crypttab(5). Optionally `--tpm2-with-pin=true` (PIN is Argon2id-hardened, TPM becomes a second factor; wrong PINs trip the TPM dictionary-attack lockout). Always keep a passphrase slot as fallback. [V] https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html and crypttab(5)
- NixOS plumbing [V]:
  - `boot.initrd.systemd.tpm2.enable` — pulls the `libcryptsetup-token-systemd-tpm2.so` token and `tpm2.target` ordering into the initrd (option referenced in `luksroot.nix` @ 26.05).
  - `boot.initrd.luks.devices.<name>.crypttabExtraOpts = [ "tpm2-device=auto" ]` — appends options to the generated crypttab line; the module's own deprecation text for old hardware-key options says exactly this ("configure the corresponding crypttab(5) options with boot.initrd.luks.devices.<name>.crypttabExtraOpts").
  - legacy per-device keyFile/yubikey options are deprecated for systemd stage 1; use cryptenroll instead. [V]
- **Dual-boot Windows BitLocker on the same TPM — does it work?** Yes; they don't collide:
  - systemd-cryptenroll stores its sealed key blob **inside the LUKS2 JSON token header** on disk; BitLocker stores its own VMK sealed to its TPM NV index + PCR validation profile (PCR 7/11). Neither evicts or overwrites the other; both just read PCRs. [V mechanisms: cryptenroll man + Microsoft recovery overview]
  - What triggers BitLocker recovery (Microsoft's own list): secure boot on/off toggles, PK/KEK/db/dbx changes, TPM clear/disable, firmware updates, boot-manager changes, partition-table changes. I.e., **your Secure Boot enrollment event will trip recovery exactly once** — lanzaboote's official dual-boot page tells you to export recovery keys beforehand and confirm the PCR change is intended at next boot. [V] https://nix-community.github.io/lanzaboote/explanation/windows-dual-boot-bitlocker.html + https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/recovery-overview
  - sbctl-side equivalent practice (Arch wiki/sbctl wiki): `sbctl enroll-keys --microsoft` keeps Microsoft certs so Windows keeps booting; without Secure Boot, TPM-sealed BitLocker prompts for the 48-digit key **every** boot. [V] https://github.com/foxboron/sbctl/wiki/Linux-Windows-Dual-Boot-with-Windows-Bitlocker
  - `boot.loader.systemd-boot.rebootForBitlocker = true` (labelled EXPERIMENTAL in the option): selecting Windows from systemd-boot sets `BootNext` and reboots so the firmware starts Windows directly with PCRs in expected states. Relevant since lanzaboote rides systemd-boot. [V] option in `systemd-boot.nix` @ 26.05
  - Firmware/UEFI updates change PCR0/7 → LUKS TPM auto-unlock stops unsealing (falls back to passphrase); re-enroll after updates (`--wipe-slot=tpm2` then re-enroll). Same class of event also makes BitLocker prompt. [V practitioner guide: https://nix-config.bricked.dev/features/tpm-disk-unlock]
- **Swap**: `swapDevices = [ { device = "/dev/disk/by-partuuid/..."; randomEncryption.enable = true; } ]`. Module-verified warnings: **random key = no hibernation** (image would be lost), and use `by-partuuid` (UUID/label are erased every boot). Cipher default `aes-xts-plain64`. If you want hibernate: persistent LUKS swap with a keyfile (weaker) or skip swap entirely and use `zramSwap` (module present). [V] `nixos/modules/config/swap.nix`
- **/tmp**: `boot.tmp.useTmpfs = true` (default `false`; option text warns **large Nix builds can fail if tmpfs too small** — size with `boot.tmp.tmpfsSize`) or `boot.tmp.cleanOnBoot = true` on a persistent /tmp. `noexec` on /tmp via `fileSystems."/tmp".options` is possible; occasional breakage from tools that exec from TMPDIR. [V options, noexec caveat I]

## 4. Secure Boot: lanzaboote in 2026

- Status: **v1.2.0 released 2026-09-26** (maintainer nikstur), under nix-community, active issue tracker through Oct 2026. Wiki still carries a "still in development" warning; meanwhile `lzbt` is packaged in nixpkgs (the module's `package` defaults to `pkgs.lzbt`), measured boot via **systemd-pcrlock** and boot counting have landed, and there's an active nixpkgs tracking issue for end-to-end boot security (#549372, opened by emilazy 2026-08) plus an All Systems Go 2026 talk on NixOS measured boot. Read: mature enough for daily use, moving parts still settle (open issues: initrd-secrets not resynced unless generation changes #644; fwupd EFI app dir #591; multi-ESP auto-enroll #651). [V]
- Setup surface (options verified in `nix/modules/lanzaboote.nix` @ master): `boot.lanzaboote.enable`, `boot.lanzaboote.pkiBundle` (sbctl-style keys), **`boot.lanzaboote.<autoGenerateKeys>.enable`** (auto-generates keys if absent; there's also `autoReboot`, `allowBrickingMyMachine`, `includeChecksumsFromTPM`), `boot.lanzaboote.configurationLimit`, and — the dual-boot answer — **`includeMicrosoftKeys` defaults to `true`**, i.e. Microsoft certs are kept in db so Windows keeps booting. `boot.lanzaboote.measuredBoot.{enable,pcrs,pcrlockDirectory}` for measured boot (community doc: pcrlock currently caps `configurationLimit` ≤ 8; PCRs 0+4+7 typical; PCRs 1-3 flaky on some hardware). [V options; pcrlock constraint V-via-community-doc https://zemdregon.github.io/nix-docs/09-nixos/configuration/tpm-and-measured-boot/]
- Preconditions for SB to mean anything (lanzaboote README "Caveats"): **BIOS/UEFI admin password**, integrity protection after boot (FDE), current firmware. Also: OEM/third-party keys in db weaken SB (wiki notes removing them can brick OpROM-dependent laptops). [V]
- Alternative in-tree since 25.11: `boot.loader.limine.secureBoot.enable` (Limine signs + hashes kernels into config). Smaller ecosystem than lanzaboote. [V release notes]
- **vs disabling Secure Boot**: with BitLocker in the picture, disabling SB means the recovery-key prompt at *every* Windows boot (sbctl wiki). With lanzaboote + `includeMicrosoftKeys` + PCR7-bound LUKS, Secure Boot actually does work for both OSes. Recommendation: enable it. [V facts, I verdict]
- Interaction with TPM2 LUKS: PCR 7 = secure-boot policy state → your LUKS TPM enrollment is bound to "Secure Boot stays on with these exact db keys". Disabling SB later just falls back to your passphrase; BitLocker throws a recovery prompt. [V semantics, I consequence]

## 5. Impermanence / tmpfs root on a daily driver

- Project: nix-community/impermanence, maintainer talyz, ~1.9k stars, 205 commits, MIT — the standard. Provides `nixosModules.impermanence` (`environment.persistence."/persist"`) and the integrated `home.persistence` (requires the HM NixOS module **and** the NixOS persistence module together — README is explicit). Options: `enable` (default true), `hideMounts`, `allowTrash`, `directories`/`files` as strings or submodules (`user`, `group`, `mode`, `parentDirectory`, `method = "auto"|"symlink"`), and `users.<name>` for home-relative paths. Mark persistent volume `neededForBoot = true`. [V] https://github.com/nix-community/impermanence (README.org, read Oct 2026)
- Wipe strategies, both shown in the README: tmpfs root (`fsType = "tmpfs"`, `size=25%` — simplest, but OOM/disk-full risk for big files and crash loses unsaved state), or btrfs subvol reset via an initrd `wipe-root` service that moves the old root to `old_roots/` and prunes >30 days (keeps rollback safety). Second one is the better daily-driver shape. [V README]
- **State people forget** (composite from a year-of-impermanence post + README example + reddit failure reports):
  - System: `/etc/machine-id`, `/etc/ssh/ssh_host_*` (else host keys rotate every boot), `/var/log`, `/var/lib/bluetooth` (pairings), `/etc/NetworkManager/system-connections`, `/var/lib/systemd/coredump`, `/var/lib/colord` (needs uid/gid/mode), `/var/lib/nixos`.
  - User: shell history, browser profile dir, `~/.ssh`, `~/.gnupg`, `~/.local/share/keyrings`, game saves/Steam, app-local SQLite DBs.
  - Passwords: the classic first-boot failure (reddit): login "incorrect password" after install because `/etc/shadow` wasn't persisted — either persist it or (better) set `users.mutableUsers = false` and declare passwords hashed in the flake. [V reddit symptom, V blog lists, I fix]
  - Practitioner verdicts: "The first week is rough. You will forget to persist something important." / "I can't go back to accumulating state on a root partition." Also: configure Nix's build dir off tmpfs or builds fill RAM (reddit). [V] https://infernalcode.com/posts/on-living-with-tmpfs/
- Opinionated templates people copy: `lowcache/voln` (the blog above), `willbush.dev` guide (tmpfs root + LUKS + flakes) and `etu`'s tmpfs-as-root and `grahamc`'s "Erase your darlings" (ZFS, the origin) — all linked from the README [V]; `keenanweaver/nix-config` (tmpfs root + btrfs + LUKS + impermanence-equivalent + nix-mineral + lanzaboote + sops — the closest composite to this user's target stack) [V]; `saylesss88/my-flake` impermanence guide (recommended in that reddit thread) [V]; wiki's "Comparison of NixOS setups" table filters by "Opt-in state". [V]
- **Worth it for this user?** With flake + home-manager already prototyped, impermanence is the natural next step and low marginal cost; the tax is the first fortnight of "forgot to persist X". Recommend btrfs-rollback variant over pure tmpfs root for a laptop (crash safety, no RAM pressure), `users.mutableUsers = false`, and per-user persistence via `home.persistence` since HM is already in the stack. [I]

## 6. Tiered checklist

### Tier 0 — Baseline (no functionality cost)

| # | Action | Options | Tradeoff | |
|---|---|---|---|---|
| 1 | Keep firewall on; no inbound | `networking.firewall.enable = true` (default); `services.openssh.openFirewall = false` or sshd off | none | [V] |
| 2 | SSH key-only, tight | `services.openssh.settings = { PasswordAuthentication = false; KbdInteractiveAuthentication = false; PermitRootLogin = "no"; }` | none (already key-only) | [V+I] |
| 3 | Core dumps off | `systemd.coredump.enable = false` | lose post-mortem debugging of crashes (journal coredumps) | [V] |
| 4 | Minimal sysctl set | `boot.kernel.sysctl."kernel.kptr_restrict" = 2; "kernel.dmesg_restrict" = 1; "kernel.yama.ptrace_scope" = 1` | `dmesg` needs root; ptrace of non-children needs root (dev annoyance is 1, acceptable) | [V wiki + I] |
| 5 | Nix daemon tight | `nix.settings.allowed-users = [ "@users" ]` (trusted-users stays `["root"]`) | other accounts need explicit entries to build | [V] |
| 6 | Declarative users | `users.mutableUsers = false` + hashed passwords in flake | `passwd` at runtime stops working (by design) | [I] |
| 7 | Firmware updates | `services.fwupd.enable = true` | none | [V-presence/I-rec] |

### Tier 1 — Recommended for this user (dev laptop, dual-boot Windows)

| # | Action | Options | Tradeoff | |
|---|---|---|---|---|
| 1 | nftables backend | `networking.nftables.enable = true` | **incompatible with Docker's iptables assumptions** — pick one; if you Docker daily, stay iptables | [V] |
| 2 | FDE + TPM2 auto-unlock | LUKS2 (argon2id default); `boot.initrd.luks.devices.<n>.crypttabExtraOpts = [ "tpm2-device=auto" ]; boot.initrd.systemd.tpm2.enable = true;` + runtime `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7` (keep passphrase slot) | firmware updates → re-enroll; PCR7 binding means SB toggles invalidate TPM unlock (falls back to passphrase) | [V] |
| 3 | Encrypted swap (or zram) | `swapDevices = [ { device = "/dev/disk/by-partuuid/…"; randomEncryption.enable = true; } ]` or `zramSwap.enable = true` | randomEncryption ⇒ **no hibernate** | [V] |
| 4 | tmpfs /tmp | `boot.tmp.useTmpfs = true; boot.tmp.tmpfsSize = "25%";` | size it or big Nix builds fail (option doc) | [V] |
| 5 | Secure Boot via lanzaboote | `boot.lanzaboote.enable = true; boot.lanzaboote.pkiBundle = "/var/lib/sbctl";` (`includeMicrosoftKeys` default true; `autoGenerateKeys.enable` for frictionless setup); **export BitLocker recovery key first** — expect one recovery prompt at first post-enrollment Windows boot; consider `boot.loader.systemd-boot.rebootForBitlocker = true` | key management is yours; UEFI password required for it to matter | [V] |
| 6 | usbguard | `services.usbguard = { enable = true; rules = <generated policy incl. built-in keyboard/pointers>; IPCAllowedUsers = [ "root" "<you>" ]; }` | new USB devices need explicit allow (that's the point); generate initial policy with all legit devices attached | [V+I] |
| 7 | sudo hygiene | `security.sudo.execWheelOnly = true` (or `security.sudo-rs.enable = true`) | none for single-admin machine | [V] |
| 8 | Extended sysctl (wiki set) | wiki NixOS_Hardening set minus pain points: rp_filter/redirect/martians, `kernel.ftrace_enabled = false`, `net.core.bpf_jit_enable = false`, `kernel.kptr_restrict = 2`; `boot.kernelParams = [ "slab_nomerge" "page_alloc.shuffle=1" "debugfs=off" ]`; module blacklist | `io_uring_disabled = 2` only if you accept occasional dev-tool breakage; skip `page_poison=1` (negligible on modern kernels, breaks nothing, but keep list minimal) | [V] |
| 9 | Sandbox your own services | `systemd.services.<n>.serviceConfig` baseline from wiki Systemd/Hardening; `systemd-analyze security <unit>` to score | `MemoryDenyWriteExecute` off for JIT workloads; debugging via `systemd-analyze unit-shell` | [V] |
| 10 | Bluetooth off at boot | `hardware.bluetooth.powerOnBoot = false` | re-enable when needed | [V] |
| 11 | Impermanence (btrfs rollback flavor) | `impermanence.nixosModules.impermanence` + `environment.persistence."/persist"` + `home.persistence` + `users.mutableUsers = false` | first weeks: forgotten-state incidents; keep `old_roots` pruning | [V+I] |

### Tier 2 — Paranoid, with real costs (know what breaks)

| # | Action | Options | Cost / what breaks | |
|---|---|---|---|---|
| 1 | linux-hardened DIY overlay | wiki overlay recipe (6.18.44-hardened1), `boot.kernelPackages` | You own kernel updates (nixpkgs dropped it for maintenance-lag reasons — that's the warning label). `INIT_ON_FREE`/stack-init perf hit; `INET_DIAG=n` degrades `ss`; unsigned modules refused; patchset default disables unpriv userns → flip `security.unprivilegedUsernsClone = true` to unbreak browsers/flatpak/podman | [V+I] |
| 2 | Kernel image protection | `security.protectKernelImage = true` | **hibernate disabled** (`nohibernate`); kexec dead | [V] |
| 3 | Lock kernel modules | `security.lockKernelModules = true` + exhaustive `boot.kernelModules` | runtime modprobe dead; forgot-a-module = device doesn't work until reboot+rebuild | [V] |
| 4 | Disable userns | `security.allowUserNamespaces = false` | **NixOS assertion conflict with `nix.settings.sandbox`;** breaks browser/flatpak/podman sandboxes; maintainer position: net-negative on desktops | [V] |
| 5 | Kernel lockdown | `boot.kernelParams = [ "lockdown=confidentiality" ]` | hibernate blocked (LOCKDOWN_HIBERNATION), perf/kprobes/ftrace/kexec restricted | [V] |
| 6 | SMT off | `security.allowSimultaneousMultithreading = false` | ~20-30% multi-thread perf; option doc calls the vector "unproven" | [V] |
| 7 | PTI always | `security.forcePageTableIsolation = true` | syscall/TLB overhead on unaffected CPUs | [V] |
| 8 | L1 flush for VMs | `security.virtualisation.flushL1DataCache = "always"` | VM-entry cost; only relevant if you run KVM guests | [V] |
| 9 | io_uring off | `boot.kernel.sysctl."kernel.io_uring_disabled" = 2` | any io_uring-adopting tool breaks — real risk for a systems engineer evaluating modern storage code | [V wiki, I risk] |
| 10 | Hardened allocator | `environment.memoryAllocator.provider = "scudo"` | "some programs may not work" (wiki) | [V] |
| 11 | AppArmor | `security.apparmor.enable = true; security.apparmor.killUnconfinedConfinables = true;` | little real coverage on NixOS desktop (integration immature); mostly noise | [V] |
| 12 | nix-mineral module | `nix-mineral.enable = true` + tiers | it IS the curated paranoid tier list; alpha software, expect occasional breakage on unstable | [V] |

## 7. Source index (primary)

nixpkgs @ `nixos-26.05` (read via raw.githubusercontent): `nixos/modules/services/networking/firewall.nix`, `nftables.nix`, `services/networking/ssh/sshd.nix`, `services/security/usbguard.nix`, `fail2ban.nix`, `security/{sudo,doas,sudo-rs,misc,apparmor,polkit,run0,lock-kernel-modules}.nix`, `system/boot/luksroot.nix`, `system/boot/tmp.nix`, `system/boot/systemd/coredump.nix`, `system/boot/loader/systemd-boot/systemd-boot.nix`, `config/swap.nix`, `config/nix.nix`, `services/hardware/bluetooth.nix` — https://github.com/NixOS/nixpkgs/tree/nixos-26.05/nixos/modules

- NixOS 26.05 release notes / announcement: https://nixos.org/manual/nixos/stable/release-notes, https://nixos.org/blog/announcements/2026/nixos-2605/
- Hardened profile removal: https://github.com/NixOS/nixpkgs/pull/501199 + https://discourse.nixos.org/t/proposal-to-deprecate-the-hardened-profile/63081
- linux_hardened removal: https://github.com/NixOS/nixpkgs/pull/502342
- Wiki: https://wiki.nixos.org/wiki/Security, /wiki/NixOS_Hardening, /wiki/Systemd/Hardening, /wiki/Secure_Boot, /wiki/Lanzaboote
- nix-mineral: https://github.com/cynicsketch/nix-mineral
- Lanzaboote: https://github.com/nix-community/lanzaboote (module `nix/modules/lanzaboote.nix` @ master), https://nix-community.github.io/lanzaboote/explanation/windows-dual-boot-bitlocker.html, releases (v1.2.0, 2026-09-26), nixpkgs tracking https://github.com/NixOS/nixpkgs/issues/549372, ASG 2026 talk https://cfp.all-systems-go.io/all-systems-go-2026/talk/QDB7AL/
- systemd: https://www.freedesktop.org/software/systemd/man/latest/crypttab.html, /systemd-cryptenroll.html
- BitLocker: https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/recovery-overview; https://github.com/foxboron/sbctl/wiki/Linux-Windows-Dual-Boot-with-Windows-Bitlocker
- cryptsetup argon2id default: https://www.kernel.org/pub/linux/utils/cryptsetup/v2.4/v2.4.0-rc0-ReleaseNotes
- Kernel lockdown reasons: https://github.com/torvalds/linux/blob/master/include/linux/security.h
- Impermanence: https://github.com/nix-community/impermanence; practitioner posts: https://infernalcode.com/posts/on-living-with-tmpfs/, https://willbush.dev/blog/impermanent-nixos/, https://grahamc.com/blog/erase-your-darlings, https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/
- TPM unlock ops guide: https://nix-config.bricked.dev/features/tpm-disk-unlock; measured-boot community doc: https://zemdregon.github.io/nix-docs/09-nixos/configuration/tpm-and-measured-boot/
- fail2ban upstream: https://github.com/fail2ban/fail2ban/blob/1.1.1/ChangeLog
