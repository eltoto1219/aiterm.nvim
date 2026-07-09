-- Run: nvim --headless --clean -l tests/picker.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

vim.o.columns = 80
vim.o.lines = 24

require("aiterm").setup({})

local selected = nil
require("aiterm.ui.picker").select("Pick one:", { "Alpha", "Beta", "Gamma" }, function(index)
    selected = index
end)

local winid = vim.api.nvim_get_current_win()
local bufnr = vim.api.nvim_win_get_buf(winid)
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

assert(lines[1] == "Search: ", "picker exposes a search prompt")
assert(lines[3] == "1. Alpha", "first picker item is numbered")
assert(lines[4] == "2. Beta", "second picker item is numbered")
assert(lines[5] == "3. Gamma", "third picker item is numbered")
assert(
    (vim.wo[winid].winhighlight or ""):find("CursorLine:AitermPickerSelected", 1, true),
    "picker uses its selected-line highlight"
)

vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "Search: gm" })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })
lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
assert(lines[3] == "3. Gamma", "picker filters with fuzzy matching")

vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

assert(selected == 3, "picker selection returns the original item index")

print("picker OK")
