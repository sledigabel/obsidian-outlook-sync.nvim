# Obsidian Outlook Sync Constitution

<!--
╔══════════════════════════════════════════════════════════════════════════════╗
║                          SYNC IMPACT REPORT                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

Version Change: [INITIAL] → 1.0.0

Rationale: This is the initial constitution establishing governance for the
outlook-md (Go CLI) and obsidian-outlook-sync (Neovim plugin) project.
MAJOR version 1.0.0 chosen as this is the foundational ratification.

Modified Principles: N/A (initial creation)

Added Sections:
  - Core Principles (7 principles defined)
  - Security & Compliance
  - Development Workflow
  - Governance

Removed Sections: N/A

Templates Requiring Updates:
  ✅ .specify/templates/plan-template.md
     → Constitution Check section already references constitution file dynamically
  ✅ .specify/templates/spec-template.md
     → Requirements section already supports principle-driven functional requirements
  ✅ .specify/templates/tasks-template.md
     → Task structure supports testability and separation of concerns principles

Follow-up TODOs:
  1. Ratification date set to today (2026-01-07) as initial adoption date
  2. All templates are compatible with defined principles
  3. No command-specific files exist yet (no updates needed)

═════════════════════════════════════════════════════════════════════════════
-->

## Core Principles

### I. Determinism

All outputs from calendar data processing MUST be stable and reproducible. Given identical calendar data and note content, the system MUST produce identical results across runs. Sorting algorithms MUST use explicit, documented comparison rules with well-defined behavior for equal elements. Random number generation, timestamps from system clocks, and non-deterministic hashing MUST NOT influence output structure or content.

**Rationale**: Users must trust that refreshing calendar data will never cause arbitrary or unpredictable changes to their notes. Determinism is essential for debugging, testing, and maintaining user confidence.

### II. Obsidian Safety

The system MUST define and document a clearly bounded managed region within Markdown files (e.g., delimited by comment markers or heading boundaries). All modifications MUST occur exclusively within this managed region. User-authored content outside the managed region MUST remain completely untouched. User-authored notes inside the managed region MUST be preserved according to explicit ownership rules documented in user-facing and developer-facing documentation.

**Rationale**: Users trust the system with their knowledge base. Any system that silently corrupts or erases user work is fundamentally unacceptable and violates user autonomy.

### III. Separation of Concerns

Responsibilities MUST be cleanly partitioned between components:

- **Go CLI (outlook-md)** MUST handle:
  - Microsoft 365 authentication and token management
  - Calendar data retrieval via Microsoft Graph API
  - Emitting machine-readable output (JSON or similar structured format)
  
- **Neovim Plugin (obsidian-outlook-sync)** MUST handle:
  - Parsing existing Markdown note content
  - Merging calendar data with existing note structures
  - Rendering and inserting agenda blocks into notes
  - User interaction and editor integration

The Go CLI MUST NOT implement Markdown parsing, merging logic, or editor-specific features. The Neovim plugin MUST NOT implement authentication, network calls, or calendar API logic. Cross-cutting concerns (e.g., logging formats, data schemas) MUST be explicitly documented at component boundaries.

**Rationale**: Clean separation ensures each component can be developed, tested, and maintained independently. It enables substitution (e.g., replacing the CLI with another calendar source) and prevents tight coupling that leads to fragile systems.

### IV. Security

The following security requirements are NON-NEGOTIABLE:

- Secrets, tokens, API keys, and credentials MUST NEVER be committed to version control
- Authentication tokens MUST be stored with filesystem permissions of 600 (owner read/write only)
- Microsoft Graph API access MUST request the minimum necessary scopes (read-only calendar access)
- Credentials MUST be loaded from secure local storage (e.g., OS keychain, encrypted config files)
- The system MUST document expected permissions and provide clear error messages when permissions are insufficient
- Token refresh logic MUST handle expiration gracefully without exposing sensitive data in logs or error messages

**Rationale**: Calendar data is often sensitive (meeting titles, attendee lists, locations). Any security lapse could expose private information or enable unauthorized access.

### V. Testability

All core logic MUST be structured as pure, testable functions wherever feasible. Side effects (network I/O, file I/O, authentication) MUST be isolated behind interfaces that support mocking or dependency injection. Microsoft Graph API interactions MUST be mockable to enable fast, repeatable tests without network dependencies. Failure modes (network errors, authentication failures, malformed data, parsing errors) MUST be explicitly modeled in code and covered by tests. Test coverage for critical paths (calendar data merging, note preservation logic) MUST be maintained and monitored.

**Rationale**: Untestable code is unmaintainable code. Complex logic for preserving user notes while merging calendar updates requires rigorous testing to prevent data loss.

### VI. Developer Ergonomics

