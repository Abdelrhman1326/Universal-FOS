$ErrorActionPreference = "Stop"

$Image = "fos-env"

function Write-Lf {
    param (
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Write-Crlf {
    param (
        [string]$Path,
        [string]$Content
    )

    $Content = $Content -replace "`r?`n", "`r`n"

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

Write-Host "[*] Setting up FOS Docker environment..."

Write-Host "[*] Writing Dockerfile (if missing)..."

if (-not (Test-Path "Dockerfile.fos")) {

$dockerfile = @'
FROM --platform=linux/amd64 ubuntu:22.04

RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
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
'@

    Write-Lf "Dockerfile.fos" $dockerfile
}

Write-Host "[*] Building Docker image..."

docker build --platform linux/amd64 -t $Image -f Dockerfile.fos .

Write-Host "[*] Generating run script..."

$run = @'
# Build FOS and run it inside the Docker environment.
# Quit with: Ctrl+A, then X

Set-Location $PSScriptRoot

docker run --rm -it -v "${PWD}:/fos" fos-env bash -c "make && qemu-system-i386 -display none -serial mon\:stdio -parallel file:/dev/stdout -drive file=obj/kern/bochs.img,media=disk,format=raw -smp 2 -m 32"
'@

Write-Lf "run.ps1" $run

$cmd = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
'@

Write-Crlf "run.cmd" $cmd

Write-Host "[*] Generating clean script..."

$clean = @'
# Clean FOS build files.

Set-Location $PSScriptRoot

docker run --rm -it -v "${PWD}:/fos" fos-env bash -c "make clean"
'@

Write-Lf "clean.ps1" $clean

$cleanCmd = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean.ps1"
'@

Write-Crlf "clean.cmd" $cleanCmd

Write-Host ""
Write-Host "========================================"
Write-Host " FOS Docker setup complete!"
Write-Host "========================================"
Write-Host ""
Write-Host "Run FOS with:"
Write-Host "    .\run.ps1"
Write-Host ""
Write-Host "Or:"
Write-Host "    .\run.cmd"
Write-Host ""
Write-Host "Clean build files with:"
Write-Host "    .\clean.ps1"
Write-Host ""
Write-Host "The Docker environment only needs to be"
Write-Host "built once. After modifying FOS, simply"
Write-Host "run the generated run script again."
Write-Host ""
