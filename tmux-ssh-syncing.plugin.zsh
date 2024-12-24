#!/hint/zsh

# Copyright (c) 2024, Andrea Alberti

# Safe method to retrieve the plugin path
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# ${0:h} -> plugin directory
fpath=("${0:h}/src" $fpath)
autoload -Uz ssh
