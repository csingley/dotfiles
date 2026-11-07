# Personal shell functions, sourced by every interactive zsh.

venv-create() {
  local projectdir
  projectdir=$(realpath "$1")
  mkdir -p "$projectdir"
  python3 -m venv --upgrade-deps "$projectdir"
  . "$projectdir"/bin/activate
  cd "$projectdir" || return
}
