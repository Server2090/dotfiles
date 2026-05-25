#!/bin/bash
# =============================================================================
# setup_terminal.sh
# Zsh + Oh My Zsh + Powerlevel10k terminal setup
# Auto-detects desktop environment and configures the right terminal
# Compatible with: KDE, GNOME, XFCE, MATE, Cinnamon, LXQt, and more
# Works on: Parrot OS, Debian, Ubuntu, Kali, and any Debian-based distro
# =============================================================================
# Run as your NORMAL user (not root/sudo):
#   bash setup_terminal.sh
# =============================================================================

# --- GUARD: Do not run as root ---
# This script manages user config files in your home directory.
# Running as root would put everything in /root instead of your actual home.
if [ "$EUID" -eq 0 ]; then
  echo "ERROR: Do NOT run this script with sudo or as root."
  echo "Run it as your normal user: bash setup_terminal.sh"
  echo "It will ask for your password automatically when needed."
  exit 1
fi

# =============================================================================
# COLORS — for readable terminal output
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}"; }

# =============================================================================
# STEP 1 — FIGURE OUT WHERE TO STORE CONFIG FILES
# =============================================================================
# BASH_SOURCE[0] is the path of this script file
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If the script is run directly from the home directory, use ~/dotfiles instead.
# This prevents circular symlinks (~/dotfiles/.zshrc -> ~/.zshrc -> ~/dotfiles/.zshrc)
if [ "$CURRENT_DIR" = "$HOME" ]; then
  warn "Script run from home directory. Using ~/dotfiles to avoid circular symlinks."
  mkdir -p "$HOME/dotfiles"
  REPO_DIR="$HOME/dotfiles"
  [ -f "$HOME/setup_terminal.sh" ] && cp "$HOME/setup_terminal.sh" "$HOME/dotfiles/setup_terminal.sh"
else
  REPO_DIR="$CURRENT_DIR"
fi

success "Config storage directory: $REPO_DIR"

# =============================================================================
# STEP 2 — DETECT DESKTOP ENVIRONMENT
# =============================================================================
# $XDG_CURRENT_DESKTOP is a standard environment variable set by the display
# manager when you log in. It reliably identifies which DE is running.
# We convert it to lowercase for easier matching (KDE, kde, Kde all become kde)
header "Detecting Desktop Environment"

# ${VAR,,} converts a variable to lowercase in bash
DETECTED_DE="${XDG_CURRENT_DESKTOP,,}"

# Also check $DESKTOP_SESSION as a fallback — some DEs set this instead
DESKTOP_SESSION_LOWER="${DESKTOP_SESSION,,}"

# Determine which DE we're on by checking for known keywords
if echo "$DETECTED_DE" in *kde* || echo "$DESKTOP_SESSION_LOWER" | grep -qi "kde\|plasma"; then
  DE="kde"
elif echo "$DETECTED_DE" | grep -qi "gnome"; then
  DE="gnome"
elif echo "$DETECTED_DE" | grep -qi "xfce"; then
  DE="xfce"
elif echo "$DETECTED_DE" | grep -qi "mate"; then
  DE="mate"
elif echo "$DETECTED_DE" | grep -qi "cinnamon\|x-cinnamon"; then
  DE="cinnamon"
elif echo "$DETECTED_DE" | grep -qi "lxqt"; then
  DE="lxqt"
elif echo "$DETECTED_DE" | grep -qi "lxde"; then
  DE="lxde"
else
  # Can't detect — fall back to checking which terminal apps are installed
  warn "Could not detect desktop environment from environment variables."
  warn "Falling back to checking installed terminal apps..."
  if command -v konsole &>/dev/null; then
    DE="kde"
  elif command -v xfce4-terminal &>/dev/null; then
    DE="xfce"
  elif command -v gnome-terminal &>/dev/null; then
    DE="gnome"
  elif command -v mate-terminal &>/dev/null; then
    DE="mate"
  else
    DE="unknown"
    warn "Could not detect terminal. Font will be installed system-wide but not auto-configured."
    warn "After setup, manually set your terminal font to: MesloLGS NF 11"
  fi
