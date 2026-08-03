# bubblebox

`box` creates an ephemeral Bubblewrap workspace. Most of the host filesystem is
read-only, the real home directory is hidden, and configured workspace paths
are writable host-backed mounts. `/workspace`, `/tmp`, and `/run` are private.
`/nix/store` remains writable so Nix-backed project tooling can run.

## Install and use

```sh
nix run . -- -f ./bubblebox.yml
nix run . -- -f ./bubblebox.yml -- opencode
nix profile install .
box -f ./bubblebox.yml -- opencode
```

Without a command after `--`, `box` opens an interactive shell in
`/workspace`. Arbitrary commands and arguments are passed unchanged.

## Configuration

Configuration is structured YAML. `workspace` is required and must be a
non-empty mapping. Each value is a scalar path to an existing regular file or
directory, mounted read-write at `/workspace/<name>`.

`access` is optional. Its only keys are booleans `ssh` (default `false`) and
`opencode` (default `true`). Unknown keys and names reserved by Bubblebox,
including `AGENTS.md`, are rejected.

```yaml
workspace:
  chadlands: /home/ogle/src/chadlands
  knowledge-base: /home/ogle/src/chadlands_kb.yml
access:
  opencode: true
  ssh: false
```

When OpenCode access is enabled, its config, data, cache, and state directories
are created if needed and mounted read-write from the host. With it disabled,
those directories remain private and ephemeral. A host `~/.gitconfig` and
`~/.nix-profile`, when present, are mounted read-only; the profile's `bin` is
prepended to the inherited `PATH`.

The generated read-only `/workspace/AGENTS.md` records each sandbox path, host
path, type, and persistence behavior. It warns that files written directly to
the workspace root are ephemeral and instructs tools to read nested
`AGENTS.md` files. `AGENTS.md` is therefore a reserved workspace name. `HOME`
is `/workspace`, with standard XDG directories set to private workspace/runtime
paths. SSH agent forwarding is opt-in and requires `SSH_AUTH_SOCK` to be a
socket; only that socket is exposed. When SSH access is enabled, Bubblebox
copies the host system `ssh_config` without `Include` directives. Included
files can appear incorrectly owned inside an unprivileged user namespace and
are rejected by OpenSSH; user SSH configuration and private keys remain hidden.
The forwarded agent appears inside the sandbox as `/run/ssh-agent.sock`; this is
a bind of the host socket and exposes the same agent identities despite the
different path.

## Scope

This is a convenience sandbox, not a hardened security boundary. Networking is
shared with the host, and Nix daemon visibility and NixOS runtime profiles are
preserved. The sandbox uses private proc, dev, tmp, and run mounts and does not
bind the host's `/dev/pts`; inherited interactive terminals should continue to
work without exposing the broad host pseudo-terminal tree. If
`/etc/resolv.conf` points into `/run`, its contents are copied to the matching
private runtime path so systemd-resolved search domains and Tailscale MagicDNS
remain available.

## Testing

`nix flake check` performs syntax and ShellCheck validation. The behavioral
suite must run outside a Nix build sandbox because it creates nested namespaces
and exercises the host Nix daemon and store:

```sh
nix build
./tests/test-box.sh ./result/bin/box
```
