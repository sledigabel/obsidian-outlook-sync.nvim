-- Unit tests for renderer.lua
-- Tests event rendering to markdown format

local renderer = require('obsidian_outlook_sync.renderer')

describe('renderer', function()
  describe('render_event', function()
    it('should render basic event with time', function()
      local event = {
        id = 'test-1',
        subject = 'Team Standup',
        isAllDay = false,
        start = '2026-01-07T09:00:00',
        ['end'] = '2026-01-07T09:30:00',
        location = 'Conference Room A',
        organizer = {
          name = 'Alice Smith',
          email = 'alice@example.com'
        },
        attendees = {
          { name = 'Bob Jones', email = 'bob@example.com', type = 'required' }
        }
      }

      local lines = renderer.render_event(event)

      -- Should have header line with time and subject
      assert.is_not_nil(lines[1])
      assert.matches('09:00%-09:30', lines[1])
      assert.matches('Team Standup', lines[1])

      -- Should include location
      local content = table.concat(lines, '\n')
      assert.matches('Conference Room A', content)
    end)

    it('should render all-day event', function()
      local event = {
        id = 'test-allday',
        subject = 'Company Holiday',
        isAllDay = true,
        start = '2026-01-01T00:00:00',
        ['end'] = '2026-01-02T00:00:00',
        location = '',
        organizer = {
          name = 'HR Department',
          email = 'hr@example.com'
        },
        attendees = {}
      }

      local lines = renderer.render_event(event)

      -- Should indicate all-day event
      local header = lines[1]
      assert.matches('All Day', header)
      assert.matches('Company Holiday', header)
    end)

    it('should render event with no location', function()
      local event = {
        id = 'test-no-location',
        subject = 'Virtual Meeting',
        isAllDay = false,
        start = '2026-01-07T14:00:00',
        ['end'] = '2026-01-07T15:00:00',
        location = '',
        organizer = {
          name = 'Jane Doe',
          email = 'jane@example.com'
        },
        attendees = {}
      }

      local lines = renderer.render_event(event)

      -- Should render without location field
      local content = table.concat(lines, '\n')
      assert.matches('Virtual Meeting', content)
      -- Should not have empty location line
      assert.is_not.matches('Location:%s*$', content)
    end)

    it('should render untitled event', function()
      local event = {
        id = 'test-untitled',
        subject = '',
        isAllDay = false,
        start = '2026-01-07T16:00:00',
        ['end'] = '2026-01-07T16:30:00',
        location = '',
        organizer = {
          name = '',
          email = ''
        },
        attendees = {}
      }

      local lines = renderer.render_event(event)

      -- Should show placeholder for empty subject
      local header = lines[1]
      assert.matches('%(Untitled Event%)', header)
    end)

    it('should render multiple attendees', function()
      local event = {
        id = 'test-attendees',
        subject = 'Planning Meeting',
        isAllDay = false,
        start = '2026-01-07T10:00:00',
        ['end'] = '2026-01-07T11:00:00',
        location = 'Room 101',
        organizer = {
          name = 'Project Manager',
          email = 'pm@example.com'
        },
        attendees = {
          { name = 'Alice', email = 'alice@example.com', type = 'required' },
          { name = 'Bob', email = 'bob@example.com', type = 'required' },
          { name = 'Charlie', email = 'charlie@example.com', type = 'optional' }
        }
      }

      local lines = renderer.render_event(event)
      local content = table.concat(lines, '\n')

      -- Should list attendees
      assert.matches('Alice', content)
      assert.matches('Bob', content)
      assert.matches('Charlie', content)
    end)
  end)

  describe('render_events', function()
    it('should render empty events list', function()
      local events = {}
      local lines = renderer.render_events(events)

      -- Should return empty list or placeholder
      assert.is_not_nil(lines)
      assert.equals('table', type(lines))
    end)

    it('should render multiple events in order', function()
      local events = {
        {
          id = 'event-1',
          subject = 'Morning Meeting',
          isAllDay = false,
          start = '2026-01-07T09:00:00',
          ['end'] = '2026-01-07T09:30:00',
          location = '',
          organizer = { name = 'Alice', email = 'alice@example.com' },
          attendees = {}
        },
        {
          id = 'event-2',
          subject = 'Lunch',
          isAllDay = false,
          start = '2026-01-07T12:00:00',
          ['end'] = '2026-01-07T13:00:00',
          location = 'Cafeteria',
          organizer = { name = 'Bob', email = 'bob@example.com' },
          attendees = {}
        }
      }

      local lines = renderer.render_events(events)
      local content = table.concat(lines, '\n')

      -- Both events should appear
      assert.matches('Morning Meeting', content)
      assert.matches('Lunch', content)

      -- Morning Meeting should appear before Lunch (chronological order)
      local morning_pos = content:find('Morning Meeting')
      local lunch_pos = content:find('Lunch')
      assert.is_true(morning_pos < lunch_pos)
    end)
  end)
end)
