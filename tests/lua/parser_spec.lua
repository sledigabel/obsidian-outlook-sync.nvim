-- Unit tests for parser.lua
-- Tests managed region extraction from markdown buffers

-- Minimal vim shim for tests that need vim.api stubs
if not vim then
  _G.vim = { api = {} }
end

local parser = require('obsidian_outlook_sync.parser')

describe('parser', function()
  describe('find_managed_region', function()
    it('should find markers in buffer', function()
      local lines = {
        '# My Daily Note',
        '',
        'Some content above',
        '<!-- AGENDA_START -->',
        'Event content here',
        '<!-- AGENDA_END -->',
        'Content below'
      }

      local start_line, end_line = parser.find_managed_region(lines)
      assert.equals(4, start_line)
      assert.equals(6, end_line)
    end)

    it('should return nil for missing start marker', function()
      local lines = {
        '# My Daily Note',
        '<!-- AGENDA_END -->',
      }

      local start_line, end_line = parser.find_managed_region(lines)
      assert.is_nil(start_line)
      assert.is_nil(end_line)
    end)

    it('should return nil for missing end marker', function()
      local lines = {
        '<!-- AGENDA_START -->',
        'Content'
      }

      local start_line, end_line = parser.find_managed_region(lines)
      assert.is_nil(start_line)
      assert.is_nil(end_line)
    end)

    it('should only find first pair of markers', function()
      local lines = {
        '<!-- AGENDA_START -->',
        'First region',
        '<!-- AGENDA_END -->',
        'Middle content',
        '<!-- AGENDA_START -->',
        'Second region',
        '<!-- AGENDA_END -->'
      }

      local start_line, end_line = parser.find_managed_region(lines)
      assert.equals(1, start_line)
      assert.equals(3, end_line)
    end)
  end)

  describe('extract_event_with_notes', function()
    it('should extract event ID from marker', function()
      local lines = {
        '<!-- EVENT_ID: event-123 -->',
        '## 09:00-10:00 Team Meeting',
        '**Location:** Room A',
        '<!-- NOTES_START -->',
        'My notes here',
        '<!-- NOTES_END -->',
      }

      local event = parser.extract_event_with_notes(lines, 1, 6)
      assert.equals('event-123', event.id)
      assert.equals(1, event.start_line)
      assert.equals(6, event.end_line)
    end)

    it('should extract notes pocket content', function()
      local lines = {
        '<!-- EVENT_ID: event-456 -->',
        '## 14:00-15:00 Project Review',
        '<!-- NOTES_START -->',
        '- Action item 1',
        '- Action item 2',
        '',
        'Additional context',
        '<!-- NOTES_END -->',
      }

      local event = parser.extract_event_with_notes(lines, 1, 8)
      assert.equals('event-456', event.id)
      assert.is_not_nil(event.notes)
      assert.equals(4, #event.notes)
      assert.equals('- Action item 1', event.notes[1])
      assert.equals('- Action item 2', event.notes[2])
      assert.equals('', event.notes[3])
      assert.equals('Additional context', event.notes[4])
    end)

    it('should handle event without notes pocket', function()
      local lines = {
        '<!-- EVENT_ID: event-789 -->',
        '## 16:00-17:00 Quick Sync',
        '**Location:** Zoom',
      }

      local event = parser.extract_event_with_notes(lines, 1, 3)
      assert.equals('event-789', event.id)
      assert.is_nil(event.notes)
    end)

    it('should handle empty notes pocket', function()
      local lines = {
        '<!-- EVENT_ID: event-empty -->',
        '## 10:00-11:00 Meeting',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      }

      local event = parser.extract_event_with_notes(lines, 1, 4)
      assert.equals('event-empty', event.id)
      assert.is_not_nil(event.notes)
      assert.equals(0, #event.notes)
    end)
  end)

  describe('parse_managed_region_events', function()
    it('should parse multiple events with notes', function()
      local lines = {
        '<!-- AGENDA_START -->',
        '<!-- EVENT_ID: event-1 -->',
        '## 09:00-10:00 Morning Meeting',
        '<!-- NOTES_START -->',
        'Notes for morning meeting',
        '<!-- NOTES_END -->',
        '',
        '<!-- EVENT_ID: event-2 -->',
        '## 14:00-15:00 Afternoon Meeting',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
        '',
        '<!-- EVENT_ID: event-3 -->',
        '## 16:00-17:00 Evening Meeting',
        '<!-- AGENDA_END -->',
      }

      local events = parser.parse_managed_region_events(lines, 1, 15)
      assert.equals(3, #events)

      assert.equals('event-1', events[1].id)
      assert.equals(1, #events[1].notes)
      assert.equals('Notes for morning meeting', events[1].notes[1])

      assert.equals('event-2', events[2].id)
      assert.equals(0, #events[2].notes)

      assert.equals('event-3', events[3].id)
      assert.is_nil(events[3].notes)
    end)
  end)

  describe('parse_event_times', function()
    it('should parse times from timed event header', function()
      local lines = {
        '<!-- EVENT_ID: event-123 -->',
        '## 09:00-10:30 Team Meeting',
        '### Attendees',
      }

      local times = parser.parse_event_times(lines, 1, 3)
      assert.is_not_nil(times)
      assert.equals(9, times.start_hour)
      assert.equals(0, times.start_min)
      assert.equals(10, times.end_hour)
      assert.equals(30, times.end_min)
    end)

    it('should parse times with afternoon hours', function()
      local lines = {
        '<!-- EVENT_ID: event-456 -->',
        '## 14:30-16:00 Project Review',
      }

      local times = parser.parse_event_times(lines, 1, 2)
      assert.is_not_nil(times)
      assert.equals(14, times.start_hour)
      assert.equals(30, times.start_min)
      assert.equals(16, times.end_hour)
      assert.equals(0, times.end_min)
    end)

    it('should return nil for all-day events', function()
      local lines = {
        '<!-- EVENT_ID: event-allday -->',
        '## All Day - Company Holiday',
      }

      local times = parser.parse_event_times(lines, 1, 2)
      assert.is_nil(times)
    end)

    it('should return nil when no header with times exists', function()
      local lines = {
        '<!-- EVENT_ID: event-789 -->',
        '### Attendees',
        'Alice Smith',
      }

      local times = parser.parse_event_times(lines, 1, 3)
      assert.is_nil(times)
    end)

    it('should parse times from header with [deleted] marker', function()
      local lines = {
        '<!-- EVENT_ID: event-deleted -->',
        '## 11:00-12:00 Cancelled Meeting [deleted]',
      }

      local times = parser.parse_event_times(lines, 1, 2)
      assert.is_not_nil(times)
      assert.equals(11, times.start_hour)
      assert.equals(0, times.start_min)
      assert.equals(12, times.end_hour)
      assert.equals(0, times.end_min)
    end)
  end)

  describe('find_notes_line', function()
    it('should find NOTES_START marker line', function()
      local lines = {
        '<!-- EVENT_ID: event-123 -->',
        '## 09:00-10:00 Team Meeting',
        '### Attendees',
        'Alice, Bob',
        '### Notes',
        '<!-- NOTES_START -->',
        'My notes here',
        '<!-- NOTES_END -->',
      }

      local notes_line = parser.find_notes_line(lines, 1, 8)
      assert.equals(6, notes_line)
    end)

    it('should return nil when no NOTES_START marker exists', function()
      local lines = {
        '<!-- EVENT_ID: event-456 -->',
        '## 14:00-15:00 Quick Sync',
        '### Attendees',
      }

      local notes_line = parser.find_notes_line(lines, 1, 3)
      assert.is_nil(notes_line)
    end)

    it('should find notes marker in longer event block', function()
      local lines = {
        '<!-- EVENT_ID: event-789 -->',
        '## 16:00-17:00 Long Meeting',
        '### Agenda',
        '- <auto> Discuss Q4 goals',
        '### Attendees',
        'Alice, Bob, Carol',
        '### Notes',
        '<!-- NOTES_START -->',
        '- Action item 1',
        '- Action item 2',
        '<!-- NOTES_END -->',
      }

      local notes_line = parser.find_notes_line(lines, 1, 11)
      assert.equals(8, notes_line)
    end)
  end)

  describe('extract timestamps', function()
    it('extracts startUnix from TIMESTAMP line', function()
      local line = '<!-- TIMESTAMP: 1748163600 -->'
      local ts = parser.extract_timestamp(line)
      assert.equals(1748163600, ts)
    end)

    it('extracts endUnix from TIMESTAMP_END line', function()
      local line = '<!-- TIMESTAMP_END: 1748165400 -->'
      local ts = parser.extract_timestamp_end(line)
      assert.equals(1748165400, ts)
    end)

    it('returns nil for non-matching line', function()
      assert.is_nil(parser.extract_timestamp('<!-- EVENT_ID: abc -->'))
      assert.is_nil(parser.extract_timestamp_end('<!-- EVENT_ID: abc -->'))
    end)

    it('extract_event_with_notes populates startUnix and endUnix', function()
      local lines = {
        '<!-- EVENT_ID: abc-123 -->',
        '<!-- TIMESTAMP: 1748163600 -->',
        '<!-- TIMESTAMP_END: 1748165400 -->',
        '## 09:00-09:30 Standup',
        '',
        '### Notes',
        '<!-- NOTES_START -->',
        '',
        '<!-- NOTES_END -->',
      }
      local event = parser.extract_event_with_notes(lines, 1, #lines)
      assert.equals('abc-123',    event.id)
      assert.equals(1748163600,   event.startUnix)
      assert.equals(1748165400,   event.endUnix)
    end)
  end)

  describe('get_event_at_cursor', function()
    -- Helper: build a minimal buffer lines table
    local function make_lines(events_block)
      local lines = { '# Daily Note', '', '<!-- AGENDA_START -->' }
      for _, line in ipairs(events_block) do
        table.insert(lines, line)
      end
      table.insert(lines, '<!-- AGENDA_END -->')
      return lines
    end

    -- Stub vim.api so tests don't need a live Neovim instance
    local orig_get_lines
    local orig_get_cursor
    local function stub_vim(lines, cursor_row)
      orig_get_lines  = vim.api.nvim_buf_get_lines
      orig_get_cursor = vim.api.nvim_win_get_cursor
      vim.api.nvim_buf_get_lines  = function() return lines end
      vim.api.nvim_win_get_cursor = function() return { cursor_row, 0 } end
    end
    local function restore_vim()
      vim.api.nvim_buf_get_lines  = orig_get_lines
      vim.api.nvim_win_get_cursor = orig_get_cursor
    end

    after_each(function() restore_vim() end)

    it('returns nil when cursor is outside managed region', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev1 -->',
        '<!-- TIMESTAMP: 1000 -->',
        '<!-- TIMESTAMP_END: 2000 -->',
        '## 09:00-09:30 Standup',
        '### Attendees',
        'Alice',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      stub_vim(lines, 1)   -- line 1 = "# Daily Note", outside region
      local result = parser.get_event_at_cursor(0)
      assert.is_nil(result)
    end)

    it('returns nil when cursor is on AGENDA_START line', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev1 -->',
        '## 09:00-09:30 Standup',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      stub_vim(lines, 3)   -- line 3 = "<!-- AGENDA_START -->"
      local result = parser.get_event_at_cursor(0)
      assert.is_nil(result)
    end)

    it('returns nil when cursor is on AGENDA_END line', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev1 -->',
        '## 09:00-09:30 Standup',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      -- AGENDA_END is last line of make_lines output
      stub_vim(lines, #lines)
      local result = parser.get_event_at_cursor(0)
      assert.is_nil(result)
    end)

    it('returns event when cursor is on EVENT_ID line', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev-abc -->',
        '<!-- TIMESTAMP: 1748163600 -->',
        '<!-- TIMESTAMP_END: 1748165400 -->',
        '## 09:00-09:30 Team Standup',
        '### Attendees',
        'Alice Smith (O)',
        'Bob Jones',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      -- EVENT_ID line is line 4 (after "# Daily Note", "", "<!-- AGENDA_START -->")
      stub_vim(lines, 4)
      local result = parser.get_event_at_cursor(0)
      assert.is_not_nil(result)
      assert.equals('ev-abc', result.id)
      assert.equals('Team Standup', result.title)
      assert.equals(1748163600, result.startUnix)
      assert.equals(1748165400, result.endUnix)
      assert.is_false(result.isAllDay)
      assert.equals(2, #result.attendees)
      assert.equals('Alice Smith (O)', result.attendees[1])
      assert.equals('Bob Jones', result.attendees[2])
    end)

    it('returns event when cursor is inside notes pocket', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev-notes -->',
        '<!-- TIMESTAMP: 1000 -->',
        '<!-- TIMESTAMP_END: 2000 -->',
        '## 10:00-10:30 Review',
        '### Attendees',
        'Carol',
        '### Notes',
        '<!-- NOTES_START -->',
        'my note line',
        '<!-- NOTES_END -->',
      })
      -- 'my note line' is at offset 9 from AGENDA_START (line 3), so line 3+9=12
      stub_vim(lines, 12)
      local result = parser.get_event_at_cursor(0)
      assert.is_not_nil(result)
      assert.equals('ev-notes', result.id)
    end)

    it('returns nil when cursor is between two events', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev1 -->',
        '## 09:00-09:30 First',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
        '',            -- blank separator line between events (offset 6 from AGENDA_START)
        '<!-- EVENT_ID: ev2 -->',
        '## 10:00-10:30 Second',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      -- blank line is at offset 6 from AGENDA_START (line 3), so line 3+6=9
      stub_vim(lines, 9)
      local result = parser.get_event_at_cursor(0)
      assert.is_nil(result)
    end)

    it('selects correct event when multiple events present', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev1 -->',
        '## 09:00-09:30 First',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
        '<!-- EVENT_ID: ev2 -->',
        '## 10:00-10:30 Second',
        '### Attendees',
        'Dave',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      -- ev2 EVENT_ID line is at offset 6 from AGENDA_START → line 3+6=9
      stub_vim(lines, 9)
      local result = parser.get_event_at_cursor(0)
      assert.is_not_nil(result)
      assert.equals('ev2', result.id)
      assert.equals('Second', result.title)
    end)

    it('returns isAllDay=true and nil timestamps for all-day event', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev-allday -->',
        '## All Day - Company Holiday',
        '### Attendees',
        'HR Department (O)',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      stub_vim(lines, 4)  -- cursor on EVENT_ID line
      local result = parser.get_event_at_cursor(0)
      assert.is_not_nil(result)
      assert.is_true(result.isAllDay)
      assert.is_nil(result.startUnix)
      assert.is_nil(result.endUnix)
      assert.equals('Company Holiday', result.title)
    end)

    it('strips [deleted] suffix from title', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev-del -->',
        '## 11:00-12:00 Cancelled Meeting [deleted]',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      stub_vim(lines, 4)
      local result = parser.get_event_at_cursor(0)
      assert.is_not_nil(result)
      assert.equals('Cancelled Meeting', result.title)
    end)

    it('includes ...and N more line in attendees', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev-big -->',
        '## 14:00-15:00 Big Meeting',
        '### Attendees',
        'Alice Smith (O)',
        'Bob Jones',
        '...and 3 more',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      stub_vim(lines, 4)
      local result = parser.get_event_at_cursor(0)
      assert.is_not_nil(result)
      assert.equals(3, #result.attendees)
      assert.equals('...and 3 more', result.attendees[3])
    end)

    it('returns empty attendees when ### Attendees section absent', function()
      local lines = make_lines({
        '<!-- EVENT_ID: ev-noatt -->',
        '## 15:00-15:30 Solo',
        '### Notes',
        '<!-- NOTES_START -->',
        '<!-- NOTES_END -->',
      })
      stub_vim(lines, 4)
      local result = parser.get_event_at_cursor(0)
      assert.is_not_nil(result)
      assert.equals(0, #result.attendees)
    end)
  end)
end)
