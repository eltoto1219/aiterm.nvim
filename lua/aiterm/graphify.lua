local M = {}

local config = require("aiterm.config")

local jobs = {}
local session_skips = {}
local prompted_repositories = {}
local pending_choices = {}
local warned_guidance = {}
local stored_state = nil

local output_files = {
    directory = "graphify-out",
    graph = "graph.json",
    html = "graph.html",
}

local minimal_ignore = {
    "# Created by aiterm.nvim for Graphify.",
    "# Add repository-specific exclusions below. This file is never overwritten by aiterm.nvim.",
    "",
    "# Environments, dependencies, and caches",
    ".venv/",
    "venv/",
    "env/",
    "__pycache__/",
    ".pytest_cache/",
    ".mypy_cache/",
    ".ruff_cache/",
    "node_modules/",
    "",
    "# Build and test output",
    "dist/",
    "build/",
    "coverage/",
    "htmlcov/",
    "target/",
}

local safe_ignore = {
    "",
    "# Media",
    "*.png",
    "*.jpg",
    "*.jpeg",
    "*.gif",
    "*.webp",
    "*.mp4",
    "*.mov",
    "*.avi",
    "*.mkv",
    "*.webm",
    "*.mp3",
    "*.wav",
    "*.flac",
    "",
    "# Large data and local databases",
    "*.csv",
    "*.tsv",
    "*.parquet",
    "*.feather",
    "*.h5",
    "*.hdf5",
    "*.npy",
    "*.npz",
    "*.sqlite",
    "*.sqlite3",
    "*.db",
}

local function opts()
    return config.opts.graphify
end

local function notify(message, level)
    if opts().ui.notifications then
        vim.notify("Graphify: " .. message, level or vim.log.levels.INFO)
    end
end

local function state_path()
    return vim.fs.joinpath(config.state_dir(), "graphify.json")
end

local function load_state()
    if stored_state ~= nil then
        return stored_state
    end

    stored_state = {}
    local path = state_path()
    if vim.fn.filereadable(path) ~= 1 then
        return stored_state
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if ok and type(decoded) == "table" then
        stored_state = decoded
    end
    return stored_state
end

local function save_state()
    vim.fn.writefile({ vim.json.encode(load_state()) }, state_path())
end

local function normalize(path)
    return path and vim.fs.normalize(path) or nil
end

local function is_directory(path)
    return type(path) == "string" and vim.fn.isdirectory(path) == 1
end

local function root_from_markers(path, markers, nested_repositories)
    local start = is_directory(path) and path or vim.fs.dirname(path)
    if not start then
        return nil
    end

    if nested_repositories ~= "outermost" then
        return vim.fs.root(start, markers)
    end

    local root = nil
    for parent in vim.fs.parents(start) do
        for _, marker in ipairs(markers) do
            if vim.uv.fs_stat(vim.fs.joinpath(parent, marker)) then
                root = parent
                break
            end
        end
    end
    return root
end

function M.root(path)
    local graphify = opts()
    local candidate = path or vim.api.nvim_buf_get_name(0)
    if not path and vim.bo.buftype ~= "" then
        candidate = vim.fn.getcwd()
    elseif candidate == "" then
        candidate = vim.fn.getcwd()
    end

    local root = root_from_markers(candidate, graphify.root.markers, graphify.root.nested_repositories)
    if root then
        return normalize(root)
    end
    if graphify.root.fallback == "cwd" then
        return normalize(vim.fn.getcwd())
    end
    return nil
end

local function git_output(root, args)
    local result = vim.fn.systemlist(vim.list_extend({ "git", "-C", root }, args))
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return result
end

local function git_snapshot(root)
    local head = git_output(root, { "rev-parse", "HEAD" })
    if not head or not head[1] then
        return nil
    end
    local dirty = git_output(root, { "status", "--porcelain", "--untracked-files=normal" })
    return {
        head = head[1],
        dirty = dirty and #dirty > 0 or false,
    }
