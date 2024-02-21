---@diagnostic disable: undefined-global, need-check-nil

local mapping = require "mapping"
local scanners = require "mapping.scanners"

local SAVE_PATH = "Simplify-Mapping/test_map.map"

local X_SIZE = 10
local Y_SIZE = 12
local Z_SIZE = 15

local MAP_NAME = "John"

local map

suite.suite "Scan/Save/Load"
  "Set up scanners" (function()
    local ok, err = scanners.setup()

    if not ok then
      FAIL(err)
    end
  end)
  "Save with scan, no error" (function()
    map = mapping.new(MAP_NAME)
    map:set_size(X_SIZE, Y_SIZE, Z_SIZE)
    map:scan(0, 0, 0)
    EXPECT_NO_THROW(map.save, map, SAVE_PATH)
  end)
  "Load no error" (function()
    EXPECT_NO_THROW(mapping.load, SAVE_PATH)
  end)
  "Load correct name" (function()
    local _map = mapping.load(SAVE_PATH)
    ASSERT_TYPE(_map, "table")
    EXPECT_EQ(_map.name, MAP_NAME)
  end)
  "Load correct size" (function()
    local _map = mapping.load(SAVE_PATH)
    ASSERT_TYPE(_map, "table")
    EXPECT_EQ(_map.data.x, X_SIZE)
    EXPECT_EQ(_map.data.y, Y_SIZE)
    EXPECT_EQ(_map.data.z, Z_SIZE)
  end)
  "Load all blocks equal" (function()
    local _map = mapping.load(SAVE_PATH)
    ASSERT_TYPE(_map, "table")

    local values = 0
    local incorrect_values = 0

    for x = -X_SIZE, X_SIZE do
      for y = -Y_SIZE, Y_SIZE do
        for z = -Z_SIZE, Z_SIZE do
          values = values + 1
          if _map.data.blocks[x][y][z].state ~= map.data.blocks[x][y][z].state then
            print(x, y, z, _map.data.blocks[x][y][z].state, map.data.blocks[x][y][z].state)
          end
          EXPECT_EQ(
            _map.data.blocks[x][y][z].state,
            map.data.blocks[x][y][z].state
          )
          if _map.data.blocks[x][y][z].state ~= map.data.blocks[x][y][z].state then
            incorrect_values = incorrect_values + 1
          end
        end
      end
      sleep()
    end

    print("For map with", values, "blocks:", incorrect_values, "incorrect values.")
    EXPECT_EQ(incorrect_values, 0)
  end)