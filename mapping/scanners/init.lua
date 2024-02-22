--- A small shim that allows using both Advanced Peripherals and Plethora's
--- scanner.

local ap = require("mapping.scanners.ap")
local plethora = require("mapping.scanners.plethora")

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
--- @param peripheral_name string The name of the peripheral to select.
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