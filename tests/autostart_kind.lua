-- Run: nvim --headless --clean -l tests/autostart_kind.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
local temp = vim.fn.tempname()
local bin = vim.fs.joinpath(temp, "bin")

vim.fn.mkdir(bin, "p")
for _, name in ipairs({ "claude", "codex" }) do
    local path = vim.fs.joinpath(bin, name)
    vim.fn.writefile({ "#!/bin/sh", "sleep 30" }, path)
    vim.fn.setfperm(path, "rwxr-xr-x")
end

vim.env.PATH = bin
vim.opt.rtp:prepend(root)

require("aiterm").setup({ ai = { autostart = true } })
local ai = require("aiterm.ai")
assert(ai.autostart_kind() == "claude", "unset autostart kind preserves first executable default")

require("aiterm").setup({ ai = { autostart = true, autostart_kind = "codex" } })
assert(ai.autostart_kind() == "codex", "configured autostart kind is preferred")

local original_notify = vim.notify
vim.notify = function() end
require("aiterm").setup({ ai = { autostart = true, autostart_kind = "missing" } })
assert(ai.autostart_kind() == nil, "unknown autostart kind does not fall back")
vim.notify = original_notify

print("autostart_kind OK")
