# MonoChat

![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Linux-teal)
![Status](https://img.shields.io/badge/Status-Beta-orange)

**MonoChat** is a modern, secure, and decentralized messenger built on the **Matrix** protocol. Designed with a focus on visual aesthetics and user experience, it features a polished iOS-style interface that provides a smooth and premium feel across all platforms.

Privacy and security are at the core of MonoChat. It leverages robust End-to-End Encryption (E2EE) to ensure your conversations remain private, and it supports decentralized communication through the Matrix network.

---

## 🚀 Key Features

*   **🛡️ End-to-End Encryption (E2EE)**: Built on `vodozemac` (Rust implementation of Olm/Megolm) for industrial-strength security.
*   **📡 Decentralized**: Connects to any Matrix homeserver (Synapse, Dendrite, Conduit, etc.).
*   **🎨 Premium UI/UX**: thoughtfully designed interface inspired by iOS aesthetics, featuring smooth animations, blur effects, and intuitive navigation.
*   **🏢 Spaces & Groups**: Full support for Matrix Spaces to organize your chats and communities.
*   **🔔 UnifiedPush Support**: Privacy-preserving push notifications that don't rely on Google services (keeps your battery life healthy and data private).
*   **🔐 Secure Storage**: Local database encryption using SQLCipher ensures your message history is safe even if your device is compromised.
*   **📱 Multi-Device**: Seamless synchronization across multiple devices with cross-signing and device verification.
*   **📂 File Sharing**: Securely share images, videos, and files with encryption.

## 🛠️ Technology Stack

MonoChat is built with **Flutter**, ensuring a high-performance, native-like experience on multiple platforms.

*   **Language**: Dart
*   **Framework**: Flutter
*   **Matrix SDK**: `matrix` package with `flutter_vodozemac` for crypto.
*   **State Management**: Provider
*   **Architecture**: Clean Architecture (Layered separation of UI, Domain, and Data).
*   **Local DB**: SQLite with SQLCipher encryption.

## 📥 Installation

### Android (F-Droid)
MonoChat will be available on F-Droid soon.
<!-- [Download from F-Droid](LINK_TO_FDROID) -->

### Build from Source

**Prerequisites:**
*   Flutter SDK
*   Dart SDK

**Steps:**

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/IQUXAe/monochat.git
    cd monochat
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    flutter run
    ```

4.  **Build simple APK:**
    ```bash
    flutter build apk --release
    ```

## 🤝 Contributing

We welcome contributions! MonoChat is Open Source software.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add: some amazing feature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

Please see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a technical overview of the codebase to help you get started.

## 📄 License

Distributed under the **GNU Cloud Affero General Public License v3.0 (AGPLv3)**. See `LICENSE` for more information.

---
*Built with ❤️ for the decentralized web.*
