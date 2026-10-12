$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

$IMAGE = "fos-env"

# Writes text with LF-only line endings and NO BOM, so files are safe for
# Linux (Docker, bash, Bochs) no matter what Windows PowerShell version runs this.
function Write-LF {
    param([string]$Path, [string]$Text)
    $Text = ($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd("`n") + "`n"
    $full = Join-Path $PSScriptRoot $Path
    [System.IO.File]::WriteAllText($full, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "[*] Setting up FOS Docker environment..."

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

# Bochs reads .bochsrc from the project root. It is a hidden file.
# FOS needs 256 MB of RAM, so only write a fallback if the project has none.
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

# Remove the old guessed config from earlier versions of this script
if (Test-Path "conf/bochsrc") {
    Remove-Item -Force "conf/bochsrc"
}

Write-Host "[*] Generating run.ps1 script..."

# NOTE: run.ps1 writes its container-side commands to a small LF-only .sh file
# (.fos_inner.sh) and runs that, which avoids Windows quoting / CRLF problems.
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

if ($env:NOCLEAN) {
    $BUILD = "make -j8 all"
} else {
    $BUILD = "rm -rf obj && make clean && make -j8 all"
}

if (-not (Test-Path ".bochsrc")) {
    Write-Host "[!] .bochsrc not found in the project root." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Using the project's Bochs config: .bochsrc"

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
        -v "${PSScriptRoot}:/fos" `
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

# Open the browser as soon as the web server inside the container is up
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
            # Web server not up yet
        }
        Start-Sleep -Seconds 1
    }
} -ArgumentList $URL

try {
    docker run --rm -it `
        -p 127.0.0.1:6080:6080 `
        -v "${PSScriptRoot}:/fos" `
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
    fos-env `
    sh -c "rm -rf obj && make clean"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Clean failed." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Clean complete."
'@

# Warn if the repo is likely to have CRLF line endings that break the Linux build
$autocrlf = (git config core.autocrlf 2>$null)
if ($autocrlf -eq "true") {
    Write-Host ""
    Write-Host "[!] git core.autocrlf is 'true'. Source files / Makefiles may have CRLF" -ForegroundColor Yellow
    Write-Host "    line endings, which can break the build inside Linux. Fix with:" -ForegroundColor Yellow
    Write-Host "        git config core.autocrlf input" -ForegroundColor Yellow
    Write-Host "    then re-clone (or run: git rm --cached -r . ; git reset --hard)." -ForegroundColor Yellow
}

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
Write-Host "Skip the full rebuild (faster):"
Write-Host '    $env:NOCLEAN=1; .\run.ps1'
Write-Host ""
Write-Host "Clean build files with:"
Write-Host "    .\clean.ps1"
Write-Host ""
