---@diagnostic disable: undefined-global, need-check-nil

local file_io = require "mapping.file_io"

local drive = peripheral.find("drive")

if drive and drive.hasData() then
  suite.suite "file_io"
    "iterators.default" (function()
      -- Expect the first value to be the path input.
      local path = "some_path/bruh.ccsmap"
      local iter = file_io.file_iterators.default(path)
      EXPECT_EQ(iter(nil, 0, "unlimited"), path)

      -- Expect the second value to be the same as the above path, but `is_1.ccsmap`
      local path_1 = "some_path/bruh_1.ccsmap"
      EXPECT_EQ(iter(path, 1, "unlimited"), path_1)

      -- Expect the third value to be `disk.getMountPath()/is_1.ccsmap`
      local path_2 = drive.getMountPath().."/bruh_1.ccsmap"
      EXPECT_EQ(iter(path_1, 2, 0), path_2)
    end)
    "iterators.from_list" (function()
      local list = {
        "some_path/bruh.ccsmap",
        "some_path/bruh_1.ccsmap",
        "some_path/bruh_2.ccsmap",
        "some_path/bruh_3.ccsmap",
        "some_path/bruh_4.ccsmap",
      }
      local iter = file_io.file_iterators.from_list(list)
      for i, v in ipairs(list) do
        EXPECT_EQ(iter(list[i - 1], i - 1, "unlimited"), v)
      end
    end)

--
else
  suite.suite "file_io"
    "No disk drive" (function()
      FAIL("No disk drive found, or no disk drive with a disk.")
    end)
end