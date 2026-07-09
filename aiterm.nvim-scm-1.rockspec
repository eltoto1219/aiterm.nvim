local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "aiterm.nvim"
version = MODREV .. SPECREV

description = {
    summary = "Terminal-first workflow suite for Neovim, built around AI coding agents.",
    detailed = [[
aiterm.nvim manages terminal buffers, AI harness sessions, persistent shpool-backed shells,
leased treehouse workspaces, run-current-file commands, and tabline integration as opt-in modules.
]],
    labels = { "neovim", "plugin", "ai", "terminal" },
    homepage = "https://github.com/eltoto1219/aiterm.nvim",
    license = "MIT",
}

dependencies = {
    "lua == 5.1",
}

source = {
    url = "git://github.com/eltoto1219/aiterm.nvim",
}

build = {
    type = "builtin",
    copy_directories = {
        "doc",
        "lua",
    },
}
