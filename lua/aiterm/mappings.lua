local M = {}

local config = require("aiterm.config")

local function termcodes(keys)
    return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function terminal_action(fn)
    return function()
        vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
        vim.schedule(fn)
    end
end

local function each_lhs(lhs, callback)
    if lhs == false or lhs == nil or lhs == "" then
        return
    end

    if type(lhs) == "table" then
        for _, item in ipairs(lhs) do
            each_lhs(item, callback)
        end
        return
    end

    if type(lhs) == "string" then
        callback(lhs)
    end
end

local function set(mode, lhs, rhs, desc)
    each_lhs(lhs, function(key)
        vim.keymap.set(mode, key, rhs, { silent = true, desc = desc })
    end)
end

local function set_pair(lhs, fn, desc)
    set("n", lhs, fn, desc)
    set("t", lhs, terminal_action(fn), desc)
end

function M.setup()
    local mappings = config.opts.mappings

    local buffers = require("aiterm.buffers")
    set("n", mappings.buffers.previous, buffers.backward, "Previous file buffer")
    set("n", mappings.buffers.next, buffers.forward, "Next file buffer")
    set_pair(mappings.buffers.alternate, buffers.alternate, "Alternate file buffer")
    set_pair(mappings.buffers.quit, buffers.quit_current_or_window, "Close window, buffer, or quit")

    local terminal = require("aiterm.terminal")
    set_pair(mappings.terminal.toggle, terminal.toggle, "Toggle terminal")
    set_pair(mappings.terminal.new, terminal.open_new, "Open new terminal")
    set("t", mappings.terminal.previous, terminal_action(terminal.backward), "Previous terminal buffer")
    set("t", mappings.terminal.next, terminal_action(terminal.forward), "Next terminal buffer")

    if config.opts.ai.enabled then
        local ai = require("aiterm.ai")
        set_pair(mappings.ai.toggle, ai.toggle, "Toggle AI buffer")
        set_pair(mappings.ai.new, ai.new_session, "New AI session")
        set_pair(mappings.ai.pick, ai.pick, "AI session picker")
        set_pair(mappings.ai.kill, ai.kill_current_or_select, "Kill AI session")
        set_pair(mappings.ai.kill_all, ai.kill_all, "Kill all AI sessions")
        set_pair(mappings.ai.restore, ai.restore_here, "Restore AI sessions for cwd")
    end

    if config.opts.processes.enabled then
        local processes = require("aiterm.processes")
        set_pair(mappings.processes.pick, processes.list, "Persistent terminal picker")
        set_pair(mappings.processes.new, processes.new, "New persistent terminal")
        set_pair(mappings.processes.attach_last, processes.attach_last, "Attach last persistent terminal")
        set_pair(mappings.processes.attach_all, processes.attach_all_cwd, "Attach all persistent terminals for cwd")
        set_pair(mappings.processes.kill, processes.kill_current_or_select, "Kill persistent terminal")
        set_pair(mappings.processes.kill_all, processes.kill_all, "Kill all persistent terminals")
    end

    if config.opts.treehouse.enabled then
        local treehouse = require("aiterm.treehouse")
        set("n", mappings.treehouse.acquire, treehouse.acquire_disposable, "Treehouse: acquire disposable workspace")
        set("n", mappings.treehouse.lease, treehouse.acquire_leased, "Treehouse: acquire leased workspace")
        set("n", mappings.treehouse.status, treehouse.status, "Treehouse: status")
        set("n", mappings.treehouse.pick, treehouse.pick, "Treehouse: workspace picker")
        set("n", mappings.treehouse.return_ws, treehouse.return_workspace, "Treehouse: return leased workspace")
    end

    if config.opts.run.enabled then
        local run = require("aiterm.run")
        set("n", mappings.run.current_file, run.exec_current_file, "Run current file")
        set("n", mappings.run.configure, run.configure_popup, "Configure current file runner")
    end
end

return M
