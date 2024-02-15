---@diagnostic disable: undefined-global, need-check-nil

local mapping = require "mapping"
local BlockState = require "mapping.block_state"

suite.suite "Map"
  "New map" (function()
    local map = mapping.new("John")
    ASSERT_TYPE(map, "table")
  end)
  "Resize map" (function()
    local map = mapping.new("John")
    map:set_size(10, 12, 15)
    ASSERT_EQ(map.data.x, 10)
    ASSERT_EQ(map.data.y, 12)
    ASSERT_EQ(map.data.z, 15)

    -- Ensure that the blocks are initialized.
    EXPECT_NO_THROW(function()
      map.data.blocks[10][12][15].state = 1
      map.data.blocks[-10][-12][-15].state = 1
    end)
  end)
  "Set block" (function()
    local map = mapping.new("John")
    map:set_size(10, 12, 15)
    ASSERT_NO_THROW(map.set_block, map, 0, 0, 0, BlockState.SOLID)
    ASSERT_EQ(map.data.blocks[0][0][0].state, BlockState.SOLID)

    -- and check on each and every block
    for x = -10, 10 do
      for y = -12, 12 do
        for z = -15, 15 do
          map:set_block(x, y, z, BlockState.EMPTY)
          ASSERT_EQ(map.data.blocks[x][y][z].state, BlockState.EMPTY)
        end
      end
    end
  end)
  "Set run" (function()
    local map = mapping.new("John")
    map:set_size(10, 12, 15)
    ASSERT_NO_THROW(map.set_run, map, 0, 0, 0, 5, BlockState.SOLID)
    for z = 0, 4 do
      ASSERT_EQ(map.data.blocks[0][0][z].state, BlockState.SOLID)
    end

    -- and check some random positions on each axis.
    map:set_run(5, 5, 5, 5, BlockState.EMPTY)
    for z = 5, 9 do
      ASSERT_EQ(map.data.blocks[5][5][z].state, BlockState.EMPTY)
    end

    map:set_run(-5, -5, -5, 5, BlockState.SOLID)
    for z = -5, -1 do
      ASSERT_EQ(map.data.blocks[-5][-5][z].state, BlockState.SOLID)
    end

    map:set_run(5, -5, 5, 5, BlockState.SOLID)
    for z = 5, 9 do
      ASSERT_EQ(map.data.blocks[5][-5][z].state, BlockState.SOLID)
    end

    map:set_run(-5, 5, -5, 5, BlockState.EMPTY)
    for z = -5, -1 do
      ASSERT_EQ(map.data.blocks[-5][5][z].state, BlockState.EMPTY)
    end

    map:set_run(5, 5, -5, 5, BlockState.SOLID)
    for z = -5, -1 do
      ASSERT_EQ(map.data.blocks[5][5][z].state, BlockState.SOLID)
    end

    map:set_run(-5, -5, 5, 5, BlockState.EMPTY)
    for z = 5, 9 do
      ASSERT_EQ(map.data.blocks[-5][-5][z].state, BlockState.EMPTY)
    end

    map:set_run(5, -5, -5, 5, BlockState.SOLID)
    for z = -5, -1 do
      ASSERT_EQ(map.data.blocks[5][-5][z].state, BlockState.SOLID)
    end
  end)
  "Get block" (function()
    local map = mapping.new("John")
    map:set_size(10, 12, 15)
    map:set_block(0, 0, 0, BlockState.SOLID)
    local block = map:get_block(0, 0, 0)
    ASSERT_EQ(block.state, BlockState.SOLID)
  end)
  "Get/Set origin" (function()
    local map = mapping.new("John")
    map:set_size(10, 12, 15)
    map:set_origin(5, -6, 7)
    local origin_x, origin_y, origin_z = map:get_origin()
    EXPECT_EQ(origin_x, 5)
    EXPECT_EQ(origin_y, -6)
    EXPECT_EQ(origin_z, 7)
  end)
  "Get/Set block with origin" (function()
    local map = mapping.new("John")
    map:set_size(10, 12, 15)
    map:set_origin(5, -6, 7)

    map:set_block(0, 0, 0, BlockState.SOLID)
    local block = map:get_block(0, 0, 0)
    ASSERT_EQ(block.state, BlockState.SOLID)

    -- And the block should be located at 5, -6, 7
    ASSERT_EQ(map.data.blocks[-5][6][-7].state, BlockState.SOLID)
  end)
  "Get size" (function()
    local map = mapping.new("John")
    map:set_size(10, 12, 15)
    local x, y, z = map:get_size()
    EXPECT_EQ(x, 10)
    EXPECT_EQ(y, 12)
    EXPECT_EQ(z, 15)
  end)
  "Volume" (function()
    local map = mapping.new("John")
    local x, y, z = 10, 12, 15
    map:set_size(x, y, z)
    local volume = map:volume()

    -- We could math it out, but I want to make sure the math is correct in
    -- itself.
    local actual_volume = 0
    for _ = -x, x do
      for _ = -y, y do
        for _ = -z, z do
          actual_volume = actual_volume + 1
        end
      end
    end
    EXPECT_EQ(volume, actual_volume)
  end)