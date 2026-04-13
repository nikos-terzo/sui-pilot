#!/usr/bin/env bash
#
# sui-pilot setup script
# Installs all dependencies required for the Claude Code plugin
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "========================================"
echo "  sui-pilot Plugin Setup"
echo "========================================"
echo ""

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -ge 18 ]; then
        log_success "Node.js $(node --version) found"
    else
        log_error "Node.js 18+ required, found $(node --version)"
        exit 1
    fi
else
    log_error "Node.js not found. Please install Node.js 18+"
    exit 1
fi

# Check pnpm
if command -v pnpm &> /dev/null; then
    log_success "pnpm $(pnpm --version) found"
else
    log_warn "pnpm not found, installing..."
    npm install -g pnpm
    log_success "pnpm installed"
fi

# Check Rust/Cargo (needed for move-analyzer)
if command -v cargo &> /dev/null; then
    log_success "Cargo $(cargo --version | cut -d' ' -f2) found"
    RUST_AVAILABLE=true
else
    log_warn "Rust/Cargo not found. move-analyzer requires Rust."
    log_warn "Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    RUST_AVAILABLE=false
fi

# Build MCP server
echo ""
log_info "Building MCP server..."
cd "$PLUGIN_ROOT/mcp/move-lsp-mcp"

if [ ! -d "node_modules" ]; then
    pnpm install
fi

pnpm build
log_success "MCP server built"

# Run tests
echo ""
log_info "Running tests..."
pnpm test 2>&1 | tail -5
log_success "Tests passed"

# Check/Install move-analyzer
echo ""
if command -v move-analyzer &> /dev/null; then
    log_success "move-analyzer found at $(which move-analyzer)"
else
    if [ "$RUST_AVAILABLE" = true ]; then
        log_warn "move-analyzer not found"
        echo ""
        read -p "Install move-analyzer now? (takes ~2-3 minutes) [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing move-analyzer from MystenLabs/sui (this may take 5-10 minutes)..."
            cargo install --git https://github.com/MystenLabs/sui.git --branch main sui-move-lsp
            log_success "move-analyzer installed"
        else
            log_warn "Skipped move-analyzer installation"
            log_warn "LSP tools will return errors until move-analyzer is installed"
            echo ""
            echo "To install later:"
            echo "  cargo install --git https://github.com/MystenLabs/sui.git --branch main sui-move-lsp"
        fi
    else
        log_warn "Cannot install move-analyzer without Rust"
        log_warn "LSP tools will return errors until move-analyzer is installed"
    fi
fi

# Summary
echo ""
echo "========================================"
echo "  Setup Complete"
echo "========================================"
echo ""
log_info "Plugin location: $PLUGIN_ROOT"
log_info "MCP server: $PLUGIN_ROOT/mcp/move-lsp-mcp/dist/index.js"
echo ""

if command -v move-analyzer &> /dev/null; then
    log_success "All LSP features available"
else
    log_warn "LSP features require move-analyzer"
    echo "  Install: cargo install --git https://github.com/movebit/move-analyzer.git --branch sui-move-analyzer"
fi

echo ""
echo "Next steps:"
echo "  1. Restart Claude Code to load the MCP server"
echo "  2. Try: /sui-pilot or /move-code-quality"
echo ""
