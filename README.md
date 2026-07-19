# LabBridge v2

Instant cross-platform file transfer for college students. No accounts, no cloud storage, no installation on lab PCs.

## How It Works

```
Open labbridge.app on lab PC → QR appears
Scan QR with LabBridge app → PC shows your folders
Drag file onto folder → File lands on your phone
```

## Architecture

| Component | Tech | What It Does |
| :--- | :--- | :--- |
| `worker/` | Cloudflare Worker + Durable Objects | Pure encrypted-chunk relay. Stores nothing. |
| `webapp/` | Single HTML file, vanilla JS | PC browser interface. No build step. |
| `mobile/` | Flutter (Android + iOS) | Phone app with local SQLite organizer. |

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
```

## Deployment

### Worker → Cloudflare (free)
```bash
cd worker
npx wrangler login
npx wrangler deploy
```

### Webapp → Cloudflare Pages (free)
Upload `webapp/` folder to Cloudflare Pages dashboard.

### Mobile → App Stores
```bash
flutter build apk    # Android
flutter build ios    # iOS (requires Mac)
```

## Security

- All file chunks encrypted client-side with AES-256-GCM before transmission
- Encryption key derived from session ID via HKDF (QR code IS the shared secret)
- Worker relays raw ciphertext — never sees plaintext
- Sessions expire after 5 minutes, Durable Object self-destructs
- No accounts, no passwords, no data stored on server ever
