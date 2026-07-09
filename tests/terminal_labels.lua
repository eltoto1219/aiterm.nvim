-- Run: nvim --headless --clean -l tests/terminal_labels.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

require("aiterm").setup({
    ai = { restore = false },
})

local terminal = require("aiterm.terminal")

local function open_plain_terminal()
    local bufnr = terminal.open_command({ "sh" }, nil, {})
    assert(bufnr, "plain terminal opened")
    assert(
        vim.wait(1000, function()
            return terminal.label_for_buf(bufnr) ~= nil
        end, 10),
        "plain terminal received a label"
    )
    return bufnr
end

local function close_terminal(bufnr)
    if vim.api.nvim_get_current_buf() == bufnr then
        vim.cmd.enew()
    end
    vim.api.nvim_buf_delete(bufnr, { force = true })
    assert(
        vim.wait(1000, function()
            return not vim.api.nvim_buf_is_valid(bufnr)
        end, 10),
        "terminal closed"
    )
end

local ai_buf = terminal.open_command({ "sh" }, "AI session", { ai_kind = "codex" })
assert(ai_buf, "AI terminal opened")

local first = open_plain_terminal()
assert(terminal.label_for_buf(first) == "T:1", "first plain terminal is T:1 even with an AI session open")

local second = open_plain_terminal()
assert(terminal.label_for_buf(second) == "T:2", "second plain terminal is T:2")

close_terminal(first)
local third = open_plain_terminal()
assert(terminal.label_for_buf(second) == "T:2", "remaining terminals retain their labels")
assert(terminal.label_for_buf(third) == "T:3", "new terminals continue the active sequence")

close_terminal(second)
close_terminal(third)
local reset = open_plain_terminal()
assert(terminal.label_for_buf(reset) == "T:1", "the sequence resets after every plain terminal closes")

close_terminal(reset)
close_terminal(ai_buf)

print("terminal_labels OK")
