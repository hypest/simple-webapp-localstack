#!/usr/bin/env bash
set -euo pipefail

# post-create script for devcontainer
# - installs awscli-local (pip)
# - symlinks version-controlled dotfiles from repo/dotfiles into $HOME (backing up existing files)
# - ensures shells source ~/.bash_aliases

echo "Running devcontainer post-create script"

# --- install awscli-local (prefer pipx, fallback to a per-user venv) ---
echo "Ensuring awscli-local (awslocal) is available"
if command -v pipx >/dev/null 2>&1; then
  # Prefer pipx to install user-level CLI tools in isolated venvs
  if ! pipx list 2>/dev/null | grep -q "awscli-local"; then
    echo "Installing awscli-local via pipx..."
    pipx install awscli-local || true
  else
    echo "awscli-local already installed via pipx"
  fi
elif command -v python3 >/dev/null 2>&1; then
  # Fall back to creating a small per-user virtualenv and symlinking the awslocal binary
  PYTHON=$(command -v python3)
  VENV_DIR="$HOME/.local/awscli-local-venv"
  if [ ! -x "$VENV_DIR/bin/awslocal" ]; then
    echo "Creating venv at $VENV_DIR and installing awscli-local..."
    mkdir -p "$(dirname "$VENV_DIR")"
    "$PYTHON" -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel >/dev/null
    "$VENV_DIR/bin/pip" install awscli-local >/dev/null
    mkdir -p "$HOME/.local/bin"
    ln -sf "$VENV_DIR/bin/awslocal" "$HOME/.local/bin/awslocal"
    echo "Installed awslocal to $HOME/.local/bin/awslocal"
  else
    echo "awscli-local already installed in venv"
  fi
  # Ensure ~/.local/bin is on PATH for interactive shells (non-interactive devcontainer lifecycle usually preserves PATH)
  if ! grep -q "export PATH=\$HOME/.local/bin" "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
  fi
else
  echo "No pipx or python3 found; skipping awscli-local install"
fi

# --- dotfiles linking ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOTFILES_DIR="$REPO_ROOT/dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
  echo "Found dotfiles in $DOTFILES_DIR; linking to $HOME"
  # enable globbing to include dotfiles
  shopt -s dotglob nullglob
  for src in "$DOTFILES_DIR"/* "$DOTFILES_DIR"/.*; do
    # skip if nothing matches
    [ -e "$src" ] || continue
    name="$(basename "$src")"
    # skip . and ..
    [ "$name" = "." ] && continue
    [ "$name" = ".." ] && continue
    target="$HOME/$name"

    # if target is already a symlink to the right place, skip
    if [ -L "$target" ]; then
      if [ "$(readlink -f "$target")" = "$src" ]; then
        echo "Symlink for $name already correct"
        continue
      else
        echo "Removing stale symlink $target"
        rm -f "$target"
      fi
    fi

    if [ -e "$target" ]; then
      ts=$(date +%Y%m%d%H%M%S)
      backup="$target.bak.$ts"
      echo "Backing up existing $target -> $backup"
      mv "$target" "$backup"
    fi

    ln -s "$src" "$target"
    echo "Linked $target -> $src"
  done
  shopt -u dotglob nullglob
else
  echo "No $DOTFILES_DIR directory found; skipping dotfiles linking"
fi

# --- ensure shells source ~/.bash_aliases ---
ALIASES_FILE="$HOME/.bash_aliases"
if ! grep -q "if [ -f ~/.bash_aliases ]" "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'BASHRC'

# Load user aliases if present
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi
BASHRC
  echo "Appended sourcing of aliases to ~/.bashrc"
else
  echo "~/.bashrc already sources ~/.bash_aliases"
fi

if command -v zsh >/dev/null 2>&1; then
  if [ ! -f "$HOME/.zshrc" ]; then
    touch "$HOME/.zshrc"
  fi
  if ! grep -q "source ~/.bash_aliases" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" <<'ZSHRC'

# Load shared aliases from bash
source ~/.bash_aliases
ZSHRC
    echo "Appended sourcing of aliases to ~/.zshrc"
  else
    echo "~/.zshrc already sources ~/.bash_aliases"
  fi
fi

echo "post-create script done"
