# LabBridge Mobile

Flutter app for Android & iOS. Pairs with the LabBridge web client via a Cloudflare Worker WebSocket relay to transfer files securely between a phone and any lab PC browser — no accounts, no installation on the PC.

## Features

- **Instant QR Pairing** — Scan a session QR code from the web client to establish an authenticated, encrypted channel.
- **End-to-End Encryption** — AES-256-GCM with HKDF-SHA256 key derivation. The QR code IS the shared secret; the relay worker never sees plaintext.
- **Chunk-ACK Transfer Protocol** — Each 512 KB chunk is individually acknowledged before the next is sent, preventing memory spikes and correctly detecting mid-transfer failures.
- **Streaming ZIP Extraction** — Large ZIPs are extracted entry-by-entry from a stream; the whole archive is never loaded into RAM. Path traversal protection (`p.isWithin`) is applied to every entry.
- **Folder Organiser** — Local SQLite database with full folder hierarchy, batch move, batch delete, re-parenting (delete a folder → its files move up a level, never orphaned).
- **Bidirectional Transfers** — Send files from the phone to the PC browser, and receive files from the PC to the phone.
- **Persistent Transfer History** — Every completed or failed transfer is recorded with status, size, and timestamp.

## Project Structure

```text
lib/
├── core/
│   ├── config.dart           # Compile-time worker URL (--dart-define)
│   ├── constants.dart        # Design tokens and colour palette
│   └── formatters.dart       # Bytes, speed, storage formatting helpers
├── models/
│   ├── file_item.dart        # Received file model
│   ├── folder.dart           # Folder hierarchy model
│   └── transfer.dart         # Transfer record model
├── screens/
│   ├── files_screen.dart     # File browser, folder tree, context actions
│   ├── files_batch_mixin.dart# Batch move / unpack / delete / extract logic
│   ├── home_screen.dart      # Dashboard, storage stats, multi-file send
│   ├── scanner_screen.dart   # QR scanner and manual session-ID entry
│   ├── settings_screen.dart  # Worker URL display, data management
│   └── transfer_screen.dart  # Active transfer view, folder picker
├── services/
│   ├── crypto_service.dart   # HKDF key derivation, AES-GCM chunk encrypt/decrypt
│   ├── db_service.dart       # SQLite CRUD, FK enforcement, atomic transactions
│   └── transfer_service.dart # WebSocket lifecycle, chunk-ACK send, folder sync
└── widgets/
    ├── file_tile.dart         # File list item
    ├── folder_tile.dart       # Folder list item
    └── transfer_progress.dart # Progress bar widget
```

## Getting Started

### Prerequisites
- Flutter SDK 3.19+ (Dart 3.3+)
- Android Studio / Xcode for device builds

### Run with default config
```bash
cd mobile
flutter pub get
flutter run
```

### Run against a custom worker
```bash
flutter run --dart-define=WORKER_WS_URL=ws://localhost:8787
```

### Static analysis
```bash
flutter analyze   # must report: No issues found
```

## Key Implementation Notes

| Area | Detail |
| :--- | :--- |
| Key derivation | `CryptoService.deriveKey` uses `utf8.encode(sessionId)` for IKM — identical to the web client's `TextEncoder`, no encoding mismatch |
| Chunk IV | 8 random bytes + 4-byte big-endian chunk index. Index is verified on decryption to catch replay/reorder |
| Transfer flow | `sendFile` waits for `ready` before sending chunk 0, then waits for an `ack` after each chunk (15 s timeout). False-positive completions are impossible |
| Folder delete | Atomically re-parents sub-folders AND contained files to the deleted folder's parent in one transaction. `PRAGMA foreign_keys = ON` set on every connection |
| Batch operations | `firstWhere` replaced with safe `.where().first` guards throughout to prevent `StateError` crashes on state desync |
| Context safety | All `BuildContext` uses across async gaps are guarded with `if (!mounted) return` or captured before the first `await` |
