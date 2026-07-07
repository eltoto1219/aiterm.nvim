# aiterm.nvim

A terminal-first workflow suite for Neovim, built around AI coding agents.

- **Terminals**: toggle, cycle, rename, and label plain terminal buffers, with prompt-jump motions through AI transcripts.
- **AI sessions**: run claude/codex (or any harness) in terminal buffers with identity pinned at spawn.
  Sessions survive nvim exits and crashes and are restored on demand or automatically.
- **Persistent processes** (opt-in): named shell sessions backed by [shpool](https://github.com/shell-pool/shpool) that outlive nvim.
- **Treehouse workspaces** (opt-in): leased git worktrees via the [treehouse](https://github.com/kunchenguid/treehouse) CLI, each living in its own persistent session, with an agent offered on acquisition.
- **Run current file**: filetype-aware run command sent to your terminal, configurable per session.
- **Tabline** (opt-in): a lualine tabline component that shows file buffers, plain terminals, or AI sessions depending on where you are.
- **Buffers**: file-vs-terminal navigation and a quit key that does the right thing for windows, buffers, and terminals.

Everything is one plugin with opt-in modules; there are no inter-plugin dependencies.

## Requirements

- Neovim >= 0.10
- Optional integrations, used when present: nvim-tree, nui.nvim, lualine
- Per module: `claude`/`codex` on PATH for AI sessions, `shpool` for persistent processes, `treehouse` + `git` for workspaces

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "eltoto1219/aiterm.nvim",
  lazy = false,
  opts = {},
}
```

Run `:checkhealth aiterm` to verify binaries for the modules you enable.

## Configuration

All options with their defaults:

```lua
require("aiterm").setup({
  terminal = {
    -- Styling autocmds: no numbers/signcolumn in terminals, startinsert on
    -- enter, stopinsert on leave, pinned background.
    style = true,
    -- Background painted under terminal windows. Must match the color nvim
    -- reports to :terminal apps via OSC 11 (hardcoded black upstream); TUIs
    -- like codex derive highlights from it. 0x000000 | "#000000" | false.
    background = 0x000000,
    -- table | fun():table merged over the environment captured at nvim
    -- launch, applied to every terminal the plugin spawns.
    env = nil,
    mappings = {
      prompt_prev = "[a",       -- jump to previous prompt in a transcript
      prompt_next = "]a",       -- jump to next prompt / live input
      rename = "<leader>r",     -- rename terminal (buffer-local in terminals)
      insert_resume = true,     -- i/a/I/A resume terminal input
      persistent_esc = true,    -- <Esc> leaves input mode in persistent terminals
    },
  },
  buffers = { enabled = true }, -- last-edit-buffer tracking autocmds
  ai = {
    enabled = true,
    -- kind name -> { args = {...}, command = fun(entry, resume)? }
    -- args are appended to the built-in claude/codex launchers; command
    -- replaces the launcher entirely for custom harnesses.
    kinds = {
      claude = { args = {} },
      codex = { args = {} },
    },
    autostart = false,          -- spawn/restore a session on plain `nvim`
    restore = true,             -- load the on-disk session registry at startup
    commands = true,            -- :Claude / :Codex (one per kind) and the :AISession* family
    codex_sessions_dir = nil,   -- default: ~/.codex/sessions
  },
  processes = {
    enabled = false,            -- requires shpool
    shpool = nil,               -- name or absolute path override
    session_prefix = "aiterm-process-",
  },
  treehouse = {
    enabled = false,            -- requires the treehouse CLI and shpool
    mappings = false,           -- table to enable, see Keymaps below
  },
  run = {
    enabled = true,
    templates = {},             -- filetype -> template, merged over built-ins
    popup_mappings = { default = "d", custom = "c", close = "q" },
  },
  tabline = { enabled = false },
  ui = {
    picker = {
      mappings = { down = "j", up = "k", confirm = "<CR>", cancel = { "q", "<Esc>" } },
    },
  },
})
```

### A note on permission-skipping flags

The default launchers pass **no** permission-bypassing flags.
If you want fully autonomous agents, opt in explicitly and understand what you are enabling:

```lua
ai = {
  kinds = {
    claude = { args = { "--dangerously-skip-permissions" } },
    codex  = { args = { "--no-alt-screen", "--search",
                        "--dangerously-bypass-approvals-and-sandbox" } },
  },
},
```

These flags let the agent run commands and edit files without asking.
Use them only in workspaces you can afford to lose (this pairs well with the treehouse module).

## Keymaps

The plugin creates **no global keymaps** by default.
Every mapping it can create is listed here; each is configurable through the option shown and carries a `desc` visible in `:map` and which-key.

| Mapping | Option | Scope | Action |
|---|---|---|---|
| `[a` / `]a` | `terminal.mappings.prompt_prev/next` | terminal buffers | Jump between prompts in a transcript |
| `<leader>r` | `terminal.mappings.rename` | terminal buffers | Rename terminal |
| `i` `a` `I` `A` | `terminal.mappings.insert_resume` | terminal buffers | Resume terminal input from normal mode |
| `<Esc>` | `terminal.mappings.persistent_esc` | persistent terminals | Leave terminal input mode |
| `j`/`k`/`<CR>`/`q`/`<Esc>` | `ui.picker.mappings` | picker floats | Navigate / confirm / cancel |
| `d` / `c` / `q` | `run.popup_mappings` | run-config float | Default / custom / close |
| (disabled) | `treehouse.mappings.{acquire,lease,status,pick,return_ws}` | global | Treehouse actions |
| `r` / `q` | fixed, shown in the dialog | treehouse confirm float | Confirm / cancel workspace return |

Suggested global mappings for your config (public API is plain functions):

```lua
local terminal = require("aiterm.terminal")
local ai = require("aiterm.ai")
local buffers = require("aiterm.buffers")
local processes = require("aiterm.processes")

vim.keymap.set("n", "<leader>t", terminal.toggle, { desc = "Toggle terminal" })
vim.keymap.set("n", "<leader>T", terminal.open_new, { desc = "New terminal" })
vim.keymap.set("n", "<leader>m", ai.toggle, { desc = "Toggle AI session" })
vim.keymap.set("n", "<leader>M", ai.new_session, { desc = "New AI session" })
vim.keymap.set("n", "<leader>nn", ai.pick, { desc = "AI session picker" })
vim.keymap.set("n", "<leader>e", function() require("aiterm.run").exec_current_file() end, { desc = "Run current file" })
vim.keymap.set("n", "qq", buffers.quit_current_or_window, { desc = "Smart close" })
vim.keymap.set("n", "<leader>pp", processes.list, { desc = "Persistent terminals" })
```

## Commands

| Command | Module | Action |
|---|---|---|
| `:Claude`, `:Codex`, ... | ai | New session (one command per configured kind) |
| `:AISessions` | ai | Pick a live or cached session |
| `:AISessionNew` | ai | Pick a harness and spawn a fresh session |
| `:AISessionKill` / `:AISessionKillAll` | ai | Kill the current/picked session, or all of them |
| `:AISessionRestore` | ai | Restore cached sessions for the current directory |
| `:TerminalRename` | terminal | Rename the current terminal |
| `:TerminalRun` | run | Run the current file with its filetype runner |
| `:TerminalConfig` | run | Configure the run command for the current filetype |
| `:TerminalProcesses`, `:TerminalProcessNew`, `:TerminalProcessKill`, `:TerminalProcessKillAll`, `:TerminalProcessAttachLast`, `:TerminalProcessAttachAll` | processes | Persistent session management |
| `:TreehouseWorkspaces`, `:TreehouseAcquire`, `:TreehouseLease`, `:TreehouseStatus`, `:TreehouseReturn` | treehouse | Workspace management |

## Tabline / statusline integration

With lualine:

```lua
tabline = {
  lualine_a = { { require("aiterm.tabline").component } },
},
sections = {
  lualine_x = { require("aiterm.treehouse").statusline },
},
```

## API highlights

- `require("aiterm.terminal")`: `toggle`, `open_new`, `forward`, `backward`, `ensure`, `rename_current`
- `require("aiterm.ai")`: `toggle`, `new_session`, `pick`, `open(kind, cwd?)`, `restore_here`, `kill_current_or_select`, `kill_all`
- `require("aiterm.buffers")`: `forward`, `backward`, `alternate`, `quit_current_or_window`
- `require("aiterm.processes")`: `list`, `new`, `attach_last`, `attach_all_cwd`, `kill_current_or_select`, `kill_all`
- `require("aiterm.treehouse")`: `acquire_disposable`, `acquire_leased`, `status`, `pick`, `return_workspace`, `statusline`
- `require("aiterm.ui.picker").select(prompt, labels, on_choice, on_cancel?)`: dependency-free centered picker

See `:help aiterm` for the full reference.

## State

Session registries live in `stdpath("state")/aiterm/`.

## License

MIT
