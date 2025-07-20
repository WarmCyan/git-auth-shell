#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

function success() {
  echo -e "${GREEN}PASS${RESET}"
}
function fail() {
  echo -e "${RED}FAIL${RESET} ($1)"
}

export GIT_AUTH_USERS="./testdir/users"
export GIT_AUTH_REPOS="./testdir/repos"
export GIT_AUTH_LOG="./tests.log"

rm -rf testdir

# basic user and repo creation
export SSH_ORIGINAL_COMMAND="create test"
git-auth-shell.sh me

echo -n "Create..."
if [[ ! -d "testdir/users/me" ]]; then fail "userdir"
elif [[ ! -f "testdir/users/me/admin" ]]; then fail "admin"
elif [[ ! -f "testdir/users/me/write" ]]; then fail "write"
elif [[ $(cat "testdir/users/me/write") != "test" ]]; then fail "writecontents"
elif [[ $(cat "testdir/users/me/admin") != "test" ]]; then fail "admincontents"
elif [[ ! -d "testdir/repos/test" ]]; then fail "repo"
else success; fi;

# block illegal admin operation
export SSH_ORIGINAL_COMMAND="grant-admin notme test"
git-auth-shell.sh notme

echo -n "Block illegal grant-admin..."
if [[ ! -d "testdir/users/notme" ]]; then fail "userdir"
elif [[ $(cat "testdir/users/notme/admin") == "test" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/notme/write") == "test" ]]; then fail "writecontents"
else success; fi;

# block illegal admin operation
export SSH_ORIGINAL_COMMAND="grant-write notme test"
git-auth-shell.sh notme

echo -n "Block illegal grant-write..."
if [[ ! -d "testdir/users/notme" ]]; then fail "userdir"
elif [[ $(cat "testdir/users/notme/admin") == "test" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/notme/write") == "test" ]]; then fail "writecontents"
else success; fi;

# block illegal admin operation
export SSH_ORIGINAL_COMMAND="rename test testing"
git-auth-shell.sh notme

echo -n "Block illegal rename..."
if [[ ! -d "testdir/repos/test" ]]; then fail "originalrenamed"
elif [[ -d "testdir/repos/testing" ]]; then fail "newnameexists"
elif [[ $(cat "testdir/users/me/admin") != "test" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/me/write") != "test" ]]; then fail "writecontents"
elif [[ $(cat "testdir/users/notme/admin") == "testing" ]]; then fail "admincontents2"
elif [[ $(cat "testdir/users/notme/write") == "testing" ]]; then fail "writecontents2"
else success; fi;

# block illegal admin operation
export SSH_ORIGINAL_COMMAND="delete test"
git-auth-shell.sh notme

echo -n "Block illegal delete..."
if [[ ! -d "testdir/repos/test" ]]; then fail "originaldeleted"
elif [[ $(cat "testdir/users/me/admin") != "test" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/me/write") != "test" ]]; then fail "writecontents"
else success; fi;

# allow granting write
export SSH_ORIGINAL_COMMAND="grant-admin notme test"
git-auth-shell.sh me

echo -n "Allow granting admin..."
if [[ $(cat "testdir/users/notme/admin") != "test" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/notme/write") != "test" ]]; then fail "writecontents"
else success; fi;

# allow revoking admin
export SSH_ORIGINAL_COMMAND="revoke-admin notme test"
git-auth-shell.sh me

echo -n "Allow revoking admin..."
if [[ $(cat "testdir/users/notme/admin") == "test" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/notme/write") != "test" ]]; then fail "writecontents"
else success; fi;

# allow revoking write
export SSH_ORIGINAL_COMMAND="revoke-write notme test"
git-auth-shell.sh me

echo -n "Allow revoking admin..."
if [[ $(cat "testdir/users/notme/write") == "test" ]]; then fail "writecontents"
else success; fi;

# allow granting just write permissions
export SSH_ORIGINAL_COMMAND="grant-write notme test"
git-auth-shell.sh me

echo -n "Allow granting write..."
if [[ $(cat "testdir/users/notme/admin") == "test" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/notme/write") != "test" ]]; then fail "writecontents"
else success; fi;

# allow renaming for admin
export SSH_ORIGINAL_COMMAND="rename test testing"
git-auth-shell.sh me

echo -n "Allow admin rename..."
if [[ -d "testdir/repos/test" ]]; then fail "originalstillexists"
elif [[ ! -d "testdir/repos/testing" ]]; then fail "nonewfolder"
elif [[ $(cat "testdir/users/me/admin") != "testing" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/me/write") != "testing" ]]; then fail "writecontents"
elif [[ $(cat "testdir/users/notme/admin") == "testing" ]]; then fail "admincontents2"
elif [[ $(cat "testdir/users/notme/write") != "testing" ]]; then fail "writecontents2"
else success; fi;

# allow deleting for admin
export SSH_ORIGINAL_COMMAND="delete testing"
git-auth-shell.sh me

echo -n "Allow admin delete..."
if [[ -d "testdir/repos/testing" ]]; then fail "originalstillexists"
elif [[ $(cat "testdir/users/me/admin") == "testing" ]]; then fail "admincontents"
elif [[ $(cat "testdir/users/me/write") == "testing" ]]; then fail "writecontents"
elif [[ $(cat "testdir/users/notme/admin") == "testing" ]]; then fail "admincontents2"
elif [[ $(cat "testdir/users/notme/write") == "testing" ]]; then fail "writecontents2"
else success; fi;

rm -rf testdir
