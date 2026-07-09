local M = {}

local function binary(health, name, required, hint)
    if vim.fn.executable(name) == 1 then
        health.ok(name .. " found: " .. vim.fn.exepath(name))
    elseif required then
        health.error(name .. " not found", hint)
    else
        health.info(name .. " not found: " .. hint)
    end
end

local function enabled(value)
    return value and "enabled" or "disabled"
end

function M.check()
    local health = vim.health
    local config = require("aiterm.config")
    local opts = config.opts

    health.start("aiterm: core")
    health.ok("state dir: " .. config.state_dir())
    health.info("buffers module: " .. enabled(opts.buffers.enabled))
    health.info("ai module: " .. enabled(opts.ai.enabled))
    health.info("processes module: " .. enabled(opts.processes.enabled))
    health.info("treehouse module: " .. enabled(opts.treehouse.enabled))
    health.info("run module: " .. enabled(opts.run.enabled))
    health.info("tabline module: " .. enabled(opts.tabline.enabled))

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
            local spec = opts.ai.kinds[kind]
            if type(spec) == "table" and type(spec.command) == "function" then
                health.info("custom command configured for AI kind '" .. kind .. "'; binary cannot be verified")
            else
                binary(health, kind, true, "install " .. kind .. " or disable/remove AI kind '" .. kind .. "'")
            end
        end
        health.info("codex sessions dir: " .. ai.codex_sessions_dir)
    else
        health.start("aiterm: ai sessions")
        health.info("disabled; install claude/codex only if you enable this module")
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
    else
        health.start("aiterm: persistent processes")
        health.info("disabled; install shpool only if you enable this module")
    end

    if opts.treehouse.enabled then
        health.start("aiterm: treehouse workspaces")
        binary(health, "treehouse", true, "install it from github.com/kunchenguid/treehouse")
        binary(health, "git", true, "git is required for workspace status")
        if not opts.processes.enabled then
            health.warn("processes module disabled", "treehouse workspaces attach through shpool sessions")
        end
        local backend = require("aiterm.process_backend")
        if backend.available() then
            health.ok("shpool available for treehouse sessions")
        else
            health.error(
                "shpool not found",
                "treehouse workspaces require shpool; install it from github.com/shell-pool/shpool"
            )
        end
    else
        health.start("aiterm: treehouse workspaces")
        health.info("disabled; install treehouse, git, and shpool only if you enable this module")
    end
end

return M
