-- Run: nvim --headless --clean -l tests/tabline.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

vim.o.columns = 80
vim.o.lines = 24

require("aiterm").setup({
    tabline = { enabled = true },
})

local tabline = require("aiterm.tabline")
local terminal = require("aiterm.terminal")

local function focused_float()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "popup" })
    return vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = 20,
        height = 1,
        row = 2,
        col = 2,
    })
end

vim.cmd.edit(vim.fn.tempname() .. "-tabline-file.lua")
local file_label = vim.fs.basename(vim.api.nvim_buf_get_name(0))
local rendered = tabline.component()
assert(rendered:find(file_label, 1, true), "file tabline renders before popup")

local win = focused_float()
rendered = tabline.component()
assert(rendered:find(file_label, 1, true), "file tabline remains while popup is focused")
vim.api.nvim_win_close(win, true)

local term_buf = terminal.open_command({ "sh" }, "plain-test", {})
assert(term_buf and vim.api.nvim_get_current_buf() == term_buf, "plain terminal opened")
rendered = tabline.component()
assert(rendered:find("plain-test", 1, true), "terminal tabline renders before popup")

win = focused_float()
rendered = tabline.component()
assert(rendered:find("plain-test", 1, true), "terminal tabline remains while popup is focused")
vim.api.nvim_win_close(win, true)

local ai_buf = terminal.open_command({ "sh" }, "ai-test", { ai_kind = "codex" })
assert(ai_buf and vim.api.nvim_get_current_buf() == ai_buf, "AI terminal opened")
rendered = tabline.component()
assert(rendered:find("ai-test", 1, true), "AI tabline renders before popup")

win = focused_float()
rendered = tabline.component()
assert(rendered:find("ai-test", 1, true), "AI tabline remains while popup is focused")
vim.api.nvim_win_close(win, true)

print("tabline OK")
