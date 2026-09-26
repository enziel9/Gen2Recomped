-- Generation II held-item mechanics shared by battle and field seams.
--
-- The Gen2 ROM extractor stamps ItemAttributes' held-effect byte and signed
-- parameter onto each item record.  Most mechanics can therefore follow the
-- cartridge's data rather than maintain a second item-name table.  The few
-- species-specific items whose ItemAttributes effect is HELD_NONE (Thick Club,
-- Light Ball, Lucky Punch, Lucky Egg and Berserk Gene) are identified by key.

local ItemEffects = require("src.inventory.ItemEffects")
local Strings = require("src.core.Strings")
local GameVersion = require("src.core.GameVersion")

local HeldItems = {}

HeldItems.EFFECT = {
  NONE = 0,
  BERRY = 1,
  LEFTOVERS = 3,
  RESTORE_PP = 6,
  CLEANSE_TAG = 8,
  HEAL_POISON = 10,
  HEAL_FREEZE = 11,
  HEAL_BURN = 12,
  HEAL_SLEEP = 13,
  HEAL_PARALYZE = 14,
  HEAL_STATUS = 15,
  HEAL_CONFUSION = 16,
  METAL_POWDER = 42,
  NORMAL_BOOST = 50,
  FIGHTING_BOOST = 51,
  FLYING_BOOST = 52,
  POISON_BOOST = 53,
  GROUND_BOOST = 54,
  ROCK_BOOST = 55,
  BUG_BOOST = 56,
  GHOST_BOOST = 57,
  FIRE_BOOST = 58,
  WATER_BOOST = 59,
  GRASS_BOOST = 60,
  ELECTRIC_BOOST = 61,
  PSYCHIC_BOOST = 62,
  ICE_BOOST = 63,
  DRAGON_BOOST = 64,
  DARK_BOOST = 65,
  STEEL_BOOST = 66,
  -- not a Crystal constant (Crystal has no Fairy); only reached by
  -- translating Polished Crystal's HELD_TYPE_BOOST, FAIRY
  FAIRY_BOOST = 67,
  ESCAPE = 72,
  CRITICAL_UP = 73,
  QUICK_CLAW = 74,
  FLINCH = 75,
  AMULET_COIN = 76,
  BRIGHTPOWDER = 77,
  FOCUS_BAND = 79,
  -- Not Crystal constants: Polished-only effects, reached only through
  -- translatePolished.  Numbered well clear of Crystal's HELD_* range.
  EVIOLITE = 200,
  CATEGORY_BOOST = 201,
  CHOICE = 202,
  ASSAULT_VEST = 203,
  FOCUS_SASH = 204,
  LIFE_ORB = 205,
  ROCKY_HELMET = 206,
}

-- HELD_CHOICE's param is the boosted stat (constants/battle_constants.asm);
-- HELD_CATEGORY_BOOST's is the move category (type_constants.asm).
HeldItems.CHOICE_STAT = { ATTACK = 0, SPEED = 2, SP_ATTACK = 3 }
HeldItems.CATEGORY = { PHYSICAL = 0, SPECIAL = 1 }

local TYPE_BY_EFFECT = {
  [50] = "NORMAL", [51] = "FIGHTING", [52] = "FLYING",
  [53] = "POISON", [54] = "GROUND", [55] = "ROCK", [56] = "BUG",
  [57] = "GHOST", [58] = "FIRE", [59] = "WATER", [60] = "GRASS",
  [61] = "ELECTRIC", [62] = "PSYCHIC", [63] = "ICE", [64] = "DRAGON",
  [65] = "DARK", [66] = "STEEL", [67] = "FAIRY",
}

-- Polished Crystal renumbered constants/item_data_constants.asm (HELD_LEFTOVERS
-- is 2 there, 3 in Crystal; HELD_LIFE_ORB 50 lands on Crystal's
-- HELD_NORMAL_BOOST) and changed what several params mean, so its raw
-- ItemAttributes bytes are translated onto the Crystal numbering the rest of
-- this file speaks.  Polished-only effects implemented here (Eviolite,
-- Muscle Band/Wise Glasses, Choice, Assault Vest, Focus Sash, Life Orb, Rocky
-- Helmet) get their own EFFECT ids above.  Everything else stays unmapped and
-- does nothing rather than the wrong thing; notably the pinch berries
-- (HELD_RAISE_STAT/RAISE_CRIT fire at 1/4 HP after ANY damage, which needs a
-- hook on every HP loss, not just the direct-hit seam), Weakness Policy and
-- Air Balloon (need hit-effectiveness and Ground-immunity hooks that do not
-- exist yet) and the EV items (Power*/Macho Brace touch stat-exp gain, not
-- battle).
local POLISHED = {
  BERRY = 1, LEFTOVERS = 2, RESTORE_PP = 3, CLEANSE_TAG = 4,
  HEAL_STATUS = 5, HEAL_CONFUSE = 6, METAL_POWDER = 13, EVIOLITE = 15,
  TYPE_BOOST = 16, CATEGORY_BOOST = 17,
  ESCAPE = 19, CRITICAL_UP = 20, FLINCH_UP = 21, QUICK_CLAW = 22,
  AMULET_COIN = 23, BRIGHTPOWDER = 24, FOCUS_BAND = 25,
  CHOICE = 33, ASSAULT_VEST = 43, FOCUS_SASH = 48, LIFE_ORB = 50,
  ROCKY_HELMET = 54,
}

