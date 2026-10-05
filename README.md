# AirCard-iOS 多语言版本

<p align="center">
  <img src="ios-app/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" height="128" alt="AirCard-iOS Icon" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.18);" />
</p>

<p align="center">
  基于 AirCard-iOS 的多语言版本，支持在 iOS 27+ 上自定义 Apple Wallet 卡面、锁屏密码主题和 PosterBoard 壁纸。
</p>

> ### 上游项目声明
>
> 本项目基于原项目 [Mak5er/AirCard-iOS](https://github.com/Mak5er/AirCard-iOS) 开发；原项目地址：[github.com/Mak5er/AirCard-iOS](https://github.com/Mak5er/AirCard-iOS)。本仓库由 [@zy364601065](https://github.com/zy364601065) 维护，主要新增应用界面多语言支持。
>
> 原项目的 MIT [LICENSE](LICENSE) 与版权声明均予以保留。

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2027+-blue?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-5.0-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/Rust-FFI%20Core-red?style=flat-square&logo=rust" alt="Rust" />
  <img src="https://img.shields.io/badge/界面语言-English%20%7C%20简体中文%20%7C%20繁體中文-0A7EA4?style=flat-square" alt="界面语言：English、简体中文、繁體中文" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

## Overview

AirCard-iOS customizes Apple Wallet card artwork, lock screen passcode dialers, and lock screen wallpapers on device without a jailbreak.

The app communicates with internal system services over a local loopback tunnel (`10.7.0.1` or `127.0.0.1`) provided by LocalDevVPN. File operations are handled by `AirliftFFI`, a Rust library that interfaces with the AirTraffic service.

> **Compatibility**: AirCard-iOS currently requires **iOS 27.0 or newer (iOS 27+)**.

## 技术栈

- **Swift / SwiftUI** — iOS 应用与用户界面。
- **Rust** — `AirliftFFI` 核心库与设备服务集成。
- **Objective-C / C** — 互操作辅助代码与框架头文件。
- **Shell** — IPA 和 iOS Framework 构建自动化。
- **YAML** — XcodeGen 项目配置。

## 本仓库新增：应用界面多语言

应用默认跟随系统语言，也可以在“设置”中手动选择：

- English (`en`)
- 简体中文 (`zh-Hans`)
- 繁體中文 (`zh-Hant`)

## Features

### 应用界面多语言
- 支持 **English**、**简体中文** 和 **繁體中文**。
- 默认跟随 iOS 系统语言，也可随时在“设置”中切换。

### Apple Wallet card skins
- Writes custom card artwork to Passbook caches (`cardBackgroundCombined@3x.png`, `@2x.png`, and `cardBackgroundCombined.pdf` for transit cards like Suica).
- Flushes front-face and thumbnail caches so new artwork appears immediately when Wallet opens.
- Detects card identifiers in real time when you bring up Apple Pay.
- Apply artwork to individual cards or batch-flash every detected card.

### Passcode dialer themes
- Live dialer preview with touch panning and zoom framing.
- Full poster layout across all ten buttons, or individual circular button cutouts.
- Targets system dialer caches (`TelephonyUI-10`).
- Localized number subtext options, including Ukrainian and Russian Cyrillic layouts.
- Import and export themes as `.passthm` files.

### PosterBoard wallpapers (.tendies)
- Import and unpack `.tendies` wallpaper archives directly from the Files app.
- Auto-detects PosterBoard wallpaper containers and active descriptor UUIDs.
- Injects wallpaper configurations and assets into PosterBoard storage.
- Automatically triggers a NeoSpring respring after flashing to apply wallpapers without rebooting your iPhone.

### Pairing options
- **Import pairing file**: Supports pairing files (`.mobiledevicepairing`, `.plist`, `.mobilepair`) from **SideStore**, **LiveContainer**, **iLoader**, **AltStore**, **Jitterbug**, or exported from Mac/PC.
- **On-device pairing (iOS 27+)**: Advertises locally over Bonjour so the phone can pair with itself via Settings > Privacy & Security > Developer Mode > Pair with AirCard-iOS.
- **Safe unpairing**: Easily delete the active pairing file to re-pair or switch pairing credentials at any time.

## Prerequisites

1. **iOS 27+** (for on-device Settings pairing) or **Any supported iOS version** when using an imported pairing file (e.g. from SideStore / iLoader).
2. **LocalDevVPN / WireGuard**: Running in loopback mode (`10.7.0.1` or `127.0.0.1`) so local connections can reach internal device services.
3. **Pairing record**: Either on-device pairing or an imported pairing file.

## Pairing Setup Guide

AirCard-iOS requires a pairing record to communicate with device lockdown services. Choose the method that best matches your setup:

### Option A: SideStore (Recommended)
If you already use SideStore on your device, it has already created a valid pairing file:
1. Open **AirCard-iOS** and go to the **Pairing** tab.
2. Tap **Import Pairing File…**.
3. In the Files document picker, navigate to:
   ```text
   On My iPhone › SideStore › ALTPairingFile.mobiledevicepairing
   ```
4. Select `ALTPairingFile.mobiledevicepairing`. The app will load it immediately (`Pairing file loaded ✅`).

### Option B: LiveContainer (with SideStore inside)
If you run SideStore inside LiveContainer:
1. Open **AirCard-iOS** › **Pairing** tab › tap **Import Pairing File…**.
2. In the Files document picker, navigate to:
   ```text
   On My iPhone › LiveContainer › SideStore › Documents › ALTPairingFile.mobiledevicepairing
   ```
   *(depending on your LiveContainer version, you can also check `On My iPhone › LiveContainer › Data › App › ... › SideStore › Documents`)*
3. Select `ALTPairingFile.mobiledevicepairing`.

### Option C: iLoader / Jitterbug / AltStore / Computer
- **iLoader / Jitterbug**: In the respective app, export your pairing file (`<UDID>.mobiledevicepairing`) into the Files app, then import it in AirCard-iOS.
- **Mac / PC**: Generate a pairing record using `jitterbugpair`, `pymobiledevice3`, or copy it from your computer (`/var/db/lockdown/<UDID>.plist` on macOS or `%ProgramData%\Apple\Lockdown\<UDID>.plist` on Windows), AirDrop/transfer it to your device, and import it into AirCard-iOS.
- **Manual placement**: You can also drop any `.mobiledevicepairing` or `.plist` directly into `On My iPhone › AirCard-iOS` via the Files app; it will appear under *Discovered in Documents* ready to use.

### Option D: On-Device Pairing (iOS 27+ only)
On devices running iOS 27 or newer:
1. In the **Pairing** tab, tap **Pair This iPhone**.
2. Note the 6-digit PIN displayed on screen.
3. Open **Settings › Privacy & Security › Developer Mode › Pair with AirCard-iOS**.
4. Enter the PIN to approve the pairing. AirCard-iOS will complete the handshake and save the credentials.

## Installation

Install `AirCard-iOS.ipa` using your preferred sideloading method:

- SideStore or AltStore
- TrollStore
- LiveContainer
- Xcode or iOS App Signer

## Building from source

### Requirements
- macOS 14.0 or newer with Xcode 16 or newer
- XcodeGen (`brew install xcodegen`)
- Rust toolchain (only needed if rebuilding `rust-core`)

### Build the IPA
```bash
git clone https://github.com/mak5er/AirCard-iOS.git
cd AirCard-iOS
./build-ipa.sh
```

The completed package is written to `build/AirCard-iOS.ipa`.

### Rebuilding the Rust framework
To compile changes in `rust-core`:
```bash
./build-ios.sh
```

## Repository structure

```
AirCard-iOS/
├── ios-app/                   # SwiftUI application
│   ├── AirCardApp.swift       # App entry point and lifecycle
│   ├── AppViewModel.swift     # State management and exploit orchestration
│   ├── ContentView.swift      # Main UI views
│   ├── TendiesView.swift      # PosterBoard wallpaper view
│   ├── TendiesEngine.swift    # Tendies extraction and injection logic
│   ├── RespringHelper.swift   # NeoSpring WebKit respring implementation
│   ├── Models.swift           # Image slicing, theme layout, archive packing
│   ├── PairingController.swift# Bonjour host and pairing sync
│   ├── NetworkStatus.swift    # VPN loopback detection
│   ├── Utilities.swift        # Background keep-alive and helper functions
│   ├── GrappaHelper.[h,m]     # ATC protocol helpers
│   ├── Info.plist             # Bundle configuration
│   └── Assets.xcassets/       # App icons and image sets
├── AirliftFFI.xcframework/    # Compiled arm64 Rust static library and headers
├── rust-core/                 # Rust core source code
├── project.yml                # XcodeGen project definition
├── build-ipa.sh               # IPA build script
├── build-ios.sh               # Rust framework build script
├── LICENSE                    # MIT License
└── README.md                  # Project documentation
```

## License

MIT License. See [LICENSE](LICENSE) for details.
