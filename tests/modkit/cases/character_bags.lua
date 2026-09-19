-- Per-character backpack: pocket caps split by #characterBags, PROTAGONIST
-- keeps using save.inventory/save.bagOrder directly (no migration), and
-- every other id gets its own save.characterBags[id] storage lazily.
-- docs/superpowers/specs/2026-09-19-per-character-backpack-design.md
-- (pokemon-wish repo).

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Bag = require("src.inventory.Bag")

local ROSTER_MOD = {
  ["mods/fix_character_bags/manifest.json"] = [[{
    "id": "fix_character_bags",
    "name": "Fixture Character Bags",
    "version": "1.0.0",
    "entry": "main.lua",
    "api": 2
  }]],
  ["mods/fix_character_bags/main.lua"] = [[
    local mod = ...
    mod.content.constants:patch("characterBags", {
      { id = "PROTAGONIST" },
      { id = "LUNA", name = "Luna", color = { {1,1,1}, {2,2,2}, {3,3,3}, {0,0,0} } },
      { id = "NICO", name = "Nico" },
    })
  ]],
}

-- No-roster parity: every function still works exactly as before when no
-- mod declares characterBags -- this is the whole "vanilla stays vanilla"
-- guarantee the design leans on.
do
  local data = T.fixtures.fresh()
  local run = T.sdk.loadNone({ data = data })
  T.eq(#run.errors, 0, "the no-mod baseline loads cleanly")
  T.eq(Bag.pocketCapacity("ITEM", data), 20, "no roster: pocket cap unchanged")
  T.eq(Bag.characterInfo("LUNA", data), nil, "no roster: no character info")
  T.eq(Bag.presentCharacters({}, data), nil, "no roster: no present-characters list")

  local save = { inventory = {} }
  T.check(Bag.add(save, "FIX_POTION", 1, data), "add still works with no character arg")
  T.eq(save.inventory.FIX_POTION, 1, "and lands in save.inventory directly")
  run.release()
end

-- With a roster: pocket caps split, PROTAGONIST is save.inventory itself
-- (not a copy), other ids get their own lazily-created storage.
do
  local data = T.fixtures.fresh()
  local run = T.sdk.loadMods({ "mods/fix_character_bags" },
    { data = data, fs = T.sdk.memfs(ROSTER_MOD) })
  T.eq(#run.errors, 0, "the roster mod loads cleanly")
  T.eq(Bag.pocketCapacity("ITEM", data), 6, "20 / 3 characters, floored")
  T.eq(Bag.pocketCapacity("TM_HM", data), 6,
    "TM/HM splits off the shared 20, not its normal unlimited cap")

  local info = Bag.characterInfo("LUNA", data)
  T.eq(info.name, "Luna", "characterInfo finds the declared entry")
  T.same(info.color, { {1,1,1}, {2,2,2}, {3,3,3}, {0,0,0} }, "and its color")
  T.eq(Bag.characterInfo("GARY", data), nil, "an id outside the roster is nil")

  local present = Bag.presentCharacters({}, data)
  T.same(present, { "PROTAGONIST", "LUNA", "NICO" },
    "no save.presentCharacters override -> everyone in roster order")
  local narrowed = Bag.presentCharacters({ presentCharacters = { "LUNA" } }, data)
  T.same(narrowed, { "LUNA" }, "an explicit save field overrides the roster default")

  -- PROTAGONIST is save.inventory itself, not a separate copy.
  local save = { inventory = {}, activeCharacter = "PROTAGONIST" }
  T.check(Bag.add(save, "FIX_POTION", 1, data, "PROTAGONIST"), "protagonist add")
  T.eq(save.inventory.FIX_POTION, 1, "protagonist bag IS save.inventory")
  T.eq(save.characterBags, nil, "no characterBags table was created for protagonist")

  -- LUNA gets her own storage, lazily, without touching save.inventory.
  T.check(Bag.add(save, "FIX_BALL", 1, data, "LUNA"), "luna add")
  T.eq(save.characterBags.LUNA.inventory.FIX_BALL, 1, "luna's own inventory")
  T.eq(save.inventory.FIX_BALL, nil, "protagonist's inventory untouched by luna's add")

  -- The per-character cap is enforced independently per character.
  local six = { "FIX_A", "FIX_B", "FIX_C", "FIX_D", "FIX_E", "FIX_F" }
  for _, id in ipairs(six) do
    T.check(Bag.add(save, id, 1, data, "NICO"), "nico fills a slot: " .. id)
  end
  T.check(not Bag.add(save, "FIX_SEVENTH", 1, data, "NICO"),
    "nico's 7th distinct item is refused at the split cap")
  T.eq(Bag.pocketSlots(save, "ITEM", data, "NICO"), 6, "nico stays at 6 slots")
  T.eq(Bag.pocketSlots(save, "ITEM", data, "PROTAGONIST"), 1,
    "protagonist's own pocket count is unaffected by nico's cap")

  -- save.activeCharacter is the default when no character arg is passed.
  save.activeCharacter = "LUNA"
  T.check(Bag.add(save, "FIX_ETHER", 1, data), "add with no character arg")
  T.eq(save.characterBags.LUNA.inventory.FIX_ETHER, 1,
    "defaults to save.activeCharacter")

  -- Bag.order/remove/inventory all agree on the same per-character storage.
  local order = Bag.order(save, "NICO")
  T.eq(#order, 6, "nico's order list matches his 6 items")
  Bag.remove(save, "FIX_A", 1, "NICO")
  T.eq(Bag.inventory(save, "NICO", data).FIX_A, nil, "remove clears the slot")
  T.eq(#Bag.order(save, "NICO"), 5, "and drops it from the order list")

  run.release()
end

T.finish("character_bags")
