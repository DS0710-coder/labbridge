# LabBridge Mobile

LabBridge Mobile is a Flutter application designed for secure, high-speed bidirectional file and folder transfer between mobile devices (Android / iOS) and PC web browsers across networks using Cloudflare Workers WebSocket relay and WebRTC.

## Features

- **Instant QR Code Pairing**: Scan a session QR code from the LabBridge web app to establish a secure, authenticated channel.
- **End-to-End Encryption**: AES-256-GCM encryption with PBKDF2 key derivation (`package:cryptography`) ensures all payloads remain private from the relay worker.
- **Streaming & Chunked Transfers**: Memory-safe streaming (`RandomAccessFile` and `archive` streams) allows transferring large files (500MB+) and extracting ZIP archives without triggering Out-Of-Memory (OOM) errors.
- **Dynamic File Organization**: Organize received and local files into custom folder hierarchies stored in local SQLite (`sqflite`). Batch move, delete, and extract files effortlessly.
- **Bidirectional Synchronization**: Automatically sync disconnect states and folder structures between mobile and PC browsers in real time.

## Project Structure

```text
lib/
├── core/
│   ├── config.dart         # Compile-time configuration & worker URLs
│   ├── constants.dart      # Application design tokens and UI constants
│   └── formatters.dart     # Centralized formatting helpers (bytes, storage, speed)
├── models/
│   ├── file_item.dart      # File item data model
│   ├── folder.dart         # Folder hierarchy data model
│   └── transfer.dart       # Transfer progress & history models
├── screens/
│   ├── files_screen.dart   # File management, folder tree & batch operations
│   ├── files_batch_mixin.dart # Modular mixin encapsulating batch actions
│   ├── home_screen.dart    # Dashboard overview & storage analytics
│   ├── scanner_screen.dart # QR code scanner & pairing connection UI
│   └── settings_screen.dart # Worker configuration & data clearing options
├── services/
│   ├── crypto_service.dart # Key derivation & chunk encryption
│   ├── db_service.dart     # SQLite storage management & physical file lifecycle
│   └── transfer_service.dart # WebSocket management & chunked transfer orchestration
└── widgets/
    ├── file_tile.dart      # UI component for displaying file items
    ├── folder_tile.dart    # UI component for displaying folders
    └── transfer_tile.dart  # UI component for displaying ongoing/completed transfers
```

## Getting Started

### Prerequisites
- Flutter SDK 3.19+ (Dart 3.3+)
- Android Studio / Xcode for platform building

### Running Locally

To build and run the application with default compile-time configuration:

```bash
flutter run
```

Or specify a custom worker URL at build time:

```bash
flutter run --dart-define=WORKER_WS_URL=wss://your-worker.workers.dev
```

### Running Tests and Static Analysis

Verify code quality and static diagnostics across the project:

```bash
flutter analyze
```