fi

success "Detected desktop environment: $DE"

# Also detect which package manager / distro we're on
# This affects package names (e.g. bat vs batcat on Debian)
if command -v apt-get &>/dev/null; then
  PKG_MANAGER="apt"
  # Check if bat is available as 'bat' or 'batcat' (Debian names it batcat)
  if apt-cache show bat &>/dev/null 2>&1; then
    BAT_PKG="bat"
    BAT_CMD="bat"
  else
    BAT_PKG="batcat"
    BAT_CMD="batcat"
  fi
elif command -v pacman &>/dev/null; then
  PKG_MANAGER="pacman"
  BAT_PKG="bat"
  BAT_CMD="bat"
elif command -v dnf &>/dev/null; then
  PKG_MANAGER="dnf"
  BAT_PKG="bat"
  BAT_CMD="bat"
else
  PKG_MANAGER="unknown"
  BAT_PKG="batcat"
  BAT_CMD="batcat"
fi

success "Package manager: $PKG_MANAGER | bat command: $BAT_CMD"

# =============================================================================
# STEP 3 — CREATE .zshrc IF IT DOESN'T EXIST IN THE REPO
# =============================================================================
# We check the REPO_DIR (dotfiles folder), not the home directory directly.
# The home directory version will be a symlink to this one.
header "Setting Up Config Files"

if [ ! -f "$REPO_DIR/.zshrc" ]; then
  info "Creating .zshrc in $REPO_DIR..."

  # This is a heredoc — everything between EOF markers is written to the file
  # The bat alias is set dynamically based on what we detected above
  cat << EOF > "$REPO_DIR/.zshrc"
# Enable Powerlevel10k instant prompt.
# This makes the prompt appear almost instantly while zsh loads in the background.
# Must stay near the top of .zshrc.
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

# Path to Oh My Zsh installation
export ZSH="\$HOME/.oh-my-zsh"

# Use Powerlevel10k as the prompt theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins to load:
# git                       = git status and shortcuts in prompt
# debian                    = apt shortcuts (on Debian-based systems)
# sudo                      = press Escape twice to add sudo to last command
# dirhistory                = Alt+Left/Right to navigate directory history
# copypath                  = copy current path to clipboard
# zsh-autosuggestions       = grey suggestions based on command history
# zsh-syntax-highlighting   = colors valid commands green, invalid red
# zsh-history-substring-search = search history with Up/Down arrows
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

source \$ZSH/oh-my-zsh.sh

# History substring search key bindings
# These make Up/Down arrow keys search history for commands starting with
# whatever you've already typed
bindkey '^\[\[A' history-substring-search-up
bindkey '^\[\[B' history-substring-search-down

# FZF — fuzzy finder key bindings and tab completion
# Ctrl+R for fuzzy history search, Ctrl+T for fuzzy file search
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ]   && source /usr/share/doc/fzf/examples/completion.zsh

# Zoxide — a smarter cd that learns your most-used directories
# Type 'z dirname' instead of 'cd /long/path/to/dirname'
eval "\$(zoxide init zsh)"

# =============================================================================
# ALIASES — shortcuts for common commands
# =============================================================================
alias bat='${BAT_CMD}'           # bat/batcat — syntax-highlighted cat replacement
alias ls='eza --icons --group-directories-first'          # better ls with icons
alias ll='eza --icons --group-directories-first --long'   # ls with details
alias la='eza --icons --group-directories-first --long --all'  # include hidden files
alias lt='eza --icons --tree --level=2'                   # show directory tree
alias upgrade='sudo apt update && sudo apt upgrade -y'    # update everything
alias c='clear'
alias h='history'
alias ports='ss -tulnp'          # show all open ports and listening services
alias apti='sudo apt install'    # quick install shortcut
alias aptu='sudo apt update'     # quick update shortcut

# Load Powerlevel10k config (run 'p10k configure' to customize your prompt)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
  success ".zshrc created"
