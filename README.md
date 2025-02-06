# reapo.nvim

## Goal

Create the best LLM propmpting experience in the terminal.

## Ackowledgements

These projects have been used as a reference and inspiration for this project:

- [avante.nvim](https://github.com/yetone/avante.nvim)
- [CodeCompanion](https://github.com/olimorris/codecompanion.nvim)
- [llama.vim](https://github.com/ggml-org/llama.vim)

Please be sure to give these projects a star!

## lazy.nvim

```lua
  {
    dir = "~/projects/reapo.nvim",
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("reapo").setup({
        model = "claude-3-5-sonnet-20241022",
        window_style = "float", -- or "split"
      })
    end,
  },
```
