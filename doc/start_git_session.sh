#!/usr/bin/env bash
######################################################
# Fabrice Muller, Polytech Nice Sophia, 2026
#
# start_git_session.sh
# START of EVERY session (including the first one): check the Git configuration,
# put the token in memory, and get the LATEST version of your work from GitHub.
# Use it after 'close_git_session.sh' was run at the end of the previous session,
# on the SAME computer or on ANOTHER one.
#
#   - Run it INSIDE your repository (or a sub-folder): this repository is updated.
#   - Run it OUTSIDE (e.g. in ~): the repository given by the URL is used,
#     in the current folder; if it does not exist on this computer, it is cloned.
#
# How to use:
#   1) Edit the variables in the "TO EDIT" block below
#   2) Make the script executable:   chmod +x start_git_session.sh
#   3) Run the script. Both arguments are optional:
#        - the repository URL (default: DEFAULT_REPO_URL below)
#        - how long (in minutes) the token stays in memory
#          (default: 195 min = 3h15min; with 0, the token is stored on disk, in plain text)
#      Examples:
#        cd ~/labs && ~/start_git_session.sh                                      # current repository (~/labs), 3h15
#        cd ~ && ./start_git_session.sh                                           # default URL, 3h15 -> ~/labs
#        cd ~ && ./start_git_session.sh 120                                       # default URL, 2h   -> ~/labs
#        cd ~ && ./start_git_session.sh https://github.com/ise-pns/labs.git 120   # this URL, 2h -> ~/labs
#
# Keep this script OUTSIDE the repository folder (never commit it).
######################################################

# ==================== TO EDIT ======================================================
STUDENT_NAME="SanQing"                          # your full name as it appears on GitHub
STUDENT_EMAIL="yiyang.chen@etu.univ-cotedazur.fr"   # email linked to your GitHub account
GITHUB_USER="sanqing333"                    # your GitHub username

# Your GitHub token:
# leave it EMPTY (recommended): the script will ask for it (hidden input).
GITHUB_TOKEN=""

DEFAULT_REPO_URL="https://github.com/sanqing333/Project_ROBOT_Vehicles.git"  # used when no URL is given in the command line
DEFAULT_CACHE_MINUTES=195                               # token kept in memory for 3h15min by default
# ===================================================================================

######################################################
# Helper Functions
ok()   { echo -e "\e[32m[OK]\e[0m $*"; }
info() { echo -e "\e[34m[..]\e[0m $*"; }
warn() { echo -e "\e[33m[!!]\e[0m $*"; }
fail() { echo -e "\e[31m[ERROR]\e[0m $*"; exit 1; }

# reminder: how long the token is kept (uses CACHE_MINUTES and TOKEN_END)
token_reminder() {
    if (( CACHE_MINUTES == 0 )); then
        info "Token stored on disk in ~/.git-credentials (no time limit)."
    else
        info "Token kept in memory for $CACHE_MINUTES min, until about $TOKEN_END."
        info "After that, Git will ask again: username = $GITHUB_USER, password = your token."
    fi
}

# function to display usage and exit
usage() {
    echo "Usage:   $0 [repository-url] [cache-minutes]"
    echo "  repository-url: default: $DEFAULT_REPO_URL"
    echo "                  (ignored when the script is run inside a repository)"
    echo "  cache-minutes:  how long the token stays in memory (default: $DEFAULT_CACHE_MINUTES)"
    echo "                  0 = store the token on disk, in plain text (~/.git-credentials)"
    echo "Examples: $0"
    echo "          $0 120"
    echo "          $0 https://github.com/ise-pns/labs.git 120"
}

# URL without a final "/" or ".git", to compare two URLs of the same repository
norm_url() { local u="${1%/}"; echo "${u%.git}"; }

# what to do when 'git pull' stops on a conflict
conflict_help() {
    warn "CONFLICT: these files were modified both on this computer and on GitHub:"
    git diff --name-only --diff-filter=U | sed 's/^/        /'
    echo "   To resolve it (VS Code: Source Control panel, Ctrl+Shift+G):"
    echo "     1) open each file, choose Accept Current / Incoming / Both, then save"
    echo "     2) git add <file>         (VS Code: '+' next to the file)"
    echo "     3) git commit --no-edit   (VS Code: 'Commit')"
    echo "     4) git push               (VS Code: 'Sync Changes')"
    echo "   The token is still in memory: no need to run this script again."
}

