local M = {}

-- Single source of truth for options. All keymaps the plugin can create live
-- under `mappings`; false disables a mapping, a string sets its lhs, and a
-- list sets multiple lhs values for the same action. `true` is reserved for
-- mappings with intrinsic built-in keys.
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
        autostart_kind = nil, -- nil picks first executable kind; string pins new autostart sessions
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
    },
    graphify = {
        enabled = false, -- requires the graphify CLI
        executable = "graphify",
        root = {
            markers = { ".git" },
            fallback = "cwd", -- cwd | disabled
            nested_repositories = "nearest", -- nearest | outermost
        },
        lifecycle = "on_ai_start", -- manual | on_ai_start | on_workspace_enter
        check = {
            on_vim_enter = true,
            on_dir_changed = true,
            on_ai_start = true,
            on_treehouse_workspace = true,
            debounce_ms = 500,
        },
        missing_graph = "ask", -- never | ask | build
        stale_graph = "ask", -- never | ask | update
        stale_detection = "git", -- git | timestamp | always
        allow_dirty_worktree = true,
        remember_skips = "session", -- never | session | repository
        git = {
            include_cache = false, -- allow graphify-out/cache/ to be tracked
        },
        safety = {
            require_git_repository = true,
            max_files_for_automatic_build = 5000,
            max_bytes_for_automatic_build = 100 * 1024 * 1024,
        },
        build = {
            code_only = true,
            extra_args = {},
            timeout_ms = 15 * 60 * 1000,
            output = "terminal", -- terminal | scratch | silent
            terminal_label = "G: build",
        },
        update = {
            extra_args = {},
            timeout_ms = 15 * 60 * 1000,
            output = "terminal", -- terminal | scratch | silent
            terminal_label = "G: update",
        },
        query = {
            output = "terminal", -- terminal | scratch | silent
            timeout_ms = 60 * 1000,
            terminal_label = "G: query",
        },
        ignore_file = {
            enabled = true,
            path = ".graphifyignore",
            create_if_missing = true,
            profile = "safe", -- minimal | safe
        },
        agents = {
            install_on_build = true,
            check_on_start = true,
            warn_when_missing = true,
            providers = { "codex", "claude" },
        },
        ui = {
            notifications = true,
            open_html = "browser", -- browser | system | disabled | command argv
            confirm = nil, -- nil uses aiterm's built-in picker
        },
        callbacks = {
            on_status = nil,
            on_complete = nil,
            on_error = nil,
        },
    },
    run = {
        enabled = true, -- :TerminalConfig + exec_current_file()
        templates = {}, -- filetype -> command template, merged over built-ins
    },
    tabline = {
        enabled = false, -- lualine tabline component + its highlights
    },
    mappings = {
        buffers = {
            previous = false,
            next = false,
            alternate = false,
            quit = false,
        },
        terminal = {
            toggle = false,
            new = false,
            previous = false,
            next = false,
            prompt_prev = "[a",
            prompt_next = "]a",
            rename = "<leader>r", -- buffer-local in terminals
            insert_resume = { "i", "a", "I", "A" },
            persistent_esc = "<Esc>",
        },
        ai = {
            toggle = false,
            new = false,
            pick = false,
            kill = false,
            kill_all = false,
            restore = false,
        },
        processes = {
            pick = false,
            new = false,
            attach_last = false,
            attach_all = false,
            kill = false,
            kill_all = false,
        },
        treehouse = {
            acquire = false,
            lease = false,
            status = false,
            pick = false,
            return_ws = false,
        },
        graphify = {
            status = false,
            build = false,
            update = false,
            query = false,
            open = false,
        },
        run = {
            current_file = false,
            configure = false,
            popup = { default = "d", custom = "c", close = "q" },
        },
        picker = {
            down = "j",
            up = "k",
            confirm = "<CR>",
            cancel = { "q", "<Esc>" },
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
