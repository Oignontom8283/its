#!/usr/bin/env bash
#
# version-bump.sh
# Bumps the crate version in Cargo.toml, commits it, and creates a git tag.
#
set -uo pipefail

# --------------------------------------------------------------------------
# Bash version guard (associative arrays require bash >= 4.0)
# --------------------------------------------------------------------------
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "[ERROR] This script requires bash >= 4.0." >&2
    exit 1
fi

# --------------------------------------------------------------------------
# Colors
# --------------------------------------------------------------------------
readonly C_RESET='\033[0m'
readonly C_YELLOW='\033[1;33m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'

log_info()    { echo -e "${C_RESET}[INFO] $1${C_RESET}"; }
log_warn()    { echo -e "${C_YELLOW}[WARN] $1${C_RESET}"; }
log_error()   { echo -e "${C_RED}[ERROR] $1${C_RESET}" >&2; }
log_success() { echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}"; }

# --------------------------------------------------------------------------
# Early dependency check.
# These are tools the script relies on that are NOT guaranteed to be
# present by default on every distribution (unlike git/cargo, which are
# domain-specific and checked further down with a localized message).
# This check intentionally stays in English only: the language system
# itself is built on jq, so it can't be used to translate this message.
# --------------------------------------------------------------------------
REQUIRED_EARLY_TOOLS=(jq)
missing_tools=()
for tool in "${REQUIRED_EARLY_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
if [ "${#missing_tools[@]}" -gt 0 ]; then
    log_error "Required command(s) not found: ${missing_tools[*]}"
    log_error "Please install them first (e.g. 'apt install ${missing_tools[*]}' or 'brew install ${missing_tools[*]}')."
    exit 1
fi

# --------------------------------------------------------------------------
# i18n — JSON-based, looked up via jq.
#
# Two languages ship embedded in the script (en/fr) so it keeps working as
# a standalone single file. On top of that, the script is modular: drop a
# "<code>.json" file next to it, in a "lang/" folder, to add a new
# language with zero code changes. Format:
#   {
#     "_meta": { "name": "spanish" },   // English name, used by --language
#     "err_git_not_found": "...",
#     ...                                // same keys as lang_via_arg, etc.
#   }
# An external file with the same code as an embedded one overrides it.
# --------------------------------------------------------------------------
LANG_JSON_EN=$(cat <<'JSON'
{
  "_meta": { "name": "english" },
  "lang_via_arg": "Language determined via the --language/-l command-line argument.",
  "lang_via_os": "Language automatically detected from OS/system settings.",
  "lang_via_default": "Could not determine a language, falling back to the default (English).",
  "err_git_not_found": "Git is not installed or not available in PATH.",
  "err_not_git_repo": "This directory is not a git repository.",
  "err_no_commits": "Repository has no commits yet.",
  "err_cargo_not_found": "Cargo is not installed or not available in PATH.",
  "err_cargo_set_version_missing": "The 'cargo set-version' command is not available. Install it with: cargo install cargo-edit",
  "err_cargo_toml_missing": "No Cargo.toml found in the repository.",
  "err_cargo_toml_dirty": "Cargo.toml already has uncommitted changes. Commit them first.",
  "err_no_level": "You must specify a version level: patch, minor or major.",
  "err_all_and_dirty": "--all and -d/--dirty cannot be used together.",
  "warn_dirty_repo": "Repository is dirty: files are modified but nothing is staged.",
  "info_use_all_or_dirty": "Use --all to stage them, or -d to ignore them.",
  "prompt_staged_files": "Currently staged files:",
  "prompt_include_files": "Include these files in the version commit? (y/n)",
  "confirm_yes_char": "y",
  "info_cancelled": "Operation cancelled, restoring the original state.",
  "err_cargo_bump": "Cargo error:",
  "info_version_bump": "Bumping version to",
  "info_lockfile_regen": "Regenerating Cargo.lock to match the new version, this may take a moment...",
  "err_lockfile_regen": "Failed to regenerate Cargo.lock:",
  "err_commit_failed": "Commit failed.",
  "err_tag_failed": "Tag creation failed.",
  "info_cleaning": "Cleaning up and restoring the repository to its original state...",
  "success_done": "DONE!",
  "success_version": "Bumped to version",
  "info_push_hint": "Run the following command to push the tag:"
}
JSON
)

