-- Polished Crystal's battle rules (Rangi42/polishedcrystal), a Gen 2
-- romhack that ports Gen VI-era mechanics onto the Crystal cartridge.
--
-- Same shape as gen3_emerald.lua, and deliberately so: src/battle/Damage.lua
-- and src/battle/Status.lua are one formula parameterised by a ruleset
-- record, not a fourth set of formulas behind a generation test. Every field
-- below is a place where Polished genuinely differs from Gen 2, cited so a
-- future reader can check it against FEATURES.md (in the polishedcrystal
-- checkout) rather than trust it.
--
-- What is NOT here: abilities and natures are gated structurally (presence
-- of def.abilities / mon.nature once the extractor writes them), not by a
-- ruleset flag -- see Abilities.of and Stats.isGen3 for the pattern this
-- follows. Hold-item renumbering lives in HeldItems.lua's own
-- GameVersion.get() == "polishedcrystal" gate, because that is cartridge
-- data (a raw byte mapping), not a battle rule. Neither belongs here.

return {
  name = "gen6_polished",

  -- Critical hits do 150% damage, not 200% (FEATURES.md "Critical hits do
  -- 150% damage, not 200%, but are more likely"). Same finished-damage
  -- multiplier path Gen 3 uses (Damage.compute reads ruleset.critMultiplier
  -- after the formula, not a level-doubling trick).
  --
  -- NOT set here: critStages / CRIT_STAGE_DEN. Polished's own crit-chance
  -- ladder (CriticalHitChances, bank 13/$4000 per the manifest) has not been
  -- read off the ROM yet -- setting critMultiplier alone still disables
  -- Gen 2's speed-based ladder (see the `not ruleset.critMultiplier` gate in
  -- Damage.critRoll), which is correct: Polished's chances are NOT Gen 2's,
  -- they are just not verified to be Gen 3's shape either. Whoever reads
  -- CriticalHitChances for real should add critStages/CRIT_STAGE_DEN here
  -- once confirmed, not guess them now.
  critMultiplier = 1.5,

  -- Electric-type Pokemon are immune to paralysis outright (not just to
  -- Electric-type moves against Ground, which src/battle/Status.lua already
  -- handles unconditionally for every ruleset). Same for Ice/freeze and
  -- Fire/burn, but those two are already unconditional in Status.lua for
  -- every generation, so they need nothing here.
  paralysisImmuneTypes = { "ELECTRIC" },

  -- Steel-type Pokemon are immune to poisoning (FEATURES.md), same rule
  -- Emerald's Hoenn cartridge has for its own reason (STEEL was Gen 3+ era
  -- there too). Poison-type still poisons itself via Toxic per FEATURES.md
  -- ("Poison-type Pokémon always hit with Toxic") -- that is a Toxic-
  -- specific accuracy rule, not a poisonImmuneTypes exemption, and is not
  -- implemented here; do not conflate the two when someone picks it up.
  poisonImmuneTypes = { "POISON", "STEEL" },
}