######################################################
# 0. Read the arguments
if [[ $# -gt 2 ]]; then
    usage
    fail "At most two arguments expected: the repository URL and a time in minutes."
fi

# check that the "TO EDIT" block has been edited
if [[ "$STUDENT_NAME" == "Prénom Nom" || "$STUDENT_EMAIL" == prenom.nom@* || "$GITHUB_USER" == "your-github-login" ]]; then
    fail "Edit the variables at the top of the script first (name, email, GitHub login)."
fi

# start with the default values
REPO_URL="$DEFAULT_REPO_URL"
CACHE_MINUTES="$DEFAULT_CACHE_MINUTES"
URL_GIVEN=false

if [[ $# -eq 1 && "$1" =~ ^[0-9]+$ ]]; then
    # only one argument and it is a number: it is the time, keep the default URL
    CACHE_MINUTES="$1"
elif [[ $# -ge 1 ]]; then
    # otherwise the 1st argument is the URL, and the 2nd (if any) the time
    REPO_URL="$1"
    URL_GIVEN=true
    [[ $# -eq 2 ]] && CACHE_MINUTES="$2"
fi

# the time must be a whole number (0, 1, 2, ...)
[[ "$CACHE_MINUTES" =~ ^[0-9]+$ ]] \
    || fail "The time must be a whole number of minutes (given: $CACHE_MINUTES)"
CACHE_MINUTES=$((10#$CACHE_MINUTES))

######################################################
# 1. Find the repository
CLONE_NEEDED=false

if TOP="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    # run INSIDE a repository: update this one
    REPO_DIR="$TOP"
    ORIGIN_URL="$(git -C "$REPO_DIR" config --get remote.origin.url)" \
        || fail "The repository $REPO_DIR has no 'origin' remote (not cloned from GitHub?)."
    if $URL_GIVEN && [[ "$(norm_url "$REPO_URL")" != "$(norm_url "$ORIGIN_URL")" ]]; then
        fail "You are inside $REPO_DIR, which comes from $ORIGIN_URL, not from $REPO_URL. Run 'cd ~' first, or give no URL."
    fi
    REPO_URL="$ORIGIN_URL"
else
    # run OUTSIDE a repository: use the folder named after the URL, in the current folder
    REPO_NAME="$(basename "$REPO_URL" .git)"
    REPO_DIR="$PWD/$REPO_NAME"
    if [[ -d "$REPO_DIR/.git" ]]; then
        ORIGIN_URL="$(git -C "$REPO_DIR" config --get remote.origin.url)" \
            || fail "The repository $REPO_DIR has no 'origin' remote (not cloned from GitHub?)."
        [[ "$(norm_url "$REPO_URL")" == "$(norm_url "$ORIGIN_URL")" ]] \
            || fail "The folder $REPO_DIR comes from $ORIGIN_URL, not from $REPO_URL."
    elif [[ -e "$REPO_DIR" ]]; then
        fail "$REPO_DIR exists but is not a Git repository: rename or move it, then run this script again."
    else
        # different computer (or folder deleted): the repository will be cloned
        CLONE_NEEDED=true
    fi
fi

# the token is stored for https://github.com, so the URL must use it
[[ "$REPO_URL" == https://github.com/* ]] \
    || fail "The URL must start with https://github.com/ (given: $REPO_URL)"

if $CLONE_NEEDED; then
    info "Repository: $REPO_URL -> not on this computer, it will be cloned into $REPO_DIR"
else
    info "Repository: $REPO_DIR ($REPO_URL)"
fi

######################################################
# 2. Check and configure Git on the computer
CUR_NAME="$(git config --global user.name)"
CUR_EMAIL="$(git config --global user.email)"
if [[ "$CUR_NAME" != "$STUDENT_NAME" || "$CUR_EMAIL" != "$STUDENT_EMAIL" ]]; then
    warn "Git identity on this computer was: '${CUR_NAME:-none}' <${CUR_EMAIL:-none}> -> updated."
fi

git config --global user.name "$STUDENT_NAME"
git config --global user.email "$STUDENT_EMAIL"
git config --global init.defaultBranch main
# pull = merge, avoids the warning message
git config --global pull.rebase false
# VS Code as editor for commit messages
git config --global core.editor "code --wait"
if (( CACHE_MINUTES == 0 )); then
    # token written to disk, in plain text, with no time limit
    git config --global credential.helper store
    TOKEN_INFO="token stored on disk in ~/.git-credentials"
    warn "The token will be saved in plain text in ~/.git-credentials (no time limit)."
else
    # token kept in memory only (never written to disk)
    git config --global credential.helper "cache --timeout=$((CACHE_MINUTES * 60))"
    TOKEN_INFO="token kept in memory for $CACHE_MINUTES min"
fi
ok "Git configured for $STUDENT_NAME <$STUDENT_EMAIL>"

######################################################
# 3. Put the GitHub token in the memory cache
if [[ -z "$GITHUB_TOKEN" ]]; then
    read -r -s -p "GitHub token for $GITHUB_USER (hidden input): " GITHUB_TOKEN
    echo
fi
[[ -n "$GITHUB_TOKEN" ]] || fail "No token given."

printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n' \
    "$GITHUB_USER" "$GITHUB_TOKEN" | git credential approve
unset GITHUB_TOKEN

# time when the token expires from the cache
# (date -d: Linux / WSL, date -r: macOS)
END_SEC=$(( $(date +%s) + CACHE_MINUTES * 60 ))
TOKEN_END="$(date -d "@$END_SEC" '+%H:%M (%d/%m)' 2>/dev/null || date -r "$END_SEC" '+%H:%M (%d/%m)')"

# check that the token gives access to the repository
info "Checking access to $REPO_URL ..."
if ! GIT_TERMINAL_PROMPT=0 git ls-remote "$REPO_URL" >/dev/null 2>&1; then
    printf 'protocol=https\nhost=github.com\nusername=%s\n\n' "$GITHUB_USER" | git credential reject
    fail "Cannot access the repository: wrong token, wrong login, wrong URL, or no access rights."
fi
ok "Access to the repository is OK ($TOKEN_INFO)"

if $CLONE_NEEDED; then
    ######################################################
    # 4. Not on this computer: clone it (= latest version from GitHub)
    info "Cloning the repository into $REPO_DIR ..."
    git clone -q "$REPO_URL" "$REPO_DIR" || fail "Clone failed."
    cd "$REPO_DIR" || fail "Cannot enter $REPO_DIR"
    BRANCH="$(git branch --show-current)"
    ok "Repository cloned: you have the latest version from GitHub."
else
    ######################################################
    # 4. Already on this computer: bring it up to date
    cd "$REPO_DIR" || fail "Cannot enter $REPO_DIR"

    # a merge must not be in progress
    if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
        conflict_help
        fail "A merge is already in progress: finish it first (steps above)."
    fi

    BRANCH="$(git branch --show-current)"
    [[ -n "$BRANCH" ]] || fail "No current branch (detached HEAD): go back to the main branch with 'git switch main', then run this script again."
    [[ "$BRANCH" == "main" ]] || warn "You are on branch '$BRANCH', not 'main'."

    # 4.1 Work left uncommitted at the end of a previous session: commit it FIRST
    if [[ -n "$(git status --porcelain)" ]]; then
        warn "Uncommitted changes left from a previous session:"
        git status -s
        DEFAULT_MSG="Unsaved work from previous session"
        read -r -p "Commit message [$DEFAULT_MSG]: " MSG
        MSG="${MSG:-$DEFAULT_MSG}"
        git add -A
        git commit -q -m "$MSG" || fail "Commit failed."
        ok "Committed: $MSG"
    fi

    # 4.2 Get GitHub's state, without changing anything
    info "Getting GitHub's state..."
    git fetch -q origin || fail "Cannot reach GitHub: check the network."

    if git rev-parse -q --verify "origin/$BRANCH" >/dev/null; then
        # 4.3 Compare: AHEAD = commits only here, BEHIND = commits only on GitHub
        read -r AHEAD BEHIND < <(git rev-list --left-right --count "HEAD...origin/$BRANCH")

        if (( AHEAD == 0 && BEHIND == 0 )); then
            # case 1: up to date
            ok "Up to date with GitHub."
        elif (( BEHIND == 0 )); then
            # case 3: ahead -> forgot to push last time
            warn "$AHEAD commit(s) of this computer were not on GitHub (push forgotten?): pushing them now."
            git push -q origin "$BRANCH" || fail "Push failed: check your token and the network."
            ok "Pushed."
        elif (( AHEAD == 0 )); then
            # case 2: behind -> work was done on another computer
            info "$BEHIND new commit(s) on GitHub (work done on another computer): updating..."
            git pull -q --no-rebase --no-edit origin "$BRANCH" || fail "git pull failed."
            ok "Updated."
        else
            # case 4: diverged -> commits on both sides: merge, then push
            warn "This computer ($AHEAD commit(s)) and GitHub ($BEHIND commit(s)) have diverged: merging..."
            if ! git pull -q --no-rebase --no-edit origin "$BRANCH"; then
                if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
                    conflict_help
                    fail "Merge stopped on a conflict: resolve it (steps above) before working."
                fi
                fail "git pull failed."
            fi
            git push -q origin "$BRANCH" || fail "Push failed: check your token and the network."
            ok "Merged and pushed."
        fi
    fi
fi

######################################################
# 5. Final check: this computer = GitHub
# check that origin points to the right repository
git remote -v
if git rev-parse -q --verify "origin/$BRANCH" >/dev/null; then
    git fetch -q origin
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse "origin/$BRANCH")" ]] \
        || fail "This computer and GitHub are still different: check with 'git status'."
    git status -sb
    # last 5 commits: the last one should be your "End of session ..." commit
    git log --oneline -5
else
    info "Branch '$BRANCH' is not on GitHub yet (empty repository?): it will be created by close_git_session.sh."
fi

######################################################
# 6. End
echo
ok "Ready to work: you have the latest version of your work."
token_reminder
echo "   cd $REPO_DIR"
echo "   At the end of the session: cd ~ && ./close_git_session.sh"
