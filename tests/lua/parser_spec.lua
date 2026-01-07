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
end)
