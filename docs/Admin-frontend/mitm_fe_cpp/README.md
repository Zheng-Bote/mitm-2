<div id="top" align="center">
<h1>MitM Admin Frontend</h1>

<p>Admin Frontend for the MitM Data Aggregator project. It connects securely to the Go-based Scheduler via REST APIs and high-performance FlatBuffers binary endpoints to manage jobs, mapping rules, and view system and audit logs.</p>

![License](https://img.shields.io/badge/license-Apache_2.0-green)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey.svg)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/Zheng-Bote/mitm_fe_cpp?logo=GitHub)](https://github.com/Zheng-Bote/mitm_fe_cpp/releases)
<br/>
[Report Issue](https://github.com/Zheng-Bote/mitm_fe_cpp/issues) · [Request Feature](https://github.com/Zheng-Bote/mitm_fe_cpp/pulls)
</div>

---
<!-- START doctoc generated TOC please keep comment here to allow auto update -->

<details>
<summary>Table of Contents</summary>

- [Features](#features)
  - [Status](#status)
- [Requirements](#requirements)
- [Building the Project](#building-the-project)
  - [1. Install Conan Dependencies & Generate Presets](#1-install-conan-dependencies-generate-presets)
  - [2. Configure with CMake](#2-configure-with-cmake)
  - [3. Build](#3-build)
  - [4. Configuration Setup](#4-configuration-setup)
  - [5. Run](#5-run)

</details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->
---

## Features
* **Encrypted Configuration**: Master configuration (`config.enc`) and user-specific configurations (`<username>_config.enc`) are protected via AES-256-GCM and Argon2id (libsodium). At startup, the application prompts for a master password.
* **Configuration Profiles**: Switch seamlessly between multiple encrypted environments directly from the UI. The active configuration is persisted and displayed in the status bar.
* **Automatic Version Check**: Uses `gh-update-checker` to asynchronously verify if a new release of the frontend is available on GitHub and displays the status in the "About" dialog.
* **Dynamic RBAC & Read-Only Mode**: Dynamically fetches the OS user's roles from the backend on startup. Modifies the UI to restrict or allow access (e.g. read-only "Viewer" mode disables all edits, full access for "Admin").
* **Manual File Upload**: Allows authorized users (UPLOADER/ADMIN) to securely upload and process `.csv` and `.xlsx` raw data files on the fly.
* **Windows Hello Authentication**: Implements seamless biometric authentication via WinRT for accessing sensitive areas like the Settings & Key Vault and authenticating the user.
* **Network Proxy Settings**: Configurable per-user network proxy settings that override defaults and support authenticated HTTP/HTTPS proxies.
* **Advanced Logging & Dashboard**: Interactive dashboard with real-time stats and comprehensive data grids for Admin, System, Job, and Transformation logs.
* **Dynamic API & Auth**: Derives the Scheduler host and authentication header directly from the decrypted config.
* **HTTPS Support**: Configurable HTTPS connectivity (`scheduler_use_https`) to securely interface with FQDNs.
* **Local Timezone Formatting**: Seamlessly translates UTC timestamps to the user's local timezone directly within data grids.
* **Scheduler Next Run**: Dynamically calculates and displays upcoming job execution times in the user's local timezone directly in the jobs grid.
* **Scheduler Active State & Control**: Displays real-time process execution status (Running PID / Idle) and allows users with the `ADMIN` role to terminate active jobs directly from the UI (`⏹ Stop Selected`).
* **Rule Sandbox**: Real-time "Test Preview" sandbox to safely simulate complex data transformations (e.g., Dates and Regex) before saving them to the backend.
* **Modern C++23 Stack**: Built with Qt6, FlatBuffers, nlohmann_json, spdlog, libsodium, and cpp-httplib.

### Status
![GitHub Created At](https://img.shields.io/github/created-at/Zheng-Bote/mitm_fe_cpp?logo=GitHub)
![GitHub Release Date](https://img.shields.io/github/release-date/Zheng-Bote/mitm_fe_cpp?logo=GitHub)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/Zheng-Bote/mitm_fe_cpp?logo=GitHub)](https://github.com/Zheng-Bote/mitm_fe_cpp/releases)
![GitHub repo size](https://img.shields.io/github/repo-size/zheng-bote/mitm_fe_cpp)
![Status](https://img.shields.io/badge/Status-stable-green)

## Requirements
*   **Compiler**: C++23 compatible (GCC 13+, Clang 16+, MSVC 19.38+)
*   **Build System**: CMake 3.21+
*   **Package Manager**: Conan 2.x
*   **Framework**: Qt6 (installed system-wide or via Qt Online Installer)
*   **System Dependencies**: OpenSSL (required by cpp-httplib)

## Building the Project

We use Conan to fetch most C++ libraries (`flatbuffers`, `spdlog`, `nlohmann_json`, `libsodium`, `cpp-httplib`, `openssl`) and CMake to build the Qt6 application. `gh-update-checker` is pulled automatically via CMake's `FetchContent`.

### 1. Install Conan Dependencies & Generate Presets

**Windows**

Run this from the `admin-frontend/mitm_fe_cpp` directory:
```bash
conan install . --build=missing -s build_type=Release
```

**Linux**

Run this from the `admin-frontend/mitm_fe_cpp` directory:
```bash
conan install . --build=missing -pr:b default
```

### 2. Configure with CMake
Conan generates modern CMake presets. Use them directly from the project root:

**Windows**

```bash
cmake --preset conan-default -DCMAKE_VS_GLOBALS=VcpkgEnabled=false
```

**Linux**

```bash
cmake --preset conan-release
```
*Note: If Qt6 is not in your system path, you may need to add `-DCMAKE_PREFIX_PATH=/path/to/Qt/6.x/gcc_64` to the configure command.*

### 3. Build
```bash
cmake --build --preset conan-release -j
```

### 4. Configuration Setup
Before running the application for the first time, you need a valid encrypted `config.enc`. This is usually generated by the backend or via a dedicated script using the same Master Key and Argon2id parameters. The frontend will ask for the password to decrypt this file at startup. By default, it expects to find `config.enc` in the same directory as the executable, or you can pass the path as a command-line argument. Once loaded, the selection is saved and remembered for future startups. User-specific proxy configurations are saved under the `configs/` directory.

### 5. Run
```bash
./build/Release/bin/mitm_fe_cpp [path/to/config.enc]
```

**Windows**
```bash
<your_Qt_path>\windeployqt6.exe --release -force-openssl mitm_fe_cpp.exe
```
