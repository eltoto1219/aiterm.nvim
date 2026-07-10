local M = {}

local ns = vim.api.nvim_create_namespace("aiterm_picker")

local function item_label(item)
    if type(item) == "table" then
        return item.label or item.display or item.ordinal or tostring(item.value or "")
    end
    return tostring(item)
end

local function normalize_items(labels)
    local items = {}
    for index, label in ipairs(labels) do
        items[index] = {
            index = index,
            label = item_label(label),
            ordinal = item_label(label):lower(),
        }
    end
    return items
end

local function matches(item, query)
    if query == "" then
        return true
    end

    local option_number = query:match("^(%d+)%.?$")
    if option_number then
        return item.index == tonumber(option_number)
    end

    local ordinal = item.ordinal
    query = query:lower()
    if ordinal:find(query, 1, true) then
        return true
    end

    local cursor = 1
    for i = 1, #query do
        local found = ordinal:find(query:sub(i, i), cursor, true)
        if not found then
            return false
        end
        cursor = found + 1
    end
    return true
end

local function numbered_labels(items)
    local rendered = {}
    local digits = #tostring(#items)

    for index, item in ipairs(items) do
        rendered[index] = string.format("%" .. digits .. "d. %s", item.index, item.label)
    end

    return rendered
end

local function setup_highlights()
    local colors = require("aiterm.ui.colors")
    local normal = colors.get_hl("NormalFloat")
    if not normal.bg then
        normal = colors.get_hl("Normal")
    end

    local cursorline = colors.get_hl("CursorLine")
    local visual = colors.get_hl("Visual")
    local fallback_bg = cursorline.bg or visual.bg
    local bg = fallback_bg

    if normal.bg and fallback_bg then
        bg = colors.blend(normal.bg, fallback_bg, 0.45)
    elseif not bg then
        bg = vim.o.background == "light" and 0xe6e6e6 or 0x303030
    end

    vim.api.nvim_set_hl(0, "AitermPickerSelected", {
        bg = bg,
        fg = normal.fg,
    })

    local prompt = colors.get_hl("FloatTitle")
    if not prompt.fg then
        prompt = colors.get_hl("Title")
    end
    if not prompt.fg then
        prompt = colors.get_hl("Special")
    end
    if not prompt.fg then
        prompt = colors.get_hl("FloatBorder")
    end

    vim.api.nvim_set_hl(0, "AitermPickerPrompt", {
        fg = prompt.fg or normal.fg,
        bold = prompt.bold,
    })
end