else
  info ".zshrc already exists in $REPO_DIR — skipping creation"
fi

# Handle p10k config — either copy existing one or create empty placeholder
if [ ! -f "$REPO_DIR/.p10k.zsh" ]; then
  if [ -f "$HOME/.p10k.zsh" ] && [ "$CURRENT_DIR" != "$HOME" ]; then
    info "Found existing .p10k.zsh — copying to dotfiles..."
    cp "$HOME/.p10k.zsh" "$REPO_DIR/.p10k.zsh"
  else
    info "No .p10k.zsh found — creating empty placeholder..."
    touch "$REPO_DIR/.p10k.zsh"
  fi
fi

# =============================================================================
# STEP 4 — INSTALL PACKAGES
# =============================================================================
header "Installing Packages"

info "Updating package list..."
sudo apt update

# Core packages — these are available on all Debian-based distros
CORE_PACKAGES="zsh git curl fzf zoxide tealdeer htop"
info "Installing core packages: $CORE_PACKAGES"
sudo apt install -y $CORE_PACKAGES

# Install bat (syntax-highlighted cat)
# On Debian/Parrot it's called batcat, elsewhere it's bat
info "Installing bat ($BAT_PKG)..."
sudo apt install -y "$BAT_PKG" || warn "bat not available — skipping"

# Install eza (modern ls replacement)
# eza is newer and not always in repos — we try it and fall back gracefully
info "Installing eza (modern ls replacement)..."
if sudo apt install -y eza 2>/dev/null; then
  success "eza installed"
else
  warn "eza not in repos — trying exa as fallback..."
  if sudo apt install -y exa 2>/dev/null; then
    success "exa installed (eza fallback)"
    # Update aliases in .zshrc to use exa instead of eza
    sed -i 's/eza /exa /g' "$REPO_DIR/.zshrc"
    info "Updated .zshrc aliases to use exa"
  else
    warn "Neither eza nor exa available."
    warn "ls/ll/la/lt aliases will fall back to plain ls."
    # Replace eza aliases with plain ls equivalents
    sed -i "s|alias ls='eza.*'|alias ls='ls --color=auto'|g" "$REPO_DIR/.zshrc"
    sed -i "s|alias ll='eza.*'|alias ll='ls -la --color=auto'|g" "$REPO_DIR/.zshrc"
    sed -i "s|alias la='eza.*'|alias la='ls -la --color=auto'|g" "$REPO_DIR/.zshrc"
    sed -i "s|alias lt='eza.*'|alias lt='ls -R'|g" "$REPO_DIR/.zshrc"
  fi
fi

# =============================================================================
# STEP 5 — CHANGE DEFAULT SHELL TO ZSH
# =============================================================================
header "Setting Zsh as Default Shell"

# which zsh finds the full path to zsh (usually /usr/bin/zsh)
# chsh -s changes the login shell for the current user
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [ "$CURRENT_SHELL" != "$(which zsh)" ]; then
  sudo chsh -s "$(which zsh)" "$USER"
  success "Default shell changed to zsh"
else
  info "Zsh is already the default shell"
fi

# =============================================================================
# STEP 6 — INSTALL OH MY ZSH
# =============================================================================
header "Installing Oh My Zsh"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  info "Downloading and installing Oh My Zsh..."
  # RUNZSH=no  — don't launch zsh immediately after install (would pause script)
  # CHSH=no    — don't try to change shell (we already did that above)
  # KEEP_ZSHRC=yes — don't overwrite our custom .zshrc with the default one
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed"
else
  info "Oh My Zsh already installed — skipping"
fi

# =============================================================================
# STEP 7 — INSTALL POWERLEVEL10K AND PLUGINS
# =============================================================================
header "Installing Powerlevel10k Theme and Plugins"

# Oh My Zsh plugins and themes go in this custom directory
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# --depth=1 clones only the latest commit — much faster, saves disk space
# The [ ! -d ] check means "only clone if it doesn't already exist"

