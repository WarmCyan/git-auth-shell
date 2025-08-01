#!/usr/bin/env bash

# ==============================================================
# git-auth-shell
# An expanded git-shell for use as a forced ssh command, allowing basic user
# authorization and git repo administration commands through a single git user
# (rather than every user having their own account on the machine itself.)
#
# Expects to be used via ssh authorized_keys, recommended key lines:
# restrict,command="git-auth-shell.sh [USERNAME_FOR_THIS_KEY] \"$SSH_ORIGINAL_COMMAND\"" ssh-rsa AAA...
#
# Author: Nathan Martindale
# License: MIT
# ==============================================================

USERS=${GIT_AUTH_USERS-${HOME}/gitusers}
REPOS=${GIT_AUTH_REPOS-${HOME}/gitrepos}
LOGLOC=${GIT_AUTH_LOG-${HOME}/gitlog.log}

GITUSER="$1"

# ---------------------------------------------------------
# utils
# ---------------------------------------------------------

function ensure_paths() {
  mkdir -p "$USERS"
  mkdir -p "$REPOS"
}

function ensure_user() {
  if [[ ! -d "${USERS}/${GITUSER}" ]]; then
    mkdir "${USERS}/${GITUSER}"
    touch "${USERS}/${GITUSER}/admin"
    touch "${USERS}/${GITUSER}/write"
  fi
}

function is_user_admin() {
  repo=$1
  grep -q "^${repo}\$" < "${USERS}/${GITUSER}/admin" && return 0
  return 1
}

function is_user_writer() {
  repo=$1
  grep -q "^${repo}\$" < "${USERS}/${GITUSER}/write" && return 0
  return 1
}

# remove any potentially problematic characters for safety
function sanitize_path() {
  repo=$1
  safe_repo="${repo//../}"
  safe_repo="${repo//\$/}"
  safe_repo="${repo//\;/}"
  safe_repo="${repo//\\/}"
  safe_repo="${repo//\{/}"
  safe_repo="${repo//\}/}"
  safe_repo="${repo//\(/}"
  safe_repo="${repo//\)/}"
  safe_repo="${repo//\`/}"
  safe_repo="${repo//\[/}"
  safe_repo="${repo//\]/}"
  safe_repo="${repo//\,/}"
  safe_repo="${repo//\n/}"
  safe_repo="${repo//\\n/}"
  echo "$safe_repo"
}

function show_help () {
  echo "Run any of the following commands with:"
  echo -e "\tssh git@someip [command] [args...]"
  echo -e "\nCommands:"
  echo -e "\tcreate [repo]"
  echo -e "\trename [repo] [newname]  # (requires admin)"
  echo -e "\tdelete [repo]  # (requires admin)"
  echo -e "\tlist-admin  # list all repos you have admin privileges for"
  echo -e "\tlist-write  # list all repos you have write privileges for"
  echo -e "\tlist-admins [repo]  # list all users with admin privileges for repo"
  echo -e "\tlist-writers [repo]  # list all users with write privileges for repo"
  echo -e "\tgrant-admin [user] [repo]  # give admin privileges to user for repo (requires admin)"
  echo -e "\tgrant-write [user] [repo]  # give write privileges to user for repo (requires admin)"
  echo -e "\trevoke-admin [user] [repo]  # remove admin privileges from user for repo (requires admin)"
  echo -e "\trevoke-write [user] [repo]  # remove write privileges from user for repo (requires admin)"
}

function log () {
  echo "$(date +%D-%T):${GITUSER}:$1" >> "$LOGLOC"
}

function logecho () {
  echo -e "\t$1" >> "$LOGLOC"
  echo "$1"
}

# ---------------------------------------------------------
# Repo folder commands
# ---------------------------------------------------------

# create new bare repo folder with specified name
# create_repo [repo]
function create_repo () {
  repo=$(sanitize_path "$1")
  if [[ -d "${REPOS}/${repo}" ]]; then
    logecho "Repo ${repo} already exists"
    exit 1
  fi

  git init --bare --initial-branch=main "${REPOS}/${repo}"
 
  # add appropriate permissions
  echo "${repo}" >> "${USERS}/${GITUSER}/admin"
  echo "${repo}" >> "${USERS}/${GITUSER}/write"
  logecho "Created repo $repo"
}

