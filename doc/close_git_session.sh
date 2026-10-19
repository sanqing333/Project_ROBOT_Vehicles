#!/usr/bin/env bash
######################################################
# Fabrice Muller, Polytech Nice Sophia, 2026
#
# close_git_session.sh
# END of EVERY session: commit, push, check that GitHub is up to date,
# then clear the token from memory.
#
# How to use:
#   1) Make the script executable (once):  chmod +x ~/close_git_session.sh
#   2) Run it, like start_git_session.sh. One optional argument: the repository URL.
#      - Run it INSIDE your repository (or a sub-folder): this repository is closed.
#      - Run it OUTSIDE (e.g. in ~): the repository given by the URL is used,
#        in the current folder (default URL: DEFAULT_REPO_URL below).
#      Option -r (or --remove-token): also remove the token saved on disk
#        (when start_git_session.sh was run with 0, e.g. by mistake on a shared computer).
#      Examples:
#        cd ~/labs && ~/close_git_session.sh                                  # current repository (~/labs)
#        cd ~ && ./close_git_session.sh                                       # default URL -> ~/labs
#        cd ~ && ./close_git_session.sh https://github.com/ise-pns/labs.git   # this URL -> ~/labs
#        cd ~ && ./close_git_session.sh -r                                    # ~/labs + remove the token from disk
#
######################################################

# ==================== TO EDIT ====================
DEFAULT_REPO_URL="https://github.com/sanqing333/Project_ROBOT_Vehicles.git"   # used when no URL is given in the command line
# =================================================

######################################################
# Helper Functions

# Functions for colored output
ok()   { echo -e "\e[32m[OK]\e[0m $*"; }
info() { echo -e "\e[34m[..]\e[0m $*"; }
warn() { echo -e "\e[33m[!!]\e[0m $*"; }
fail() { echo -e "\e[31m[ERROR]\e[0m $*"; exit 1; }

# what to do when 'git pull' stops on a conflict
conflict_help() {
    warn "CONFLICT: these files were modified both on this computer and on GitHub:"
    git diff --name-only --diff-filter=U | sed 's/^/        /'
    echo "   To resolve it (VS Code: Source Control panel, Ctrl+Shift+G):"
    echo "     1) open each file, choose Accept Current / Incoming / Both, then save"
    echo "     2) git add <file>         (VS Code: '+' next to the file)"
    echo "     3) git commit --no-edit   (VS Code: 'Commit')"
    echo "     4) git push               (VS Code: 'Sync Changes')"
    echo "   Then run this script again to push and clear the token."
}

# function to display usage and exit
usage() {
    echo "Usage:   $0 [-r|--remove-token] [repository-url]"
    echo "  repository-url:     default: $DEFAULT_REPO_URL"
    echo "                      (ignored when the script is run inside a repository)"
    echo "  -r, --remove-token: also remove the token saved on disk (~/.git-credentials)"
    echo "Examples: $0"
    echo "          $0 https://github.com/ise-pns/labs.git"
    echo "          $0 -r"
}

# URL without a final "/" or ".git", to compare two URLs of the same repository
norm_url() { local u="${1%/}"; echo "${u%.git}"; }

######################################################
# 0. Read the arguments
# options (anywhere on the command line), the rest is the URL
REMOVE_TOKEN=false
ARGS=()
for ARG in "$@"; do
    case "$ARG" in
        -r|--remove-token) REMOVE_TOKEN=true ;;
        -h|--help)         usage; exit 0 ;;
        -*)                usage; fail "Unknown option: $ARG" ;;
        *)                 ARGS+=("$ARG") ;;
    esac
done
set -- "${ARGS[@]}"

