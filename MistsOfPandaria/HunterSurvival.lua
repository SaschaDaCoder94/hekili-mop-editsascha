--[[
    Hekili Hunter (Survival) Module for Mists of Pandaria
    Original Authors: Saschadasilva, smufrik
    Refactored and debugged for consistency and fluid gameplay.
]]

-- Early return if the player is not a Hunter.
if select(2, UnitClass('player')) ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G["Hekili"]

-- Early return if Hekili is not available.
if not Hekili or not Hekili.NewSpecialization then return end

local class = Hekili.Class
local state = Hekili.State
local strformat = string.format

-- Create the specialization object for Survival Hunter (ID 255).
local spec = Hekili:NewSpecialization(255, true)

----------------------------------------------------------------------------------------------------
-- RESOURCE REGISTRATION
-- Defines passive/periodic resource generation. Active gains are handled by abilities' 'spend' value.
----------------------------------------------------------------------------------------------------

-- MoP Power Type for Focus is 2.
spec:RegisterResource(2, {
    dire_beast = {
        resource = "focus",
        aura = "dire_beast",
        last = function()
            local app = state.buff.dire_beast.applied
            local t = state.query_time
            return app + floor((t - app) / 2) * 2
        end,
        interval = 2,
        value = 5,
    },
    fervor = {
        resource = "focus",
        aura = "fervor",
        last = function() return state.buff.fervor.applied end,
        interval = 1,
        value = 5,
        duration = 10,
    },
})

----------------------------------------------------------------------------------------------------
-- STATE MANAGEMENT
-- Defines custom variables and logic hooks for core mechanics.
----------------------------------------------------------------------------------------------------

-- Registers the 'hunter' table as a persistent part of the state engine.
spec:RegisterStateTable("hunter", {
    -- This special function is called by Hekili every time the state is reset.
    onReset = function(t)
        -- 't' refers to the 'hunter' table itself.
        -- If we are out of combat, this reliably resets our custom timers for the next fight.
        if state.time == 0 then
            t.lastLockProcTime = 0
            t.lockICDExpires = 0
        end
    end
})

-- Hooks into the combat log to reliably detect when a new Lock and Load buff is applied.
-- This is the most accurate way to handle procs and avoids addon update-order race conditions.
spec:RegisterHook("COMBAT_LOG_EVENT_UNFILTERED", function(_, subtype, _, sourceGUID, _, _, _, _, _, _, _, spellID, _)
    if sourceGUID ~= state.GUID then return end

    -- We only care about buffs being applied.
    if subtype == "SPELL_AURA_APPLIED" then
        -- The spell ID for the Lock and Load buff is 56453.
        if spellID == 56453 then
            -- A new proc has occurred in the game.
            local now = GetTime()

            -- Set the timers in our stable state table.
            state.hunter.lastLockProcTime = now
            state.hunter.lockICDExpires = now + 9 -- Start the 9-second ICD.

            -- Force the addon to immediately re-evaluate its recommendations with the new proc.
            Hekili:ForceUpdate("Lock_and_Load_Proc")
        end
    end
end)

----------------------------------------------------------------------------------------------------
-- TALENTS
----------------------------------------------------------------------------------------------------

spec:RegisterTalents({
    -- Tier 1 (Level 15)
    posthaste = { 1, 1, 109215 },
    narrow_escape = { 1, 2, 109298 },
    crouching_tiger_hidden_chimera = { 1, 3, 118675 },

    -- Tier 2 (Level 30)
    binding_shot = { 2, 1, 109248 },
    wyvern_sting = { 2, 2, 19386 },
    intimidation = { 2, 3, 19577 },

    -- Tier 3 (Level 45)
    exhilaration = { 3, 1, 109260 },
    aspect_of_the_iron_hawk = { 3, 2, 109260 },
    spirit_bond = { 3, 3, 109212 },

    -- Tier 4 (Level 60)
    fervor = { 4, 1, 82726 },
    dire_beast = { 4, 2, 120679 },
    thrill_of_the_hunt = { 4, 3, 109306 },

    -- Tier 5 (Level 75)
    a_murder_of_crows = { 5, 1, 131894 },
    blink_strikes = { 5, 2, 130392 },
    lynx_rush = { 5, 3, 120697 },

    -- Tier 6 (Level 90)
    glaive_toss = { 6, 1, 117050 },
    powershot = { 6, 2, 109259 },
    barrage = { 6, 3, 120360 },
})

