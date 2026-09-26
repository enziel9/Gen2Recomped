-- Generation II held-item runtime regression tests.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local S = require("tests.harness").suite("gen2 held items")
local check, eq = S.check, S.eq
local HeldItems = require("src.battle.HeldItems")
local TurnOrder = require("src.battle.TurnOrder")
local Damage = require("src.battle.Damage")
local Encounter = require("src.world.Encounter")
local ruleset = require("src.battle.rulesets.gen1_faithful")

local function item(key, effect, param)
  return { key = key, heldEffect = effect or 0, heldParam = param or 0 }
end

local data = {
  constants = { generation = 2 },
  items = {
    QUICK_CLAW = item("QUICK_CLAW", 74, 60),
    BRIGHTPOWDER = item("BRIGHTPOWDER", 77, 20),
    SCOPE_LENS = item("SCOPE_LENS", 73, 0),
    STICK = item("STICK", 0, 0),
    LUCKY_PUNCH = item("LUCKY_PUNCH", 0, 0),
    THICK_CLUB = item("THICK_CLUB", 0, 0),
    LIGHT_BALL = item("LIGHT_BALL", 0, 0),
    METAL_POWDER = item("METAL_POWDER", 42, 10),
    MYSTIC_WATER = item("MYSTIC_WATER", 59, 10),
    DRAGON_SCALE = item("DRAGON_SCALE", 64, 10),
    DRAGON_FANG = item("DRAGON_FANG", 0, 0),
    FOCUS_BAND = item("FOCUS_BAND", 79, 30),
    KINGS_ROCK = item("KING_S_ROCK", 75, 30),
    LEFTOVERS = item("LEFTOVERS", 3, 10),
    BERRY = item("BERRY", 1, 10),
    GOLD_BERRY = item("GOLD_BERRY", 1, 30),
    BERRY_JUICE = item("BERRY_JUICE", 1, 20),
    PSNCUREBERRY = item("PSNCUREBERRY", 10, 0),
    BITTER_BERRY = item("BITTER_BERRY", 16, 0),
    MIRACLEBERRY = item("MIRACLEBERRY", 15, 0),
    MYSTERYBERRY = item("MYSTERYBERRY", 6, -1),
    LUCKY_EGG = item("LUCKY_EGG", 0, 0),
    AMULET_COIN = item("AMULET_COIN", 76, 10),
    SMOKE_BALL = item("SMOKE_BALL", 72, 0),
    CLEANSE_TAG = item("CLEANSE_TAG", 8, 0),
    BERSERK_GENE = item("BERSERK_GENE", 0, 0),
  },
  moves = { TACKLE = { pp = 35 }, SKETCH = { pp = 1 } },
}

local function mon(species, held, hp, maxhp)
  hp, maxhp = hp or 100, maxhp or 100
  return {
    species = species or "EEVEE", item = held, hp = hp,
    stats = { hp = maxhp }, moves = {}, status = nil,
  }
end

local function battler(species, held, speed, hp, maxhp)
  return {
    mon = mon(species, held, hp, maxhp), species = species,
    curStats = { attack = 100, defense = 100, speed = speed or 50,
                 special = 100, spatk = 100, spdef = 100 },
    curTypes = { "NORMAL" }, stages = { accuracy = 0, evasion = 0 },
    isPlayer = true, name = species or "MON",
  }
end

-- Quick Claw: priority still wins; equal priority checks serially and stops on
-- the first successful holder instead of rolling both.
do
  local a = battler("EEVEE", "QUICK_CLAW", 10)
  local b = battler("RATTATA", nil, 100)
  local calls = 0
  local rng = function() calls = calls + 1; return 0 end
  check(TurnOrder.firstMover(a, { priority = 0 }, b, { priority = 0 }, rng, nil, nil, data),
        "Quick Claw can move a slower holder first")
  eq(calls, 1, "Quick Claw consumes one roll when the first holder succeeds")
  calls = 0
  check(not TurnOrder.firstMover(a, { priority = 0 }, b, { priority = 1 }, rng, nil, nil, data),
        "Quick Claw never crosses move-priority classes")
  eq(calls, 0, "different move priority does not roll Quick Claw")

  local qa = battler("EEVEE", "QUICK_CLAW", 10)
  local qb = battler("RATTATA", "QUICK_CLAW", 100)
  calls = 0
  check(TurnOrder.firstMover(qa, {}, qb, {}, rng, nil, nil, data),
        "first checked Quick Claw holder wins immediately")
  eq(calls, 1, "two holders do not pre-roll both claws")
