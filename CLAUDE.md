# obsidian-outlook-sync.nvim Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-21

## Active Technologies

- Lua (Neovim plugin)
- Go (CLI binary for Microsoft Graph API)
- Microsoft Graph API (calendar access)

## Project Structure

```text
lua/obsidian_outlook_sync/
  - init.lua              # Plugin initialization & command registration
  - commands.lua          # Command handlers
  - parser.lua            # Buffer parsing & managed regions
  - cli.lua               # CLI invocation
  - navigation.lua        # Meeting navigation & cursor positioning
  - renderer.lua          # Markdown rendering
outlook-md/               # Go CLI binary
  - cmd/outlook-md/       # CLI entry point
  - internal/             # Internal packages (calendar, auth, config)
  - pkg/schema/           # JSON schema (CLI ↔ Plugin contract)
tests/
  - lua/                  # Lua unit tests (busted)
  - go/                   # Go tests
```

## Commands

### Calendar Sync Commands
- `:OutlookAgendaToday` - Sync today's calendar events (00:00-24:00)
- `:OutlookAgendaTomorrow` - Sync tomorrow's calendar events
- `:OutlookAgendaWeek` - Sync this week's calendar events (Monday-Sunday)

### Navigation Commands
- `:OutlookJumpToCurrentNotes` - Jump to notes section of current or next meeting

## Code Style

- **Lua**: Follow standard Neovim plugin conventions
- **Go**: Follow standard Go conventions (gofmt, golint)
- **Tests**: Use busted for Lua, standard Go testing for Go

## Recent Changes

- 2026-01-21: Added OutlookJumpToCurrentNotes command with smart navigation to current/next meeting notes
- 2026-01-07: Added 001-outlook-md-sync feature

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
