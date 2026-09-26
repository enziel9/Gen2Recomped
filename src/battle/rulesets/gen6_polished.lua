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
  -- after the formula, not a level-doubling trick). Confirmed in
  -- engine/battle/effect_commands.asm (damage mod "Critical hits": ln 3,2);
  -- the SNIPER ability raises it to 9/4 there, which is an ability, not a
  -- ruleset constant, and is not modelled here.
  critMultiplier = 1.5,

  -- "More likely" in numbers: CriticalHitChances (data/battle/
  -- critical_hit_chances.asm, ROM 0d:4000, bytes 01 03 0C 18 read off
  -- polishedcrystal-3.2.3.gbc) is a numerator over 24, rolled by
  -- BattleCommand_critical (0d:5d94) as BattleRandomRange(24) < n:
  -- stage 0 = 1/24, 1 = 1/8, 2 = 1/2, 3+ = always (the asm jumps straight to
  -- .guranteed_crit for c >= 3). That is the Gen 6 ladder, not Gen 3's
  -- 1/16..1/2, hence a per-ruleset table rather than Damage.lua's default.
  -- Stage sources match Damage.critRoll's critStages branch as-is: high-crit
  -- move +1 (CriticalHitMoves), Focus Energy +2, Scope Lens/Razor Claw +1,
  -- Lucky Punch/Leek on their species +2. Not modelled: SUPER_LUCK +1 and
  -- BATTLE_ARMOR/SHELL_ARMOR blocking (abilities), and affection level 3
  -- doubling the numerator (no affection system).
  critStages = true,
  critStageDen = { [0] = 24, 8, 2, 1 },

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
