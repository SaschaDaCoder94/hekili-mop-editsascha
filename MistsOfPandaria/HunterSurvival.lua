-- Combat log event handlers for Survival mechanics
spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID ~= state.GUID then return end
    
    -- Lock and Load procs from Auto Shot crits and other ranged abilities
    if subtype == "SPELL_PERIODIC_DAMAGE" and spellID == 3674 then -- Black Arrow
        if lnl_icd_ready() and math.random() <= 0.20 then
            state.applyBuff( "lock_and_load", 8 )
            lnl_last_proc = GetTime()
        end
    end

)
