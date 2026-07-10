-- Run: nvim --headless --clean -l scripts/generate_changelog.lua v0.3.0 v0.2.1
local version = assert(arg[1], "release version is required")
local previous = assert(arg[2], "previous release tag is required")
local output = arg[3] or "CHANGELOG.md"

local function git(arguments)
    local command = { "git" }
    vim.list_extend(command, arguments)
    local result = vim.system(command, { text = true }):wait()
    assert(result.code == 0, vim.trim(result.stderr or "git command failed"))
    return vim.trim(result.stdout or "")
end

local remote = git({ "remote", "get-url", "origin" })
local repository = remote:gsub("%.git$", ""):gsub("^git@github%.com:", "https://github.com/")
assert(repository:match("^https://github%.com/"), "origin must be a GitHub repository")

local labels = {
    ai = "AI",
    ci = "CI",
    codex = "Codex",
    graphify = "Graphify",
    terminal = "Terminal",
}

local sections = {
    Added = {},
    Changed = {},
    Fixed = {},
}

local function capitalize(value)
    return value:sub(1, 1):upper() .. value:sub(2)
end

local function entry_for(hash, subject)
    local kind, scope, summary = subject:match("^([%w]+)%(([^)]+)%):%s*(.+)$")
    if not kind then
        kind, summary = subject:match("^([%w]+):%s*(.+)$")
    end

    local section = nil
    if kind == "feat" then
        section = "Added"
    elseif kind == "fix" then
        section = "Fixed"
    elseif kind == "docs" then
        section = "Changed"
    elseif not kind and subject:match("^[Aa]dded ") then
        section = "Changed"
        summary = subject
    elseif not kind and (subject:match("^[Uu]pdated ") or subject:match("^[Oo]verhauled ")) then
        section = "Changed"
        summary = subject
    end

    if not section then
        return
    end

    summary = capitalize(summary):gsub("[%.!]$", "")
    if scope then
        summary = (labels[scope] or capitalize(scope)) .. ": " .. summary
    end
    local short = hash:sub(1, 7)
    sections[section][#sections[section] + 1] = "- "
        .. summary
        .. ". ([`"
        .. short
        .. "`]("
        .. repository
        .. "/commit/"
        .. hash
        .. "))"
end

local range = previous .. "..HEAD"
local history = git({ "log", range, "--reverse", "--format=%H%x09%s" })
for line in history:gmatch("[^\n]+") do
    local hash, subject = line:match("^(%x+)%s+(.+)$")
    if hash and subject then
        entry_for(hash, subject)
    end
end

local lines = {
    "# Changelog",
    "",
    "All notable changes to this project are documented in this file.",
    "",
    "## ["
        .. version:gsub("^v", "")
        .. "]("
        .. repository
        .. "/compare/"
        .. previous
        .. "..."
        .. version
        .. ") - "
        .. os.date("%Y-%m-%d"),
}
local release_version = version:gsub("^v", "")

for _, section in ipairs({ "Added", "Changed", "Fixed" }) do
    if #sections[section] > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "### " .. section
        lines[#lines + 1] = ""
        vim.list_extend(lines, sections[section])
    end
end

if vim.fn.filereadable(output) == 1 then
    local prior = vim.fn.readfile(output)
    local first_release = nil
    for index, line in ipairs(prior) do
        if line:match("^## %[") then
            first_release = index
            break
        end
    end
    if first_release then
        if prior[first_release]:match("^## %[(.-)%]") == release_version then
            first_release = nil
            for index = 2, #prior do
                if prior[index]:match("^## %[") and prior[index]:match("^## %[(.-)%]") ~= release_version then
                    first_release = index
                    break
                end
            end
        end
    end
    if first_release then
        lines[#lines + 1] = ""
        for index = first_release, #prior do
            lines[#lines + 1] = prior[index]
        end
    end
end

vim.fn.writefile(lines, output)
print("generated " .. output .. " for " .. version .. " from " .. range)