end

-- BrightPowder: a threshold can reach zero (no artificial 1/256 floor).
do
  local a, d = battler("EEVEE", nil), battler("RATTATA", "BRIGHTPOWDER")
  local hit = Damage.accuracyRoll(ruleset, { accuracy = 100 }, a, d,
    function() return 0 end, 10, data)
  check(not hit, "BrightPowder may reduce the hit threshold to zero")
end

-- Gen II critical ladder plus held stages.
do
  local a = battler("EEVEE", "SCOPE_LENS")
  local seenMax
  local rng = function(lo, hi) seenMax = hi; return 31 end
  check(Damage.critRoll(ruleset, a, "TACKLE", rng, false, data),
        "Scope Lens raises base crit stage to 32/256")
  eq(seenMax, 255, "Gen II crit uses a byte roll")

  a = battler("FARFETCHD", "STICK")
  check(Damage.critRoll(ruleset, a, "TACKLE", function() return 63 end, false, data),
        "Stick gives Farfetch'd two crit stages")
  a = battler("CHANSEY", "LUCKY_PUNCH")
  check(Damage.critRoll(ruleset, a, "TACKLE", function() return 63 end, false, data),
        "Lucky Punch gives Chansey two crit stages")
end

-- Species stat items and type boosters are data-driven.
do
  local a, d = battler("MAROWAK", "THICK_CLUB"), battler("DITTO", "METAL_POWDER")
  local atk, def = HeldItems.modifyBattleStats(data, a, d, "attack", "defense", 100, 100)
  eq(atk, 200, "Thick Club doubles Cubone/Marowak Attack")
  eq(def, 150, "Metal Powder raises untransformed Ditto Defense by 50 percent")

  a = battler("PIKACHU", "LIGHT_BALL")
  atk = HeldItems.modifyBattleStats(data, a, battler("EEVEE"), "spatk", "spdef", 100, 100)
  eq(atk, 200, "Light Ball doubles Pikachu Sp. Atk")

  a = battler("VAPOREON", "MYSTIC_WATER")
  eq(HeldItems.applyTypeBoost(data, a, "WATER", 101), 111,
     "type booster applies x1.10 with its own floor")
  -- The fixture deliberately keeps Crystal's raw ItemAttributes bug so this
  -- verifies the recomp-level correction rather than hiding it in test data.
  a.mon.item = "DRAGON_SCALE"
  eq(HeldItems.applyTypeBoost(data, a, "DRAGON", 101), 101,
     "Dragon Scale does not inherit Crystal's accidental Dragon boost")
  a.mon.item = "DRAGON_FANG"
  eq(HeldItems.applyTypeBoost(data, a, "DRAGON", 101), 111,
     "Dragon Fang is corrected to boost Dragon-type damage")
end

-- Focus Band is a direct-damage guard; King's Rock is one held-effect roll.
do
  local d = battler("EEVEE", "FOCUS_BAND", 50, 40, 100)
  eq(HeldItems.limitDirectDamage(data, d, 80, function() return 0 end), 39,
     "Focus Band leaves a surviving holder at 1 HP")
  eq(HeldItems.limitDirectDamage(data, d, 80, function() return 30 end), 80,
     "Focus Band fails at/above its 30/256 threshold")

  local u = battler("EEVEE", "KINGS_ROCK")
  local t = battler("RATTATA", nil)
  check(HeldItems.tryKingsRock(data, u, t, { effect = "NO_ADDITIONAL_EFFECT" },
                               function() return 0 end, false),
        "King's Rock can flinch on a NormalHit-script move")
  check(t.flinched == true, "King's Rock sets flinch volatile")
  t.flinched = nil
  check(not HeldItems.tryKingsRock(data, u, t, { effect = "POISON_SIDE_EFFECT1" },
                                   function() return 0 end, false),
        "King's Rock skips move scripts that do not contain kingsrock")
  check(HeldItems.tryKingsRock(data, u, t, { effect = "SNORE_EFFECT" },
                               function() return 0 end, false),
        "King's Rock still runs on Snore's native-flinch script")
  t.flinched = nil
  check(HeldItems.tryKingsRock(data, u, t, { id = "TRIPLE_KICK",
        effect = "NO_ADDITIONAL_EFFECT", multiHit = 3 },
        function() return 0 end, false),
        "King's Rock runs after Triple Kick")
  t.flinched = nil
  check(not HeldItems.tryKingsRock(data, u, t, { effect = "NO_ADDITIONAL_EFFECT" },
                                   function() return 0 end, true),
        "King's Rock does not pass a Substitute")