end

local function graph_path(root)
    return vim.fs.joinpath(root, output_files.directory, output_files.graph)
end

local function output_path(root, name)
    return vim.fs.joinpath(root, output_files.directory, name)
end

function M.ignore_path(root)
    return vim.fs.joinpath(root, opts().ignore_file.path)
end

function M.ensure_ignore(root)
    local ignore = opts().ignore_file
    if not ignore.enabled or not ignore.create_if_missing then
        return false
    end

    local path = M.ignore_path(root)
    if vim.uv.fs_stat(path) then
        return false
    end

    local lines = vim.deepcopy(minimal_ignore)
    if ignore.profile == "safe" then
        vim.list_extend(lines, safe_ignore)
    end
    vim.fn.writefile(lines, path)
    notify("created " .. vim.fs.basename(path) .. "; review it for repository-specific exclusions")
    return true
end

local function normalize_ignore_pattern(pattern)
    return vim.trim(pattern):gsub("^/", ""):gsub("/$", "")
end

local function ignore_rule_present(lines, rule)
    local target = normalize_ignore_pattern(rule)
    for _, line in ipairs(lines) do
        local pattern = normalize_ignore_pattern(line)
        if pattern == target or (pattern ~= "" and vim.startswith(target, pattern .. "/")) then
            return true
        end
    end
    return false
end

local function append_ignore_rule(path, rule)
    local lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
    if ignore_rule_present(lines, rule) then
        return false
    end
    if #lines > 0 and lines[#lines] ~= "" then
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = rule
    vim.fn.writefile(lines, path)
    return true
end

local function ensure_cache_git_policy(root)
    if opts().git.include_cache then
        return false
    end
    local changed = append_ignore_rule(vim.fs.joinpath(root, ".gitignore"), "graphify-out/cache/")
    if changed then
        notify("ignored graphify-out/cache/ in .gitignore")
    end
    return changed
end

