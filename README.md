# bubblebox

`box` creates an ephemeral Bubblewrap workspace. The host filesystem is visible
read-only; configured workspace paths, `/tmp`, `/run`, and `/nix/store` are the
only writable mounts.

## Install and use

Run directly from this repository:

```sh
nix run . -- -f ./chadlands_kb.yml
nix run . -- -f ./chadlands_kb.yml -- opencode
```

Or install `box` into your Nix profile:

```sh
nix profile install .
box -f ./chadlands_kb.yml -- opencode
```

## Configuration

The configuration is a non-empty YAML mapping from a workspace name to an
existing host file or directory. Names may contain letters, numbers, `.`, `_`,
and `-`; each becomes a writable mount at `/workspace/<name>`.

```yaml
chadlands: /home/ogle/src/chadlands
knowledge-base: /home/ogle/src/chadlands_kb.yml
```

Without a command after `--`, `box` opens an interactive shell in `/workspace`.

## Scope

This is a convenience sandbox, not a hardened security boundary. It preserves
the host network and environment, and intentionally exposes `/nix/store` as a
read-write mount so Nix-backed project tooling can run. The host home directory
is read-only. On NixOS, `/run/current-system` and `/run/wrappers` are read-only
submounts so inherited system tools remain available while the rest of `/run`
stays private.

The host pseudo-terminal filesystem (`/dev/pts`) is also mounted so interactive
terminal applications such as OpenCode retain their controlling terminal.

XDG cache, data, state, and runtime directories are redirected into private
`/tmp` paths. This prevents applications from inheriting stale host runtime
state while leaving the rest of the home overlay available.
