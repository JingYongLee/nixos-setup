#!/usr/bin/env python3
"""Drive the NixOS installer's autologin console (hvc0) over `virsh console`
long enough to drop the host SSH public key for the `nixos` and `root`
users of the live environment. After this, nixos-anywhere can reach the
installer over SSH on the libvirt NAT network.

Stdlib only: pty + select against `virsh console vm --force`.
"""

import os
import pty
import select
import sys
import time

VM = "vm"
PUBKEY_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "keys", "jingyonglee.pub"
)


def main() -> int:
    with open(PUBKEY_PATH) as f:
        pubkey = f.read().strip()

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(
            "virsh",
            ["virsh", "--connect", "qemu:///system", "console", VM, "--force"],
        )

    buf = b""

    def drain(timeout_s: float = 1.0) -> bytes:
        """Consume whatever arrives within the timeout."""
        nonlocal buf
        got = b""
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            r, _, _ = select.select([fd], [], [], max(0.0, deadline - time.time()))
            if not r:
                continue
            chunk = os.read(fd, 4096)
            if not chunk:
                break
            buf += chunk
            got += chunk
        sys.stdout.write(got.decode(errors="replace"))
        sys.stdout.flush()
        return got

    def wait_for(token: bytes, timeout_s: float) -> bool:
        """Wait until token appears in the stream (searches cumulative buf)."""
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            if token in buf:
                return True
            if not drain(2.0):
                continue
        return token in buf

    def send(line: str) -> None:
        os.write(fd, line.encode() + b"\r")
        drain(0.5)

    # Wake the autologin shell and wait for its prompt.
    time.sleep(2)
    send("")
    if not wait_for(b"nixos@nixos", timeout_s=120):
        print("\nERROR: installer prompt never appeared", file=sys.stderr)
        os.kill(pid, 15)
        return 1

    marker = "BOOTSTRAP_DONE"
    send(
        f"mkdir -p ~/.ssh && echo '{pubkey}' >> ~/.ssh/authorized_keys"
        " && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    )
    send(f"echo '{pubkey}' | sudo tee -a /root/.ssh/authorized_keys >/dev/null")
    send(f"sleep 1 && echo {marker}_$((1+1))")
    if not wait_for(f"{marker}_2".encode(), timeout_s=60):
        print("\nERROR: bootstrap commands never completed", file=sys.stderr)
        os.kill(pid, 15)
        return 1

    # Detach from the console (ctrl-]) and end the virsh process.
    os.write(fd, b"\x1d")
    time.sleep(1)
    os.kill(pid, 15)
    print("\nBootstrap complete: SSH keys installed on the live installer.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