-- Centered searchable picker. Plain labels preserve the original callback API:
-- on_choice receives the original label index after filtering.
function M.select(prompt, labels, on_choice, on_cancel)
    if #labels == 0 then
        return
    end

    -- A picker can open while an AI terminal owns terminal-mode input. Leave
    -- that mode before creating and focusing the prompt float so subsequent
    -- keys are consumed only by the picker search buffer.
    if vim.bo.buftype == "terminal" then
        vim.cmd.stopinsert()
    end

    setup_highlights()

    local all_items = normalize_items(labels)
    local visible = vim.deepcopy(all_items)
    local query = ""
    local selected = 1

    local width = math.max(44, math.min(72, vim.o.columns - 8))
    local list_height = math.min(#labels, math.max(1, vim.o.lines - 10))
    local height = list_height + 4
    local row = math.floor((vim.o.lines - height) / 2) - 1
    local col = math.floor((vim.o.columns - width) / 2)
    local list_bufnr = vim.api.nvim_create_buf(false, true)
    local prompt_bufnr = vim.api.nvim_create_buf(false, true)
    local list_winid = vim.api.nvim_open_win(list_bufnr, true, {
        relative = "editor",
        width = width,
        height = list_height,
        row = math.max(row, 0),
        col = math.max(col, 0),
        style = "minimal",
        border = "rounded",
        title = " " .. prompt .. " ",
        title_pos = "center",
    })
    local prompt_winid = vim.api.nvim_open_win(prompt_bufnr, true, {
        relative = "editor",
        width = width,
        height = 1,
        row = math.max(row + list_height + 2, 0),
        col = math.max(col, 0),
        style = "minimal",
        border = "rounded",
    })

    for _, bufnr in ipairs({ list_bufnr, prompt_bufnr }) do
        vim.bo[bufnr].bufhidden = "wipe"
        vim.bo[bufnr].buftype = "nofile"
        vim.bo[bufnr].swapfile = false
        vim.bo[bufnr].modifiable = true
        vim.bo[bufnr].filetype = "aiterm_picker"
    end
    vim.wo[list_winid].wrap = false
    vim.wo[list_winid].winhighlight = "CursorLine:AitermPickerSelected"
    vim.wo[prompt_winid].wrap = false

    local prompt_prefix = "> "
    local rendering = false
    local closed = false

    local function is_picker_win(winid)
        return winid == list_winid or winid == prompt_winid
    end

    local function render()
        rendering = true
        visible = {}
        for _, item in ipairs(all_items) do
            if matches(item, query) then
                visible[#visible + 1] = item
            end
        end
        if selected > #visible then
            selected = #visible
        end
        if selected < 1 then
            selected = 1
        end

        local lines = {}
        if #visible == 0 then
            lines[#lines + 1] = "No matches"
        else
            vim.list_extend(lines, numbered_labels(visible))
        end

        vim.bo[list_bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(list_bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_clear_namespace(list_bufnr, ns, 0, -1)
        if #visible > 0 then
            vim.api.nvim_buf_set_extmark(list_bufnr, ns, selected - 1, 0, {
                line_hl_group = "AitermPickerSelected",
            })
            pcall(vim.api.nvim_win_set_cursor, list_winid, { selected, 0 })
        end
        vim.bo[prompt_bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { prompt_prefix .. query })
        vim.api.nvim_buf_clear_namespace(prompt_bufnr, ns, 0, -1)
        vim.api.nvim_buf_set_extmark(prompt_bufnr, ns, 0, 0, {
            end_col = #prompt_prefix - 1,
            hl_group = "AitermPickerPrompt",
        })
        pcall(vim.api.nvim_win_set_cursor, prompt_winid, { 1, #prompt_prefix + #query })
        rendering = false
    end

    local function close_picker()
        if closed then
            return
        end
        closed = true
        if vim.api.nvim_win_is_valid(prompt_winid) then
            vim.api.nvim_win_close(prompt_winid, true)
        end
        if vim.api.nvim_win_is_valid(list_winid) then
            vim.api.nvim_win_close(list_winid, true)
        end
    end

    local function choose_current()
        local item = visible[selected]
        close_picker()
        if item then
            -- Let the current mapping and insert-mode lifecycle finish before
            -- a callback can open another picker. Opening it synchronously can
            -- leave the new option list current while Insert mode is inherited
            -- from the prompt that was just closed.
            vim.schedule(function()
                on_choice(item.index)
            end)
        end
    end

    local function cancel_picker()
        close_picker()
        if on_cancel then
            on_cancel()
        end
    end

    local function move(delta)
        return function()
            if closed then
                return
            end
            if #visible == 0 then
                return
            end
            selected = selected + delta
            if selected < 1 then
                selected = #visible
            end
            if selected > #visible then
                selected = 1
            end
            render()
        end
    end

    local function set_keymaps(mode, lhs, rhs, desc)
        if not lhs then
            return
        end
        for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
            for _, bufnr in ipairs({ list_bufnr, prompt_bufnr }) do
                vim.keymap.set(mode, key, rhs, { buffer = bufnr, silent = true, nowait = true, desc = desc })
            end
        end
    end

    local function focus_prompt()
        if vim.api.nvim_win_is_valid(prompt_winid) then
            vim.api.nvim_set_current_win(prompt_winid)
            vim.api.nvim_win_set_cursor(prompt_winid, { 1, #prompt_prefix + #query })
            vim.schedule(function()
                if closed or not vim.api.nvim_win_is_valid(prompt_winid) then
                    return
                end
                if vim.api.nvim_get_current_win() ~= prompt_winid then
                    return
                end
                if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
                    vim.api.nvim_feedkeys("i", "nx!", false)
                end
            end)
        end
    end

    local function focus_list()
        if not closed and vim.api.nvim_win_is_valid(list_winid) then
            vim.api.nvim_set_current_win(list_winid)
        end
    end

    local mappings = require("aiterm.config").opts.mappings.picker
    set_keymaps("n", mappings.down, move(1), "Picker: next item")
    set_keymaps("n", mappings.up, move(-1), "Picker: previous item")
    set_keymaps({ "n", "i" }, "<Down>", move(1), "Picker: next item")
    set_keymaps({ "n", "i" }, "<Up>", move(-1), "Picker: previous item")
    set_keymaps("i", "<C-n>", move(1), "Picker: next item")
    set_keymaps("i", "<C-p>", move(-1), "Picker: previous item")
    set_keymaps({ "n", "i" }, mappings.confirm, choose_current, "Picker: select item")
    -- Insert-mode <Esc> must leave insert mode and hand focus to the option
    -- list through InsertLeave. Keep cancellation in normal mode so users can
    -- cycle choices, then press i to resume editing the prompt text.
    set_keymaps("n", mappings.cancel, cancel_picker, "Picker: cancel")
    vim.keymap.set("i", "<Esc>", function()
        vim.cmd.stopinsert()
        focus_list()
    end, {
        buffer = prompt_bufnr,
        silent = true,
        nowait = true,
        desc = "Picker: focus options",
    })
    set_keymaps("n", "i", focus_prompt, "Picker: focus search")
    set_keymaps("n", "/", focus_prompt, "Picker: focus search")

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = prompt_bufnr,
        callback = function()
            if rendering then
                return
            end
            local line = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1] or ""
            if not vim.startswith(line, prompt_prefix) then
                render()
                return
            end
            query = line:sub(#prompt_prefix + 1)
            selected = 1
            render()
        end,
    })

    vim.api.nvim_create_autocmd("InsertLeave", {
        buffer = prompt_bufnr,
        callback = function()
            vim.schedule(function()
                if closed or not vim.api.nvim_win_is_valid(list_winid) then
                    return
                end
                if not is_picker_win(vim.api.nvim_get_current_win()) then
                    return
                end
                focus_list()
            end)
        end,
    })

    vim.api.nvim_create_autocmd("InsertEnter", {
        buffer = list_bufnr,
        callback = function()
            if closed then
                return
            end
            focus_prompt()
        end,
    })

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = list_bufnr,
        callback = function()
            if rendering or closed then
                return
            end
            render()
        end,
    })

    for _, bufnr in ipairs({ list_bufnr, prompt_bufnr }) do
        vim.api.nvim_create_autocmd("WinLeave", {
            buffer = bufnr,
            callback = function()
                vim.schedule(function()
                    if closed then
                        return
                    end
                    if is_picker_win(vim.api.nvim_get_current_win()) then
                        return
                    end
                    cancel_picker()
                end)
            end,
        })
    end

    render()
    focus_prompt()
end

return M
