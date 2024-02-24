--- Small library for saving a map to a file and loading a map from a file.
--- Saves in a binary format, as CC has a limited "disk drive" size.

local expect = require("cc.expect").expect ---@type fun(arg_n:integer, value:any, ...:string)

local BlockState = require("mapping.block_state")

local CURRENT_SAVE_VERSION = 1

local file_io = {
  file_iterators = {},
  max_file_size = 256 * 1024, -- 256 KiB
  min_file_size = 1024 -- 1 KiB
}

--- Get the root of a drive from a path.
---@param path string The path to get the root of.
---@return string? root The root of the drive, or nil if the path is in root.
local function get_drive_root(path)
  local drive = fs.getDrive(path:match("^/?([^/]+)"))
  if drive and drive ~= "hdd" then
    return path:match("^/?([^/]+)")
  end

  -- Explicit return so that I know wtf this function is returning.
  return nil
end

--- A basic function to return what the next file should be named in a series of multi-file saves.
--- This function is used as the default for the `next_name` parameter of `file_io.save_map`.
--- This iterator will return files like so:
--- 1. "path"
--- 2. "path_1"
--- 3. "path_2"
--- and so forth, until the disk runs low on space (at least file_io.min_file_size must be able to be written).
--- After that, it will check if any disk drives have enough space to continue the series, and if so, it will continue the series on the first disk drive with enough space.
--- If no disk drives have enough space, it will throw an error.
---@return fun(last_name:string?,last_index:integer,space_left:integer|"unlimited"):string next_path The function to get the next path in the series.
function file_io.file_iterators.default(initial_path)
 return function(last_name, last_index, space_left)
    -- The first iteration will not provide a last name, so we will use the initial path.
    if last_index <= 0 then
      return initial_path
    end

    local next_name = last_name or initial_path

    local i = 0
    if next_name:match("_%d+.ccsmap$") then
      -- Get the current index from the last file name.
      local n = tonumber(next_name:match("_(%d+).ccsmap$"))
      i = n and n or i

      -- Remove everything after the last underscore.
      next_name = next_name:match("^(.+)_") or next_name
    end

    if space_left == "unlimited" or space_left > file_io.min_file_size then
      return next_name .. "_" .. (i + 1) .. ".ccsmap"
    end

    -- There likely isn't enough space to continue the series, so let's check if
    -- there are any disk drives with enough space.
    local disks = {peripheral.find("drive")}
    local current_root = get_drive_root(next_name)
    ---@cast disks Drive[]

    if current_root then
      next_name = fs.getName(next_name)
    end

    if not disks then
      error("Not enough space to continue the series, and no disk drives found.", 3)
    end

    i = 0

    for j = 1, #disks do
      local disk = disks[j]

      -- We want to ensure the drive has
      -- A: A data storage medium,
      -- B: Enough space to continue the series, and
      -- C: Is not the same drive as the last file was written to, since we have
      --    already determined it to be out of space.
      if disk.hasData() and disk.getMountPath() ~= current_root then
        local disk_free_space = disk.getFreeSpace()

        next_name = disk.getMountPath() .. "/" .. next_name

        if disk_free_space == "unlimited" or disk_free_space > file_io.min_file_size then
          -- There is enough space to continue the series.
          return next_name .. "_" .. (i + 1) .. ".ccsmap"
        end
      end
    end

    error("Not enough space to continue the series, and no disk drives found with enough space.", 3)
  end
end

--- A basic function to return what the next file should be named in a series of multi-file saves.
--- This iterator will return the next file in the list, or throw an error if there are no more files in the list.
---@return fun(last_name:string?,last_index:integer,space_left:integer|"unlimited"):string next_path The function to get the next path in the series.
function file_io.file_iterators.from_list(list)
  ---@param last_name string The name of the last file in the series.
  ---@param last_index integer The index of the last file in the series.
  ---@return string next_name The name of the next file in the series.
  return function(last_name, last_index, space_left)
    local next_index = last_index + 1
    if list[next_index] then
      return list[next_index]
    else
      error("No more files in the list.", 3)
    end
  end
end

