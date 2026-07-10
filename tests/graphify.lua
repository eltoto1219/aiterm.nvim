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
vim.g.mapleader = " "

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
    mappings = {
        graphify = {
            open = "<leader>go",
        },
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

local opener_argv = nil
local system_open_path = nil
local original_has = vim.fn.has
local original_executable = vim.fn.executable
local original_jobstart = vim.fn.jobstart
local original_ui_open = vim.ui.open
vim.fn.has = function(feature)
    return feature == "unix" and 1 or 0
end
vim.fn.executable = function(command)
    return command == "sensible-browser" and 1 or 0
end
vim.fn.jobstart = function(argv, _)
    opener_argv = argv
    return 1
end
vim.ui.open = function(path)
    system_open_path = path
    return {}, nil
end
vim.cmd.cd(repository)
vim.api.nvim_feedkeys(" go", "x", false)
assert(opener_argv ~= nil, "Graphify open mapping starts an HTML opener")
opener_argv = nil
vim.cmd.AITermGraphifyOpen()
assert(opener_argv ~= nil, "Graphify open command uses the same HTML opener")
assert(opener_argv[1] == "sensible-browser", "Graphify HTML uses a browser instead of the text/html MIME handler")
assert(
    opener_argv[2] == vim.fs.joinpath(repository, "graphify-out", "graph.html"),
    "Graphify browser receives the generated HTML path: "
        .. vim.inspect({
            opener_argv = opener_argv,
            cwd = vim.fn.getcwd(),
            root = graphify.root(),
            buftype = vim.bo.buftype,
        })
)

opener_argv = nil
vim.fn.has = function(feature)
    return (feature == "mac" or feature == "unix") and 1 or 0
end
vim.fn.executable = function(command)
    return command == "open" and 1 or 0
end
assert(graphify.open_html(repository), "Graphify starts the macOS browser opener")
assert(opener_argv[1] == "open", "macOS uses its native open command")

opener_argv = nil
vim.fn.has = function(feature)
    return feature == "win32" and 1 or 0
end
vim.fn.executable = function(_)
    return 0
end
assert(graphify.open_html(repository), "Graphify falls back to Neovim's Windows opener")
assert(opener_argv == nil, "Windows fallback does not invoke a Unix browser command")
assert(
    system_open_path == vim.fs.joinpath(repository, "graphify-out", "graph.html"),
    "Windows fallback receives the generated HTML path"
)

require("aiterm.config").opts.graphify.ui.open_html = { "custom-browser", "--new-window" }
assert(graphify.open_html(repository), "Graphify accepts an OS-independent custom browser command")
assert(
    vim.deep_equal(opener_argv, {
        "custom-browser",
        "--new-window",
        vim.fs.joinpath(repository, "graphify-out", "graph.html"),
    }),
    "custom browser argv is passed without shell parsing"
)

require("aiterm.config").opts.graphify.ui.open_html = "browser"
vim.fn.has = original_has
vim.fn.executable = original_executable
vim.fn.jobstart = original_jobstart
vim.ui.open = original_ui_open

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
    "AITermGraphifyStatus",
    "AITermGraphifyBuild",
    "AITermGraphifyUpdate",
    "AITermGraphifyQuery",
    "AITermGraphifyExplain",
    "AITermGraphifyPath",
    "AITermGraphifyOpen",
    "AITermGraphifyResetPrompts",
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

local policy_repository = vim.fs.joinpath(temporary, "policy-repository")
vim.fn.mkdir(policy_repository, "p")
vim.fn.writefile({ "return {}" }, vim.fs.joinpath(policy_repository, "example.lua"))
assert(vim.fn.system({ "git", "init", "-q", policy_repository }) == "", "policy test repository initialized")
assert(
    vim.fn.system({ "git", "-C", policy_repository, "config", "user.email", "test@example.com" }) == "",
    "policy email configured"
)
assert(
    vim.fn.system({ "git", "-C", policy_repository, "config", "user.name", "Test User" }) == "",
    "policy name configured"
)
assert(vim.fn.system({ "git", "-C", policy_repository, "add", "." }) == "", "policy file staged")
assert(
    vim.fn.system({ "git", "-C", policy_repository, "commit", "-qm", "initial" }) == "",
    "policy repository committed"
)

local policy_prompts = {}
require("aiterm").setup({
    graphify = {
        enabled = true,
        executable = executable,
        missing_graph = "ask",
        build = { output = "scratch", timeout_ms = 2000 },
        ui = {
            confirm = function(choices, _, respond)
                policy_prompts[#policy_prompts + 1] = choices
                if choices[1] == "Run now" then
                    respond("Run now")
                else
                    respond("Ignore graph output in Git")
                end
            end,
        },
    },
})

graphify.prepare_workspace(policy_repository, { source = "startup" })
assert(
    vim.wait(2000, function()
        return graphify.status(policy_repository).kind == "fresh"
    end),
    "accepting a build starts Graphify after the output policy prompt"
)
assert(#policy_prompts == 2, "build confirmation is followed by the output policy confirmation")
assert(policy_prompts[2][2] == "Ignore graph output in Git", "output policy offers Git ignore")
local gitignore = table.concat(vim.fn.readfile(vim.fs.joinpath(policy_repository, ".gitignore")), "\n")
local graphifyignore = table.concat(vim.fn.readfile(vim.fs.joinpath(policy_repository, ".graphifyignore")), "\n")
assert(gitignore:find("graphify-out/", 1, true), "output policy adds graphify-out to .gitignore")
assert(graphifyignore:find("graphify-out/", 1, true), "output policy adds graphify-out to .graphifyignore")
assert(graphifyignore:find("node_modules/", 1, true), "output policy preserves the generated Graphify baseline")
assert(graphify.ignore_graph_output(policy_repository), "output ignore policy remains callable")
gitignore = table.concat(vim.fn.readfile(vim.fs.joinpath(policy_repository, ".gitignore")), "\n")
graphifyignore = table.concat(vim.fn.readfile(vim.fs.joinpath(policy_repository, ".graphifyignore")), "\n")
assert(select(2, gitignore:gsub("graphify%-out/", "")) == 1, "output policy does not duplicate .gitignore rules")
assert(
    select(2, graphifyignore:gsub("graphify%-out/", "")) == 1,
    "output policy does not duplicate .graphifyignore rules"
)

local skip_repository = vim.fs.joinpath(temporary, "skip-repository")
vim.fn.mkdir(skip_repository, "p")
vim.fn.writefile({ "return {}" }, vim.fs.joinpath(skip_repository, "example.lua"))
assert(vim.fn.system({ "git", "init", "-q", skip_repository }) == "", "skip test repository initialized")
assert(
    vim.fn.system({ "git", "-C", skip_repository, "config", "user.email", "test@example.com" }) == "",
    "skip email configured"
)
assert(
    vim.fn.system({ "git", "-C", skip_repository, "config", "user.name", "Test User" }) == "",
    "skip name configured"
)
assert(vim.fn.system({ "git", "-C", skip_repository, "add", "." }) == "", "skip file staged")
assert(vim.fn.system({ "git", "-C", skip_repository, "commit", "-qm", "initial" }) == "", "skip repository committed")

local prompts = 0
require("aiterm").setup({
    graphify = {
        enabled = true,
        executable = executable,
        missing_graph = "ask",
        ui = {
            confirm = function(choices, _, respond)
                prompts = prompts + 1
                assert(choices[3] == "Skip and don't ask again", "persistent skip is offered as the third choice")
                respond(choices[3])
            end,
        },
    },
})

graphify.prepare_workspace(skip_repository, { source = "startup" })
assert(prompts == 1, "missing graph prompts at startup")
graphify.prepare_workspace(skip_repository, { source = "startup" })
assert(prompts == 1, "persistent skip suppresses the next startup prompt for the repository root")
vim.cmd.cd(skip_repository)
vim.cmd.AITermGraphifyResetPrompts()
graphify.prepare_workspace(skip_repository, { source = "startup" })
assert(prompts == 2, "reset command restores the startup prompt for the current repository")
assert(graphify.reset_skips(skip_repository), "startup prompt choice can be reset again")
vim.api.nvim_exec_autocmds("VimEnter", {})
assert(
    vim.wait(1000, function()
        return prompts == 3
    end),
    "VimEnter checks the current repository for a missing graph"
)

assert(graphify.reset_skips(skip_repository), "persistent prompt choice can be cleared for session prompt test")
local session_prompts = 0
require("aiterm.config").setup({
    graphify = {
        enabled = true,
        executable = executable,
        missing_graph = "ask",
        remember_skips = "never",
        ui = {
            confirm = function(choices, _, respond)
                session_prompts = session_prompts + 1
                respond(choices[2])
            end,
        },
    },
})

require("aiterm.ai").prepare_workspace("codex", skip_repository)
require("aiterm.ai").prepare_workspace("codex", skip_repository)
assert(session_prompts == 1, "Codex prompts only once per repository during a Neovim session")

vim.fn.mkdir(vim.fs.joinpath(skip_repository, "graphify-out"), "p")
vim.fn.writefile({ '{"nodes": [], "links": []}' }, vim.fs.joinpath(skip_repository, "graphify-out", "graph.json"))
require("aiterm.config").opts.graphify.stale_detection = "always"
require("aiterm.ai").prepare_workspace("codex", skip_repository)
assert(session_prompts == 1, "missing and stale checks share one repository prompt allowance")

assert(graphify.reset_skips(skip_repository), "session prompt choice can be reset")
require("aiterm.ai").prepare_workspace("codex", skip_repository)
assert(session_prompts == 2, "reset restores the repository prompt during the same session")

assert(graphify.reset_skips(skip_repository), "session prompt can be reset for pending output policy test")
assert(vim.fn.delete(vim.fs.joinpath(skip_repository, "graphify-out"), "rf") == 0, "pending prompt graph removed")
local run_prompts = 0
local output_prompts = 0
require("aiterm.config").opts.graphify.ui.confirm = function(choices, _, respond)
    if choices[1] == "Run now" then
        run_prompts = run_prompts + 1
        respond(choices[1])
        return
    end
    output_prompts = output_prompts + 1
end

require("aiterm.ai").prepare_workspace("codex", skip_repository)
require("aiterm.ai").prepare_workspace("codex", skip_repository)
assert(run_prompts == 1, "pending output policy does not reopen the repository prompt")
assert(output_prompts == 1, "only one output policy prompt opens for the repository")

vim.fn.delete(temporary, "rf")
print("graphify OK")
