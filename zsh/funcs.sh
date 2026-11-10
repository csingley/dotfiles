# Personal shell functions, sourced by every interactive zsh.

venv-create() {
  local projectdir
  projectdir=$(realpath "$1")
  mkdir -p "$projectdir"
  python3 -m venv --upgrade-deps "$projectdir"
  . "$projectdir"/bin/activate
  cd "$projectdir" || return
}

# sudo's secure_path leaves out the Nix profile, so `sudo iftop` says "command not found". Hand it
# the full path of the command this shell would run. Only the plain `sudo cmd` form: with options
# first (sudo -u user cmd) or a builtin, function or alias, sudo gets the arguments as typed.
sudo() {
  local cmd=${commands[$1]-}
  if [[ -n $cmd && $1 != -* ]]; then
    command sudo "$cmd" "${@:2}"
  else
    command sudo "$@"
  fi
}