local POLISHED_DIRECT = {
  [POLISHED.BERRY] = HeldItems.EFFECT.BERRY,
  [POLISHED.LEFTOVERS] = HeldItems.EFFECT.LEFTOVERS,
  [POLISHED.RESTORE_PP] = HeldItems.EFFECT.RESTORE_PP,
  [POLISHED.CLEANSE_TAG] = HeldItems.EFFECT.CLEANSE_TAG,
  [POLISHED.HEAL_CONFUSE] = HeldItems.EFFECT.HEAL_CONFUSION,
  [POLISHED.METAL_POWDER] = HeldItems.EFFECT.METAL_POWDER,
  [POLISHED.ESCAPE] = HeldItems.EFFECT.ESCAPE,
  [POLISHED.CRITICAL_UP] = HeldItems.EFFECT.CRITICAL_UP,
  [POLISHED.AMULET_COIN] = HeldItems.EFFECT.AMULET_COIN,
  [POLISHED.FOCUS_BAND] = HeldItems.EFFECT.FOCUS_BAND,
  [POLISHED.EVIOLITE] = HeldItems.EFFECT.EVIOLITE,
  [POLISHED.CATEGORY_BOOST] = HeldItems.EFFECT.CATEGORY_BOOST,
  [POLISHED.CHOICE] = HeldItems.EFFECT.CHOICE,
  [POLISHED.ASSAULT_VEST] = HeldItems.EFFECT.ASSAULT_VEST,
  [POLISHED.FOCUS_SASH] = HeldItems.EFFECT.FOCUS_SASH,
  [POLISHED.LIFE_ORB] = HeldItems.EFFECT.LIFE_ORB,
  [POLISHED.ROCKY_HELMET] = HeldItems.EFFECT.ROCKY_HELMET,
}

-- HELD_HEAL_STATUS carries a status bitmask as its param (PSN bit 3, BRN 4,
-- FRZ 5, PAR 6, SLP_MASK %111; ALL_STATUS $FF reads back signed as -1).
local POLISHED_STATUS_MASK = {
  [8] = HeldItems.EFFECT.HEAL_POISON,
  [16] = HeldItems.EFFECT.HEAL_BURN,
  [32] = HeldItems.EFFECT.HEAL_FREEZE,
  [64] = HeldItems.EFFECT.HEAL_PARALYZE,
  [7] = HeldItems.EFFECT.HEAL_SLEEP,
  [-1] = HeldItems.EFFECT.HEAL_STATUS,
}

-- HELD_TYPE_BOOST carries the type id (constants/type_constants.asm).
local POLISHED_TYPE_BOOST = {
  [0] = HeldItems.EFFECT.NORMAL_BOOST, HeldItems.EFFECT.FIGHTING_BOOST,
  HeldItems.EFFECT.FLYING_BOOST, HeldItems.EFFECT.POISON_BOOST,
  HeldItems.EFFECT.GROUND_BOOST, HeldItems.EFFECT.ROCK_BOOST,
  HeldItems.EFFECT.BUG_BOOST, HeldItems.EFFECT.GHOST_BOOST,
  HeldItems.EFFECT.STEEL_BOOST, HeldItems.EFFECT.FIRE_BOOST,
  HeldItems.EFFECT.WATER_BOOST, HeldItems.EFFECT.GRASS_BOOST,
  HeldItems.EFFECT.ELECTRIC_BOOST, HeldItems.EFFECT.PSYCHIC_BOOST,
  HeldItems.EFFECT.ICE_BOOST, HeldItems.EFFECT.DRAGON_BOOST,
  HeldItems.EFFECT.DARK_BOOST, HeldItems.EFFECT.FAIRY_BOOST,
}

