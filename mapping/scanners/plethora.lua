--- Plethora overloads for the scan system.

local block_movement = require "mapping.block_movement"
local BlockState = require "mapping.block_state"

---@class plethora : ScannerShim
local plethora = {
  selected_scanner = nil ---@type string? The name of the selected scanner.
}

local SCANNER_TYPE = "plethora:scanner"
local MANIP_TYPE = "manipulator"

--- Scan the area around the given position.
---@param map Map The map to scan into.
---@param pos_x number The x position of the centerpoint of the scan.
---@param pos_y number The y position of the centerpoint of the scan.
---@param pos_z number The z position of the centerpoint of the scan.
---@return boolean success Whether the scan was successful.
function plethora.scan_into(map, pos_x, pos_y, pos_z)
  local scan_data = peripheral.call(plethora.selected_scanner, "scan")

  if not scan_data then
    return false
  end

  -- Plethora is nice and returns what blocks are air, so we can just directly
  -- throw this into the map.
  for i = 1, #scan_data do
    local block = scan_data[i]
    local x, y, z = block.x, block.y, block.z

    if block_movement[block.name] then
      map:set_block(pos_x + x, pos_y + y, pos_z + z, BlockState.EMPTY)
    else
      map:set_block(pos_x + x, pos_y + y, pos_z + z, BlockState.SOLID)
    end
  end

  return true
end

--- Search for scanners, and select the first one found.
---@return boolean success Whether a scanner was found.
function plethora.search_scanners()
  local scanner = peripheral.find(SCANNER_TYPE)
  local manipulators = {peripheral.find(MANIP_TYPE)}

  if scanner then
    -- If there is a scanner directly attached, this is likely a turtle. We can
    -- use it directly.

    -- Nothing actually needs to happen here, but I'll leave this here as
    -- documentation in case that changes.
  else
    -- If there is no scanner, it may be attached to a manipulator instead.
    if manipulators[1] then
      for _, manip in ipairs(manipulators) do
        if manip.hasModule(SCANNER_TYPE) then
          scanner = manip
          break
        end
      end
    else
      return false -- No scanner or manipulator found.
    end
  end

  if scanner then
    plethora.selected_scanner = peripheral.getName(scanner)
    return true
  end

  return false
end

--- In the case that the user has multiple scanners, this function allows the
--- user to select which scanner to use. Shims should do error checking to
--- ensure that the scanner is valid.
---@param peripheral_name string The name of the peripheral to select.
---@return boolean success Whether the scanner given was selected.
function plethora.select_scanner(peripheral_name)
  if peripheral.isPresent(peripheral_name) and peripheral.getType(peripheral_name) == SCANNER_TYPE then
    plethora.selected_scanner = peripheral_name
    return true
  end

  return false
end

return plethora