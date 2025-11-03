# Obsidian MCP Server

A Model Context Protocol (MCP) server for git-backed Obsidian vaults. Access and manage your notes through Claude, ChatGPT, and other LLMs by syncing changes via git.

[![Node.js 22+](https://img.shields.io/badge/node.js-22+-green.svg)](https://nodejs.org/)

## Overview

This MCP server provides **16 tools** and **1 resource** to interact with your Obsidian vault:

**Tools** (organized into 5 categories):

- File Operations (7) - Read, create, edit, delete, move, append, and patch notes
- Directory Operations (3) - Create directories and list files
- Search - Fuzzy search with fuse.js, optional exact matching, and relevance scoring
- Tag Management (4) - Add, remove, rename, and manage tags
- Journal Logging - Auto-log LLM activity to daily journals

**Resources**:

- Vault README - On-demand access to vault organization guidelines and structure

**Deployment Options (all single-user):**

- **Stdio Mode**: Local deployment (e.g., Claude Desktop, Cursor)
- **HTTP Mode**: Local HTTP deployment with OAuth (e.g., local MCP clients)
- **AWS Lambda**: Remote HTTP deployment with OAuth and DynamoDB session persistence (e.g., ChatGPT, remote MCP deployment)

## How It Works

This server is designed for **git-backed Obsidian vaults** managed by plugins like [obsidian-git](https://github.com/Vinzent03/obsidian-git). The workflow:

1. **Pull** - Server clones/pulls your vault from a git repository
2. **Modify** - LLM makes changes through MCP tools (create notes, add tags, etc.)
3. **Push** - Server automatically commits and pushes changes back to git
4. **Sync** - Your Obsidian clients pull changes to reflect updates

This enables LLM access to your vault without Obsidian being open, and keeps all clients synchronized through git.

## Prerequisites

**For Local Deployment:**
- Node.js 22+ and npm, or
- Docker

**For Remote (AWS) Deployment:**
- AWS Account with AWS Lambda access

## Vault Requirements

Before using this server, ensure your Obsidian vault is:

1. **Git-initialized** - Your vault must be a git repository
2. **Pushed to remote** - Hosted on GitHub
3. **Sync-enabled** - We recommend [obsidian-git](https://github.com/Vinzent03/obsidian-git) plugin for automatic sync

The server will clone your vault, make changes, and push them back. Your Obsidian clients should regularly pull to stay in sync.

**Required GitHub Scopes:** Personal Access Token needs `repo` (all)

## Installation & Setup

### Option 1: Using npm

```bash
# Clone and install
git clone https://github.com/eddmann/obsidian-mcp
cd obsidian-mcp
npm install
```

Then configure credentials:

```bash
# Copy example env template
cp .env.example .env

# Edit .env and fill in required fields
```

### Option 2: Using Docker

```bash
# Pull the image
docker pull ghcr.io/eddmann/obsidian-mcp:latest
```

Then configure credentials:

```bash
# Copy example env template
cp .env.example obsidian-mcp.env

# Edit obsidian-mcp.env and fill in required fields
```

## Transport Modes

The server supports two transport modes selected via runtime configuration (stdio is default for local development):

### Stdio Mode (Default)

Uses standard input/output for communication with a single pre-configured vault.

- Authentication: Pre-configured GitHub PAT and vault settings in `.env` file
- Users: Single user per deployment
- Setup: Configure `.env` once, credentials persist across runs
- Token Storage: Local `.env` file
- Best for: Claude Desktop, Cursor, local MCP clients

### HTTP Mode (Streamable HTTP)

Uses HTTP transport with OAuth for secure remote access.

- Authentication: OAuth 2.0 with personal token login (MCP OAuth → Git Access)
- Users: Single user (vault owner) with session-based access
- Setup: Environment-based configuration + OAuth secrets
- Token Storage: In-memory (local HTTP) or DynamoDB (Lambda)
- Session Lifetime: Configurable (default: 24 hours)
- Best for: ChatGPT, Claude web, remote deployments, AWS Lambda

## Claude Desktop Configuration

Add to your configuration file:

- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

### Using npm

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npm",
      "args": [
        "run",
        "--prefix",
        "/ABSOLUTE/PATH/TO/obsidian-mcp",
        "dev"
      ]
    }
  }
}
```

### Using Docker

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-v",
        "/ABSOLUTE/PATH/TO/obsidian-mcp.env:/app/.env",
        "ghcr.io/eddmann/obsidian-mcp:latest",
        "stdio"
      ]
    }
  }
}
```

## ChatGPT Integration & HTTP Mode

### Running in HTTP Mode

Start the server in HTTP mode for remote deployment:

```bash
# Using npm
npm run dev:http

# Using Docker
docker run -p 3000:3000 --rm \
  -v "/ABSOLUTE/PATH/TO/obsidian-mcp.env:/app/.env" \
  ghcr.io/eddmann/obsidian-mcp:latest \
  http
```

Environment variables can be configured in your `.env` file (see Installation & Setup above).

## Usage

Ask your LLM to interact with your Obsidian vault using natural language.

### File Operations

```
"Read my daily note for today"
"Create a new note called 'Meeting Notes' in the Work folder"
"Append my todo list to today's note"
"Add a new section under the '## Ideas' heading in my brainstorm note"
"Move 'draft.md' to the Archive folder"
"Delete my old scratch notes"
```

### Directory Operations

```
"Create a new folder called 'Projects/New Project'"
"List all markdown files in my vault"
"Show me what's in the Archive directory"
```

### Search

```
"Search for all notes mentioning 'machine learning'"
"Find notes with TODO items"
"Search for notes about 'project alpha' and show context"
```

### Tag Management

```
"Add tags #work and #important to my meeting note"
"Remove the #draft tag from all notes"
"Rename the tag #todo to #task across my vault"
"Show me all tags and their usage counts"
```

### Journal Logging

```
"Log this conversation to my journal: we discussed MCP server setup"
"Add a journal entry about today's coding work on the Obsidian project"
```

The journal tool automatically creates/appends to daily journal files with timestamps, activity types, and project linking.

## Available Tools

### File Operations (7 tools)

| Tool             | Description                                                                                   |
| ---------------- | --------------------------------------------------------------------------------------------- |
| `read-note`      | Read the contents of a note file                                                              |
| `create-note`    | Create a new note with content                                                                |
| `edit-note`      | Replace the entire content of a note                                                          |
| `delete-note`    | Delete a note file                                                                            |
| `move-note`      | Move or rename a note                                                                         |
| `append-content` | Append content to an existing or new file                                                     |
| `patch-content`  | Insert content at a specific location (heading, 1-based line number, block, or frontmatter)  |

### Directory Operations (3 tools)

| Tool                  | Description                        |
| --------------------- | ---------------------------------- |
| `create-directory`    | Create a new directory in the vault|
| `list-files-in-vault` | List all files in the vault root   |
| `list-files-in-dir`   | List files in a specific directory |

### Search (1 tool)

| Tool           | Description                                                                    |
| -------------- | ------------------------------------------------------------------------------ |
| `search-vault` | Fuzzy or exact search across vault filenames and content with relevance scoring |

### Tag Management (4 tools)

| Tool          | Description                                     |
| ------------- | ----------------------------------------------- |
| `add-tags`    | Add tags to a note (frontmatter or inline)      |
| `remove-tags` | Remove tags from a note                         |
| `rename-tag`  | Rename a tag across all notes in the vault      |
| `manage-tags` | List, count, or merge tags across the vault     |

### Journal Logging (1 tool)

| Tool                | Description                                      |
| ------------------- | ------------------------------------------------ |
| `log-journal-entry` | Automatically log work to today's journal entry  |

## Available Resources

MCP resources provide contextual information that LLMs can access on-demand without loading the data upfront.

### Vault README

| Resource       | URI                       | Description                                                                                                                                          |
| -------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `vault-readme` | `obsidian://vault-readme` | Provides access to the README.md file from your vault root containing organization guidelines, structure information, and vault-specific conventions |

**Usage**: If your vault contains a README.md file in its root directory, LLMs can access it through this resource to understand how your vault is organized. This helps the LLM make better decisions about where to create files, how to structure notes, and follow your vault's conventions.


## License

MIT
