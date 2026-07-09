-- Run: nvim --headless --clean -l tests/codex_qa_multi_session.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
local temp = vim.fn.tempname()
local bin = vim.fs.joinpath(temp, "bin")
local home = vim.fs.joinpath(temp, "home")
local cwd = vim.fs.joinpath(temp, "project")
local state = vim.fs.joinpath(temp, "state")
local resumes = vim.fs.joinpath(temp, "resumes")
local session_ids = {
    "11111111-1111-4111-8111-111111111111",
    "22222222-2222-4222-8222-222222222222",
    "33333333-3333-4333-8333-333333333333",
}
local rollout_command = table.concat({
    'printf \'{"type":"session_meta","payload":{"id":"%s"}}\\n',
    '{"type":"event_msg","payload":{"type":"user_message","message":"hello"}}\\n\' "$id"',
    ' > "$HOME/.codex/sessions/2026/07/09/rollout-2026-07-09T12-00-00-$id.jsonl"',
})

vim.fn.mkdir(bin, "p")
vim.fn.mkdir(home, "p")
vim.fn.mkdir(cwd, "p")
vim.fn.mkdir(state, "p")

local fake_codex = vim.fs.joinpath(bin, "codex")
vim.fn.writefile({
    "#!/bin/sh",
    'mkdir -p "$HOME/.codex/sessions/2026/07/09"',
    'id="${CODEX_SESSION_ID:?}"',
    rollout_command,
    "sleep 30",
}, fake_codex)
vim.fn.setfperm(fake_codex, "rwxr-xr-x")

vim.env.HOME = home
vim.env.XDG_STATE_HOME = state
vim.env.PATH = bin .. ":" .. vim.env.PATH
vim.opt.rtp:prepend(root)

local next_id = 0
require("aiterm").setup({
    ai = {
        autostart = false,
        restore = false,
        kinds = {
            codex = {
                command = function(entry, resume)
                    if resume then
                        vim.fn.writefile({ entry.id }, resumes, "a")
                        return { "sh", "-c", "sleep 30" }
                    end
                    next_id = next_id + 1
                    return { "env", "CODEX_SESSION_ID=" .. session_ids[next_id], "sh", fake_codex }
                end,
            },
        },
    },
})

local ai = require("aiterm.ai")
local buffers = {}
for _ = 1, #session_ids do
    local bufnr = ai.open("codex", cwd)
    assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "fake Codex session opened")
    buffers[#buffers + 1] = bufnr
end

assert(
    vim.wait(500, function()
        local sessions = vim.fs.joinpath(home, ".codex", "sessions")
        return #vim.fn.globpath(sessions, "**/rollout-*.jsonl", true, true) == #session_ids
    end),
    "all Codex rollout files created before quit"
)

vim.api.nvim_exec_autocmds("QuitPre", {})
for _, bufnr in ipairs(buffers) do
    vim.cmd.bwipeout({ args = { tostring(bufnr) }, bang = true })
end
vim.api.nvim_exec_autocmds("VimLeavePre", {})

local registry = vim.fs.joinpath(vim.fn.stdpath("state"), "aiterm", "ai_sessions.json")
assert(vim.fn.filereadable(registry) == 1, "AI session registry written")

local ok, entries = pcall(vim.json.decode, table.concat(vim.fn.readfile(registry), "\n"))
assert(ok and type(entries) == "table", "AI session registry is valid JSON")
assert(#entries == #session_ids, "every Codex session wiped during qa is persisted")

local restored_ids = {}
for _, entry in ipairs(entries) do
    restored_ids[entry.id] = true
end
assert(vim.tbl_count(restored_ids) == #session_ids, "every persisted session keeps its distinct Codex id")

vim.cmd.cd(vim.fn.fnameescape(cwd))
assert(ai.restore_here(), "every persisted session is restored")
assert(
    vim.wait(500, function()
        return #vim.fn.readfile(resumes) == #session_ids
    end),
    "every persisted session starts a restored buffer"
)

local resumed_ids = {}
for _, id in ipairs(vim.fn.readfile(resumes)) do
    resumed_ids[id] = true
end
assert(vim.tbl_count(resumed_ids) == #session_ids, "every restored buffer resumes a distinct Codex session")

print("codex_qa_multi_session OK")
