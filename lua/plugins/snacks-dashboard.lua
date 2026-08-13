-- lua/plugins/snacks-dashboard.lua
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
          {
            pane = 2,
            section = "terminal",
            cmd = "echo '                       │ ╲ ││\\n            Powered by ││╲╲││.\\n                       ││ ╲ │\\n                       neovim\\n─────────────────────────────────────────────\\n        Help poor children in Uganda!\\n type  :help Kuwasha<Enter>  for information'",
            height = 7,
            padding = 4,
          },
        },
      },
    },
  },
}
