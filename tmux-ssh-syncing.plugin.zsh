#!/hint/zsh

# Copyright (c) 2024, Andrea Alberti

# Dynamically load 'ssh' function by overwriting
# the loader function below with the actual function
function ssh() {
  local loader_path
  loader_path="${(%):-%x}"

  # Determine the directory of the loader and append the src path
  local src_path="${loader_path:h}/src/ssh.zsh"

  # Source the actual implementation
  source "$src_path"

  # Overwrite this function with the actual implementation
  ssh "$@"
}
