# LabBridge v2

Instant cross-platform file transfer for college students. No accounts, no cloud storage, no installation on lab PCs.

## How It Works

```
Open labbridge.app on lab PC → QR appears
Scan QR with LabBridge app → PC shows your folders
Drag file onto folder → File lands on your phone
Send files from phone → Files appear in browser for download
```

## Architecture

| Component | Tech | What It Does |
| :--- | :--- | :--- |
| `worker/` | Cloudflare Worker + Durable Objects | Encrypted-chunk relay. Stores nothing. Rate-limited per IP. |
| `webapp/` | Single HTML file, vanilla JS | PC browser interface. Streamed Blob downloads, XSS-safe rendering. |
| `mobile/` | Flutter (Android + iOS) | Phone app with local SQLite organiser, batch file management. |

## Development

### Worker (local relay server)
```bash
cd worker
npm install
npx wrangler dev    # localhost:8787
```

### Webapp (no build step)
Open `webapp/index.html` in a browser. Update `WORKER_URL` at top of file to point to your local worker.

### Mobile
```bash
cd mobile
flutter pub get
flutter run
# Custom worker URL:
flutter run --dart-define=WORKER_WS_URL=ws://localhost:8787
```

## Deployment

### Worker → Cloudflare (free)
```bash
cd worker
npx wrangler login
npx wrangler deploy
```

### Webapp → Cloudflare Pages (free)
Upload `webapp/` folder to Cloudflare Pages dashboard. Update `WORKER_URL` at the top of `index.html` to your deployed worker URL.

### Mobile → App Stores
```bash
flutter build apk    # Android
flutter build ios    # iOS (requires Mac)
```

## Security

- All file chunks encrypted client-side with **AES-256-GCM** before transmission
- Encryption key derived from session ID via **HKDF-SHA256** — the QR code IS the shared secret
- Mobile and web client use identical UTF-8 encoding for key derivation (no encoding mismatch)
- Chunk index is embedded in the GCM IV and verified on decryption to prevent replay/reorder attacks
- Worker relays raw ciphertext — never sees plaintext
- Sessions expire after 5 minutes; Durable Object self-destructs via alarm
- Per-IP rate limiting on session creation (Cloudflare `CF-Connecting-IP`, not spoofable)
- Binary relay only forwards whitelisted message types
- No accounts, no passwords, no data stored on server ever

## Mobile Data Model

Files and folders are stored in a local SQLite database with FK enforcement (`PRAGMA foreign_keys = ON`). Deleting a folder re-parents both its sub-folders and its directly contained files one level up — nothing is ever silently orphaned.

## Platform Support

| Platform | Status |
| :--- | :--- |
| Android | ✅ Supported |
| iOS | ✅ Supported |
| Linux / Windows / macOS desktop | ❌ Not supported |
