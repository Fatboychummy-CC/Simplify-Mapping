--- This file serves as a base for any shims required for scanners.

---@class ScannerShim
---@field scan_into fun(map:Map, x:number, y:number, z:number):ScanData|nil
---@field search_scanners fun():boolean

---@class shim_base : ScannerShim
local shim_base = {
  selected_scanner = nil ---@type string? The name of the selected scanner.
}

--- Scan the area around the given position.
---@param map Map The map to scan into.
---@param pos_x number The x position of the centerpoint of the scan.
---@param pos_y number The y position of the centerpoint of the scan.
---@param pos_z number The z position of the centerpoint of the scan.
---@return boolean success Whether the scan was successful.
function shim_base.scan_into(map, pos_x, pos_y, pos_z)
  return false
end

--- Search for scanners, and select the first one found.
---@return boolean success Whether a scanner was found.
function shim_base.search_scanners()
  return false
end

--- In the case that the user has multiple scanners, this function allows the
--- user to select which scanner to use. Shims should do error checking to
--- ensure that the scanner is valid.
---@param peripheral_name string The name of the peripheral to select.
---@return boolean success Whether the scanner given was selected.
function shim_base.select_scanner(peripheral_name)
  shim_base.selected_scanner = peripheral_name

  return true
end

return shim_base