#!/usr/bin/env bash
# Provision the vm domain under qemu:///system and boot the NixOS minimal
# installer ISO. Idempotent per virt-install semantics: the domain must not
# already exist. A fresh domain and disk: the predecessor nixvm stays
# untouched as the known-good baseline.
set -euo pipefail

# Host-side prerequisites (once, on the hypervisor host): the new repo
# cloned at ~/workspace/nixos-setup (rename the old checkout to
# nixos-setup-legacy first; GitHub redirects cover its remote either way).
ISO="${ISO:-/tmp/opencode/nixos-iso/nixos-minimal-26.05-x86_64.iso}"
REPO="${REPO:-$HOME/workspace/nixos-setup}"

[[ -f "$ISO" ]] || { echo "ISO not found: $ISO" >&2; exit 1; }

virsh --connect qemu:///system net-start default 2>/dev/null || true
virsh --connect qemu:///system net-autostart default >/dev/null

# QXL is the SPICE-native video device (virtio-gpu dumb-buffer scanout
# stalled under SPICE client attach on this host). QXL advertises
# 1024x768 as preferred; the guest session forces 1920x1080.
VIDEO_ARGS=(
  --video qxl --graphics spice,listen=none
)

virt-install \
  --connect qemu:///system \
  --name vm \
  --memory 8192 --vcpus 8 --cpu host-passthrough \
  --machine q35 --boot uefi \
  --disk pool=default,size=40,format=qcow2,bus=virtio,boot.order=1,cache=writeback,discard=unmap \
  --cdrom "$ISO" \
  --network network=default,model=virtio \
  "${VIDEO_ARGS[@]}" \
  --channel unix,target_type=virtio,name=org.qemu.guest_agent.0 \
  --console pty,target_type=virtio \
  --input tablet,bus=virtio \
  --rng /dev/urandom,model=virtio \
  --filesystem source.dir="$REPO",target.dir=nixos-setup,driver.type=virtiofs \
  --memorybacking source.type=memfd,access.mode=shared \
  --os-variant nixos-26.05 \
  --noautoconsole \
  --wait 0
