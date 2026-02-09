The latest release is **<tag>** [Git hash: <git_hash>]
<!-- markdown-link-check-disable-next-line -->
1. Download from: **[<full_pkg_name>.deb](<package_download_url>)**
2. Install with: **`sudo dpkg -i <full_pkg_name>.deb`**

If you'd like to live life on the edge, you can do this with a single command:
```bash
deb_name="$(mktemp --suffix=.deb)" && \
wget      -O "$deb_name" <package_download_url> && \
sudo dpkg -i "$deb_name"
```
