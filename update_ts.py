import json

def update_file(html_path, ts_path, var_name):
    with open(html_path, 'r', encoding='utf-8') as f:
        html = f.read()
    
    ts_content = f"export const {var_name} = {json.dumps(html)};\n"
    
    with open(ts_path, 'w', encoding='utf-8') as f:
        f.write(ts_content)

update_file('webapp/index.html', 'worker/src/index_html.ts', 'INDEX_HTML')
update_file('webapp/phone.html', 'worker/src/phone_html.ts', 'PHONE_HTML')