-- Params rescaled to this file's conventions: chances here are out of 256,
-- Polished's QUICK_CLAW/FLINCH_UP are percent (BattleRandomRange 100); type
-- boosts are x1.2 (`ln a, 6, 5`), not Crystal's param-percent 10.
-- BRIGHTPOWDER is a x0.9 multiplier there ($9a) and a flat subtraction from
-- the 0-255 threshold here: 26 is 10% of a sure hit.
local function translatePolished(raw, param)
  local direct = POLISHED_DIRECT[raw]
  if direct then return direct, param end
  if raw == POLISHED.HEAL_STATUS then
    return POLISHED_STATUS_MASK[param] or HeldItems.EFFECT.NONE, 0
  elseif raw == POLISHED.TYPE_BOOST then
    return POLISHED_TYPE_BOOST[param] or HeldItems.EFFECT.NONE, 20
  elseif raw == POLISHED.QUICK_CLAW then
    return HeldItems.EFFECT.QUICK_CLAW, math.floor(param * 256 / 100)
  elseif raw == POLISHED.FLINCH_UP then
    return HeldItems.EFFECT.FLINCH, math.floor(param * 256 / 100)
  elseif raw == POLISHED.BRIGHTPOWDER then
    return HeldItems.EFFECT.BRIGHTPOWDER, 26
  end
  return HeldItems.EFFECT.NONE, 0
end

local function polishedNumbering()
  return GameVersion.get() == "polishedcrystal"
end

local STATUS_BY_EFFECT = {
  [HeldItems.EFFECT.HEAL_POISON] = "PSN",
  [HeldItems.EFFECT.HEAL_FREEZE] = "FRZ",
  [HeldItems.EFFECT.HEAL_BURN] = "BRN",
  [HeldItems.EFFECT.HEAL_SLEEP] = "SLP",
  [HeldItems.EFFECT.HEAL_PARALYZE] = "PAR",
}

local function norm(value)
  if value == nil then return nil end
  local key = tostring(value):upper():gsub("[%.']", "")
  key = key:gsub("[^A-Z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  local aliases = {
    KING_S_ROCK = "KINGS_ROCK",
    MYSTERYBERRY = "MYSTERY_BERRY",
    MIRACLEBERRY = "MIRACLE_BERRY",
    SILVERPOWDER = "SILVER_POWDER",
    TWISTEDSPOON = "TWISTED_SPOON",
    NEVERMELTICE = "NEVER_MELT_ICE",
    BLACKGLASSES = "BLACK_GLASSES",
    FARFETCH_D = "FARFETCHD",
  }
  return aliases[key] or key
end
HeldItems.norm = norm

local function monOf(holder)
  return holder and (holder.mon or holder) or nil
end

local function itemDef(data, holder)
  local mon = monOf(holder)
  local id = mon and (mon.item or mon.heldItem)
  if not (id and data and data.items) then return nil, id end
  return data.items[id], id
end

function HeldItems.itemKey(data, holder)
  local def, id = itemDef(data, holder)
  if not id then return nil end
  local key = ItemEffects.alias(id, def)
  return norm(key or (def and (def.key or def.name)) or id)
end

function HeldItems.effect(data, holder)
  local def, id = itemDef(data, holder)
  if type(def) ~= "table" then return HeldItems.EFFECT.NONE, 0 end

  -- Intentional Gen II cleanup approved for the recomp ruleset: retail
  -- Crystal accidentally assigns HELD_DRAGON_BOOST to Dragon Scale and leaves
  -- Dragon Fang with HELD_NONE.  Treat Dragon Fang as the Dragon-type booster
  -- and Dragon Scale as a normal held item instead of reproducing that bug.
  local raw = tonumber(def.heldEffect) or HeldItems.EFFECT.NONE
  local param = tonumber(def.heldParam) or 0
  -- Polished's own attributes already give Dragon Fang the Dragon boost.
  if polishedNumbering() then return translatePolished(raw, param) end

  local key = norm(ItemEffects.alias(id, def) or def.key or def.name or id)
  if key == "DRAGON_FANG" then
    return HeldItems.EFFECT.DRAGON_BOOST, 10
  elseif key == "DRAGON_SCALE" then
    return HeldItems.EFFECT.NONE, 0
  end

  return raw, param
end

local function speciesKey(holder)
  local mon = monOf(holder)
  return norm(mon and mon.species)
end

local function consume(holder)
  local mon = monOf(holder)
  if not mon then return end
  mon.item, mon.heldItem = nil, nil
end
HeldItems.consume = consume

local function isAlive(holder)
  local mon = monOf(holder)
  return mon and (tonumber(mon.hp) or 0) > 0
end

local function heal(holder, amount)
  local mon = monOf(holder)
  local maxHP = mon and mon.stats and tonumber(mon.stats.hp)
  if not (mon and maxHP and tonumber(mon.hp)) or mon.hp <= 0 or mon.hp >= maxHP then
    return 0
  end
  local before = mon.hp
  mon.hp = math.min(maxHP, mon.hp + math.max(1, math.floor(amount or 0)))
  return mon.hp - before
end

