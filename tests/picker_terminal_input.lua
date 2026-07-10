-- Run: nvim --headless --clean -l tests/picker_terminal_input.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

if vim.fn.has("win32") == 1 then
    print("picker terminal input skipped on Windows")
    return
end

require("aiterm").setup({})

local terminal = require("aiterm.terminal")
local received = vim.fn.tempname()
local bufnr = terminal.open_command({ "sh", "-c", 'cat > "$1"', "sh", received }, "picker-input")
assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "AI-like terminal opened")

local terminal_winid = vim.api.nvim_get_current_win()
local canceled = false
require("aiterm.ui.picker").select("Graphify test", { "Alpha", "Beta" }, function(index)
    error("picker selection should not run during this focus test: " .. index)
end, function()
    canceled = true
end)

assert(vim.bo.buftype == "nofile", "picker prompt takes focus from the terminal")
assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "i"
    end),
    "picker starts with Search owning insert-mode input"
)

vim.api.nvim_feedkeys("needle", "nx!", false)
assert(
    vim.wait(1000, function()
        return vim.api.nvim_get_current_line():find("needle", 1, true) ~= nil
    end),
    "typed picker search text stays in the prompt buffer"
)
assert(vim.fn.getfsize(received) == 0, "typed picker search text does not reach the live terminal")

vim.api.nvim_set_current_win(terminal_winid)
assert(
    vim.wait(1000, function()
        return canceled
    end),
    "leaving the picker returns focus without sending picker text to the terminal"
)
assert(vim.fn.getfsize(received) == 0, "picker navigation never reaches the live terminal prompt")

if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end
vim.fn.delete(received)
print("picker terminal input OK")
