-- Run: nvim --headless --clean -l tests/unused_codex.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
local temp = vim.fn.tempname()
local bin = vim.fs.joinpath(temp, "bin")
local home = vim.fs.joinpath(temp, "home")
local cwd = vim.fs.joinpath(temp, "project")
local state = vim.fs.joinpath(temp, "state")
local session_id = "11111111-1111-4111-8111-111111111111"

vim.fn.mkdir(bin, "p")
vim.fn.mkdir(home, "p")
vim.fn.mkdir(cwd, "p")
vim.fn.mkdir(state, "p")

local fake_codex = vim.fs.joinpath(bin, "codex")
vim.fn.writefile({
    "#!/bin/sh",
    'mkdir -p "$HOME/.codex/sessions/2026/07/08"',
    (
        'echo \'{"type":"session_meta","payload":{"id":"%s"}}\''
        .. ' > "$HOME/.codex/sessions/2026/07/08/rollout-2026-07-08T12-00-00-%s.jsonl"'
    ):format(session_id, session_id),
    "sleep 30",
}, fake_codex)
vim.fn.setfperm(fake_codex, "rwxr-xr-x")

vim.env.HOME = home
vim.env.XDG_STATE_HOME = state
vim.env.PATH = bin .. ":" .. vim.env.PATH
vim.opt.rtp:prepend(root)

require("aiterm").setup({ ai = { autostart = false, restore = false } })

local bufnr = require("aiterm.ai").open("codex", cwd)
assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "fake Codex session opened")

assert(
    vim.wait(500, function()
        local sessions = vim.fs.joinpath(home, ".codex", "sessions")
        return #vim.fn.globpath(sessions, "**/rollout-*.jsonl", true, true) > 0
    end),
    "Codex rollout file created before quit"
)

vim.api.nvim_exec_autocmds("VimLeavePre", {})

local registry = vim.fs.joinpath(vim.fn.stdpath("state"), "aiterm", "ai_sessions.json")
assert(vim.fn.filereadable(registry) == 1, "AI session registry written")

local ok, entries = pcall(vim.json.decode, table.concat(vim.fn.readfile(registry), "\n"))
assert(ok and type(entries) == "table", "AI session registry is valid JSON")
assert(#entries == 0, "unused Codex session is not persisted as restorable")

vim.cmd.bwipeout({ args = { tostring(bufnr) }, bang = true })
print("unused Codex OK")
