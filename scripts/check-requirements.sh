#!/usr/bin/env bash
#
# check-requirements.sh
# Validates that all required tools are installed with the minimum versions.
# If any are missing, it offers to install them.
#
# Optimized for Kali Linux (Debian-based) with KVM/libvirt.
#
# Usage: ./scripts/check-requirements.sh
#

set -o pipefail

# ─────────────────────────────────────────────────────────────
# Output colors
# ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─────────────────────────────────────────────────────────────
# OS detection
# ─────────────────────────────────────────────────────────────
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)

# ─────────────────────────────────────────────────────────────
# Print helpers
# ─────────────────────────────────────────────────────────────
print_header() {
  echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_ok()      { echo -e "  ${GREEN}✔${NC} $1"; }
print_missing() { echo -e "  ${RED}✘${NC} $1"; }
print_warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
print_info()    { echo -e "  ${CYAN}ℹ${NC} $1"; }

# ─────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────

# Compares two semantic versions. Returns 0 if $1 >= $2
version_gte() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Asks a yes/no question
ask_yes_no() {
  local prompt="$1"
  local reply
  read -r -p "$(echo -e "${YELLOW}${prompt} [y/N]: ${NC}")" reply
  [[ "$reply" =~ ^[yYsS]$ ]]
}

# Ensures sudo privileges
require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}sudo privileges are required to install packages.${NC}"
    sudo -v || { echo -e "${RED}Could not obtain sudo.${NC}"; exit 1; }
  fi
}

# Ensures pipx is installed (required for Ansible and LocalStack)
ensure_pipx() {
  if ! command -v pipx >/dev/null 2>&1; then
    print_info "Installing pipx (required for Python applications)..."
    require_sudo
    sudo apt-get update -qq
    sudo apt-get install -y pipx
    pipx ensurepath
  fi
}

# ─────────────────────────────────────────────────────────────
# Version getters
# ─────────────────────────────────────────────────────────────
get_git_version() {
  command -v git >/dev/null 2>&1 && git --version | awk '{print $3}'
}

get_python_version() {
  command -v python3 >/dev/null 2>&1 && python3 --version | awk '{print $2}'
}

get_jq_version() {
  command -v jq >/dev/null 2>&1 && jq --version | sed 's/^jq-//'
}

get_aws_version() {
  command -v aws >/dev/null 2>&1 && aws --version 2>&1 | awk '{print $1}' | cut -d'/' -f2
}

get_terraform_version() {
  command -v terraform >/dev/null 2>&1 && terraform --version | head -n1 | awk '{print $2}' | sed 's/^v//'
}

get_ansible_version() {
  command -v ansible >/dev/null 2>&1 && ansible --version | head -n1 | awk '{print $NF}' | tr -d ']'
}

get_docker_version() {
  command -v docker >/dev/null 2>&1 && docker --version | awk '{print $3}' | tr -d ','
}

get_vagrant_version() {
  command -v vagrant >/dev/null 2>&1 && vagrant --version | awk '{print $2}'
}

get_virsh_version() {
  command -v virsh >/dev/null 2>&1 && virsh --version
}

get_localstack_version() {
  command -v localstack >/dev/null 2>&1 && localstack --version 2>/dev/null | awk '{print $NF}'
}

# ─────────────────────────────────────────────────────────────
# Installers
# ─────────────────────────────────────────────────────────────

install_base_packages() {
  require_sudo
  sudo apt-get update -qq
  sudo apt-get install -y curl wget unzip git jq build-essential \
    python3 python3-pip python3-venv python3-full \
    gnupg software-properties-common lsb-release apt-transport-https ca-certificates \
    pipx
  pipx ensurepath
}

install_git() {
  require_sudo
  sudo apt-get update -qq && sudo apt-get install -y git
}

install_python() {
  require_sudo
  sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-venv python3-full
}

install_jq() {
  require_sudo
  sudo apt-get update -qq && sudo apt-get install -y jq
}

install_awscli() {
  require_sudo
  local tmpdir
  tmpdir=$(mktemp -d)
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmpdir/awscliv2.zip" \
    && unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir" \
    && sudo "$tmpdir/aws/install" --update
  rm -rf "$tmpdir"
}

install_terraform() {
  require_sudo
  sudo apt-get update -qq
  sudo apt-get install -y gnupg software-properties-common curl
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y terraform
}

# Ansible via pipx (PEP 668 compliant)
install_ansible() {
  ensure_pipx
  pipx install --include-deps ansible
  # Ansible needs these Python libs for AWS interaction; install inside its venv
  pipx inject ansible boto3 botocore
  # ansible-lint as a separate pipx app
  pipx install ansible-lint 2>/dev/null || pipx upgrade ansible-lint
}

install_docker() {
  require_sudo
  sudo apt-get update -qq
  sudo apt-get install -y docker.io docker-compose
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"
  print_warn "Log out and back in for the 'docker' group to take effect."
}

# Vagrant: try apt first, fall back to manual .deb download
install_vagrant() {
  require_sudo

  # Option 1: try the official HashiCorp apt repo
  sudo apt-get update -qq
  if sudo apt-get install -y vagrant 2>/dev/null; then
    return 0
  fi

  # Option 2: fall back to direct .deb download
  print_warn "Vagrant is not available in the configured apt repos."
  print_info "Falling back to direct .deb download from HashiCorp..."

  local version="2.4.1"
  local arch
  arch=$(dpkg --print-architecture)

  if [ "$arch" != "amd64" ]; then
    print_missing "Automatic install only supports amd64. Detected: $arch"
    print_info "Download manually from: https://developer.hashicorp.com/vagrant/downloads"
    return 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  local url="https://releases.hashicorp.com/vagrant/${version}/vagrant_${version}-1_amd64.deb"

  print_info "Downloading: $url"
  if curl -fsSL "$url" -o "$tmpdir/vagrant.deb"; then
    sudo dpkg -i "$tmpdir/vagrant.deb" || sudo apt-get install -f -y
    rm -rf "$tmpdir"
    return 0
  else
    rm -rf "$tmpdir"
    print_missing "Failed to download Vagrant .deb"
    print_info "Download manually from: https://developer.hashicorp.com/vagrant/downloads"
    return 1
  fi
}

