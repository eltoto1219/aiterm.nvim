# plugins workspace

Two public nvim plugins extracted from ~/.config/nvim (lua namespace `eltoto`), each its own git repo:

- `aiterm.nvim/` (github.com/eltoto1219/aiterm.nvim): terminal + AI sessions + shpool processes + treehouse + run + tabline. One plugin, opt-in modules. Options/mappings single source of truth: `lua/aiterm/config.lua`.

Conventions:

- Every keybind the plugins create must be configurable via opts and carry `desc=` (Antonio's requirement).
- No dangerous AI flags as defaults; they live in the consumer config's opts.
- Tests: `nvim --headless --clean -l tests/smoke.lua` per repo; CI = stylua --check + smoke. stylua is not installed locally; use `npx -y @johnnymorganz/stylua-bin .` before pushing.
- The config consumes aiterm via `dir = ~/projects/plugins/aiterm.nvim` (local dev); flip to `"eltoto1219/aiterm.nvim"` once stable. dictation already consumes from GitHub.
- Config-side keymaps stay in ~/.config/nvim/lua/eltoto/remap.lua (leader is `w`).
