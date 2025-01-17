# Copyright (c) 2024, Andrea Alberti

ssh() {
  emulate -LR zsh
  
  function __tmux_ssh_build_remote_window_name() {
    trap '' INT # Prevent interruption inside this function
    local remote_host_name
    typeset -aU remote_window_name # Unique array

    # Loop through all panes in the current window
    while read -r pane_id; do
      # Check if the pane has a remote host name set
      remote_host_name=$(tmux show-option -t "$pane_id" -pqv @remote-host-name)
      if [[ -n "$remote_host_name" ]]; then
        # Add to array if not already present
        remote_window_name+=("$remote_host_name")
      fi
    done < <(tmux list-panes -t "$current_window_id" -F "#{pane_id}")

    # Join the array elements with a "+" separator
    echo "${(j:+:)remote_window_name}"
  }

  # Define a cleanup function for the trap
  # shellcheck disable=SC2317
  function __tmux_ssh_cleanup() {
    trap '' INT # Prevent interruption inside this function
    local remote_window_name original_window_name current_window_id current_pane_id

    current_window_id=$1
    current_pane_id=$2

    # Remove the host name from the list after SSH exits
    tmux set-option -t "$current_pane_id" -up @remote-host-name

    # Rebuild the window name after SSH exits
    remote_window_name=$(__tmux_ssh_build_remote_window_name)

    # Restore the original window name if no more active SSH sessions
    if [[ -z "$remote_window_name" ]]; then
      original_window_name="$(tmux show-option -t "$current_pane_id" -wqv "@original-window-name")"
      tmux rename-window -t "$current_pane_id" "$original_window_name"
      # Remove the window name variable when there are no more SSH sessions active
      tmux set-option -t "$current_pane_id" -uwq "@original-window-name"
    else
      tmux rename-window -t "$current_pane_id" "$remote_window_name"
    fi
  }

  # Skip if not in a tmux session
  if [[ -z "$TMUX" ]]; then
    command ssh "$@"
    return
  fi

  # Get the current tmux window and pane IDs
  local current_window_id current_pane_id original_window_name
  current_window_id=$(tmux display-message -p "#{window_id}")
  current_pane_id=$(tmux display-message -p "#{pane_id}")

  # Perform a dry-run to get the remote host name
  local remote_host_name
  remote_host_name=$(command ssh -G "$@" 2>/dev/null | awk '/^host / {print $2}' 2>/dev/null )
  remote_host_name=${remote_host_name:-"unknown"}

  # Save the original window name if not already stored
  if [[ -z "$(tmux show-option -t "$current_pane_id" -wqv "@original-window-name")" ]]; then
    original_window_name="$(tmux display-message -t "$current_pane_id" -p "#W")"
    tmux set-option -wq "@original-window-name" "$original_window_name"
  fi

  # Store the remote host name for this pane
  tmux set-option -pq @remote-host-name "$remote_host_name"

  # Build the concatenated window name
  local remote_window_name
  remote_window_name=$(__tmux_ssh_build_remote_window_name)
  
  # Rename the TMUX window to the concatenated name
  tmux rename-window "$remote_window_name"

  # Execute the clean up function
  local cleanup_cmd
  cleanup_cmds="
  __tmux_ssh_cleanup '$current_window_id' '$current_pane_id'
    # Avoid function pollution
    unfunction __tmux_ssh_build_remote_window_name __tmux_ssh_cleanup
  "
  trap "$cleanup_cmds" EXIT
  trap "return 1" TERM INT

  # Start SSH process in the background
  command ssh "$@"
}
