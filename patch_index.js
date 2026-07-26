const fs = require('fs');

let html = fs.readFileSync('webapp/index.html', 'utf8');

// Replace CSS
html = html.replace(/#chat-modal \{[\s\S]*?@media \(max-width: 640px\)/m, 
`#chat-modal {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.4);
      backdrop-filter: blur(4px);
      z-index: 99999;
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    .chat-modal-box {
      background: #000000;
      width: 100%;
      max-width: 400px;
      height: 90vh;
      max-height: 600px;
      display: flex;
      flex-direction: column;
      border: 1px solid #2C2C2E;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 20px 40px rgba(0,0,0,0.5);
    }
    .chat-modal-header {
      padding: 16px;
      border-bottom: 1px solid #2C2C2E;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: rgba(18, 18, 18, 0.85);
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
      gap: 12px;
    }
    .chat-modal-messages {
      flex: 1;
      padding: 16px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 12px;
      background: #000000;
    }
    .chat-modal-footer {
      padding: 12px 16px;
      border-top: 1px solid #2C2C2E;
      background: #121212;
      display: flex;
      gap: 10px;
      align-items: center;
      width: 100%;
      box-sizing: border-box;
    }

    @media (max-width: 640px)`);

// Replace HTML
html = html.replace(/<div id="chat-modal">[\s\S]*?<\/div>\s*<\/div>\s*<\/div>\s*<script>/m,
`<div id="chat-modal">
    <div class="chat-modal-box">
      <div class="chat-modal-header">
        <div style="font-family: var(--mono); font-size: 13px; font-weight: 800; color: #FFFFFF; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex-shrink: 1;">[ MESSAGES / CHAT ]</div>
        <button onclick="closeChatModal()" style="background: transparent; border: 1px solid var(--border); color: var(--text-2); padding: 6px 12px; font-size: 11px; font-weight: 800; cursor: pointer; text-transform: uppercase; white-space: nowrap; flex-shrink: 0;">[ CLOSE ]</button>
      </div>
      <div id="chat-modal-messages" class="chat-modal-messages">
        <div id="chat-empty-state" style="margin: auto; color: var(--text-3); font-family: var(--mono); font-size: 12px; text-align: center;">No messages in this session yet.</div>
      </div>
      <div class="chat-modal-footer">
        <textarea id="chat-modal-input" placeholder="Type a message..." style="flex: 1 1 0%; min-width: 0; width: 0; height: 44px; background: var(--surface); border: 1px solid var(--border); padding: 10px 12px; color: var(--text); font-family: var(--mono); font-size: 13px; outline: none; resize: none; border-radius: 0; box-sizing: border-box;" onkeydown="if(event.key==='Enter'&&!event.shiftKey){event.preventDefault();sendModalChatMessage();}"></textarea>
        <button onclick="sendModalChatMessage()" style="flex: 0 0 auto; flex-shrink: 0; background: #FFFFFF; color: #000000; border: 1px solid var(--border); font-family: var(--mono); font-size: 12px; font-weight: 800; padding: 0 14px; height: 44px; cursor: pointer; text-transform: uppercase; margin: 0; border-radius: 0;">[ SEND ]</button>
      </div>
    </div>
  </div>

  <script>`);

// Replace appendChatMessage
html = html.replace(/function appendChatMessage\(sender, text\) \{[\s\S]*?function sendModalChatMessage/m,
`function appendChatMessage(sender, text) {
      const emptyState = document.getElementById('chat-empty-state');
      if (emptyState) emptyState.remove();

      const list = document.getElementById('chat-modal-messages');
      if (!list) return;

      const isMe = sender === 'YOU';
      const wrapper = document.createElement('div');
      wrapper.style.display = 'flex';
      wrapper.style.flexDirection = 'column';
      wrapper.style.alignItems = isMe ? 'flex-end' : 'flex-start';
      wrapper.style.width = '100%';

      const tag = document.createElement('span');
      tag.style.fontFamily = 'var(--mono)';
      tag.style.fontSize = '10px';
      tag.style.color = 'var(--text-3)';
      tag.style.marginBottom = '4px';
      tag.innerText = isMe ? '[ YOU ]' : '[ PEER ]';

      const msgDiv = document.createElement('div');
      msgDiv.style.padding = '10px 14px';
      msgDiv.style.background = isMe ? 'var(--surface-2)' : '#18181B';
      msgDiv.style.border = isMe ? '1px solid var(--border)' : '1px solid #3F3F46';
      msgDiv.style.fontFamily = 'var(--mono)';
      msgDiv.style.fontSize = '13px';
      msgDiv.style.color = '#FFFFFF';
      msgDiv.style.whiteSpace = 'pre-wrap';
      msgDiv.style.maxWidth = '85%';
      msgDiv.style.wordBreak = 'break-word';
      msgDiv.style.borderRadius = '0';
      msgDiv.textContent = text;

      const copyBtn = document.createElement('button');
      copyBtn.innerText = '[ COPY ]';
      copyBtn.style.marginTop = '4px';
      copyBtn.style.background = 'transparent';
      copyBtn.style.border = 'none';
      copyBtn.style.color = 'var(--text-2)';
      copyBtn.style.fontSize = '10px';
      copyBtn.style.fontFamily = 'var(--mono)';
      copyBtn.style.cursor = 'pointer';
      copyBtn.style.padding = '0';
      copyBtn.onclick = (e) => {
        e.stopPropagation();
        navigator.clipboard.writeText(text);
        copyBtn.innerText = '[ COPIED! ]';
        setTimeout(() => { copyBtn.innerText = '[ COPY ]'; }, 1500);
      };

      wrapper.appendChild(tag);
      wrapper.appendChild(msgDiv);
      wrapper.appendChild(copyBtn);
      list.appendChild(wrapper);

      setTimeout(() => {
        list.scrollTo({ top: list.scrollHeight, behavior: 'smooth' });
      }, 50);

      const modal = document.getElementById('chat-modal');
      if (!modal || modal.style.display === 'none') {
        if (!isMe) {
          unreadChatCount++;
          updateChatBadges();
        }
      }
    }

    function sendModalChatMessage`);

fs.writeFileSync('webapp/index.html', html);
