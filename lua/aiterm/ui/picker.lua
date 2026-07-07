local M = {}

-- Centered floating list picker: leaves Insert mode; j/k/<Down>/<Up> move
-- (wrapping), <CR> selects, and q/<Esc> cancel. Calls on_choice with the
-- selected index, or the optional on_cancel callback after cancellation.
function M.select(prompt, labels, on_choice, on_cancel)
    if #labels == 0 then
        return
    end

    vim.cmd.stopinsert()

    local width = math.max(40, math.min(60, vim.o.columns - 8))
    local height = math.min(#labels + 2, math.max(4, vim.o.lines - 8))
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

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, labels)

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].filetype = "aiterm_picker"

    local function close_picker()
        if vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_win_close(winid, true)
        end
    end

    local function choose_current()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        close_picker()
        if labels[line] then
            on_choice(line)
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
            local line = vim.api.nvim_win_get_cursor(winid)[1]
            local target = line + delta
            if target < 1 then
                target = #labels
            elseif target > #labels then
                target = 1
            end
            vim.api.nvim_win_set_cursor(winid, { target, 0 })
        end
    end

    local function set_keymaps(lhs, rhs, desc)
        if not lhs then
            return
        end
        for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
            vim.keymap.set("n", key, rhs, { buffer = bufnr, silent = true, nowait = true, desc = desc })
        end
    end

    local mappings = require("aiterm.config").opts.ui.picker.mappings
    set_keymaps(mappings.down, move(1), "Picker: next item")
    set_keymaps(mappings.up, move(-1), "Picker: previous item")
    set_keymaps("<Down>", move(1), "Picker: next item")
    set_keymaps("<Up>", move(-1), "Picker: previous item")
    set_keymaps(mappings.confirm, choose_current, "Picker: select item")
    set_keymaps(mappings.cancel, cancel_picker, "Picker: cancel")

    vim.api.nvim_win_set_cursor(winid, { 1, 0 })
end

return M
