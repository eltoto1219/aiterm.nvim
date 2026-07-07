-- Run: nvim --headless --clean -l tests/smoke.lua
local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

local modules = {
    "aiterm",
    "aiterm.config",
    "aiterm.terminal",
    "aiterm.ai",
    "aiterm.buffers",
    "aiterm.processes",
    "aiterm.process_backend",
    "aiterm.treehouse",
    "aiterm.run",
    "aiterm.tabline",
    "aiterm.health",
    "aiterm.ui.picker",
    "aiterm.ui.input",
    "aiterm.ui.colors",
}
for _, name in ipairs(modules) do
    require(name)
end

-- Default setup: core commands exist, opt-in modules stay off.
require("aiterm").setup({})
local commands = vim.api.nvim_get_commands({})
assert(commands.TerminalRename, "terminal command registered")
assert(commands.Claude and commands.Codex and commands.AIRestore, "ai commands registered")
assert(commands.TerminalConfig, "run command registered")
assert(commands.TerminalProcesses == nil, "processes stay opt-in")

-- Safe defaults: no permission-bypassing flags unless opted in.
local ai = require("aiterm.ai")
local claude_argv = table.concat(ai.commands.claude(nil, false), " ")
assert(not claude_argv:find("dangerously", 1, true), "no dangerous claude flags by default")
local codex_argv = table.concat(ai.commands.codex(nil, false), " ")
assert(not codex_argv:find("dangerously", 1, true), "no dangerous codex flags by default")

-- Opting in wires args, custom kinds, and opt-in modules.
require("aiterm").setup({
    ai = {
        kinds = {
            claude = { args = { "--dangerously-skip-permissions" } },
            myharness = {
                args = {},
                command = function()
                    return { "myharness" }
                end,
            },
        },
    },
    processes = { enabled = true, session_prefix = "custom-prefix-" },
    treehouse = { enabled = true, mappings = { status = "<leader>fs" } },
})
commands = vim.api.nvim_get_commands({})
assert(commands.TerminalProcesses and commands.TerminalProcessNew, "processes commands registered when enabled")
assert(commands.Myharness, "custom kind gets a generated command")
claude_argv = table.concat(ai.commands.claude(nil, false), " ")
assert(claude_argv:find("--dangerously-skip-permissions", 1, true), "opted-in claude args applied")
assert(vim.tbl_contains(ai.kind_names(), "myharness"), "custom kind listed")
assert(require("aiterm.process_backend").session_name("x") == "custom-prefix-x", "session prefix configurable")

local treehouse_map
for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
    if map.desc == "Treehouse: status" then
        treehouse_map = true
    end
end
assert(treehouse_map, "treehouse mapping registered from opts")

-- Pure logic: color math and run template rendering via public surfaces.
local colors = require("aiterm.ui.colors")
assert(colors.to_hex(0xff0000) == "#ff0000", "color hex conversion")
assert(colors.blend(0x000000, 0xffffff, 0.5) ~= nil, "color blend")

print("smoke OK")
