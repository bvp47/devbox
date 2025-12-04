#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/bvp47/dotfiles.git"

echo "==> [container] installing chezmoi and applying dotfiles..."

if ! command -v chezmoi >/dev/null 2>&1; then
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

export PATH="/usr/local/bin:$PATH"

chezmoi init "$DOTFILES_REPO" || true
chezmoi apply || true

echo "==> [container] dotfiles applied."