if [[ $# -gt 1 ]]; then
    usage
    fail "At most one argument expected: the repository URL."
fi
# a number is the token time of start_git_repo.sh, not used here
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    usage
    fail "No time argument for this script (the token is cleared at the end)."
fi

REPO_URL="${1:-$DEFAULT_REPO_URL}"
URL_GIVEN=false
[[ $# -eq 1 ]] && URL_GIVEN=true

######################################################
# 1. Find the repository
if TOP="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    # run INSIDE a repository: close this one (check the URL only if one was given)
    REPO_DIR="$TOP"
    CHECK_URL=$URL_GIVEN
else
    # run OUTSIDE a repository: use the folder named after the URL, in the current folder
    REPO_DIR="$PWD/$(basename "$REPO_URL" .git)"
    [[ -d "$REPO_DIR/.git" ]] \
        || fail "No repository $REPO_DIR on this computer: 'cd' into your repository first, or give its URL."
    CHECK_URL=true
fi
cd "$REPO_DIR" || fail "Cannot enter $REPO_DIR"

# Check that the repository has an 'origin' remote (cloned from GitHub)
ORIGIN_URL="$(git config --get remote.origin.url)" \
    || fail "This repository has no 'origin' remote (not cloned from GitHub?)."

# Check that it is the expected repository
if $CHECK_URL && [[ "$(norm_url "$REPO_URL")" != "$(norm_url "$ORIGIN_URL")" ]]; then
    fail "$REPO_DIR comes from $ORIGIN_URL, not from $REPO_URL."
fi
info "Repository: $REPO_DIR ($ORIGIN_URL)"

# a merge must not be in progress
git rev-parse -q --verify MERGE_HEAD >/dev/null \
    && { conflict_help; fail "A merge is already in progress: finish it first (steps above)."; }

BRANCH="$(git branch --show-current)"
[[ -n "$BRANCH" ]] || fail "No current branch (detached HEAD): go back to the main branch with 'git switch main', then run this script again."
[[ "$BRANCH" == "main" ]] || warn "You are on branch '$BRANCH', not 'main'."

######################################################
# 2. Commit everything
if [[ -n "$(git status --porcelain)" ]]; then
    info "Changes to commit:"
    git status -s

    DEFAULT_MSG="End of session $(date +%Y-%m-%d)"
    read -r -p "Commit message [$DEFAULT_MSG]: " MSG
    MSG="${MSG:-$DEFAULT_MSG}"

    git add -A
    git commit -q -m "$MSG" || fail "Commit failed."
    ok "Committed: $MSG"
else
    info "Nothing new to commit."
fi

######################################################
# 3. Push to GitHub
info "Pushing to GitHub..."
if ! git push -u origin "$BRANCH"; then
    warn "Push refused: GitHub probably has commits made from another computer."
    warn "Run 'git pull', resolve any conflict, then run this script again."
    fail "Nothing has been pushed. The token is kept in memory so that you can pull."
fi

######################################################
# 4. Check that GitHub is up to date
git fetch -q origin
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/$BRANCH" 2>/dev/null)"
[[ "$LOCAL" == "$REMOTE" ]] || fail "Local and GitHub are different: check with 'git status'."

git status -sb
# the last commit is on GitHub
git log --oneline -5 "origin/$BRANCH"

[[ -z "$(git status --porcelain)" ]] || warn "Some files are still not committed (see above)."
ok "Your work is on GitHub."

######################################################
# 5. Clean up the computer
# clears the token from memory
git credential-cache exit 2>/dev/null

if $REMOVE_TOKEN; then
    # option -r: back to "token in memory" mode...
    if git config --global --get-all credential.helper | grep -q 'store'; then
        git config --global --unset-all credential.helper
        git config --global credential.helper "cache --timeout=11700"
    fi
    # ...and remove the GitHub token from the files where "store" writes it
    for CRED_FILE in "$HOME/.git-credentials" "${XDG_CONFIG_HOME:-$HOME/.config}/git/credentials"; do
        if [[ -f "$CRED_FILE" ]] && grep -q 'github\.com' "$CRED_FILE"; then
            # remove only the GitHub lines (keep other sites, e.g. GitLab)
            sed -i '/github\.com/d' "$CRED_FILE"
            [[ -s "$CRED_FILE" ]] || rm -f "$CRED_FILE"
        fi
    done
    ok "Token cleared from memory and from disk: start_git_repo.sh will ask for it next time."
elif git config --global --get-all credential.helper | grep -q 'store'; then
    # start_git_repo.sh was run with 0: the token stays on disk, on purpose
    info "Token kept on disk in ~/.git-credentials (start_git_repo.sh run with 0)."
    warn "Only on YOUR OWN computer: on a shared computer, anyone can read it."
    warn "To remove it: run this script again with the option -r"
else
    ok "Token cleared from memory."
fi
echo
echo "   If you signed in to GitHub in VS Code: account icon (bottom left) -> Sign out"
echo "   Then log out of your session."
