# Small Git Server

TODO: tidy this up

It's possible to self host git repositories without something heavy like gitlab!

Git itself supports using the ssh protocol, meaning if you have a `git` user on
your machine, and an appropriate SSH key set up, you could clone a `my-repo`
repo in the `git` user's home directory with:

```
git clone git@mymachine:my-repo
```

This becomes a little trickier when you want to enable multiple people to have
access and have some semblance of authorization (as well as prevent them from
just SSHing into the machine and doing whatever).

The latter issue can be addressed through the use of `git-shell` and forced
commands in authorized keys files. `git-shell` is a tool that comes with `git`,
only accepting a very specific set of git commands for pulling/pushing. You
could either set `git-shell` as the default shell for the `git` user, or force
the command by putting this in the `authorized_keys` file for each SSH key:

```
restrict,command="git-shell -c \"$SSH_ORIGINAL_COMMAND\"" ssh-rsa AAA...
```

This prevents anyone with SSH access from doing anything other than git
commands, but it doesn't address multiuser permissions. The `git-auth-shell.sh`
in this repo provides an overly simplistic solution! The auth shell accepts an
additional set of commands for creating repos and managing admin/write
permissions. It assumes a username associated with a key is passed in, so the
prefix in the authorized keys becomes:

```
restrict,command="git-auth-shell.sh myusername \"$SSH_ORIGINAL_COMMAND\"" ssh-rsa AAA...
```


