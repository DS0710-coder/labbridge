const fs = require('fs');

let html = fs.readFileSync('webapp/phone.html', 'utf8');

// Fix 1: Remove duplicate CSS blocks
html = html.replace(/    \.chat-modal-messages \{\n      flex: 1;\n      padding: 16px;\n      overflow-y: auto;\n      display: flex;\n      flex-direction: column;\n      gap: 12px;\n      background: #09090B;\n      -webkit-overflow-scrolling: touch;\n    \}\n    \.chat-modal-footer \{\n      padding: 12px;\n      padding-bottom: max\(12px, env\(safe-area-inset-bottom\)\);\n      border-top: 1px solid var\(--border\);\n      background: var\(--surface-2\);\n      display: flex;\n      gap: 10px;\n      align-items: center;\n      width: 100%;\n      box-sizing: border-box;\n    \}\n/, '');

html = html.replace('    header {', '    .chat-modal-box header {');

// Fix 2: Safari iOS tail clipping fix
html = html.replace(/z-index: -1;\n    \}/, 'z-index: 0;\n    }');
html = html.replace(/margin-left: 6px;\n    \}/, 'margin-left: 6px;\n      overflow: visible;\n    }');
html = html.replace(/justify-content: flex-start;\n    \}/, 'justify-content: flex-start;\n      overflow: visible;\n    }');

// Fix 3: chat-empty-state innerHTML bug
const newClearChat = `function clearChatMessages() {
      unreadChatCount = 0;
      updateChatBadges();
      closeChatModal();
      const list = document.getElementById('chat-modal-messages');
      if (list) {
        const emptyDiv = document.createElement('div');
        emptyDiv.id = 'chat-empty-state';
        emptyDiv.style.cssText = 'margin: auto; color: var(--text-3); font-family: var(--mono); font-size: 12px; text-align: center; padding: 20px;';
        emptyDiv.innerText = 'No messages in this session yet.';
        list.innerHTML = '';
        list.appendChild(emptyDiv);
      }
    }`;
html = html.replace(/function clearChatMessages\(\) \{[\s\S]*?\}\n/, newClearChat + '\n');

// Fix 4: Badge reset race condition
html = html.replace(/const state = \{/, 'const state = {\n      chatModalOpen: false,');
html = html.replace(/function openChatModal\(\) \{/, 'function openChatModal() {\n      state.chatModalOpen = true;');
html = html.replace(/input\.focus\(\);/, "input.focus();\n        input.style.height = '44px';");
html = html.replace(/function closeChatModal\(\) \{/, 'function closeChatModal() {\n      state.chatModalOpen = false;');
html = html.replace(/if \(!modal \|\| modal\.style\.display === 'none'\) \{\n        if \(!isMe\) \{/, 'if (!state.chatModalOpen && !isMe) {\n        if (true) {');

// Fix 5: localStorage key inconsistency
html = html.replace(/const savedUrl = localStorage\.getItem\('cueflex_worker_url'\) \|\| localStorage\.getItem\('cueflex_worker_url'\);/, "const savedUrl = localStorage.getItem('cueflex_worker_url');");
html = html.replace(/localStorage\.setItem\('worker_url', /g, "localStorage.setItem('cueflex_worker_url', ");

// Fix 6: Remove textarea and button inline border-radius 
html = html.replace(/style="flex: 1 1 0%; min-width: 0; width: 0; height: 44px; background: var\(--surface\); border: 1px solid var\(--border\); padding: 10px 12px; color: var\(--text\); font-family: var\(--mono\); font-size: 13px; outline: none; resize: none; border-radius: 0; box-sizing: border-box;"/, 
`style="flex: 1 1 0%; min-width: 0; height: 44px; background: var(--surface); border: 1px solid var(--border); padding: 10px 12px; color: var(--text); font-family: var(--mono); font-size: 13px; outline: none; resize: none; box-sizing: border-box;"`);

html = html.replace(/style="flex: 0 0 auto; flex-shrink: 0; background: #FFFFFF; color: #000000; border: 1px solid var\(--border\); font-family: var\(--mono\); font-size: 12px; font-weight: 800; padding: 0 14px; height: 44px; cursor: pointer; text-transform: uppercase; margin: 0; border-radius: 0;"/, 
`style="flex: 0 0 auto; flex-shrink: 0; background: #FFFFFF; color: #000000; border: 1px solid var(--border); font-family: var(--mono); font-size: 12px; font-weight: 800; padding: 0 14px; height: 44px; cursor: pointer; text-transform: uppercase; margin: 0;"`);

fs.writeFileSync('webapp/phone.html', html);
console.log('done');
