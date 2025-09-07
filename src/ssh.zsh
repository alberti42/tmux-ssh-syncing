# Copyright (c) 2024, Andrea Alberti

ssh() {
  emulate -LR zsh

  # --- cursor helpers -------------------------------------------------------

  # Query cursor style via DECRQSS for DECSCUSR (CSI Ps SP q)
  # Returns empty on failure, or 0..6 on success.
  __tmux_query_cursor_style() {
    local fd buf chunk i
    local ESC=$'\e'                       # ESC
    local DCS=$'\eP'                      # ESC P
    local ST=$'\e\\'                      # ESC \  (String Terminator)
    local DECRQSS=$'\eP$q q\e\\'          # DCS $ q " q " ST
    local stty_orig cursor_style dcs_reply ps

    # Open TTY; bail quietly if it fails
    exec {fd}<> /dev/tty || return 0

    { # --- try block ---
      
      # Raw-ish mode so reply isn't echoed/line-buffered
      stty_orig=$(stty -g <&$fd)
      stty -echo -icanon time 0 min 0 <&$fd
      
      # Ask: terminal replies DCS "1$r q<Ps> q" ST (success)
      printf '%s' "$DECRQSS" > /dev/tty

      buf=''
      # Read until we see ST (ESC \) anywhere in the buffer (cap ~2s)
      for i in {1..100}; do
        IFS= read -r -u $fd -k 1 -t 0.01 chunk || chunk=''
        [[ -n "$chunk" ]] && buf+="$chunk"
        [[ $buf == *"$ST"* ]] && break
      done

      # Extract first DCS block and require DECRQSS success "1$r"
      [[ $buf == *"$DCS"*"$ST"* ]] || return 0
      dcs_reply=${buf#*"$DCS"}
      dcs_reply=${dcs_reply%%"$ST"*}
      
      # Must be a success reply
      [[ $dcs_reply == 1'$r'* ]] || return 0

      ps=''
      if [[ $dcs_reply == '1$r q'[0-6]' q'* ]]; then
        ps="${dcs_reply#'1$r q'}"
        ps="${ps%%' q'*}"
      fi
      
      # Validate 0..6 and print
      if [[ $ps = <-> && $ps -ge 0 && $ps -le 6 ]]; then
        print -r -- "$ps"
      fi
      return 0
    } always {
      # --- always cleanup, even on early return ---
      
      # Restore TTY and close FD
      stty "$stty_orig" <&$fd 2>/dev/null
      : {fd}>&-
    }
  }

  # Map tmux's cursor-style option to DECSCUSR Ps
  __tmux_ps_from_tmux_cursor_style() {
    local style
    style="$(command tmux display-message -p "#{?cursor-style,#{cursor-style},}")"
    [[ -z "$style" ]] && style="$(command tmux show -gqv cursor-style 2>/dev/null)"
    style="${style:l}"; style="${style//_/-}"
    case "$style" in
      ""|default)         print -r -- "0" ;;
      blinking-block)     print -r -- "1" ;;
      block)              print -r -- "2" ;;
      blinking-underline) print -r -- "3" ;;
      underline)          print -r -- "4" ;;
      blinking-bar)       print -r -- "5" ;;
      bar)                print -r -- "6" ;;
      *)                  print -r -- "0" ;;
    esac
  }

  # Set cursor style if we have a valid Ps in [0..6]
  __tmux_set_cursor_style() {
    local ps="$1"
    # numeric guard
    [[ $ps = <-> ]] && (( ps >= 0 && ps <= 6 )) || return 0

    # Prefer writing to the controlling TTY; fall back to stdout if unavailable
    if [[ -w /dev/tty ]]; then
      printf $'\e['"%s"$' q' "$ps" > /dev/tty
    else
      printf $'\e['"%s"$' q' "$ps"
    fi
  }

  # --- tmux window name helpers --------------------------------------------

  function __tmux_ssh_build_remote_window_name() {
    trap '' INT # Prevent interruption inside this function
    local remote_host_name
    typeset -aU remote_window_name # Unique array

    # Loop through all panes in the current window
    while read -r pane_id; do
      # Check if the pane has a remote host name set
      remote_host_name=$(command tmux show-option -t "$pane_id" -pqv @remote-host-name)
      if [[ -n "$remote_host_name" ]]; then
        # Add to array if not already present
        remote_window_name+=("$remote_host_name")
      fi
    done < <(command tmux list-panes -t "$current_window_id" -F "#{pane_id}")

    # Join the array elements with a "+" separator
    echo "${(j:+:)remote_window_name}"
  }

  # Define a cleanup function for the trap
  # shellcheck disable=SC2317
  function __tmux_ssh_cleanup() {
    trap '' INT # Prevent interruption inside this function
    local remote_window_name original_window_name current_window_id current_pane_id orig_cursor_style

    current_window_id=$1
    current_pane_id=$2

    # Remove the host name from the list after SSH exits
    command tmux set-option -t "$current_pane_id" -up @remote-host-name

    # Rebuild the window name after SSH exits
    remote_window_name=$(__tmux_ssh_build_remote_window_name)

    # Restore the original window name if no more active SSH sessions
    if [[ -z "$remote_window_name" ]]; then
      original_window_name="$(command tmux show-option -t "$current_pane_id" -wqv "@original-window-name")"
      command tmux rename-window -t "$current_pane_id" "$original_window_name"
      # Remove the window name variable when there are no more SSH sessions active
      command tmux set-option -t "$current_pane_id" -uwq "@original-window-name"
    else
      command tmux rename-window -t "$current_pane_id" "$remote_window_name"
    fi

    # Restore original cursor style if we captured it
    orig_cursor_style="$(command tmux show-option -t "$current_pane_id" -wqv "@original-cursor-style")"
    if [[ -n "$orig_cursor_style" ]]; then
      __tmux_set_cursor_style "$orig_cursor_style"
      # clear stored value
      command tmux set-option -t "$current_pane_id" -uwq "@original-cursor-style"
    fi
  }

  # Skip if not in a tmux session
  if [[ -z "$TMUX" ]]; then
    command ssh "$@"
    return
  fi

  # Get the current tmux window and pane IDs
  local current_window_id current_pane_id original_window_name
  current_window_id=$(command tmux display-message -p "#{window_id}")
  current_pane_id=$(command tmux display-message -p "#{pane_id}")

  # Capture original cursor style (best-effort)
  local cursor_style
  if [[ -z "$(command tmux show-option -t "$current_pane_id" -wqv "@original-cursor-style")" ]]; then
    cursor_style="$(__tmux_query_cursor_style)"
    [[ -z "$cursor_style" ]] && cursor_style="$(__tmux_ps_from_tmux_cursor_style)"
    command tmux set-option -t "$current_pane_id" -wq "@original-cursor-style" "$cursor_style"
  fi
  
  # Compute remote host and update window name
  local remote_host_name
  remote_host_name=$(command ssh -G "$@" 2>/dev/null | awk '/^host / {print $2}' 2>/dev/null )
  remote_host_name=${remote_host_name:-"unknown"}

  # Save the original window name if not already stored
  if [[ -z "$(command tmux show-option -t "$current_pane_id" -wqv "@original-window-name")" ]]; then
    original_window_name="$(command tmux display-message -t "$current_pane_id" -p "#W")"
    command tmux set-option -wq "@original-window-name" "$original_window_name"
  fi

  # Store the remote host name for this pane
  command tmux set-option -pq @remote-host-name "$remote_host_name"

  # Build the concatenated window name
  local remote_window_name
  remote_window_name=$(__tmux_ssh_build_remote_window_name)
  
  # Rename the TMUX window to the concatenated name
  command tmux rename-window "$remote_window_name"

  # Execute the clean up function
  local cleanup_cmds
  cleanup_cmds="
  __tmux_ssh_cleanup '$current_window_id' '$current_pane_id'
    # Avoid function pollution
    unfunction __tmux_ssh_build_remote_window_name __tmux_ssh_cleanup \
           __tmux_query_cursor_style __tmux_set_cursor_style \
           __tmux_ps_from_tmux_cursor_style
  "
  trap "$cleanup_cmds" EXIT
  trap "return 1" TERM INT

  # Start SSH process in the background
  command ssh "$@"
}