LANG_JSON_FR=$(cat <<'JSON'
{
  "_meta": { "name": "french" },
  "lang_via_arg": "Langue déterminée via le paramètre --language/-l en ligne de commande.",
  "lang_via_os": "Langue détectée automatiquement depuis les paramètres du système.",
  "lang_via_default": "Impossible de déterminer une langue, utilisation de la langue par défaut (anglais).",
  "err_git_not_found": "Git n'est pas installé ou introuvable dans le PATH.",
  "err_not_git_repo": "Ce répertoire n'est pas un dépôt git.",
  "err_no_commits": "Le dépôt ne contient encore aucun commit.",
  "err_cargo_not_found": "Cargo n'est pas installé ou introuvable dans le PATH.",
  "err_cargo_set_version_missing": "La commande 'cargo set-version' est introuvable. Installez-la avec : cargo install cargo-edit",
  "err_cargo_toml_missing": "Aucun Cargo.toml trouvé dans le dépôt.",
  "err_cargo_toml_dirty": "Cargo.toml a déjà des modifications non validées. Committez-les d'abord.",
  "err_no_level": "Vous devez préciser un niveau de version : patch, minor ou major.",
  "err_all_and_dirty": "--all et -d/--dirty sont incompatibles.",
  "warn_dirty_repo": "Dépôt modifié : des fichiers sont modifiés mais rien n'est indexé.",
  "info_use_all_or_dirty": "Utilisez --all pour les indexer, ou -d pour les ignorer.",
  "prompt_staged_files": "Fichiers actuellement indexés :",
  "prompt_include_files": "Inclure ces fichiers dans le commit de version ? (o/n)",
  "confirm_yes_char": "o",
  "info_cancelled": "Annulation effectuée, restauration de l'état initial.",
  "err_cargo_bump": "Erreur Cargo :",
  "info_version_bump": "Passage à la version",
  "info_lockfile_regen": "Régénération du Cargo.lock pour correspondre à la nouvelle version, cela peut prendre un instant...",
  "err_lockfile_regen": "Échec de la régénération du Cargo.lock :",
  "err_commit_failed": "Erreur lors du commit.",
  "err_tag_failed": "Erreur lors de la création du tag.",
  "info_cleaning": "Nettoyage et restauration du dépôt à son état initial...",
  "success_done": "TERMINÉ !",
  "success_version": "Version passée à",
  "info_push_hint": "Exécutez la commande suivante pour pousser le tag :"
}
JSON
)

declare -A LANG_DATA
LANG_DATA[en]="$LANG_JSON_EN"
LANG_DATA[fr]="$LANG_JSON_FR"

declare -A LANGUAGE_NAMES
LANGUAGE_NAMES[en]="english"
LANGUAGE_NAMES[fr]="french"

AVAILABLE_LANGUAGES=(en fr)

# Discover extra languages dropped in ./lang/<code>.json next to the script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"
LANG_DIR="$SCRIPT_DIR/lang"

