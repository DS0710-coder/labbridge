import re

with open('/home/dev7shah/Desktop/projects/labbridge/webapp/index.html', 'r') as f:
    content = f.read()

# NEW-02: Progress percentage can exceed 100%
content = re.sub(r'const pct = Math\.round\(\(transfer\.sentChunks \/ transfer\.total_chunks\) \* 100\);', 'const pct = Math.min(100, Math.round((transfer.sentChunks / transfer.total_chunks) * 100));', content)
content = re.sub(r'const pct = Math\.round\(\(receivedCount \/ transfer\.total_chunks\) \* 100\);', 'const pct = Math.min(100, Math.round((receivedCount / transfer.total_chunks) * 100));', content)

# NEW-03: Dropped directory silently queues a 0-byte File object
old_queue = """      const validFiles = files.filter(f => {
        if (f.size > 500 * 1024 * 1024) {
          console.warn(`File ${f.name} is too large. Maximum size is 500MB.`);
          alert(`File ${f.name} is too large. Maximum size is 500MB.`);
          return false;
        }
        return true;
      });"""
new_queue = """      const validFiles = files.filter(f => {
        if (!f.type && f.size === 0) {
          alert(`Folders are not supported directly. Please drop individual files or zip the folder.`);
          return false;
        }
        if (f.size > 500 * 1024 * 1024) {
          console.warn(`File ${f.name} is too large. Maximum size is 500MB.`);
          alert(`File ${f.name} is too large. Maximum size is 500MB.`);
          return false;
        }
        return true;
      });"""
content = content.replace(old_queue, new_queue)

# NEW-04: 'paired' message re-derives crypto key and resets UI
old_paired = """        state.cryptoKey = await deriveAESKey(state.sessionId);
        setPhase('paired');
        if (msg.shortcut_mode) {
          document.getElementById('shortcut-mode-hint').style.display = 'block';
        }"""
new_paired = """        if (!state.cryptoKey) {
          state.cryptoKey = await deriveAESKey(state.sessionId);
        }
        if (state.phase !== 'paired' && state.phase !== 'transferring') {
          setPhase('paired');
        }
        if (msg.shortcut_mode) {
          document.getElementById('shortcut-mode-hint').style.display = 'block';
        }"""
content = content.replace(old_paired, new_paired)

# NEW-06: Shortcut mode hint never hidden
old_setphase = """    function setPhase(phase) {
      state.phase = phase;
      document.getElementById('phase-waiting').style.display = (phase === 'waiting') ? 'block' : 'none';
      document.getElementById('phase-paired').style.display = (phase === 'paired') ? 'flex' : 'none';
      document.getElementById('phase-transferring').style.display = (phase === 'transferring') ? 'block' : 'none';
      document.getElementById('phase-done').style.display = (phase === 'done') ? 'block' : 'none';
      if (phase === 'paired') {
        renderSendQueue();
      }
    }"""
new_setphase = """    function setPhase(phase) {
      state.phase = phase;
      document.getElementById('phase-waiting').style.display = (phase === 'waiting') ? 'block' : 'none';
      document.getElementById('phase-paired').style.display = (phase === 'paired') ? 'flex' : 'none';
      document.getElementById('phase-transferring').style.display = (phase === 'transferring') ? 'block' : 'none';
      document.getElementById('phase-done').style.display = (phase === 'done') ? 'block' : 'none';
      if (phase === 'waiting') {
        document.getElementById('shortcut-mode-hint').style.display = 'none';
      }
      if (phase === 'paired') {
        renderSendQueue();
      }
    }"""
content = content.replace(old_setphase, new_setphase)

with open('/home/dev7shah/Desktop/projects/labbridge/webapp/index.html', 'w') as f:
    f.write(content)