# move the repo folder (if you have admin)
# rename_repo [repo] [newrepo]
function rename_repo () {
  repo=$(sanitize_path "$1")

  if ! is_user_admin "$repo"; then
    logecho "Admin permission required for this op on $repo"
    exit 1
  fi

  newrepo=$(sanitize_path "$2")
  mv "${REPOS}/${repo}" "${REPOS}/${newrepo}"

  # update any permissions files
  IFS=$'\n'
  for user in $(list_writers "$repo"); do
    sed -i -e "s/^${repo}$/${newrepo}/g" "${USERS}/${user}/write"
  done
  for user in $(list_admins "$repo"); do
    sed -i -e "s/^${repo}$/${newrepo}/g" "${USERS}/${user}/admin"
  done

  logecho "Moved repo $repo to $newrepo"
}

# delete the repo folder
# (if you have admin)
# delete_repo [repo]
function delete_repo () {
  repo=$(sanitize_path "$1")

  if ! is_user_admin "$repo"; then
    logecho "Admin permission required for this op on $repo"
    exit 1
  fi

  rm -rf "${REPOS:?}/${repo}"

  # update any permissions files
  IFS=$'\n'
  for user in $(list_writers "$repo"); do
    sed -i -e "/^${repo}$/d" "${USERS}/${user}/write"
  done
  for user in $(list_admins "$repo"); do
    sed -i -e "/^${repo}$/d" "${USERS}/${user}/admin"
  done

  logecho "Deleted repo $repo"
}

# ---------------------------------------------------------
# Listing commands
# ---------------------------------------------------------

# list all repos
# list_repos
# function list_repos () {
#   echo "not implemented"
# }

# list all repos current user as admin perms for
# list_admin
function list_admin () {
  cat "${USERS}/${GITUSER}/admin"
}

# list all repos current user as write perms for
# list_write
function list_write () {
  cat "${USERS}/${GITUSER}/write"
}

# list all users with write permissions for specified repo
# (if you have write)
# list_writers [repo]
function list_writers () {
  repo=$(sanitize_path "$1")

  if ! is_user_writer "$repo"; then
    logecho "Write permission required for this op on $repo"
    exit 1
  fi

  pushd "${USERS}" > /dev/null
  IFS=$'\n'
  # printf to remove prefix ./
  for user_dir in $(find . -mindepth 1 -maxdepth 1 -type d -printf '%P\n'); do
    grep -q "^${repo}\$" < "${user_dir}/write" && echo "${user_dir}"
  done;
  popd > /dev/null
}

# list all users with admin permissions for specified repo
# (if you have admin)
# list_admins [repo]
function list_admins () {
  repo=$(sanitize_path "$1")

  if ! is_user_admin "$repo"; then
    logecho "Admin permission required for this op on $repo"
    exit 1
  fi

  pushd "${USERS}" > /dev/null
  IFS=$'\n'
  # printf to remove prefix ./
  for user_dir in $(find . -mindepth 1 -maxdepth 1 -type d -printf '%P\n'); do
    grep -q "^${repo}\$" < "${user_dir}/admin" && echo "${user_dir}"
  done;
  popd > /dev/null
}

# ---------------------------------------------------------
# Permission commands
# ---------------------------------------------------------

# add specified user as an admin to specified repo
# (if you have admin)
# grant_admin [user] [repo]
function grant_admin () {
  user=$(sanitize_path "$1")
  repo=$(sanitize_path "$2")
  
  if ! is_user_admin "$repo"; then
    logecho "Admin permission required for this op on $repo"
    exit 1
  fi

  echo "$repo" >> "${USERS}/${user}/admin"
  echo "$repo" >> "${USERS}/${user}/write"
  logecho "Admin permissions granted to $user for $repo"
}

# add specified user with write permissons to specified repo
# (if you have admin)
# grant_write [user] [repo]
function grant_write () {
  user=$(sanitize_path "$1")
  repo=$(sanitize_path "$2")
  
  if ! is_user_admin "$repo"; then
    logecho "Admin permission required for this op on $repo"
    exit 1
  fi

  echo "$repo" >> "${USERS}/${user}/write"
  logecho "Write permissions granted to $user for $repo"
}

