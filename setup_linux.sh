#!/bin/bash

set -e

IMAGE="fos-env"

echo "[*] Setting up FOS Docker environment..."

echo "[*] Writing Dockerfile..."

cat > Dockerfile.fos <<'EOF'
FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y ca-certificates \
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
        pkg-config \
        libncurses-dev \
        libx11-dev \
        libxrandr-dev \
        libxpm-dev \
    && rm -rf /var/lib/apt/lists/*

# Build Bochs 2.7 from source WITHOUT _FORTIFY_SOURCE, so the glibc
# "buffer overflow detected" abort from the Ubuntu package cannot trigger.
# It installs to /usr/local, which comes before /usr/bin in PATH.
RUN cd /tmp \
    && wget -O bochs.tar.gz https://sourceforge.net/projects/bochs/files/bochs/2.7/bochs-2.7.tar.gz/download \
    && tar xzf bochs.tar.gz \
    && cd bochs-2.7 \
    && CFLAGS="-O2 -U_FORTIFY_SOURCE" CXXFLAGS="-O2 -U_FORTIFY_SOURCE" \
       ./configure \
           --enable-debugger \
           --enable-disasm \
           --enable-cpu-level=6 \
           --enable-x86-64=no \
           --with-term \
           --with-x11 \
    && make -j"$(nproc)" \
    && make install \
    && cd / && rm -rf /tmp/bochs*

RUN mkdir -p /opt/cross \
    && cd /opt/cross \
    && wget -O i386-elf-toolchain-linux.tar.bz2 \
        https://github.com/YoussefRaafatNasry/fos-v2/releases/download/toolchain/i386-elf-toolchain-linux.tar.bz2 \
    && tar xjf i386-elf-toolchain-linux.tar.bz2 \
    && rm i386-elf-toolchain-linux.tar.bz2

ENV PATH="/opt/cross/bin:/usr/local/bin:${PATH}"

WORKDIR /fos
EOF

echo "[*] Building Docker image..."

docker build --platform linux/amd64 -t "$IMAGE" -f Dockerfile.fos .

echo "[*] Checking for the project's Bochs config (.bochsrc)..."

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

rm -f conf/bochsrc

echo "[*] Generating run script..."

cat > run <<'EOF'
#!/bin/bash

set -e

cd "$(dirname "$0")"

MODE="${1:-web}"

if [ -n "${NOCLEAN:-}" ]; then
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

    # Fixed 80x25 screen avoids buffer problems in Bochs's ncurses GUI,
    # and the speaker is disabled to remove the ALSA errors.
    docker run --rm -it \
        -e TERM=xterm \
        -v "$PWD":/fos \
        fos-env \
        bash -c "
$BUILD || exit 1
stty rows 25 cols 80
export LINES=25 COLUMNS=80
echo c > /tmp/bochs.rc
bochs -rc /tmp/bochs.rc -q 'speaker: enabled=0' 'display_library: term'
"
    exit
fi

if [ "$MODE" != "web" ]; then
    echo "[!] Usage: ./run [web|term]"
    exit 1
fi

URL="http://localhost:6080/vnc.html?autoconnect=true&resize=scale"

echo "[*] Browser mode: $URL"

# Open the browser when noVNC is ready.
(
    for i in $(seq 1 300); do
        if curl -fsS -o /dev/null http://localhost:6080/vnc.html; then
            if [ "$(uname -s)" = "Darwin" ]; then
                open "$URL"
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$URL" >/dev/null 2>&1 || true
            else
                echo "[!] Open this URL manually: $URL"
            fi
            exit 0
        fi
        sleep 1
    done
    echo "[!] Timed out waiting for noVNC."
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

bochs -rc /tmp/bochs.rc -q 'speaker: enabled=0' 'display_library: x'
"
EOF

chmod +x run

echo "[*] Generating clean script..."

cat > clean <<'EOF'
#!/bin/bash

set -e

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
echo "Skip the full rebuild:"
echo "    NOCLEAN=1 ./run"
echo ""
echo "Clean build files:"
echo "    ./clean"
echo ""
