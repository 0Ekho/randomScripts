--[[ BSD-0
 Copyright (C) 2018, Ekho

 Permission to use, copy, modify, and/or distribute this software for any
 purpose with or without fee is hereby granted.

 THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 ------------------------------------------------------------------------------
 --]]
 
local version = "0.0.1-alpha"
 
local utils = require("mp.utils")

local save_path = "/tmp/mpv_timestamps"

local function save_time()
    local cur_time = mp.get_property_osd("time-pos/full")
    
    local path = mp.get_property("path")
    local file = io.open(save_path, "a")
    file:write(cur_time)
    file:write("\n")
    file:close()
    mp.osd_message("current timestamp saved to"..save_path, 4)
end

local function save_fpath()
    local path = mp.get_property("path")
    local file = io.open(save_path, "a")
    file:write(path)
    file:write("\n")
    file:close()
    mp.osd_message("current file name saved to"..save_path, 4)
end

mp.add_key_binding("N", "save_fpath", save_fpath, {repeatable=true})
mp.add_key_binding("M", "save_time", save_time, {repeatable=true})
