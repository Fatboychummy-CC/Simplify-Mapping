--- This main file solely just runs the tests. It is not required if you are
--- installing this library.

local args = table.pack(...)

local function add_paths(...)
  local paths = {...}
  local path = package.path
  local formatter = "%s;%s/?.lua;%s/?/init.lua"

  for _, v in ipairs(paths) do
    path = formatter:format(path, v, v)
  end

  package.path = path
end

add_paths("tests")

local verbose = {
  v = true,
  verbose = true,
  ["-v"] = true,
  ["--verbose"] = true
}

local monitors_set = 0
local redirect_monitor

for i = 1, args.n do
  if verbose[args[i]:lower()] then
    require "Framework.logger".verbose = true
  elseif peripheral.getType(args[i]) == "monitor" then
    if monitors_set == 0 then
      redirect_monitor = args[i]
    elseif monitors_set == 1 then
      require "Framework.runner".set_monitor(args[i])
    else
      error("Too many monitors specified.", 0)
    end
    monitors_set = monitors_set + 1
  else
    error(("Invalid argument %d."):format(i), 0)
  end
end

local function run_folders(...)
  local CCTest = require "Framework"

  for _, folder in ipairs({...}) do
    CCTest.load_tests(folder)
  end

  CCTest.run_all_suites()
end

local old, ok, err

---@diagnostic disable-next-line undefined-global we're checking for the existence of a library that exists on certain platforms
if periphemu then
  -- Running in CraftOS-PC, cannot run all tests.

  print("Running CraftOS-PC tests.")
  sleep(1)

  ok, err = pcall(
    run_folders,
    "/Simplify-Mapping/tests/craftos-pc",
    "/Simplify-Mapping/tests/ingame"
  )
else
  -- Running ingame, run all tests.
  if monitors_set == 0 then
    error("Testing framework requires two monitors if running ingame (Expected redirect monitor then framework monitor).", 0)
  elseif monitors_set < 2 then
    error("Not enough monitors specified (Expected redirect monitor then framework monitor).", 0)
  end

  print("Running ingame tests.")
  sleep(1)

  local wrapped = peripheral.wrap(redirect_monitor) --[[@as Monitor?]]

  if not wrapped then
    error("Failed to wrap monitor.", 0)
  end

  wrapped.setBackgroundColor(colors.black)
  wrapped.setTextColor(colors.white)
  wrapped.clear()
  wrapped.setCursorPos(1, 1)
  wrapped.setTextScale(0.5)

  old = term.redirect(wrapped)

  ok, err = pcall(
    run_folders,
    "/Simplify-Mapping/tests/craftos-pc",
    "/Simplify-Mapping/tests/ingame"
  )
end

term.redirect(old)
if not ok then
  printError(err)
end