end

-- Status/confusion consumables.
do
  local b = battler("EEVEE", "PSNCUREBERRY")
  b.mon.status = "PSN"
  local msgs = HeldItems.onStatus({ data = data }, b)
  check(#msgs == 1 and b.mon.status == nil and b.mon.item == nil,
        "PSNCUREBERRY immediately cures poison and is consumed")

  b = battler("EEVEE", "BITTER_BERRY")
  b.confusedTurns = 4
  msgs = HeldItems.onConfusion({ data = data }, b)
  check(#msgs == 1 and b.confusedTurns == nil and b.mon.item == nil,
        "Bitter Berry immediately cures confusion")

  b = battler("EEVEE", "MIRACLEBERRY")
  b.mon.status = "BRN"
  b.confusedTurns = 3
  msgs = HeldItems.onStatus({ data = data }, b)
  check(#msgs == 1 and b.mon.status == nil and b.confusedTurns == nil,
        "MiracleBerry clears primary status and confusion together")
end

-- Weather/residual seam: an HP item can trigger after damage, but an already
-- fainted battler is never revived.  Healing queues the real HP-bar target.
do
  local queue = {}
  local battle = {
    data = data, result = nil,
    sayNext = function(_, text) queue[#queue + 1] = { text = text } end,
    drainNext = function(_, who, hp) queue[#queue + 1] = { who = who, hp = hp } end,
  }
  battle.player = battler("EEVEE", "BERRY", 50, 49, 100)
  battle.enemy = battler("RATTATA", nil, 50, 100, 100)
  HeldItems.endTurn(battle)
  eq(battle.player.mon.hp, 59, "Berry can trigger after residual damage crosses half HP")
  check(battle.player.mon.item == nil, "healing Berry is consumed")
  check(queue[#queue].hp == 59, "healing item queues HP-bar refresh to healed HP")

  battle.player = battler("EEVEE", "LEFTOVERS", 50, 0, 100)
  HeldItems.endTurn(battle)
  eq(battle.player.mon.hp, 0, "Leftovers never revives a residual KO")
end

-- Berserk Gene, Lucky Egg, Amulet Coin, Smoke Ball and Cleanse Tag.
do
  local rngCalls = 0
  local battle = {
    data = data,
    sayNext = function() end,
    rng = function(lo, hi)
      rngCalls = rngCalls + 1
      eq(lo, 2, "Berserk Gene confusion roll uses the normal Gen II lower bound")
      eq(hi, 5, "Berserk Gene confusion roll uses the normal Gen II upper bound")
      return 4
    end,
  }
  local b = battler("EEVEE", "BERSERK_GENE")
  check(HeldItems.onEntry(battle, b), "Berserk Gene activates on entry")
  eq(b.stages.attack, 2, "Berserk Gene raises Attack two stages")
  eq(b.confusedTurns, 4, "Berserk Gene initializes a normal confusion duration")
  eq(HeldItems.confusionCounter(battle, b), 4, "Berserk Gene stores the new side confusion counter")
  eq(rngCalls, 1, "Berserk Gene rolls confusion duration exactly once")
  check(b.mon.item == nil, "Berserk Gene is consumed")

  battle = {
    data = data,
    sayNext = function() end,
    heldConfusionCounters = { player = 3 },
    rng = function(lo, hi)
      eq(lo, 2, "corrected Berserk Gene reroll lower bound")
      eq(hi, 5, "corrected Berserk Gene reroll upper bound")
      return 5
    end,
  }
  b = battler("EEVEE", "BERSERK_GENE")
  HeldItems.onEntry(battle, b)
  eq(b.confusedTurns, 5, "Berserk Gene replaces a stale same-side confusion counter")
  eq(HeldItems.confusionCounter(battle, b), 5, "Berserk Gene stores the fresh confusion counter")

  local egg = mon("CHANSEY", "LUCKY_EGG")
  eq(HeldItems.modifyExperience(data, egg, 100), 150, "Lucky Egg gives x1.5 EXP")

  battle = { data = data }
  b = battler("MEOWTH", "AMULET_COIN")
  HeldItems.observeParticipant(battle, b)
  eq(HeldItems.modifyPrize(battle, 1000), 2000,
     "Amulet Coin doubles prize after its holder participates")

  b = battler("EEVEE", "SMOKE_BALL")
  check(HeldItems.canEscape(data, b), "Smoke Ball guarantees wild escape")

  local party = { mon("EEVEE", "CLEANSE_TAG"), mon("RATTATA") }
  eq(HeldItems.cleanseTagRate(data, party, 25), 12,
     "Cleanse Tag halves the encounter-rate byte with floor")
  party = { mon("EEVEE"), mon("RATTATA", "CLEANSE_TAG") }
  eq(HeldItems.cleanseTagRate(data, party, 25), 12,
     "Cleanse Tag works from any occupied party slot")
end

-- Encounter.roll applies an already-adjusted rate before the slot RNG.
do
  local calls = 0
  local enc = { grass = { rate = 25, buckets = { 256 }, slots = { { species = "RATTATA", level = 2 } } } }
  local got = Encounter.roll(enc, function() calls = calls + 1; return calls == 1 and 12 or 0 end, nil, 12)
  check(got == nil, "halved encounter rate rejects roll equal to threshold")
  eq(calls, 1, "failed rate check consumes no encounter-slot roll")
end

-- Polished Crystal's renumbered HELD_* bytes translate onto Crystal's.
do
  local GameVersion = require("src.core.GameVersion")
  local before = GameVersion.get()
  GameVersion.set("polishedcrystal")
  local pdata = { items = {
    LEFTOVERS = item("LEFTOVERS", 2, 10),
    LIFE_ORB = item("LIFE_ORB", 50, 0),
    PECHA_BERRY = item("PECHA_BERRY", 5, 8),
    LUM_BERRY = item("LUM_BERRY", 5, -1),
    PIXIE_PLATE = item("PIXIE_PLATE", 16, 17),
    DRAGON_FANG = item("DRAGON_FANG", 16, 15),
    QUICK_CLAW = item("QUICK_CLAW", 22, 20),
  } }
  local function holder(key) return { mon = { item = key } } end
  eq(HeldItems.effect(pdata, holder("LEFTOVERS")), HeldItems.EFFECT.LEFTOVERS,
     "Polished HELD_LEFTOVERS (2) is Leftovers")
  eq(HeldItems.effect(pdata, holder("LIFE_ORB")), HeldItems.EFFECT.LIFE_ORB,
     "Polished HELD_LIFE_ORB (50) is Life Orb, not Crystal's Normal boost")
  eq(HeldItems.effect(pdata, holder("PECHA_BERRY")), HeldItems.EFFECT.HEAL_POISON,
     "Polished status mask 1<<PSN heals poison")
  eq(HeldItems.effect(pdata, holder("LUM_BERRY")), HeldItems.EFFECT.HEAL_STATUS,
     "Polished ALL_STATUS heals everything")
  local e, p = HeldItems.effect(pdata, holder("DRAGON_FANG"))
  eq(e, HeldItems.EFFECT.DRAGON_BOOST, "Polished type boost reads the type param")
  eq(p, 20, "Polished type boost is x1.2")
  eq(HeldItems.applyTypeBoost(pdata, holder("PIXIE_PLATE"), "FAIRY", 100), 120,
     "Polished Fairy boost applies")
  e, p = HeldItems.effect(pdata, holder("QUICK_CLAW"))
  eq(p, 51, "Polished Quick Claw 20% rescaled to /256")
  GameVersion.set(before)
end

-- Polished-only hold items (Choice, Assault Vest, Eviolite, Life Orb, Focus
-- Sash, Rocky Helmet, Muscle Band / Wise Glasses).
do
  local GameVersion = require("src.core.GameVersion")
  local before = GameVersion.get()
  GameVersion.set("polishedcrystal")
  local pdata = {
    items = {
      CHOICE_BAND = { key = "CHOICE_BAND", name = "CHOICE BAND", heldEffect = 33, heldParam = 0 },
      CHOICE_SCARF = item("CHOICE_SCARF", 33, 2),
      CHOICE_SPECS = item("CHOICE_SPECS", 33, 3),
      ASSAULT_VEST = item("ASSAULT_VEST", 43, 0),
      EVIOLITE = item("EVIOLITE", 15, 50),
      LIFE_ORB = item("LIFE_ORB", 50, 0),
      FOCUS_SASH = item("FOCUS_SASH", 48, 0),
      ROCKY_HELMET = { key = "ROCKY_HELMET", name = "ROCKY HELMET", heldEffect = 54, heldParam = 0 },
      MUSCLE_BAND = item("MUSCLE_BAND", 17, 0),
      WISE_GLASSES = item("WISE_GLASSES", 17, 1),
      AIR_BALLOON = item("AIR_BALLOON", 42, 0),
    },
    pokemon = { PICHU = { evolutions = { { species = "PIKACHU" } } },
                RAICHU = { evolutions = {} } },
    moves = { TACKLE = { id = "TACKLE", name = "TACKLE", power = 40 },
              GROWL = { id = "GROWL", name = "GROWL", power = 0, category = "status" },
              EMBER = { id = "EMBER", name = "EMBER", power = 40, category = "special" } },
  }

  local atk, def = HeldItems.modifyBattleStats(pdata, battler("EEVEE", "CHOICE_BAND"),
                                              battler("EEVEE"), "attack", "defense", 100, 100)
  eq(atk, 150, "Choice Band x1.5 physical Attack")
  atk = HeldItems.modifyBattleStats(pdata, battler("EEVEE", "CHOICE_BAND"),
                                    battler("EEVEE"), "spatk", "spdef", 100, 100)
  eq(atk, 100, "Choice Band leaves Sp. Atk alone")
  atk = HeldItems.modifyBattleStats(pdata, battler("EEVEE", "CHOICE_SPECS"),
                                    battler("EEVEE"), "spatk", "spdef", 100, 100)
  eq(atk, 150, "Choice Specs x1.5 Sp. Atk")
  atk = HeldItems.modifyBattleStats(pdata, battler("EEVEE", "CHOICE_SCARF"),
                                    battler("EEVEE"), "attack", "defense", 100, 100)
  eq(atk, 100, "Choice Scarf does not boost Attack")
  _, def = HeldItems.modifyBattleStats(pdata, battler("EEVEE"), battler("EEVEE", "ASSAULT_VEST"),
                                       "spatk", "spdef", 100, 100)
  eq(def, 150, "Assault Vest x1.5 Sp. Def")
  _, def = HeldItems.modifyBattleStats(pdata, battler("EEVEE"), battler("EEVEE", "ASSAULT_VEST"),
                                       "attack", "defense", 100, 100)
  eq(def, 100, "Assault Vest leaves Defense alone")
  _, def = HeldItems.modifyBattleStats(pdata, battler("EEVEE"), battler("PICHU", "EVIOLITE"),
                                       "attack", "defense", 100, 100)
  eq(def, 150, "Eviolite x1.5 Defense on a species that can evolve")
  _, def = HeldItems.modifyBattleStats(pdata, battler("EEVEE"), battler("PICHU", "EVIOLITE"),
                                       "spatk", "spdef", 100, 100)
  eq(def, 150, "Eviolite x1.5 Sp. Def on a species that can evolve")
  _, def = HeldItems.modifyBattleStats(pdata, battler("EEVEE"), battler("RAICHU", "EVIOLITE"),
                                       "attack", "defense", 100, 100)
  eq(def, 100, "Eviolite does nothing on a fully evolved species")

  local scarf = battler("EEVEE", "CHOICE_SCARF", 100)
  scarf.mon.status = nil
  eq(TurnOrder.effectiveSpeed(scarf, { data = pdata }), 150, "Choice Scarf x1.5 Speed")
  eq(TurnOrder.effectiveSpeed(battler("EEVEE", "CHOICE_BAND", 100), { data = pdata }), 100,
     "Choice Band leaves Speed alone")

  eq(HeldItems.applyDamageBoost(pdata, battler("EEVEE", "LIFE_ORB"), false, 100), 130,
     "Life Orb x1.3 damage")
  eq(HeldItems.applyDamageBoost(pdata, battler("EEVEE", "MUSCLE_BAND"), false, 100), 110,
     "Muscle Band x1.1 physical damage")
  eq(HeldItems.applyDamageBoost(pdata, battler("EEVEE", "MUSCLE_BAND"), true, 100), 100,
     "Muscle Band ignores special moves")
  eq(HeldItems.applyDamageBoost(pdata, battler("EEVEE", "WISE_GLASSES"), true, 100), 110,
     "Wise Glasses x1.1 special damage")
  eq(HeldItems.effect(pdata, battler("EEVEE", "AIR_BALLOON")), HeldItems.EFFECT.NONE,
     "Air Balloon stays unimplemented (NONE)")

  -- Focus Sash: certain from full HP, consumed; nothing below full HP
  local sash = battler("EEVEE", "FOCUS_SASH", 50, 100, 100)
  local dmg, why = HeldItems.limitDirectDamage(pdata, sash, 250)
  eq(dmg, 99, "Focus Sash leaves a full-HP holder at 1 HP")
  eq(why, "FOCUS_SASH", "Focus Sash reports itself")
  eq(sash.mon.item, nil, "Focus Sash is consumed")
  sash = battler("EEVEE", "FOCUS_SASH", 50, 99, 100)
  eq(HeldItems.limitDirectDamage(pdata, sash, 250), 250, "Focus Sash fails below full HP")

  local function fakeBattle()
    local b = { data = pdata, said = {} }
    function b:sayNext(t) table.insert(self.said, t) end
    function b:drainNext() end
    return b
  end
  -- Life Orb recoil: 1/10 max HP
  local fb = fakeBattle()
  local orb = battler("EEVEE", "LIFE_ORB", 50, 100, 100)
  HeldItems.lifeOrbRecoil(fb, orb)
  eq(orb.mon.hp, 90, "Life Orb recoil costs 1/10 max HP")
  eq(#fb.said, 1, "Life Orb recoil prints one message")

  -- Rocky Helmet: 1/6 attacker max HP per contact hit; special moves without a
  -- contact flag are assumed non-contact, an explicit flag wins
  fb = fakeBattle()
  local attacker = battler("EEVEE", nil, 50, 120, 120)
  local helmet = battler("RHYHORN", "ROCKY_HELMET")
  HeldItems.rockyHelmet(fb, attacker, helmet, pdata.moves.TACKLE, 1)
  eq(attacker.mon.hp, 100, "Rocky Helmet deals 1/6 attacker max HP on contact")
  HeldItems.rockyHelmet(fb, attacker, helmet, pdata.moves.EMBER, 1)
  eq(attacker.mon.hp, 100, "Rocky Helmet ignores special moves without a contact flag")
  HeldItems.rockyHelmet(fb, attacker, helmet, { power = 40, makesContact = false }, 1)
  eq(attacker.mon.hp, 100, "Rocky Helmet honours makesContact = false")
  HeldItems.rockyHelmet(fb, attacker, helmet, pdata.moves.TACKLE, 2)
  eq(attacker.mon.hp, 60, "Rocky Helmet applies per landed hit")

  -- Choice lock and Assault Vest selection refusals
  local chooser = battler("EEVEE", "CHOICE_BAND")
  chooser.curMoves = { { id = "TACKLE", pp = 10 }, { id = "GROWL", pp = 10 } }
  eq(HeldItems.selectionBlock(pdata, chooser, pdata.moves.GROWL), nil,
     "Choice holder is free before its first move")
  chooser.lastMove = "TACKLE"
  check(HeldItems.selectionBlock(pdata, chooser, pdata.moves.GROWL) ~= nil,
        "Choice holder is locked out of other moves")
  eq(HeldItems.selectionBlock(pdata, chooser, pdata.moves.TACKLE), nil,
     "Choice holder may repeat its locked move")
  chooser.curMoves[1].pp = 0
  eq(HeldItems.selectionBlock(pdata, chooser, pdata.moves.GROWL), nil,
     "Choice lock releases once the locked move is out of PP")
  chooser.curMoves[1].pp = 10
  chooser.lastMove = "METRONOME_PICK"
  eq(HeldItems.selectionBlock(pdata, chooser, pdata.moves.GROWL), nil,
     "Choice lock on a move not in the moveset does not bind")
  local vest = battler("EEVEE", "ASSAULT_VEST")
  check(HeldItems.selectionBlock(pdata, vest, pdata.moves.GROWL) ~= nil,
        "Assault Vest refuses status moves")
  eq(HeldItems.selectionBlock(pdata, vest, pdata.moves.TACKLE), nil,
     "Assault Vest allows damaging moves")

  -- The AI obeys the same lock
  local TrainerAI = require("src.battle.TrainerAI")
  local ai = battler("EEVEE", "CHOICE_BAND")
  ai.isPlayer = false
  ai.curMoves = { { id = "TACKLE", pp = 10 }, { id = "GROWL", pp = 10 } }
  ai.lastMove = "TACKLE"
  local picked = TrainerAI.chooseMove(ai, function(lo) return lo end,
    { data = pdata, ruleset = {} })
  eq(picked and picked.id, "TACKLE", "AI Choice holder picks its locked move")
  GameVersion.set(before)
end

S.finish()
