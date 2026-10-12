$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

$IMAGE = "fos-env"

# Writes text with LF-only line endings and NO BOM, so files are safe for
# Linux (Docker, bash, Bochs) regardless of PowerShell version settings.
function Write-LF {
    param([string]$Path, [string]$Text)
    $Text = ($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd("`n") + "`n"
    $full = Join-Path $PSScriptRoot $Path
    [System.IO.File]::WriteAllText($full, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "[*] Setting up FOS Docker environment (Windows Browser Mode)..."

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Docker was not found. Install and start Docker Desktop first." -ForegroundColor Red
    exit 1
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Docker is installed but not running. Start Docker Desktop and try again." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Writing Dockerfile..."

Write-LF "Dockerfile.fos" @'
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
        curl \
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
'@

Write-Host "[*] Building Docker image..."

docker build --platform linux/amd64 -t $IMAGE -f Dockerfile.fos .
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Docker build failed." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Checking for the project's Bochs config (.bochsrc)..."

if (Test-Path ".bochsrc") {
    Write-Host "    Found .bochsrc - keeping it."
} else {
    Write-Host "    Not found - writing a minimal .bochsrc"

    Write-LF ".bochsrc" @'
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
'@
}

if (Test-Path "conf/bochsrc") {
    Remove-Item -Force "conf/bochsrc"
}

Write-Host "[*] Generating run.ps1 script..."

Write-LF "run.ps1" @'
param(
    [string]$Mode = "web"
)

$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

function Write-LF {
    param([string]$Path, [string]$Text)
    $Text = ($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd("`n") + "`n"
    $full = Join-Path $PSScriptRoot $Path
    [System.IO.File]::WriteAllText($full, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# Dynamically obtain total logical CPU cores
$NCPUS = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
if (-not $NCPUS) { $NCPUS = 8 }

if ($env:NOCLEAN) {
    $BUILD = "make -j${NCPUS} all"
} else {
    # Delete contents of obj without unmounting the tmpfs RAM mount
    $BUILD = "rm -rf obj/* && make -j${NCPUS} all"
}

if (-not (Test-Path ".bochsrc")) {
    Write-Host "[!] .bochsrc not found in the project root." -ForegroundColor Red
    exit 1
}

$Inner = ".fos_inner.sh"

if ($Mode -eq "term") {
    Write-Host "[*] Terminal mode. To quit: Ctrl+C, then type q and press Enter."

    $script = @(
        '#!/bin/bash',
        "$BUILD || exit 1",
        'echo c > /tmp/bochs.rc',
        "bochs -rc /tmp/bochs.rc -q 'display_library: term'"
    ) -join "`n"

    Write-LF $Inner $script

    docker run --rm -it `
        --cpus="${NCPUS}" `
        --memory="8g" `
        -v "${PSScriptRoot}:/fos" `
        --mount type=tmpfs,destination=/fos/obj `
        fos-env `
        bash /fos/.fos_inner.sh

    exit $LASTEXITCODE
}

$URL = "http://localhost:6080/vnc.html?autoconnect=true&resize=scale"
Write-Host "[*] Browser mode: $URL"

$script = @(
    '#!/bin/bash',
    "$BUILD || exit 1",
    'export DISPLAY=:99',
    'Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 &',
    'sleep 1',
    'x11vnc -display :99 -forever -shared -nopw -quiet >/dev/null 2>&1 &',
    'websockify --web /usr/share/novnc 6080 localhost:5900 >/dev/null 2>&1 &',
    'echo c > /tmp/bochs.rc',
    "bochs -rc /tmp/bochs.rc -q 'display_library: x'"
) -join "`n"

Write-LF $Inner $script

# Launch default browser automatically as soon as noVNC server is responsive
$job = Start-Job -ScriptBlock {
    param($targetUrl)
    for ($i = 1; $i -le 300; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri "http://localhost:6080/vnc.html" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) {
                Start-Process $targetUrl
                break
            }
        } catch {
            # Waiting for web server start
        }
        Start-Sleep -Seconds 1
    }
} -ArgumentList $URL

try {
    docker run --rm -it `
        --cpus="${NCPUS}" `
        --memory="8g" `
        -p 127.0.0.1:6080:6080 `
        -v "${PSScriptRoot}:/fos" `
        --mount type=tmpfs,destination=/fos/obj `
        fos-env `
        bash /fos/.fos_inner.sh
} finally {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
}
'@

Write-Host "[*] Generating clean.ps1 script..."

Write-LF "clean.ps1" @'
$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Write-Host "[*] Cleaning FOS build files..."

docker run --rm `
    -v "${PSScriptRoot}:/fos" `
    --mount type=tmpfs,destination=/fos/obj `
    fos-env `
    sh -c "rm -rf obj/*"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Clean failed." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Clean complete."
'@

Write-Host ""
Write-Host "========================================"
Write-Host " FOS Docker setup complete!"
Write-Host "========================================"
Write-Host ""
Write-Host "Run FOS in your browser:"
Write-Host "    .\run.ps1"
Write-Host ""
Write-Host "Run FOS in this terminal:"
Write-Host "    .\run.ps1 term"
Write-Host ""
Write-Host "Skip full rebuild (faster):"
Write-Host '    $env:NOCLEAN=1; .\run.ps1'
Write-Host ""
Write-Host "Clean build files with:"
Write-Host "    .\clean.ps1"
Write-Host ""
