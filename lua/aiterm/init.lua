local M = {}

function M.register_provider(provider_type, name, spec, opts)
    return require("aiterm.providers").register(provider_type, name, spec, opts)
end

function M.providers(provider_type)
    local providers = require("aiterm.providers")
    return provider_type and providers.list(provider_type) or providers
end

function M.setup(opts)
    local config = require("aiterm.config")
    config.setup(opts)

    if config.opts.buffers.enabled then
        require("aiterm.buffers").setup()
    end
    require("aiterm.terminal").setup()
    if config.opts.ai.enabled then
        require("aiterm.ai").setup()
    end
    if config.opts.processes.enabled then
        require("aiterm.processes").setup()
    end
    if config.opts.treehouse.enabled then
        require("aiterm.treehouse").setup()
    end
    if config.opts.graphify.enabled then
        require("aiterm.graphify").setup()
    end
    if config.opts.run.enabled then
        require("aiterm.run").register()
    end
    if config.opts.tabline.enabled then
        local tabline = require("aiterm.tabline")
        tabline.setup_highlights()
        tabline.register_autocmds()
    end
    require("aiterm.mappings").setup()
end

return M
