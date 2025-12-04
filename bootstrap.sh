#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/bvp47/dotfiles.git"
DEVBOX_REPO="https://github.com/bvp47/devbox.git"

USER_NAME="${USER:-$(id -un)}"

echo "==> Detecting OS..."

OS="$(uname -s)"

install_base_macos() {
  echo "==> Detected macOS"

  # Homebrew
  if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for this session (Apple Silicon default)
    if [ -d /opt/homebrew/bin ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    # Make sure brew is in PATH
    if [ -d /opt/homebrew/bin ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi

  echo "==> Installing base tools with Homebrew..."
  brew update

  # CLI tools
  brew install \
    git \
    zsh \
    curl \
    chezmoi \
    devpod

  # Docker (GUI app) – requires you to log in / start it yourself
  if ! command -v docker >/dev/null 2>&1; then
    echo "==> Installing Docker Desktop (you'll still need to open it once and accept the EULA)..."
    brew install --cask docker
  fi

  echo "==> macOS base tools installed."
  echo "==> Make sure Docker Desktop is running before using DevPod."
}

install_base_linux() {
  echo "==> Detected Linux"

  if [ ! -f /etc/os-release ]; then
    echo "Cannot detect distro (missing /etc/os-release)."
    exit 1
  fi

  . /etc/os-release

  echo "==> Distro ID: $ID"

  case "$ID" in
    ubuntu|debian)
      sudo apt-get update
      sudo apt-get install -y curl git zsh docker.io
      ;;
    arch|archlinux)
      sudo pacman -Sy --noconfirm curl git zsh docker
      ;;
    fedora)
      sudo dnf install -y curl git zsh docker
      ;;
    *)
      echo "==> Unknown distro '$ID', trying generic Docker install script..."
      sudo apt-get update || true
      curl -fsSL https://get.docker.com | sh
      sudo apt-get install -y curl git zsh || true
      ;;
  esac

  echo "==> Enabling & starting docker service..."
  sudo systemctl enable --now docker || true

  echo "==> Adding $USER_NAME to docker group (you may need to log out/in)..."
  sudo usermod -aG docker "$USER_NAME" || true
}

echo "==> Installing base packages (curl, git, zsh, docker, chezmoi, devpod)..."

case "$OS" in
  Darwin)
    install_base_macos
    ;;
  Linux)
    install_base_linux
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

echo "==> Ensuring chezmoi is available..."

if ! command -v chezmoi >/dev/null 2>&1; then
  # Fallback installer for weird cases
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Initializing chezmoi with $DOTFILES_REPO..."
chezmoi init "$DOTFILES_REPO" || true
chezmoi apply || true

echo "==> Ensuring DevPod CLI is available..."

if ! command -v devpod >/dev/null 2>&1; then
  # macOS should have devpod from brew; Linux fallback:
  curl -fsSL https://get.devpod.sh | sh
  sudo mv devpod /usr/local/bin/devpod
fi

echo "==> Configuring DevPod docker provider..."
devpod provider add docker || true
devpod provider use docker

echo "==> Bringing up DevPod workspace from $DEVBOX_REPO ..."
devpod up "$DEVBOX_REPO"

cat <<EOF

==> All done!

On macOS:
  - Make sure Docker Desktop is running.
  - DevPod will have created a workspace called 'devbox'.
  - You can attach with:  devpod ssh devbox
  - Or open VS Code:     devpod ide vscode devbox

EOF
