#!/usr/bin/env bash
set -euo pipefail

# ── dirs ────────────────────────────────────────────────────────────────────
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$BIN:$PATH"

# Add to shell rc if not already there
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$RC" ] && ! grep -q '\.local/bin' "$RC"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
  fi
done

ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

echo "==> Detected: $OS / $ARCH"

# ── helpers ─────────────────────────────────────────────────────────────────
already_installed() { command -v "$1" >/dev/null 2>&1 && echo "==> $1 already installed, skipping." && return 0 || return 1; }

# ── kubectl ─────────────────────────────────────────────────────────────────
if ! already_installed kubectl; then
  echo "==> Installing kubectl..."
  KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLo "$BIN/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/amd64/kubectl"
  chmod +x "$BIN/kubectl"
  echo "==> kubectl $KUBECTL_VERSION installed."
fi

# ── k9s ─────────────────────────────────────────────────────────────────────
if ! already_installed k9s; then
  echo "==> Installing k9s..."
  K9S_VERSION="$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name"' | cut -d'"' -f4)"
  curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
    | tar xz -C "$BIN" k9s
  echo "==> k9s $K9S_VERSION installed."
fi

# ── Azure CLI ────────────────────────────────────────────────────────────────
if ! already_installed az; then
  echo "==> Installing Azure CLI..."
  # Installs to ~/.azure-cli virtualenv, no sudo needed
  curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash 2>/dev/null || {
    # Fallback: pip install into user space
    python3 -m pip install --user azure-cli
  }
  # If installed via pip user, the binary lands in ~/.local/bin already
  echo "==> Azure CLI installed."
fi

# ── AWS CLI ──────────────────────────────────────────────────────────────────
if ! already_installed aws; then
  echo "==> Installing AWS CLI v2..."
  TMPDIR="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMPDIR/awscliv2.zip"
  cd "$TMPDIR"
  unzip -q awscliv2.zip
  # Install to ~/.local so no sudo needed
  ./aws/install --install-dir "$HOME/.local/aws-cli" --bin-dir "$BIN"
  cd -
  rm -rf "$TMPDIR"
  echo "==> AWS CLI installed."
fi

# ── gcloud ───────────────────────────────────────────────────────────────────
if ! already_installed gcloud; then
  echo "==> Installing gcloud CLI..."
  curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
  # gcloud installs to ~/google-cloud-sdk/bin
  export PATH="$HOME/google-cloud-sdk/bin:$PATH"
  for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ] && ! grep -q 'google-cloud-sdk' "$RC"; then
      echo 'export PATH="$HOME/google-cloud-sdk/bin:$PATH"' >> "$RC"
    fi
  done
  echo "==> gcloud installed."
fi

# ── tmux ─────────────────────────────────────────────────────────────────────
if ! already_installed tmux; then
  echo "==> tmux not found. Attempting install (may need sudo)..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y tmux 2>/dev/null || echo "==> Could not install tmux (no sudo). Skip."
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y tmux 2>/dev/null || echo "==> Could not install tmux (no sudo). Skip."
  else
    echo "==> No supported package manager found for tmux. Skip."
  fi
fi

# ── python3 ──────────────────────────────────────────────────────────────────
if ! already_installed python3; then
  echo "==> python3 not found. Attempting install (may need sudo)..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y python3 python3-pip python3-venv 2>/dev/null || echo "==> Could not install python3 (no sudo). Skip."
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y python3 2>/dev/null || echo "==> Could not install python3 (no sudo). Skip."
  else
    echo "==> No supported package manager found for python3. Skip."
  fi
else
  echo "==> python3 already installed, skipping."
fi

# ── chezmoi + dotfiles ───────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/bvp47/dotfiles.git"

if ! already_installed chezmoi; then
  echo "==> Installing chezmoi..."
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$BIN"
fi

echo "==> Applying dotfiles from $DOTFILES_REPO..."
chezmoi init "$DOTFILES_REPO" || true
chezmoi apply || true

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "==> All done! Tools installed to $BIN"
echo ""
echo "    kubectl  : $(kubectl version --client --short 2>/dev/null || echo 'installed')"
echo "    k9s      : $(k9s version --short 2>/dev/null || echo 'installed')"
echo "    az       : $(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo 'installed')"
echo "    aws      : $(aws --version 2>&1 || echo 'installed')"
echo "    gcloud   : $(gcloud version 2>/dev/null | head -1 || echo 'installed')"
echo "    python3  : $(python3 --version 2>/dev/null || echo 'installed')"
echo "    tmux     : $(tmux -V 2>/dev/null || echo 'installed')"
echo ""
echo "==> Run: source ~/.bashrc  (or ~/.zshrc) to reload PATH"
echo "==> Then authenticate with:"
echo "      az login"
echo "      aws configure  (or aws sso login)"
echo "      gcloud auth login"
