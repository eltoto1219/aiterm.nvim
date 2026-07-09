local M = {}

local registry = {
    ai = {},
    process = {},
    workspace = {},
    picker_action = {},
}

local function assert_name(value, label)
    if type(value) ~= "string" or value == "" then
        error(label .. " must be a non-empty string", 3)
    end
end

local function assert_table(value, label)
    if type(value) ~= "table" then
        error(label .. " must be a table", 3)
    end
end

local function bucket(provider_type)
    assert_name(provider_type, "provider type")
    local providers = registry[provider_type]
    if not providers then
        error("unknown aiterm provider type: " .. provider_type, 3)
    end
    return providers
end

local validators = {}

validators.ai = function(name, spec)
    if type(spec.command) ~= "function" then
        error("AI provider '" .. name .. "' requires a command(entry, resume) function", 3)
    end
    if spec.executable ~= nil and type(spec.executable) ~= "string" then
        error("AI provider '" .. name .. "' executable must be a string", 3)
    end
    if spec.prepare_workspace ~= nil and type(spec.prepare_workspace) ~= "function" then
        error("AI provider '" .. name .. "' prepare_workspace must be a function", 3)
    end
end

validators.process = function(name, spec)
    if spec.list ~= nil and type(spec.list) ~= "function" then
        error("process provider '" .. name .. "' list must be a function", 3)
    end
    if spec.attach ~= nil and type(spec.attach) ~= "function" then
        error("process provider '" .. name .. "' attach must be a function", 3)
    end
end

validators.workspace = function(name, spec)
    if spec.pick ~= nil and type(spec.pick) ~= "function" then
        error("workspace provider '" .. name .. "' pick must be a function", 3)
    end
    if spec.statusline ~= nil and type(spec.statusline) ~= "function" then
        error("workspace provider '" .. name .. "' statusline must be a function", 3)
    end
end

validators.picker_action = function(name, spec)
    if type(spec.run) ~= "function" then
        error("picker action provider '" .. name .. "' requires a run(selection) function", 3)
    end
end

function M.register(provider_type, name, spec, opts)
    local providers = bucket(provider_type)
    assert_name(name, "provider name")
    assert_table(spec, "provider spec")

    opts = opts or {}
    if providers[name] and not opts.replace then
        error("aiterm provider already registered: " .. provider_type .. "." .. name, 2)
    end

    validators[provider_type](name, spec)
    providers[name] = spec
    return spec
end

function M.get(provider_type, name)
    return bucket(provider_type)[name]
end

function M.names(provider_type)
    local names = vim.tbl_keys(bucket(provider_type))
    table.sort(names)
    return names
end

function M.list(provider_type)
    local providers = bucket(provider_type)
    local copy = {}
    for name, spec in pairs(providers) do
        copy[name] = spec
    end
    return copy
end

function M.clear(provider_type, name)
    if name then
        bucket(provider_type)[name] = nil
        return
    end

    for key in pairs(bucket(provider_type)) do
        bucket(provider_type)[key] = nil
    end
end

return M
