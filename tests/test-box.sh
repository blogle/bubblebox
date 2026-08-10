#!/usr/bin/env bash
set -euo pipefail

box=${1:-"$(dirname "$0")/../box"}
[[ -x "$box" ]] || { printf 'box executable not found: %s\n' "$box" >&2; exit 1; }
repo=$(realpath "$(dirname "$0")/..")

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/dir with spaces"
mkdir -p "$tmp/home/.nix-profile/bin"
mkdir -p "$tmp/home/.ssh"
printf '# Nested project instructions\n' > "$tmp/dir with spaces/AGENTS.md"
printf 'fixture\n' > "$tmp/file with spaces"
printf 'tab fixture\n' > "$tmp/file$(printf '\t')name"
printf '[user]\n\tname = Bubble Box\n' > "$tmp/home/.gitconfig"
printf '# known hosts fixture\n' > "$tmp/home/.ssh/known_hosts"
cat > "$tmp/home/.nix-profile/bin/profile-tool" <<'EOF'
#!/bin/sh
printf 'profile fixture\n'
EOF
chmod +x "$tmp/home/.nix-profile/bin/profile-tool"

cat > "$tmp/config.yml" <<EOF
workspace:
  directory: "$tmp/dir with spaces"
  file: "$tmp/file with spaces"
  repository: "$repo"
  tabbed: "$tmp/file\tname"
access:
  opencode: false
  ssh: false
EOF

# The variables in this script are intentionally expanded by the inner shell.
# shellcheck disable=SC2016
HOME="$tmp/home" HOST_HOME="$tmp/home" HOST_PID="$$" PATH="$PATH" "$box" -f "$tmp/config.yml" -- sh -eu -c '
  test "$HOME" = /workspace
  test "$PWD" = /workspace
  test ! -e "$HOST_HOME"
  test ! -e "/proc/$HOST_PID"
  test "$XDG_CONFIG_HOME" = /workspace/.config
  test "$(stat -c %a "$XDG_RUNTIME_DIR")" = 700
  test -r /etc/resolv.conf
  test -d /workspace/directory
  test -r /workspace/directory/AGENTS.md
  test "$(cat /workspace/file)" = fixture
  test "$(cat "/workspace/tabbed")" = "tab fixture"
  test -d /workspace/.config/opencode
  test -z "${SSH_AUTH_SOCK-}"
  test -r /workspace/AGENTS.md
  grep -F "top-level \`/workspace\` directory is ephemeral" /workspace/AGENTS.md >/dev/null
  grep -F "/workspace/directory" /workspace/AGENTS.md >/dev/null
  grep -F "Read its nested" /workspace/AGENTS.md >/dev/null || grep -F "read its nested" /workspace/AGENTS.md >/dev/null
  test "$(profile-tool)" = "profile fixture"
  grep -F "Bubble Box" /workspace/.gitconfig >/dev/null
  ! printf changed 2>/dev/null >>/workspace/AGENTS.md
  ! printf changed 2>/dev/null >>/workspace/.gitconfig
  ! printf changed 2>/dev/null >>/workspace/.nix-profile/bin/profile-tool
  printf persisted > /workspace/directory/result
  printf ephemeral > /workspace/root-result
  nix store info --store daemon >/dev/null
  nix flake metadata path:/workspace/repository >/dev/null
'

test "$(cat "$tmp/dir with spaces/result")" = persisted
test ! -e "$tmp/home/root-result"

cat > "$tmp/default-access.yml" <<EOF
workspace:
  directory: "$tmp/dir with spaces"
EOF

HOME="$tmp/home" PATH="$PATH" "$box" -f "$tmp/default-access.yml" -- sh -eu -c '
  test -d /workspace/.config/opencode
  printf state > /workspace/.local/state/opencode/test-state
'
test "$(cat "$tmp/home/.local/state/opencode/test-state")" = state

cat > "$tmp/bad-access.yml" <<EOF
workspace:
  directory: "$tmp/dir with spaces"
access:
  ssh: "true"
EOF
if HOME="$tmp/home" PATH="$PATH" "$box" -f "$tmp/bad-access.yml" -- true 2>"$tmp/error"; then
  printf 'expected string access.ssh to fail\n' >&2
  exit 1
fi
grep -F 'access.ssh must be a boolean' "$tmp/error" >/dev/null

cat > "$tmp/ssh.yml" <<EOF
workspace:
  directory: "$tmp/dir with spaces"
access:
  opencode: false
  ssh: true
EOF

if command -v ssh-agent >/dev/null && command -v ssh-add >/dev/null && command -v ssh >/dev/null; then
  # shellcheck disable=SC2016
  HOME="$tmp/home" PATH="$PATH" ssh-agent -a "$tmp/agent.sock" \
    "$box" -f "$tmp/ssh.yml" -- sh -eu -c '
      test "$SSH_AUTH_SOCK" = /run/ssh-agent.sock
      test -S "$SSH_AUTH_SOCK"
      test -r /workspace/.ssh/known_hosts
      test "$(cat /workspace/.ssh/known_hosts)" = "# known hosts fixture"
      test "$(ssh -G example.invalid | awk '\''$1 == "userknownhostsfile" { print $2; exit }'\'')" = /workspace/.ssh/known_hosts
      status=0
      ssh-add -l >/dev/null 2>&1 || status=$?
      test "$status" -eq 1
      ssh -G example.invalid >/dev/null
    '
fi

if HOME="$tmp/home" SSH_AUTH_SOCK="$tmp/missing.sock" PATH="$PATH" \
  "$box" -f "$tmp/ssh.yml" -- true 2>"$tmp/error"; then
  printf 'expected invalid SSH_AUTH_SOCK to fail\n' >&2
  exit 1
fi
grep -F 'access.ssh requires SSH_AUTH_SOCK to name a socket' "$tmp/error" >/dev/null
