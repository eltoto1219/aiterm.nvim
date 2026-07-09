local M = {}
local config = require("aiterm.config")
local buffers = require("aiterm.buffers")
local ui_input = require("aiterm.ui.input")

-- Snapshot of the environment at nvim launch, so terminals spawned later do
-- not inherit mutations made to vim.env during the session.
local launch_env = vim.fn.environ()

local function terminal_env()
    local env = vim.deepcopy(launch_env)
    local extra = config.opts.terminal.env
    if type(extra) == "function" then
        extra = extra()
    end
    if type(extra) == "table" then
        env = vim.tbl_extend("force", env, extra)
    end
    return env
end

local last_terminal_bufnr = nil
local custom_labels = {}
local reopen_tree_on_file_focus = false

local function tree_api()
    local ok, api = pcall(require, "nvim-tree.api")
    return ok and api or nil
end

local function hide_tree_for_terminal()
    local api = tree_api()
    if api and api.tree.is_visible() then
        reopen_tree_on_file_focus = true
        pcall(api.tree.close)
    end
end

local function restore_tree_for_file()
    local api = tree_api()
    if not reopen_tree_on_file_focus or not api or api.tree.is_visible() then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    reopen_tree_on_file_focus = false
    pcall(api.tree.open, { find_file = true, focus = false })
    if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
    end
end

local function close_tree_permanently()
    local ok, api = pcall(require, "nvim-tree.api")
    if ok and api.tree.is_visible() then
        reopen_tree_on_file_focus = false
        pcall(api.tree.close)
    end
end