local function displayName(holder)
  if not holder then return "POKéMON" end
  if holder.name then return holder.isPlayer == false and ("Enemy " .. holder.name) or holder.name end
  local mon = monOf(holder)
  return mon and (mon.nickname or mon.species) or "POKéMON"
end

local function queueHeal(battle, holder, text)
  if text then battle:sayNext(Strings(text, displayName(holder))) end
  local mon = monOf(holder)
  if battle.drainNext and mon then battle:drainNext(holder, mon.hp) end
end

-- -------------------------------------------------------------------------
-- Turn order / hit chance / critical chance
-- -------------------------------------------------------------------------

function HeldItems.quickClaw(data, holder, rng)
  local effect, param = HeldItems.effect(data, holder)
  if effect ~= HeldItems.EFFECT.QUICK_CLAW then return false end
  rng = rng or love.math.random
  return rng(0, 255) < param
end

function HeldItems.accuracyPenalty(data, holder)
  local effect, param = HeldItems.effect(data, holder)
  return effect == HeldItems.EFFECT.BRIGHTPOWDER and param or 0
end

function HeldItems.criticalStageBonus(data, holder)
  local effect = HeldItems.effect(data, holder)
  if effect == HeldItems.EFFECT.CRITICAL_UP then return 1 end
  local key, species = HeldItems.itemKey(data, holder), speciesKey(holder)
  if key == "STICK" and species == "FARFETCHD" then return 2 end
  if key == "LUCKY_PUNCH" and species == "CHANSEY" then return 2 end
  return 0
end

-- -------------------------------------------------------------------------
-- Damage/stat held items
-- -------------------------------------------------------------------------

function HeldItems.modifyBattleStats(data, attacker, defender, atkStat, defStat, atk, dfn)
  local aKey, aSpecies = HeldItems.itemKey(data, attacker), speciesKey(attacker)
  local dEffect = HeldItems.effect(data, defender)
  local dSpecies = speciesKey(defender)

  if aKey == "THICK_CLUB" and (aSpecies == "CUBONE" or aSpecies == "MAROWAK")
     and atkStat == "attack" then
    atk = atk * 2
  elseif aKey == "LIGHT_BALL" and aSpecies == "PIKACHU"
     and (atkStat == "spatk" or atkStat == "special") then
    atk = atk * 2
  end

  -- A transformed Ditto keeps mon.species = DITTO while battler.species is the
  -- copied species.  Metal Powder only works before Transform.
  local untransformedDitto = dSpecies == "DITTO"
    and (defender.species == nil or norm(defender.species) == "DITTO")
  local anyDef = defStat == "defense" or defStat == "spdef" or defStat == "special"
  local spDef = defStat == "spdef" or defStat == "special"
  if dEffect == HeldItems.EFFECT.METAL_POWDER and untransformedDitto and anyDef then
    dfn = math.floor(dfn * 3 / 2)
  end

  -- Polished's Choice Band/Specs (ApplyPhysical/SpecialAttackDamageMod x1.5),
  -- Assault Vest (Sp.Def damage mod 2/3, i.e. Sp.Def x1.5) and Eviolite
  -- (SetDefenseBoost x1.5 on both defences while the species can still
  -- evolve).  Only reachable through translatePolished.
  local aEffect, aParam = HeldItems.effect(data, attacker)
  if aEffect == HeldItems.EFFECT.CHOICE then
    if (aParam == HeldItems.CHOICE_STAT.ATTACK and atkStat == "attack")
       or (aParam == HeldItems.CHOICE_STAT.SP_ATTACK
           and (atkStat == "spatk" or atkStat == "special")) then
      atk = math.floor(atk * 3 / 2)
    end
  end
  if dEffect == HeldItems.EFFECT.ASSAULT_VEST and spDef then
    dfn = math.floor(dfn * 3 / 2)
  elseif dEffect == HeldItems.EFFECT.EVIOLITE and anyDef
     and HeldItems.canEvolve(data, defender) then
    dfn = math.floor(dfn * 3 / 2)
  end
  return atk, dfn
end

-- Eviolite's gate: the holder's own (party) species has an evolution entry,
-- the same EvosAttacks test Polished makes.
function HeldItems.canEvolve(data, holder)
  local mon = monOf(holder)
  local def = mon and data and data.pokemon and data.pokemon[mon.species]
  return def ~= nil and type(def.evolutions) == "table" and #def.evolutions > 0
end

function HeldItems.applyTypeBoost(data, attacker, moveType, damage)
  local effect, param = HeldItems.effect(data, attacker)
  if TYPE_BY_EFFECT[effect] ~= moveType then return damage end
  -- ItemAttributes stores 10 for the retail type boosters: x1.10, with the
  -- floor occurring here inside the damage pipeline.
  return math.max(1, math.floor(damage * (100 + param) / 100))
end

