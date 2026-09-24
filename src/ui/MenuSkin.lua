-- An opt-in restyle of the START menu and the battle command menu: a drawn,
-- rounded two-tone frame with a soft drop shadow and a highlighted cursor
-- row (HGSS-like), and optionally Gen 5-style coloured command buttons in
-- battle.  Nothing is skinned unless a skin is chosen, so a vanilla boot
-- draws exactly the six-glyph Game Boy frame it always did.
--
-- Chosen by POKEPORT_MENU_SKIN (for trying it out without touching data)
-- or Theme.menuSkin (a mod sets it from field.theme or directly):
--   "hgss" -- rounded frame + row highlight on both menus
--   "gen5" -- the same frame, plus coloured FIGHT/PKMN/ITEM/RUN buttons

local Font = require("src.render.Font")
local Theme = require("src.ui.Theme")

local MenuSkin = {}

local ENV_SKIN = os.getenv("POKEPORT_MENU_SKIN")

local SKINS = { hgss = true, gen5 = true }

MenuSkin.PALETTE = {
  fill      = { 0.97, 0.97, 0.99, 1 },
  edge      = { 0.19, 0.25, 0.35, 1 },
  inner     = { 0.55, 0.72, 0.88, 1 },
  shadow    = { 0, 0, 0, 0.30 },
  highlight = { 0.80, 0.89, 0.98, 1 },
  buttons   = {
    FIGHT = { 0.91, 0.33, 0.30 },
    PKMN  = { 0.36, 0.72, 0.35 },
    ITEM  = { 0.95, 0.70, 0.22 },
    RUN   = { 0.30, 0.55, 0.90 },
  },
}

function MenuSkin.current()
  local s = (ENV_SKIN and ENV_SKIN ~= "" and ENV_SKIN) or Theme.menuSkin
  return SKINS[s] and s or nil
end

-- A pushed Font style (the battle's glass windows over a 3D backdrop) owns
-- the look of every box in its region, so the skin stands aside for it.
function MenuSkin.active()
  if Font.style() then return nil end
  return MenuSkin.current()
end

local function rect(c, x, y, w, h)
  if w <= 0 or h <= 0 then return end
  love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
  love.graphics.rectangle("fill", x, y, w, h)
end

-- Pixel-space rounded frame: 1px dark edge with its corner pixels pulled in,
-- a 1px light inner bevel, then the paper.
local function frame(x, y, w, h, P)
  rect(P.fill, x + 1, y + 1, w - 2, h - 2)
  rect(P.edge, x + 2, y, w - 4, 1)
  rect(P.edge, x + 2, y + h - 1, w - 4, 1)
  rect(P.edge, x, y + 2, 1, h - 4)
  rect(P.edge, x + w - 1, y + 2, 1, h - 4)
  rect(P.edge, x + 1, y + 1, 1, 1)
  rect(P.edge, x + w - 2, y + 1, 1, 1)
  rect(P.edge, x + 1, y + h - 2, 1, 1)
  rect(P.edge, x + w - 2, y + h - 2, 1, 1)
  rect(P.inner, x + 2, y + 1, w - 4, 1)
  rect(P.inner, x + 2, y + h - 2, w - 4, 1)
  rect(P.inner, x + 1, y + 2, 1, h - 4)
  rect(P.inner, x + w - 2, y + 2, 1, h - 4)
end

-- Drop-in for Font.drawBox(tx, ty, tw, th) in tile coordinates.
function MenuSkin.drawBox(tx, ty, tw, th)
  local P = MenuSkin.PALETTE
  local x, y, w, h = tx * 8, ty * 8, tw * 8, th * 8
  rect(P.shadow, x + 2, y + h, w - 2, 2)
  rect(P.shadow, x + w, y + 2, 2, h)
  frame(x, y, w, h, P)
  -- the palette remap would otherwise fold the frame into the map's four
  -- shades on the overworld; a no-op where no zone list is in force (battle)
  require("src.render.PaletteFX").markTrueColor(x, y, w + 2, h + 2)
  love.graphics.setColor(1, 1, 1, 1)
end

-- The band behind the row under the cursor.  x/y is the label's glyph origin.
function MenuSkin.highlightRow(x, y, w)
  rect(MenuSkin.PALETTE.highlight, x, y - 3, w, 14)
  love.graphics.setColor(0, 0, 0, 1)
end

function MenuSkin.textWidth(text)
  local w = 0
  for _, code in ipairs(Font.encode(text)) do w = w + Font.advanceOf(code) end
  return w
end

local function mix(c, t)
  return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t,
           c[3] + (1 - c[3]) * t, 1 }
end

-- A Gen 5-style command button around a label whose glyphs start at (x, y)
-- and run `w` pixels.  The selected one is stronger and outlined, which is
-- what marks the cursor in this skin.
function MenuSkin.button(key, x, y, w, selected)
  local base = MenuSkin.PALETTE.buttons[key] or MenuSkin.PALETTE.inner
  local bx, by, bw, bh = x - 3, y - 3, w + 6, 14
  if selected then
    frame(bx, by, bw, bh, { fill = mix(base, 0.35), edge = base,
                            inner = mix(base, 0.75) })
  else
    rect(mix(base, 0.72), bx + 1, by + 1, bw - 2, bh - 2)
  end
  love.graphics.setColor(0, 0, 0, 1)
end

return MenuSkin
