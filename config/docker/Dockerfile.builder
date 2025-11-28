# ============================================================================
# Builder Dockerfile for CloudToLocalLLM
# Contains tools to build Flutter, Node.js, and sync artifacts
# ============================================================================
FROM cloudtolocalllm/base:latest

USER root

# Install build dependencies
# - git: for pulling code
# - kubectl: for exec-ing into pods
# - nodejs/npm: for building API/Streaming
# - java/clang/cmake/ninja/pkg-config/gtk3-devel: for Flutter Linux build (if needed) or just basic tools
# - unzip: for flutter installation
RUN dnf -y install \
    git \
    # Node.js 22 (LTS) is the default in Fedora 41+. Ensure package.json engines match this.
    nodejs \
    npm \
    java-devel \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    gtk3-devel \
    unzip \
    which \
    && dnf clean all

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Switch to cloudtolocalllm user for Flutter install
USER cloudtolocalllm
WORKDIR /home/cloudtolocalllm

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable
ENV PATH="/home/cloudtolocalllm/flutter/bin:$PATH"
RUN flutter config --no-analytics
RUN flutter doctor

# Set up app directory
WORKDIR /app

# Copy build script
COPY --chown=cloudtolocalllm:cloudtolocalllm scripts/build-and-sync.sh /usr/local/bin/build-and-sync.sh
RUN chmod +x /usr/local/bin/build-and-sync.sh

# Keep the container running
CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
