# flutter_lldb_helper.py

## Architecture Metrics
- **Path:** `mobile/ios/Flutter/ephemeral/flutter_lldb_helper.py`
- **Extension:** `.py`
- **Size:** 1276 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 0
- **Out-Degree (Imports):** 0

## Explanation
Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

## Structural Outline
- `handle_new_rx_page`
- `__lldb_init_module`

## Imports (Dependencies)
*No internal imports*

## Imported By (Dependents)
*Not imported by any file*

## Source Code Snippet
```py
#
# Generated file, do not edit.
#

import lldb

def handle_new_rx_page(frame: lldb.SBFrame, bp_loc, extra_args, intern_dict):
    """Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages."""
    base = frame.register["x0"].GetValueAsAddress()
    page_len = frame.register["x1"].GetValueAsUnsigned()

    # Note: NOTIFY_DEBUGGER_ABOUT_RX_PAGES will check contents of the
    # first page to see if handled it correctly. This makes diagnosing
    # misconfiguration (e.g. missing breakpoint) easier.
    data = bytearray(page_len)
    data[0:8] = b'IHELPED!'

    error = lldb.SBError()
    frame.GetThread().GetProcess().WriteMemory(base, data, error)
    if not error.Success():
...
```