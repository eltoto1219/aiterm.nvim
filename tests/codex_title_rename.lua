-- Run: nvim --headless --clean -l tests/codex_title_rename.lua
local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(script), ".."))
local temp = vim.fn.tempname()
local bin = vim.fs.joinpath(temp, "bin")
local cwd = vim.fs.joinpath(temp, "work")
local sessions = vim.fs.joinpath(temp, "sessions")
local state_db = vim.fs.joinpath(temp, "state.sqlite")
local thread_id = "11111111-1111-4111-8111-111111111111"
local session_key = "22222222-2222-4222-8222-222222222222"

vim.fn.mkdir(bin, "p")
vim.fn.mkdir(cwd, "p")
vim.fn.mkdir(vim.fs.joinpath(sessions, "2026", "07", "08"), "p")
vim.fn.writefile({ "#!/bin/sh", "sleep 30" }, vim.fs.joinpath(bin, "codex"))
vim.fn.setfperm(vim.fs.joinpath(bin, "codex"), "rwxr-xr-x")

vim.env.PATH = bin .. ":" .. vim.env.PATH
vim.env.XDG_STATE_HOME = vim.fs.joinpath(temp, "state")
vim.opt.rtp:prepend(root)

vim.fn.writefile(
    { '{"type":"event_msg","payload":{"type":"user_message","message":"hello"}}' },
    vim.fs.joinpath(sessions, "2026", "07", "08", "rollout-2026-07-08T12-00-00-" .. thread_id .. ".jsonl")
)

local registry = vim.fs.joinpath(vim.fn.stdpath("state"), "aiterm", "ai_sessions.json")
vim.fn.mkdir(vim.fs.dirname(registry), "p")
vim.fn.writefile({
    vim.json.encode({
        {
            key = session_key,
            kind = "codex",
            id = thread_id,
            cwd = cwd,
            title = "Initial Title",
            last_used = os.time(),
        },
    }),
}, registry)

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
    tabline = { enabled = true },
    ai = {
        restore = true,
        autostart = false,
        codex_sessions_dir = sessions,
        kinds = {
            codex = {
                args = {},
                command = function()
                    return { "sh", vim.fs.joinpath(bin, "codex") }
                end,
            },
        },
    },
})

local ai = require("aiterm.ai")
ai.codex_state_db = state_db

vim.cmd.cd(cwd)
local bufnr = ai.restore_here()
assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "cached codex session restored")

local terminal = require("aiterm.terminal")
assert(terminal.label_for_buf(bufnr) == "Initial Title", "restored codex session starts with its cached title")

python([[
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute('update threads set title = ? where id = ?', ('temp', sys.argv[2]))
con.commit()
]])

assert(
    vim.wait(7000, function()
        return terminal.label_for_buf(bufnr) == "temp" and require("aiterm.tabline").component():find("temp", 1, true)
    end, 100),
    "codex title rename updates the restored session label and tabline"
)

if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end

print("codex_title_rename OK")
