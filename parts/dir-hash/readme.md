# para-dir-hash
#
eg:  **`para-dir-hash test_dir [directory]`**

```
[FORMAT: {"formatRev": 1, "style": "TREE", "links": "NOFOLLOW", "filterFilenames": ["__pycache__", ".git", ".DS_Store", "_skip_*"]}]
#
# Review of directory: ./
# Max depth found    : 2
# Filtering filenames: __pycache__, .git, .DS_Store, _skip_*
#
# Style              : Tree
#
# Format         : [attributes] | [hash] [TreePrefix]── [filename]
#                  (Hash has a '*' suffix if error and '?' if not fully reviewed)
#
drwxr-xr-x | dir_ae58f6b09292964163028e3335b6  └── ./
-rw-r--r-- | d41d8cd98f00b204e9800998ecf8427e      ├── blank
drwxr-xr-x | dir__0_entries__________________      ├── empty-ish/
__20666___ | link_ee35e7c782791419f29316f183d      ├── null → /dev/null
lrw-r--r-- | link_ec3a739190c8fef11985de370d5      ├── readme.md → ../readme.md
lrwxr-xr-x | link_3b13b57e111b2471503e23c47a8      └── src → ../src/
```

# Future work #

* Option for following links (with protection against infinite loops)
