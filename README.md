# devbox

A portable Kubernetes development environment and jumpbox bootstrap toolkit. Spin up a fully equipped dev container on your local machine, or quickly set up any client jumpbox with the tools you need.

---

## Overview

This repo provides two things:

- **`bootstrap.sh`** — sets up your local machine (macOS or Linux) with Docker, DevPod, and a full dev container pre-loaded with Kubernetes tooling
- **`jb.sh`** — a lightweight, no-sudo installer for client jumpboxes where you just need the CLI tools and nothing else

---

## Local Machine Setup (bootstrap.sh)

### Prerequisites
- macOS or Ubuntu/Debian/Fedora/Arch Linux
- Internet access
- On macOS: Docker Desktop must be opened and accepted once after install

### What it installs
| Tool | Purpose |
|------|---------|
| `git`, `curl`, `zsh` | Base tools |
| `docker` | Container runtime |
| `chezmoi` | Dotfiles manager |
| `devpod` | Dev container manager |

### Usage

```bash
curl -fsSL https://raw.githubusercontent.com/bvp47/devbox/main/bootstrap.sh | bash
```

After it completes, make sure Docker Desktop is running, then connect to your devbox:

```bash
devpod ssh devbox
# or open in VS Code:
devpod up devbox --ide vscode
```

---

## Dev Container (devbox)

The devbox is a Docker container defined in `.devcontainer/` that runs Ubuntu 22.04 and comes pre-installed with everything you need for Kubernetes work.

### Tools inside the container
| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes CLI |
| `helm` | Kubernetes package manager |
| `k9s` | Terminal UI for cluster management |
| `python3` + pip + venv | Python runtime |
| `go` | Go runtime |
| `node` + npm | Node.js runtime |
| `git`, `zsh`, `neovim`, `tmux`, `jq` | Shell & utilities |

### VS Code extensions (auto-installed)
- Python
- Go
- Kubernetes Tools
- Docker

### Kubeconfig

Your local `~/.kube` directory is mounted into the container at `/root/.kube`, so any cluster contexts you have on your local machine are automatically available inside the devbox.

### Dotfiles

On first creation the container runs `chezmoi` to apply your dotfiles from `https://github.com/bvp47/dotfiles.git`.

---

## Client Jumpbox Setup (jumpbox.sh)

For client environments where you SSH into a jumpbox and need tooling fast — no Docker, no sudo required for most tools.

### What it installs
| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes CLI |
| `k9s` | Terminal UI for cluster management |
| Cloud CLI (your choice) | `az`, `aws`, or `gcloud` |
| `python3` | If not already present (needs sudo) |
| `tmux` | If not already present (needs sudo) |
| `chezmoi` + dotfiles | Your personal shell config |

All binaries install to `~/.local/bin` — no sudo needed except for `python3` and `tmux` if they're missing.

### Usage

```bash
curl -fsSL https://raw.githubusercontent.com/bvp47/devbox/main/jumpbox.sh -o jumpbox.sh && bash jumpbox.sh
```

> Note: must be downloaded first (not piped) because the script has an interactive menu.

At startup you'll be prompted to choose your cloud provider:

```
┌─────────────────────────────────────────┐
│         jumpbox setup - cloud CLI        │
├─────────────────────────────────────────┤
│  1) Azure (az)                           │
│  2) AWS (aws)                            │
│  3) Google Cloud (gcloud)                │
│  4) All of the above                     │
│  5) None / Skip cloud CLIs               │
└─────────────────────────────────────────┘
```

### After install

```bash
source ~/.bashrc   # reload PATH
```

Then authenticate to your client's cloud:

```bash
# Azure
az login
az aks get-credentials --resource-group <rg> --name <cluster>

# AWS
aws configure        # or: aws sso login
aws eks update-kubeconfig --region <region> --name <cluster>

# GCP
gcloud auth login
gcloud container clusters get-credentials <cluster> --region <region>
```

Then verify cluster access:

```bash
kubectl get nodes
k9s
```

---

## Repo Structure

```
devbox/
├── bootstrap.sh              # Local machine setup
├── jb.sh                # Client jumpbox setup
└── .devcontainer/
    ├── devcontainer.json     # Dev container config + kubeconfig mount
    ├── Dockerfile            # Ubuntu 22.04 image with all tools
    └── setup.sh              # Post-create dotfiles apply
```

---

## Workflows

### Local Development
```
bootstrap.sh → Docker + DevPod → devpod ssh devbox → kubectl / helm / k9s
```

### Client Jumpbox
```
ssh -A user@jumpbox → jb.sh → az/aws/gcloud login → kubectl get nodes
```

> Use `ssh -A` to forward your local SSH key to the jumpbox for private repo access without storing keys on the client machine.
