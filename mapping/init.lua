--- Main mapping library.

local expect = require "cc.expect".expect ---@type fun(arg_n:integer, value:any, ...:string)
local scanners
local file_io = require "mapping.file_io"

---@class MapData
---@field x integer The highest x position of the map. This value is mirrored for the lowest position as well (i.e. the map is from -x to x).
---@field y integer The highest y position of the map. This value is mirrored for the lowest position as well (i.e. the map is from -y to y).
---@field z integer The highest z position of the map. This value is mirrored for the lowest position as well (i.e. the map is from -z to z).
---@field blocks BlockData[][][] The blocks of the map.

---@class BlockData
---@field x integer The x position of the block.
---@field y integer The y position of the block.
---@field z integer The z position of the block.
---@field state BlockState The state of the block.
---@field weight number? The weight of the block, if it is weighted. This should be used if pathfinding is to be used, and can be used to make a block more or less desirable to move through.

---@class Map
---@field name string The name of the map.
---@field data MapData The data of the map.
---@field origin_x integer The x offset of the map. This offset is applied to all operations on the map, so that the map can correspond to real-world coordinates.
---@field origin_y integer The y offset of the map. This offset is applied to all operations on the map, so that the map can correspond to real-world coordinates.
---@field origin_z integer The z offset of the map. This offset is applied to all operations on the map, so that the map can correspond to real-world coordinates.
local map = {
  BlockState = require "mapping.block_state",
  _id = {} -- Identifier object for the map, to ensure methods are called with `:` syntax.
}

local function check_id(self)
  if type(self) ~= "table" or self._id ~= map._id then
    error("Expected to be called on an object using 'obj:method()' syntax.", 3)
  end
end

--- Create a new map object.
---@param name string The name of the map.
---@return Map map The new map.
function map.new(name)
  return setmetatable(
    {
      name = name,
      origin_x = 0,
      origin_y = 0,
      origin_z = 0,
      data = {
        x = 0,
        y = 0,
        z = 0,
        blocks = {}
      }
    },
    { __index = map }
  )
end

--- Load a map from a file. This can either be used to construct a new map, or using an already created map object you can do obj:load("path").
---@param map_object Map|string The map to load data into, or the path to the file.
---@param path string? The path to the file.
---@return Map map The map object with the data loaded.
function map.load(map_object, path)
  if type(map_object) == "string" then
    path = map_object
    map_object = map.new("_")
  else
    expect(1, map_object, "table")
    expect(2, path, "string")
  end
  ---@cast path string

  file_io.load_map(path, map_object)

  return map_object
end

--- Set the size of the map. Loads the map with unknown blocks. Note that this creates a map of from -x to x, and so on, thus the size is essentially double what you put here.
--- WARNING: This wipes any map data in the map, and may take a long while for large maps!
---@param x integer The width/2 of the map.
---@param y integer The height/2 of the map.
---@param z integer The depth/2 of the map.
function map:set_size(x, y, z)
  check_id(self)
  expect(1, x, "number")
  expect(2, y, "number")
  expect(3, z, "number")

  self.data.x = x
  self.data.y = y
  self.data.z = z
  self.data.blocks = {}

  local blocks = self.data.blocks
  local unknown = map.BlockState.UNKNOWN

  for i = -x, x do
    local Xs = {}
    blocks[i] = Xs
    for j = -y, y do
      local Ys = {}
      Xs[j] = Ys
      for k = -z, z do
        Ys[k] = {
          x = i,
          y = j,
          z = k,
          state = unknown
        }
      end
    end
  end
end

--- Set the state of a block.
---@param x integer The x position of the block.
---@param y integer The y position of the block.
---@param z integer The z position of the block.
---@param state BlockState The state of the block.
---@return boolean success Whether the operation was successful.
---@return string? error The error message if the operation was not successful.
function map:set_block(x, y, z, state)
  check_id(self)
  expect(1, x, "number")
  expect(2, y, "number")
  expect(3, z, "number")
  expect(4, state, "number")
  if state ~= 0 and state ~= 1 and state ~= 2 and state ~= 3 then
    error("Invalid state supplied.", 2)
  end

  x = x - self.origin_x
  y = y - self.origin_y
  z = z - self.origin_z

  if x < -self.data.x or x > self.data.x or y < -self.data.y or y > self.data.y or z < -self.data.z or z > self.data.z then
    return false, "Block position out of range."
  end

  self.data.blocks[x][y][z].state = state
  return true
