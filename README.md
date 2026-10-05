## Quick Start

### 1. Download the repository

Clone the repository:

```bash
git clone https://github.com/<your-username>/fos-v2-docker.git
```

### 2. Enter the FOS project

```bash
cd Uneversal-FOS
```

### 3. Run the setup script

Choose the script for your operating system:

**Linux**

```bash
chmod +x setup_linux.sh
./setup-linux.sh
```

**macOS**

```bash
bash setup-macos.sh
```

**Windows**

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-windows.ps1
```

> ** You only need to do this once.**
>
> The setup takes around **5 minutes** and builds a complete Docker environment for FOS, including everything required to build and run it.
>
> Once the setup is finished, **you will not need to run the setup script again**.

### 4. Run FOS

After setup, a `run` script will be generated in your FOS directory.

Run it:

```bash
./run
```

This script will build and start FOS for you.

### After Changing Your FOS Code

You **do not** need to run the setup again.

Whenever you modify your FOS source code, simply run:

```bash
./run
```

The script will detect your changes, rebuild the necessary parts of FOS, and start it again.

So your normal workflow is simply:

```text
Edit FOS code
     ↓
./run
     ↓
Changes are detected
     ↓
FOS is rebuilt
     ↓
FOS starts
```

**Setup once. Run `./run` whenever you want to build and run FOS.**