The project MUST provide simple, documented workflows for common tasks:

- **Building**: Single Makefile command (e.g., `make build`) to compile all components
- **Testing**: Single command (e.g., `make test`) to run all test suites
- **Setup**: README with step-by-step setup instructions, including authentication setup
- **Dependencies**: Clear documentation of required tools (Go version, Neovim version, plugin manager)

Documentation MUST include:
- Architecture overview showing component boundaries
- Data flow diagrams (calendar data → CLI → plugin → notes)
- Contribution guidelines

**Rationale**: Lowering the barrier to entry for contributors and users accelerates development, reduces support burden, and fosters a healthy project ecosystem.

### VII. Failure Transparency

Errors MUST be explicit, actionable, and informative. Error messages MUST include:
- What operation failed (e.g., "Failed to retrieve calendar events")
- Why it failed (e.g., "Authentication token expired")
- What the user should do next (e.g., "Run `outlook-md auth` to re-authenticate")

The system MUST NEVER silently corrupt notes on failure. On any error (network failure, parsing error, unexpected data format), the system MUST:
1. Log the error with full context
2. Abort the operation without modifying the note
3. Return a non-zero exit code (CLI) or display an error message (plugin)

Partial updates (e.g., updating half of an agenda block before failing) are PROHIBITED.

**Rationale**: Silent failures and cryptic errors lead to user frustration and data loss. Users must always understand what went wrong and how to fix it. Non-destructive failure modes protect user data integrity.

## Security & Compliance

### Data Handling

- The system MUST operate in read-only mode for calendar data (no write operations to Microsoft 365)
- Calendar data MUST NOT be persisted to disk except in managed regions of user-owned Markdown files
- The system MUST NOT transmit calendar data to any third-party services
- Logs MUST NOT contain authentication tokens, full calendar event details (only metadata for debugging), or user credentials

### Microsoft Graph Scopes

The CLI MUST request only the following Microsoft Graph API scopes:
- `Calendars.Read` (read user calendars)
- `offline_access` (refresh tokens for long-lived sessions)

Additional scopes MUST NOT be requested without explicit user consent and documentation justification.

## Development Workflow

### Build & Test Requirements

- All code changes MUST pass automated tests before merge
- New features MUST include tests demonstrating correct behavior and edge case handling
- Breaking changes to component interfaces (CLI output format, plugin API) MUST be documented and versioned
- The Makefile MUST provide targets for: `build`, `test`, `clean`, `install`
- CI/CD pipelines (if implemented) MUST enforce test passage and linting standards

### Documentation Standards

- README MUST include: project purpose, installation steps, authentication setup, basic usage examples
- Code comments MUST explain non-obvious logic (especially calendar merging rules, note preservation logic)
- API contracts between CLI and plugin MUST be explicitly documented (data schemas, error codes)
- User-facing plugin commands MUST include inline help text

### Review & Merge Process

- Changes affecting note modification logic MUST undergo peer review
- Security-sensitive changes (authentication, credential handling) MUST undergo security-focused review
- All PRs MUST include a description of what changed and why
- Commit messages MUST follow conventional commit format (e.g., `feat:`, `fix:`, `docs:`)

## Governance

### Amendment Procedure

1. Proposed amendments MUST be documented in a PR with clear rationale
2. Amendments affecting core principles (I-VII) require explicit justification for why existing principles are insufficient
3. Amendments MUST include impact analysis on existing templates (.specify/templates/*) and documentation
4. Amendments MUST update the `CONSTITUTION_VERSION` according to semantic versioning rules
5. Amendments MUST update `LAST_AMENDED_DATE` to the date of merge

### Versioning Policy

- **MAJOR** increment: Removal or backward-incompatible redefinition of core principles, fundamental changes to project goals or architecture
- **MINOR** increment: Addition of new principles or sections, material expansion of existing principles with new mandatory requirements
- **PATCH** increment: Clarifications, wording improvements, typo fixes, non-semantic refinements, formatting changes

### Compliance Review

- All implementation plans (`specs/*/plan.md`) MUST include a "Constitution Check" section verifying alignment with principles
- Pull requests introducing new features MUST reference relevant constitutional principles in their description
- Complexity or deviations from principles MUST be explicitly justified in documentation (see plan-template.md "Complexity Tracking" section)
- Quarterly reviews of codebase alignment with constitutional principles are RECOMMENDED

### Runtime Development Guidance

This constitution defines the project's governance and architectural principles. For tactical development guidance, command workflows, and template usage instructions, refer to `.opencode/AGENTS.md` and `.specify/templates/README.md` (if present).

**Version**: 1.0.0 | **Ratified**: 2026-01-07 | **Last Amended**: 2026-01-07
