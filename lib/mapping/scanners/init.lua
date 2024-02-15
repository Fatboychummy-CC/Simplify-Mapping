--- A small shim that allows using both Advanced Peripherals and Plethora's
--- scanner.

local ap = require("mapping.scanners.ap")
local plethora = require("mapping.scanners.plethora")

local selected

if ap.search_scanners() then
  selected = ap
elseif plethora.search_scanners() then
  selected = plethora
else
  error("No scanners found.", 0)
end

---@class ScannerShim
---@field scan_into fun(map:Map, x:number, y:number, z:number):ScanData|nil
---@field search_scanners fun():boolean

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
  return selected.scan_into(map, x, y, z)
end

return scanners