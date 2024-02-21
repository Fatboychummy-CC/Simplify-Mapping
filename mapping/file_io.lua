--- Small library for saving a map to a file and loading a map from a file.
--- Saves in a binary format, as CC has a limited "disk drive" size.

local expect = require("cc.expect").expect ---@type fun(arg_n:integer, value:any, ...:string)

local BlockState = require("mapping.block_state")

local CURRENT_SAVE_VERSION = 1

local file_io = {}

--- Save a map to a file.
---@param path string The path to the file.
---@param map Map The map to save.
---@return boolean success Whether the save was successful.
---@return string? error The error message if the save failed.
function file_io.save_map(path, map)
  expect(1, path, "string")
  expect(2, map, "table")

  -- Header: "CCSMAP"
  -- Then 2 bytes for version (currently 1)
  -- Then 2 bytes for flags
  -- 2 bytes for the length of the map name
  -- Then the map name
  -- Then 6 bytes for the total amount of node runs
  -- then 3 to 6 bytes for the size of the map in each dimension (one or two
  --  bytes each, will need to calculate if one or two is needed, and set the
  --  appropriate flag if so.)

  local flags = 0
  local size_flag = false
  if map.data.x > 127 or map.data.y > 127 or map.data.z > 127 then
    size_flag = true
    flags = bit32.bor(flags, 1)
  end

  -- Parse the input into node runs.
  local node_runs = {}
  local num_runs = 0

  local unknown = BlockState.UNKNOWN

  -- O(n) where n is the number of blocks.
  for x = -map.data.x, map.data.x do
    local Xs = map.data.blocks[x]
    for y = -map.data.y, map.data.y do
      local Ys = Xs[y]
      local z = -map.data.z
      local last_state = Ys[z].state
      local start_z = z
      while z < map.data.z do
        z = z + 1
        local state = Ys[z].state
        if state ~= last_state then
          if last_state ~= unknown then
            -- We have a new node run.
            local run = {
              x = x,
              y = y,
              z = start_z,
              state = last_state,
              nodes = z - start_z
            }
            num_runs = num_runs + 1
            node_runs[num_runs] = run
          end

          last_state = state
          start_z = z
        end
      end
    end
  end


  local main_header = string.pack(
    (">c6I2I2"):format(#map.name),
    "CCSMAP",
    CURRENT_SAVE_VERSION,
    flags
  )

  local map_name_header = string.pack(
    ("I1c%d"):format(#map.name),
    #map.name,
    map.name
  )

  local node_runs_header = string.pack(">I6", num_runs)

  local size_header = string.pack(
    ">I2I2I2",
    map.data.x,
    map.data.y,
    map.data.z
  )

  -- If true, it means we have written the headers already, thus this is a
  -- multifile write. We don't need to write ALL headers on subsequent writes,
  -- and we need to change the flag to note that we are writing a multifile.
  local wrote_headers = false
  local function write_headers(handle)
    if not wrote_headers then
      handle.write(main_header)
      handle.write(map_name_header)
      handle.write(node_runs_header)
      handle.write(size_header)
      wrote_headers = true
    else
      ---@fixme The flags here need to be updated.
      main_header = string.pack(
        (">c6I2I2"):format(#map.name),
        "CCSMAP",
        CURRENT_SAVE_VERSION,
        flags
      )
      handle.write(main_header)
    end
  end


  -- We will buffer everything to write at once, to avoid partial writes.
  -- As well, it should make it easier to swap to new files if we need to.
  local buffer = {}
  local buffer_i = 0

  -- Add the node runs.
  local solid = map.BlockState.SOLID
  for i = 1, num_runs do
    local run = node_runs[i]
    buffer_i = buffer_i + 1
    buffer[buffer_i] = string.pack(
      (">I1%s"):format(size_flag and "I2i2i2i2" or "I1i1i1i1"),
      run.state,
      run.nodes,
      run.x,
      run.y,
      run.z
    )
  end

  -- Open the file
  local handle = fs.open(path, "wb")

  if not handle then
    return false, "Failed to open file for writing."
  end

  -- Write the headers
  write_headers(handle)

  -- Write the node runs
  for i = 1, buffer_i do
    handle.write(buffer[i])
  end

  -- Close the file
  handle.close()

  return true
end

--- Load a map from a file.
---@param path string The path to the file.
---@param map Map The map to load data into.
function file_io.load_map(path, map)
  expect(1, path, "string")

  -- Open the file
  local handle = fs.open(path, "rb")

  if not handle then
    error("Failed to open file for reading.", 2)
  end

  -- Read the headers
  local header = handle.read(6)
  print("Header: '" .. tostring(header) .. "'")

  if header ~= "CCSMAP" then
    handle.close()
    error("Invalid file format.", 2)
  end

  --- Ensure that a specific amount of bytes have been returned.
  ---@param n integer The amount of bytes to ensure.
  ---@return string bytes The bytes read.
  local function ensure_bytes(n)
    local bytes = handle.read(n)
    if not bytes then
      handle.close()
      error("Unexpected end of file (1).", 2)
    end
    return bytes
  end

  local version = string.unpack(">I2", ensure_bytes(2))

  print("Save version:", version)
  if version > CURRENT_SAVE_VERSION then
    handle.close()
    error("Unsupported save version.", 2)
  end

  local flags = string.unpack(">I2", ensure_bytes(2))
  local size_flag = bit32.band(flags, 1) == 1
  local multi_flag = bit32.band(flags, 2) == 2
  local multi_last_flag = bit32.band(flags, 4) == 4
  local multi_first_flag = bit32.band(flags, 8) == 8
  print("Flags:", flags)
  print("  Large?", size_flag)
  print("  Multi?", multi_flag)
  print("  Multi last?", multi_last_flag)
  print("  Multi first?", multi_first_flag)

  local name_length = string.unpack(">I1", ensure_bytes(1))
  print("Name length:", name_length)

  local name = ensure_bytes(name_length)
  print("Name: '" .. tostring(name) .. "'")

  local num_runs = string.unpack(">I6", ensure_bytes(6))
  print("Num runs:", num_runs)


  local map_size_x, map_size_y, map_size_z = string.unpack(">I2I2I2", ensure_bytes(6))  --[[@as integer,integer,integer]]
  print("Map size:", map_size_x, map_size_y, map_size_z)

  local runs = {}
  local run_n = 0
  -- 1 + 1 + 3 or 1 + 2 + 6
  local read_size = size_flag and 9 or 5
  for i = 1, num_runs do
    local next_str = handle.read(read_size)

    if not next_str then
      -- We have reached the end of the file.
      if not multi_flag then
        handle.close()
        error("Unexpected end of file (2).", 2)
      end

      -- we need to open the next file.
      ---@fixme This is not implemented yet.
      error("Multi-file not yet implemented.", 2)
    end

    --[[
      buffer[buffer_i] = string.pack(
        (">I1%s"):format(size_flag and "I2i2i2i2" or "I1i1i1i1"),
        run.state,
        run.nodes,
        run.x,
        run.y,
        run.z
      )
    ]]

    local state, node_count, start_x, start_y, start_z = string.unpack(
      (">I1%s"):format(size_flag and "I2i2i2i2" or "I1i1i1i1"),
      next_str
    )

    local solid = BlockState.SOLID
    local empty = BlockState.EMPTY
    local unknown = BlockState.UNKNOWN

    print("State:", state == solid and "Solid" or state == empty and "Empty" or "Unknown")
    if state == unknown then
      handle.close()
      error("(Debug) Read unknown state for node run, we should not be saving unknown nodes.", 2)
    end
    print("Node count:", node_count)
    print("Start:", start_x, start_y, start_z)

    run_n = run_n + 1
    runs[run_n] = {
      state = state,
      nodes = node_count,
      x = start_x,
      y = start_y,
      z = start_z
    }
  end

  handle.close()

  -- Now we can crap the data into the map

  -- First, size the map appropriately
  map:set_size(map_size_x, map_size_y, map_size_z)

  -- Then, set the name
  map.name = name

  -- Finally, set the runs
  for i = 1, run_n do
    local run = runs[i]
    map:set_run(
      run.x,
      run.y,
      run.z,
      run.nodes,
      run.state
    )
  end

  return true
end

return file_io
