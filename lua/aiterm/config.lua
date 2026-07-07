local M = {}

-- Single source of truth for every option and default mapping. Any mapping
-- value can be set to false to disable that keymap.
M.defaults = {
    terminal = {
        -- Styling autocmds: no numbers/signcolumn in terminals, startinsert on
        -- enter, stopinsert on leave, and a pinned background (see below).
        style = true,
        -- Background painted under terminal windows. Must stay in sync with
        -- the color nvim reports to :terminal apps via OSC 11 (hardcoded
        -- black upstream); TUIs like codex derive highlights from it.
        -- Number (0x000000) or "#rrggbb" string; false skips painting.
        background = 0x000000,
        -- table | fun():table merged over the environment captured at launch,
        -- applied to every terminal the plugin spawns.
        env = nil,
        mappings = {
            prompt_prev = "[a",
            prompt_next = "]a",
            rename = "<leader>r", -- buffer-local in terminals
            insert_resume = true, -- i/a/I/A resume terminal input
            persistent_esc = true, -- <Esc> leaves input mode in persistent terminals
        },
    },
    buffers = {
        enabled = true, -- last-edit-buffer tracking autocmds
    },
    ai = {
        enabled = true,
        -- kind name -> { args = {...}, command = fun(entry, resume)? }.
        -- args are appended to the built-in claude/codex launchers; command
        -- replaces the launcher entirely for custom harnesses.
        -- No permission-skipping flags ship by default; opt in explicitly.
        kinds = {
            claude = { args = {} },
            codex = { args = {} },
        },
        autostart = false, -- spawn/restore an AI session on plain `nvim`
        restore = true, -- load the on-disk session registry at startup
        commands = true, -- :Claude/:Codex (per kind) and the :AISession* family
        codex_sessions_dir = nil, -- default: ~/.codex/sessions
    },
    processes = {
        enabled = false, -- requires the shpool binary
        shpool = nil, -- name or absolute path; default: shpool on PATH (plus ~/.local/bin, ~/.cargo/bin)
        session_prefix = "aiterm-process-",
    },
    treehouse = {
        enabled = false, -- requires the treehouse CLI and shpool
        -- false for no global maps, or a table like:
        -- { acquire = "<leader>fa", lease = "<leader>fl", status = "<leader>fs",
        --   pick = "<leader>fw", return_ws = "<leader>fr" }
        mappings = false,
    },
    run = {
        enabled = true, -- :TerminalConfig + exec_current_file()
        templates = {}, -- filetype -> command template, merged over built-ins
        popup_mappings = { default = "d", custom = "c", close = "q" },
    },
    tabline = {
        enabled = false, -- lualine tabline component + its highlights
    },
    ui = {
        picker = {
            mappings = { down = "j", up = "k", confirm = "<CR>", cancel = { "q", "<Esc>" } },
        },
    },
}

M.opts = vim.deepcopy(M.defaults)

function M.setup(opts)
    M.opts = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
    return M.opts
end

function M.state_dir()
    local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "aiterm")
    vim.fn.mkdir(dir, "p")
    return dir
end

return M
