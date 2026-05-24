#!/bin/bash
# setup_terminal.sh - Complete Zsh Automation with Permissions and GUI Font Fixes

# -----------------------------------------------------------------------------
# GUARD 1: Prevent running with sudo / root
# -----------------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
  echo "ERROR: Please DO NOT run this script with sudo or as root!"
  echo "Run it as your normal user like this: bash setup_terminal.sh"
  echo "The script will automatically prompt you for your password only when installing apps."
  exit 1
fi

# Determine where the script is currently located
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# GUARD 4: Prevent Circular Symlinks (If run directly from the Home Directory)
# -----------------------------------------------------------------------------
if [ "$CURRENT_DIR" = "$HOME" ]; then
  echo "NOTICE: You ran this script directly from your Home directory (~)."
  echo "To prevent circular shortcut loops, we are automatically creating"
  echo "a dedicated folder at ~/dotfiles for your configuration storage."
  
  mkdir -p "$HOME/dotfiles"
  REPO_DIR="$HOME/dotfiles"
  
  if [ -f "$HOME/setup_terminal.sh" ]; then
    cp "$HOME/setup_terminal.sh" "$HOME/dotfiles/setup_terminal.sh"
  fi
else
  REPO_DIR="$CURRENT_DIR"
fi

echo "Storage directory verified at: $REPO_DIR"

# -----------------------------------------------------------------------------
# GUARD 2: Auto-create standalone config files if they don't exist in repo
# -----------------------------------------------------------------------------
if [ ! -f "$REPO_DIR/.zshrc" ]; then
  echo "Master .zshrc not found in storage folder. Creating it automatically..."
  cat << 'EOF' > "$REPO_DIR/.zshrc"
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  debian
  sudo
  dirhistory
  copypath
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

source $ZSH/oh-my-zsh.sh

# Key bindings for history substring search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# FZF config (Debian/Ubuntu paths)
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# Zoxide init
eval "$(zoxide init zsh)"

# Aliases
alias bat='batcat'
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first --long'
alias la='eza --icons --group-directories-first --long --all'
alias lt='eza --icons --tree --level=2'
alias upgrade='sudo apt update && sudo apt upgrade -y'
alias c='clear'
alias h='history'
alias ports='ss -tulnp'
alias apti='sudo apt install'
alias aptu='sudo apt update'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
fi

if [ ! -f "$REPO_DIR/.p10k.zsh" ]; then
  if [ -f "$HOME/.p10k.zsh" ] && [ "$CURRENT_DIR" != "$HOME" ]; then
    echo "Found your existing .p10k.zsh configuration! Pulling it into storage..."
    cp "$HOME/.p10k.zsh" "$REPO_DIR/.p10k.zsh"
  else
    echo "No .p10k.zsh configuration template found. Generating an empty file..."
    touch "$REPO_DIR/.p10k.zsh"
  fi
fi

# -----------------------------------------------------------------------------
# App Installation & Configurations
# -----------------------------------------------------------------------------
echo "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y zsh git curl fzf zoxide bat eza tealdeer htop

echo "Changing default shell to Zsh for $USER..."
sudo chsh -s $(which zsh) $USER

echo "Installing Oh My Zsh (unattended)..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

echo "Cloning Powerlevel10k and Plugins..."
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ] && git clone https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

# -----------------------------------------------------------------------------
# Font Installation with Universal Permissions Fix
# -----------------------------------------------------------------------------
echo "Installing Powerlevel10k fonts (MesloLGS NF) system-wide..."
FONT_DIR="/usr/share/fonts/truetype/meslo"
sudo mkdir -p "$FONT_DIR"

URL_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Regular.ttf" "$URL_BASE/MesloLGS%20NF%20Regular.ttf"
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Bold.ttf" "$URL_BASE/MesloLGS%20NF%20Bold.ttf"
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Italic.ttf" "$URL_BASE/MesloLGS%20NF%20Italic.ttf"
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Bold Italic.ttf" "$URL_BASE/MesloLGS%20NF%20Bold%20Italic.ttf"

echo "Applying readable permissions to font files..."
sudo chmod 755 "$FONT_DIR"
sudo chmod 644 "$FONT_DIR"/*.ttf

echo "Forcing system font cache rebuild..."
sudo fc-cache -fv

# -----------------------------------------------------------------------------
# Kali Xfce Terminal GUI Configuration Bypass
# -----------------------------------------------------------------------------
echo "Injecting MesloLGS NF font directly into Xfce Terminal configuration..."
mkdir -p "$HOME/.config/xfce4/terminal/"
sed -i '/^FontName=/d' "$HOME/.config/xfce4/terminal/terminalrc" 2>/dev/null
echo "FontName=MesloLGS NF 11" >> "$HOME/.config/xfce4/terminal/terminalrc"

# -----------------------------------------------------------------------------
# GUARD 3: Safe Symlinking (Force-clearing out old files/broken circular links)
# -----------------------------------------------------------------------------
echo "Linking configurations to your home directory..."
rm -rf "$HOME/.zshrc"
rm -rf "$HOME/.p10k.zsh"

ln -s "$REPO_DIR/.zshrc" "$HOME/.zshrc"
ln -s "$REPO_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

echo "Updating Tealdeer (tldr) cache..."
mkdir -p "$HOME/.cache/tealdeer"
tldr --update

echo "Setup complete! Please completely close all terminal windows and open a new one to see the changes."
