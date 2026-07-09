-- Run: nvim --headless --clean -l tests/ai_picker_cwd.lua
local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(script), ".."))
local temp = vim.fn.tempname()
local current_cwd = vim.fs.joinpath(temp, "current")
local other_cwd = vim.fs.joinpath(temp, "other")

vim.env.XDG_STATE_HOME = vim.fs.joinpath(temp, "state")
vim.fn.mkdir(current_cwd, "p")
vim.fn.mkdir(other_cwd, "p")
vim.opt.rtp:prepend(root)

local config = require("aiterm.config")
local registry = vim.fs.joinpath(config.state_dir(), "ai_sessions.json")
vim.fn.writefile({
    vim.json.encode({
        {
            key = "cached-current-key",
            kind = "sh",
            id = "cached-current-id",
            cwd = current_cwd,
            title = "Cached Current",
            last_used = 40,
        },
        {
            key = "cached-other-key",
            kind = "sh",
            id = "cached-other-id",
            cwd = other_cwd,
            title = "Cached Other",
            last_used = 50,
        },
    }),
}, registry)
vim.cmd.cd(vim.fn.fnameescape(current_cwd))

require("aiterm").setup({
    ai = {
        restore = true,
        autostart = false,
        kinds = {
            sh = {
                args = {},
                command = function()
                    return { "sh", "-c", "sleep 30" }
                end,
            },
        },
    },
})

local ai = require("aiterm.ai")
local terminal = require("aiterm.terminal")

local current_buf = ai.open("sh", current_cwd)
assert(current_buf and vim.api.nvim_buf_is_valid(current_buf), "current cwd AI session opened")
terminal.set_label(current_buf, "Live Current")

local other_buf = ai.open("sh", other_cwd)
assert(other_buf and vim.api.nvim_buf_is_valid(other_buf), "other cwd AI session opened")
terminal.set_label(other_buf, "Live Other")

vim.cmd.cd(vim.fn.fnameescape(current_cwd))

local captured_labels = nil
require("aiterm.ui.picker").select = function(_, labels)
    captured_labels = labels
end

ai.pick()

assert(captured_labels ~= nil, "AI picker opened")
local rendered = table.concat(captured_labels, "\n")
assert(rendered:find("sh: Live Current", 1, true), "current cwd live session is shown with harness")
assert(rendered:find("sh: Cached Current (cached)", 1, true), "current cwd cached session is shown with harness")
assert(not rendered:find("Live Other", 1, true), "other cwd live session is hidden")
assert(not rendered:find("Cached Other", 1, true), "other cwd cached session is hidden")

for _, bufnr in ipairs({ current_buf, other_buf }) do
    if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
end

print("ai_picker_cwd OK")
