#!/usr/bin/env bash

USERS=${GIT_AUTH_USERS-${HOME}/gitusers}
REPOS=${GIT_AUTH_REPOS-${HOME}/gitrepos}

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

# remove any .. and $ for safety
function sanitize_path() {
  repo=$1
  safe_repo="${repo//../}"
  safe_repo="${repo//\$/}"
  echo "$safe_repo"
}

function help () {
  echo "not implemented"
}

# ---------------------------------------------------------
# Repo folder commands
# ---------------------------------------------------------

# create new bare repo folder with specified name
# create_repo [repo]
function create_repo () {
  repo=$(sanitize_path "$1")
  if [[ -d "${REPOS}/${repo}" ]]; then
    echo "Repo ${repo} already exists"
    exit 1
  fi

  git init --bare --initial-branch=main "${REPOS}/${repo}"
 
  # add appropriate permissions
  echo "${repo}" >> "${USERS}/${GITUSER}/admin"
  echo "${repo}" >> "${USERS}/${GITUSER}/write"
  echo "Created repo $repo"
}

# move the repo folder (if you have admin)
# rename_repo [repo] [newrepo]
function rename_repo () {
  repo=$(sanitize_path "$1")

  if ! is_user_admin "$repo"; then
    echo "Admin permission required for this op on $repo"
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

  echo "Moved repo $repo to $newrepo"
}

# delete the repo folder
# (if you have admin)
# delete_repo [repo]
function delete_repo () {
  repo=$(sanitize_path "$1")

  if ! is_user_admin "$repo"; then
    echo "Admin permission required for this op on $repo"
    exit 1
  fi

  rm -rf "${REPOS:?}/${repo}"

  # update any permissions files
  IFS=$'\n'
  for user in $(list_writers "$repo"); do
    sed -i "/^${repo}$/d" "${USERS}/${user}/write"
  done
  for user in $(list_admins "$repo"); do
    sed -i "/^${repo}$/d" "${USERS}/${user}/admin"
  done

  echo "Deleted repo $repo"
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
    echo "Write permission required for this op on $repo"
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
    echo "Admin permission required for this op on $repo"
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
    echo "Admin permission required for this op on $repo"
    exit 1
  fi

  echo "$repo" >> "${USERS}/${user}/admin"
  echo "$repo" >> "${USERS}/${user}/write"
  echo "Admin permissions granted to $user for $repo"
}

# add specified user with write permissons to specified repo
# (if you have admin)
# grant_write [user] [repo]
function grant_write () {
  user=$(sanitize_path "$1")
  repo=$(sanitize_path "$2")
  
  if ! is_user_admin "$repo"; then
    echo "Admin permission required for this op on $repo"
    exit 1
  fi

  echo "$repo" >> "${USERS}/${user}/write"
  echo "Write permissions granted to $user for $repo"
}

# remove specified user as an admin to specified repo
# (if you have admin)
# revoke_admin [user] [repo]
function revoke_admin () {
  user=$(sanitize_path "$1")
  repo=$(sanitize_path "$2")
  
  if ! is_user_admin "$repo"; then
    echo "Admin permission required for this op on $repo"
    exit 1
  fi

  sed -i "/^${repo}$/d" "${USERS}/${user}/admin"
  echo "Admin permissions removed from $repo for $user"
}

# remove specified user with write permissions to specified repo
# (if you have admin)
# revoke_write [user] [repo]
function revoke_write () {
  user=$(sanitize_path "$1")
  repo=$(sanitize_path "$2")
  
  if ! is_user_admin "$repo"; then
    echo "Admin permission required for this op on $repo"
    exit 1
  fi

  sed -i "/^${repo}$/d" "${USERS}/${user}/write"
  echo "Write permissions removed from $repo for $user"
}

# =========================================================

ensure_paths
ensure_user

cmd_array=($SSH_ORIGINAL_COMMAND)
echo "$(date +%D-%T):${GITUSER}:${SSH_ORIGINAL_COMMAND}" >> "${HOME}/git-commands.log"
# echo "${cmd_array[3]}"

cmd_word="${cmd_array[0]}"
if [[ "$cmd_word" == "create" ]]; then
  create_repo "${cmd_array[1]}"
elif [[ "$cmd_word" == "rename" ]]; then
  rename_repo "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "delete" ]]; then
  delete_repo "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "list-admin" ]]; then
  list_admin
elif [[ "$cmd_word" == "list-write" ]]; then
  list_write
elif [[ "$cmd_word" == "list-admins" ]]; then
  list_admins "${cmd_array[1]}"
elif [[ "$cmd_word" == "list-writers" ]]; then
  list_writers "${cmd_array[1]}"
elif [[ "$cmd_word" == "grant-admin" ]]; then
  grant_admin "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "grant-write" ]]; then
  grant_write "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "revoke-admin" ]]; then
  revoke_admin "${cmd_array[1]}" "${cmd_array[2]}"
elif [[ "$cmd_word" == "revoke-write" ]]; then
  revoke_write "${cmd_array[1]}" "${cmd_array[2]}"

elif [[ "$cmd_word" == "git" ]]; then
  if [[ "${cmd_array[2]}" == "receive-pack" ]]; then
    if ! is_user_writer "${cmd_array[3]}"; then
      echo "User doesn't have write permissions for this repo."
      exit 1
    fi
  fi
  # elif [[ "${cmd_array[2]}" == "upload-archive" ]]; then
  #   if ! is_user_writer "${cmd_array[3]}"; then
  #     echo "User doesn't have write permissions for this repo."
  #     exit 1
  #   fi
  # fi
  pushd "${REPOS}" > /dev/null
  echo -e "\t$(pwd)" >> "${HOME}/git-commands.log"
  git-shell -c "${cmd_array[@]:1}"
  popd > /dev/null
fi