----------------------------------------------------------------------------------------------------
-- AURAS (Buffs & Debuffs)
----------------------------------------------------------------------------------------------------

spec:RegisterAuras({
    a_murder_of_crows = { id = 131894, duration = 30 },
    aspect_of_the_cheetah = { id = 5118 },
    aspect_of_the_hawk = { id = 13165 },
    aspect_of_the_iron_hawk = {
            id = 109260,
            duration = 3600,
            max_stack = 1,
            generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "player", 109260 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 3600
                    t.caster = "player"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
        },
    barrage = { id = 120360, duration = 3 },
    binding_shot = { id = 109248, duration = 4 },
    black_arrow = { id = 3674, duration = 20, debuff = true },
    blink_strikes = { id = 130392 },
    careful_aim = { id = 82926, duration = 20, max_stack = 2 },
    concussive_shot = { id = 5116, duration = 6 },
    deterrence = { id = 19263, duration = 5 },
    dire_beast = { id = 120679, duration = 15 },
    disengage = { id = 781 },
    exhilaration = { id = 109260 },
    explosive_shot = { id = 53301, duration = 4 },
    explosive_trap = { id = 13813, duration = 20 },
    fervor = { id = 82726, duration = 3 },
    focus_fire = { id = 82692, duration = 20 },
    growl = { id = 2649, duration = 3, type = "Taunt" },
    hunters_mark = { id = 1130, duration = 300, type = "Ranged" },
    intimidation = { id = 19577, duration = 3 },
    kill_command = { id = 34026 },
    lynx_rush = { id = 120697, duration = 4 },
    mend_pet = { id = 136, duration = 10, unit = "pet" },
    misdirection = { id = 34477, duration = 8 },
    multi_shot = { id = 2643 },
    pet_dash = { id = 61684, duration = 16 },
    pet_prowl = { id = 24450 },
    piercing_shots = { id = 82924, duration = 8 },
    rapid_fire = { id = 3045, duration = 15 },
    serpent_sting = { id = 118253, duration = 15, tick_time = 3, debuff = true },
    silencing_shot = { id = 34490, duration = 3 },
    stampede = { id = 121818, duration = 12 },
    steady_focus = { id = 109259, duration = 10 },
    thrill_of_the_hunt = { id = 34720, duration = 8 },
    widow_venom = { id = 82654, duration = 12, debuff = true },
    wyvern_sting = { id = 19386, duration = 30 },

    lock_and_load = {
        id = 56453,
        duration = 12,
        max_stack = 3,
    },

    -- This virtual aura tracks the Internal Cooldown (ICD) of Lock and Load.
    -- It is triggered by the Combat Log Hook to ensure perfect timing.
    Lock_ICD = {
         duration = 9, -- The internal cooldown duration.
         generate = function(t)
            -- This function simply checks the timer that the Combat Log handler manages.
            if state.hunter.lockICDExpires > state.query_time then
                -- The ICD is ACTIVE.
                t.count = 1
                t.expires = state.hunter.lockICDExpires
                t.applied = state.hunter.lockICDExpires - 9
                t.caster = "player"
            else
                -- The ICD has expired.
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end
        end,
    },
})

----------------------------------------------------------------------------------------------------
-- STATE FUNCTIONS
----------------------------------------------------------------------------------------------------

spec:RegisterStateFunction("apply_aspect", function(name)
    removeBuff("aspect_of_the_hawk")
    removeBuff("aspect_of_the_iron_hawk")
    removeBuff("aspect_of_the_cheetah")
    removeBuff("aspect_of_the_pack")
    if name then applyBuff(name) end
end)

----------------------------------------------------------------------------------------------------
-- ABILITIES
----------------------------------------------------------------------------------------------------

