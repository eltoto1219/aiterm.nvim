-- Run: nvim --headless --clean -l tests/buffer_navigation.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

require("aiterm").setup({
    ai = { restore = false },
    mappings = {
        buffers = {
            previous = "[b",
            next = "]b",
        },
        terminal = {
            previous = "[t",
            next = "]t",
        },
    },
})

local terminal = require("aiterm.terminal")

vim.cmd.edit(vim.fn.tempname() .. "-buffer-navigation-one.lua")
local first_file = vim.api.nvim_get_current_buf()
vim.cmd.edit(vim.fn.tempname() .. "-buffer-navigation-two.lua")
local second_file = vim.api.nvim_get_current_buf()

local first_terminal = terminal.open_command({ "sh" }, "plain-terminal-one", {})
assert(first_terminal, "first plain terminal opened")
local second_terminal = terminal.open_command({ "sh" }, "plain-terminal-two", {})
assert(second_terminal, "second plain terminal opened")
local first_ai = terminal.open_command({ "sh" }, "ai-session-one", { ai_kind = "codex" })
assert(first_ai, "first AI terminal opened")
local second_ai = terminal.open_command({ "sh" }, "ai-session-two", { ai_kind = "codex" })
assert(second_ai, "second AI terminal opened")

local function use_normal_mapping(keys, expected_buf, description)
    if vim.bo.buftype == "terminal" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "nx", false)
    else
        vim.cmd.stopinsert()
    end
    assert(
        vim.wait(1000, function()
            return vim.api.nvim_get_mode().mode:sub(1, 1) == "n"
        end, 10),
        description .. " starts in normal mode"
    )
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
    assert(
        vim.wait(1000, function()
            return vim.api.nvim_get_current_buf() == expected_buf
        end, 10),
        description
    )
end

vim.cmd.buffer(first_file)
use_normal_mapping("]b", second_file, "file navigation stays within file buffers")
use_normal_mapping("[b", first_file, "file navigation works in normal mode")

vim.cmd.buffer(first_terminal)
use_normal_mapping("]t", second_terminal, "terminal navigation works in normal mode")
use_normal_mapping("[t", first_terminal, "terminal navigation stays within plain terminals")

vim.cmd.buffer(first_ai)
use_normal_mapping("]t", second_ai, "AI navigation works in normal mode")
use_normal_mapping("[t", first_ai, "AI navigation stays within AI sessions")

print("buffer_navigation OK")
