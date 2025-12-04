#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${USER:-$(id -un)}"
DOTFILES_REPO="https://github.com/bvp47/dotfiles.git"
DEVBOX_REPO="https://github.com/bvp47/devbox.git"

echo "==> Detecting distro and installing base packages (curl, git, zsh, docker)..."

if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      sudo apt-get update
      sudo apt-get install -y curl git zsh ca-certificates
      sudo apt-get install -y docker.io
      ;;
    arch)
      sudo pacman -Sy --noconfirm curl git zsh docker
      ;;
    fedora)
      sudo dnf install -y curl git zsh docker
      ;;
    *)
      echo "Unknown distro '$ID', trying generic Docker install..."
      curl -fsSL https://get.docker.com | sh
      ;;
  esac
else
  echo "Cannot detect distro (missing /etc/os-release)."
  exit 1
fi

echo "==> Enabling Docker..."
sudo systemctl enable --now docker || true
sudo usermod -aG docker "$USER_NAME" || true

echo "==> Installing chezmoi..."
# Install chezmoi into ~/.local/bin
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

export PATH="$HOME/.local/bin:$PATH"

echo "==> Initializing dotfiles from $DOTFILES_REPO..."
chezmoi init "$DOTFILES_REPO" || true
chezmoi apply

echo "==> Installing DevPod CLI..."
curl -fsSL https://get.devpod.sh | sh
sudo mv devpod /usr/local/bin/devpod

echo "==> Configuring DevPod docker provider..."
devpod provider add docker || true
devpod provider use docker

echo "==> Creating DevPod workspace from $DEVBOX_REPO..."
devpod up "$DEVBOX_REPO"

echo "==> DONE."
echo "You may need to log out & log back in so your 'docker' group membership is active."
echo "After that, you can run:  devpod ssh <workspace-name>"