spec:RegisterAbilities({
    a_murder_of_crows = {
        id = 131894,
        cooldown = 120,
        spend = 60,
        spendType = "focus",
        toggle = "cooldowns",
        handler = function() applyDebuff("target", "a_murder_of_crows") end,
    },
    aimed_shot = {
        id = 19434,
        cast = 2.4,
        cooldown = 10,
        spend = 50,
        spendType = "focus",
    },
    arcane_shot = {
        id = 3044,
        spend = function() return buff.thrill_of_the_hunt.up and 10 or 30 end,
        spendType = "focus",
        handler = function()
            if buff.thrill_of_the_hunt.up then
                removeStack("thrill_of_the_hunt", 1)
            end
        end,
    },
    aspect_of_the_cheetah = {
        id = 5118,
        handler = function() apply_aspect("aspect_of_the_cheetah") end,
    },
    aspect_of_the_hawk = {
        id = 13165,
        handler = function() apply_aspect("aspect_of_the_hawk") end,
    },
    aspect_of_the_iron_hawk = {
        id = 109260,
        handler = function() apply_aspect("aspect_of_the_iron_hawk") end,
    },
    auto_shot = {
        id = 75,
        cooldown = function() return state.mainhand_speed end,
        gcd = "off",
    },
    barrage = {
        id = 120360,
        cast = 3,
        channeled = true,
        cooldown = 20,
        spend = 40,
        spendType = "focus",
        handler = function() applyBuff("barrage") end,
    },
    binding_shot = { id = 109248 },
    black_arrow = {
        id = 3674,
        cooldown = 22, -- 30s base, minus 8s from MoP passive Improved Serpent Sting
        spend = 35,
        spendType = "focus",
        handler = function() applyDebuff("target", "black_arrow") end,
    },
    blink_strike = { id = 130392, cooldown = 20 },
    call_pet_1 = { id = 883, usable = function() return not pet.exists end },
    call_pet_2 = { id = 83242, usable = function() return not pet.exists end },
    call_pet_3 = { id = 83243, usable = function() return not pet.exists end },
 
    
    cobra_shot = {
        id = 77767,
        cast = function() return 2.0 / haste end,
        spend = -14,
        spendType = "focus",
        handler = function()
            if debuff.serpent_sting.up then
                local serpent_sting_aura = class.auras.serpent_sting
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                if debuff.serpent_sting.expires > (query_time + serpent_sting_aura.duration) then
                    debuff.serpent_sting.expires = query_time + serpent_sting_aura.duration
                end
            end
        end,
    },
    concussive_shot = { id = 5116, spend = 15, spendType = "focus", handler = function() applyDebuff("target", "concussive_shot", 6) end },
    deterrence = { id = 19263, cooldown = 90, gcd = "off", toggle = "defensives", handler = function() applyBuff("deterrence") end },
    dire_beast = { id = 120679, cooldown = 45, toggle = "cooldowns", handler = function() applyBuff("dire_beast") end },
    disengage = { id = 781, cooldown = 20, gcd = "off" },
    dismiss_pet = { id = 2641, cast = 2, usable = function() return pet.alive end },
    exhilaration = { id = 109260, cooldown = 120, gcd = "off", toggle = "defensives" },
    explosive_shot = {
        id = 53301,
        cooldown = function() return state.buff.lock_and_load.up and 0 or 6 end,
        spend = function() return buff.lock_and_load.up and 0 or 25 end,
        spendType = "focus",
        handler = function()
            applyDebuff("target", "explosive_shot")
            if buff.lock_and_load.up then
                removeStack("lock_and_load", 1)
            end
        end,
    },
    explosive_trap = { id = 13813, cooldown = 30, gcd = "off" },
    feign_death = { id = 5384, cooldown = 30, gcd = "off" },
    fervor = { id = 82726, cooldown = 30, gcd = "off", toggle = "cooldowns", handler = function() applyBuff("fervor") end },
    glaive_toss = { id = 117050, cooldown = 15, spend = 15, spendType = "focus" },
    hunters_mark = { id = 1130, handler = function() applyDebuff("target", "hunters_mark", 300) end },
    intimidation = { id = 19577 },
    kill_command = { id = 34026, cooldown = 6, spend = 40, spendType = "focus" },
    kill_shot = { id = 53351, spend = 0, spendType = "focus" },
    lynx_rush = { id = 120697, cooldown = 90, toggle = "cooldowns", handler = function() applyDebuff("target", "lynx_rush") end },
    mend_pet = { id = 136, channeled = true, cast = 10 },
    misdirection = { id = 34477, cooldown = 30, gcd = "off", handler = function() applyBuff("misdirection") end },
    multi_shot = { id = 2643, spend = 40, spendType = "focus" },
    pet_claw = { id = 16827, gcd = "off" },
    pet_bite = { id = 17253, gcd = "off" },
    pet_dash = { id = 61684, gcd = "off" },
    pet_growl = { id = 2649, cooldown = 5, gcd = "off" },
    pet_prowl = { id = 24450, gcd = "off" },
    powershot = { id = 109259, cast = 3, cooldown = 45, spend = 15, spendType = "focus" },
    rapid_fire = { id = 3045, cooldown = 300, gcd = "off", toggle = "cooldowns", handler = function() applyBuff("rapid_fire") end },
    revive_pet = { id = 982, cast = 6 },
    serpent_sting = { id = 1978, spend = 25, spendType = "focus", handler = function() applyDebuff("target", "serpent_sting") end },
    silencing_shot = { id = 34490, cooldown = 20, toggle = "interrupts", debuff = "casting", readyTime = state.timeToInterrupt },
    stampede = { id = 121818, cooldown = 300, gcd = "off", toggle = "cooldowns", handler = function() applyBuff("stampede") end },
    steady_shot = { id = 56641, cast = function() return 2.0 / haste end, spend = -14, spendType = "focus" },
    tranquilizing_shot = { id = 19801, cooldown = 8 },
    widow_venom = { id = 82654, spend = 15, spendType = "focus" },
    wyvern_sting = { id = 19386 },
})

