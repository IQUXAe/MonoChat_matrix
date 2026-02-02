# MonoChat Technical Architecture

This document provides a high-level overview of the MonoChat architecture for developers and contributors.

## 🏗️ Architectural Pattern

MonoChat follows the principles of **Clean Architecture**, separating the codebase into distinct layers of responsibility. This facilitates testability, maintainability, and scalability.

The project structure in `lib/` reflects these layers:

### 1. Presentation Layer (`lib/ui`, `lib/controllers`)
Responsible for showing data to the user and handling user interactions.
*   **Screens (`ui/screens`)**: Flutter widgets representing full pages.
*   **Widgets (`ui/widgets`)**: Reusable UI components.
*   **Controllers (`controllers/`)**: `ChangeNotifier` classes that manage the state of the UI. They interact with the Domain/Data layers to fetch or update data and notify the UI of changes.
    *   `AuthController`: Manages login/registration state.
    *   `SpaceController`: Manages Matrix Spaces hierarchy.
    *   `RoomListController`: Manages the list of active chats.

### 2. Domain Layer (`lib/domain`)
Contains the business logic and entities of the application. Ideally, this layer is independent of any external frameworks (though in practice, Matrix types are used).
*   **Entities**: Core data models used by the app.
*   **Repositories (Interfaces)**: Abstract definitions of how data should be accessed.

### 3. Data Layer (`lib/data`, `lib/services`)
Responsible for data retrieval, storage, and networking.
*   **Repositories (Implementations)**: Concrete implementations of the capabilities defined in the Domain layer.
    *   `MatrixAuthRepository`: Handles interaction with the Matrix SDK for auth.
    *   `MatrixRoomRepository`: Abstraction over room operations.
*   **Services (`lib/services`)**:
    *   `MatrixService`: A singleton wrapper around the specific Matrix Client SDK instance. It initializes the client, manages the session, and handles the sync loop.
    *   `BackgroundUploader`: Handles media uploads in the background.

## 🔐 Security & Cryptography

Security is a primary requirement for MonoChat.

*   **Encryption Engine**: We use `flutter_vodozemac`, a Flutter binding for the Rust-based `vodozemac` library (the official Matrix Rust SDK crypto crate). This handles Olm/Megolm sessions directly.
*   **Local Storage**: The `matrix` Dart SDK is configured to use `sqflite_sqlcipher`.
    *   The database is encrypted using a key derived from the user's credentials or a randomly generated key stored in the device's Secure Storage (Keychain/Keystore).
    *   This ensures that `access_tokens` and message history are encrypted at rest.

## 🔄 State Management

The application uses **Provider** for dependency injection and state management.

*   **Dependency Injection**: `MultiProvider` at the root of the app (`main.dart`) initializes and exposes the core services (`MatrixService`, Repositories) and global controllers (`ThemeController`, `AuthController`).
*   **Reactive UI**: Widgets use `Consumer<T>` or `context.select<T>` to listen for changes in Controllers and rebuild only when necessary.

## 🔔 Notifications

Push notifications are handled via **UnifiedPush** to protect user privacy and avoid dependency on proprietary Google Play Services where possible.
*   `NotificationBackgroundHandler`: Handles incoming push payloads in a background isolate to decrypt and display notifications even when the app is closed.

## 🎨 Design System

The app enforces a strict **iOS-style (Cupertino)** design language across all platforms:
*   We use `CupertinoApp` as the root.
*   Custom widgets in `ui/widgets` should mimic iOS behaviors (blur headers, swipe-to-back, bottom sheets).
*   `ThemeController` manages dynamic theme switching (Light/Dark) and palette generation.
