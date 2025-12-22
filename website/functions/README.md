# Cloudflare Pages Functions

This directory contains Pages Functions that run on Cloudflare's edge network.

## _middleware.js

This middleware automatically replaces placeholders in HTML files with real information stored in environment variables.

### Placeholders

- `[NAME_PLACEHOLDER]` → Real name (for legal compliance)
- `[EMAIL_PLACEHOLDER]` → Contact email address
- `[ADDRESS_PLACEHOLDER]` → Physical address

### Setup

1. Go to your Cloudflare Pages project
2. Navigate to **Settings** → **Environment variables**
3. Add the following variables:
   - **Variable name**: `REAL_NAME`
     - **Value**: Your real name (e.g., `山田 太郎`)
     - **Environment**: Production (and Preview if needed)
   - **Variable name**: `REAL_EMAIL`
     - **Value**: Your contact email (e.g., `contact@example.com`)
     - **Environment**: Production (and Preview if needed)
   - **Variable name**: `REAL_ADDRESS`
     - **Value**: Your physical address (e.g., `〒100-0001 東京都千代田区千代田 1-1`)
     - **Environment**: Production (and Preview if needed)
4. Click **Save** and redeploy

### How it works

- Intercepts all HTML responses based on content-type
- Replaces placeholders with corresponding environment variables using regex
- Runs at Cloudflare edge with no build step required
- Keeps personal information private (never committed to source code)
