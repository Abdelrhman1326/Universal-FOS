#!/bin/bash

set -e

IMAGE="fos-env"

echo "[*] Setting up FOS Docker environment..."

echo "[*] Writing Dockerfile..."

cat > Dockerfile.fos <<'EOF'

FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

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
        bochs \
        bochs-term \
        bochs-sdl \
        bochs-x \
        bochsbios \
        vgabios \
        xvfb \
        x11vnc \
        novnc \
        websockify \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/cross \
    && cd /opt/cross \
    && wget https://github.com/YoussefRaafatNasry/fos-v2/releases/download/toolchain/i386-elf-toolchain-linux.tar.bz2 \
    && tar xjf i386-elf-toolchain-linux.tar.bz2 \
    && rm i386-elf-toolchain-linux.tar.bz2

ENV PATH="/opt/cross/bin:${PATH}"

WORKDIR /fos

EOF

echo "[*] Building Docker image..."

docker build --platform linux/amd64 -t "$IMAGE" -f Dockerfile.fos .

echo "[*] Checking for the project's Bochs config (.bochsrc)..."

# Bochs reads .bochsrc from the project root. It is a hidden file, so plain
# `ls` does not show it. FOS needs 256 MB of RAM, so only write a fallback
# if the project does not already have one.

if [ -f ".bochsrc" ]; then
    echo "    Found .bochsrc - keeping it."
else
    echo "    Not found - writing a minimal .bochsrc"

cat > .bochsrc <<'EOF'

romimage: file=./BIOS-bochs-latest_2-3

vgaromimage: file=./VGABIOS-lgpl-latest

vga: extension=none

cpu: count=1, ips=10000000

megs: 256

ata0: enabled=1, ioaddr1=0x1f0, ioaddr2=0x3f0, irq=14

ata0-master: type=disk, mode=flat, path="./obj/kern/bochs.img"

boot: disk

clock: sync=realtime, time0=local

floppy_bootsig_check: disabled=0

log: bochs.log

panic: action=ask

error: action=report

info: action=ignore

debug: action=ignore

mouse: enabled=0

private_colormap: enabled=0

EOF

fi

# Remove the old guessed config from earlier versions of this script
rm -f conf/bochsrc

echo "[*] Generating run script..."

cat > run <<'EOF'

#!/bin/bash

# Same steps as the Windows "Build and Run Bochs" task, but inside Docker:
#   1. rm -rf obj && make clean && make -j8 all     (full clean rebuild)
#   2. bochs -q                                     (uses ./.bochsrc)
#
#   ./run              Browser mode: opens http://localhost:6080
#   ./run term         Terminal mode: text screen inside this terminal
#   NOCLEAN=1 ./run   Skip the clean rebuild (faster, only runs make)
#
# Stop with Ctrl+C.

cd "$(dirname "$0")"

MODE="${1:-web}"

if [ -n "$NOCLEAN" ]; then
    BUILD="make -j8 all"
else
    BUILD="rm -rf obj && make clean && make -j8 all"
fi

if [ ! -f .bochsrc ]; then
    echo "[!] .bochsrc not found in the project root."
    exit 1
fi

echo "[*] Using the project's Bochs config: .bochsrc"

if [ "$MODE" = "term" ]; then
    echo "[*] Terminal mode. To quit: Ctrl+C, then type q and press Enter."

    docker run --rm -it \
        -v "$PWD":/fos \
        fos-env \
        bash -c "
$BUILD || exit 1

echo c > /tmp/bochs.rc

bochs -rc /tmp/bochs.rc -q 'display_library: term'
"

    exit
fi

URL="http://localhost:6080/vnc.html?autoconnect=true&resize=scale"

echo "[*] Browser mode: $URL"

# Open the browser as soon as the web server inside the container is up
(
    for i in $(seq 1 300); do
        if curl -s -o /dev/null http://localhost:6080/vnc.html; then
            xdg-open "$URL" >/dev/null 2>&1
            break
        fi

        sleep 1
    done
) &

docker run --rm -it \
    -p 127.0.0.1:6080:6080 \
    -v "$PWD":/fos \
    fos-env \
    bash -c "
$BUILD || exit 1

export DISPLAY=:99

Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 &

sleep 1

x11vnc \
    -display :99 \
    -forever \
    -shared \
    -nopw \
    -quiet >/dev/null 2>&1 &

websockify \
    --web /usr/share/novnc \
    6080 \
    localhost:5900 >/dev/null 2>&1 &

echo c > /tmp/bochs.rc

bochs -rc /tmp/bochs.rc -q 'display_library: x'
"

EOF

chmod +x run

echo "[*] Generating clean script..."

cat > clean <<'EOF'

#!/bin/bash

cd "$(dirname "$0")"

echo "[*] Cleaning FOS build files..."

docker run --rm \
    -v "$PWD":/fos \
    fos-env \
    sh -c "rm -rf obj && make clean"

echo "[*] Clean complete."

EOF

chmod +x clean

echo ""

echo "========================================"
echo " FOS Docker setup complete!"
echo "========================================"

echo ""

echo "Run FOS in your browser:"
echo "    ./run"

echo ""

echo "Run FOS in this terminal:"
echo "    ./run term"

echo ""

echo "Skip the full rebuild (faster):"
echo "    NOCLEAN=1 ./run"

echo ""

echo "Clean build files with:"
echo "    ./clean"

echo ""
