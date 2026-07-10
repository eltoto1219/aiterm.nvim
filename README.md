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
- **Providers**: a small public registry for companion plugins or user config to add AI harnesses, process providers, workspace providers, and picker actions.

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

## Install Dependencies

The core plugin works with only Neovim.
Install the optional CLIs for the modules you plan to enable.

### Neovim

Use your system package manager or install from the official Neovim releases.

```sh
# macOS
brew install neovim

# Ubuntu or Debian
sudo apt install neovim

# Arch
sudo pacman -S neovim
```

### AI CLIs

Install at least one AI harness when `ai.enabled = true`.

```sh
# Codex CLI, macOS and Linux
curl -fsSL https://chatgpt.com/codex/install.sh | sh

# Claude Code, macOS, Linux, and WSL
curl -fsSL https://claude.ai/install.sh | bash
```

Alternative Claude Code installs:

```sh
# macOS Homebrew
brew install --cask claude-code

# Windows WinGet
winget install Anthropic.ClaudeCode

# npm
npm install -g @anthropic-ai/claude-code
```

After installation, authenticate each CLI from a normal terminal:

```sh
codex
claude
```

### Persistent Process CLI

Install `shpool` when `processes.enabled = true` or `treehouse.enabled = true`.

```sh
# Cargo
cargo install shpool

# macOS Homebrew
brew tap shell-pool/shpool
brew install shpool
```

On macOS, start the daemon at login if you use the Homebrew service:

```sh
brew services start shpool
```

### Treehouse CLI

Install `treehouse` when `treehouse.enabled = true`.

```sh
# macOS or Linux
curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh

# Go
go install github.com/kunchenguid/treehouse@latest

# Nix
nix run github:kunchenguid/treehouse
```

### Verify Tools

Run these checks after installing optional dependencies:

```sh
nvim --version
codex --version
claude --version
shpool --version
treehouse --version
```

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

## Quickstart Workflow

Start with a minimal setup:

```lua
require("aiterm").setup({})
```

Open Neovim in a project and run `:checkhealth aiterm`.
Fix any missing optional tool reported for the modules you want to use.

Create a new AI session:

```vim
:AISessionNew
```

Pick an existing or cached AI session for the current directory:

```vim
:AISessions
```

Run the current file in a terminal:

```vim
:TerminalRun
```

Add global mappings only after the workflow feels right:

```lua
require("aiterm").setup({
  mappings = {
    ai = {
      new = "<leader>M",
      pick = "<leader>nn",
    },
    terminal = {
      toggle = "<leader>t",
      new = "<leader>T",
    },
    run = {
      current_file = "<leader>e",
    },
  },
})
```

Enable persistent processes when you want named terminal sessions to survive Neovim exits:

```lua
require("aiterm").setup({
  processes = { enabled = true },
})
```

Enable treehouse when you want isolated worktrees backed by persistent sessions:

```lua
require("aiterm").setup({
  processes = { enabled = true },
  treehouse = { enabled = true },
})
```

Enable Graphify when you want AI sessions to work from a repository knowledge graph before searching raw files:

```sh
uv tool install graphifyy
graphify install
```

```lua
require("aiterm").setup({
  graphify = { enabled = true },
})
```