info "Installing Powerlevel10k theme..."
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k" && success "Powerlevel10k installed"

info "Installing zsh-autosuggestions..."
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
  git clone https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" && success "zsh-autosuggestions installed"

info "Installing zsh-syntax-highlighting..."
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" && success "zsh-syntax-highlighting installed"

info "Installing zsh-history-substring-search..."
[ ! -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ] && \
  git clone https://github.com/zsh-users/zsh-history-substring-search \
  "$ZSH_CUSTOM/plugins/zsh-history-substring-search" && success "zsh-history-substring-search installed"

# =============================================================================
# STEP 8 — INSTALL MESLO FONTS SYSTEM-WIDE
# =============================================================================
# MesloLGS NF is a patched Nerd Font that includes all the icons
# Powerlevel10k uses. Without it you get garbled symbols in the prompt.
header "Installing MesloLGS NF Fonts"

FONT_DIR="/usr/share/fonts/truetype/meslo"
sudo mkdir -p "$FONT_DIR"

URL_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"

info "Downloading MesloLGS NF font files..."
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Regular.ttf"     "$URL_BASE/MesloLGS%20NF%20Regular.ttf"
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Bold.ttf"        "$URL_BASE/MesloLGS%20NF%20Bold.ttf"
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Italic.ttf"      "$URL_BASE/MesloLGS%20NF%20Italic.ttf"
sudo curl -sSLo "$FONT_DIR/MesloLGS NF Bold Italic.ttf" "$URL_BASE/MesloLGS%20NF%20Bold%20Italic.ttf"

