#!/hint/zsh

# Copyright (c) 2024, Andrea Alberti

# Safe method to retrieve the path of the plugin init script
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# Path to 'src' directory containg the files to be sourced
local src_dir
src_dir="${0:h}/src"

# Dynamically define the function with expanded value of $src_dir
ssh() {
  typeset -g src_ssh
  if [[ -z "$src_ssh" ]]; then
    src_ssh="$src_dir/ssh.zsh"
  else
    source "$src_ssh"
    ssh "$@"
  fi
}
# Initialize src_ssh
ssh