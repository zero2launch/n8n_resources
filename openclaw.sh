#!/bin/bash

# setup-zero2launch.sh - Configure OpenClaw to use Zero2Launch API
# Works on: macOS, Linux, Windows (WSL/Git Bash/MSYS2)
# Usage: ./setup-zero2launch.sh <ZERO2LAUNCH_API_KEY>

set -e

# Check if API key is provided
if [ -z "$1" ]; then
    echo "Error: API key is required"
    echo ""
    echo "Usage: $0 <ZERO2LAUNCH_API_KEY>"
    echo ""
    echo "Get your API key at: https://www.skool.com/z2l-premium-builders-circle-7291"
    exit 1
fi

ZERO2LAUNCH_API_KEY="$1"
CONFIG_DIR="${HOME}/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Define the configuration
# qwen-safety as primary (content moderation & safety)
# Multiple models available as fallbacks and alternatives
NEW_CONFIG=$(cat <<EOF
{
  "env": { "ZERO2LAUNCH_API_KEY": "${ZERO2LAUNCH_API_KEY}" },
  "agents": {
    "defaults": {
      "model": {
        "primary": "zero2launch/qwen-safety",
        "fallbacks": ["zero2launch/openai", "zero2launch/deepseek"]
      },
      "models": {
        "zero2launch/qwen-safety": { "alias": "Qwen Safety (Zero2Launch)" },
        "zero2launch/openai": { "alias": "GPT-5.2 (Zero2Launch)" },
        "zero2launch/openai-fast": { "alias": "o3-mini (Zero2Launch)" },
        "zero2launch/deepseek": { "alias": "DeepSeek V3.1 (Zero2Launch)" },
        "zero2launch/gemini": { "alias": "Gemini 2.5 Flash (Zero2Launch)" },
        "zero2launch/claude-sonnet-4": { "alias": "Claude Sonnet 4 (Zero2Launch)" },
        "zero2launch/gemini-2.5-pro": { "alias": "Gemini 2.5 Pro (Zero2Launch)" }
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "zero2launch": {
        "baseUrl": "https://api.zero2launch.com/v1",
        "apiKey": "\${ZERO2LAUNCH_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "qwen-safety",
            "name": "Qwen Safety — Content moderation & safety checks",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000
          },
          {
            "id": "openai",
            "name": "GPT-5.2 — Flagship OpenAI model",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000
          },
          {
            "id": "openai-fast",
            "name": "o3-mini — Fast reasoning model",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000
          },
          {
            "id": "deepseek",
            "name": "DeepSeek V3.1 — Strong reasoning & tool calling",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000
          },
          {
            "id": "gemini",
            "name": "Gemini 2.5 Flash — Fast multimodal model",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000
          },
          {
            "id": "claude-sonnet-4",
            "name": "Claude Sonnet 4 — Balanced intelligence & speed",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 200000
          },
          {
            "id": "gemini-2.5-pro",
            "name": "Gemini 2.5 Pro — Most intelligent Gemini",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 1000000
          }
        ]
      }
    }
  },
  "tools": {
    "web": {
      "search": {
        "provider": "perplexity",
        "perplexity": {
          "baseUrl": "https://api.zero2launch.com/v1",
          "apiKey": "\${ZERO2LAUNCH_API_KEY}",
          "model": "perplexity-fast"
        }
      }
    }
  }
}
EOF
)

# Require jq for JSON merging
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required. Install it with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

# Merge or create config
if [ -f "$CONFIG_FILE" ]; then
    echo "Merging Zero2Launch config into existing $CONFIG_FILE..."
    EXISTING_CONFIG=$(cat "$CONFIG_FILE")
    MERGED_CONFIG=$(printf '%s\n%s' "$EXISTING_CONFIG" "$NEW_CONFIG" | jq -s '
        def deep_merge(a; b):
            a as $a | b as $b |
            if ($a | type) == "object" and ($b | type) == "object" then
                ($a | keys) + ($b | keys) | unique | map(
                    . as $key |
                    if ($a | has($key)) and ($b | has($key)) then
                        { ($key): deep_merge($a[$key]; $b[$key]) }
                    elif ($b | has($key)) then
                        { ($key): $b[$key] }
                    else
                        { ($key): $a[$key] }
                    end
                ) | add
            else
                $b
            end;
        # If existing config already has a search provider, keep it intact
        .[0] as $old | .[1] as $new |
        (if $old.tools.web.search.provider // null
         then $new | .tools.web.search = $old.tools.web.search
         else $new end) as $adjusted |
        deep_merge($old; $adjusted)
    ')
    printf '%s\n' "$MERGED_CONFIG" > "$CONFIG_FILE"
else
    echo "Creating new config at $CONFIG_FILE..."
    printf '%s\n' "$NEW_CONFIG" | jq '.' > "$CONFIG_FILE"
fi

# Ensure gateway.mode is set (required for fresh installs)
if command -v openclaw >/dev/null 2>&1; then
    CURRENT_MODE=$(openclaw config get gateway.mode 2>/dev/null | grep -o '"[a-z]*"' | tr -d '"' || true)
    if [ -z "$CURRENT_MODE" ] || [ "$CURRENT_MODE" = "null" ]; then
        openclaw config set gateway.mode local >/dev/null 2>&1 || true
    fi
fi

MASKED_KEY="${ZERO2LAUNCH_API_KEY:0:8}...${ZERO2LAUNCH_API_KEY: -4}"

echo ""
echo "🚀 Zero2Launch API configured for OpenClaw!"
echo ""
echo "  Config:  $CONFIG_FILE"
echo "  API Key: $MASKED_KEY"
echo ""
echo "  Primary model: Qwen Safety (content moderation & safety)"
echo "  Fallbacks:     GPT-5.2, DeepSeek V3.1"
echo "  Web search:    Perplexity via Zero2Launch"
echo "  Also available: o3-mini, Gemini 2.5 Flash/Pro, Claude Sonnet 4"
echo ""
echo "  Switch models in chat: /model zero2launch/openai"
echo "  Manage your account:   https://zero2hero.vn"
echo ""
if ! command -v openclaw >/dev/null 2>&1; then
    echo "Next: Install OpenClaw with:"
    echo "  curl -fsSL https://openclaw.ai/install.sh | bash"
else
    echo "Restarting OpenClaw gateway..."
    openclaw gateway restart 2>/dev/null && echo "  ✓ Gateway restarted" || echo "  Run: openclaw gateway restart"
fi
