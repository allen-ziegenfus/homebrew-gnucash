# GnuCash Python bindings for macOS

GnuCash's Python bindings (`import gnucash`) on a Mac, without building
GnuCash yourself.

The official GnuCash.app cannot include them: Apple's notarization will not
let the bundle link a Python from outside it, and Homebrew's `gnucash` cask
is that app. Linux distributions ship them as `python3-gnucash`; this tap is
the macOS equivalent.

```sh
brew install allen-ziegenfus/gnucash/gnucash-python
python3.13 -c "import gnucash"
```

`gnucash-python` builds only the engine library and the bindings
(`WITH_GNUCASH=OFF`): no GUI, no GTK, no WebKit. It reads and writes the same
XML books as the app, through GnuCash's own engine, so a script cannot
produce a file the app will not open. Use the same major version as your app,
and only open a book while the app has it closed.

| formula | GnuCash | Python |
|---|---|---|
| `gnucash-python` | 5.17 | 3.13 |

SQL books (`WITH_SQL`), OFX and AqBanking are off.

### Example

```python
import gnucash._sw_core_utils as cu
from gnucash import Session, SessionOpenMode

cu.gnc_prefs_set_file_save_compressed(True)   # save gzipped, as the app does
with Session("xml:///path/to/book.gnucash", SessionOpenMode.SESSION_NORMAL_OPEN) as s:
    acct = s.book.get_root_account().lookup_by_full_name("Assets:Checking")
    acct.BeginEdit(); acct.SetNotes("closed: 2026-08-07"); acct.CommitEdit()
    s.save()
```

`lookup_by_full_name` uses the book's own account separator, which may be
`.` rather than `:` (Preferences > Accounts).
