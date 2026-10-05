#!/bin/bash

set -e

IMAGE="fos-env"

echo "[*] Setting up FOS Docker environment..."

echo "[*] Writing Dockerfile (if missing)..."

if [ ! -f "Dockerfile.fos" ]; then
cat > Dockerfile.fos <<'EOF'
FROM --platform=linux/amd64 ubuntu:22.04

# Install CA certificates first over HTTP so HTTPS APT mirrors can be trusted
RUN apt-get update && apt-get install -y ca-certificates \
    && sed -i 's|http://archive.ubuntu.com|https://mirrors.edge.kernel.org|g' /etc/apt/sources.list \
    && sed -i 's|http://security.ubuntu.com|https://mirrors.edge.kernel.org|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y \
        build-essential \
        qemu-system-x86 \
        gdb \
        libfl-dev \
        wget \
        bzip2 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/cross \
    && cd /opt/cross \
    && wget https://github.com/YoussefRaafatNasry/fos-v2/releases/download/toolchain/i386-elf-toolchain-linux.tar.bz2 \
    && tar xjf i386-elf-toolchain-linux.tar.bz2 \
    && rm i386-elf-toolchain-linux.tar.bz2

ENV PATH="/opt/cross/bin:${PATH}"

WORKDIR /fos
EOF
fi

echo "[*] Building Docker image..."

docker build --platform linux/amd64 -t "$IMAGE" -f Dockerfile.fos .

echo "[*] Generating run script..."

cat > run <<'EOF'
#!/bin/bash

# Build FOS and run it inside the Docker environment.
# Quit with: Ctrl+A, then X

cd "$(dirname "$0")"

docker run --rm -it \
    -v "$PWD":/fos \
    fos-env \
    bash -c "make && qemu-system-i386 -display none -serial mon\:stdio -parallel file:/dev/stdout -drive file=obj/kern/bochs.img,media=disk,format=raw -smp 2 -m 32"
EOF

chmod +x run

echo "[*] Generating clean script..."

cat > clean <<'EOF'
#!/bin/bash

cd "$(dirname "$0")"

echo "[*] Cleaning FOS build files..."

make clean

echo "[*] Clean complete."
EOF

chmod +x clean

echo ""
echo "========================================"
echo " FOS Docker setup complete!"
echo "========================================"
echo ""
echo "Run FOS with:"
echo "    ./run"
echo ""
echo "Clean build files with:"
echo "    ./clean"
echo ""
echo "The Docker environment only needs to be"
echo "built once. After modifying FOS, simply"
echo "run ./run again."
echo ""
