-- Run: nvim --headless --clean -l tests/unused_claude.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
local temp = vim.fn.tempname()
local bin = vim.fs.joinpath(temp, "bin")
local home = vim.fs.joinpath(temp, "home")
local cwd = vim.fs.joinpath(temp, "project")

vim.fn.mkdir(bin, "p")
vim.fn.mkdir(home, "p")
vim.fn.mkdir(cwd, "p")

local fake_claude = vim.fs.joinpath(bin, "claude")
vim.fn.writefile({
    "#!/bin/sh",
    "while [ $# -gt 0 ]; do",
    '  case "$1" in',
    "    --resume)",
    '      echo "cannot find conversation with ID: $2" >&2',
    "      exit 1",
    "      ;;",
    "  esac",
    "  shift",
    "done",
    "sleep 30",
}, fake_claude)
vim.fn.setfperm(fake_claude, "rwxr-xr-x")

vim.env.HOME = home
vim.env.PATH = bin .. ":" .. vim.env.PATH
vim.opt.rtp:prepend(root)

require("aiterm").setup({ ai = { autostart = false, restore = false } })

local ai = require("aiterm.ai")
local bufnr = ai.open("claude", cwd)
assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "fake Claude session opened")

vim.api.nvim_exec_autocmds("VimLeavePre", {})

local registry = vim.fs.joinpath(vim.fn.stdpath("state"), "aiterm", "ai_sessions.json")
assert(vim.fn.filereadable(registry) == 1, "AI session registry written")

local ok, entries = pcall(vim.json.decode, table.concat(vim.fn.readfile(registry), "\n"))
assert(ok and type(entries) == "table", "AI session registry is valid JSON")
assert(#entries == 0, "unused Claude session is not persisted as restorable")

vim.cmd.bwipeout({ args = { tostring(bufnr) }, bang = true })
print("unused Claude OK")
