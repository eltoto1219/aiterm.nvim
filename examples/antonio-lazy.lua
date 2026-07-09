-- Antonio's full lazy.nvim setup.
--
-- This enables the whole workflow surface: AI sessions, persistent shpool
-- processes, treehouse workspaces, run-current-file mappings, and the tabline.
return {
    {
        "eltoto1219/aiterm.nvim",
        -- For local development, replace the repo string above with:
        -- dir = vim.fs.normalize("~/projects/plugins/aiterm.nvim"),
        lazy = false,
        priority = 900,
        opts = {
            ai = {
                autostart = true,
                autostart_kind = "claude",
                kinds = {
                    claude = {
                        args = {
                            "--dangerously-skip-permissions",
                        },
                    },
                    codex = {
                        args = {
                            "--no-alt-screen",
                            "--search",
                            "--dangerously-bypass-approvals-and-sandbox",
                        },
                    },
                },
            },
            processes = {
                enabled = true,
                session_prefix = "proc-",
            },
            treehouse = {
                enabled = true,
            },
            mappings = {
                buffers = {
                    previous = "<leader>,",
                    next = "<leader>;",
                    alternate = "<leader>y",
                    quit = "qq",
                },
                terminal = {
                    toggle = "<leader>t",
                    new = "<leader>T",
                    previous = "<leader>,",
                    next = "<leader>;",
                },
                ai = {
                    toggle = "<leader>m",
                    pick = "<leader>nn",
                    kill = "<leader>nk",
                    kill_all = "<leader>nK",
                    new = "<leader>M",
                },
                processes = {
                    pick = "<leader>pp",
                    new = "<leader>pn",
                    attach_last = "<leader>pa",
                    attach_all = "<leader>pA",
                    kill = "<leader>pk",
                    kill_all = "<leader>pK",
                },
                treehouse = {
                    acquire = "<leader>fa",
                    lease = "<leader>fl",
                    status = "<leader>fs",
                    pick = "<leader>fw",
                    return_ws = "<leader>fr",
                },
                run = {
                    current_file = "<leader>e",
                },
            },
            tabline = {
                enabled = true,
            },
        },
    },
}