-- Polished's other attacker damage items, from the same BattleCommand_DamageCalc
-- switch as the type boost (an item is only ever one of them): Life Orb x1.3,
-- Muscle Band / Wise Glasses x1.1 for a matching physical / special move.
function HeldItems.applyDamageBoost(data, attacker, special, damage)
  local effect, param = HeldItems.effect(data, attacker)
  if effect == HeldItems.EFFECT.LIFE_ORB then
    return math.max(1, math.floor(damage * 13 / 10))
  elseif effect == HeldItems.EFFECT.CATEGORY_BOOST then
    local want = special and HeldItems.CATEGORY.SPECIAL or HeldItems.CATEGORY.PHYSICAL
    if param == want then return math.max(1, math.floor(damage * 11 / 10)) end
  end
  return damage
end

-- Choice Scarf: x1.5 after paralysis and the speed abilities, as in
-- Polished's GetSpeed.
function HeldItems.modifySpeed(data, holder, speed)
  local effect, param = HeldItems.effect(data, holder)
  if effect == HeldItems.EFFECT.CHOICE and param == HeldItems.CHOICE_STAT.SPEED then
    return math.max(1, math.floor(speed * 3 / 2))
  end
  return speed
end

-- Second return value names the item that saved the holder, when one did, so
-- the caller can print it after the HP bar moves.  Focus Band stays silent to
-- keep the existing Crystal behaviour byte-for-byte.
function HeldItems.limitDirectDamage(data, target, damage, rng)
  if not isAlive(target) or damage <= 0 then return damage end
  local effect, param = HeldItems.effect(data, target)
  local mon = monOf(target)
  local hp = tonumber(mon.hp) or 0
  if hp <= 1 or damage < hp then return damage end
  -- Focus Sash: a certainty from FULL HP (CheckOpponentFullHP), consumed on
  -- use; Focus Band is a flat roll at any HP and is kept.
  if effect == HeldItems.EFFECT.FOCUS_SASH then
    local maxHP = mon.stats and tonumber(mon.stats.hp)
    if maxHP and hp >= maxHP then
      consume(target)
      return hp - 1, "FOCUS_SASH"
    end
    return damage
  end
  if effect ~= HeldItems.EFFECT.FOCUS_BAND then return damage end
  rng = rng or love.math.random
  if rng(0, 255) < param then return hp - 1 end
  return damage
end

local function itemName(data, id)
  local def = id and data and data.items and data.items[id]
  return (type(def) == "table" and def.name) or tostring(id or "ITEM"):gsub("_", " ")
end
HeldItems.itemName = itemName

local function hasMagicGuard(holder)
  local ok, Abilities = pcall(require, "src.battle.Abilities")
  return ok and Abilities.of(holder) == "MAGIC_GUARD"
end