local function listed_terminal_buffers()
    local terminals = {}

    for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if vim.bo[bufinfo.bufnr].buftype == "terminal" then
            terminals[#terminals + 1] = bufinfo
        end
    end

    table.sort(terminals, function(a, b)
        return a.bufnr < b.bufnr
    end)

    return terminals
end

function M.is_terminal(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal"
end

function M.buffers()
    local buffers = {}

    for _, bufinfo in ipairs(listed_terminal_buffers()) do
        buffers[#buffers + 1] = bufinfo.bufnr
    end

    return buffers
end

function M.buffer_info()
    return listed_terminal_buffers()
end

function M.label_for_buf(bufnr)
    local custom = custom_labels[bufnr]
    if custom and custom ~= "" then
        return custom
    end

    for index, bufinfo in ipairs(listed_terminal_buffers()) do
        if bufinfo.bufnr == bufnr then
            return "T:" .. index
        end
    end

    return nil
end

function M.get_last_terminal_buf()
    if M.is_terminal(last_terminal_bufnr or -1) and vim.fn.buflisted(last_terminal_bufnr) == 1 then
        return last_terminal_bufnr
    end

    return nil
end

local function enter_insert()
    vim.cmd.startinsert()
end

local safe_switch_buffer

local function with_current_window_buffer_unlocked(callback)
    local current_win = vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(current_win) then
        return false
    end

    local had_winfixbuf = vim.wo[current_win].winfixbuf
    if had_winfixbuf then
        vim.wo[current_win].winfixbuf = false
    end

    local ok = pcall(callback)

    if vim.api.nvim_win_is_valid(current_win) then
        vim.wo[current_win].winfixbuf = had_winfixbuf
    end

    return ok
end

safe_switch_buffer = function(bufnr)
    return with_current_window_buffer_unlocked(function()
        vim.cmd.buffer(bufnr)
    end)
end

local function safe_enew()
    return with_current_window_buffer_unlocked(function()
        vim.cmd.enew()
    end)
end

local function terminal_keys(keys)
    return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function repeat_key(key, count)
    if count <= 0 then
        return ""
    end
    return string.rep(key, count)
end

local function terminal_cursor_keys(from, to)
    local keys = {}
    local row_delta = to[1] - from[1]
    local col_delta = to[2] - from[2]

    keys[#keys + 1] = repeat_key(row_delta > 0 and "<Down>" or "<Up>", math.abs(row_delta))
    keys[#keys + 1] = repeat_key(col_delta > 0 and "<Right>" or "<Left>", math.abs(col_delta))

    return table.concat(keys)
end

local function terminal_target_cursor(target)
    return { target[1], math.max(target[2] - 1, 0) }
end

local function cursor_is_live_input(from, cursor)
    return type(from) == "table" and cursor[1] == from[1]
end

local function resume_target_cursor(action)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local target = { cursor[1], cursor[2] }
    local line = vim.api.nvim_get_current_line()

    if action == "a" then
        target[2] = math.min(target[2] + 1, #line)
    elseif action == "I" then
        local first = line:find("%S")
        target[2] = first and first - 1 or 0
    elseif action == "A" then
        target[2] = #line
    end

    return target
end

local function resume_terminal_input(action)
    local bufnr = vim.api.nvim_get_current_buf()
    local from = vim.b[bufnr].aiterm_terminal_input_cursor
    local cursor = vim.api.nvim_win_get_cursor(0)
    local to = resume_target_cursor(action)
    local keys

    if cursor_is_live_input(from, cursor) then
        to = terminal_target_cursor(to)
        keys = terminal_cursor_keys(from, to)
    else
        keys = ""
    end

    vim.cmd.startinsert()
    if keys ~= "" then
        vim.schedule(function()
            if vim.api.nvim_get_current_buf() == bufnr and M.is_terminal(bufnr) then
                vim.api.nvim_feedkeys(terminal_keys(keys), "t", false)
                if cursor_is_live_input(from, cursor) then
                    vim.b[bufnr].aiterm_terminal_input_cursor = to
                end
            end
        end)
    end
end

function M.open_new()
    hide_tree_for_terminal()
    if not safe_enew() then
        return
    end
    vim.fn.termopen(vim.o.shell, { env = terminal_env() })
    enter_insert()
end

function M.set_label(bufnr, label)
    if label and label ~= "" then
        custom_labels[bufnr] = label
    else
        custom_labels[bufnr] = nil
    end
    M.refresh_names()
    vim.cmd.redrawtabline()
    local ok, lualine = pcall(require, "lualine")
    if ok then
        lualine.refresh({
            place = { "tabline", "statusline" },
        })
    end
end

function M.open_command(command, label, opts)
    hide_tree_for_terminal()
    if not safe_enew() then
        return nil
    end
    local bufnr = vim.api.nvim_get_current_buf()

    if label and label ~= "" then
        custom_labels[bufnr] = label
    end

    -- Tagged before termopen so the TermOpen/BufEnter autocmds firing inside
    -- it already see this as an AI buffer (e.g. last-terminal tracking).
    if opts and opts.ai_kind then
        vim.b[bufnr].aiterm_ai_kind = opts.ai_kind
    end

    local job_opts = { env = terminal_env() }
    if opts and opts.cwd and vim.fn.isdirectory(opts.cwd) == 1 then
        job_opts.cwd = opts.cwd
    end

    vim.fn.termopen(command, job_opts)
    vim.schedule(M.refresh_names)
    enter_insert()

    return bufnr
end

-- AI harness buffers are terminals too, but <leader>t must never land on
-- them: they have their own toggle. Fallback selection uses this list.
local function plain_terminal_buffers()
    local terms = {}
    for _, bufnr in ipairs(M.buffers()) do
        if vim.b[bufnr].aiterm_ai_kind == nil then
            terms[#terms + 1] = bufnr
        end
    end

    return terms
end

function M.focus(bufnr)
    hide_tree_for_terminal()
    if not safe_switch_buffer(bufnr) then
        return false
    end
    enter_insert()
    return true
end

function M.ensure()
    local terms = plain_terminal_buffers()
    local current = vim.api.nvim_get_current_buf()

    if M.is_terminal(current) then
        enter_insert()
        return
    end

    local last_terminal = M.get_last_terminal_buf()
    if last_terminal then
        hide_tree_for_terminal()
        if not safe_switch_buffer(last_terminal) then
            return
        end
        enter_insert()
        return
    end

    if #terms > 0 then
        hide_tree_for_terminal()
        if not safe_switch_buffer(terms[1]) then
            return
        end
        enter_insert()
        return
    end

    M.open_new()
end

function M.toggle()
    local current = vim.api.nvim_get_current_buf()
    local terms = plain_terminal_buffers()

    if M.is_terminal(current) and vim.b[current].aiterm_ai_kind == nil then
        local target = buffers.get_workflow_return_buf(function(bufnr)
            return M.is_terminal(bufnr) and vim.b[bufnr].aiterm_ai_kind == nil
        end)
        if target then
            if not safe_switch_buffer(target) then
                return
            end
            if M.is_terminal(target) then
                vim.cmd.startinsert()
            elseif buffers.is_named_edit_buf(target) then
                restore_tree_for_file()
            end
        end
        return
    end

    local last_terminal = M.get_last_terminal_buf()
    if last_terminal then
        hide_tree_for_terminal()
        if not safe_switch_buffer(last_terminal) then
            return
        end
        enter_insert()
        return
    end

    if #terms > 0 then
        hide_tree_for_terminal()
        if not safe_switch_buffer(terms[1]) then
            return
        end
        enter_insert()
        return
    end

    M.open_new()
end

local function cycle(offset)
    local current = vim.api.nvim_get_current_buf()
    local current_is_ai = vim.b[current].aiterm_ai_kind ~= nil
    local all = M.buffer_info()
    local terms = {}
    for _, item in ipairs(all) do
        local item_is_ai = vim.b[item.bufnr].aiterm_ai_kind ~= nil
        if item_is_ai == current_is_ai then
            terms[#terms + 1] = item
        end
    end

    for index, item in ipairs(terms) do
        if item.bufnr == current then
            local target = terms[index + offset]
            if not target then
                target = offset > 0 and terms[1] or terms[#terms]
            end

            if target and target.bufnr ~= current then
                hide_tree_for_terminal()
                if not safe_switch_buffer(target.bufnr) then
                    if M.is_terminal(vim.api.nvim_get_current_buf()) then
                        enter_insert()
                    end
                    return
                end
            end

            if M.is_terminal(vim.api.nvim_get_current_buf()) then
                enter_insert()
            end
            return
        end
    end
end

function M.forward()
    cycle(1)
end

function M.backward()
    cycle(-1)
end

-- nvim_buf_set_name has :file semantics: the old name is kept on a new
-- unlisted buffer. Those leftovers make later renames fail with "buffer name
-- already in use", so terminals get stuck on stale T:n names after closes.
local function wipe_unlisted_name_holder(name, keep_bufnr)
    local absolute_name = vim.fn.fnamemodify(name, ":p")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= keep_bufnr and vim.b[buf].aiterm_terminal_name_holder then
            local bufname = vim.api.nvim_buf_get_name(buf)
            if bufname == name or bufname == absolute_name then
                pcall(vim.api.nvim_buf_delete, buf, { force = false })
            end
        end
    end
end

local function buffer_name_in_use(name, keep_bufnr)
    local absolute_name = vim.fn.fnamemodify(name, ":p")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= keep_bufnr then
            local bufname = vim.api.nvim_buf_get_name(buf)
            if bufname == name or bufname == absolute_name then
                return true
            end
        end
    end

    return false
end

function M.refresh_names()
    for index, bufinfo in ipairs(listed_terminal_buffers()) do
        local desired = M.label_for_buf(bufinfo.bufnr) or ("T:" .. index)
        local current = vim.api.nvim_buf_get_name(bufinfo.bufnr)

        if vim.fs.basename(current) ~= desired then
            wipe_unlisted_name_holder(desired, bufinfo.bufnr)
            if buffer_name_in_use(desired, bufinfo.bufnr) then
                goto continue
            end
            local existing_buffers = {}
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                existing_buffers[buf] = true
            end
            if pcall(vim.api.nvim_buf_set_name, bufinfo.bufnr, desired) then
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if
                        not existing_buffers[buf]
                        and vim.fn.buflisted(buf) == 0
                        and vim.api.nvim_buf_get_name(buf) == current
                    then
                        vim.b[buf].aiterm_terminal_name_holder = true
                    end
                end
                wipe_unlisted_name_holder(current, bufinfo.bufnr)
            end
        end
        ::continue::
    end
end

function M.rename_current()
    local current = vim.api.nvim_get_current_buf()

    if not M.is_terminal(current) then
        vim.notify("Current buffer is not a terminal", vim.log.levels.WARN)
        return
    end

    -- Persistent process labels keep their P:/P:th: prefix across renames.
    local existing = custom_labels[current] or ""
    local prefix = existing:match("^(P:th:)") or existing:match("^(P:)")

    ui_input.centered({
        title = " Terminal Name ",
        prompt = "Name: ",
        default = prefix and existing:sub(#prefix + 1) or "",
    }, function(input)
        if input == nil then
            return
        end

        local trimmed = vim.trim(input)
        if trimmed == "" then
            if prefix then
                vim.notify("Persistent terminals need a name after " .. prefix, vim.log.levels.WARN)
                return
            end
            M.set_label(current, nil)
            vim.notify("Reset terminal name to default numbering")
        else
            M.set_label(current, (prefix or "") .. trimmed)
            vim.notify("Renamed terminal to " .. (prefix or "") .. trimmed)
        end

        if M.is_terminal(current) and vim.api.nvim_get_current_buf() == current then
            enter_insert()
        end
    end)
end

-- Lines where the user typed a prompt: ❯ (claude), › (codex), or a plain >.
-- No semantic markers exist in these transcripts (the TUIs don't emit OSC 133
-- prompt marks), so a pattern over the rendered text is the mechanism.
M.prompt_pattern = [[\v^\s*[❯›>]\s]]

local function prompt_jump(direction)
    return function()
        if vim.fn.search(M.prompt_pattern, direction < 0 and "bW" or "W") ~= 0 then
            vim.cmd("normal! zz")
        elseif direction > 0 then
            -- Past the last transcript prompt: the live input box at the
            -- bottom doesn't match the pattern (it's drawn inside a border),
            -- so snap to it while remaining in normal mode.
            vim.cmd("normal! G")
        end
    end
end

function M.set_prompt_jump_keymaps(bufnr)
    local mappings = config.opts.mappings.terminal
    local jumps = {
        { mappings.prompt_prev, -1, "Jump to previous prompt" },
        { mappings.prompt_next, 1, "Jump to next prompt, or to the live input in normal mode" },
    }
    for _, jump in ipairs(jumps) do
        local lhs, direction, desc = jump[1], jump[2], jump[3]
        for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
            if key == false or key == nil or key == "" then
                goto continue
            end
            vim.keymap.set("n", key, prompt_jump(direction), {
                buffer = bufnr,
                silent = true,
                desc = desc,
            })
            vim.keymap.set("t", key, function()
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
                vim.schedule(prompt_jump(direction))
            end, {
                buffer = bufnr,
                silent = true,
                desc = desc,
            })
            ::continue::
        end
    end
end

function M.configure_persistent_buffer(bufnr, session_name)
    if not M.is_terminal(bufnr) then
        return
    end

    vim.b[bufnr].aiterm_process_name = session_name

    -- shpool passes raw bytes through, so nvim's terminal emulator owns the
    -- history: native motions, search, visual mode, and yank work directly.
    -- 10000 matches the shpool restore window (session_restore_mode lines).
    vim.bo[bufnr].scrollback = 10000

    M.set_prompt_jump_keymaps(bufnr)

    local persistent_esc = config.opts.mappings.terminal.persistent_esc
    if persistent_esc then
        for _, lhs in ipairs(type(persistent_esc) == "table" and persistent_esc or { persistent_esc }) do
            if lhs ~= false and lhs ~= nil and lhs ~= "" then
                vim.keymap.set("t", lhs == true and "<Esc>" or lhs, "<C-\\><C-n>", {
                    buffer = bufnr,
                    silent = true,
                    nowait = true,
                    desc = "Leave terminal input mode",
                })
            end
        end
    end
end

function M.persistent_process_name(bufnr)
    if not M.is_terminal(bufnr) then
        return nil
    end

    local name = vim.b[bufnr].aiterm_process_name
    return type(name) == "string" and name ~= "" and name or nil
end

function M.find_persistent_buffer(session_name)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if M.persistent_process_name(bufnr) == session_name then
            local job_id = vim.b[bufnr].terminal_job_id
            if type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
                return bufnr
            end
        end
    end
end

-- Terminal window styling: pinned background, no numbers/signcolumn, and
-- startinsert/stopinsert on enter/leave. Gated by opts.terminal.style.
local function normalized_background()
    local value = config.opts.terminal.background
    if type(value) == "string" then
        return tonumber(value:gsub("#", ""), 16)
    end
    return value
end

local function setup_style(group)
    local terminal_bg = normalized_background()

    local function set_terminal_highlights()
        if not terminal_bg then
            return
        end
        local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        local normal_nc = vim.api.nvim_get_hl(0, { name = "NormalNC", link = false })
        local end_of_buffer = vim.api.nvim_get_hl(0, { name = "EndOfBuffer", link = false })

        vim.api.nvim_set_hl(0, "AitermTerminalNormal", { fg = normal.fg, bg = terminal_bg })
        vim.api.nvim_set_hl(0, "AitermTerminalNormalNC", { fg = normal_nc.fg or normal.fg, bg = terminal_bg })
        vim.api.nvim_set_hl(0, "AitermTerminalEndOfBuffer", { fg = end_of_buffer.fg or terminal_bg, bg = terminal_bg })
    end

    local function apply_terminal_window_style(winid)
        if not terminal_bg or not vim.api.nvim_win_is_valid(winid) then
            return
        end

        vim.wo[winid].winhighlight = table.concat({
            "Normal:AitermTerminalNormal",
            "NormalNC:AitermTerminalNormalNC",
            "EndOfBuffer:AitermTerminalEndOfBuffer",
        }, ",")
    end

    local function clear_terminal_window_style(winid)
        if not vim.api.nvim_win_is_valid(winid) then
            return
        end

        local current = vim.wo[winid].winhighlight or ""
        if current:find("AitermTerminal", 1, true) then
            vim.wo[winid].winhighlight = ""
        end
    end

    vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
        group = group,
        callback = set_terminal_highlights,
    })

    vim.api.nvim_create_autocmd({ "TermOpen", "TermEnter", "BufEnter" }, {
        group = group,
        pattern = "term://*",
        callback = function()
            vim.wo.relativenumber = false
            vim.wo.number = false
            vim.opt_local.signcolumn = "no"
            apply_terminal_window_style(vim.api.nvim_get_current_win())
        end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        group = group,
        pattern = "*",
        callback = function(event)
            if vim.bo[event.buf].buftype == "" then
                clear_terminal_window_style(vim.api.nvim_get_current_win())
                -- restore the user's global defaults, not hardcoded values
                vim.wo.number = vim.go.number
                vim.wo.relativenumber = vim.go.relativenumber
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        pattern = "term://*",
        callback = function()
            vim.cmd.stopinsert()
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        pattern = "term://*",
        callback = function()
            vim.cmd.startinsert()
        end,
    })
end

function M.setup()
    local group = vim.api.nvim_create_augroup("AitermTerminalState", { clear = true })

    vim.api.nvim_create_user_command("TerminalRename", M.rename_current, {
        desc = "Rename a terminal while preserving persistent prefixes",
    })

    vim.api.nvim_create_autocmd({ "TermOpen", "BufAdd", "BufEnter", "BufWipeout", "BufDelete" }, {
        group = group,
        callback = function(event)
            if event.event == "BufWipeout" or event.event == "BufDelete" then
                custom_labels[event.buf] = nil
            elseif M.is_terminal(event.buf) then
                -- AI harness buffers have their own toggle (<leader>m); keep
                -- <leader>t pointed at the last plain terminal.
                if vim.b[event.buf].aiterm_ai_kind == nil then
                    last_terminal_bufnr = event.buf
                end
                hide_tree_for_terminal()
            elseif buffers.is_named_edit_buf(event.buf) then
                restore_tree_for_file()
            end
            vim.schedule(M.refresh_names)
        end,
    })

    vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        callback = function(event)
            local opts = { buffer = event.buf, silent = true }
            local mappings = config.opts.mappings.terminal

            if mappings.insert_resume then
                local lhs_list = type(mappings.insert_resume) == "table" and mappings.insert_resume
                    or { "i", "a", "I", "A" }
                for _, lhs in ipairs(lhs_list) do
                    if lhs == false or lhs == nil or lhs == "" then
                        goto continue
                    end
                    vim.keymap.set(
                        "n",
                        lhs,
                        function()
                            resume_terminal_input(lhs)
                        end,
                        vim.tbl_extend("force", opts, {
                            desc = "Return to terminal input mode",
                        })
                    )
                    ::continue::
                end
            end
            if mappings.rename then
                for _, lhs in ipairs(type(mappings.rename) == "table" and mappings.rename or { mappings.rename }) do
                    if lhs ~= false and lhs ~= nil and lhs ~= "" then
                        vim.keymap.set(
                            "n",
                            lhs,
                            M.rename_current,
                            vim.tbl_extend("force", opts, {
                                desc = "Rename current terminal",
                            })
                        )
                    end
                end
            end
        end,
    })

    vim.api.nvim_create_autocmd("TermLeave", {
        group = group,
        callback = function(event)
            if M.is_terminal(event.buf) then
                vim.b[event.buf].aiterm_terminal_input_cursor = vim.api.nvim_win_get_cursor(0)
            end
        end,
    })

    if config.opts.terminal.style then
        setup_style(group)
    end
end

function M.close_tree_permanently()
    close_tree_permanently()
end

return M