end

--- Set a node run of blocks.
---@param x integer The x position of the start of the run.
---@param y integer The y position of the start of the run.
---@param z integer The z position of the start of the run.
---@param length integer The length of the run.
---@param state BlockState The state of the run.
---@return boolean success Whether the operation was successful. Note that *some* of the run may be set even if this returns false, this just indicates if the entire run was succesful.
---@return string? error The error message if the operation was not successful.
function map:set_run(x, y, z, length, state)
  check_id(self)
  expect(1, x, "number")
  expect(2, y, "number")
  expect(3, z, "number")
  expect(4, length, "number")
  expect(5, state, "number")
  if state ~= 0 and state ~= 1 and state ~= 2 and state ~= 3 then
    error("Invalid state supplied.", 2)
  end

  x = x - self.origin_x
  y = y - self.origin_y
  z = z - self.origin_z

  if x < -self.data.x or x > self.data.x or y < -self.data.y or y > self.data.y or z < -self.data.z or z > self.data.z then
    return false, "Block position out of range."
  end

  local blocks = self.data.blocks

  for i = z, z + length - 1 do
    if i < -self.data.z or i > self.data.z then
      return false, "Block position out of range."
    end
    blocks[x][y][i].state = state
  end

  return true
end

--- Get the block data of a block at the given position.
---@param x integer The x position of the block.
---@param y integer The y position of the block.
---@param z integer The z position of the block.
---@return BlockData block The state of the block.
function map:get_block(x, y, z)
  check_id(self)
  expect(1, x, "number")
  expect(2, y, "number")
  expect(3, z, "number")

  x = x - self.origin_x
  y = y - self.origin_y
  z = z - self.origin_z

  if x < -self.data.x or x > self.data.x or y < -self.data.y or y > self.data.y or z < -self.data.z or z > self.data.z then
    error("Block position out of range.", 2)
  end

  return self.data.blocks[x][y][z]
end

--- Set the offset of the map.
---@param x integer The x offset of the map.
---@param y integer The y offset of the map.
---@param z integer The z offset of the map.
function map:set_origin(x, y, z)
  check_id(self)
  expect(1, x, "number")
  expect(2, y, "number")
  expect(3, z, "number")

  self.origin_x = x
  self.origin_y = y
  self.origin_z = z
end

--- Get the offset of the map.
---@return integer x The x offset of the map.
---@return integer y The y offset of the map.
---@return integer z The z offset of the map.
function map:get_origin()
  check_id(self)
  return self.origin_x, self.origin_y, self.origin_z
end

--- Get the size of the map.
---@return integer x The width of the map.
---@return integer y The height of the map.
---@return integer z The depth of the map.
function map:get_size()
  check_id(self)
  return self.data.x, self.data.y, self.data.z
end

--- Save a map to a file.
---@param path string The path to the file.
function map:save(path)
  check_id(self)
  expect(1, path, "string")

  return file_io.save_map(path, self)
end

--- Scan a map using a scanner.
---@param x integer The x position of the centerpoint of the scan.
---@param y integer The y position of the centerpoint of the scan.
---@param z integer The z position of the centerpoint of the scan.
---@return boolean success Whether the scan was successful.
function map:scan(x, y, z)
  check_id(self)

  if not scanners then
    scanners = require "mapping.scanners"
  end

  return scanners.scan_into(self, x, y, z)
end

--- Get the volume of the map.
---@return integer volume The volume of the map.
function map:volume()
  check_id(self)
  return (self.data.x * 2 + 1) * (self.data.y * 2 + 1) * (self.data.z * 2 + 1)
end

return map