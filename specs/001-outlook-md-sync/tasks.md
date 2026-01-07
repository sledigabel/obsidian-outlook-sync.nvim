# Tasks: Outlook Calendar Sync to Obsidian Markdown

**Input**: Design documents from `/specs/001-outlook-md-sync/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-plugin-v1.json

**Tests**: Tests are included based on FR-047 to FR-054 (8 specific test requirements)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

Per plan.md project structure:
- **Go CLI**: `outlook-md/` (cmd/, internal/, pkg/)
- **Neovim Plugin**: `lua/obsidian_outlook_sync/`
- **Tests**: `tests/go/` and `tests/lua/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure for both CLI and plugin components

- [X] T001 Create Go CLI project structure: outlook-md/{cmd/outlook-md,internal/{auth,calendar,output,config},pkg/schema}/
- [X] T002 Create Neovim plugin structure: lua/obsidian_outlook_sync/{init,cli,parser,merger,renderer,config}.lua
- [X] T003 [P] Initialize Go module in outlook-md/go.mod with Go 1.21+
- [X] T004 [P] Create Makefile at repository root with build, test, clean, install targets
- [X] T005 [P] Create .gitignore with bin/, ~/.outlook-md/token-cache, *.log entries
- [X] T006 [P] Create test directories: tests/{go/{auth,calendar,output},lua/}
- [X] T007 [P] Create contracts directory: specs/001-outlook-md-sync/contracts/ (already exists)
- [X] T008 [P] Create testdata directory for test fixtures: tests/go/testdata/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T009 Define JSON schema types in outlook-md/pkg/schema/v1.go (CLIOutput, CalendarEvent, Organizer, Attendee)
- [X] T010 [P] Implement configuration loading in outlook-md/internal/config/config.go (Keychain lookup, env var fallback)
- [X] T011 [P] Create GraphClient interface in outlook-md/internal/calendar/client.go (for mockability per research.md)
- [X] T012 [P] Create test fixtures in tests/go/testdata/: calendar_response_{empty,single,many,allday}.json
- [X] T013 [P] Implement schema validation helper in tests/go/schema_test.go for JSON contract tests

**Checkpoint**: ✅ Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Initial Calendar Sync (Priority: P1) 🎯 MVP

**Goal**: Fetch today's calendar events from Outlook/M365 and display them in Obsidian note managed region

**Independent Test**: Run `:OutlookAgendaToday` in Neovim with markdown file containing `<!-- AGENDA_START -->` and `<!-- AGENDA_END -->` markers, verify calendar events appear

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T014 [P] [US1] Unit test for JSON output formatting in tests/go/output/formatter_test.go
- [X] T015 [P] [US1] Unit test for markdown parser in tests/lua/parser_spec.lua (extract managed region)
- [X] T016 [P] [US1] Unit test for event renderer in tests/lua/renderer_spec.lua (basic event formatting)
- [X] T017 [P] [US1] Integration test with mocked Graph API in tests/go/calendar/client_test.go

### Implementation for User Story 1 - CLI Component

- [X] T018 [P] [US1] Implement CLI entry point in outlook-md/cmd/outlook-md/main.go (command routing, flag parsing)
- [X] T019 [P] [US1] Implement "today" command handler in outlook-md/cmd/outlook-md/main.go (calculate 00:00-24:00 window)
- [X] T020 [US1] Implement GraphClient HTTP implementation in outlook-md/internal/calendar/client.go (HTTP calls to /me/calendarView)
- [X] T021 [US1] Implement event fetching in outlook-md/internal/calendar/events.go (parse Graph API response to CalendarEvent)
- [X] T022 [US1] Implement JSON formatter in outlook-md/internal/output/formatter.go (serialize CLIOutput to stdout)
- [X] T023 [US1] Add error handling: write errors to stderr, return non-zero exit codes per FR-009/FR-010

### Implementation for User Story 1 - Plugin Component

