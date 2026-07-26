# LabBridge Architecture & Context

## Overview
LabBridge is a secure, low-latency, peer-to-peer file transfer and messaging bridge designed for seamless communication between a PC and a mobile device. It eliminates the need for user accounts, app installations, or cloud storage by leveraging web technologies (WebSockets, Web Crypto API) and edge computing (Cloudflare Workers) to facilitate encrypted data exchange.

The primary use case is transferring photos, documents, and text snippets from a phone to a laptop (or vice versa) as quickly and securely as possible.

## Core Features
- **End-to-End Encryption (E2EE):** All files and text messages are encrypted on the client side using AES-GCM before being transmitted. The server acts purely as a relay and cannot decrypt the contents.
- **Frictionless Pairing:** The PC generates a short-lived session and displays a QR code. The phone scans the QR code to instantly join the session.
- **Chunked File Streaming:** Large files are sliced into small chunks (e.g., 512KB), encrypted, and streamed over the network. The receiver decrypts, buffers, and reassembles the file locally.
- **Resilient Connectivity:** Sessions are persisted via `localStorage`. If a user refreshes the page or their phone temporarily goes to sleep, the devices seamlessly reconnect to the ongoing session.
- **Cross-Platform:** Works natively in modern web browsers (via `index.html` and `phone.html`). It also supports a specialized headless mode for iOS Shortcuts to interact with the relay API.

## Technical Architecture

### 1. Frontend (`webapp/`)
The frontend is built with vanilla HTML, CSS, and JavaScript to remain lightweight and heavily optimized.

- **`index.html` (PC Terminal):**
  - Serves as the dashboard for the PC.
  - Generates the secure Session ID and renders the QR code.
  - Provides a drag-and-drop zone for sending files to the phone.
  - Renders a visually appealing "carousel" interface for viewing multiple received files, complete with photo lightboxes and "Download All" functionality.
  - Houses the unified chat modal for E2EE text messaging.

- **`phone.html` (Mobile Client):**
  - Optimized for mobile viewports.
  - Uses `html5-qrcode` to scan the PC's QR code.
  - Provides a streamlined interface to pick photos or documents from the mobile device.
  - Uploads files in chunks and displays a progress bar.

### 2. Edge Relay (`worker/`)
The backend is built on **Cloudflare Workers** using **Durable Objects**. 
A Durable Object provides a single point of coordination for a specific session, allowing the PC and phone to connect to the exact same edge node.

- **WebSocket Hibernation:** The worker uses the WebSocket Hibernation API. This allows the Durable Object to go to sleep during idle periods (saving costs) while keeping the WebSocket connections alive.
- **Message Routing:** When a chunk or message arrives from one peer, the worker routes it directly to the other peer (`other.send(message)`).
- **Shortcut Buffering:** If an iOS Shortcut is sending/receiving data and cannot maintain a persistent WebSocket, the worker temporarily buffers chunks in the Durable Object's persistent storage until the shortcut polls for them.
- **Limits & Security:** The worker enforces strict rate limits, session TTLs (e.g., 5-minute lifetimes), and maximum transfer limits (e.g., 500MB per file) to prevent abuse and manage resource consumption.

## Security & Encryption Model
1. **Session Generation:** The PC generates a random 12-character alphanumeric Session ID (`s`).
2. **Key Derivation:** Both the PC and Phone use the Web Crypto API's `HKDF` (HMAC-based Extract-and-Expand Key Derivation Function) with SHA-256 to derive a 256-bit AES-GCM key from the Session ID. The salt is a hardcoded project-specific string (e.g., `cueflex-v2`).
3. **Transmission:** 
   - Before sending, the file is sliced. For each chunk, a random 12-byte Initialization Vector (IV) is generated.
   - The chunk is encrypted using AES-GCM.
   - The IV is prepended to the encrypted payload.
   - The binary blob is sent over the WebSocket (which is itself secured via TLS/WSS).
4. **Decryption:** The receiving peer extracts the IV from the first 12 bytes, uses its derived key to decrypt the rest of the payload, and appends the plaintext chunk to a local Blob array.

## User Flow
1. **Initiation:** The user opens LabBridge on their PC. The PC fetches a new Session ID from the Cloudflare Worker and displays it as a QR code.
2. **Pairing:** The user opens the camera on their phone and scans the QR code. The phone navigates to `phone.html?s=[SESSION_ID]`.
3. **Handshake:** The phone connects to the WebSocket. The worker notifies the PC that a peer has joined (`type: "paired"`). Both UIs transition to the "Connected" dashboard.
4. **Data Transfer:**
   - The user selects a file (e.g., on the phone).
   - The phone sends a `transfer_init` JSON message containing the file metadata (name, size, chunk count).
   - The PC prepares a buffer and waits.
   - The phone encrypts and streams chunks sequentially.
   - The PC receives, decrypts, and acknowledges (`ack`) each chunk.
   - Once all chunks arrive, the PC reconstructs the file and presents it in the UI.
5. **Termination:** The session ends when either user clicks "Disconnect," or the 5-minute server-side timer expires. Local storage is cleared, and both devices return to their initial states.
