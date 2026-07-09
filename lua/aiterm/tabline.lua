local M = {}
local terminal = require("aiterm.terminal")
local colors = require("aiterm.ui.colors")
local augroup = nil
local last_context_winid = nil

local function set_hl(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
end

local function listed_buffers()
    return vim.fn.getbufinfo({ buflisted = 1 })
end

local function regular_buffers()
    local buffers = {}

    for _, bufinfo in ipairs(listed_buffers()) do
        if bufinfo.name ~= "" and not terminal.is_terminal(bufinfo.bufnr) then
            buffers[#buffers + 1] = bufinfo
        end
    end

    table.sort(buffers, function(a, b)
        return a.bufnr < b.bufnr
    end)

    return buffers
end

local function is_ai_buffer(bufnr)
    return vim.b[bufnr].aiterm_ai_kind ~= nil
end

local function is_normal_window(winid)
    local ok, config = pcall(vim.api.nvim_win_get_config, winid)
    return ok and config.relative == ""
end

local function remember_context_window(winid)
    if vim.api.nvim_win_is_valid(winid) and is_normal_window(winid) then
        last_context_winid = winid
    end
end

local function context_bufnr()
    local current_winid = vim.api.nvim_get_current_win()
    if is_normal_window(current_winid) then
        remember_context_window(current_winid)
        return vim.api.nvim_win_get_buf(current_winid)
    end

    if last_context_winid and vim.api.nvim_win_is_valid(last_context_winid) then
        return vim.api.nvim_win_get_buf(last_context_winid)
    end

    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_normal_window(winid) then
            remember_context_window(winid)
            return vim.api.nvim_win_get_buf(winid)
        end
    end

    return vim.api.nvim_get_current_buf()
end

-- AI harness buffers are terminals too, but they get their own tabline
-- group: plain terminals and AI sessions never mix in one strip.
local function terminal_buffers()
    local buffers = {}

    for _, bufinfo in ipairs(terminal.buffer_info()) do
        if not is_ai_buffer(bufinfo.bufnr) then
            buffers[#buffers + 1] = bufinfo
        end
    end

    return buffers
end

local function ai_buffers()
    local buffers = {}

    for _, bufinfo in ipairs(terminal.buffer_info()) do
        if is_ai_buffer(bufinfo.bufnr) then
            buffers[#buffers + 1] = bufinfo
        end
    end

    return buffers
end

local function render_segment(text, hl_group)
    return string.format("%%#%s# %s %%*", hl_group, text)
end

local function regular_label(bufinfo)
    local label = vim.fs.basename(bufinfo.name)

    if bufinfo.changed == 1 then
        label = label .. " +"
    end

    return label
end

local function terminal_label(bufinfo)
    local label = terminal.label_for_buf(bufinfo.bufnr) or vim.fs.basename(vim.api.nvim_buf_get_name(bufinfo.bufnr))

    if bufinfo.changed == 1 then
        label = label .. " +"
    end

    return label
end

function M.setup_highlights()
    local normal = colors.get_hl("Normal")
    local tabline = colors.get_hl("TabLine")
    local tabline_sel = colors.get_hl("TabLineSel")
    local tabline_fill = colors.get_hl("TabLineFill")
    local inactive_bg = colors.lighten(tabline.bg or normal.bg, 0.08, tabline.fg or normal.fg)
    local active_bg = colors.lighten(tabline_sel.bg or inactive_bg, 0.18, tabline_sel.fg or normal.fg)
    local separator_bg = colors.lighten(tabline_fill.bg or tabline.bg or normal.bg, 0.05, tabline.fg or normal.fg)
    local inactive_fg = tabline.fg or normal.fg
    local active_fg = tabline_sel.fg or normal.fg

    set_hl("AitermTablineFileActive", {
        fg = active_fg,
        bg = active_bg,
        bold = true,
        italic = tabline_sel.italic,
    })
    set_hl("AitermTablineFileInactive", {
        fg = inactive_fg,
        bg = inactive_bg,
        bold = tabline.bold,
        italic = tabline.italic,
    })
    set_hl("AitermTablineTermActive", {
        fg = active_fg,
        bg = active_bg,
        bold = true,
        italic = tabline_sel.italic,
    })
    set_hl("AitermTablineTermInactive", {
        fg = inactive_fg,
        bg = inactive_bg,
        bold = tabline.bold,
        italic = tabline.italic,
    })
    set_hl("AitermTablineSeparator", {
        fg = tabline_fill.fg or inactive_fg,
        bg = separator_bg,
    })
end

function M.register_autocmds()
    if augroup then
        return
    end

    augroup = vim.api.nvim_create_augroup("AitermTablineHighlights", { clear = true })

    vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
        group = augroup,
        callback = function()
            M.setup_highlights()
            local ok, lualine = pcall(require, "lualine")
            if ok then
                lualine.refresh({
                    place = { "tabline", "statusline" },
                })
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        group = augroup,
        callback = function()
            remember_context_window(vim.api.nvim_get_current_win())
        end,
    })
end

function M.component()
    local current = context_bufnr()
    local current_is_term = vim.bo[current].buftype == "terminal"
    local current_is_ai = current_is_term and is_ai_buffer(current)
    local buffers
    if current_is_ai then
        buffers = ai_buffers()
    elseif current_is_term then
        buffers = terminal_buffers()
    else
        buffers = regular_buffers()
    end

    if #buffers == 0 then
        return ""
    end

    local items = {}

    for _, bufinfo in ipairs(buffers) do
        local is_active = bufinfo.bufnr == current
        local label = current_is_term and terminal_label(bufinfo) or regular_label(bufinfo)
        local hl_group

        if current_is_term then
            hl_group = is_active and "AitermTablineTermActive" or "AitermTablineTermInactive"
        else
            hl_group = is_active and "AitermTablineFileActive" or "AitermTablineFileInactive"
        end

        items[#items + 1] = render_segment(label, hl_group)
    end

    return table.concat(items, "%#AitermTablineSeparator#|%*")
end

return M
