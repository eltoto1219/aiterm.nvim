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
assert(prompt_lines[1] == "> ", "picker exposes a concise search prompt")
assert(vim.api.nvim_win_get_height(prompt_winid) == 1, "picker search prompt is one line tall")
assert(
    (vim.wo[list_winid].winhighlight or ""):find("CursorLine:AitermPickerSelected", 1, true),
    "picker uses its selected-line highlight"
)
assert(vim.fn.hlexists("AitermPickerPrompt") == 1, "picker defines a highlighted search prompt")
local escape_mapping = nil
for _, map in ipairs(vim.api.nvim_buf_get_keymap(prompt_bufnr, "i")) do
    assert(map.lhs ~= "jk", "picker does not install an insert-mode jk mapping")
    if map.desc == "Picker: focus options" then
        escape_mapping = map
    end
end
assert(
    escape_mapping and type(escape_mapping.callback) == "function",
    "escape leaves search for picker options in insert mode"
)

assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "i"
    end),
    "picker starts in live Search input"
)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
assert(
    vim.wait(100, function()
        return vim.api.nvim_get_current_win() == list_winid
    end),
    "escape exits Search and focuses picker options"
)
vim.api.nvim_feedkeys("j", "x", false)
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
assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "i"
    end),
    "returning to Search restores insert mode"
)

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

vim.api.nvim_buf_set_lines(prompt_bufnr, 0, 1, false, { "> gm" })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt_bufnr })
lines = vim.api.nvim_buf_get_lines(list_bufnr, 0, -1, false)
assert(lines[1] == "3. Gamma", "picker filters with fuzzy matching")

vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

assert(
    vim.wait(1000, function()
        return selected == 3
    end),
    "picker selection returns the original item index"
)

local numbered_selection = nil
require("aiterm.ui.picker").select("Pick by number:", { "Alpha", "Beta", "Gamma" }, function(index)
    numbered_selection = index
end)

local numbered_prompt_winid = vim.api.nvim_get_current_win()
local numbered_list_bufnr = nil
for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if winid ~= numbered_prompt_winid and vim.api.nvim_win_get_config(winid).relative == "editor" then
        numbered_list_bufnr = vim.api.nvim_win_get_buf(winid)
        break
    end
end
assert(numbered_list_bufnr ~= nil, "numbered picker opens an option list")
assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "i"
    end),
    "numbered picker starts in insert mode"
)
vim.api.nvim_feedkeys("2", "x", false)
assert(
    vim.wait(1000, function()
        local numbered_lines = vim.api.nvim_buf_get_lines(numbered_list_bufnr, 0, -1, false)
        return #numbered_lines == 1 and numbered_lines[1] == "2. Beta"
    end),
    "typing an option number filters to that exact option"
)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
assert(
    vim.wait(1000, function()
        return numbered_selection == 2
    end),
    "enter executes the option selected by number"
)

local picker = require("aiterm.ui.picker")
picker.select("First prompt:", { "Run now" }, function()
    picker.select("Second prompt:", { "Keep graph output in Git", "Ignore graph output in Git" }, function() end)
end)
assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "i" and vim.api.nvim_get_current_line() == "> "
    end),
    "first chained picker starts in its live prompt"
)
vim.api.nvim_feedkeys("1", "x", false)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "i" and vim.api.nvim_get_current_line() == "> "
    end),
    "second chained picker automatically owns live prompt input"
)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "n" and vim.api.nvim_get_current_line() == "1. Keep graph output in Git"
    end),
    "second chained picker can enter normal-mode option navigation"
)
vim.api.nvim_feedkeys("a", "x", false)
assert(
    vim.wait(1000, function()
        return vim.fn.mode() == "i" and vim.api.nvim_get_current_line() == "> "
    end),
    "append returns the second chained picker to live prompt input"
)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc><Esc>", true, false, true), "x", false)
vim.wait(100)

local canceled = false
require("aiterm.ui.picker").select("Cancel on leave:", { "Alpha", "Beta" }, function() end, function()
    canceled = true
end)

prompt_winid = vim.api.nvim_get_current_win()
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
