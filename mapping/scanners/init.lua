--- A small shim that allows using both Advanced Peripherals and Plethora's
--- scanner.

local ap = require("mapping.scanners.ap")
local plethora = require("mapping.scanners.plethora")
local block_state = require("mapping.block_state")
local block_movement = require("mapping.block_movement")

local selected

---@class ScanData The data of a scan.
---@field x number The width of the scan.
---@field y number The height of the scan.
---@field z number The depth of the scan.
---@field data ScanBlock[] The data of the scan.

---@class ScanBlock The data of a single block in a scan.
---@field x number The x position of the block.
---@field y number The y position of the block.
---@field z number The z position of the block.
---@field name string The name of the block.

---@alias turtle_facing
---| `0` # North, or towards -Z.
---| `1` # East, or towards +X.
---| `2` # South, or towards +Z.
---| `3` # West, or towards -X.

---@class scanners
local scanners = {}

--- Scan the area around the given position.
---@param map Map The map to scan into.
---@param x integer The x position of the centerpoint of the scan.
---@param y integer The y position of the centerpoint of the scan.
---@param z integer The z position of the centerpoint of the scan.
---@return boolean success Whether the scan was successful.
function scanners.scan_into(map, x, y, z)
  if not selected then
    error("Scanners have not been set up.", 2)
  end
  return selected.scan_into(map, x, y, z)
end

--- Use `inspectDown`/`inspectUp`/`inspect` to scan the area around the given position, if this is a turtle.
---@param map Map The map to scan into.
---@param x integer The x position of the turtle.
---@param y integer The y position of the turtle.
---@param z integer The z position of the turtle.
---@param facing turtle_facing The direction the turtle is facing, as a number from 0 to 3 (0 is north, 1 is east, 2 is south, 3 is west).
function scanners.turtle_scan_into(map, x, y, z, facing)
  if not turtle then
    error("This function can only be used on a turtle.", 2)
  end

  local is_forward, forward_block = turtle.inspect()
  local is_up, up_block = turtle.inspectUp()
  local is_down, down_block = turtle.inspectDown()

  local SOLID = block_state.SOLID
  local AIR = block_state.AIR

  if is_up then
    map:set_block(x, y + 1, z, block_movement[up_block.name] and AIR or SOLID)
  else
    map:set_block(x, y + 1, z, AIR)
  end
  if is_down then
    map:set_block(x, y - 1, z, block_movement[down_block.name] and AIR or SOLID)
  else
    map:set_block(x, y - 1, z, AIR)
  end

  if is_forward then
    if facing == 0 then -- Towards -Z
      map:set_block(x, y, z - 1, block_movement[forward_block.name] and AIR or SOLID)
    elseif facing == 1 then -- Towards +X
      map:set_block(x + 1, y, z, block_movement[forward_block.name] and AIR or SOLID)
    elseif facing == 2 then -- Towards +Z
      map:set_block(x, y, z + 1, block_movement[forward_block.name] and AIR or SOLID)
    elseif facing == 3 then -- Towards -X
      map:set_block(x - 1, y, z, block_movement[forward_block.name] and AIR or SOLID)
    end
  else
    if facing == 0 then -- Towards -Z
      map:set_block(x, y, z - 1, AIR)
    elseif facing == 1 then -- Towards +X
      map:set_block(x + 1, y, z, AIR)
    elseif facing == 2 then -- Towards +Z
      map:set_block(x, y, z + 1, AIR)
    elseif facing == 3 then -- Towards -X
      map:set_block(x - 1, y, z, AIR)
    end
  end
end

--- Set up the scanner shim.
---@return boolean success Whether the setup was successful.
---@return string? message The error message, if the setup was not successful.
function scanners.setup()
  if ap.search_scanners() then
    selected = ap
    return true
  elseif plethora.search_scanners() then
    selected = plethora
    return true
  else
    return false, "No scanners found."
  end
end

--- Check if the scanner shim is set up.
---@return boolean success Whether the scanner shim is set up.
function scanners.is_setup()
  return selected ~= nil
end

--- In the case that the user has multiple scanners, this function allows the
--- user to select which scanner to use.
---@param peripheral_name string The name of the peripheral to select.
---@return boolean success Whether the operation was successful.
---@return string? message The error message if the operation was not successful.
function scanners.select_scanner(peripheral_name)
  if ap.select_scanner(peripheral_name) then
    selected = ap
    return true
  elseif plethora.select_scanner(peripheral_name) then
    selected = plethora
    return true
  end

  return false, "No scanner with that name found."
end

--- Get the selected scanner.
---@return string? scanner_name The name of the selected scanner, or nil if no scanner is selected.
function scanners.get_selected_scanner()
  return selected and selected.selected_scanner
end

return scanners