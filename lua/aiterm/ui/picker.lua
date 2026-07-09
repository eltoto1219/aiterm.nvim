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
end

-- Centered searchable picker. Plain labels preserve the original callback API:
-- on_choice receives the original label index after filtering.
function M.select(prompt, labels, on_choice, on_cancel)
    if #labels == 0 then
        return
    end

    setup_highlights()

    local all_items = normalize_items(labels)
    local visible = vim.deepcopy(all_items)
    local query = ""
    local selected = 1

    local width = math.max(44, math.min(72, vim.o.columns - 8))
    local height = math.min(#labels + 3, math.max(6, vim.o.lines - 8))
    local row = math.floor((vim.o.lines - height) / 2) - 1
    local col = math.floor((vim.o.columns - width) / 2)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local winid = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.max(row, 0),
        col = math.max(col, 0),
        style = "minimal",
        border = "rounded",
        title = " " .. prompt .. " ",
        title_pos = "center",
    })

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].modifiable = true
    vim.bo[bufnr].filetype = "aiterm_picker"
    vim.wo[winid].wrap = false
    vim.wo[winid].winhighlight = "CursorLine:AitermPickerSelected"

    local prompt_prefix = "Search: "
    local rendering = false

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

        local lines = { prompt_prefix .. query, "" }
        if #visible == 0 then
            lines[#lines + 1] = "No matches"
        else
            vim.list_extend(lines, numbered_labels(visible))
        end

        vim.bo[bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        if #visible > 0 then
            vim.api.nvim_buf_set_extmark(bufnr, ns, selected + 1, 0, {
                line_hl_group = "AitermPickerSelected",
            })
        end
        vim.bo[bufnr].modifiable = true
        pcall(vim.api.nvim_win_set_cursor, winid, { 1, #prompt_prefix + #query })
        rendering = false
    end

    local function close_picker()
        if vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_win_close(winid, true)
        end
    end

    local function choose_current()
        local item = visible[selected]
        close_picker()
        if item then
            on_choice(item.index)
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
            vim.keymap.set(mode, key, rhs, { buffer = bufnr, silent = true, nowait = true, desc = desc })
        end
    end

    local function focus_prompt()
        if vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_set_current_win(winid)
            vim.api.nvim_win_set_cursor(winid, { 1, #prompt_prefix + #query })
            vim.cmd.startinsert()
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
    set_keymaps({ "n", "i" }, mappings.cancel, cancel_picker, "Picker: cancel")
    set_keymaps("n", "i", focus_prompt, "Picker: focus search")
    set_keymaps("n", "/", focus_prompt, "Picker: focus search")

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = bufnr,
        callback = function()
            if rendering then
                return
            end
            local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
            if not vim.startswith(line, prompt_prefix) then
                render()
                return
            end
            query = line:sub(#prompt_prefix + 1)
            selected = 1
            render()
        end,
    })

    render()
    focus_prompt()
end

return M