---@fixme This should only take the `next_name` function, and it should be `next_path` instead.
---@fixme 8 run states should be able to be condensed into one byte, then the next 8 runs can be written back-to-back without needing to write the state again.
---       This will likely require a bump in the save version, but it will save a fair bit of space.
---@fixme We should further reduce output file size using huffman encoding.
--- Save a map to a file.
---@param map Map The map to save.
---@param next_path string|fun(last_name:string?,last_index:integer,space_left:integer|"unlimited"): string  A function to get the next file in the series of multi-file saves, or the initial file path.
---@return boolean success Whether the save was successful.
---@return string? error The error message if the save failed.
function file_io.save_map(map, next_path)
  expect(1, map, "table")
  expect(2, next_path, "function", "string")
  next_path = type(next_path) == "function" and next_path or file_io.file_iterators.default(next_path)

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

  --- Write the headers to the file.
  ---@param handle BinaryWriteHandle The handle to write to.
  ---@param multifile boolean Whether this is a multifile write.
  ---@param last_file boolean Whether this is the last file in the series.
  ---@param next_file_name string The name of the next file in the series.
  local function write_headers(handle, multifile, last_file, next_file_name)
    -- flag[0] = large format
    -- flag[1] = multifile
    -- flag[2] = multifile, last file in series
    if multifile then
      -- add multifile flag if needed.
      flags = bit32.bor(flags, 2)

      -- add multifile last flag if needed.
      if last_file then
        flags = bit32.bor(flags, 4)
      end
    end

    main_header = string.pack(
      (">c6I2I2"):format(#map.name),
      "CCSMAP",
      CURRENT_SAVE_VERSION,
      flags
    )

    if not wrote_headers then
      handle.write(main_header)
      handle.write(map_name_header)
      handle.write(node_runs_header)
      handle.write(size_header)
      wrote_headers = true
    else
      handle.write(main_header)
    end
  end


  -- We will buffer everything to write at once, to avoid partial writes.
  -- As well, it should make it easier to swap to new files if we need to.
  local buffer = {}
  local buffer_i = 0

  -- Add the node runs.
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

  -- Determine the file size
  local file_size = 0
  for i = 1, buffer_i do
    file_size = file_size + #buffer[i]
  end

  print("STARTING WRITE SEQUENCE")
  sleep(5)

  local last_name
  local buffer_pos = 0
  local i = 0
  local multifile = false
  while buffer_pos < buffer_i do
    local new_path = next_path(last_name, i, fs.getFreeSpace(last_name or ""))
    i = i + 1

    print("NEW PATH:", new_path)
    sleep(1)

    -- Check how much space is available on the chosen disk.
    local disk_space = fs.getFreeSpace(new_path)

    -- Pretend to write everything to see how much space is taken...
    local space_needed = 0
    local last_file = true
    for j = buffer_pos + 1, buffer_i do
      space_needed = space_needed + #buffer[j]
      if space_needed > file_io.max_file_size or (disk_space ~= "unlimited" and space_needed > disk_space - 100) then
        multifile = true
        last_file = false
        break
      end
    end

    print("DETERMINED SPACE NEEDED:", space_needed)
    print("FREE SPACE:", disk_space)
    print("MULTIFILE?", multifile)
    print("LAST FILE?", last_file)

    -- Now we can actually write the file, since we know how much space we need.

    -- Open the file
    local handle, err = fs.open(new_path, "wb") --[[@as BinaryWriteHandle?]]
    print("OPENED FILE")

    if not handle then
      return false, ("Failed to open '%s' for writing: %s"):format(new_path, err)
    end

    -- Write the headers
    write_headers(handle, multifile, last_file, new_path)
    print("WRITE HEADERS")
    sleep(5)

    -- Write node runs until we run low on space.
    local written = 0
    local closed = false
    for j = buffer_pos + 1, buffer_i do
      local run = buffer[j]
      buffer_pos = j

      -- Write the run
      handle.write(run)

      -- If we have written enough, or we are about to run out of space, then
      -- we should stop writing to this file.
      written = written + #run
      if written > file_io.max_file_size or (disk_space ~= "unlimited" and written > disk_space - 100) then
        handle.close()
        closed = true
        print("CLOSED! (1)")
        break
      end
    end

    -- The last file in the series will likely not be closed, since we will
    -- not reach max file size or run out of space while writing it.
    -- (at least in theory)
    if not closed then
      handle.close()
      print("CLOSED! (2)")
    end

    last_name = new_path
    print("End iteration")
    sleep(5)
  end

  print("Done!")
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
