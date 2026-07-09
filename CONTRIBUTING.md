# Contributing

Thanks for taking the time to improve `aiterm.nvim`.
This project tries to keep the core small, dependency-light, and predictable inside normal Neovim workflows.

## Development Setup

Clone the repository and add it to your Neovim runtime path while developing.

```sh
git clone https://github.com/eltoto1219/aiterm.nvim
cd aiterm.nvim
```

For local manual testing, point your plugin manager at the checkout with `dir = "~/path/to/aiterm.nvim"`.
The example in [examples/antonio-lazy.lua](examples/antonio-lazy.lua) shows a complete local lazy.nvim setup.

The core test suite needs Neovim 0.10 or newer.
Optional modules need their external tools only when you are testing those modules manually.

- AI sessions need `claude` or `codex` on `PATH`.
- Persistent processes need `shpool` on `PATH`.
- Treehouse workflows need `treehouse`, `git`, and `shpool` on `PATH`.

## Validation

Run the same checks locally before opening a pull request.

```sh
make format-check
make lint
make test
```

`make format-check` uses Stylua through `npx`.
`make lint` expects `luacheck` to be available.
`make test` runs every Lua file in `tests/` with `nvim --headless --clean`.

When a change touches UI behavior, also test it manually in a real Neovim session.
Headless tests are useful, but they do not catch every focus, float, or terminal-mode edge case.

## Code Guidelines

Keep changes scoped to the behavior you are changing.
Prefer existing modules and patterns over new abstractions.
All plugin-created keymaps must be configurable through `opts.mappings` and must include a `desc`.
Do not add permission-skipping AI flags as defaults.
Those flags belong in user configuration.
Do not manually edit generated files or changelog output.

When adding tests, make them reproduce the user-facing behavior as closely as possible.
For picker, terminal, and buffer behavior, prefer driving Neovim state directly over only unit-testing helpers.

## Provider API

Providers let user config or companion plugins extend `aiterm.nvim` without patching the core modules.
Register providers with `require("aiterm").register_provider(type, name, spec, opts?)`.
You can register providers before or after `require("aiterm").setup({})`.

```lua
require("aiterm").register_provider("ai", "goose", {
  command = function(entry, resume)
    if resume and entry and entry.id then
      return { "goose", "resume", entry.id }
    end
    return { "goose", "session" }
  end,
  executable = "goose",
})
```

Provider names must be non-empty strings.
Provider specs must be tables.
Registering the same provider twice is an error unless you pass `{ replace = true }`.

```lua
require("aiterm").register_provider("ai", "goose", spec, { replace = true })
```

Use `require("aiterm").providers(type)` to get a copy of the registered providers for a type.
Use `require("aiterm.providers").names(type)` when you only need sorted names.

### AI Providers

AI providers are consumed by the built-in AI session module.
They appear in `:AISessionNew`, generated `:<Kind>` commands, autostart selection, health checks, and session spawning.

An AI provider spec supports these fields.

| Field | Required | Type | Description |
|---|---:|---|---|
| `command` | yes | `fun(entry, resume): string[]` | Returns the argv used to spawn or resume the terminal command. |
| `executable` | no | `string` | Binary checked by health checks and availability checks. |
| `prepare_workspace` | no | `fun(cwd: string)` | Runs before spawning the terminal for a workspace. |

The `entry` argument is the AI session registry entry.
It includes the session `kind`, current working directory `cwd`, generated session `id`, stable `key`, display `title`, and timestamps when available.
The `resume` argument is true when the provider should resume an existing session instead of starting a new one.

Return a list of argv parts instead of a shell string.
The terminal launcher handles shell escaping and execution.

```lua
require("aiterm").register_provider("ai", "myagent", {
  command = function(entry, resume)
    if resume then
      return { "myagent", "resume", entry.id }
    end
    return { "myagent", "start", "--cwd", entry.cwd }
  end,
  executable = "myagent",
  prepare_workspace = function(cwd)
    vim.fn.mkdir(vim.fs.joinpath(cwd, ".myagent"), "p")
  end,
})
```

Set `executable = nil` when the provider cannot be checked with `vim.fn.executable()`.
Health checks will report that the provider is configured without an executable check.

### Configured AI Kinds

Users can also add simple AI kinds through `opts.ai.kinds`.
Use this when the provider belongs to one local configuration instead of a reusable companion plugin.

```lua
require("aiterm").setup({
  ai = {
    kinds = {
      myagent = {
        executable = "myagent",
        command = function(entry, resume)
          return resume
              and { "myagent", "resume", entry.id }
              or { "myagent", "start" }
        end,
      },
    },
  },
})
```

Use `register_provider()` when you are writing a plugin, want to register before setup, or need explicit replacement behavior.
Use `opts.ai.kinds` when the extension is just local user configuration.

### Other Provider Types

The registry also validates `process`, `workspace`, and `picker_action` provider specs.
These are public extension points for companion integrations and future core consumers.

Process providers may expose `list()` and `attach()` functions.
Workspace providers may expose `pick()` and `statusline()` functions.
Picker action providers must expose `run(selection)`.

```lua
require("aiterm").register_provider("picker_action", "open-log", {
  run = function(selection)
    vim.cmd.edit(selection.path)
  end,
})
```

When adding a new core consumer for an existing provider type, update this file, the README provider reference, and `tests/providers.lua`.
When adding a new provider type, add a registry bucket, a validator, focused tests, and user-facing docs.

## Pull Requests

Describe the user-facing behavior you changed.
Include the commands you ran and any manual testing that matters.
If a check could not be run, say why.
Keep documentation changes in sync with behavior changes.