Graphify is optional and is not installed by `aiterm.nvim`.
This integration is currently tested with Graphify 0.9.11.
Review the [upstream installation instructions](https://github.com/safishamsi/graphify#install) when upgrading because Graphify's CLI and assistant-installation workflow can change independently of this plugin.
The first graph build creates a safe baseline `.graphifyignore` only when the repository does not already have one.
Existing `.graphifyignore` files are preserved during baseline initialization.

## Mental Model

`aiterm.nvim` is built around terminal buffers.
It does not provide a chat sidebar, inline completion engine, or LSP-style AI edit layer.

Plain terminals are normal `:terminal` buffers with plugin-managed naming, toggling, cycling, and prompt-jump mappings.
AI sessions are terminal buffers with a configured harness such as `claude`, `codex`, or a provider-defined command.
Persistent processes are named shell sessions managed by `shpool`, so the process can outlive Neovim.
Treehouse workspaces are isolated git worktrees managed by the `treehouse` CLI and paired with persistent sessions.
Graphify builds a queryable code graph for an opted-in Git repository and runs separately from the AI terminal.
Providers are extension points for adding AI harnesses and integration hooks without patching the plugin.

Session state is keyed by project directory.
Opening the picker from one repository shows sessions for that repository, including restorable cached AI sessions when restore is enabled.

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

Full workflow example:

See [`examples/antonio-lazy.lua`](examples/antonio-lazy.lua) for a complete lazy.nvim setup with AI sessions, persistent processes, treehouse workspaces, keymaps, and the tabline enabled.
That example opts into permission-bypassing AI harness flags, so review those arguments before copying it.

## Common Recipes

Codex only:

```lua
require("aiterm").setup({
  ai = {
    kinds = {
      codex = { args = {} },
    },
  },
})
```

Claude only:

```lua
require("aiterm").setup({
  ai = {
    kinds = {
      claude = { args = {} },
    },
  },
})
```

Disable all AI features:

```lua
require("aiterm").setup({
  ai = { enabled = false },
})
```

Add a custom local AI harness through config:

```lua
require("aiterm").setup({
  ai = {
    kinds = {
      myagent = {
        executable = "myagent",
        command = function(entry, resume)
          if resume and entry and entry.id then
            return { "myagent", "resume", entry.id }
          end
          return { "myagent", "start", "--cwd", entry.cwd }
        end,
      },
    },
  },
})
```

Enable an autonomous treehouse workflow explicitly:

```lua
require("aiterm").setup({
  processes = { enabled = true },
  treehouse = { enabled = true },
  ai = {
    kinds = {
      claude = { args = { "--dangerously-skip-permissions" } },
      codex = { args = { "--dangerously-bypass-approvals-and-sandbox" } },
    },
  },
})
```

Only use permission-bypassing flags in disposable or isolated workspaces.
Treehouse workspaces are a better fit for that style than your main checkout.

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
  graphify = {
    enabled = false,            -- requires the graphify CLI
    executable = "graphify",
    root = {
      markers = { ".git" },
      fallback = "cwd",        -- cwd | disabled
      nested_repositories = "nearest", -- nearest | outermost
    },
    lifecycle = "on_ai_start", -- manual | on_ai_start | on_workspace_enter
    check = {
      on_vim_enter = true,
      on_dir_changed = true,
      on_ai_start = true,
      on_treehouse_workspace = true,
      debounce_ms = 500,
    },
    missing_graph = "ask",     -- never | ask | build
    stale_graph = "ask",       -- never | ask | update
    stale_detection = "git",   -- git | timestamp | always
    allow_dirty_worktree = true,
    remember_skips = "session", -- never | session | repository
    safety = {
      require_git_repository = true,
      max_files_for_automatic_build = 5000,
      max_bytes_for_automatic_build = 100 * 1024 * 1024,
    },
    build = {
      code_only = true,
      extra_args = {},
      timeout_ms = 15 * 60 * 1000,
      output = "terminal",     -- terminal | scratch | silent
      terminal_label = "G: build",
    },
    update = {
      extra_args = {},
      timeout_ms = 15 * 60 * 1000,
      output = "terminal",     -- terminal | scratch | silent
      terminal_label = "G: update",
    },
    query = {
      output = "terminal",     -- terminal | scratch | silent
      timeout_ms = 60 * 1000,
      terminal_label = "G: query",
    },
    ignore_file = {
      enabled = true,
      path = ".graphifyignore",
      create_if_missing = true,
      profile = "safe",        -- minimal | safe
    },
    agents = {
      check_on_start = true,
      warn_when_missing = true,
      providers = { "codex", "claude" },
    },
    ui = {
      notifications = true,
      open_html = "browser",   -- browser | system | disabled | { "custom-opener", "--flag" }
      confirm = nil,            -- nil uses aiterm's built-in picker
    },
    callbacks = {
      on_status = nil,          -- fun(status, root)
      on_complete = nil,        -- fun(result, root)
      on_error = nil,           -- fun(result, root)
    },
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
    graphify = {
      status = false,
      build = false,
      update = false,
      query = false,
      open = false,
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

## Graphify Workflow

Graphify support is an opt-in codebase-graph workflow for AI sessions and Treehouse workspace agents.
`aiterm.nvim` resolves the repository root, checks for `graphify-out/graph.json`, and starts Graphify jobs asynchronously.
It does not block the AI session while a graph builds or updates.

With the default `check.on_vim_enter = true`, Neovim checks the graph at startup and AI sessions check it again when needed.
Set `lifecycle = "manual"` to disable automatic startup and AI-session checks.

```text
Open Neovim in a repository or start :Codex, :Claude, or a Treehouse workspace agent
  -> resolve the Git repository root
  -> inspect graph presence and Git freshness
  -> choose Run now, Skip, or Skip and don't ask again
  -> start or continue the AI session immediately
  -> show Graphify completion or failure in a terminal, scratch buffer, or notification
```

The default build runs `graphify extract <root> --code-only` followed by `graphify cluster-only <root> --no-label`.
This parses code locally and avoids semantic document extraction, API keys, and uploads by default.
The clustering step generates `GRAPH_REPORT.md` and `graph.html` without community-label LLM calls.
Set `graphify.build.code_only = false` only when you intentionally want Graphify to process supported non-code content.

The plugin creates this baseline `.graphifyignore` when the file is absent and `graphify.ignore_file.create_if_missing = true`:

```gitignore
# Environments, dependencies, and caches
.venv/
venv/
env/
__pycache__/
node_modules/

# Build and test output
dist/
build/
coverage/
target/

# Media and large data
*.png
*.mp4
*.mp3
*.parquet
*.sqlite
```

The real generated profile also ignores common image, video, audio, and scientific-data extensions.
It intentionally keeps Markdown, JSON, YAML, TOML, SVG, and generic `data/` directories because they can be valuable project context.

### Your Responsibilities

- Install Graphify yourself with `uv tool install graphifyy`.
- Run `graphify install` to register Graphify with the AI assistants detected by its installer.
- Keep the Graphify executable on the `PATH` inherited by Neovim.
- Review the generated `.graphifyignore` and add repository-specific exclusions.
- Decide whether `graphify-out/` should be committed for your team or ignored locally.
- Run `graphify codex install` and or `graphify claude install` inside a repository when you want those agents to prefer graph queries.
- Review Graphify-generated agent instruction changes before committing them.
- Treat graph results as navigation hints and read the relevant source before making edits.
- When upgrading beyond the documented tested version, rerun the verification sequence below because Graphify can change independently of this plugin.

Graphify also supports project-scoped and platform-specific assistant installation.
For example, use `graphify install --project --platform codex` when you want the Graphify skill stored inside the current repository instead of your user profile.
Review the files produced by any assistant installer before committing them.

`aiterm.nvim` never installs Graphify, installs Git hooks, rewrites `AGENTS.md`, or starts an HTTP server.
It changes `.gitignore` or an existing `.graphifyignore` only after you explicitly choose to ignore generated graph output.
MCP setup is intentionally outside this first integration release.
Graphify Git hooks are also user-owned and are never installed by this plugin.
If you choose to use `graphify hook install`, consult the upstream instructions and refresh the hook after reinstalling or upgrading Graphify.

Choosing `Skip and don't ask again` saves the choice in `stdpath("state")/aiterm/graphify.json` for the repository root.
Every subdirectory shares that saved choice because they share one graph.
The missing or stale graph confirmation appears at most once per repository during a Neovim session, regardless of the selected response.
Run `:AITermGraphifyResetPrompts` from the repository or any of its subdirectories to restore the prompt.

Choosing `Run now` for a missing graph opens a second prompt asking whether generated `graphify-out/` files should remain tracked by Git.
Choosing `Ignore graph output in Git` appends `graphify-out/` to `.gitignore` and `.graphifyignore` only when an equivalent rule is not already present.
Choosing `Keep graph output in Git` does not modify either file.

### Graphify Lifecycles

- `manual` disables automatic startup, directory, and AI-session checks.
- `on_ai_start` checks when an AI session starts and is the default lifecycle.
- `on_workspace_enter` checks on directory changes instead of normal AI-session starts.
- `check.on_vim_enter` controls the separate startup check and defaults to `true` for every non-manual lifecycle.
- `check.on_dir_changed` only applies to `on_workspace_enter`.
- `check.on_ai_start` only applies to `on_ai_start`.
- `check.on_treehouse_workspace` controls Treehouse agent checks within `on_ai_start`.

Repository roots are resolved from the current file, terminal, or working directory before a graph check runs.
Opening Neovim from a subdirectory uses the same graph as the repository root.
When repositories are nested, `root.nested_repositories = "nearest"` selects the closest repository and `"outermost"` selects the highest matching repository.

### Graphify Policies

| Option | Values | Behavior |
|---|---|---|
| `missing_graph` | `never`, `ask`, `build` | Ignore a missing graph, ask before building, or build automatically when safety limits allow it. |
| `stale_graph` | `never`, `ask`, `update` | Ignore a stale graph, ask before updating, or update automatically. |
| `stale_detection` | `git`, `timestamp`, `always` | Compare the recorded Git snapshot, compare the latest commit time with the graph file, or consider the graph stale on every check. |
| `remember_skips` | `never`, `session`, `repository` | Do not retain ordinary Skip choices, retain them for the Neovim session, or persist them in aiterm state. |
| `allow_dirty_worktree` | boolean | Permit or reject automatic builds and updates while tracked or untracked worktree changes are present. Manual commands remain available. |
| `build.output`, `update.output`, `query.output` | `terminal`, `scratch`, `silent` | Show the job in an aiterm terminal, collect results in a scratch buffer, or run without opening an output buffer. |

Automatic builds also respect `safety.max_files_for_automatic_build` and `safety.max_bytes_for_automatic_build`.
Manual `:AITermGraphifyBuild` and `:AITermGraphifyUpdate` commands are not blocked by those automatic-build limits.

### Graphify Commands

| Command | Action |
|---|---|
| `:AITermGraphifyStatus` | Show executable, graph, and freshness status for the current repository. |
| `:AITermGraphifyBuild` | Build a code-only graph and create a missing baseline `.graphifyignore`. |
| `:AITermGraphifyUpdate[!]` | Incrementally update the graph, or force an update with `!`. |
| `:AITermGraphifyQuery {question}` | Query the current repository graph. |
| `:AITermGraphifyExplain {node}` | Explain a graph node and its neighbors. |
| `:AITermGraphifyPath {source} {target}` | Find a shortest graph path between two node names. |
| `:AITermGraphifyOpen` | Open `graphify-out/graph.html` when Graphify generated it. |
| `:AITermGraphifyResetPrompts` | Clear saved choices and the current session prompt allowance for the repository. |

The default `ui.open_html = "browser"` uses a browser launcher available on the current platform and falls back to Neovim's native `vim.ui.open()` implementation.
Linux, macOS, and Windows are supported without requiring the same external command on every platform.
Set `ui.open_html = "system"` to always use the native system association, or provide an argv list such as `{ "firefox", "--new-window" }` to select a browser explicitly without shell parsing.

Recommended opt-in mappings:

```lua
mappings = {
  graphify = {
    status = "<leader>gs",
    build = "<leader>gb",
    update = "<leader>gu",
    query = "<leader>gq",
    open = "<leader>go",
  },
}
```

### Verify The Integration

Run this sequence from a Git repository after enabling Graphify:

```text
graphify --version
:checkhealth aiterm
:AITermGraphifyStatus
:AITermGraphifyBuild
:AITermGraphifyQuery describe the architecture
:AITermGraphifyOpen
```

The status command should report the repository root and either a missing, fresh, stale, or active build state.
The build should create `graphify-out/graph.json` and `graphify-out/graph.html`, the query should use that graph, and the open command should launch the HTML graph in a browser.

### Graphify Agent Guidance

The Graphify CLI owns agent-specific guidance.
Run one or both commands explicitly in each repository:

```sh
graphify codex install
graphify claude install
```

`aiterm.nvim` checks whether Graphify guidance appears in `AGENTS.md` or `CLAUDE.md` and warns once per repository when it is missing.
It does not install the guidance because those files are repository-owned instructions.
A global or skill-directory Graphify installation can still work even though the current repository-guidance check does not detect it yet.

Graphify controls its own query logging behavior independently of `aiterm.nvim`.
Current Graphify releases can write query metadata under the Graphify cache directory; consult the [upstream Graphify documentation](https://github.com/safishamsi/graphify) for `GRAPHIFY_QUERY_LOG` and `GRAPHIFY_QUERY_LOG_DISABLE` when repository or prompt privacy requires different handling.

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
| (disabled) | `mappings.terminal.{toggle,new,previous,next}` | global | Plain terminal actions; previous/next work in terminal and normal modes |
| (disabled) | `mappings.ai.{toggle,new,pick,kill,kill_all,restore}` | global | AI session actions |
| (disabled) | `mappings.processes.{pick,new,attach_last,attach_all,kill,kill_all}` | global | Persistent terminal actions |
| (disabled) | `mappings.treehouse.{acquire,lease,status,pick,return_ws}` | global | Treehouse actions |
| (disabled) | `mappings.graphify.{status,build,update,query,open}` | global | Graphify graph actions |
| (disabled) | `mappings.run.{current_file,configure}` | global | Run current file or configure its runner |
| `[a` / `]a` | `mappings.terminal.prompt_prev/next` | terminal buffers | Jump between prompts in a transcript |
| `<leader>r` | `mappings.terminal.rename` | terminal buffers | Rename terminal |
| `i` `a` `I` `A` | `mappings.terminal.insert_resume` | terminal buffers | Resume terminal input from normal mode, preserving the input cursor unless used on the live input row |
| `<Esc>` | `mappings.terminal.persistent_esc` | persistent terminals | Leave terminal input mode |
| `j`/`k`/`<CR>`/`q`/`<Esc>` | `mappings.picker` | picker floats | Type an option number and press `<CR>` to select it; in normal mode, cycle, confirm, or cancel; `<Esc>` in the prompt returns to options and `i` resumes input. |
| `d` / `c` / `q` | `mappings.run.popup` | run-config float | Default / custom / close |
| `r` / `q` | fixed, shown in the dialog | treehouse confirm float | Confirm / cancel workspace return |

Example global mappings:

```lua
mappings = {
  buffers = { previous = "<leader>,", next = "<leader>;", alternate = "<leader>y", quit = "qq" },
  terminal = { toggle = "<leader>t", new = "<leader>T", previous = "<leader>,", next = "<leader>;" },
  ai = { toggle = "<leader>m", new = "<leader>M", pick = "<leader>nn" },
  processes = { pick = "<leader>pp", new = "<leader>pn" },
  graphify = { status = "<leader>gs", build = "<leader>gb", query = "<leader>gq" },
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
| `:AITermGraphifyStatus`, `:AITermGraphifyBuild`, `:AITermGraphifyUpdate`, `:AITermGraphifyQuery`, `:AITermGraphifyExplain`, `:AITermGraphifyPath`, `:AITermGraphifyOpen` | graphify | Repository graph status, lifecycle, and queries |

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

## Provider API

Companion plugins and user config can register providers before or after `setup()`.
The initial public provider types are `ai`, `process`, `workspace`, and `picker_action`.
See [CONTRIBUTING.md](CONTRIBUTING.md#provider-api) for the longer guide to writing and validating providers.

AI providers participate in `:AISessionNew`, generated `:<Kind>` commands, autostart selection, health checks, and session spawning:

```lua
require("aiterm").register_provider("ai", "goose", {
  command = function(entry, resume)
    if resume and entry and entry.id then
      return { "goose", "resume", entry.id }
    end
    return { "goose", "session" }
  end,
  executable = "goose",
  prepare_workspace = function(cwd)
    -- Optional hook before spawning the terminal.
  end,
})
```

AI provider specs support:

| Field | Required | Description |
|---|---:|---|
| `command(entry, resume)` | yes | Returns the argv list used to spawn or resume the terminal command |
| `executable` | no | Binary checked by health and availability checks |
| `prepare_workspace(cwd)` | no | Runs before spawning the AI terminal in a workspace |

`command()` should return a list like `{ "goose", "session" }`, not a shell string.
The `entry` argument contains the AI session metadata, including `kind`, `cwd`, `id`, `key`, and display title fields when available.
The `resume` argument is true when aiterm is restoring or resuming an existing session.

Use `require("aiterm").providers("ai")` or `require("aiterm.providers").names("ai")` to inspect registered providers.
Pass `{ replace = true }` as the fourth argument when intentionally replacing an existing provider.

```lua
require("aiterm").register_provider("ai", "goose", spec, { replace = true })
```

`process`, `workspace`, and `picker_action` providers are validated registry extension points for integrations.
Process providers may define `list()` and `attach()`.
Workspace providers may define `pick()` and `statusline()`.
Picker action providers must define `run(selection)`.

### Provider Example

Use a provider when you want a companion plugin or reusable config to add an AI harness.

```lua
local aiterm = require("aiterm")

aiterm.register_provider("ai", "goose", {
  executable = "goose",
  command = function(entry, resume)
    if resume and entry and entry.id then
      return { "goose", "resume", entry.id }
    end
    return { "goose", "session", "--working-dir", entry.cwd }
  end,
  prepare_workspace = function(cwd)
    vim.fn.mkdir(vim.fs.joinpath(cwd, ".goose"), "p")
  end,
})
```

Use `opts.ai.kinds` instead when the harness belongs only to one local Neovim configuration.

## API highlights

- `require("aiterm.terminal")`: `toggle`, `open_new`, `forward`, `backward`, `ensure`, `rename_current`
- `require("aiterm.ai")`: `toggle`, `new_session`, `pick`, `open(kind, cwd?)`, `restore_here`, `kill_current_or_select`, `kill_all`
- `require("aiterm.buffers")`: `forward`, `backward`, `alternate`, `quit_current_or_window`
- `require("aiterm.processes")`: `list`, `new`, `attach_last`, `attach_all_cwd`, `kill_current_or_select`, `kill_all`
- `require("aiterm.treehouse")`: `acquire_disposable`, `acquire_leased`, `status`, `pick`, `return_workspace`, `statusline`
- `require("aiterm.graphify")`: `status`, `build`, `update`, `query`, `explain`, `path`, `open_html`
- `require("aiterm.ui.picker").select(prompt, labels, on_choice, on_cancel?)`: dependency-free searchable picker
- `require("aiterm").register_provider(type, name, spec, opts?)`: register an extension provider

See `:help aiterm` for the full reference.

## State

Session registries live in `stdpath("state")/aiterm/`.
AI session metadata is stored there so `:AISessions` and `:AISessionRestore` can find cached sessions for the current project.
Terminal buffers themselves are still Neovim terminal buffers, so a plain terminal process does not survive Neovim unless it is backed by `shpool`.
Persistent process sessions live in `shpool`, not in the aiterm state directory.
Treehouse worktrees live under the treehouse root configured by the `treehouse` CLI.
Graphify build snapshots live in `stdpath("state")/aiterm/graphify.json`.
Graphify graph output and `.graphifyignore` always live in the repository that owns the graph.

Deleting `stdpath("state")/aiterm/ai_sessions.json` forgets cached AI session metadata.
It does not delete external Codex, Claude, shpool, or treehouse state.

## Health And Troubleshooting

Run health checks first:

```vim
:checkhealth aiterm
```

If `:Claude`, `:Codex`, or `:AISessionNew` does not show the harness you expect, check that the CLI is on `PATH` and that `ai.enabled` is true.
Run `claude --version` or `codex --version` from the same shell environment that launches Neovim.

If sessions do not restore, check that `ai.restore = true` and that you are in the same project directory.
Session restore is scoped to the current working directory.

If persistent terminals do not start, check `shpool --version` and confirm `processes.enabled = true`.
On macOS with Homebrew, make sure the service is running if you expect the daemon to start at login.

If treehouse commands are unavailable, check `treehouse --version`, `git --version`, and `shpool --version`.
Treehouse support requires both the treehouse CLI and persistent process support.

If Graphify commands are unavailable, run `graphify --help` from the same shell that launches Neovim.
Install the official package with `uv tool install graphifyy`, then run `:checkhealth aiterm`.
If a graph is unexpectedly stale, run `:AITermGraphifyUpdate` or `:AITermGraphifyUpdate!` after a refactor that removed files.

If picker navigation feels wrong, remember that picker mappings are local to the picker floats.
Normal-mode `j` and `k` cycle options by default, and entering insert mode focuses the search prompt.

If a terminal UI looks visually wrong, check `terminal.background`.
Some terminal TUIs read the reported terminal background color and derive their highlights from it.

## Design Guarantees

- The plugin creates no global keymaps unless you configure them.
- Every plugin-created keymap is configurable and includes a `desc`.
- Core terminal, buffer, and run-current-file features do not require external binaries.
- Optional external CLIs are checked and reported, not installed automatically.
- Permission-skipping AI flags are never enabled by default.
- Provider registration is public API.
- Internal state files are implementation details unless documented here.

## API Stability

Public API:

- setup options documented in this README
- user commands documented in this README
- provider registration through `require("aiterm").register_provider()`
- provider inspection through `require("aiterm").providers()` and `require("aiterm.providers")`
- module functions listed under API highlights

Internal implementation details:

- exact JSON shape under `stdpath("state")/aiterm/`
- private helper functions inside `lua/aiterm/*`
- buffer variable names not documented as API
- highlight internals outside named public highlight groups

The provider registry is intended to stay stable.
If a provider type gains a new core consumer, the existing validator contract should continue to work.

## When To Use This

Use `aiterm.nvim` when you want terminal-native AI and process workflows inside Neovim.
It is a good fit if you already like terminal agents, project-local sessions, persistent shells, and worktree isolation.

Do not use it as a replacement for an AI chat sidebar, inline completion plugin, or code-action assistant.
Those tools solve a different workflow.

## FAQ

### Does this require Claude or Codex?

No.
Core terminal, buffer, and run-current-file features do not need AI CLIs.
AI sessions need at least one configured harness.

### Can I use another AI agent?

Yes.
Use `opts.ai.kinds` for local config or `register_provider("ai", name, spec)` for reusable provider integration.

### Why are there no default global keymaps?

Global mappings are personal and conflict-prone.
The plugin exposes every mapping through `opts.mappings` so users can choose their own layout.

### Can sessions persist outside Neovim?

AI session metadata can be restored after Neovim exits.
Plain terminal processes do not survive Neovim unless they are persistent `shpool` sessions.

### What does treehouse add?

Treehouse adds isolated reusable git worktrees.
That makes it easier to run autonomous or long-lived agent work without dirtying your main checkout.

### Can I disable modules?

Yes.
Set the module option to `enabled = false` where supported, such as `ai`, `processes`, `treehouse`, `run`, `buffers`, and `tabline`.

## Development

```sh
make format-check
make lint
make test
```

CI runs formatting, `luacheck`, and the full headless test suite on stable and nightly Neovim across Linux, macOS, and Windows.

## License

MIT
