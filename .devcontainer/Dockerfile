FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ENV DEBIAN_FRONTEND=noninteractive

# Core build and debugging tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    make \
    g++ \
    python3 \
    python3-pip \
    iputils-ping \
    netcat \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install nvm and multiple Node.js runtimes used by this workspace
USER vscode
ENV NVM_DIR=/home/vscode/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 10 \
    && nvm install 16 \
    && nvm install 20 \
    && nvm alias default 16 \
    && nvm use default \
    && npm install -g npm@8 @angular/cli@8.3.29 mongosh azure-functions-core-tools@4 --unsafe-perm true \
    && npm config set legacy-peer-deps true

# Make nvm available in interactive shells
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /home/vscode/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /home/vscode/.bashrc \
    && echo 'nvm use default >/dev/null 2>&1' >> /home/vscode/.bashrc

USER root

# Install bicep through Azure CLI so az bicep commands are available
RUN az bicep install || true

USER vscode
