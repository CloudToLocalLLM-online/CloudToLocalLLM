FROM ghcr.io/cirruslabs/flutter:stable
RUN echo "=== Container User Info ===" && \
    echo "Current user: \right-pc\rightguy" && \
    echo "Current UID: \" && \
    echo "Current GID: \" && \
    echo "Home: \C:\Users\rightguy" && \
    echo "" && \
    echo "=== All users ===" && \
    cat /etc/passwd && \
    echo "" && \
    echo "=== Environment ===" && \
    env | grep -E "(HOME|USER|PUB)" || true
