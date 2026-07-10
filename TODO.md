# TODO

Adoption polish, roughly in impact order:

- [x] Document setup examples for other plugin managers beyond lazy.nvim.
- [ ] Record short demo GIFs for the README (terminal toggle, AI session restore after a restart, treehouse acquire + agent offer). Do the same for whisper-dictation.nvim.
- [ ] Record a Graphify demo GIF covering startup detection, graph creation, query, and browser opening.
- [ ] Rewrite the README intro around the user problem: persistent AI and terminal workflows inside Neovim.
- [ ] Add a minimal setup config block and a full Antonio workflow config block.
- [x] Document `:checkhealth aiterm` as the recommended first debugging path.
- [ ] Add tests for session registry migration and backward compatibility before changing registry shape again.
- [ ] Add `docs/workflows.md` with concrete workflows for AI session resume, persistent processes, treehouse workspace agents, and Graphify build/query usage.
- [x] Use user-facing release notes from now on with `Added`, `Changed`, and `Fixed` sections.
- [ ] Consider an `:AITermStatus` command summarizing enabled modules, binaries, cwd sessions, and last restore state.
- [ ] Add a real-CLI Graphify compatibility smoke test pinned to the documented supported version instead of relying only on the fake executable test.
- [ ] Run the real-CLI Graphify smoke test on Linux, macOS, and Windows so command and path behavior cannot drift by platform.
- [ ] Extend Graphify guidance detection to current project and global skill locations such as `.agents/skills/graphify/SKILL.md` and `.claude/skills/graphify/SKILL.md`.
- [ ] Improve `:checkhealth aiterm` with the Graphify version, resolved repository root, graph paths, selected HTML opener, and detected guidance location.
- [ ] Improve Git staleness detection for graphs created outside aiterm before a plugin-owned build snapshot exists.
- [ ] Treat an empty Git repository without a first commit as a repository rather than reporting it as unsupported.
- [ ] Document Graphify Git hooks as an optional user-owned alternative to lifecycle updates without installing or modifying hooks automatically.
- [ ] Design an opt-in Graphify MCP integration around `graphifyy[mcp]`, per-repository graph paths, server lifecycle ownership, and structured graph tools.
- [x] Add GitHub topics for aiterm.nvim discoverability: `neovim`, `neovim-plugin`, `ai`, `terminal`.
- [ ] Add GitHub topics for whisper-dictation.nvim discoverability: `neovim`, `neovim-plugin`, `whisper`, `dictation`.
- [x] Tag `v0.1.0` release on aiterm.nvim so users can pin versions.
- [x] Tag `v0.2.1` release on aiterm.nvim with green CI.
- [ ] Tag `v0.1.0` release on whisper-dictation.nvim so users can pin versions.
- [ ] Announce on r/neovim and This Week in Neovim once the demos are up.

Deliberately deferred until real contributors show up: CONTRIBUTING.md, issue templates, vimdoc generation tooling.
