#!/usr/bin/env bash
# ============================================================
# Claude Code Settings Sync Script — Mac/Linux
# Usage:
#   bash sync.sh              # 동기화 실행
#   bash sync.sh --dry-run    # 변경사항만 확인 (실제 반영 안 함)
#   bash sync.sh --install-cron  # 30분 주기 cron 등록
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="$SCRIPT_DIR/.sync.lock"
CONF_FILE="$SCRIPT_DIR/sync.conf"

DRY_RUN=false
INSTALL_CRON=false

changed_count=0
changed_files=()

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Logging ───────────────────────────────────────────────

log_info()  { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN${NC} $1"; }
log_error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR${NC} $1"; }

# ── Argument Parsing ──────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   DRY_RUN=true; shift ;;
            --install-cron) INSTALL_CRON=true; shift ;;
            --help|-h)
                echo "Usage: bash sync.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run        변경사항만 확인 (실제 반영 안 함)"
                echo "  --install-cron   30분 주기 cron 등록"
                echo "  --help, -h       이 도움말 표시"
                exit 0
                ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done
}

# ── Lock Management ───────────────────────────────────────

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log_error "Already running (PID: $pid)"
            exit 2
        fi
        log_warn "Stale lock found (PID: $pid). Removing."
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# ── Config Loading ────────────────────────────────────────

load_config() {
    if [ ! -f "$CONF_FILE" ]; then
        log_error "sync.conf not found: $CONF_FILE"
        exit 1
    fi

    SYNC_TARGETS=""
    SYNC_EXCLUDES=""
    REMOTE_BRANCH="main"
    COMMIT_PREFIX="sync"
    SOURCE_DIR="$HOME/.claude"

    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^"//;s/"$//')
        value=$(eval echo "$value")  # expand $HOME etc.
        case "$key" in
            SYNC_TARGETS)   SYNC_TARGETS="$value" ;;
            SYNC_EXCLUDES)  SYNC_EXCLUDES="$value" ;;
            REMOTE_BRANCH)  REMOTE_BRANCH="$value" ;;
            COMMIT_PREFIX)  COMMIT_PREFIX="$value" ;;
            SOURCE_DIR)     SOURCE_DIR="$value" ;;
        esac
    done < "$CONF_FILE"

    if [ -z "$SYNC_TARGETS" ]; then
        log_error "SYNC_TARGETS is empty in sync.conf"
        exit 1
    fi

    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi
}

# ── Exclude Check ─────────────────────────────────────────

is_excluded() {
    local filepath="$1"
    local basename
    basename=$(basename "$filepath")

    for pattern in $SYNC_EXCLUDES; do
        # shellcheck disable=SC2254
        case "$basename" in
            $pattern) return 0 ;;
        esac
        case "$filepath" in
            */$pattern/*) return 0 ;;
            */$pattern) return 0 ;;
        esac
    done
    return 1
}

# ── Diff & Copy ───────────────────────────────────────────

diff_and_copy() {
    local source="$1"
    local dest="$2"
    local rel_path="$3"

    if [ ! -e "$source" ]; then
        log_warn "Source not found, skipping: $rel_path"
        return
    fi

    if [ -d "$source" ]; then
        mkdir -p "$dest"
        local file
        while IFS= read -r file; do
            local rel="${file#$source/}"
            local dest_file="$dest/$rel"

            if is_excluded "$rel"; then
                continue
            fi

            if [ ! -f "$dest_file" ] || ! diff -q "$file" "$dest_file" &>/dev/null; then
                if [ "$DRY_RUN" = true ]; then
                    log_info "[DRY-RUN] Would copy: $rel_path/$rel"
                else
                    mkdir -p "$(dirname "$dest_file")"
                    cp "$file" "$dest_file"
                    log_info "Copied: $rel_path/$rel"
                fi
                changed_count=$((changed_count + 1))
                changed_files+=("$rel_path/$rel")
            fi
        done < <(find "$source" -type f)
    else
        if is_excluded "$rel_path"; then
            return
        fi

        if [ ! -f "$dest" ] || ! diff -q "$source" "$dest" &>/dev/null; then
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY-RUN] Would copy: $rel_path"
            else
                cp "$source" "$dest"
                log_info "Copied: $rel_path"
            fi
            changed_count=$((changed_count + 1))
            changed_files+=("$rel_path")
        fi
    fi
}

