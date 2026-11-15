# ── Mac: machine values ───────────────────────────────────────────────
# Loaded by fish conf.d after the shared fragments; the zz- prefix sorts last.
# init.sh links this file from hosts/Mac into fish/conf.d.

# PROXY (Clash Verge listens on 7890; 7897 has no listener)
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export NO_PROXY="*.ts.net,localhost,127.0.0.1,*.local"
export no_proxy="*.ts.net,localhost,127.0.0.1,*.local"

# Confluence
export CONFLUENCE_READ_ONLY=false
export CONFLUENCE_PI_WRITES=true
export CONFLUENCE_PI_WRITE_SPACES=OF

# Pi-MCP-Adapter
export MCP_UI_VIEWER=none
