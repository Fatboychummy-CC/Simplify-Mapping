--- Plethora overloads for the scan system.
---@fixme I need to test this with Plethora to ensure that the right values are being supplied.

---@class plethora : ScannerShim
local plethora = {
  selected_scanner = nil ---@type string? The name of the selected scanner.
}

function plethora.scan_into(map, x, y, z)
  return peripheral.call(plethora.selected_scanner, "scan")
end

function plethora.search_scanners()
  local scanner = peripheral.find("block_scanner")

  if scanner then
    plethora.selected_scanner = peripheral.getName(scanner)
    return true
  end

  return false
end

return plethora