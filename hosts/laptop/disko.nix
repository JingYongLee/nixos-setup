# Declarative disk for laptop. Pattern A (disko's dual-boot-safe form):
# each partition is its own "disk" entry so disko never owns the GPT and
# the Windows partitions are simply never referenced.
#
# Run with:  disko --mode format,mount --flake .#laptop
# NEVER with destroy modes: /dev/nvme0n1 is the shared Windows disk.
#
#   nvme0n1p1  260M  Windows ESP     (untouched)
#   nvme0n1p2   16M  MSR             (untouched)
#   nvme0n1p3  226G  Windows NTFS    (untouched)
#   nvme0n1p4    2G  Linux ESP       (wipefs'd first; formatted fresh here)
#   nvme0n1p5  248G  old EndeavourOS -> LUKS2 + btrfs NixOS root
#   nvme0n1p6    1G  Windows recovery(untouched)
{
  ...
}:
{
  disko.devices = {
    disk = {
      root = {
        device = "/dev/nvme0n1p5"; # fixed single-NVMe laptop
        type = "disk";
        content = {
          type = "luks";
          name = "luksroot";
          settings = {
            allowDiscards = true;
            # TPM2 auto-unlock is deliberately NOT enrolled yet: PCR
            # measurements are only stable with Secure Boot on, which is
            # off. Enroll later alongside lanzaboote if we go that way.
          };
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/root" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                ];
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                ];
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                ];
              };
              "/persist" = {
                mountpoint = "/persist";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                ];
              };
            };
          };
        };
      };

      esp = {
        device = "/dev/nvme0n1p4";
        type = "disk";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
        };
      };
    };
  };
}