if [ -d "$LANG_DIR" ]; then
    for lang_file in "$LANG_DIR"/*.json; do
        [ -e "$lang_file" ] || continue
        lang_code=$(basename "$lang_file" .json)
        lang_code="${lang_code,,}"
        if ! jq empty "$lang_file" >/dev/null 2>&1; then
            log_warn "Skipping invalid language file: $lang_file"
            continue
        fi
        lang_name=$(jq -r '._meta.name // empty' "$lang_file")
        [ -n "$lang_name" ] || lang_name="$lang_code"
        LANG_DATA[$lang_code]=$(cat "$lang_file")
        LANGUAGE_NAMES[$lang_code]="${lang_name,,}"
        if [[ ! " ${AVAILABLE_LANGUAGES[*]} " == *" $lang_code "* ]]; then
            AVAILABLE_LANGUAGES+=("$lang_code")
        fi
    done
fi

LANG_CODE="en"

t() {
    local key="$1"
    local json="${LANG_DATA[$LANG_CODE]:-$LANG_JSON_EN}"
    local val
    val=$(jq -r --arg k "$key" '.[$k] // empty' <<< "$json" 2>/dev/null)
    if [ -z "$val" ] && [ "$LANG_CODE" != "en" ]; then
        val=$(jq -r --arg k "$key" '.[$k] // empty' <<< "$LANG_JSON_EN" 2>/dev/null)
    fi
    [ -n "$val" ] && printf '%s' "$val" || printf '%s' "$key"
}

# --------------------------------------------------------------------------
# Help — never translated: it documents the CLI arguments themselves, which
# are also never translated.
# --------------------------------------------------------------------------
show_help() {
    cat <<'EOF'
Usage: version-bump.sh <patch|minor|major> [options]

Bumps the crate version in Cargo.toml, commits it, and creates a git tag.

Version level (required, one of):
  patch, fix          Bump the patch version
  minor, feat         Bump the minor version
  major, breaking     Bump the major version

Options:
  -a, --tag-name NAME     Custom tag name (default: v<version>)
  -m, --tag-comment MSG   Custom annotated tag message
      --all                Stage all modified files before committing
  -d, --dirty              Allow a dirty working tree without staging anything
  -y, --yes                Skip confirmation prompts
  -l, --language LANG      Force the message language
  -h, --help                Show this help message and exit

Adding a language: drop a "<code>.json" file in a "lang/" folder next to
this script (see the embedded en/fr blocks in the script for the format).

Examples:
  version-bump.sh patch -y
  version-bump.sh minor --all -m "New features"
  version-bump.sh major -l french
EOF
    local langs
    langs=$(printf '%s, ' "${LANGUAGE_NAMES[@]}")
    echo "Available languages for -l/--language: ${langs%, }"
}

usage_error() {
    echo "[ERROR] $1" >&2
    echo "" >&2
    show_help >&2
    exit 1
}

# --------------------------------------------------------------------------
# OS language detection
# --------------------------------------------------------------------------
detect_os_language() {
    local raw="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    local code="${raw:0:2}"
    code="${code,,}"
    local l
    for l in "${AVAILABLE_LANGUAGES[@]}"; do
        if [ "$l" = "$code" ]; then
            printf '%s' "$code"
            return 0
        fi
    done
    return 1
}

# ==========================================================================
# Argument parsing.
# This happens BEFORE language initialization: usage/help/error-on-bad-args
# stay in English and always take precedence over the localized messages
# that come afterwards.
# ==========================================================================
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

LEVEL=""
TAG_NAME=""
TAG_COMMENT=""
VALIDATE_ALL=false
ALLOW_DIRTY=false
AUTO_CONFIRM=false
LANG_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        patch|fix) LEVEL="patch"; shift ;;
        minor|feat) LEVEL="minor"; shift ;;
        major|breaking) LEVEL="major"; shift ;;
        -a|--tag-name)
            [ $# -ge 2 ] || usage_error "Missing value for $1"
            TAG_NAME="$2"; shift 2 ;;
        -m|--tag-comment)
            [ $# -ge 2 ] || usage_error "Missing value for $1"
            TAG_COMMENT="$2"; shift 2 ;;
        --all) VALIDATE_ALL=true; shift ;;
        -d|--dirty) ALLOW_DIRTY=true; shift ;;
        -y|--yes) AUTO_CONFIRM=true; shift ;;
        -l|--language)
            [ $# -ge 2 ] || usage_error "Missing value for $1"
            LANG_ARG="$2"; shift 2 ;;
        *) usage_error "Unrecognized argument: $1" ;;
    esac
done

# ==========================================================================
# Language initialization
# ==========================================================================
DETECT_METHOD=""

if [ -n "$LANG_ARG" ]; then
    LANG_ARG_LOWER=$(printf '%s' "$LANG_ARG" | tr '[:upper:]' '[:lower:]')
    LANG_CODE=""
    for code in "${!LANGUAGE_NAMES[@]}"; do
        if [ "${LANGUAGE_NAMES[$code]}" = "$LANG_ARG_LOWER" ]; then
            LANG_CODE="$code"
            break
        fi
    done
    if [ -z "$LANG_CODE" ]; then
        usage_error "Unknown language '$LANG_ARG'. Available: ${LANGUAGE_NAMES[*]}"
    fi
    DETECT_METHOD="arg"
else
    if OS_CODE=$(detect_os_language); then
        LANG_CODE="$OS_CODE"
        DETECT_METHOD="os"
    else
        LANG_CODE="en"
        DETECT_METHOD="default"
    fi
fi

# Startup notice: always in English, whatever the selected language is.
echo -e "${C_RESET}[INFO] Selected language: ${LANGUAGE_NAMES[$LANG_CODE]} (parameter: --language=${LANGUAGE_NAMES[$LANG_CODE]})${C_RESET}"

# Follow-up notice: in the now-active language, explains how it was picked.
case "$DETECT_METHOD" in
    arg)     log_info "$(t lang_via_arg)" ;;
    os)      log_info "$(t lang_via_os)" ;;
    default) log_info "$(t lang_via_default)" ;;
esac

# ==========================================================================
# Environment checks
# ==========================================================================
if ! command -v git >/dev/null 2>&1; then
    log_error "$(t err_git_not_found)"
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_error "$(t err_not_git_repo)"
    exit 1
fi

if ! git rev-parse HEAD >/dev/null 2>&1; then
    log_error "$(t err_no_commits)"
    exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
    log_error "$(t err_cargo_not_found)"
    exit 1
fi

if ! cargo set-version --help >/dev/null 2>&1; then
    log_error "$(t err_cargo_set_version_missing)"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT" || { log_error "$(t err_not_git_repo)"; exit 1; }

if [ ! -f "Cargo.toml" ]; then
    log_error "$(t err_cargo_toml_missing)"
    exit 1
fi

if git status --porcelain Cargo.toml | grep -q "M"; then
    log_error "$(t err_cargo_toml_dirty)"
    exit 1
fi

if [ -z "$LEVEL" ]; then
    log_error "$(t err_no_level)"
    echo ""
    show_help
    exit 1
fi

if [ "$VALIDATE_ALL" = true ] && [ "$ALLOW_DIRTY" = true ]; then
    log_error "$(t err_all_and_dirty)"
    exit 1
fi

# ==========================================================================
# Snapshot / rollback machinery.
# From this point on, any error rolls back EVERYTHING to the exact state
# the repository was in before the script ran (commit, index, working
# tree, untracked files included).
# ==========================================================================
ORIGINAL_HEAD=$(git rev-parse HEAD)
SCRIPT_SUCCESS=false
SNAPSHOT_CREATED=false

restore_snapshot() {
    log_warn "$(t info_cleaning)"
    git reset --hard "$ORIGINAL_HEAD" >/dev/null 2>&1
    git clean -fd >/dev/null 2>&1
    if [ "$SNAPSHOT_CREATED" = true ]; then
        git stash pop --index --quiet >/dev/null 2>&1
    fi
}

on_exit() {
    local exit_code=$?
    if [ "$SCRIPT_SUCCESS" = false ]; then
        restore_snapshot
    fi
    exit "$exit_code"
}
trap on_exit EXIT
trap 'exit 130' INT TERM

# Snapshot the current tracked + untracked state (if any), then immediately
# reapply it so nothing visibly changes — this just keeps a safe reference
# in the stash list that we can pop back to on failure.
if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
    if git stash push --include-untracked --quiet -m "version-bump-script-backup-$$"; then
        SNAPSHOT_CREATED=true
        git stash apply --index --quiet >/dev/null 2>&1
    fi
fi

# ==========================================================================
# Staging logic
# ==========================================================================
if [ "$VALIDATE_ALL" = true ]; then
    git add .
fi

STAGED_FILES=$(git diff --cached --name-only)
DIRTY_FILES=$(git status --porcelain | grep -v "Cargo.toml" || true)

if [ -z "$STAGED_FILES" ] && [ -n "$DIRTY_FILES" ] && [ "$ALLOW_DIRTY" = false ]; then
    log_warn "$(t warn_dirty_repo)"
    log_info "$(t info_use_all_or_dirty)"
    exit 1
fi

if [ -n "$STAGED_FILES" ]; then
    if [ "$AUTO_CONFIRM" = false ]; then
        log_info "$(t prompt_staged_files)"
        echo "$STAGED_FILES"
        yes_char=$(t confirm_yes_char)
        REPLY=""
        read -r -p "$(t prompt_include_files) " -n 1 REPLY
        echo
        if [[ ! "$REPLY" =~ ^[${yes_char^^}${yes_char,,}]$ ]]; then
            log_info "$(t info_cancelled)"
            exit 1
        fi
    fi
fi

# ==========================================================================
# Version bump
# ==========================================================================
OUTPUT=$(cargo set-version --bump "$LEVEL" 2>&1)
if [ $? -ne 0 ]; then
    log_error "$(t err_cargo_bump) $OUTPUT"
    exit 1
fi

NEW_VERSION=$(echo "$OUTPUT" | awk '{print $NF}')
log_info "$(t info_version_bump) $NEW_VERSION"

# --------------------------------------------------------------------------
# Regenerate Cargo.lock so it matches the new manifest version.
# Run in the foreground on purpose: this can take a little while on bigger
# dependency graphs, but we deliberately wait for it to fully finish
# (no backgrounding, no timeout) rather than moving on with a stale lockfile.
# --------------------------------------------------------------------------
log_info "$(t info_lockfile_regen)"
LOCKFILE_OUTPUT=$(cargo generate-lockfile 2>&1)
if [ $? -ne 0 ]; then
    log_error "$(t err_lockfile_regen) $LOCKFILE_OUTPUT"
    exit 1
fi

git add Cargo.toml
if [ -f "Cargo.lock" ] && ! git check-ignore -q Cargo.lock; then
    git add Cargo.lock
fi

if ! git commit -m "chore: bump version to $NEW_VERSION" >/dev/null; then
    log_error "$(t err_commit_failed)"
    exit 1
fi

FINAL_TAG=${TAG_NAME:-"v$NEW_VERSION"}
COMMENT=${TAG_COMMENT:-"Release $FINAL_TAG"}

if ! git tag -a "$FINAL_TAG" -m "$COMMENT"; then
    log_error "$(t err_tag_failed)"
    exit 1
fi

# Success: drop the safety snapshot instead of restoring it.
if [ "$SNAPSHOT_CREATED" = true ]; then
    git stash drop --quiet >/dev/null 2>&1
fi
SCRIPT_SUCCESS=true

echo ""
log_success "$(t success_done)"
log_success "$(t success_version) $FINAL_TAG"
echo ""
echo "$(t info_push_hint)"
echo ">   git push --tags"
echo ""