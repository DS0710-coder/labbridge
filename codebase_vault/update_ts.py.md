# update_ts.py

## Architecture Metrics
- **Path:** `update_ts.py`
- **Extension:** `.py`
- **Size:** 513 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 0
- **Out-Degree (Imports):** 0

## Explanation
*No explanation provided in source code.*

## Structural Outline
- `update_file`

## Imports (Dependencies)
*No internal imports*

## Imported By (Dependents)
*Not imported by any file*

## Source Code Snippet
```py
import json

def update_file(file_path, ts_path, var_name):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    ts_content = f"export const {var_name} = {json.dumps(content)};\n"
    
    with open(ts_path, 'w', encoding='utf-8') as f:
        f.write(ts_content)

update_file('webapp/index.html', 'worker/src/index_html.ts', 'INDEX_HTML')
update_file('webapp/phone.html', 'worker/src/phone_html.ts', 'PHONE_HTML')
update_file('webapp/sw.js', 'worker/src/sw_js.ts', 'SW_JS')
```