# chmod 755 on the directory = everyone can read and enter it
# chmod 644 on the files = everyone can read, only root can write
sudo chmod 755 "$FONT_DIR"
sudo chmod 644 "$FONT_DIR"/*.ttf

# fc-cache rebuilds the system font cache so apps can find the new fonts
# -f = force rebuild even if cache seems current
# -v = verbose, shows what it's doing
info "Rebuilding font cache..."
sudo fc-cache -fv
success "Fonts installed and cache rebuilt"

# =============================================================================
# STEP 9 — CONFIGURE TERMINAL FONT (AUTO-DETECTED PER DESKTOP ENVIRONMENT)
# =============================================================================
header "Configuring Terminal Font for: $DE"

configure_kde() {
  # Konsole stores profiles in ~/.local/share/konsole/
  # Each profile is a .profile file with INI-style key=value settings
  # The font format is: FontName,size,-1,5,weight,italic,underline,strikeout,fixedpitch,0
  # Most of those numbers are Qt font rendering flags — leave them as-is
  info "Configuring Konsole (KDE)..."

  KONSOLE_DIR="$HOME/.local/share/konsole"
  mkdir -p "$KONSOLE_DIR"

  # Find existing default profile or create one
  # Konsole names its default profile differently on different systems
  KONSOLE_PROFILE=""
  for f in "$KONSOLE_DIR"/*.profile; do
    if [ -f "$f" ]; then
      KONSOLE_PROFILE="$f"
      break
    fi
  done

  if [ -z "$KONSOLE_PROFILE" ]; then
    # No profile exists — create one from scratch
    KONSOLE_PROFILE="$KONSOLE_DIR/Default.profile"
    info "Creating new Konsole profile: $KONSOLE_PROFILE"
    cat > "$KONSOLE_PROFILE" << 'EOF'
[Appearance]
Font=MesloLGS NF,11,-1,5,400,0,0,0,0,0
ColorScheme=Linux

[General]
Name=Default
Parent=FALLBACK/
Command=/usr/bin/zsh
EOF
  else
    info "Updating existing Konsole profile: $KONSOLE_PROFILE"
    # Remove any existing Font line and add the new one
    sed -i '/^Font=/d' "$KONSOLE_PROFILE"
    # Remove any existing Command line and add zsh
    sed -i '/^Command=/d' "$KONSOLE_PROFILE"
    # Add [Appearance] section if it doesn't exist
    grep -q '^\[Appearance\]' "$KONSOLE_PROFILE" || echo -e "\n[Appearance]" >> "$KONSOLE_PROFILE"
    grep -q '^\[General\]'    "$KONSOLE_PROFILE" || echo -e "\n[General]"    >> "$KONSOLE_PROFILE"
    # Insert font after [Appearance] header
    sed -i '/^\[Appearance\]/a Font=MesloLGS NF,11,-1,5,400,0,0,0,0,0' "$KONSOLE_PROFILE"
    # Insert shell command after [General] header
    sed -i '/^\[General\]/a Command=/usr/bin/zsh' "$KONSOLE_PROFILE"
  fi

  # Also set this as the default profile in konsolerc
  KONSOLERC="$HOME/.config/konsolerc"
  if [ -f "$KONSOLERC" ]; then
    sed -i '/^DefaultProfile=/d' "$KONSOLERC"
  fi
  PROFILE_NAME=$(basename "$KONSOLE_PROFILE")
  mkdir -p "$HOME/.config"
  echo "[Desktop Entry]" >> "$KONSOLERC" 2>/dev/null || true
  echo "DefaultProfile=$PROFILE_NAME" >> "$KONSOLERC"

  success "Konsole configured with MesloLGS NF font and zsh shell"
  warn "You may need to go to Settings → Edit Current Profile and verify the font"
}

configure_xfce() {
  # XFCE terminal stores its config in a plain text file
  # FontName=FontName Size is all that's needed
  info "Configuring XFCE Terminal..."
  mkdir -p "$HOME/.config/xfce4/terminal"
  XFCE_CONFIG="$HOME/.config/xfce4/terminal/terminalrc"
  # Remove existing FontName line, then append the new one
  sed -i '/^FontName=/d' "$XFCE_CONFIG" 2>/dev/null || true
  echo "FontName=MesloLGS NF 11" >> "$XFCE_CONFIG"
  success "XFCE Terminal configured with MesloLGS NF font"
}

configure_gnome() {
  # GNOME Terminal uses dconf (a binary config database) for settings
  # gsettings is the command-line interface to dconf
  info "Configuring GNOME Terminal..."
  if command -v gsettings &>/dev/null; then
    # Get the UUID of the default profile
    DEFAULT_PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -n "$DEFAULT_PROFILE" ]; then
      PROFILE_PATH="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$DEFAULT_PROFILE/"
      gsettings set "$PROFILE_PATH" font "MesloLGS NF 11"
      gsettings set "$PROFILE_PATH" use-system-font false
      success "GNOME Terminal configured with MesloLGS NF font"
    else
      warn "Could not find GNOME Terminal default profile — set font manually"
    fi
  else
    warn "gsettings not found — set GNOME Terminal font manually to: MesloLGS NF 11"
  fi
}

configure_mate() {
  # MATE Terminal also uses dconf/gsettings, similar to GNOME Terminal
  info "Configuring MATE Terminal..."
  if command -v gsettings &>/dev/null; then
    DEFAULT_PROFILE=$(gsettings get org.mate.terminal.global default-profile 2>/dev/null | tr -d "'")
    if [ -n "$DEFAULT_PROFILE" ]; then
      PROFILE_PATH="org.mate.terminal.profile:/org/mate/terminal/profiles/$DEFAULT_PROFILE/"
      gsettings set "$PROFILE_PATH" font "MesloLGS NF 11"
      gsettings set "$PROFILE_PATH" use-system-font false
      success "MATE Terminal configured with MesloLGS NF font"
    else
      warn "Could not find MATE Terminal default profile — set font manually"
    fi
  else
    warn "gsettings not found — set MATE Terminal font manually to: MesloLGS NF 11"
  fi
}

configure_cinnamon() {
  # Cinnamon uses GNOME Terminal or its own terminal (nemo-terminal)
  # The settings schema is similar to GNOME's
  info "Configuring Cinnamon Terminal..."
  if command -v gsettings &>/dev/null; then
    DEFAULT_PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -n "$DEFAULT_PROFILE" ]; then
      PROFILE_PATH="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$DEFAULT_PROFILE/"
      gsettings set "$PROFILE_PATH" font "MesloLGS NF 11"
      gsettings set "$PROFILE_PATH" use-system-font false
      success "Cinnamon Terminal configured with MesloLGS NF font"
    else
      warn "Could not find terminal profile — set font manually to: MesloLGS NF 11"
    fi
  fi
}

configure_lxqt() {
  # LXQt uses qterminal, which stores config in a plain INI file
  info "Configuring QTerminal (LXQt)..."
  QTERMINAL_CONFIG="$HOME/.config/qterminal.org/qterminal.ini"
  mkdir -p "$(dirname "$QTERMINAL_CONFIG")"
  if [ -f "$QTERMINAL_CONFIG" ]; then
    sed -i '/^fontFamily=/d' "$QTERMINAL_CONFIG"
    sed -i '/^fontSize=/d'   "$QTERMINAL_CONFIG"
    sed -i '/^\[General\]/a fontFamily=MesloLGS NF\nfontSize=11' "$QTERMINAL_CONFIG"
  else
    cat > "$QTERMINAL_CONFIG" << 'EOF'
[General]
fontFamily=MesloLGS NF
fontSize=11
EOF
  fi
  success "QTerminal configured with MesloLGS NF font"
}

configure_unknown() {
  warn "Could not auto-configure terminal font."
  warn "Please manually set your terminal font to: MesloLGS NF 11"
  warn "The font has been installed system-wide and is available to all apps."
}

# Call the right configuration function based on detected DE
case "$DE" in
  kde)       configure_kde      ;;
  gnome)     configure_gnome    ;;
  xfce)      configure_xfce     ;;
  mate)      configure_mate     ;;
  cinnamon)  configure_cinnamon ;;
  lxqt|lxde) configure_lxqt   ;;
  *)         configure_unknown  ;;
esac

# =============================================================================
# STEP 10 — CREATE SYMLINKS FROM DOTFILES TO HOME DIRECTORY
# =============================================================================
# Symlinks (ln -s) are shortcuts. ~/.zshrc will point to ~/dotfiles/.zshrc
# This means editing either file edits the same content
# rm -rf first removes any existing file or broken symlink at that path
header "Linking Config Files to Home Directory"

info "Linking .zshrc..."
rm -rf "$HOME/.zshrc"
ln -s "$REPO_DIR/.zshrc" "$HOME/.zshrc"
success "~/.zshrc -> $REPO_DIR/.zshrc"

info "Linking .p10k.zsh..."
rm -rf "$HOME/.p10k.zsh"
ln -s "$REPO_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
success "~/.p10k.zsh -> $REPO_DIR/.p10k.zsh"

# =============================================================================
# STEP 11 — UPDATE TEALDEER CACHE
# =============================================================================
# tealdeer is a fast Rust implementation of tldr (simplified man pages)
# tldr --update downloads the latest cheat sheet database
header "Updating Tealdeer (tldr) Cache"

mkdir -p "$HOME/.cache/tealdeer"
tldr --update 2>/dev/null && success "Tealdeer cache updated" || warn "Tealdeer update failed — run 'tldr --update' manually"

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║         Setup Complete!                      ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Desktop environment: ${CYAN}$DE${NC}"
echo -e "  Config location:     ${CYAN}$REPO_DIR${NC}"
echo -e "  Font installed:      ${CYAN}MesloLGS NF${NC}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. Close ALL terminal windows completely"
echo -e "  2. Open a fresh terminal"
echo -e "  3. Run ${CYAN}p10k configure${NC} to set up your prompt style"
echo ""
if [ "$DE" = "kde" ]; then
  echo -e "  ${YELLOW}KDE note:${NC} If icons look wrong, open Konsole →"
  echo -e "  Settings → Edit Current Profile → Appearance"
  echo -e "  and confirm font is set to MesloLGS NF"
  echo ""
fi