-- Item recoil bypasses a Substitute (it is the user's own HP), so it is taken
-- here rather than through BattleState:applyDamage.
local function loseHP(battle, holder, amount)
  local mon = monOf(holder)
  local dealt = math.min(amount, mon.hp)
  mon.hp = mon.hp - dealt
  if dealt > 0 and battle.drainNext then battle:drainNext(holder, mon.hp) end
  return dealt
end

-- Rocky Helmet: 1/6 of the ATTACKER's max HP per landed contact hit, even if
-- the holder fainted from it (Polished checks only that the attacker is still
-- up).  Contact comes from move.makesContact, which RomExtractorGen2 now
-- writes for Polished (physical/special category vs. AbnormalContactMoves,
-- see extractMoves ~2821-2835) -- Crystal/Gold/Silver still leave it nil,
-- so the fallback below ("physical moves make contact") still carries them.
function HeldItems.makesContact(move)
  if move.makesContact ~= nil then return move.makesContact == true end
  local category = move.category
  if category == nil then
    category = require("src.battle.TypeChart").category(move.type)
  end
  return category ~= "special" -- Damage's categoryOf also defaults to physical
end

function HeldItems.rockyHelmet(battle, user, target, move, hits)
  if not (battle and user and target and move) then return end
  if HeldItems.effect(battle.data, target) ~= HeldItems.EFFECT.ROCKY_HELMET then return end
  if not HeldItems.makesContact(move) or hasMagicGuard(user) then return end
  local maxHP = monOf(user).stats and tonumber(monOf(user).stats.hp)
  if not maxHP then return end
  local name = itemName(battle.data, monOf(target).item or monOf(target).heldItem)
  for _ = 1, math.max(1, hits or 1) do
    if not isAlive(user) then break end
    battle:sayNext(Strings("%s\nwas hurt by\n%s!", displayName(user), name))
    loseHP(battle, user, math.max(1, math.floor(maxHP / 6)))
  end
end

-- Life Orb: 1/10 max HP after a move that dealt damage (EndMoveUserItems).
function HeldItems.lifeOrbRecoil(battle, user)
  if not (battle and isAlive(user)) then return end
  if HeldItems.effect(battle.data, user) ~= HeldItems.EFFECT.LIFE_ORB then return end
  if hasMagicGuard(user) then return end
  local maxHP = monOf(user).stats and tonumber(monOf(user).stats.hp)
  if not maxHP then return end
  battle:sayNext(Strings("%s\nlost some of its\nHP!", displayName(user)))
  loseHP(battle, user, math.max(1, math.floor(maxHP / 10)))
end

-- -------------------------------------------------------------------------
-- Move selection: Choice lock and Assault Vest
-- -------------------------------------------------------------------------

local function isStatusMove(move)
  return move.category == "status" or (tonumber(move.power) or 0) == 0
end

-- The move a Choice holder is locked into, or nil.  Polished keeps the lock in
-- the Encore variable; here it is derived from battler.lastMove, which
-- makeBattler builds fresh on every switch-in, so switching out clears it
-- without a dedicated hook.  The lock only holds while that move is still in
-- the moveset with PP left: a called move (Metronome's pick) or an exhausted
-- one frees the holder instead of leaving it with nothing selectable.
function HeldItems.choiceLockedMove(data, battler)
  if not (battler and battler.lastMove) then return nil end
  if HeldItems.effect(data, battler) ~= HeldItems.EFFECT.CHOICE then return nil end
  local mon = monOf(battler)
  for _, m in ipairs(battler.curMoves or (mon and mon.moves) or {}) do
    if m.id == battler.lastMove and (tonumber(m.pp) or 0) > 0 then return m.id end
  end
  return nil
end

-- nil when the move may be chosen, else the refusal text.
function HeldItems.selectionBlock(data, battler, move)
  if not (battler and move) then return nil end
  local effect = HeldItems.effect(data, battler)
  local mon = monOf(battler)
  local id = mon and (mon.item or mon.heldItem)
  if effect == HeldItems.EFFECT.ASSAULT_VEST and isStatusMove(move) then
    return Strings("The %s\nprevents usage\nof status moves!", itemName(data, id))
  elseif effect == HeldItems.EFFECT.CHOICE then
    local locked = HeldItems.choiceLockedMove(data, battler)
    if locked and locked ~= move.id then
      local lockedDef = data and data.moves and data.moves[locked]
      return Strings("The %s\nonly allows use\nof %s!", itemName(data, id),
                     lockedDef and lockedDef.name or locked)
    end
  end
  return nil
end

-- Crystal does not run BattleCommand_KingsRock after every damaging move.
-- It is an explicit command in selected move-effect scripts (NormalHit,
-- LeechHit, MultiHit, RecoilHit, SkyAttack, Snore, etc.).  Keep that script
-- boundary here instead of approximating it from power or from whether a move
-- already has a native flinch chance.  In particular Sky Attack and Snore
-- really execute BOTH flinchtarget and kingsrock on cartridge.
local KINGS_ROCK_EFFECTS = {
  NO_ADDITIONAL_EFFECT = true,
  SWIFT_EFFECT = true,
  DRAIN_HP_EFFECT = true,
  EXPLODE_EFFECT = true,
  PAY_DAY_EFFECT = true,
  BIDE_EFFECT = true,
  THRASH_PETAL_DANCE_EFFECT = true,
  TWO_TO_FIVE_ATTACKS_EFFECT = true,
  ATTACK_TWICE_EFFECT = true,
  JUMP_KICK_EFFECT = true,
  TWINEEDLE_EFFECT = true,
  RECOIL_EFFECT = true,
  CHARGE_EFFECT = true,
  RAGE_EFFECT = true,
  FLY_EFFECT = true,
  SUPER_FANG_EFFECT = true,
  SPECIAL_DAMAGE_EFFECT = true,
  REVERSAL_EFFECT = true,
  COUNTER_EFFECT = true,
  SNORE_EFFECT = true,
  FALSE_SWIPE_EFFECT = true,
  THIEF_EFFECT = true,
  ROLLOUT_EFFECT = true,
  FURY_CUTTER_EFFECT = true,
  RETURN_EFFECT = true,
  PRESENT_EFFECT = true,
  FRUSTRATION_EFFECT = true,
  MAGNITUDE_EFFECT = true,
  PURSUIT_EFFECT = true,
  RAPID_SPIN_EFFECT = true,
  HIDDEN_POWER_EFFECT = true,
  MIRROR_COAT_EFFECT = true,
  SOLARBEAM_EFFECT = true,
  BEAT_UP_EFFECT = true,
}

function HeldItems.supportsKingsRock(move)
  if not move then return false end
  -- Triple Kick has its own Crystal effect byte, but the importer represents
  -- its three-hit semantics through move.multiHit instead of a separate effect
  -- name.  Its script ends in `kingsrock` just like the other eligible moves.
  if norm(move.id) == "TRIPLE_KICK" or tonumber(move.multiHit) == 3 then
    return true
  end
  return KINGS_ROCK_EFFECTS[norm(move.effect)] == true
end

function HeldItems.tryKingsRock(data, user, target, move, rng, blockedBySubstitute)
  if blockedBySubstitute or not isAlive(target) or not HeldItems.supportsKingsRock(move) then
    return false
  end
  local effect, param = HeldItems.effect(data, user)
  if effect ~= HeldItems.EFFECT.FLINCH then return false end
  rng = rng or love.math.random
  if rng(0, 255) < param then
    target.flinched = true
    return true
  end
  return false
end

-- -------------------------------------------------------------------------
-- Automatic consumables
-- -------------------------------------------------------------------------

-- Gen II keeps one confusion counter per battle side, separate from the
-- active party struct.  Switching therefore leaves the previous counter
-- behind.  Ordinary confusion effects initialize this counter explicitly;
-- Berserk Gene does the same here as an intentional correction of Crystal's
-- retail 256-turn/stale-counter bug.
local function confusionSide(holder)
  return holder and holder.isPlayer and "player" or "enemy"
end

function HeldItems.setConfusionCounter(battle, holder, turns)
  if not (battle and holder) then return end
  battle.heldConfusionCounters = battle.heldConfusionCounters or {}
  battle.heldConfusionCounters[confusionSide(holder)] = math.max(0, tonumber(turns) or 0)
end

function HeldItems.confusionCounter(battle, holder)
  local counters = battle and battle.heldConfusionCounters
  return counters and (tonumber(counters[confusionSide(holder)]) or 0) or 0
end

local function curePersistent(holder, wanted)
  local mon = monOf(holder)
  local status = mon and mon.status
  if not status then return false end
  if wanted and norm(status) ~= wanted then return false end
  mon.status = nil
  holder.sleepTurns, holder.toxicCounter = nil, nil
  return true
end

function HeldItems.onStatus(battle, holder)
  if not (battle and isAlive(holder)) then return {} end
  local effect = HeldItems.effect(battle.data, holder)
  local wanted = STATUS_BY_EFFECT[effect]
  local changed = false
  if wanted then
    changed = curePersistent(holder, wanted)
  elseif effect == HeldItems.EFFECT.HEAL_STATUS then
    changed = curePersistent(holder)
    -- MiracleBerry cures every major status at once, including confusion.
    -- If a primary status triggered it while confusion is also active, clear
    -- both before consuming the item rather than leaving confusion behind.
    if changed then
      holder.confusedTurns = nil
      HeldItems.setConfusionCounter(battle, holder, 0)
    end
  end
  if not changed then return {} end
  consume(holder)
  holder.shownStatus = holder.mon.status
  return { Strings("%s's held item\ncured its status!", displayName(holder)) }
end

function HeldItems.onConfusion(battle, holder)
  if not (battle and isAlive(holder)) or not holder.confusedTurns then return {} end
  local effect = HeldItems.effect(battle.data, holder)
  local key = HeldItems.itemKey(battle.data, holder)
  if effect ~= HeldItems.EFFECT.HEAL_CONFUSION
     and effect ~= HeldItems.EFFECT.HEAL_STATUS
     and key ~= "BITTER_BERRY" and key ~= "MIRACLE_BERRY" then
    return {}
  end
  holder.confusedTurns = nil
  HeldItems.setConfusionCounter(battle, holder, 0)
  consume(holder)
  return { Strings("%s snapped out\nwith its held item!", displayName(holder)) }
end

local function restorePP(data, holder)
  local mon = monOf(holder)
  for i, move in ipairs(mon and mon.moves or {}) do
    if (tonumber(move.pp) or 0) <= 0 then
      local def = data.moves and data.moves[move.id]
      local base = def and tonumber(def.pp)
      local maxPP = base
      if base then maxPP = base + (tonumber(move.ppUps) or 0) * math.floor(base / 5) end
      local amount = norm(move.id) == "SKETCH" and 1 or 5
      move.pp = maxPP and math.min(maxPP, amount) or amount
      if holder.curMoves and holder.curMoves ~= mon.moves and holder.curMoves[i] then
        holder.curMoves[i].pp = move.pp
      end
      return true
    end
  end
  return false
end

local function processLeftovers(battle, holder)
  if not isAlive(holder) then return end
  local effect = HeldItems.effect(battle.data, holder)
  if effect ~= HeldItems.EFFECT.LEFTOVERS then return end
  local mon = monOf(holder)
  local maxHP = mon.stats and tonumber(mon.stats.hp)
  if not maxHP then return end
  local got = heal(holder, math.max(1, math.floor(maxHP / 16)))
  if got > 0 then
    queueHeal(battle, holder, "%s restored HP\nwith LEFTOVERS!")
  end
end

local function processRestorePP(battle, holder)
  if not isAlive(holder) then return end
  local effect = HeldItems.effect(battle.data, holder)
  if effect == HeldItems.EFFECT.RESTORE_PP and restorePP(battle.data, holder) then
    consume(holder)
    battle:sayNext(Strings("%s's held item\nrestored PP!", displayName(holder)))
  end
end

local function processHealingItem(battle, holder)
  if not isAlive(holder) then return end
  local effect, param = HeldItems.effect(battle.data, holder)
  local mon = monOf(holder)
  if effect == HeldItems.EFFECT.BERRY then
    local maxHP = mon.stats and tonumber(mon.stats.hp)
    if maxHP and mon.hp * 2 <= maxHP then
      -- Polished's Sitrus and Figy carry param 0; _HeldHPHealingItem heals
      -- a quarter / a third of max HP for them by item id instead.
      local key = HeldItems.itemKey(battle.data, holder)
      if key == "SITRUS_BERRY" then
        param = math.floor(maxHP / 4)
      elseif key == "FIGY_BERRY" then
        param = math.floor(maxHP / 3)
      end
      local got = heal(holder, param)
      if got > 0 then
        consume(holder)
        queueHeal(battle, holder, "%s restored HP\nwith its held item!")
      end
    end
    return
  end

  -- Status berries normally fire as soon as the condition is inflicted.  This
  -- fallback mirrors HandleHealingItems for a status that entered through an
  -- older/non-standard seam.
  local msgs = HeldItems.onStatus(battle, holder)
  if #msgs == 0 then msgs = HeldItems.onConfusion(battle, holder) end
  for _, msg in ipairs(msgs) do battle:sayNext(msg) end
end

-- HandleBetweenTurnEffects reaches held items only after weather and its faint
-- checks.  Keep the item phases grouped rather than processing every item on
-- one battler at once: cartridge order is Leftovers, MysteryBerry, then the
-- healing/status-item family.
function HeldItems.endTurn(battle)
  if not battle or battle.result then return end
  local battlers = { battle.player, battle.enemy }
  for _, b in ipairs(battlers) do processLeftovers(battle, b) end
  for _, b in ipairs(battlers) do processRestorePP(battle, b) end
  for _, b in ipairs(battlers) do processHealingItem(battle, b) end
end

-- Berserk Gene is HELD_NONE in ItemAttributes and is detected by key.
-- Crystal retail leaves the side confusion counter uninitialized, causing a
-- stale-counter/256-turn bug.  This implementation intentionally corrects
-- that legacy bug by initializing a normal Gen II confusion duration.
function HeldItems.onEntry(battle, holder)
  if not (battle and isAlive(holder)) then return false end
  if HeldItems.itemKey(battle.data, holder) ~= "BERSERK_GENE" then return false end
  consume(holder)
  holder.stages = holder.stages or {}
  holder.stages.attack = math.min(6, (tonumber(holder.stages.attack) or 0) + 2)
  holder.confusedTurns = battle.rng(2, 5)
  HeldItems.setConfusionCounter(battle, holder, holder.confusedTurns)
  battle:sayNext(Strings("%s's BERSERK GENE\nsharply raised ATTACK!", displayName(holder)))
  return true
end

-- -------------------------------------------------------------------------
-- EXP / prize money / escape / encounter rate
-- -------------------------------------------------------------------------

function HeldItems.modifyExperience(data, mon, gained)
  if HeldItems.itemKey(data, mon) == "LUCKY_EGG" then
    return math.max(1, math.floor(gained * 3 / 2))
  end
  return gained
end

function HeldItems.observeParticipant(battle, holder)
  if battle and holder and holder.isPlayer then
    local effect = HeldItems.effect(battle.data, holder)
    if effect == HeldItems.EFFECT.AMULET_COIN then battle.amuletCoin = true end
  end
end

function HeldItems.modifyPrize(battle, prize)
  return battle and battle.amuletCoin and prize * 2 or prize
end

function HeldItems.canEscape(data, holder)
  local effect = HeldItems.effect(data, holder)
  return effect == HeldItems.EFFECT.ESCAPE
end

-- Crystal scans the whole party for Cleanse Tag, then halves the encounter
-- rate byte before the first encounter RNG draw.  The holder does not need to
-- be in slot one (ApplyCleanseTagEffectOnEncounterRate loops wPartyCount).
function HeldItems.cleanseTagRate(data, party, rate)
  for _, mon in ipairs(party or {}) do
    local effect = HeldItems.effect(data, mon)
    if effect == HeldItems.EFFECT.CLEANSE_TAG then
      return math.floor((tonumber(rate) or 0) / 2)
    end
  end
  return rate
end

return HeldItems
