-- Run: nvim --headless --clean -l tests/providers.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

local aiterm = require("aiterm")
local providers = require("aiterm.providers")

providers.clear("ai")

aiterm.register_provider("ai", "goose", {
    command = function(entry, resume)
        return { "goose", resume and "resume" or "run", entry and entry.cwd or "" }
    end,
    executable = nil,
})

local duplicate_ok = pcall(function()
    aiterm.register_provider("ai", "goose", {
        command = function()
            return { "goose" }
        end,
    })
end)
assert(not duplicate_ok, "duplicate providers require explicit replacement")

local invalid_ok = pcall(function()
    aiterm.register_provider("ai", "broken", {})
end)
assert(not invalid_ok, "AI providers require command functions")

require("aiterm").setup({
    ai = {
        kinds = {
            claude = { args = {} },
            codex = { args = {} },
        },
    },
})

local names = require("aiterm.ai").kind_names()
assert(vim.tbl_contains(names, "goose"), "registered AI provider appears in kind list")

local argv = require("aiterm.ai").shell_command("goose")
assert(argv and argv:find("goose", 1, true), "registered AI provider supplies commands")

local listed = aiterm.providers("ai")
assert(listed.goose ~= nil, "aiterm.providers returns registered providers")

print("providers OK")
