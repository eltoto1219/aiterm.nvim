local root = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."))
vim.opt.rtp:prepend(root)

local temporary = vim.fn.tempname()
local repository = vim.fs.joinpath(temporary, "repository")
local state = vim.fs.joinpath(temporary, "state")
local executable = vim.fs.joinpath(temporary, "graphify")
local log = vim.fs.joinpath(temporary, "graphify.log")
vim.fn.mkdir(repository, "p")
vim.fn.mkdir(state, "p")
vim.env.XDG_STATE_HOME = state
vim.env.GRAPHIFY_TEST_LOG = log

vim.fn.writefile({
    "#!/bin/sh",
    "set -eu",
    'printf \'%s\\n\' "$*" >> "$GRAPHIFY_TEST_LOG"',
    'case "$1" in',
    "  extract)",
    '    mkdir -p "$2/graphify-out"',
    '    printf \'{\\"nodes\\": [], \\"links\\": []}\\n\' > "$2/graphify-out/graph.json"',
    "    ;;",
    "  update)",
    '    mkdir -p "$2/graphify-out"',
    '    printf \'{\\"nodes\\": [], \\"links\\": []}\\n\' > "$2/graphify-out/graph.json"',
    "    ;;",
    "  cluster-only)",
    "    printf '<html></html>\\n' > \"$2/graphify-out/graph.html\"",
    "    ;;",
    "  query|explain|path)",
    "    printf '%s result\\n' \"$1\"",
    "    ;;",
    "esac",
}, executable)
assert(vim.fn.system({ "chmod", "+x", executable }) == "", "fake graphify is executable")

vim.fn.writefile({ "local M = {}", "return M" }, vim.fs.joinpath(repository, "example.lua"))
assert(vim.fn.system({ "git", "init", "-q", repository }) == "", "test repository initialized")
assert(
    vim.fn.system({ "git", "-C", repository, "config", "user.email", "test@example.com" }) == "",
    "test email configured"
)
assert(vim.fn.system({ "git", "-C", repository, "config", "user.name", "Test User" }) == "", "test name configured")
assert(vim.fn.system({ "git", "-C", repository, "add", "." }) == "", "test file staged")
assert(vim.fn.system({ "git", "-C", repository, "commit", "-qm", "initial" }) == "", "test repository committed")

require("aiterm").setup({
    graphify = {
        enabled = true,
        executable = executable,
        missing_graph = "build",
        stale_graph = "update",
        build = { output = "scratch", timeout_ms = 2000 },
    },
})

local graphify = require("aiterm.graphify")
assert(graphify.root(vim.fs.joinpath(repository, "example.lua")) == repository, "Graphify resolves the Git root")
assert(graphify.status(repository).kind == "missing", "new repository graph is missing")

assert(graphify.build(repository, { output = "scratch" }), "Graphify build starts")
assert(
    vim.wait(2000, function()
        return graphify.status(repository).kind == "fresh"
    end),
    "Graphify build completes"
)
assert(
    vim.fn.filereadable(vim.fs.joinpath(repository, "graphify-out", "graph.html")) == 1,
    "Graphify build writes graph HTML"
)
assert(vim.fn.filereadable(vim.fs.joinpath(repository, ".graphifyignore")) == 1, "Graphify ignore file created")
local ignore = table.concat(vim.fn.readfile(vim.fs.joinpath(repository, ".graphifyignore")), "\n")
assert(ignore:find("node_modules/", 1, true), "baseline ignore excludes dependencies")
assert(ignore:find("*.png", 1, true), "safe baseline ignore excludes images")
assert(ignore:find("*.parquet", 1, true), "safe baseline ignore excludes data")

assert(vim.fn.delete(vim.fs.joinpath(repository, "graphify-out"), "rf") == 0, "test graph removed")
assert(graphify.status(repository).kind == "missing", "removed graph is detected")
require("aiterm.ai").prepare_workspace("codex", repository)
assert(
    vim.wait(2000, function()
        return graphify.status(repository).kind == "fresh"
    end),
    "AI workspace preparation starts a configured missing-graph build"
)

local commands = vim.api.nvim_get_commands({})
for _, name in ipairs({
    "AitermGraphifyStatus",
    "AitermGraphifyBuild",
    "AitermGraphifyUpdate",
    "AitermGraphifyQuery",
    "AitermGraphifyExplain",
    "AitermGraphifyPath",
    "AitermGraphifyOpen",
}) do
    assert(commands[name], name .. " command registered")
end

vim.fn.writefile({ "local M = { changed = true }", "return M" }, vim.fs.joinpath(repository, "example.lua"))
assert(vim.fn.system({ "git", "-C", repository, "add", "." }) == "", "changed file staged")
assert(vim.fn.system({ "git", "-C", repository, "commit", "-qm", "changed" }) == "", "changed file committed")
assert(graphify.status(repository).kind == "stale", "Git commit marks graph stale")
assert(graphify.update(repository, { output = "scratch" }), "Graphify update starts")
assert(
    vim.wait(2000, function()
        return graphify.status(repository).kind == "fresh"
    end),
    "Graphify update completes"
)

assert(graphify.query("what is this?", repository), "Graphify query starts")
assert(
    vim.wait(2000, function()
        return graphify.status(repository).kind ~= "building"
    end),
    "Graphify query completes"
)
assert(graphify.explain("example", repository), "Graphify explain starts")
assert(
    vim.wait(2000, function()
        return graphify.status(repository).kind ~= "building"
    end),
    "Graphify explain completes"
)
assert(graphify.path("example", "M", repository), "Graphify path starts")
assert(
    vim.wait(2000, function()
        return graphify.status(repository).kind ~= "building"
    end),
    "Graphify graph commands complete"
)

local calls = table.concat(vim.fn.readfile(log), "\n")
assert(calls:find("extract " .. repository .. " --code-only", 1, true), "build uses local code-only extraction")
assert(
    calls:find("cluster-only " .. repository .. " --no-label", 1, true),
    "build clusters without an LLM and writes graph HTML"
)
assert(calls:find("update " .. repository, 1, true), "update uses Graphify incremental update")
assert(calls:find("query what is this? --graph", 1, true), "query scopes Graphify to the repository graph")
assert(calls:find("explain example --graph", 1, true), "explain scopes Graphify to the repository graph")
assert(calls:find("path example M --graph", 1, true), "path scopes Graphify to the repository graph")

local custom_ignore_root = vim.fs.joinpath(temporary, "custom-ignore")
vim.fn.mkdir(custom_ignore_root, "p")
vim.fn.writefile({ "custom/" }, vim.fs.joinpath(custom_ignore_root, ".graphifyignore"))
assert(not graphify.ensure_ignore(custom_ignore_root), "existing ignore file is preserved")
assert(
    table.concat(vim.fn.readfile(vim.fs.joinpath(custom_ignore_root, ".graphifyignore")), "\n") == "custom/",
    "aiterm never edits an existing Graphify ignore file"
)

vim.fn.delete(temporary, "rf")
print("graphify OK")
