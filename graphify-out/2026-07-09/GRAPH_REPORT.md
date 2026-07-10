# Graph Report - aiterm.nvim  (2026-07-09)

## Corpus Check
- 43 files · ~34,384 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 407 nodes · 855 edges · 22 communities (20 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c4bf91df`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Contributing
- CLAUDE.md
- TODO.md

## God Nodes (most connected - your core abstractions)
1. `aiterm.nvim` - 23 edges
2. `opts()` - 20 edges
3. `start_job()` - 16 edges
4. `notify()` - 15 edges
5. `M.setup()` - 14 edges
6. `M.root()` - 14 edges
7. `spawn()` - 12 edges
8. `M.quit_current_or_window()` - 12 edges
9. `M.setup()` - 12 edges
10. `M.prepare_workspace()` - 11 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (22 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.07
Nodes (52): ai_provider(), buffer_alive(), capture_codex_id_for_buffer(), capture_pending_codex_ids(), claim_codex_id(), claude_conversation_exists(), claude_conversation_path(), claude_projects_dir() (+44 more)

### Community 1 - "Community 1"
Cohesion: 0.08
Nodes (45): assign_automatic_label(), buffer_name_in_use(), close_tree_permanently(), cursor_is_live_input(), cycle(), enter_insert(), hide_tree_for_terminal(), listed_terminal_buffers() (+37 more)

### Community 2 - "Community 2"
Cohesion: 0.11
Nodes (53): append_ignore_rule(), automatic_build_allowed(), browser_argv(), check_guidance(), choose(), command_for(), ensure_cache_git_policy(), finish() (+45 more)

### Community 3 - "Community 3"
Cohesion: 0.16
Nodes (28): backend_available(), buffer_session(), default_branch_ref(), finish_acquisition(), git_status(), hash_untracked(), is_th_session(), local_default_branch() (+20 more)

### Community 4 - "Community 4"
Cohesion: 0.21
Nodes (24): close_tree_if_visible(), file_windows_in_tab(), is_named_edit_buf(), is_normal_window(), is_terminal_buf(), listed_buffers(), M.alternate(), M.backward() (+16 more)

### Community 5 - "Community 5"
Cohesion: 0.19
Nodes (21): attach(), cwd_map_path(), forget_session_cwd(), last_session_path(), load_cwd_map(), load_last_session_name(), M.attach_all_cwd(), M.attach_last() (+13 more)

### Community 6 - "Community 6"
Cohesion: 0.13
Nodes (20): ai_buffers(), context_bufnr(), is_ai_buffer(), is_normal_window(), listed_buffers(), M.component(), M.register_autocmds(), M.setup_highlights() (+12 more)

### Community 7 - "Community 7"
Cohesion: 0.27
Nodes (13): close_window(), current_filepath(), current_filetype(), current_runner_description(), display_mapping(), M.configure_popup(), M.exec_current_file(), render_command() (+5 more)

### Community 8 - "Community 8"
Cohesion: 0.35
Nodes (10): M.attach_command(), M.available(), M.command(), M.kill_session(), M.managed_sessions(), M.session_exists(), M.session_name(), M.system() (+2 more)

### Community 9 - "Community 9"
Cohesion: 0.27
Nodes (6): each_lhs(), M.setup(), set(), set_pair(), termcodes(), terminal_action()

### Community 10 - "Community 10"
Cohesion: 0.38
Nodes (8): assert_name(), assert_table(), bucket(), M.clear(), M.get(), M.list(), M.names(), M.register()

### Community 11 - "Community 11"
Cohesion: 0.05
Nodes (42): A note on permission-skipping flags, AI CLIs, aiterm.nvim, API highlights, API Stability, Can I disable modules?, Can I use another AI agent?, Can sessions persist outside Neovim? (+34 more)

### Community 12 - "Community 12"
Cohesion: 0.43
Nodes (4): item_label(), M.select(), normalize_items(), setup_highlights()

### Community 13 - "Community 13"
Cohesion: 0.83
Nodes (3): binary(), enabled(), M.check()

### Community 19 - "Contributing"
Cohesion: 0.18
Nodes (9): AI Providers, Code Guidelines, Configured AI Kinds, Contributing, Development Setup, Other Provider Types, Provider API, Pull Requests (+1 more)

## Knowledge Gaps
- **46 isolated node(s):** `plugins workspace`, `Development Setup`, `Validation`, `Code Guidelines`, `AI Providers` (+41 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `aiterm.nvim` connect `Community 11` to `Contributing`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `plugins workspace`, `Development Setup`, `Validation` to the rest of the system?**
  _46 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06971153846153846 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.08051948051948052 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.11380471380471381 - nodes in this community are weakly interconnected._
- **Should `Community 6` be split into smaller, more focused modules?**
  _Cohesion score 0.13105413105413105 - nodes in this community are weakly interconnected._
- **Should `Community 11` be split into smaller, more focused modules?**
  _Cohesion score 0.047619047619047616 - nodes in this community are weakly interconnected._