- [X] T024 [P] [US1] Implement plugin initialization in lua/obsidian_outlook_sync/init.lua (setup function, command registration)
- [X] T025 [P] [US1] Implement buffer parser in lua/obsidian_outlook_sync/parser.lua (find AGENDA_START/END markers)
- [X] T026 [US1] Implement CLI invocation in lua/obsidian_outlook_sync/cli.lua (subprocess call, capture stdout/stderr)
- [X] T027 [US1] Implement basic event renderer in lua/obsidian_outlook_sync/renderer.lua (format events as markdown headers)
- [X] T028 [US1] Implement atomic buffer replacement in lua/obsidian_outlook_sync/parser.lua (nvim_buf_set_lines)
- [X] T029 [US1] Implement :OutlookAgendaToday command handler (orchestrate: parse → CLI call → render → replace)
- [X] T030 [US1] Add error handling: display CLI stderr if non-zero exit code per FR-029

**Checkpoint**: At this point, basic calendar sync should work end-to-end (fetch events, display in note)

---

## Phase 4: User Story 2 - Preserve User Notes on Refresh (Priority: P1) 🎯 MVP

**Goal**: Preserve user-added notes when refreshing agenda, handle deleted events intelligently

**Independent Test**: Add custom content between `<!-- NOTES_START -->` and `<!-- NOTES_END -->` markers, run `:OutlookAgendaToday` again, verify content unchanged

### Tests for User Story 2

- [ ] T031 [P] [US2] Unit test for notes pocket extraction in tests/lua/parser_spec.lua
- [ ] T032 [P] [US2] Unit test for meaningful notes detection in tests/lua/merger_spec.lua
- [ ] T033 [P] [US2] Unit test for event merging logic in tests/lua/merger_spec.lua (preserve notes, match by EVENT_ID)
- [ ] T034 [P] [US2] Integration test for deleted event retention in tests/lua/merger_spec.lua

### Implementation for User Story 2

- [ ] T035 [P] [US2] Extend parser to extract EVENT_ID markers in lua/obsidian_outlook_sync/parser.lua
- [ ] T036 [P] [US2] Extend parser to extract NOTES_START/END pockets in lua/obsidian_outlook_sync/parser.lua
- [ ] T037 [US2] Implement event merger in lua/obsidian_outlook_sync/merger.lua (match old/new events by EVENT_ID)
- [ ] T038 [US2] Implement meaningful notes detection in lua/obsidian_outlook_sync/merger.lua (per FR-025 algorithm)
- [ ] T039 [US2] Implement deleted event handling in lua/obsidian_outlook_sync/merger.lua (keep if meaningful, remove if not)
- [ ] T040 [US2] Extend renderer to preserve notes pockets verbatim in lua/obsidian_outlook_sync/renderer.lua
- [ ] T041 [US2] Extend renderer to add [deleted] marker for retained deleted events in lua/obsidian_outlook_sync/renderer.lua
- [ ] T042 [US2] Update :OutlookAgendaToday command to use merger before renderer

**Checkpoint**: At this point, User Story 1 AND 2 should both work (initial sync + notes preservation)

---

## Phase 5: User Story 3 - First-Time Authentication (Priority: P2)

**Goal**: Enable device-code flow authentication for first-time users

**Independent Test**: Run `outlook-md today --format json --tz America/New_York` without tokens, complete browser auth, verify JSON output

### Tests for User Story 3

- [ ] T043 [P] [US3] Unit test for device code flow initiation in tests/go/auth/device_flow_test.go
- [ ] T044 [P] [US3] Unit test for token caching in tests/go/auth/token_cache_test.go
- [ ] T045 [P] [US3] Unit test for token refresh in tests/go/auth/token_cache_test.go

### Implementation for User Story 3

