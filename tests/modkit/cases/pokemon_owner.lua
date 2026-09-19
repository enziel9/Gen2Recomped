-- give_pokemon tags mon.owner when a character roster is declared, and
-- never touches it otherwise. docs/superpowers/specs/2026-09-19-per-
-- character-backpack-design.md (pokemon-wish repo), "Proprieta dei
-- Pokemon per personaggio".

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local ROSTER_MOD = {
  ["mods/fix_owner_roster/manifest.json"] = [[{
    "id": "fix_owner_roster",
    "name": "Fixture Owner Roster",
    "version": "1.0.0",
    "entry": "main.lua",
    "api": 2
  }]],
  ["mods/fix_owner_roster/main.lua"] = [[
    local mod = ...
    mod.content.constants:patch("characterBags", {
      { id = "PROTAGONIST" },
      { id = "LUNA", name = "Luna" },
    })
  ]],
}

-- No roster: mon.owner is never set, matching every save before this
-- feature existed.
do
  local data = T.fixtures.fresh()
  local run = T.sdk.loadNone({ data = data })
  T.eq(#run.errors, 0, "the no-mod baseline loads cleanly")
  local Commands = require("src.script.Commands")
  local save = { party = {}, pokedex = { seen = {}, owned = {} }, player = { name = "TEST" } }
  local ctx = { game = { data = data, stack = { push = function() end } }, save = save }
  Commands.give_pokemon(ctx, "FIXMON_A", 5, true)
  T.eq(save.party[1].owner, nil, "no roster -> no owner field at all")
  run.release()
end

-- With a roster: owner defaults to save.activeCharacter, and an explicit
-- opts.owner overrides it.
do
  local data = T.fixtures.fresh()
  local run = T.sdk.loadMods({ "mods/fix_owner_roster" },
    { data = data, fs = T.sdk.memfs(ROSTER_MOD) })
  T.eq(#run.errors, 0, "the roster mod loads cleanly")
  local Commands = require("src.script.Commands")

  local save = { party = {}, pokedex = { seen = {}, owned = {} }, player = { name = "TEST" } }
  local ctx = { game = { data = data, stack = { push = function() end } }, save = save }
  Commands.give_pokemon(ctx, "FIXMON_A", 5, true)
  T.eq(save.party[1].owner, "PROTAGONIST",
    "no activeCharacter set yet -> falls back to the roster's first id")

  save.activeCharacter = "LUNA"
  Commands.give_pokemon(ctx, "FIXMON_A", 5, true)
  T.eq(save.party[2].owner, "LUNA", "defaults to save.activeCharacter")

  Commands.give_pokemon(ctx, "FIXMON_A", 5, true, { owner = "PROTAGONIST" })
  T.eq(save.party[3].owner, "PROTAGONIST", "an explicit opts.owner overrides it")

  run.release()
end

T.finish("pokemon_owner")