# remove specified user as an admin to specified repo
# (if you have admin)
# revoke_admin [user] [repo]
function revoke_admin () {
  user=$(sanitize_path "$1")
  repo=$(sanitize_path "$2")
  
  if ! is_user_admin "$repo"; then
    logecho "Admin permission required for this op on $repo"
    exit 1
  fi

  sed -i "/^${repo}$/d" "${USERS}/${user}/admin"
  logecho "Admin permissions removed from $repo for $user"
}

# remove specified user with write permissions to specified repo
# (if you have admin)
# revoke_write [user] [repo]
function revoke_write () {
  user=$(sanitize_path "$1")
  repo=$(sanitize_path "$2")
  
  if ! is_user_admin "$repo"; then
    logecho "Admin permission required for this op on $repo"
    exit 1
  fi

  sed -i "/^${repo}$/d" "${USERS}/${user}/write"
  logecho "Write permissions removed from $repo for $user"
}

# =========================================================

ensure_paths
ensure_user

cmd_array=($SSH_ORIGINAL_COMMAND)
log "$(date +%D-%T):${GITUSER}:${SSH_ORIGINAL_COMMAND}"

cmd_word="${cmd_array[0]}"
if [[ "$cmd_word" == "help" ]]; then
  show_help
elif [[ "$cmd_word" == "create" ]]; then
  if [[ "${#cmd_array[@]}" -lt 2 ]]; then
    logecho "Missing arguments, please use 'create [repo]'"
    exit 1
  fi
  create_repo "${cmd_array[1]}"
elif [[ "$cmd_word" == "rename" ]]; then
  if [[ "${#cmd_array[@]}" -lt 3 ]]; then
    logecho "Missing arguments, please use 'rename [repo] [newname]'"
    exit 1
  fi
  rename_repo "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "delete" ]]; then
  if [[ "${#cmd_array[@]}" -lt 2 ]]; then
    logecho "Missing arguments, please use 'delete [repo]'"
    exit 1
  fi
  delete_repo "${cmd_array[1]}"
elif [[ "$cmd_word" == "list-admin" ]]; then
  list_admin
elif [[ "$cmd_word" == "list-write" ]]; then
  list_write
elif [[ "$cmd_word" == "list-admins" ]]; then
  if [[ "${#cmd_array[@]}" -lt 2 ]]; then
    logecho "Missing arguments, please use 'list-admins [repo]'"
    exit 1
  fi
  list_admins "${cmd_array[1]}"
elif [[ "$cmd_word" == "list-writers" ]]; then
  if [[ "${#cmd_array[@]}" -lt 2 ]]; then
    logecho "Missing arguments, please use 'list-writers [repo]'"
    exit 1
  fi
  list_writers "${cmd_array[1]}"
elif [[ "$cmd_word" == "grant-admin" ]]; then
  if [[ "${#cmd_array[@]}" -lt 3 ]]; then
    logecho "Missing arguments, please use 'grant-admin [user] [repo]'"
    exit 1
  fi
  grant_admin "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "grant-write" ]]; then
  if [[ "${#cmd_array[@]}" -lt 3 ]]; then
    logecho "Missing arguments, please use 'grant-write [user] [repo]'"
    exit 1
  fi
  grant_write "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "revoke-admin" ]]; then
  if [[ "${#cmd_array[@]}" -lt 3 ]]; then
    logecho "Missing arguments, please use 'revoke-admin [user] [repo]'"
    exit 1
  fi
  revoke_admin "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "revoke-write" ]]; then
  if [[ "${#cmd_array[@]}" -lt 3 ]]; then
    logecho "Missing arguments, please use 'revoke-write [user] [repo]'"
    exit 1
  fi
  revoke_write "${cmd_array[1]}" "${cmd_array[2]}"

elif [[ "$cmd_word" == "git-receive-pack" || "$cmd_word" == "git-upload-pack" || "$cmd_word" == "git-upload-archive" ]]; then
  if [[ "$cmd_word" == "git-receive-pack" ]]; then
    if ! is_user_writer ${cmd_array[1]:1:-1}; then  # DON'T QUOTE already has single quotes
      logecho "User doesn't have write permissions for this repo."
      exit 1
    fi
  fi
  pushd "${REPOS}" > /dev/null
  git-shell -c "${SSH_ORIGINAL_COMMAND}"
  popd > /dev/null
else
  logecho "Command not recognized."
  show_help
fi
