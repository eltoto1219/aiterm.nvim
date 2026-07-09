-- Run: nvim --headless --clean -l tests/terminal_insert_resume.lua
local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(script), ".."))
vim.opt.rtp:prepend(root)

require("aiterm").setup({
    terminal = { style = false },
})

local terminal = require("aiterm.terminal")
local bufnr = terminal.open_command({ "sh", "-c", "printf 'abcdefghij\\n'; sleep 30" }, "insert-resume-test")
assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "terminal opened")
local input_row = nil
assert(vim.wait(1000, function()
    for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        if line:find("abcdefghij", 1, true) then
            input_row = row
            return true
        end
    end
    return false
end), "test terminal line found")

vim.cmd.stopinsert()
assert(vim.wait(1000, function()
    return vim.fn.mode() == "n"
end), "entered terminal normal mode")

local resume_i = nil
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if mapping.lhs == "i" then
        resume_i = mapping.callback
        break
    end
end
assert(type(resume_i) == "function", "insert-resume mapping callback exists")

local original_feedkeys = vim.api.nvim_feedkeys
local captured = {}
vim.api.nvim_feedkeys = function(keys, mode, escape_ks)
    captured[#captured + 1] = keys
    return original_feedkeys(keys, mode, escape_ks)
end

local function encoded(keys)
    return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

vim.api.nvim_win_set_cursor(0, { input_row, 3 })
vim.b[bufnr].aiterm_terminal_input_cursor = { input_row, 5 }
assert(
    vim.deep_equal(vim.api.nvim_win_get_cursor(0), { input_row, 3 }),
    "test cursor placed in live input: " .. vim.inspect(vim.api.nvim_win_get_cursor(0))
)
resume_i()
assert(vim.wait(1000, function()
    return #captured == 1
end), "live input resume sent movement keys")
assert(
    captured[1] == encoded("<Left><Left><Left>"),
    "live input resume applies one-column terminal offset: " .. vim.inspect(captured[1])
)

captured = {}
vim.cmd.stopinsert()
assert(vim.wait(1000, function()
    return vim.fn.mode() == "n"
end), "re-entered terminal normal mode")
vim.api.nvim_win_set_cursor(0, { input_row, 3 })
vim.b[bufnr].aiterm_terminal_input_cursor = { input_row + 1, 5 }
resume_i()
vim.wait(100)
assert(#captured == 0, "scrollback resume preserves the previous terminal input cursor")

vim.api.nvim_feedkeys = original_feedkeys
if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end

print("terminal_insert_resume OK")