install_libvirt() {
  require_sudo
  sudo apt-get update -qq
  sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
    bridge-utils virtinst libvirt-dev ruby-dev libxml2-dev libxslt-dev zlib1g-dev
  sudo systemctl enable --now libvirtd
  sudo usermod -aG libvirt,kvm "$USER"
  print_warn "Log out and back in for the 'libvirt' and 'kvm' groups to take effect."
}

# LocalStack via pipx
install_localstack() {
  ensure_pipx
  pipx install localstack
}

# ─────────────────────────────────────────────────────────────
# Requirements definition
# Format: name|min_version|version_fn|install_fn
# ─────────────────────────────────────────────────────────────
REQUIREMENTS=(
  "git|2.30|get_git_version|install_git"
  "python3|3.10|get_python_version|install_python"
  "jq|1.6|get_jq_version|install_jq"
  "aws|2.0|get_aws_version|install_awscli"
  "terraform|1.5|get_terraform_version|install_terraform"
  "ansible|2.15|get_ansible_version|install_ansible"
  "docker|20.10|get_docker_version|install_docker"
  "vagrant|2.3|get_vagrant_version|install_vagrant"
  "virsh|8.0|get_virsh_version|install_libvirt"
  "localstack|3.0|get_localstack_version|install_localstack"
)

# ─────────────────────────────────────────────────────────────
# Main logic
# ─────────────────────────────────────────────────────────────
main() {
  print_header "Project requirements check"
  print_info "Detected OS: ${BOLD}$OS${NC}"

  if [[ "$OS" != "kali" && "$OS" != "debian" && "$OS" != "ubuntu" ]]; then
    print_warn "This script is optimized for Kali/Debian/Ubuntu."
    print_info "Some automatic installations may not work."
  fi

  echo
  local missing_tools=()
  local outdated_tools=()

  # ── Phase 1: Diagnostics ───────────────────────────────────
  echo -e "${BOLD}Diagnostics:${NC}"
  for req in "${REQUIREMENTS[@]}"; do
    IFS='|' read -r name min_version version_fn install_fn <<< "$req"
    local current
    current=$($version_fn)

    if [ -z "$current" ]; then
      print_missing "$name ${RED}(not installed, >= $min_version required)${NC}"
      missing_tools+=("$req")
    elif version_gte "$current" "$min_version"; then
      print_ok "$name $current ${GREEN}(>= $min_version)${NC}"
    else
      print_warn "$name $current ${YELLOW}(outdated, >= $min_version required)${NC}"
      outdated_tools+=("$req")
    fi
  done

  # ── Phase 2: Everything OK? ────────────────────────────────
  if [ ${#missing_tools[@]} -eq 0 ] && [ ${#outdated_tools[@]} -eq 0 ]; then
    echo
    print_ok "${BOLD}All good! Every tool meets the requirements.${NC}"
    echo
    exit 0
  fi

  echo
  [ ${#missing_tools[@]} -gt 0 ] && print_warn "${#missing_tools[@]} missing tool(s)."
  [ ${#outdated_tools[@]} -gt 0 ] && print_warn "${#outdated_tools[@]} outdated tool(s)."

  echo
  if ! ask_yes_no "Install/update missing tools?"; then
    print_info "Skipping installation. Some tools may not work."
    exit 0
  fi

  # ── Phase 3: Installation ──────────────────────────────────
  echo
  print_header "Installing tools"
  print_info "Updating base packages first..."

  install_base_packages

  # Logical order: Python and pipx first, then the rest
  local install_order=("python3" "git" "jq" "aws" "terraform" "vagrant" "virsh" "docker" "ansible" "localstack")

  for name in "${install_order[@]}"; do
    for req in "${missing_tools[@]}" "${outdated_tools[@]}"; do
      IFS='|' read -r req_name _ _ install_fn <<< "$req"
      if [ "$req_name" == "$name" ]; then
        echo
        print_info "Installing ${BOLD}$name${NC}..."
        if $install_fn; then
          print_ok "$name installed successfully."
        else
          print_missing "Failed to install $name. Please install it manually."
        fi
      fi
    done
  done

  # ── Phase 4: Final verification ────────────────────────────
  echo
  print_header "Final verification"
  local all_ok=true
  for req in "${REQUIREMENTS[@]}"; do
    IFS='|' read -r name min_version version_fn _ <<< "$req"
    local current
    current=$($version_fn)
    if [ -z "$current" ]; then
      print_missing "$name is still not available."
      all_ok=false
    elif version_gte "$current" "$min_version"; then
      print_ok "$name $current"
    else
      print_warn "$name $current (still below $min_version)"
      all_ok=false
    fi
  done

  echo
  if $all_ok; then
    echo -e "${GREEN}${BOLD}✔ Environment ready to continue with the project.${NC}"
    print_info "Note: if pipx installed new tools, run:"
    print_info "  source ~/.bashrc"
    print_info "or open a new terminal so PATH is updated."
  else
    echo -e "${YELLOW}${BOLD}⚠ Some tools require manual attention.${NC}"
    print_info "Check each tool's official documentation."
    exit 1
  fi
}

main "$@"
