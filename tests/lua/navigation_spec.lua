-- Unit tests for navigation.lua
-- Tests time comparison, meeting finding, and navigation logic

local navigation = require('obsidian_outlook_sync.navigation')

describe('navigation', function()
  describe('compare_time', function()
    it('should identify time as current when in range', function()
      -- 10:30 is within 10:00-11:00
      local result = navigation.compare_time(10, 30, 10, 0, 11, 0)
      assert.equals('current', result)
    end)

    it('should identify time as future when before range', function()
      -- 09:30 is before 10:00-11:00
      local result = navigation.compare_time(9, 30, 10, 0, 11, 0)
      assert.equals('future', result)
    end)

    it('should identify time as past when after range', function()
      -- 11:30 is after 10:00-11:00
      local result = navigation.compare_time(11, 30, 10, 0, 11, 0)
      assert.equals('past', result)
    end)

    it('should handle edge case at start boundary (inclusive)', function()
      -- 10:00 is at start of 10:00-11:00
      local result = navigation.compare_time(10, 0, 10, 0, 11, 0)
      assert.equals('current', result)
    end)

    it('should handle edge case at end boundary (exclusive)', function()
      -- 11:00 is at end of 10:00-11:00 (exclusive)
      local result = navigation.compare_time(11, 0, 10, 0, 11, 0)
      assert.equals('past', result)
    end)

    it('should handle meetings spanning across multiple hours', function()
      -- 14:30 is within 13:00-16:00
      local result = navigation.compare_time(14, 30, 13, 0, 16, 0)
      assert.equals('current', result)
    end)
  end)

  describe('find_current_meetings', function()
    it('should find single current meeting', function()
      local events = {
        {times = {start_hour = 9, start_min = 0, end_hour = 10, end_min = 0}},
        {times = {start_hour = 10, start_min = 30, end_hour = 11, end_min = 0}},
        {times = {start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}},
      }
      local current_time = {hour = 10, min = 45}

      local matches = navigation.find_current_meetings(events, current_time)
      assert.equals(1, #matches)
      assert.same({start_hour = 10, start_min = 30, end_hour = 11, end_min = 0}, matches[1].times)
    end)

    it('should find multiple overlapping meetings', function()
      local events = {
        {times = {start_hour = 10, start_min = 0, end_hour = 11, end_min = 0}},
        {times = {start_hour = 10, start_min = 30, end_hour = 11, end_min = 30}},
        {times = {start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}},
      }
      local current_time = {hour = 10, min = 45}

      local matches = navigation.find_current_meetings(events, current_time)
      assert.equals(2, #matches)
    end)

    it('should return empty array when no meetings are current', function()
      local events = {
        {times = {start_hour = 9, start_min = 0, end_hour = 10, end_min = 0}},
        {times = {start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}},
      }
      local current_time = {hour = 11, min = 0}

      local matches = navigation.find_current_meetings(events, current_time)
      assert.equals(0, #matches)
    end)

    it('should skip all-day events (events without times)', function()
      local events = {
        {times = nil},  -- All-day event
        {times = {start_hour = 10, start_min = 0, end_hour = 11, end_min = 0}},
      }
      local current_time = {hour = 10, min = 30}

      local matches = navigation.find_current_meetings(events, current_time)
      assert.equals(1, #matches)
      assert.same({start_hour = 10, start_min = 0, end_hour = 11, end_min = 0}, matches[1].times)
    end)
  end)

  describe('find_next_meeting', function()
    it('should find next upcoming meeting', function()
      local events = {
        {times = {start_hour = 9, start_min = 0, end_hour = 10, end_min = 0}},
        {times = {start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}},
        {times = {start_hour = 16, start_min = 0, end_hour = 17, end_min = 0}},
      }
      local current_time = {hour = 11, min = 0}

      local next = navigation.find_next_meeting(events, current_time)
      assert.is_not_nil(next)
      assert.same({start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}, next.times)
    end)

    it('should find nearest upcoming meeting when multiple future meetings exist', function()
      local events = {
        {times = {start_hour = 9, start_min = 0, end_hour = 10, end_min = 0}},
        {times = {start_hour = 16, start_min = 0, end_hour = 17, end_min = 0}},
        {times = {start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}},
      }
      local current_time = {hour = 11, min = 0}

      local next = navigation.find_next_meeting(events, current_time)
      assert.is_not_nil(next)
      assert.same({start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}, next.times)
    end)

    it('should return nil when no future meetings exist', function()
      local events = {
        {times = {start_hour = 9, start_min = 0, end_hour = 10, end_min = 0}},
        {times = {start_hour = 10, start_min = 0, end_hour = 11, end_min = 0}},
      }
      local current_time = {hour = 15, min = 0}

      local next = navigation.find_next_meeting(events, current_time)
      assert.is_nil(next)
    end)

    it('should skip all-day events', function()
      local events = {
        {times = nil},  -- All-day event
        {times = {start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}},
      }
      local current_time = {hour = 11, min = 0}

      local next = navigation.find_next_meeting(events, current_time)
      assert.is_not_nil(next)
      assert.same({start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}, next.times)
    end)

    it('should skip current meetings and only return future ones', function()
      local events = {
        {times = {start_hour = 9, start_min = 0, end_hour = 10, end_min = 0}},
        {times = {start_hour = 10, start_min = 0, end_hour = 11, end_min = 30}},
        {times = {start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}},
      }
      local current_time = {hour = 10, min = 30}

      local next = navigation.find_next_meeting(events, current_time)
      assert.is_not_nil(next)
      assert.same({start_hour = 14, start_min = 0, end_hour = 15, end_min = 0}, next.times)
    end)
  end)

  describe('parse_subject_from_header', function()
    it('should parse subject from timed event header', function()
      local subject = navigation.parse_subject_from_header('## 09:00-10:00 Team Standup')
      assert.equals('Team Standup', subject)
    end)

    it('should parse subject from all-day event header', function()
      local subject = navigation.parse_subject_from_header('## All Day - Company Holiday')
      assert.equals('Company Holiday', subject)
    end)

    it('should remove [deleted] marker from timed events', function()
      local subject = navigation.parse_subject_from_header('## 09:00-10:00 Team Standup [deleted]')
      assert.equals('Team Standup', subject)
    end)

    it('should remove [deleted] marker from all-day events', function()
      local subject = navigation.parse_subject_from_header('## All Day - Company Holiday [deleted]')
      assert.equals('Company Holiday', subject)
    end)

    it('should handle subjects with multiple words and special characters', function()
      local subject = navigation.parse_subject_from_header('## 14:30-15:00 Q4 Planning: Strategy & OKRs')
      assert.equals('Q4 Planning: Strategy & OKRs', subject)
    end)

    it('should return empty string for malformed headers', function()
      local subject = navigation.parse_subject_from_header('Not a valid header')
      assert.equals('', subject)
    end)
  end)
end)
