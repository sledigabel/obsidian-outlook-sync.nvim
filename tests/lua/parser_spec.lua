-- Unit tests for parser.lua
-- Tests managed region extraction from markdown buffers

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
end)