- [ ] T046 [P] [US3] Implement device code flow in outlook-md/internal/auth/device_flow.go (using golang.org/x/oauth2)
- [ ] T047 [P] [US3] Implement token cache in outlook-md/internal/auth/token_cache.go (save/load ~/.outlook-md/token-cache)
- [ ] T048 [US3] Set file permissions to 0600 on token cache write per FR-007/FR-039
- [ ] T049 [US3] Implement TokenSource wrapper for automatic refresh in outlook-md/internal/auth/device_flow.go
- [ ] T050 [US3] Integrate auth into CLI main: check cache → device flow if missing → pass TokenSource to GraphClient
- [ ] T051 [US3] Add stderr output for device code URL and instructions per acceptance scenario

**Checkpoint**: Authentication flow complete - users can authenticate from scratch

---

## Phase 6: User Story 4 - Attendee Information Display (Priority: P2)

**Goal**: Display organizer and attendee information for each event with deterministic ordering and truncation

**Independent Test**: Sync events with various attendee counts, verify formatting/ordering/truncation per FR-026/FR-027

### Tests for User Story 4

- [ ] T052 [P] [US4] Unit test for attendee sorting in tests/go/calendar/events_test.go (deterministic multi-key sort)
- [ ] T053 [P] [US4] Unit test for attendee truncation in tests/lua/renderer_spec.lua (>15 attendees → "…and N more")
- [ ] T054 [P] [US4] Unit test for organizer rendering in tests/lua/renderer_spec.lua

### Implementation for User Story 4

- [ ] T055 [P] [US4] Implement attendee sorting in outlook-md/internal/calendar/events.go (sort.SliceStable with multi-key comparator per research.md)
- [ ] T056 [US4] Apply sorting to attendees during CalendarEvent creation in outlook-md/internal/calendar/events.go
- [ ] T057 [US4] Extend renderer to generate Organizer section in lua/obsidian_outlook_sync/renderer.lua (per FR-036)
- [ ] T058 [US4] Extend renderer to generate Invitees section in lua/obsidian_outlook_sync/renderer.lua (per FR-037)
- [ ] T059 [US4] Implement attendee truncation logic in lua/obsidian_outlook_sync/renderer.lua (first 15 + summary line per FR-027/FR-038)
- [ ] T060 [US4] Add scaffold sections to new event template: Agenda, Organizer, Invitees, Notes per FR-034

**Checkpoint**: Full event details now displayed (subject, time, location, organizer, attendees)

---

## Phase 7: User Story 5 - Secure Configuration Management (Priority: P3)

**Goal**: Store client ID and tenant ID in macOS Keychain instead of plaintext config

**Independent Test**: Store credentials in Keychain using `security` commands, verify CLI retrieves them successfully

### Tests for User Story 5

- [ ] T061 [P] [US5] Unit test for Keychain lookup in tests/go/config/config_test.go (mock `security` command execution)
- [ ] T062 [P] [US5] Unit test for env var fallback in tests/go/config/config_test.go

### Implementation for User Story 5

- [ ] T063 [P] [US5] Implement Keychain lookup via `security` CLI in outlook-md/internal/config/keychain_darwin.go
- [ ] T064 [US5] Update config loading to prioritize Keychain over env vars in outlook-md/internal/config/config.go
- [ ] T065 [US5] Add clear error messages for missing Keychain entries per acceptance scenarios
- [ ] T066 [US5] Add clear error messages for Keychain access denied per acceptance scenarios

**Checkpoint**: Configuration securely managed via Keychain on macOS

---

## Phase 8: User Story 6 - Custom Time Range Queries (Priority: P3)

**Goal**: Support querying events for custom date ranges beyond "today"

**Independent Test**: Run `outlook-md range <START> <END> --format json --tz <TZ>`, verify events within range returned

### Tests for User Story 6

- [ ] T067 [P] [US6] Unit test for RFC3339 timestamp parsing in tests/go/calendar/events_test.go
- [ ] T068 [P] [US6] Integration test for multi-day range query in tests/go/calendar/client_test.go

### Implementation for User Story 6

