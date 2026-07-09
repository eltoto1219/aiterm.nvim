-- Run: nvim --headless --clean -l tests/codex_duplicate_repair.lua
local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(script), ".."))
local temp = vim.fn.tempname()
local bin = vim.fs.joinpath(temp, "bin")
local cwd = vim.fs.joinpath(temp, "work")
local sessions = vim.fs.joinpath(temp, "sessions")
local resumes = vim.fs.joinpath(temp, "resumes")
local session_ids = {
    "11111111-1111-4111-8111-111111111111",
    "22222222-2222-4222-8222-222222222222",
    "33333333-3333-4333-8333-333333333333",
}

vim.fn.mkdir(bin, "p")
vim.fn.mkdir(cwd, "p")
vim.fn.mkdir(vim.fs.joinpath(sessions, "2026", "07", "09"), "p")
vim.env.XDG_STATE_HOME = vim.fs.joinpath(temp, "state")
vim.opt.rtp:prepend(root)

for index, id in ipairs(session_ids) do
    vim.fn.writefile({
        vim.json.encode({ type = "session_meta", payload = { id = id, cwd = cwd } }),
        vim.json.encode({ type = "event_msg", payload = { type = "user_message", message = "same title" } }),
    }, vim.fs.joinpath(sessions, "2026", "07", "09", "rollout-" .. index .. "-" .. id .. ".jsonl"))
end

local registry = vim.fs.joinpath(vim.fn.stdpath("state"), "aiterm", "ai_sessions.json")
vim.fn.mkdir(vim.fs.dirname(registry), "p")
local entries = {}
for index = 1, #session_ids do
    entries[index] = {
        key = "44444444-4444-4444-8444-" .. string.format("%012d", index),
        kind = "codex",
        id = session_ids[#session_ids],
        cwd = cwd,
        title = "same title",
        last_used = os.time(),
    }
end
vim.fn.writefile({ vim.json.encode(entries) }, registry)

require("aiterm").setup({
    ai = {
        autostart = false,
        restore = true,
        codex_sessions_dir = sessions,
        kinds = {
            codex = {
                args = {},
                command = function(entry, resume)
                    if resume then
                        vim.fn.writefile({ entry.id }, resumes, "a")
                    end
                    return { "sh", "-c", "sleep 30" }
                end,
            },
        },
    },
})

local ok, repaired_entries = pcall(vim.json.decode, table.concat(vim.fn.readfile(registry), "\n"))
assert(ok and type(repaired_entries) == "table", "repaired registry is valid JSON")
local repaired_ids = {}
for _, entry in ipairs(repaired_entries) do
    repaired_ids[entry.id] = true
end
assert(vim.tbl_count(repaired_ids) == #session_ids, "repaired registry persists distinct Codex IDs")

vim.cmd.cd(cwd)
assert(require("aiterm.ai").restore_here(), "duplicate Codex entries restored")
assert(
    vim.wait(1000, function()
        return vim.fn.filereadable(resumes) == 1 and #vim.fn.readfile(resumes) == #session_ids
    end, 10),
    "every cached Codex session resumed"
)

local resumed_ids = {}
for _, id in ipairs(vim.fn.readfile(resumes)) do
    resumed_ids[id] = true
end
assert(vim.tbl_count(resumed_ids) == #session_ids, "duplicate cached IDs are repaired before restore")

print("codex_duplicate_repair OK")
