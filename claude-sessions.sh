#!/usr/bin/env bash
#
# claude-sessions.sh — inspect, back up, and manage Claude Code's local
# session data (the ~/.claude directory and its ~/.claude.json registry).
#
# Works on Linux and macOS (bash 3.2+, no GNU-only flags). Requires python3
# for the JSON-aware commands (list/retention/migrate/relink); backup only
# needs tar.
#
# Commands:
#   list                           show projects, session counts, sizes, last activity
#   backup [dest-dir]              archive the config dir + registry json
#   retention <days>               set cleanupPeriodDays (0 = keep sessions forever)
#   migrate <src-dir> <dst-dir>    merge one config dir into another (non-destructive)
#   relink <old-path> <new-path>   fix session history after a project folder moved
#
# Config dir resolution follows Claude Code itself: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

require_python() {
  command -v python3 >/dev/null 2>&1 || {
    echo "Error: python3 is required for '$1' but was not found in PATH." >&2
    exit 1
  }
}

# Best-effort absolute-ify a user-supplied path (does not resolve symlinks;
# just anchors relative paths to $PWD, same as most paths Claude records).
abspath() {
  local p="$1"
  case "$p" in
    /*) printf '%s\n' "${p%/}" ;;
    *) printf '%s\n' "${PWD%/}/${p%/}" ;;
  esac
}

default_config_dir() {
  local d="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  printf '%s\n' "${d%/}"
}

# The top-level *.claude.json registry that goes with a given config dir.
# When CLAUDE_CONFIG_DIR points somewhere custom, Claude Code keeps
# .claude.json inside that same directory instead of $HOME.
config_json_for() {
  local dir="${1%/}"
  if [ "$dir" = "$HOME/.claude" ]; then
    printf '%s\n' "$HOME/.claude.json"
  else
    printf '%s\n' "$dir/.claude.json"
  fi
}

# Claude Code encodes a project's absolute path as a directory name under
# projects/ by replacing every "/" with "-" (so "/home/a/app" -> "-home-a-app").
encode_path() {
  local p="${1%/}"
  printf '%s' "$p" | sed 's#/#-#g'
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <command> [args]

Commands:
  list                           Show projects, session counts, sizes, last activity
  backup [dest-dir]              Archive the config dir + registry json
                                  (default dest: ~/.claude-backups)
  retention <days>                Set cleanupPeriodDays (0 disables cleanup, keeps forever)
  migrate <src-dir> <dst-dir>    Merge one config dir into another.
                                  Never deletes and never overwrites existing files.
  relink <old-path> <new-path>   Fix session history after a project folder was
                                  moved from <old-path> to <new-path>.

Config dir resolution: \${CLAUDE_CONFIG_DIR:-\$HOME/.claude}
EOF
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

cmd_list() {
  require_python list
  local dir json
  dir="$(default_config_dir)"
  json="$(config_json_for "$dir")"

  if [ ! -d "$dir/projects" ]; then
    echo "No project sessions found under $dir/projects"
    return 0
  fi

  python3 - "$dir/projects" "$json" <<'PYEOF'
import sys, os, glob, json
from datetime import datetime

proj_dir, json_path = sys.argv[1], sys.argv[2]

registry = {}
if os.path.isfile(json_path):
    try:
        with open(json_path) as f:
            registry = (json.load(f) or {}).get("projects", {}) or {}
    except Exception:
        registry = {}

def encode(p):
    return p.rstrip("/").replace("/", "-")

encoded_to_real = {encode(p): p for p in registry.keys()}

def human(n):
    return f"{n/1024/1024:.1f}M" if n >= 1024 * 1024 else f"{n/1024:.1f}K"

rows = []
for entry in sorted(os.listdir(proj_dir)):
    full = os.path.join(proj_dir, entry)
    if not os.path.isdir(full):
        continue
    jsonl_files = glob.glob(os.path.join(full, "*.jsonl"))
    sessions = [f for f in jsonl_files if not os.path.basename(f).startswith(("agent-", "summary-"))]
    last = 0.0
    size = 0
    for f in jsonl_files:
        try:
            st = os.stat(f)
            size += st.st_size
            last = max(last, st.st_mtime)
        except OSError:
            pass
    real = encoded_to_real.get(entry)
    label = real if real else entry.replace("-", "/") + "  (unregistered, path guessed)"
    last_str = datetime.fromtimestamp(last).strftime("%Y-%m-%d %H:%M") if last else "-"
    rows.append((label, len(sessions), last_str, size))

if not rows:
    print("No project sessions found.")
    sys.exit(0)

print(f"{'PROJECT':<55} {'SESSIONS':>8}  {'LAST ACTIVITY':<16}  {'SIZE':>8}")
print("-" * 92)
total_sessions = total_size = 0
for label, count, last_str, size in rows:
    total_sessions += count
    total_size += size
    print(f"{label:<55} {count:>8}  {last_str:<16}  {human(size):>8}")
print("-" * 92)
print(f"{len(rows)} project(s), {total_sessions} session file(s), {human(total_size)} total")
PYEOF
}

# ---------------------------------------------------------------------------
# backup
# ---------------------------------------------------------------------------

cmd_backup() {
  local dir json dest ts archive
  dir="$(default_config_dir)"
  json="$(config_json_for "$dir")"
  dest="${1:-$HOME/.claude-backups}"
  mkdir -p "$dest"
  ts="$(date +%Y%m%d-%H%M%S)"
  archive="$dest/claude-backup-$ts.tar.gz"

  local targets=()
  if [ -d "$dir" ]; then
    targets+=("$dir")
  else
    echo "Warning: $dir not found, skipping" >&2
  fi
  if [ -f "$json" ]; then
    targets+=("$json")
  else
    echo "Warning: $json not found, skipping" >&2
  fi

  if [ ${#targets[@]} -eq 0 ]; then
    echo "Nothing to back up." >&2
    return 1
  fi

  tar -czf "$archive" "${targets[@]}"
  local size
  size="$(du -h "$archive" | cut -f1)"
  echo "Backup created: $archive ($size)"
  echo "Includes: ${targets[*]}"
}

# ---------------------------------------------------------------------------
# retention
# ---------------------------------------------------------------------------

cmd_retention() {
  require_python retention
  local days="${1:-}"
  if [ -z "$days" ] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo "Usage: $SCRIPT_NAME retention <days>   (0 keeps sessions forever)" >&2
    return 1
  fi

  local dir settings
  dir="$(default_config_dir)"
  mkdir -p "$dir"
  settings="$dir/settings.json"

  python3 - "$settings" "$days" <<'PYEOF'
import sys, json, os

path, days = sys.argv[1], int(sys.argv[2])
data = {}
if os.path.isfile(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error: could not parse {path}: {e}", file=sys.stderr)
        sys.exit(1)

old = data.get("cleanupPeriodDays")
data["cleanupPeriodDays"] = days

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)

print(f"cleanupPeriodDays: {old if old is not None else 'default (30)'} -> {days}  ({path})")
if days == 0:
    print("Cleanup disabled — sessions are kept indefinitely.")
PYEOF
}

# ---------------------------------------------------------------------------
# migrate
# ---------------------------------------------------------------------------

cmd_migrate() {
  require_python migrate
  local src="${1:-}" dst="${2:-}"
  if [ -z "$src" ] || [ -z "$dst" ]; then
    echo "Usage: $SCRIPT_NAME migrate <src-config-dir> <dst-config-dir>" >&2
    return 1
  fi
  src="$(abspath "$src")"
  dst="$(abspath "$dst")"

  if [ ! -d "$src" ]; then
    echo "Error: source config dir '$src' does not exist" >&2
    return 1
  fi
  mkdir -p "$dst"

  local src_json dst_json
  src_json="$(config_json_for "$src")"
  dst_json="$(config_json_for "$dst")"

  echo "Merging '$src' -> '$dst' (non-destructive: existing files in the destination are left untouched)"

  local copied_dirs=0 merged_dirs=0 copied_files=0 skipped_files=0
  local other_copied=0 other_skipped=0

  if [ -d "$src/projects" ]; then
    mkdir -p "$dst/projects"
    while IFS= read -r -d '' pdir; do
      local name target
      name="$(basename "$pdir")"
      target="$dst/projects/$name"
      if [ ! -e "$target" ]; then
        cp -R "$pdir" "$target"
        copied_dirs=$((copied_dirs + 1))
      else
        merged_dirs=$((merged_dirs + 1))
        while IFS= read -r -d '' f; do
          local fname
          fname="$(basename "$f")"
          if [ -e "$target/$fname" ]; then
            skipped_files=$((skipped_files + 1))
          else
            cp "$f" "$target/$fname"
            copied_files=$((copied_files + 1))
          fi
        done < <(find "$pdir" -mindepth 1 -maxdepth 1 -type f -print0)
      fi
    done < <(find "$src/projects" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  while IFS= read -r -d '' entry; do
    local name target
    name="$(basename "$entry")"
    [ "$name" = "projects" ] && continue
    target="$dst/$name"
    if [ -e "$target" ]; then
      other_skipped=$((other_skipped + 1))
    else
      cp -R "$entry" "$target"
      other_copied=$((other_copied + 1))
    fi
  done < <(find "$src" -mindepth 1 -maxdepth 1 -print0)

  local json_merged="no"
  if [ -f "$src_json" ]; then
    python3 - "$src_json" "$dst_json" <<'PYEOF'
import sys, json, os

src_path, dst_path = sys.argv[1], sys.argv[2]

with open(src_path) as f:
    src = json.load(f)

dst = {}
if os.path.isfile(dst_path):
    try:
        with open(dst_path) as f:
            dst = json.load(f)
    except Exception:
        dst = {}

added_projects = 0
src_projects = src.get("projects", {}) or {}
dst_projects = dst.setdefault("projects", {})
for path, val in src_projects.items():
    if path not in dst_projects:
        dst_projects[path] = val
        added_projects += 1

added_top = 0
for k, v in src.items():
    if k == "projects":
        continue
    if k not in dst:
        dst[k] = v
        added_top += 1

tmp = dst_path + ".tmp"
with open(tmp, "w") as f:
    json.dump(dst, f, indent=2)
    f.write("\n")
os.replace(tmp, dst_path)

print(f"Registry merge: {added_projects} project entry(ies) added, {added_top} other key(s) added -> {dst_path}")
PYEOF
    json_merged="yes"
  fi

  echo ""
  echo "Summary:"
  echo "  project dirs copied whole   : $copied_dirs"
  echo "  project dirs merged         : $merged_dirs"
  echo "  session files copied        : $copied_files"
  echo "  session files skipped (already existed): $skipped_files"
  echo "  other top-level items copied: $other_copied (skipped existing: $other_skipped)"
  echo "  .claude.json merged         : $json_merged"
  echo ""
  echo "Nothing was deleted or overwritten in '$src' or '$dst'. To use the merged config:"
  echo "  export CLAUDE_CONFIG_DIR=\"$dst\""
}

# ---------------------------------------------------------------------------
# relink
# ---------------------------------------------------------------------------

cmd_relink() {
  require_python relink
  local old="${1:-}" new="${2:-}"
  if [ -z "$old" ] || [ -z "$new" ]; then
    echo "Usage: $SCRIPT_NAME relink <old-project-path> <new-project-path>" >&2
    return 1
  fi
  old="$(abspath "$old")"
  new="$(abspath "$new")"

  local dir json
  dir="$(default_config_dir)"
  json="$(config_json_for "$dir")"

  local old_enc new_enc old_dir new_dir
  old_enc="$(encode_path "$old")"
  new_enc="$(encode_path "$new")"
  old_dir="$dir/projects/$old_enc"
  new_dir="$dir/projects/$new_enc"

  if [ ! -d "$old_dir" ]; then
    echo "Error: no session history found for '$old' (looked in $old_dir)" >&2
    return 1
  fi

  if [ -e "$new_dir" ]; then
    echo "Destination history dir already exists ($new_dir) — merging session files, existing ones are kept"
    while IFS= read -r -d '' f; do
      local fname
      fname="$(basename "$f")"
      if [ -e "$new_dir/$fname" ]; then
        echo "  skip (exists): $fname"
      else
        mv "$f" "$new_dir/$fname"
      fi
    done < <(find "$old_dir" -mindepth 1 -maxdepth 1 -type f -print0)
    rmdir "$old_dir" 2>/dev/null || echo "Note: $old_dir left in place (not empty after merge)"
  else
    mv -- "$old_dir" "$new_dir"
    echo "Renamed history dir: $old_dir -> $new_dir"
  fi

  python3 - "$new_dir" "$old" "$new" <<'PYEOF'
import sys, os, json, glob

proj_dir, old_path, new_path = sys.argv[1], sys.argv[2], sys.argv[3]

def fix(v):
    if isinstance(v, str):
        if v == old_path:
            return new_path
        if v.startswith(old_path + "/"):
            return new_path + v[len(old_path):]
    return v

changed_files = 0
changed_lines = 0
for path in glob.glob(os.path.join(proj_dir, "*.jsonl")):
    out_lines = []
    dirty = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            stripped = line.rstrip("\n")
            if not stripped:
                out_lines.append(stripped)
                continue
            try:
                obj = json.loads(stripped)
            except Exception:
                out_lines.append(stripped)
                continue
            touched = False
            if isinstance(obj, dict) and "cwd" in obj:
                newv = fix(obj["cwd"])
                if newv != obj["cwd"]:
                    obj["cwd"] = newv
                    touched = True
            if touched:
                out_lines.append(json.dumps(obj, ensure_ascii=False))
                dirty = True
                changed_lines += 1
            else:
                out_lines.append(stripped)
    if dirty:
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write("\n".join(out_lines) + "\n")
        os.replace(tmp, path)
        changed_files += 1

print(f"Rewrote cwd in {changed_lines} line(s) across {changed_files} session file(s)")
PYEOF

  if [ -f "$json" ]; then
    python3 - "$json" "$old" "$new" <<'PYEOF'
import sys, json, os

path, old_path, new_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(path) as f:
    data = json.load(f)

projects = data.get("projects", {}) or {}
if old_path in projects:
    val = projects.pop(old_path)
    if new_path in projects:
        print(f"Warning: registry already has an entry for {new_path}; old entry for {old_path} was dropped without merging")
    else:
        projects[new_path] = val
        print(f"Registry entry renamed: {old_path} -> {new_path}")
    data["projects"] = projects
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
else:
    print(f"No registry entry for {old_path} in {path} (nothing to rename there)")
PYEOF
  fi

  echo ""
  echo "Done. cd into '$new' and run 'claude --continue' (or --resume) to verify."
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  local cmd="${1:-}"
  if [ $# -gt 0 ]; then
    shift
  fi
  case "$cmd" in
    list) cmd_list "$@" ;;
    backup) cmd_backup "$@" ;;
    retention) cmd_retention "$@" ;;
    migrate) cmd_migrate "$@" ;;
    relink) cmd_relink "$@" ;;
    -h|--help|help|"") usage ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
