-- Run: nvim --headless --clean -l tests/graphify_startup.lua
local root = vim.fs.normalize(
    vim.fn.fnamemodify(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), ".."), ":p")
)
vim.opt.rtp:prepend(root)

local temporary = vim.fn.tempname()
local repository = vim.fs.joinpath(temporary, "repository")
local state = vim.fs.joinpath(temporary, "state")
vim.fn.mkdir(repository, "p")
vim.fn.mkdir(state, "p")
vim.env.XDG_STATE_HOME = state

vim.fn.writefile({ "return {}" }, vim.fs.joinpath(repository, "example.lua"))
assert(vim.fn.system({ "git", "init", "-q", repository }) == "", "test repository initialized")
assert(
    vim.fn.system({ "git", "-C", repository, "config", "user.email", "test@example.com" }) == "",
    "test email configured"
)
assert(vim.fn.system({ "git", "-C", repository, "config", "user.name", "Test User" }) == "", "test name configured")
assert(vim.fn.system({ "git", "-C", repository, "add", "." }) == "", "test file staged")
assert(vim.fn.system({ "git", "-C", repository, "commit", "-qm", "initial" }) == "", "test repository committed")
vim.cmd.cd(repository)

local confirmations = {}
local status_checks = 0
require("aiterm").setup({
    ai = {
        autostart = true,
        autostart_kind = "test",
        restore = false,
        kinds = {
            test = {
                executable = "sh",
                command = function()
                    return { "sh", "-c", "sleep 2" }
                end,
            },
        },
    },
    graphify = {
        enabled = true,
        executable = "true",
        missing_graph = "ask",
        stale_graph = "never",
        callbacks = {
            on_status = function()
                status_checks = status_checks + 1
            end,
        },
        ui = {
            confirm = function(_, _, _)
                local bufnr = vim.api.nvim_get_current_buf()
                confirmations[#confirmations + 1] = {
                    bufnr = bufnr,
                    ai_kind = vim.b[bufnr].aiterm_ai_kind,
                }
            end,
        },
    },
})

local original_list_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function()
    return { {} }
end
vim.api.nvim_exec_autocmds("VimEnter", {})

assert(
    vim.wait(2000, function()
        return #confirmations == 1
    end),
    "startup reaches the Graphify confirmation"
)
assert(confirmations[1].ai_kind == "test", "AI terminal opens and receives focus before the Graphify confirmation")
vim.wait(750)
assert(status_checks == 1, "AI autostart is the sole owner of the on_ai_start Graphify startup check")

vim.api.nvim_list_uis = original_list_uis
vim.fn.delete(temporary, "rf")
print("graphify startup OK")