# ── Sync Targets ──────────────────────────────────────────

sync_targets() {
    for target in $SYNC_TARGETS; do
        diff_and_copy "$SOURCE_DIR/$target" "$SCRIPT_DIR/$target" "$target"
    done
}

# ── Git Operations ────────────────────────────────────────

git_commit_push() {
    cd "$SCRIPT_DIR"

    if ! command -v git &>/dev/null; then
        log_error "git is not installed"
        exit 1
    fi

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "Not a git repository: $SCRIPT_DIR"
        exit 1
    fi

    git add -A

    if [ -z "$(git status --porcelain)" ]; then
        log_info "No git changes after sync. Skipping commit."
        return
    fi

    local file_summary
    if [ ${#changed_files[@]} -le 3 ]; then
        file_summary=$(IFS=', '; echo "${changed_files[*]}")
    else
        file_summary="${changed_files[0]}, ${changed_files[1]} and $((${#changed_files[@]} - 2)) more"
    fi

    local message="${COMMIT_PREFIX}: update ${file_summary}"
    git commit -m "$message"
    log_info "Committed: $message"

    if ! git push origin "$REMOTE_BRANCH" 2>/dev/null; then
        log_warn "Push failed. Trying pull --rebase..."
        if git pull --rebase origin "$REMOTE_BRANCH"; then
            git push origin "$REMOTE_BRANCH"
            log_info "Push succeeded after rebase."
        else
            git rebase --abort 2>/dev/null || true
            log_error "Rebase conflict. Manual resolution required."
            exit 3
        fi
    else
        log_info "Pushed to origin/$REMOTE_BRANCH"
    fi
}

# ── Cron Installation ─────────────────────────────────────

install_cron() {
    local cron_entry="*/30 * * * * cd $SCRIPT_DIR && bash sync.sh >> /tmp/claude-sync.log 2>&1"

    if crontab -l 2>/dev/null | grep -q "sync.sh"; then
        log_warn "Cron entry already exists:"
        crontab -l | grep "sync.sh"
        echo ""
        echo "To remove: crontab -e (then delete the sync.sh line)"
        return
    fi

    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    log_info "Cron registered: every 30 minutes"
    log_info "Log: /tmp/claude-sync.log"
    echo ""
    echo "To remove: crontab -e (then delete the sync.sh line)"
}

# ── Main ──────────────────────────────────────────────────

main() {
    parse_args "$@"

    if [ "$INSTALL_CRON" = true ]; then
        install_cron
        exit 0
    fi

    echo ""
    echo "=============================================="
    echo "  Claude Code Settings Sync"
    echo "=============================================="
    echo ""

    cd "$SCRIPT_DIR"

    acquire_lock
    trap 'release_lock; log_error "Interrupted"; exit 1' INT TERM
    trap 'release_lock' EXIT

    load_config
    log_info "Source: $SOURCE_DIR"
    log_info "Targets: $SYNC_TARGETS"
    [ "$DRY_RUN" = true ] && log_warn "DRY-RUN mode enabled"

    sync_targets

    if [ "$changed_count" -eq 0 ]; then
        log_info "No changes detected. Everything is up to date."
        echo ""
        exit 0
    fi

    log_info "$changed_count file(s) changed."

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] No actual changes made."
        echo ""
        exit 0
    fi

    git_commit_push

    echo ""
    echo "=============================================="
    echo -e "  ${GREEN}Sync complete!${NC} ($changed_count file(s))"
    echo "=============================================="
    echo ""
}

main "$@"