----------------------------------------------------------------------------------------------------
-- PETS & GEAR
----------------------------------------------------------------------------------------------------

spec:RegisterPet("tenacity", 1, "call_pet_1")
spec:RegisterPet("ferocity", 2, "call_pet_2")
spec:RegisterPet("cunning", 3, "call_pet_3")

spec:RegisterGear("tier16", 99169, 99170, 99171, 99172, 99173)
spec:RegisterGear("tier15", 95307, 95308, 95309, 95310, 95311)
spec:RegisterGear("tier14", 84242, 84243, 84244, 84245, 84246)

----------------------------------------------------------------------------------------------------
-- STATE EXPRESSIONS (APL Custom Functions)
----------------------------------------------------------------------------------------------------

spec:RegisterStateExpr("focus_time_to_max", function()
    local regen_rate = 6 * haste
    return math.max(0, ((state.focus.max or 100) - (state.focus.current or 0)) / regen_rate)
end)

spec:RegisterStateExpr("ttd", function()
    return state.target.time_to_die
end)

spec:RegisterStateExpr("focus_deficit", function()
    return (state.focus.max or 100) - (state.focus.current or 0)
end)

-- Checks if a pet is active and alive.
spec:RegisterStateExpr("pet_alive", function()
    return pet.alive
end)

-- Used to check for Bloodlust/Heroism type effects.
spec:RegisterStateExpr("bloodlust", function()
    return buff.bloodlust.up
end)

-- Main logic for determining if Cobra Shot is a good choice.
spec:RegisterStateExpr("should_cobra_shot", function()
    if (state.focus.current or 0) > 86 then return false end -- Don't cast if we will over-cap focus.
    return true
end)

----------------------------------------------------------------------------------------------------
-- OPTIONS & SETTINGS
----------------------------------------------------------------------------------------------------

spec:RegisterOptions({
    enabled = true,
    aoe = 3,
    damageExpiration = 3,
    package = "Survival",
})

