-- Run: nvim --headless --clean -l tests/picker.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

vim.o.columns = 80
vim.o.lines = 24

require("aiterm").setup({})
vim.keymap.set("i", "jk", "<Esc>", { noremap = true })
local base_winid = vim.api.nvim_get_current_win()

local selected = nil
require("aiterm.ui.picker").select("Pick one:", { "Alpha", "Beta", "Gamma" }, function(index)
    selected = index
end)

local prompt_winid = vim.api.nvim_get_current_win()
local prompt_bufnr = vim.api.nvim_win_get_buf(prompt_winid)
local list_winid = nil
for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if winid ~= prompt_winid and vim.api.nvim_win_get_config(winid).relative == "editor" then
        list_winid = winid
        break
    end
end
assert(list_winid ~= nil, "picker opens a separate list window")

local list_bufnr = vim.api.nvim_win_get_buf(list_winid)
local ns = vim.api.nvim_create_namespace("aiterm_picker")
local lines = vim.api.nvim_buf_get_lines(list_bufnr, 0, -1, false)
local prompt_lines = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)

assert(lines[1] == "1. Alpha", "first picker item is numbered")
assert(lines[2] == "2. Beta", "second picker item is numbered")
assert(lines[3] == "3. Gamma", "third picker item is numbered")
assert(#lines == 3, "picker list does not include the search prompt")
assert(prompt_lines[1] == "Search: ", "picker exposes a separate search prompt")
assert(vim.api.nvim_win_get_height(prompt_winid) == 1, "picker search prompt is one line tall")
assert(
    (vim.wo[list_winid].winhighlight or ""):find("CursorLine:AitermPickerSelected", 1, true),
    "picker uses its selected-line highlight"
)
assert(vim.fn.hlexists("AitermPickerPrompt") == 1, "picker defines a highlighted search prompt")
for _, map in ipairs(vim.api.nvim_buf_get_keymap(prompt_bufnr, "i")) do
    assert(map.lhs ~= "jk", "picker does not install an insert-mode jk mapping")
end

vim.api.nvim_feedkeys("jkj", "x", false)
vim.wait(20)
assert(vim.api.nvim_get_current_win() == list_winid, "leaving insert mode focuses picker options")
local marks = vim.api.nvim_buf_get_extmarks(list_bufnr, ns, 0, -1, { details = true })
local selected_row = nil
for _, mark in ipairs(marks) do
    if mark[4].line_hl_group == "AitermPickerSelected" then
        selected_row = mark[2]
    end
end
assert(selected_row == 1, "normal-mode j moves to the next picker item")

vim.api.nvim_feedkeys("k", "x", false)
vim.wait(20)
marks = vim.api.nvim_buf_get_extmarks(list_bufnr, ns, 0, -1, { details = true })
selected_row = nil
for _, mark in ipairs(marks) do
    if mark[4].line_hl_group == "AitermPickerSelected" then
        selected_row = mark[2]
    end
end
assert(selected_row == 0, "normal-mode k moves to the previous picker item")

vim.api.nvim_feedkeys("i", "x", false)
vim.wait(100, function()
    return vim.api.nvim_get_current_win() == prompt_winid
end)
assert(vim.api.nvim_get_current_win() == prompt_winid, "entering insert mode focuses picker search")

vim.api.nvim_feedkeys("jk", "x", false)
vim.wait(100, function()
    return vim.api.nvim_get_current_win() == list_winid
end)
assert(vim.api.nvim_get_current_win() == list_winid, "user insert-exit mapping focuses options again")

vim.api.nvim_feedkeys("a", "x", false)
vim.wait(100, function()
    return vim.api.nvim_get_current_win() == prompt_winid
end)
assert(vim.api.nvim_get_current_win() == prompt_winid, "append insert mode focuses picker search")
lines = vim.api.nvim_buf_get_lines(list_bufnr, 0, -1, false)
assert(lines[1] == "1. Alpha", "append insert mode does not edit picker options")

vim.api.nvim_buf_set_lines(prompt_bufnr, 0, 1, false, { "Search: gm" })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt_bufnr })
lines = vim.api.nvim_buf_get_lines(list_bufnr, 0, -1, false)
assert(lines[1] == "3. Gamma", "picker filters with fuzzy matching")

vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

assert(selected == 3, "picker selection returns the original item index")

local canceled = false
require("aiterm.ui.picker").select("Cancel on leave:", { "Alpha", "Beta" }, function() end, function()
    canceled = true
end)

prompt_winid = vim.api.nvim_get_current_win()
prompt_bufnr = vim.api.nvim_win_get_buf(prompt_winid)
list_winid = nil
for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if winid ~= prompt_winid and vim.api.nvim_win_get_config(winid).relative == "editor" then
        list_winid = winid
        break
    end
end
assert(list_winid ~= nil, "second picker opens a separate list window")

vim.api.nvim_set_current_win(base_winid)
vim.wait(100)
assert(canceled, "picker cancels when focus leaves the popup")
assert(not vim.api.nvim_win_is_valid(prompt_winid), "picker prompt closes when focus leaves")
assert(not vim.api.nvim_win_is_valid(list_winid), "picker list closes when focus leaves")

print("picker OK")
