-- Compat shim, not an alias: src.core.ModCompat deliberately has no entry for
-- src.world.gen2.FieldMoves because this engine has no single module that
-- matches it -- field-move eligibility lives as methods on OverworldState
-- (tryCutOW, useSurfFieldMove, tryDiveOW, tryWaterfallOW...). Mods that
-- `require` the Gold-port name unconditionally (e.g. pokemon-gen1-recomp-
-- mod-qol's easy_interactions) still need the require itself to succeed, so
-- this wraps those methods behind the handful of entry points such mods
-- actually call: fromMenu, isSurfing, trySurfOW.
--
-- Every caller in that mod only reaches these through its own
-- World:fieldContext(), which this engine does not implement -- so ctx is
-- always nil and these bodies are unreachable in practice. They are still
-- written to degrade honestly (party-knows-the-move / real surf gate)
-- instead of stubbing, in case a future engine version adds fieldContext.

local FieldMoves = {}

local function overworld()
  local ok, Game = pcall(require, "src.core.Game")
  return ok and Game and Game.overworld or nil
end

function FieldMoves.isSurfing(playerState)
  return playerState ~= nil and playerState.surfing == true
end

function FieldMoves.trySurfOW(ctx)
  local ow = overworld()
  if not ow then return { ok = false } end
  return { ok = ow:useSurfFieldMove() == "ok" }
end

function FieldMoves.fromMenu(moveId, ctx)
  local ow = overworld()
  if not ow or type(ow.partyKnows) ~= "function" then return { ok = false } end
  return { ok = ow:partyKnows(moveId) ~= nil }
end

return FieldMoves