spec:RegisterSetting("focus_dump_threshold", 80, {
    name = "Focus Dump Threshold",
    desc = strformat("Focus level at which to prioritize spending abilities to avoid Focus capping."),
    type = "range",
    min = 50,
    max = 120,
    step = 5,
    width = "full"
})

    spec:RegisterPack( "Survival", 20250804, [[Hekili:fRv4YTTns4NLKBgv75s1jlB162XoZiNOK4CowzSuUo9pscIescJPi0rckFQtg(SF7cascqcsjz376pIJejWUlwS7h29dAYztgpzKprqNCF3oD715Yox0(SF(IE9(LjJe72qNmAdX7rYs4dHK1WFhLeTLTLeGVyxaN4JciMNe5bVCYO5jSaXTHtM7uQD6bJDd1dECp4JRy((u1yPXEtgnEfloDg(ps6mTEtNXxaF3tW4HPZcyXc41l4rPZ(e9rwaR9KrYhIMbbLT8J3lxx0qY8aQ)KBGxjfq2qMYxmvSIoDf5PhvkpITrnG(J(6G3noD2x6FF)po4ldUhKd8wbnIrMm6vPZMNSyr7QIPDYM0zTsNbJqqcOHIsJHfXdvdmZQeGxOKvEKkYXikutYM6w15JbmbXKr8n0qAutoTLbe2w6ubpoUK3A4xhC)GhsN9WWX9hF7W7tNDYhyrXI0zN1jDwm1Jh6hFQ5ct7CmezMdrUQwW9sGn43EniHEn7I848aF(tHTJfK1BO(02ruI)UcZo75OyoVjpTpv6jJPrGRqmnwWcxA5)SEdkUloaXnpaIGNsII4pLTNzS6oVxH4ngjk8E7nQiISH5pDblIAzMfpgfZpTFp38aohMqs0UY(UI3GI6N3VOI3fs2etNgVjc8rXv2lSFnk0lRvOgUPl6uid6)ztapgdBIxXXq37)LAfHomBbnAlpYve2vPZ6ziB1arzEwN9juY01jr(0imFYd2ZQnc(CdfuzsQKpF6cssGWv2NvI2x6F79MPzF9HBh(WTJ)90z3D7OXfQXJeemv9LPiUOL5ZwtLlCyjkbnNQG01aanMSPMRCr1KYmKAwKrCZPF40HDuWcwZOOF7W1aHtDLlwt4IT)8S2GNJ79iC0sOp(rIpMBjHU2SIedl2t6FZOH39TXdGJAU9JFAWOXMU9NwrdvNlTLAbWjtqd4ycDO)u8esmh1rADMDcNIf4Ye72gpfYCB3owmAjv0EfLeiw1EJhy3xb7oD70CQVvQLmEnpd22FvobUAYx9GchogO8j6LcgIbhim1NPJ0USweY6HoQhnVEvjpQPES(9cY0mEqU)T6WKU4Jf04aaOQ7W1CtXCaoncthI5P)O6lJt5m4YeBLe5rclIBoRbuMNpQD9imGEtc8N6XNhrKgrLf7fgao5Jsk16pNxl1yb6(2RyngMuULXcSs8phs8FpDbnet30auFta16kG9PtUB4VzbfD6bIw6NjrPbugHWYaUamG(Ysgbeisiuf(AyB5fO7ScZLh5TjcklC9CIZd9YJzSQy1BfLkiRkzMFkje2msNL1ss6SFeSx(xr7BW7g(LB6ln1bFT)dvGpDx9SwpgLyVMJkrfdUMVvdj8cRB)aBqOPMw2xjT73i2tZdfoa5I(aALO5II3qftjby4NDid(8ZAUQ3tWojeczzLRjr4bRqIW3)EoColE6CaDkD2PsRwxsHpCi2kzis8uCAPZGKYoh6XaMZuf3wuqtdXTgLGBhS(UHdV79d)T7RRZYCSzJA7lGMDx4FZvSvlwAUQ0VRYja1IYwFi3FnhfwFe3r1Cy9HE))4a16lwdYnAlZzSvwezoZV86r(WMllR22(KI)exHyQ0m5Z1bl4Zo1SWmZ(eRVUScDdjv0OhXAYEX6oxuUktlBucOHZhPIZGT8aSg78V7QuQstQBPj19Wka6k72711)i4rrqWurjqowhgI1vrnzZydxJGA31HCZiijwizfqD07wweC4naqcJuHJz1BYuzppnHO1yBu3n8D)tOwH7Fp0c1W(WFV5Bpilq4t9hnOI95QROMaWQRdhhTo1i4KtLxod9YARyvyw8uJEQvSaser9nl)07h8Hb3p62)1aTZ6BJV9oO(jhqnMcXcRXYpibOB07vA4M8OOEvSGhUhQXeRGuur7yMirApkhv3cjTMf7djRQV1iESEZ0NbLpeeGdWmzJe(VtG6B)difiF7CVGYXm4)8YMILVsRnpIQjUcqFRP0m4RwlpTBlnku3fPtSFRr4e8VRbyG5OBgUwBaSqOmfMF1aICdWAe71amhTk4g5r55ca0F4a38t8xAcVvJOM1ewqZesaIvPvvS1IO8KablxR1hJ3Oo0Ssu4mHO(n7HwIUoj)eNyZji)pN)L6ZAEbnBxFMWlPxBzeoKYfJVtDBu)Cxy0prIcLmrpA8ky9YwVHhj03S0pKxQ)pKolIcytryoxmh5aLKi4RjYEc9wrcxsJBN(57yHWR(PFfq2dJt2GYchGYKabkRo7hGbM(5BxN92llDVwWRHvrIyfuS9iiQBre7rSDz(cgcx(HKiOLlW8(aOSFCCcA(WbUKyuwOq6haTa)EIGK(5VgX4G7J9hGvjW1xfUobX6bpiw)EY8yEqIa(0k2Yv0ybSu(DEcOTa(syqG38jCOeHdzH3y3o5GxZrcuvotcszaQgKnbW84aKXASl9iUqFCIAJfhvH5oilqhASxUtRyAviVBqLvlVHqzYgi1TOlHeO0mbDbCLBcC5bGmPXVbMrOxqIV0HfrxerJxj)875JJLBk9xUeEOsRFqfw9rKuCTD(etScEHSk0Fv7JNTiIVoBDdtwEfOL8uQzOm4e5(eyT7WPcbva4EWoW3OV1ZqFMhewflV8taJfI5aXWHVULZ8X9HNYTTa6wAqSCUWGIzR9KUgmoPWPcl0ajfokx38DOnix2zMfAIeCGbe0zgStT7BRgO6CA7LTbN4CQ0gqev5aovzFqHrjOTcEcqC4NcPYnLxlh1pcDAfTL63(1OJE0UqVvr8q5wTmG9gfP7VllLZzGhyLEbuseETWcaviugwKR1eKV(hWMhWSJikySJux4e8b1no9gDeRE)I4XibG4p5gSMzywqhmWqUjVu8tL(va5hkeKNeR3POzH40flO6iWsU)Lr8KnQ0ku9WXTCP9JUE89VwwX9RronWyapQmaCywYXNaRmqUlH37ngGQnC9Ec0uyi0gCHBAtazxSyhk65KasOmiCnb0l8pPGgPy0g(Gq(DP4Ubr0HTaesplaxxVuUUI16kBPxjeBfAS0SimLqIHELWOo2c8ZqenYDyCwgrwWIAH5dUMqmhFHkXfoXcDgaah6kK2574R3eqrGP(sSsyw3bGLPF(gv0ildbBHEszJcHuHLewblM4HH)iTJAFIuFY5Xcbm)16eDZCAv8N0iMtL3luekCP)vEmbXK6XmYizHsoilYRZSpnaLNxcGQq1c2imk35QCuqdiOEnxbfi9kdCj0GhU7d(raqs65(BfgsfwrvV2n1OPFw73ANZo7F)6)HtYrFdBX1VQrUtB9knRPTuKhEich5qSojRzKS1RomEtpe1LpP9QZ9qtkUwRFnwWWPup5CG6E0MuoIJ)KkSE(9VBZ45PT01CwMRZR70QAvDV9SE6GGMVn5CRlBfO(QKw)3GSkCT6gJrBef)vN1z)tjVKQSz92RpF)ZcAnbhVDL1V9C9Y4p3lX10AS75bnb3CiOSJQ3uRPSY7zrUYl3JZvx3TtZAwwM7BV(IoTA8QAnfIr56YapNDd0sl4Z75kw56lnfO1LIAkYY3YADHDfIQcrUk3sZ0h3AFuhNVySCMgmTAOfhS52QEMCZKCPvrbdrg7r9S0UI1sdfBZfVsWxzpNIwIW5vPBQCJ5cRDNIoEmMLXtnNMmI9iVIX9NOMtqMwbh(viUFzRV9qTKpSFYzfiSkSQJkyO6oEHuYU3aue1CjdUM1HM)4yUhzYSdjuqREXXD2uT7sRze7BTsRC1bowR2)uVSDuU(vI5qgnGc6y0hDIwXuFEOrgGn6OYgjcVqVo4E)yoTPzXCeh0uJekHQ50kYw8x2rV0R(lMTqn6u3k1FDqLEDSL7vNY(tRyp9cUgY8lmKCWq5EBbF(gXwUO5VLXMLzWQP4m4UhLMXmUOMzyYrV0akrQ)BVUR7jwLwEJ4kdI8DpBBQ2nw5UPTVLnL9ULPj35gs0ff9TAGE(Si4U9CRgtgYnuJlI4B1aj8MQrg346NaqHfKxGCfa7A)Pb0QrOCtbUpesN)KaCGBAkZNh05ZOqolTEuN)AoXd)4)JQwWs7BZz(O0ZV5(wUU1E3t(apXT1jv30)(3TVM8tRrd5SBzRHsxj)lqdjWz7mbD9BWRn)6SRA)igB3AI1SUc986bU68A2ikwsUFV6c0vLxAEd55N6zEv6zNZzEvxgN6WPpNJWvt7yoYwnJIlJYOQOEDYiciRf5RVqdoSplW(ELqz6qs1D5vU62RQjFKfWUNUr1c94BuspXJOzj5Lhn5)o
]] )