function M.ignore_graph_output(root)
    root = root or M.root()
    if not root then
        return false
    end

    M.ensure_ignore(root)
    local updated = {}
    local gitignore = vim.fs.joinpath(root, ".gitignore")
    if append_ignore_rule(gitignore, "graphify-out/") then
        updated[#updated + 1] = ".gitignore"
    end

    local graphifyignore = M.ignore_path(root)
    if append_ignore_rule(graphifyignore, "graphify-out/") then
        updated[#updated + 1] = vim.fs.basename(graphifyignore)
    end

    if #updated > 0 then
        notify("ignored graphify-out/ in " .. table.concat(updated, " and "))
    else
        notify("graphify-out/ is already ignored")
    end
    return true
end

local function state_for(root)
    local state = load_state()
    state[root] = state[root] or {}
    return state[root]
end

function M.status(root)
    root = root or M.root()
    if not root then
        return { kind = "unsupported", message = "no repository root found" }
    end

    if vim.fn.executable(opts().executable) ~= 1 then
        return { kind = "unavailable", root = root, message = opts().executable .. " is not on PATH" }
    end

    if jobs[root] then
        return { kind = "building", root = root, action = jobs[root].action }
    end

    local snapshot = git_snapshot(root)
    if opts().safety.require_git_repository and not snapshot then
        return { kind = "unsupported", root = root, message = "not a Git repository" }
    end

    if vim.fn.filereadable(graph_path(root)) ~= 1 then
        return { kind = "missing", root = root, graph = graph_path(root) }
    end

    local prior = state_for(root)
    if opts().stale_detection == "always" then
        return {
            kind = "stale",
            root = root,
            graph = graph_path(root),
            message = "configured to update on every check",
        }
    end

    if opts().stale_detection == "timestamp" and snapshot then
        local committed_at = git_output(root, { "log", "-1", "--format=%ct" })
        local graph_time = vim.fn.getftime(graph_path(root))
        if committed_at and tonumber(committed_at[1]) and tonumber(committed_at[1]) > graph_time then
            return {
                kind = "stale",
                root = root,
                graph = graph_path(root),
                message = "latest commit is newer than graph",
            }
        end
    end

    if opts().stale_detection == "git" and snapshot and prior.snapshot then
        if snapshot.head ~= prior.snapshot.head or snapshot.dirty ~= prior.snapshot.dirty then
            return {
                kind = "stale",
                root = root,
                graph = graph_path(root),
                message = "Git state changed since last build",
            }
        end
    end

    return { kind = "fresh", root = root, graph = graph_path(root), snapshot = snapshot }
end

local function invoke_callback(name, ...)
    local callback = opts().callbacks[name]
    if type(callback) == "function" then
        local ok, err = pcall(callback, ...)
        if not ok then
            notify("callback " .. name .. " failed: " .. tostring(err), vim.log.levels.WARN)
        end
    end
end

local function remember_skip(root, kind, persistent)
    if persistent then
        state_for(root).skips = state_for(root).skips or {}
        state_for(root).skips[kind] = true
        save_state()
        return
    end
    if opts().remember_skips == "never" then
        return
    end
    if opts().remember_skips == "repository" then
        state_for(root).skips = state_for(root).skips or {}
        state_for(root).skips[kind] = true
        save_state()
        return
    end
    session_skips[root] = session_skips[root] or {}
    session_skips[root][kind] = true
end

local function skipped(root, kind)
    local stored = load_state()[root]
    if stored and stored.skips and stored.skips[kind] then
        return true
    end
    if opts().remember_skips == "repository" then
        return false
    end
    return session_skips[root] and session_skips[root][kind] or false
end

local function repository_size(root)
    local files = git_output(root, { "ls-files" })
    if not files then
        return nil
    end

    local count, bytes = 0, 0
    for _, relative in ipairs(files) do
        count = count + 1
        local size = vim.fn.getfsize(vim.fs.joinpath(root, relative))
        if size > 0 then
            bytes = bytes + size
        end
    end
    return { files = count, bytes = bytes }
end

local function automatic_build_allowed(root)
    local safety = opts().safety
    local size = repository_size(root)
    if not size then
        return true
    end
    if size.files > safety.max_files_for_automatic_build or size.bytes > safety.max_bytes_for_automatic_build then
        notify("automatic build skipped because the repository exceeds configured safety limits", vim.log.levels.WARN)
        return false
    end
    return true
end

local function command_for(action, root, argument, force)
    local graphify = opts()
    local argv = { graphify.executable }
    if action == "build" then
        vim.list_extend(argv, { "extract", root })
        if graphify.build.code_only then
            argv[#argv + 1] = "--code-only"
        end
        vim.list_extend(argv, graphify.build.extra_args)
    elseif action == "update" then
        vim.list_extend(argv, { "update", root })
        if force then
            argv[#argv + 1] = "--force"
        end
        vim.list_extend(argv, graphify.update.extra_args)
    elseif action == "path" then
        vim.list_extend(argv, { "path", argument[1], argument[2], "--graph", graph_path(root) })
    else
        vim.list_extend(argv, { action, argument, "--graph", graph_path(root) })
    end
    return argv
end

local function open_scratch(label, lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "aiterm://graphify/" .. label .. "/" .. vim.uv.hrtime())
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].swapfile = false
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(bufnr)
    return bufnr
end

local start_cluster_job

local function finish(root, action, code, stdout, stderr)
    local job = jobs[root]
    if not job or job.action ~= action then
        return
    end

    if code == 0 and job.needs_cluster then
        if not start_cluster_job(root, job) then
            jobs[root] = nil
            notify(action .. " failed: could not start Graphify clustering", vim.log.levels.ERROR)
            invoke_callback("on_error", { action = action, code = -1 }, root)
        end
        return
    end
    jobs[root] = nil

    if code == 0 then
        if action == "build" or action == "update" then
            local state = state_for(root)
            state.snapshot = git_snapshot(root)
            state.built_at = os.time()
            state.skips = nil
            save_state()
        end
        notify(action .. " completed for " .. root)
        invoke_callback("on_complete", { action = action, code = code, stdout = stdout, stderr = stderr }, root)
        return
    end

    local detail = vim.trim(stderr or "")
    if detail == "" then
        detail = "exit code " .. tostring(code)
    end
    notify(action .. " failed: " .. detail, vim.log.levels.ERROR)
    invoke_callback("on_error", { action = action, code = code, stdout = stdout, stderr = stderr }, root)
end

local function start_scratch_job(root, job, argv)
    local label = "Graphify " .. (job.needs_cluster and job.action or "cluster")
    local bufnr = open_scratch(label, { "Running: " .. table.concat(argv, " ") })
    jobs[root] = job
    local handle = vim.system(argv, { cwd = root, text = true, timeout = job.timeout_ms }, function(result)
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                local lines = vim.split((result.stdout or "") .. (result.stderr or ""), "\n", { plain = true })
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            end
            finish(root, job.action, result.code, result.stdout, result.stderr)
        end)
    end)
    job.handle = handle
end

local function start_silent_job(root, job, argv)
    jobs[root] = job
    local handle = vim.system(argv, { cwd = root, text = true, timeout = job.timeout_ms }, function(result)
        vim.schedule(function()
            finish(root, job.action, result.code, result.stdout, result.stderr)
        end)
    end)
    job.handle = handle
end

local function start_terminal_job(root, job, argv, label)
    local terminal = require("aiterm.terminal")
    jobs[root] = job
    local bufnr = terminal.open_command(argv, label, {
        cwd = root,
        on_exit = function(_, code)
            vim.schedule(function()
                finish(root, job.action, code, nil, nil)
            end)
        end,
    })
    if not bufnr then
        jobs[root] = nil
        return false
    end

    job.bufnr = bufnr
    local job_id = vim.b[bufnr].terminal_job_id
    vim.defer_fn(function()
        if jobs[root] == job and job_id and job_id > 0 then
            vim.fn.jobstop(job_id)
        end
    end, job.timeout_ms)
    return true
end

start_cluster_job = function(root, previous)
    local job = {
        action = previous.action,
        needs_cluster = false,
        output = previous.output,
        timeout_ms = previous.timeout_ms,
    }
    local argv = { opts().executable, "cluster-only", root, "--no-label" }
    if job.output == "scratch" then
        start_scratch_job(root, job, argv)
        return true
    elseif job.output == "silent" then
        start_silent_job(root, job, argv)
        return true
    else
        return start_terminal_job(root, job, argv, "G: cluster")
    end
end

local function start_job(action, root, argument, options)
    root = root or M.root()
    options = options or {}
    if not root then
        notify("no repository root found", vim.log.levels.WARN)
        return false
    end
    if jobs[root] then
        notify(jobs[root].action .. " is already running for " .. root)
        return false
    end
    if vim.fn.executable(opts().executable) ~= 1 then
        notify(opts().executable .. " is not installed or not on PATH", vim.log.levels.ERROR)
        return false
    end

    if options.automatic and not opts().allow_dirty_worktree then
        local snapshot = git_snapshot(root)
        if snapshot and snapshot.dirty then
            notify("automatic " .. action .. " skipped because the worktree is dirty", vim.log.levels.WARN)
            return false
        end
    end

    if action == "build" or action == "update" then
        ensure_cache_git_policy(root)
    end

    if action == "build" then
        M.ensure_ignore(root)
    end

    local argv = options.argv or command_for(action, root, argument, options.force)
    local timeout_ms = options.timeout_ms
        or (action == "build" and opts().build.timeout_ms)
        or (action == "update" and opts().update.timeout_ms)
        or opts().query.timeout_ms
    local destination = options.output or (action == "build" and opts().build.output or opts().query.output)
    if action == "update" then
        destination = options.output or opts().update.output
    end
    local job = {
        action = action,
        needs_cluster = action == "build" or action == "update",
        output = destination,
        timeout_ms = timeout_ms,
    }
    if destination == "scratch" then
        start_scratch_job(root, job, argv)
        return true
    end
    if destination == "silent" then
        start_silent_job(root, job, argv)
        return true
    end

    local labels = {
        build = opts().build.terminal_label,
        update = opts().update.terminal_label,
        query = opts().query.terminal_label,
        explain = "G: explain",
        path = "G: path",
    }
    return start_terminal_job(root, job, argv, labels[action] or "G: graphify")
end

function M.build(root, options)
    return start_job("build", root, nil, options)
end

function M.build_here()
    return M.build(M.root())
end

function M.update(root, options)
    return start_job("update", root, nil, options)
end

function M.update_here()
    return M.update(M.root())
end

function M.query(question, root)
    if not question or question == "" then
        return false
    end
    return start_job("query", root, question)
end

function M.explain(node, root)
    if not node or node == "" then
        return false
    end
    return start_job("explain", root, node)
end

function M.path(source, target, root)
    if not source or source == "" or not target or target == "" then
        return false
    end
    return start_job("path", root, { source, target })
end

function M.query_prompt()
    vim.ui.input({ prompt = "Graphify query: " }, function(question)
        if question and question ~= "" then
            M.query(question)
        end
    end)
end

local function start_html_opener(argv)
    local job = vim.fn.jobstart(argv, {
        detach = true,
        on_exit = function(_, code)
            if code ~= 0 then
                vim.schedule(function()
                    notify("HTML opener exited with code " .. code, vim.log.levels.WARN)
                end)
            end
        end,
    })
    if job <= 0 then
        notify("could not start HTML opener: " .. table.concat(argv, " "), vim.log.levels.ERROR)
        return false
    end
    return true
end

local function browser_argv(path)
    local setting = opts().ui.open_html
    if type(setting) == "table" then
        if type(setting[1]) ~= "string" or setting[1] == "" then
            return nil
        end
        local argv = vim.deepcopy(setting)
        argv[#argv + 1] = path
        return argv
    end
    if
        type(setting) == "string"
        and setting ~= ""
        and setting ~= "browser"
        and setting ~= "system"
        and setting ~= "disabled"
    then
        return { setting, path }
    end

    if vim.fn.has("mac") == 1 and vim.fn.executable("open") == 1 then
        return { "open", path }
    end
    if vim.fn.has("unix") == 1 and vim.fn.executable("sensible-browser") == 1 then
        return { "sensible-browser", path }
    end
    for _, executable in ipairs({ "google-chrome", "chromium", "firefox" }) do
        if vim.fn.executable(executable) == 1 then
            return { executable, path }
        end
    end
    -- Neovim implements vim.ui.open with the native opener for the current
    -- platform, including Windows. Returning nil selects that fallback.
end

function M.open_html(root)
    root = root or M.root()
    if not root then
        notify("no repository root found", vim.log.levels.WARN)
        return
    end
    local path = output_path(root, output_files.html)
    if vim.fn.filereadable(path) ~= 1 then
        notify("graph HTML is not available at " .. path, vim.log.levels.WARN)
        return
    end
    if opts().ui.open_html == "disabled" then
        notify("opening graph HTML is disabled")
        return
    end

    if opts().ui.open_html ~= "system" then
        local argv = browser_argv(path)
        if argv then
            return start_html_opener(argv)
        end
    end

    if not vim.ui.open then
        notify("no HTML opener is available for " .. path, vim.log.levels.WARN)
        return false
    end
    local _, err = vim.ui.open(path)
    if err then
        notify("could not open graph HTML: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

local function guidance_present(root, provider)
    local file = provider == "claude" and "CLAUDE.md" or "AGENTS.md"
    local path = vim.fs.joinpath(root, file)
    if vim.fn.filereadable(path) ~= 1 then
        return false
    end
    for _, line in ipairs(vim.fn.readfile(path)) do
        if line:lower():find("graphify", 1, true) then
            return true
        end
    end
    return false
end

function M.guidance_status(root)
    root = root or M.root()
    local result = {}
    if not root then
        return result
    end
    for _, provider in ipairs(opts().agents.providers) do
        result[provider] = guidance_present(root, provider)
    end
    return result
end

local function check_guidance(root, active_provider)
    local agents = opts().agents
    if not agents.check_on_start or not agents.warn_when_missing or warned_guidance[root] then
        return
    end
    local providers = active_provider and { active_provider } or agents.providers
    for _, provider in ipairs(providers) do
        if (provider == "codex" or provider == "claude") and not guidance_present(root, provider) then
            warned_guidance[root] = true
            notify(
                "agent guidance is not installed; run `graphify "
                    .. provider
                    .. " install` in this repository to prefer graph queries",
                vim.log.levels.WARN
            )
            return
        end
    end
end

local function choose(root, kind, message, action)
    if
        prompted_repositories[root]
        or skipped(root, kind)
        or (pending_choices[root] and pending_choices[root][kind])
    then
        return
    end

    prompted_repositories[root] = true
    pending_choices[root] = pending_choices[root] or {}
    pending_choices[root][kind] = true

    local function respond(choice)
        pending_choices[root][kind] = nil
        if choice == "Run now" then
            local output_choices = { "Keep graph output in Git", "Ignore graph output in Git" }
            local function finish_output_choice(output_choice)
                if output_choice == "Ignore graph output in Git" then
                    M.ignore_graph_output(root)
                end
                action()
            end

            local confirm = opts().ui.confirm
            if type(confirm) == "function" then
                confirm(
                    output_choices,
                    { prompt = "Graphify: keep generated graph output in Git?" },
                    finish_output_choice
                )
                return
            end
            require("aiterm.ui.picker").select(
                "Graphify: keep generated graph output in Git?",
                output_choices,
                function(index)
                    finish_output_choice(output_choices[index])
                end,
                function()
                    finish_output_choice(nil)
                end
            )
        elseif choice == "Skip and don't ask again" then
            remember_skip(root, kind, true)
        else
            remember_skip(root, kind)
        end
    end

    local confirm = opts().ui.confirm
    if type(confirm) == "function" then
        confirm({ "Run now", "Skip", "Skip and don't ask again" }, { prompt = "Graphify: " .. message }, respond)
        return
    end

    -- The built-in vim.ui.select fallback is implemented with inputlist(),
    -- which clashes with command-line UIs such as noice.nvim during startup.
    -- Keep this picker self-contained so its list and search prompt share one
    -- lifecycle and do not leave overlapping command-line floats behind.
    local choices = { "Run now", "Skip", "Skip and don't ask again" }
    require("aiterm.ui.picker").select("Graphify: " .. message, choices, function(index)
        respond(choices[index])
    end, function()
        respond(nil)
    end)
end

function M.prepare_workspace(path, context)
    context = context or {}
    local graphify = opts()
    if not graphify.enabled then
        return
    end
    if context.source == "startup" then
        if not graphify.check.on_vim_enter or graphify.lifecycle == "manual" then
            return
        end
    else
        if context.kind and graphify.lifecycle ~= "on_ai_start" then
            return
        end
        if not context.kind and graphify.lifecycle ~= "on_workspace_enter" then
            return
        end
    end

    if context.source == "treehouse" and not graphify.check.on_treehouse_workspace then
        return
    end
    if context.kind and context.source ~= "treehouse" and not graphify.check.on_ai_start then
        return
    end

    local root = M.root(path)
    local status = M.status(root)
    invoke_callback("on_status", status, root)
    if status.kind == "fresh" then
        check_guidance(root, context.kind)
        return
    end
    if status.kind == "missing" then
        if graphify.missing_graph == "build" and automatic_build_allowed(root) then
            M.build(root, { automatic = true })
        elseif graphify.missing_graph == "ask" then
            choose(root, "missing", "no graph exists for this repository. Build it?", function()
                M.build(root)
            end)
        end
        return
    end
    if status.kind == "stale" then
        if graphify.stale_graph == "update" then
            M.update(root, { automatic = true })
        elseif graphify.stale_graph == "ask" then
            choose(root, "stale", "the graph may be stale. Update it?", function()
                M.update(root)
            end)
        end
    end
end

function M.show_status()
    local status = M.status()
    local root = status.root and (" for " .. status.root) or ""
    notify(status.kind .. root .. (status.message and ": " .. status.message or ""))
    invoke_callback("on_status", status, status.root)
    return status
end

function M.reset_skips(root)
    root = root or M.root()
    if not root then
        notify("no repository root found", vim.log.levels.WARN)
        return false
    end

    local stored = load_state()[root]
    if stored then
        stored.skips = nil
        save_state()
    end
    session_skips[root] = nil
    prompted_repositories[root] = nil
    pending_choices[root] = nil
    notify("cleared saved Graphify prompt choices for " .. root)
    return true
end

function M.setup()
    vim.api.nvim_create_user_command("AITermGraphifyStatus", M.show_status, {
        desc = "Show Graphify status for the current repository",
    })
    vim.api.nvim_create_user_command("AITermGraphifyBuild", function()
        M.build(M.root())
    end, {
        desc = "Build a Graphify graph for the current repository",
    })
    vim.api.nvim_create_user_command("AITermGraphifyUpdate", function(command)
        M.update(M.root(), { force = command.bang })
    end, {
        bang = true,
        desc = "Incrementally update the Graphify graph for the current repository",
    })
    vim.api.nvim_create_user_command("AITermGraphifyQuery", function(command)
        M.query(command.args)
    end, {
        nargs = "+",
        desc = "Query the Graphify graph for the current repository",
    })
    vim.api.nvim_create_user_command("AITermGraphifyExplain", function(command)
        M.explain(command.args)
    end, {
        nargs = "+",
        desc = "Explain a Graphify node for the current repository",
    })
    vim.api.nvim_create_user_command("AITermGraphifyPath", function(command)
        if #command.fargs ~= 2 then
            notify("path requires exactly two node names", vim.log.levels.WARN)
            return
        end
        M.path(command.fargs[1], command.fargs[2])
    end, {
        nargs = "+",
        desc = "Find the Graphify path between two nodes",
    })
    vim.api.nvim_create_user_command("AITermGraphifyOpen", function()
        M.open_html()
    end, {
        desc = "Open the Graphify HTML graph for the current repository",
    })
    vim.api.nvim_create_user_command("AITermGraphifyResetPrompts", function()
        M.reset_skips()
    end, {
        desc = "Clear saved Graphify skip choices for the current repository",
    })

    local group = vim.api.nvim_create_augroup("AitermGraphify", { clear = true })
    if opts().check.on_vim_enter then
        vim.api.nvim_create_autocmd("VimEnter", {
            group = group,
            callback = function()
                -- AI autostart performs its own Graphify preparation only
                -- after the terminal has received focus. Do not start a
                -- competing timer that can leave a visible picker focused
                -- behind that terminal.
                local ai_owns_startup = opts().lifecycle == "on_ai_start"
                    and config.opts.ai.enabled
                    and config.opts.ai.autostart
                    and require("aiterm.ai").should_autostart()
                if ai_owns_startup then
                    return
                end
                vim.defer_fn(function()
                    M.prepare_workspace(vim.fn.getcwd(), { source = "startup" })
                end, opts().check.debounce_ms)
            end,
        })
    end
    if opts().lifecycle == "on_workspace_enter" and opts().check.on_dir_changed then
        vim.api.nvim_create_autocmd("DirChanged", {
            group = group,
            callback = function(event)
                vim.defer_fn(function()
                    M.prepare_workspace(event.file, {})
                end, opts().check.debounce_ms)
            end,
        })
    end
end

return M
