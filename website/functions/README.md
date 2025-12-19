# Cloudflare Pages Functions

This directory contains Pages Functions that run on Cloudflare's edge network.

## _middleware.js

This middleware automatically replaces `[ADDRESS_PLACEHOLDER]` in HTML files with the real address stored in environment variables.

### Setup

1. Go to your Cloudflare Pages project
2. Navigate to **Settings** → **Environment variables**
3. Add a new variable:
   - **Variable name**: `REAL_ADDRESS`
   - **Value**: Your real address (e.g., `〒100-0001 東京都千代田区千代田 1-1`)
   - **Environment**: Production (and Preview if needed)
4. Click **Save** and redeploy

### How it works

- Intercepts all HTML responses based on content-type
- Replaces all occurrences of `[ADDRESS_PLACEHOLDER]` with the real address using regex
- Runs at Cloudflare edge with no build step required
- Keeps your address private (never committed to source code)
