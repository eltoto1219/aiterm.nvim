-- Run: nvim --headless --clean -l tests/codex_title_rename.lua
local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(script), ".."))
local temp = vim.fn.tempname()
local bin = vim.fs.joinpath(temp, "bin")
local cwd = vim.fs.joinpath(temp, "work")
local sessions = vim.fs.joinpath(temp, "sessions")
local state_db = vim.fs.joinpath(temp, "state.sqlite")
local thread_id = "11111111-1111-4111-8111-111111111111"

vim.fn.mkdir(bin, "p")
vim.fn.mkdir(cwd, "p")
vim.fn.mkdir(vim.fs.joinpath(sessions, "2026", "07", "08"), "p")
vim.fn.writefile({ "#!/bin/sh", "sleep 30" }, vim.fs.joinpath(bin, "codex"))
vim.fn.setfperm(vim.fs.joinpath(bin, "codex"), "rwxr-xr-x")

vim.env.PATH = bin .. ":" .. vim.env.PATH
vim.env.XDG_STATE_HOME = vim.fs.joinpath(temp, "state")
vim.opt.rtp:prepend(root)

local function python(script_body)
    local result = vim.fn.system({ "python3", "-c", script_body, state_db, thread_id })
    assert(vim.v.shell_error == 0, result)
end

python([[
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute('create table threads (id text primary key, title text)')
con.execute('insert into threads (id, title) values (?, ?)', (sys.argv[2], 'Initial Title'))
con.commit()
]])

require("aiterm").setup({
    ai = {
        restore = false,
        autostart = false,
        codex_sessions_dir = sessions,
        kinds = {
            codex = {
                args = {},
                command = function()
                    return { "codex" }
                end,
            },
        },
    },
})

local ai = require("aiterm.ai")
ai.codex_state_db = state_db

local bufnr = ai.open("codex", cwd)
assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "codex session opened")

vim.fn.writefile(
    { "{}" },
    vim.fs.joinpath(sessions, "2026", "07", "08", "rollout-2026-07-08T12-00-00-" .. thread_id .. ".jsonl")
)

local terminal = require("aiterm.terminal")
assert(
    vim.wait(7000, function()
        return terminal.label_for_buf(bufnr) == "Initial Title"
    end, 100),
    "codex title is read from state db"
)

python([[
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute('update threads set title = ? where id = ?', ('temp', sys.argv[2]))
con.commit()
]])

assert(
    vim.wait(5000, function()
        return terminal.label_for_buf(bufnr) == "temp"
    end, 100),
    "codex title rename updates the live label"
)

if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end

print("codex_title_rename OK")