- [ ] T069 [P] [US6] Implement "range" command handler in outlook-md/cmd/outlook-md/main.go (parse startRFC3339, endRFC3339 args)
- [ ] T070 [US6] Add RFC3339 timestamp validation in outlook-md/cmd/outlook-md/main.go
- [ ] T071 [US6] Extend GraphClient to accept custom time window in outlook-md/internal/calendar/client.go
- [ ] T072 [US6] Update CLI output to reflect custom window in JSON per CLI-Plugin contract

**Checkpoint**: All user stories complete - CLI and plugin feature-complete

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, documentation, and final integration

### Additional Testing (FR-047 to FR-054)

- [ ] T073 [P] Unit test for managed region parsing in tests/lua/parser_spec.lua (various marker positions, multiple regions)
- [ ] T074 [P] Unit test for meaningful-notes detection edge cases in tests/lua/merger_spec.lua (only whitespace, only headers, mixed)
- [ ] T075 [P] Unit test for deterministic rendering in tests/lua/renderer_spec.lua (same input → same output)
- [ ] T076 [P] Contract test for JSON schema validation in tests/go/schema_test.go (version check, required fields, forward compat)
- [ ] T077 [P] Integration test with mocked Graph responses for all scenarios in tests/go/calendar/client_test.go (empty, single, many, all-day events)

### Documentation & Build

- [ ] T078 [P] Create README.md at repository root with Azure AD setup, build instructions, Keychain config (per FR-055 to FR-064)
- [ ] T079 [P] Create Vim help doc in obsidian-outlook-sync/doc/obsidian-outlook-sync.txt
- [ ] T080 [P] Add Makefile target `make test` that runs both Go and Lua tests
- [ ] T081 [P] Add Makefile target `make build` that compiles CLI to ./bin/outlook-md
- [ ] T082 [P] Add Makefile target `make install` that copies binary to /usr/local/bin (optional)
- [ ] T083 [P] Add quickstart example to README showing Lazy.nvim plugin spec per FR-061

### Edge Cases & Error Handling

- [ ] T084 [P] Handle missing AGENDA_START/END markers gracefully in lua/obsidian_outlook_sync/parser.lua
- [ ] T085 [P] Handle CLI not found in PATH gracefully in lua/obsidian_outlook_sync/cli.lua
- [ ] T086 [P] Handle network failures with clear error messages in outlook-md/internal/calendar/client.go
- [ ] T087 [P] Handle token refresh failures with re-auth instructions in outlook-md/internal/auth/device_flow.go
- [ ] T088 [P] Handle unsupported JSON schema versions in lua/obsidian_outlook_sync/cli.lua
- [ ] T089 [P] Handle events with no subject (render as "(Untitled Event)") in lua/obsidian_outlook_sync/renderer.lua
- [ ] T090 [P] Handle all-day events (render as "**All Day**: Subject") in lua/obsidian_outlook_sync/renderer.lua

### Configuration & Customization

- [ ] T091 [P] Implement plugin configuration in lua/obsidian_outlook_sync/config.lua (cli_path, timezone, markers, timeout)
- [ ] T092 [P] Add marker customization support in lua/obsidian_outlook_sync/parser.lua (read from config)
- [ ] T093 [P] Add CLI path customization in lua/obsidian_outlook_sync/cli.lua (read from config or search PATH)
- [ ] T094 [P] Add timeout handling for CLI subprocess in lua/obsidian_outlook_sync/cli.lua (30s default per quickstart.md)

### Final Integration & Validation

