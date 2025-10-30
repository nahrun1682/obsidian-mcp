# Multi-stage build for minimal final image
FROM node:22-slim AS builder

WORKDIR /build

# Copy workspace files
COPY package.json package-lock.json ./
COPY tsconfig.base.json ./
COPY packages/app/package.json ./packages/app/

# Install dependencies
RUN npm ci --workspace @obsidian-mcp/app --include-workspace-root

# Copy source code and build configuration
COPY packages/app/src ./packages/app/src
COPY packages/app/tsconfig.json ./packages/app/

# Build both stdio and http bundles
RUN npm run build:stdio --workspace @obsidian-mcp/app && \
    npm run build:http --workspace @obsidian-mcp/app

# Runtime stage - minimal Node.js image
FROM node:22-slim

WORKDIR /app

# Install git (required for simple-git operations at runtime)
RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy built bundles from builder
COPY --from=builder /build/packages/app/dist/stdio/index.js ./dist/stdio/index.js
COPY --from=builder /build/packages/app/dist/http/index.js ./dist/http/index.js

# Create entrypoint script inline
RUN cat > /app/entrypoint.sh <<'EOF'
#!/bin/sh
set -e

# Default mode is stdio if no argument provided
MODE="${1:-stdio}"

case "$MODE" in
  stdio)
    echo "Starting Obsidian MCP Server in stdio mode..."
    exec node dist/stdio/index.js
    ;;
  http)
    echo "Starting Obsidian MCP Server in http mode..."
    exec node dist/http/index.js
    ;;
  *)
    echo "Error: Invalid mode '$MODE'. Use 'stdio' or 'http'."
    echo "Usage: docker run ... obsidian-mcp [stdio|http]"
    echo "  stdio (default) - Run in stdio mode for local MCP clients"
    echo "  http            - Run in HTTP mode on port 3000"
    exit 1
    ;;
esac
EOF

RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV NODE_ENV=production \
    NODE_OPTIONS="--no-warnings" \
    LOCAL_VAULT_PATH=/app/vaults/vault-local

# Create directory for git clones (vault storage)
RUN mkdir -p /app/vaults

# Expose port for HTTP mode (used when running with 'http' argument)
EXPOSE 3000

# Use custom entrypoint script to handle mode selection
# Defaults to stdio mode
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["stdio"]
