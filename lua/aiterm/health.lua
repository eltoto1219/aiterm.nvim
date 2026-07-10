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
        local providers = require("aiterm.providers")
        for _, kind in ipairs(ai.kind_names()) do
            local provider = providers.get("ai", kind)
            local spec = opts.ai.kinds[kind]
            if provider and provider.executable == nil then
                health.info("AI provider '" .. kind .. "' configured without an executable check")
            elseif type(spec) == "table" and type(spec.command) == "function" then
                health.info("custom command configured for AI kind '" .. kind .. "'; binary cannot be verified")
            else
                local executable = provider and provider.executable or kind
                binary(
                    health,
                    executable,
                    true,
                    "install " .. executable .. " or disable/remove AI kind '" .. kind .. "'"
                )
            end
        end
        health.info("codex sessions dir: " .. ai.codex_sessions_dir)
    else
        health.start("aiterm: ai sessions")
        health.info("disabled; install claude/codex only if you enable this module")
    end

    if opts.graphify.enabled then
        health.start("aiterm: Graphify")
        local graphify = require("aiterm.graphify")
        binary(
            health,
            opts.graphify.executable,
            true,
            "install it with `uv tool install graphifyy` or disable opts.graphify"
        )
        health.info("lifecycle: " .. opts.graphify.lifecycle)
        health.info("missing graph policy: " .. opts.graphify.missing_graph)
        health.info("stale graph policy: " .. opts.graphify.stale_graph)
        local status = graphify.status()
        health.info(
            "current repository graph: " .. status.kind .. (status.message and " (" .. status.message .. ")" or "")
        )
        for provider, present in pairs(graphify.guidance_status(status.root)) do
            if present then
                health.ok("Graphify " .. provider .. " guidance found")
            else
                health.info("Graphify " .. provider .. " guidance not found; setup stays manual")
            end
        end
    else
        health.start("aiterm: Graphify")
        health.info("disabled; install graphifyy only if you enable this module")
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
