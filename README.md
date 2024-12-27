# tmux-ssh-syncing Plugin for Zsh Shell

Synchronize your `tmux` window names with active `ssh` sessions. This plugin dynamically updates the `tmux` window name to reflect the remote hosts of active `ssh` sessions in the same window. It also restores the original window name when all `ssh` sessions are closed.

## Features

- Dynamically updates `tmux` window names to show connected remote hosts.
- Ensures unique and clean concatenation of remote hostnames.
- Automatically restores the original `tmux` window name when no `ssh` sessions remain.
- Works seamlessly with `oh-my-zsh` and `zinit` plugin managers.

<a href="https://asciinema.org/a/696301" target="_blank"><img src="https://asciinema.org/a/696301.svg" alt="Screenshot" /></a>

---

## Installation

### Using [oh-my-zsh](https://ohmyz.sh)

1. Clone the repository into the `custom/plugins` directory:
   ```
   git clone https://github.com/alberti42/tmux-ssh-syncing.git $ZSH_CUSTOM/plugins/tmux-ssh-syncing
   ```

2. Add the plugin to your `.zshrc`:
   ```
   plugins=(... tmux-ssh-syncing)
   ```

3. Restart your terminal or reload your shell:
   ```
   source ~/.zshrc
   ```

### Using [zinit](https://github.com/zdharma-continuum/zinit)

1. Add the following to your `.zshrc`:
   ```
   zinit ice lucid wait
   zinit light alberti42/tmux-ssh-syncing
   ```

2. Restart your terminal or reload your shell:
   ```
   source ~/.zshrc
   ```

---

## How It Works

- When you start an `ssh` session inside `tmux`, the plugin:
  - Captures the remote hostname of the session.
  - Appends the hostname to the current `tmux` window name.
  - Ensures unique hostnames in the window name.
- When the `ssh` session ends:
  - The plugin removes the hostname from the `tmux` window name.
  - If no active `ssh` sessions remain, it restores the original window name.

---

## Example

1. Open a `tmux` session.
2. Start an `ssh` session:
   ```
   ssh user@remote-host
   ```
   The `tmux` window name updates to:
   ```
   remote-host
   ```

3. Open another pane and start a new `ssh` session:
   ```
   ssh user@another-host
   ```
   The `tmux` window name updates to:
   ```
   remote-host+another-host
   ```

4. Exit one or both `ssh` sessions, and the window name dynamically adjusts or restores to its original name.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
