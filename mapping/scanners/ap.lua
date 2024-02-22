--- Advanced Peripherals overloads for the scan system.

local block_movement = require "mapping.block_movement"
local BlockState = require "mapping.block_state"

---@class AP : ScannerShim
local ap = {
  selected_scanner = nil ---@type string? The name of the selected scanner.
}

local GEOSCANNER_TYPE = "geoScanner"

--- Scan the area around the given position.
---@param map Map The map to scan into.
---@param pos_x number The x position of the centerpoint of the scan.
---@param pos_y number The y position of the centerpoint of the scan.
---@param pos_z number The z position of the centerpoint of the scan.
---@return boolean success Whether the scan was successful.
function ap.scan_into(map, pos_x, pos_y, pos_z)
  local scan_data = peripheral.call(ap.selected_scanner, "scan", 8)

  if not scan_data then
    return false
  end

  -- Convert the scan data into a 3d array
  local data = {}

  for _, block in ipairs(scan_data) do
    if not data[block.x] then
      data[block.x] = {}
    end

    if not data[block.x][block.y] then
      data[block.x][block.y] = {}
    end

    data[block.x][block.y][block.z] = block
  end

  -- Set the blocks in the map
  for x = -8, 8 do
    for y = -8, 8 do
      for z = -8, 8 do
        local block = data[x] and data[x][y] and data[x][y][z]

        if block then
          if block_movement[block.name] then
            map:set_block(pos_x + x, pos_y + y, pos_z + z, BlockState.EMPTY)
          else
            map:set_block(pos_x + x, pos_y + y, pos_z + z, BlockState.SOLID)
          end
        else
          map:set_block(pos_x + x, pos_y + y, pos_z + z, BlockState.EMPTY)
        end
      end
    end
  end

  return true
end

--- Search for scanners, and select the first one found.
---@return boolean success Whether a scanner was found.
function ap.search_scanners()
  local scanner = peripheral.find(GEOSCANNER_TYPE)

  if scanner then
    ap.selected_scanner = peripheral.getName(scanner)
    return true
  end

  return false
end

--- In the case that the user has multiple scanners, this function allows the
--- user to select which scanner to use. Shims should do error checking to
--- ensure that the scanner is valid.
---@param peripheral_name string The name of the peripheral to select.
---@return boolean success Whether the scanner given was selected.
function ap.select_scanner(peripheral_name)
  if peripheral.isPresent(peripheral_name) and peripheral.getType(peripheral_name) == GEOSCANNER_TYPE then
    ap.selected_scanner = peripheral_name
    return true
  end

  return false
end

return ap