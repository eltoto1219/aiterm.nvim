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

Everything is one plugin with opt-in modules.
The plugin does not install external binaries or optional UI plugins for you.

## Requirements

- Neovim >= 0.10
- Core terminal, buffers, and run-current-file features: no required external dependencies
- AI sessions: `claude` and/or `codex` on PATH, depending on the configured kinds
- Persistent processes: `shpool` on PATH, or `opts.processes.shpool` pointing at the binary
- Treehouse workspaces: `treehouse`, `git`, and `shpool` on PATH
- Optional UI integrations, used when present: `nvim-tree`, `nui.nvim`, `lualine`

`aiterm.nvim` follows the usual Neovim plugin convention: it documents and checks external tools, but does not auto-install them.
Run `:checkhealth aiterm` after setup to verify the modules you enable.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "eltoto1219/aiterm.nvim",
  lazy = false,
  opts = {},
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "eltoto1219/aiterm.nvim",
  config = function()
    require("aiterm").setup({})
  end,
})
```

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'eltoto1219/aiterm.nvim'
```

```lua
require("aiterm").setup({})
```

With native packages:

```sh
git clone https://github.com/eltoto1219/aiterm.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/aiterm.nvim
```

```lua
require("aiterm").setup({})
```

## Module Recipes

Default setup:

```lua
require("aiterm").setup({})
```

Core-only setup with no AI binaries required:

```lua
require("aiterm").setup({
  ai = { enabled = false },
})
```

AI sessions only:

```lua
require("aiterm").setup({
  ai = {
    enabled = true,
    kinds = {
      claude = { args = {} },
      codex = { args = {} },
    },
  },
})
```

Persistent terminals:

```lua
require("aiterm").setup({
  processes = { enabled = true },
})
```

Treehouse workspaces:

```lua
require("aiterm").setup({
  processes = { enabled = true },
  treehouse = { enabled = true },
})
```

Tabline component:

```lua
require("aiterm").setup({
  tabline = { enabled = true },
})
```

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
    autostart_kind = nil,       -- nil picks first executable kind; e.g. "codex"
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
  },
  run = {
    enabled = true,
    templates = {},             -- filetype -> template, merged over built-ins
  },
  tabline = { enabled = false },
  mappings = {
    buffers = {
      previous = false,
      next = false,
      alternate = false,
      quit = false,
    },
    terminal = {
      toggle = false,
      new = false,
      previous = false,
      next = false,
      prompt_prev = "[a",
      prompt_next = "]a",
      rename = "<leader>r",
      insert_resume = { "i", "a", "I", "A" },
      persistent_esc = "<Esc>",
    },
    ai = {
      toggle = false,
      new = false,
      pick = false,
      kill = false,
      kill_all = false,
      restore = false,
    },
    processes = {
      pick = false,
      new = false,
      attach_last = false,
      attach_all = false,
      kill = false,
      kill_all = false,
    },
    treehouse = {
      acquire = false,
      lease = false,
      status = false,
      pick = false,
      return_ws = false,
    },
    run = {
      current_file = false,
      configure = false,
      popup = { default = "d", custom = "c", close = "q" },
    },
    picker = {
      down = "j",
      up = "k",
      confirm = "<CR>",
      cancel = { "q", "<Esc>" },
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
| (disabled) | `mappings.buffers.{previous,next,alternate,quit}` | global | File-buffer navigation and smart close |
| (disabled) | `mappings.terminal.{toggle,new,previous,next}` | global | Plain terminal actions |
| (disabled) | `mappings.ai.{toggle,new,pick,kill,kill_all,restore}` | global | AI session actions |
| (disabled) | `mappings.processes.{pick,new,attach_last,attach_all,kill,kill_all}` | global | Persistent terminal actions |
| (disabled) | `mappings.treehouse.{acquire,lease,status,pick,return_ws}` | global | Treehouse actions |
| (disabled) | `mappings.run.{current_file,configure}` | global | Run current file or configure its runner |
| `[a` / `]a` | `mappings.terminal.prompt_prev/next` | terminal buffers | Jump between prompts in a transcript |
| `<leader>r` | `mappings.terminal.rename` | terminal buffers | Rename terminal |
| `i` `a` `I` `A` | `mappings.terminal.insert_resume` | terminal buffers | Resume terminal input from normal mode, preserving the input cursor unless used on the live input row |
| `<Esc>` | `mappings.terminal.persistent_esc` | persistent terminals | Leave terminal input mode |
| `j`/`k`/`<CR>`/`q`/`<Esc>` | `mappings.picker` | picker floats | Navigate / confirm / cancel |
| `d` / `c` / `q` | `mappings.run.popup` | run-config float | Default / custom / close |
| `r` / `q` | fixed, shown in the dialog | treehouse confirm float | Confirm / cancel workspace return |

Example global mappings:

```lua
mappings = {
  buffers = { previous = "<leader>,", next = "<leader>;", alternate = "<leader>y", quit = "qq" },
  terminal = { toggle = "<leader>t", new = "<leader>T", previous = "<leader>,", next = "<leader>;" },
  ai = { toggle = "<leader>m", new = "<leader>M", pick = "<leader>nn" },
  processes = { pick = "<leader>pp", new = "<leader>pn" },
  run = { current_file = "<leader>e" },
}
```

## Commands

| Command | Module | Action |
|---|---|---|
| `:Claude`, `:Codex`, ... | ai | New session (one command per configured kind) |
| `:AISessions` | ai | Pick a harness-prefixed live or cached session for the current directory |
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
