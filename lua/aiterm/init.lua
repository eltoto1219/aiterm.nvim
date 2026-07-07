local M = {}

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
    if config.opts.run.enabled then
        require("aiterm.run").register()
    end
    if config.opts.tabline.enabled then
        local tabline = require("aiterm.tabline")
        tabline.setup_highlights()
        tabline.register_autocmds()
    end
end

return M
