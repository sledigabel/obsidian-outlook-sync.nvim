-- Unit tests for merger.lua
-- Tests event merging and notes preservation logic

local merger = require('obsidian_outlook_sync.merger')

describe('merger', function()
  describe('is_meaningful_notes', function()
    it('should return false for empty notes', function()
      local notes = {}
      assert.is_false(merger.is_meaningful_notes(notes))
    end)

    it('should return false for only blank lines', function()
      local notes = {'', '  ', '\t'}
      assert.is_false(merger.is_meaningful_notes(notes))
    end)

    it('should return false for only section headers', function()
      local notes = {'### Agenda', '### Notes'}
      assert.is_false(merger.is_meaningful_notes(notes))
    end)

    it('should return false for only scaffold content', function()
      local notes = {
        '- <auto> Added to calendar',
        '- <auto> Reminder set'
      }
      assert.is_false(merger.is_meaningful_notes(notes))
    end)

    it('should return true for user-written content', function()
      local notes = {'- My action item'}
      assert.is_true(merger.is_meaningful_notes(notes))
    end)

    it('should return true for mixed content with at least one meaningful line', function()
      local notes = {
        '',
        '### Agenda',
        '- <auto> Created',
        '- User-written note',
        ''
      }
      assert.is_true(merger.is_meaningful_notes(notes))
    end)
  end)

  describe('merge_events', function()
    it('should preserve notes for existing events', function()
      local old_events = {
        {
          id = 'event-1',
          notes = {'My important notes'}
        }
      }

      local new_events = {
        {id = 'event-1', subject = 'Team Meeting'}
      }

      local merged = merger.merge_events(old_events, new_events)
      assert.equals(1, #merged)
      assert.equals('event-1', merged[1].id)
      assert.equals('Team Meeting', merged[1].subject)
      assert.is_not_nil(merged[1].notes)
      assert.equals('My important notes', merged[1].notes[1])
    end)

    it('should add new events without notes', function()
      local old_events = {}

      local new_events = {
        {id = 'event-new', subject = 'New Meeting'}
      }

      local merged = merger.merge_events(old_events, new_events)
      assert.equals(1, #merged)
      assert.equals('event-new', merged[1].id)
      assert.is_nil(merged[1].notes)
    end)

    it('should retain deleted events with meaningful notes', function()
      local old_events = {
        {
          id = 'event-deleted',
          subject = 'Cancelled Meeting',
          notes = {'Important context about cancellation'}
        }
      }

      local new_events = {}

      local merged = merger.merge_events(old_events, new_events)
      assert.equals(1, #merged)
      assert.equals('event-deleted', merged[1].id)
      assert.is_true(merged[1].deleted)
      assert.equals('Important context about cancellation', merged[1].notes[1])
    end)

    it('should remove deleted events without meaningful notes', function()
      local old_events = {
        {
          id = 'event-deleted',
          subject = 'Cancelled Meeting',
          notes = {'- <auto> Created'}
        }
      }

      local new_events = {}

      local merged = merger.merge_events(old_events, new_events)
      assert.equals(0, #merged)
    end)

    it('should handle complex merge scenario', function()
      local old_events = {
        {id = 'event-1', notes = {'Keep these notes'}},
        {id = 'event-2', notes = {'- <auto> No meaningful notes'}},
        {id = 'event-3', notes = {'Important notes'}},
      }

      local new_events = {
        {id = 'event-1', subject = 'Updated Meeting 1'},
        {id = 'event-4', subject = 'New Meeting 4'},
      }

      local merged = merger.merge_events(old_events, new_events)

      -- Should have: event-1 (updated), event-3 (deleted with notes), event-4 (new)
      -- event-2 is deleted without meaningful notes, so removed
      assert.equals(3, #merged)

      -- Find each event
      local e1, e3, e4
      for _, e in ipairs(merged) do
        if e.id == 'event-1' then e1 = e end
        if e.id == 'event-3' then e3 = e end
        if e.id == 'event-4' then e4 = e end
      end

      assert.is_not_nil(e1)
      assert.equals('Updated Meeting 1', e1.subject)
      assert.equals('Keep these notes', e1.notes[1])
      assert.is_false(e1.deleted or false)

      assert.is_not_nil(e3)
      assert.is_true(e3.deleted)
      assert.equals('Important notes', e3.notes[1])

      assert.is_not_nil(e4)
      assert.equals('New Meeting 4', e4.subject)
      assert.is_nil(e4.notes)
      assert.is_false(e4.deleted or false)
    end)
  end)
end)