- [ ] T095 Validate quickstart.md end-to-end: Azure AD setup → CLI build → Keychain → plugin install → first sync
- [ ] T096 Run all tests (`make test`) and ensure 100% pass rate for critical paths (merge logic, notes detection, attendee ordering)
- [ ] T097 Verify constitution compliance: determinism (T075), Obsidian safety (buffer never modified outside region), separation of concerns
- [ ] T098 Performance validation: CLI fetch < 3s, plugin render < 2s, end-to-end < 10s per SC-001/SC-006

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed) or sequentially by priority
  - US1 + US2 are P1 (MVP) - MUST be completed first
  - US3 + US4 are P2 - Should be completed second
  - US5 + US6 are P3 - Can be deferred or implemented later
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - Extends US1 (requires US1 parser/renderer)
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - Independent (auth is separate from sync logic)
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - Extends US1 (requires renderer)
- **User Story 5 (P3)**: Can start after US3 (requires auth flow) - Independent
- **User Story 6 (P3)**: Can start after US1 (extends CLI commands) - Independent

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- CLI components before plugin components (plugin depends on CLI output)
- Parser before merger before renderer (data flow)
- Core implementation before error handling
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T003-T008)
- All Foundational tasks marked [P] can run in parallel (T010-T013)
- Within US1: CLI tasks (T018-T023) and plugin tasks (T024-T030) can proceed in parallel by different developers
- US3 (auth) and US4 (attendees) are fully independent and can run in parallel
- US5 (Keychain) and US6 (range queries) are independent and can run in parallel
- All Polish tasks marked [P] can run in parallel (T073-T094)

---

## Parallel Example: User Story 1 (MVP Implementation)

**Assumption**: 2 developers (Dev A = CLI, Dev B = Plugin)

```bash
# Phase 1: Setup (Both developers)
Dev A & Dev B: T001-T008 in parallel (30 min)

# Phase 2: Foundational (Both developers)
Dev A: T009, T011, T012         # Schema, interface, test fixtures
Dev B: T013                      # Schema validation helper
(20 min in parallel)

# Phase 3: User Story 1 Tests (Both developers)
Dev A: T014, T017                # CLI tests
Dev B: T015, T016                # Plugin tests
(15 min in parallel, tests should FAIL)

# Phase 3: User Story 1 Implementation
Dev A: T018-T023                 # CLI implementation (60 min)
Dev B: T024-T030                 # Plugin implementation (60 min)
(In parallel!)

# Total time for MVP (US1): ~2.5 hours with 2 developers
# Sequential time: ~3.5 hours with 1 developer
```

---

## Suggested MVP Scope

**Minimum Viable Product**: User Stories 1 + 2 (Priority P1)

**Why this scope**:
- US1: Core functionality (fetch and display calendar events)
- US2: Critical for usability (preserve user notes, handle deleted events)
- Together deliver complete value: users can see agenda AND take notes safely

**Tasks for MVP**: T001-T042 (42 tasks)

**Estimated effort**:
- With 2 developers (1 CLI, 1 Plugin): ~1 week
- With 1 developer: ~2 weeks

**Deferrable to post-MVP**:
- US3 (Auth): Can use manual token file or env vars initially
- US4 (Attendees): Basic event display is functional without attendee details
- US5 (Keychain): Config can use env vars initially
- US6 (Range queries): "today" command is sufficient for most users

---

## Task Count Summary

- **Phase 1 (Setup)**: 8 tasks (T001-T008)
- **Phase 2 (Foundational)**: 5 tasks (T009-T013)
- **Phase 3 (US1)**: 17 tasks (T014-T030)
- **Phase 4 (US2)**: 12 tasks (T031-T042)
- **Phase 5 (US3)**: 9 tasks (T043-T051)
- **Phase 6 (US4)**: 9 tasks (T052-T060)
- **Phase 7 (US5)**: 6 tasks (T061-T066)
- **Phase 8 (US6)**: 6 tasks (T067-T072)
- **Phase 9 (Polish)**: 26 tasks (T073-T098)

**Total**: 98 tasks

**MVP (US1+US2)**: 42 tasks
**Full Feature (all 6 user stories)**: 72 tasks (before polish)
**With Polish**: 98 tasks

---

## Format Validation ✅

All tasks follow the required checklist format:
- ✅ Checkbox: All tasks start with `- [ ]`
- ✅ Task ID: Sequential T001-T098
- ✅ [P] marker: Present for all parallelizable tasks
- ✅ [Story] label: Present for all user story phase tasks (US1-US6)
- ✅ File paths: Included in all implementation task descriptions
- ✅ Clear actions: Each task has specific, actionable description

Tasks are immediately executable by an LLM with provided context from design documents.