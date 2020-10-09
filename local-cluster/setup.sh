#!/usr/bin/env bash
set -ex

# default versions
HELM_VER='2.16.12'
HELM_PLUGIN_DIFF_VER='3.1.3'
HELM_PLUGIN_TILLER_VER='0.9.3'
HELMFILE_VER='0.130.1'
KIND_VERSION='0.9.0'
KUBECTL_VERSION='1.19.2'

LIGHT_GREEN='\033[1;32m'
NC='\033[0m' # No Color

while [ $# -gt 0 ]; do
  case "$1" in
    --helm_ver=*|-hv=*)
      if [[ "$1" != *=2.*.* ]]; then
        printf "\nIncompatible Helm ver.\nSupported syntax/version: ${LIGHT_GREEN}2.[x].[x]${NC}\n"
        exit 1
      fi
      HELM_VER="${1#*=}"
      ;;
    --help|-h)
      printf "\nUsage:\
        \n    ${LIGHT_GREEN}--helm_ver,-hv${NC}      Set Helm version to be deployed.\
        \n    ${LIGHT_GREEN}--help,-h${NC}           Prints this message.\
        \nExample:\n    ${LIGHT_GREEN}bash $0 -hv=2.16.12${NC}\n"   # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "\nError: ${LIGHT_GREEN}Invalid argument${NC}\n"
      exit 2
      ;;
  esac
  shift
done

# Install req. pkgs
OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release)

if [ "$OS_ID" == "\"centos\"" ] || [ "$OS_ID" == "\"rhel\"" ] ; then
  if ! `sudo rpm -q docker-ce curl >/dev/null 2>&1` ; then
    sudo yum install -y docker-ce curl
  fi
elif [ "$OS_ID" == "ubuntu" ] || [ "$OS_ID" == "debian" ] ; then
  if ! `sudo dpkg -l docker.io curl >/dev/null 2>&1` ; then
    sudo apt update && apt install -y docker.io curl
  fi
else
    echo "Use "${0}" only on RHEL / CentOS / Ubuntu / Debian"
    exit 3
fi

# Unmask and start Docker service
sudo systemctl unmask docker && \
sudo systemctl start docker

# Install latest "kubectl"
echo -e "\nDownloading kubectl binary..." && \
curl -LO https://storage.googleapis.com/kubernetes-release/release/v"$KUBECTL_VERSION"/bin/linux/amd64/kubectl && \
chmod +x ./kubectl && \
yes | sudo mv ./kubectl /usr/local/bin/kubectl >/dev/null 2>&1 && \
echo -e "\nkubectl version:" && \
kubectl version --client=true && \
source <(kubectl completion bash 2>/dev/null)

# Install "helm"
echo -e "\nDownloading Helm Client binary..." && \
curl -LO https://get.helm.sh/helm-v"$HELM_VER"-linux-amd64.tar.gz && \
tar xf helm-v"$HELM_VER"-linux-amd64.tar.gz && \
yes | mv ./linux-amd64/helm /usr/local/bin >/dev/null 2>&1 && \
rm -rf ./linux-amd64 helm-v"$HELM_VER"-linux-amd64.tar.gz && \
echo -e "\nhelm version:" && \
helm version --client=true && \
source <(helm completion bash 2>/dev/null)

# Install/update Helm plugins: "helm-diff", "tiller"
echo -e "\nInstalling/updating Helm plugins: \"helm-diff\" and \"tiller\"..."
mkdir -p "$(helm home)/plugins"
set +e; helm plugin remove tiller diff >/dev/null 2>&1; set -e
helm plugin install https://github.com/rimusz/helm-tiller --version="$HELM_PLUGIN_TILLER_VER" >/dev/null 2>&1 && \
helm plugin install https://github.com/databus23/helm-diff --version="$HELM_PLUGIN_DIFF_VER" >/dev/null 2>&1 || \
helm plugin update diff tiller >/dev/null
echo -e "\nInstalled Helm plugins:"
helm plugin list 2>/dev/null

# Install latest "helmfile"
echo -e "\nDownloading Helmfile binary..." && \
curl -LO https://github.com/roboll/helmfile/releases/download/v"$HELMFILE_VER"/helmfile_linux_amd64 && \
chmod +x ./helmfile_linux_amd64 && \
yes | mv ./helmfile_linux_amd64 /usr/local/bin/helmfile >/dev/null 2>&1 && \
echo -e "\n" && \
helmfile -v

# Install kINd
echo -e "\nDownloading kINd binary..." && \
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v"$KIND_VERSION"/kind-$(uname)-amd64 && \
chmod +x ./kind && \
yes | mv ./kind /usr/local/bin/kind >/dev/null 2>&1 && \
echo -e "\nkINd version:" && \
kind version && \
source <(kind completion bash 2>/dev/null)
