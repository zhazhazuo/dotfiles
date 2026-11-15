# ── PERSONAL: machine values ──────────────────────────────────────────
# Loaded by fish conf.d after the shared fragments; the zz- prefix sorts last.
# init.sh links this file from hosts/PERSONAL into fish/conf.d.

# PROXY (the proxy listens on 7897 on this machine)
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export NO_PROXY="*.ts.net,localhost,127.0.0.1,*.local"
export no_proxy="*.ts.net,localhost,127.0.0.1,*.local"

# Confluence
export CONFLUENCE_READ_ONLY=false
export CONFLUENCE_PI_WRITES=true
export CONFLUENCE_PI_WRITE_SPACES=OF

# Pi-MCP-Adapter
export MCP_UI_VIEWER=none
