local M = {}

local function binary(health, name, required, hint)
    if vim.fn.executable(name) == 1 then
        health.ok(name .. " found: " .. vim.fn.exepath(name))
    elseif required then
        health.error(name .. " not found", hint)
    else
        health.warn(name .. " not found", hint)
    end
end

function M.check()
    local health = vim.health
    local config = require("aiterm.config")
    local opts = config.opts

    health.start("aiterm: core")
    health.ok("state dir: " .. config.state_dir())
    local integrations = {
        { "nvim-tree.api", "nvim-tree (auto-hide while a terminal is focused)" },
        { "nui.input", "nui.nvim (nicer centered input; falls back to vim.ui.input)" },
        { "lualine", "lualine (tabline component consumer)" },
    }
    for _, item in ipairs(integrations) do
        if pcall(require, item[1]) then
            health.ok("optional integration active: " .. item[2])
        else
            health.info("optional integration not installed: " .. item[2])
        end
    end

    if opts.ai.enabled then
        health.start("aiterm: ai sessions")
        local ai = require("aiterm.ai")
        for _, kind in ipairs(ai.kind_names()) do
            binary(health, kind, false, "sessions of kind '" .. kind .. "' cannot be spawned")
        end
        health.info("codex sessions dir: " .. ai.codex_sessions_dir)
    end

    if opts.processes.enabled then
        health.start("aiterm: persistent processes")
        local backend = require("aiterm.process_backend")
        if backend.available() then
            health.ok("shpool available")
        else
            health.error(
                "shpool not found",
                "install it from github.com/shell-pool/shpool or set opts.processes.shpool"
            )
        end
    end

    if opts.treehouse.enabled then
        health.start("aiterm: treehouse workspaces")
        binary(health, "treehouse", true, "install it from github.com/kunchenguid/treehouse")
        binary(health, "git", true, "git is required for workspace status")
        if not opts.processes.enabled then
            health.warn("processes module disabled", "treehouse workspaces attach through shpool sessions")
        end
    end
end

return M
