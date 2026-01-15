# Quickstart Guide: Outlook Calendar Sync

**Feature**: Sync Outlook/M365 calendar events into Obsidian markdown notes via Neovim
**Time to Complete**: ~15 minutes (5 minutes if you already have Azure AD app)
**Difficulty**: Intermediate (requires Azure AD access)

## Prerequisites

Before starting, ensure you have:

- ✅ **Go 1.21+** installed ([download](https://go.dev/dl/))
- ✅ **Neovim 0.5+** installed ([download](https://neovim.io/))
- ✅ **Microsoft 365 or Outlook.com account** with calendar access
- ✅ **Azure AD tenant access** (to register application)
  - Personal Microsoft accounts: Use personal Azure AD tenant
  - Work accounts: May require admin consent (check with IT)
- ✅ **macOS** (for Keychain integration)
  - Linux/Windows: Use environment variables for config (instructions below)

**Optional**:
- `jq` for testing JSON output
- Lazy.nvim or other Neovim plugin manager

## Step 1: Register Azure AD Application (10 minutes)

### 1.1 Navigate to Azure Portal

1. Open [Azure Portal](https://portal.azure.com)
2. Sign in with your Microsoft account
3. Search for "Azure Active Directory" in top search bar
4. Click "App registrations" in left sidebar

### 1.2 Create New Registration

1. Click "+ New registration"
2. Fill in details:
   - **Name**: `outlook-md-cli` (or your preferred name)
   - **Supported account types**: "Accounts in this organizational directory only (Single tenant)"
     - For personal accounts: "Accounts in any organizational directory and personal Microsoft accounts"
   - **Redirect URI**: Select "Public client/native (mobile & desktop)" and enter `http://localhost`
3. Click "Register"

### 1.3 Note Your Credentials

After registration, you'll see the application overview page:

- **Application (client) ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Directory (tenant) ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

**⚠️ IMPORTANT**: Copy both IDs now. You'll need them for configuration.

### 1.4 Grant API Permissions

1. Click "API permissions" in left sidebar
2. Click "+ Add a permission"
3. Select "Microsoft Graph"
4. Select "Delegated permissions"
5. Search and check:
   - `Calendars.Read` (read user calendars)
   - `offline_access` (refresh tokens for long-lived sessions)
6. Click "Add permissions"
7. **If using work account**: Click "Grant admin consent for [Your Org]" (requires admin)
   - If you're not an admin, ask IT to grant consent

**Verification**: You should see both permissions listed with green checkmarks.

## Step 2: Build the CLI (2 minutes)

### 2.1 Clone and Build

```bash
# Clone the repository (or download release binary)
git clone https://github.com/your-username/obsidian-outlook-sync.git
cd obsidian-outlook-sync

# Navigate to CLI directory
cd outlook-md

# Build the binary
make build

# Verify binary exists
ls -lh bin/outlook-md
```

### 2.2 Install to PATH (Optional)

**Option A: System-wide install** (requires sudo):
```bash
sudo make install
# Installs to /usr/local/bin/outlook-md
```

**Option B: User install** (no sudo):
```bash
mkdir -p ~/bin
cp bin/outlook-md ~/bin/
# Add ~/bin to PATH in ~/.zshrc or ~/.bashrc:
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Option C: Use relative path** (no install):
```bash
# Use ./bin/outlook-md or absolute path
```

**Verification**: Run `outlook-md --help` (or `./bin/outlook-md --help`)

## Step 3: Configure Credentials (3 minutes)

### macOS: Store in Keychain (Recommended)

```bash
# Store client ID
security add-generic-password \
  -s com.github.obsidian-outlook-sync \
  -a client-id \
  -w 'YOUR_CLIENT_ID_HERE'

# Store tenant ID
security add-generic-password \
  -s com.github.obsidian-outlook-sync \
  -a tenant-id \
  -w 'YOUR_TENANT_ID_HERE'

# Verify (will prompt for keychain password)
security find-generic-password \
  -s com.github.obsidian-outlook-sync \
  -a client-id -w
```

**Troubleshooting**: If you get "password exists" error, delete first:
```bash
security delete-generic-password -s com.github.obsidian-outlook-sync -a client-id
security delete-generic-password -s com.github.obsidian-outlook-sync -a tenant-id
# Then re-run add commands above
```

### Linux/Windows: Use Environment Variables (Alternative)

```bash
# Add to ~/.bashrc or ~/.zshrc
export OUTLOOK_MD_CLIENT_ID="YOUR_CLIENT_ID_HERE"
export OUTLOOK_MD_TENANT_ID="YOUR_TENANT_ID_HERE"

# Reload shell
source ~/.bashrc  # or ~/.zshrc
```

## Step 4: Authenticate with Microsoft (2 minutes)

### 4.1 Run First-Time Auth

```bash
# Replace America/New_York with your timezone
# See: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
outlook-md today --format json --tz America/New_York
```

**Expected Output** (on stderr):
```
To sign in, use a web browser to open the page https://microsoft.com/devicelogin
and enter the code ABCD1234 to authenticate.
```

### 4.2 Complete Browser Auth

1. Open the URL in your browser: https://microsoft.com/devicelogin
2. Enter the code shown in terminal (e.g., `ABCD1234`)
3. Sign in with your Microsoft account
4. Grant permissions when prompted
5. Return to terminal

**Expected**: CLI now outputs JSON with your calendar events.

### 4.3 Verify Token Cache

```bash
# Check token cache was created
ls -lh ~/.outlook-md/token-cache

# Should show file with permissions: -rw------- (600)
# If permissions are wrong, fix with:
chmod 600 ~/.outlook-md/token-cache
```

**Token Location**: `~/.outlook-md/token-cache`
**Token Expiry**: Access tokens expire after ~1 hour, but CLI auto-refreshes using cached refresh token

### 4.4 Test JSON Output

```bash
# Test with jq (if installed)
outlook-md today --format json --tz America/New_York | jq .version
# Should output: 1

outlook-md today --format json --tz America/New_York | jq '.events | length'
# Should output: number of events today
```

## Step 5: Install Neovim Plugin (5 minutes)

### 5.1 Using Lazy.nvim (Recommended)

Add to your Neovim config (`~/.config/nvim/lua/plugins/outlook-sync.lua` or `init.lua`):

```lua
return {
  'your-github-username/obsidian-outlook-sync',
  config = function()
    require('obsidian_outlook_sync').setup({
      -- Path to CLI binary (default: searches PATH)
      cli_path = 'outlook-md',  -- or absolute path: '/usr/local/bin/outlook-md'

      -- Your IANA timezone
      timezone = 'America/New_York',  -- Change this!

      -- CLI timeout (milliseconds)
      timeout = 30000,  -- 30 seconds

      -- Custom markers (optional, defaults shown)
      markers = {
        agenda_start = '<!-- AGENDA_START -->',
        agenda_end = '<!-- AGENDA_END -->',
        event_id = '<!-- EVENT_ID: %s -->',
        notes_start = '<!-- NOTES_START -->',
        notes_end = '<!-- NOTES_END -->'
      },

      -- Custom error handler (optional)
      on_error = function(err)
        vim.notify(err, vim.log.levels.ERROR)
      end
    })
  end
}
```

**Important**: Change `timezone` to your actual timezone!

### 5.2 Using vim-plug

Add to `~/.config/nvim/init.vim`:

```vim
Plug 'your-github-username/obsidian-outlook-sync'

" After plug#end(), add:
lua << EOF
require('obsidian_outlook_sync').setup({
  timezone = 'America/New_York'  -- Change this!
})
EOF
```

### 5.3 Restart Neovim and Install

```vim
:Lazy sync         " (Lazy.nvim)
" OR
:PlugInstall       " (vim-plug)
```

### 5.4 Verify Installation

```vim
:checkhealth obsidian_outlook_sync
```

**Expected**: All checks pass (CLI found, config valid, auth working)

## Step 6: Use the Plugin (2 minutes)

### 6.1 Create Test Note

Open or create an Obsidian note in Neovim:

```bash
nvim ~/Documents/Obsidian/daily-note.md
```

### 6.2 Add Agenda Markers

Insert these lines anywhere in your note:

```markdown
# My Daily Note

Some content here...

<!-- AGENDA_START -->
<!-- AGENDA_END -->

More content below...
```

### 6.3 Run Sync Command

In Neovim normal mode:

```vim
:OutlookAgendaToday
```

**Expected Result**: Your events appear between the markers!

**Example Output**:
```markdown
<!-- AGENDA_START -->
- **09:00–09:30** Team Standup (Conference Room A)
  <!-- EVENT_ID: AAMkAGI2THVSAAA= -->
  <!-- NOTES_START -->
  - Agenda:
    - <auto> **09:00–09:30** Team Standup (Conference Room A)
  - Organizer:
    - <auto> Alice Smith <alice@example.com>
  - Invitees:
    - <auto> Bob Jones <bob@example.com> (required)
    - <auto> Carol White <carol@example.com> (optional)
  - Notes:
    -
  <!-- NOTES_END -->

- **14:00–15:00** Product Review
  <!-- EVENT_ID: AAMkAGI2PRODREV= -->
  <!-- NOTES_START -->
  - Agenda:
    - <auto> **14:00–15:00** Product Review
  - Organizer:
    - <auto> David Lee <david@example.com>
  - Invitees:
    - <auto> (No attendees)
  - Notes:
    -
  <!-- NOTES_END -->
<!-- AGENDA_END -->
```

### 6.4 Add Your Notes

Edit the "Notes:" section under any event:

```markdown
  - Notes:
    - Discussed Q1 roadmap
    - ACTION: Follow up with Bob on API design
    - Next steps: Review design doc by Friday
```

### 6.5 Refresh (Test Preservation)

Run `:OutlookAgendaToday` again.

**Expected**: Your notes are preserved exactly as written!

## Verification Checklist

- [ ] CLI runs and outputs JSON (`outlook-md today --format json --tz <YOUR_TZ> | jq .version` shows `1`)
- [ ] Token cache exists at `~/.outlook-md/token-cache` with permissions `600`
- [ ] Plugin installed (`:checkhealth obsidian_outlook_sync` passes)
- [ ] Events appear in note after running `:OutlookAgendaToday`
- [ ] User notes preserved after second sync
- [ ] Content outside `<!-- AGENDA_START/END -->` unchanged

## Common Issues

### Issue: "CLI not found in PATH"

**Solution**:
1. Verify binary exists: `ls -lh bin/outlook-md`
2. Check PATH: `echo $PATH`
3. Either install to PATH directory or use absolute path in plugin config:
   ```lua
   cli_path = '/Users/you/obsidian-outlook-sync/outlook-md/bin/outlook-md'
   ```

### Issue: "Authentication token expired"

**Symptoms**: CLI returns error after not being used for days/weeks

**Solution**:
```bash
# Clear token cache
rm ~/.outlook-md/token-cache

# Re-authenticate
outlook-md today --format json --tz America/New_York
# Follow device code flow again
```

### Issue: "Missing Keychain entries" (macOS)

**Solution**:
```bash
# Verify credentials are stored
security find-generic-password -s com.github.obsidian-outlook-sync -a client-id -w
security find-generic-password -s com.github.obsidian-outlook-sync -a tenant-id -w

# If missing, re-add (see Step 3)
```

### Issue: "API permissions not granted"

**Symptoms**: CLI returns "Access denied" or "Insufficient privileges"

**Solution**:
1. Return to Azure Portal → Your app → API permissions
2. Verify `Calendars.Read` and `offline_access` are listed
3. If work account, click "Grant admin consent"
4. Clear token cache and re-authenticate

### Issue: Events don't appear or are cut off

**Check**:
1. Verify timezone is correct in plugin config
2. Check CLI output directly:
   ```bash
   outlook-md today --format json --tz YOUR_TZ | jq .
   ```
3. Verify events exist in time window queried
4. Check Neovim messages: `:messages`

### Issue: "Request failed with status 429" (Rate limited)

**Solution**: Wait 60 seconds and retry. Microsoft Graph has rate limits (~5000 requests/hour).

## Next Steps

### Map a Keybinding (Optional)

Add to Neovim config:

```lua
-- Map <leader>oa to sync agenda
vim.keymap.set('n', '<leader>oa', ':OutlookAgendaToday<CR>', { desc = 'Sync Outlook agenda' })
```

### Auto-sync on File Open (Optional, Advanced)

⚠️ **Warning**: This triggers network requests on every file open. Use with caution.

```lua
vim.api.nvim_create_autocmd('BufReadPost', {
  pattern = '*.md',
  callback = function()
    -- Only auto-sync files in daily notes directory
    local filepath = vim.fn.expand('%:p')
    if string.match(filepath, 'daily%-notes') then
      vim.cmd('OutlookAgendaToday')
    end
  end
})
```

### Create Daily Note Template

Create `~/Documents/Obsidian/templates/daily.md`:

```markdown
# {{date:YYYY-MM-DD}}

## Morning Review
- [ ] Check calendar
- [ ] Review yesterday's notes

## Calendar
<!-- AGENDA_START -->
<!-- AGENDA_END -->

## Notes

## End of Day
- [ ] Update calendar notes
- [ ] Plan tomorrow
```

Then use Templater or manual copy to create daily notes.

## Uninstall (If Needed)

### Remove CLI

```bash
# If installed system-wide
sudo rm /usr/local/bin/outlook-md

# If installed to ~/bin
rm ~/bin/outlook-md

# Remove token cache
rm -rf ~/.outlook-md

# Remove Keychain entries (macOS)
security delete-generic-password -s com.github.obsidian-outlook-sync -a client-id
security delete-generic-password -s com.github.obsidian-outlook-sync -a tenant-id
```

### Remove Plugin

Remove plugin entry from Neovim config, then:

```vim
:Lazy clean         " (Lazy.nvim)
" OR
:PlugClean          " (vim-plug)
```

### Revoke Azure AD App

1. Azure Portal → Azure Active Directory → App registrations
2. Find your app (`outlook-md-cli`)
3. Click "Delete"
4. Confirm deletion

## Support

- **Issues**: https://github.com/your-username/obsidian-outlook-sync/issues
- **Discussions**: https://github.com/your-username/obsidian-outlook-sync/discussions
- **Documentation**: See README.md in repository

## Security Notes

- **Token cache** contains sensitive access tokens. Never commit to git. Permissions are automatically set to `600` (owner only).
- **Keychain entries** store client/tenant IDs. These are less sensitive than tokens but still should not be shared publicly.
- **API permissions** are read-only (`Calendars.Read`). This tool cannot modify your calendar.
- **Device code flow** means no passwords are ever entered in the CLI. You authenticate via browser.

## License

[Your license here]

---

**Congratulations!** You can now sync your Outlook calendar into Obsidian notes while preserving your meeting notes. Happy note-taking! 🎉