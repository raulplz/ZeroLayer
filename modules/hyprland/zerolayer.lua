-- ZerØLayer · Hyprland
-- Lo carga hypr/hyprland.lua. Para quitarlo: zerolayer uninstall hyprland

hl.config({
  general = { gaps_in = 5, gaps_out = 10, border_size = 2 },
  decoration = {
    rounding = 14,
    dim_inactive = true,
    dim_strength = 0.06,
    blur = { enabled = true, size = 4, passes = 2 },
  },
})

-- Cambio de escritorio corto y deslizante.
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide" })
