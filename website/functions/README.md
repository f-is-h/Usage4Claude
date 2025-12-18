# Cloudflare Pages Functions

This directory contains Pages Functions that run on Cloudflare's edge network.

## _middleware.js

This middleware replaces `[ADDRESS_PLACEHOLDER]` in HTML files with the real address stored in environment variables.

## Setup Environment Variable

1. Go to your Cloudflare Pages project
2. Navigate to **Settings** → **Environment variables**
3. Add a new variable:
   - **Variable name**: `REAL_ADDRESS`
   - **Value**: Your real address (e.g., `〒100-0001 東京都千代田区千代田 1-1`)
   - **Environment**: Production (and Preview if needed)
4. Click **Save**
5. Redeploy your site

## How it works

- Intercepts all HTML responses
- Searches for `[ADDRESS_PLACEHOLDER]` in `<p>`, `<span>`, and `<div>` elements
- Replaces with the value from `REAL_ADDRESS` environment variable
- Runs at edge, no build step needed
- Address never appears in GitHub source code
