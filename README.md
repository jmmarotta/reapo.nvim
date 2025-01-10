# reapo.nvim

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
