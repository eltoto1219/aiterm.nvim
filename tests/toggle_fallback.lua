-- Run: nvim --headless --clean -l tests/toggle_fallback.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

require("aiterm").setup({})

local ai = require("aiterm.ai")
local terminal = require("aiterm.terminal")

assert(vim.api.nvim_buf_get_name(0) == "", "test starts without a named file buffer")

local ai_buf = terminal.open_command({ "sh" }, "ai-test", { ai_kind = "claude" })
assert(ai_buf and vim.api.nvim_get_current_buf() == ai_buf, "AI terminal spawned and focused")

terminal.toggle()
local term_buf = vim.api.nvim_get_current_buf()
assert(
    term_buf ~= ai_buf and terminal.is_terminal(term_buf) and vim.b[term_buf].aiterm_ai_kind == nil,
    "terminal toggle opens a plain terminal from AI"
)

terminal.toggle()
assert(
    vim.api.nvim_get_current_buf() == ai_buf,
    "terminal toggle falls back to most recent non-terminal-workflow buffer"
)

ai.toggle()
assert(vim.api.nvim_get_current_buf() == term_buf, "AI toggle falls back to most recent non-AI buffer")

print("toggle fallback OK")
