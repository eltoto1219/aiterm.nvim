# TODO

Adoption polish, roughly in impact order:

- [x] Document setup examples for other plugin managers beyond lazy.nvim.
- [ ] Record short demo GIFs for the README (terminal toggle, AI session restore after a restart, treehouse acquire + agent offer). Do the same for whisper-dictation.nvim.
- [ ] Rewrite the README intro around the user problem: persistent AI and terminal workflows inside Neovim.
- [ ] Add a minimal setup config block and a full Antonio workflow config block.
- [ ] Document `:checkhealth aiterm` as the recommended first debugging path.
- [ ] Add tests for session registry migration and backward compatibility before changing registry shape again.
- [ ] Add `docs/workflows.md` with concrete workflows for AI session resume, persistent processes, and treehouse workspace agents.
- [ ] Use user-facing release notes from now on with `Added`, `Changed`, and `Fixed` sections.
- [ ] Consider an `:AitermStatus` command summarizing enabled modules, binaries, cwd sessions, and last restore state.
- [x] Add GitHub topics for aiterm.nvim discoverability: `neovim`, `neovim-plugin`, `ai`, `terminal`.
- [ ] Add GitHub topics for whisper-dictation.nvim discoverability: `neovim`, `neovim-plugin`, `whisper`, `dictation`.
- [x] Tag `v0.1.0` release on aiterm.nvim so users can pin versions.
- [x] Tag `v0.2.1` release on aiterm.nvim with green CI.
- [ ] Tag `v0.1.0` release on whisper-dictation.nvim so users can pin versions.
- [ ] Announce on r/neovim and This Week in Neovim once the demos are up.

Deliberately deferred until real contributors show up: CONTRIBUTING.md, issue templates, vimdoc generation tooling.
