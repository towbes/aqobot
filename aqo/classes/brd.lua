--- @type mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local mez = require('aqo.routines.mez')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local mode = require('aqo.mode')
local state = require('aqo.state')
local ui = require('aqo.ui')

local brd = {}

local SPELLSETS = {melee=1,caster=1,meleedot=1}
local EPIC_OPTS = {always=1,shm=1,burn=1,never=1}
local OPTS = {
    RALLYGROUP=false,
    USEFADE=false,
    MEZST=true,
    MEZAE=true,
    USEEPIC='always',
    BYOS=false,
}
config.set_spell_set('melee')
mq.cmd('/squelch /stick mod 0')

-- All spells ID + Rank name
local spells = {
    ['aura']=common.get_spellid_and_rank('Aura of Pli Xin Liako') or common.get_spellid_and_rank('Aura of Margidor') or common.get_spellid_and_rank('Aura of Begalru') or {name=nil,id=nil}, -- spell dmg, overhaste, flurry, triple atk
    ['composite']=common.get_spellid_and_rank('Composite Psalm') or common.get_spellid_and_rank('Dissident Psalm') or common.get_spellid_and_rank('Dichotomic Psalm') or {name=nil,id=nil}, -- DD+melee dmg bonus + small heal
    ['aria']=common.get_spellid_and_rank('Aria of Pli Xin Liako') or common.get_spellid_and_rank('Aria of Margidor') or {name=nil,id=nil}, -- spell dmg, overhaste, flurry, triple atk
    ['warmarch']=common.get_spellid_and_rank('War March of Centien Xi Va Xakra') or common.get_spellid_and_rank('War March of Radiwol') or {name=nil,id=nil}, -- haste, atk, ds
    ['arcane']=common.get_spellid_and_rank('Arcane Harmony') or common.get_spellid_and_rank('Arcane Symphony') or common.get_spellid_and_rank('Arcane Ballad') or {name=nil,id=nil}, -- spell dmg proc
    ['suffering']=common.get_spellid_and_rank('Shojralen\'s Song of Suffering') or common.get_spellid_and_rank('Omorden\'s Song of Suffering') or {name=nil,id=nil}, -- melee dmg proc
    ['spiteful']=common.get_spellid_and_rank('Von Deek\'s Spiteful Lyric') or common.get_spellid_and_rank('Omorden\'s Spiteful Lyric') or common.get_spellid_and_rank('Kaficus\' Spiteful Lyric') or {name=nil,id=nil}, -- AC
    ['pulse']=common.get_spellid_and_rank('Pulse of Nikolas') or common.get_spellid_and_rank('Pulse of Vhal`Sera') or {name=nil,id=nil}, -- heal focus + regen
    ['sonata']=common.get_spellid_and_rank('Xetheg\'s Spry Sonata') or common.get_spellid_and_rank('Kellek\'s Spry Sonata') or {name=nil,id=nil}, -- spell shield, AC, dmg mitigation
    ['dirge']=common.get_spellid_and_rank('Dirge of the Restless') or {name=nil,id=nil},-- or common.get_spellid_and_rank('Dirge of the Restless'), -- spell+melee dmg mitigation
    ['firenukebuff']=common.get_spellid_and_rank('Constance\'s Aria') or common.get_spellid_and_rank('Sontalak\'s Aria') or {name=nil,id=nil}, -- inc fire DD
    ['firemagicdotbuff']=common.get_spellid_and_rank('Fyrthek Fior\'s Psalm of Potency') or common.get_spellid_and_rank('Velketor\'s Psalm of Potency') or {name=nil,id=nil}, -- inc fire+mag dot
    ['crescendo']=common.get_spellid_and_rank('Zelinstein\'s Lively Crescendo') or common.get_spellid_and_rank('Zburator\'s Lively Crescendo') or {name=nil,id=nil}, -- small heal hp, mana, end
    ['insult']=common.get_spellid_and_rank('Yelinak\'s Insult') or common.get_spellid_and_rank('Sathir\'s Insult') or {name=nil,id=nil}, -- synergy DD
    ['insult2']=common.get_spellid_and_rank('Sogran\'s Insult') or common.get_spellid_and_rank('Omorden\'s Insult') or {name=nil,id=nil}, -- synergy DD 2
    ['chantflame']=common.get_spellid_and_rank('Shak Dathor\'s Chant of Flame') or common.get_spellid_and_rank('Sontalak\'s Chant of Flame') or {name=nil,id=nil},
    ['chantfrost']=common.get_spellid_and_rank('Sylra Fris\' Chant of Frost') or common.get_spellid_and_rank('Yelinak\'s Chant of Frost') or {name=nil,id=nil},
    ['chantdisease']=common.get_spellid_and_rank('Coagulus\' Chant of Disease') or common.get_spellid_and_rank('Zlexak\'s Chant of Disease') or {name=nil,id=nil},
    ['chantpoison']=common.get_spellid_and_rank('Cruor\'s Chant of Poison') or common.get_spellid_and_rank('Malvus\'s Chant of Poison') or {name=nil,id=nil},
    ['alliance']=common.get_spellid_and_rank('Coalition of Sticks and Stones') or common.get_spellid_and_rank('Covenant of Sticks and Stones') or {name=nil,id=nil},
    ['mezst']=common.get_spellid_and_rank('Slumber of the Diabo') or common.get_spellid_and_rank('Slumber of Zburator') or {name=nil,id=nil},
    ['mezae']=common.get_spellid_and_rank('Wave of Nocturn') or common.get_spellid_and_rank('Wave of Sleep') or common.get_spellid_and_rank('Wave of Somnolence') or {name=nil,id=nil},
}
for name,spell in pairs(spells) do
    if spell['name'] then
        logger.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        logger.printf('[%s] Could not find spell!', name)
    end
end

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local melee = {}
table.insert(melee, spells['composite'])
table.insert(melee, spells['crescendo'])
table.insert(melee, spells['aria'])
table.insert(melee, spells['spiteful'])
table.insert(melee, spells['suffering'])
table.insert(melee, spells['warmarch'])
table.insert(melee, spells['pulse'])
table.insert(melee, spells['dirge'])
-- synergy
-- mezst
-- mezae

local caster = {}
table.insert(caster, spells['composite'])
table.insert(caster, spells['crescendo'])
table.insert(caster, spells['aria'])
table.insert(caster, spells['arcane'])
table.insert(caster, spells['firenukebuff'])
table.insert(caster, spells['suffering'])
table.insert(caster, spells['warmarch'])
table.insert(caster, spells['firemagicdotbuff'])
table.insert(caster, spells['pulse'])
table.insert(caster, spells['dirge'])
-- synergy
-- mezst
-- mezae

local meleedot = {}
table.insert(meleedot, spells['composite'])
table.insert(meleedot, spells['crescendo'])
table.insert(meleedot, spells['chantflame'])
table.insert(meleedot, spells['aria'])
table.insert(meleedot, spells['warmarch'])
table.insert(meleedot, spells['chantdisease'])
table.insert(meleedot, spells['suffering'])
table.insert(meleedot, spells['pulse'])
table.insert(meleedot, spells['dirge'])
table.insert(meleedot, spells['chantfrost'])
-- synergy
-- mezst
-- mezae

local songs = {
    ['melee']=melee,
    ['caster']=caster,
    ['meleedot']=meleedot,
}

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID())
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID())

-- entries in the AAs table are pairs of {aa name, aa id}
local burnAAs = {}
table.insert(burnAAs, common.get_aaid_and_name('Quick Time'))
table.insert(burnAAs, common.get_aaid_and_name('Funeral Dirge'))
table.insert(burnAAs, common.get_aaid_and_name('Spire of the Minstrels'))
table.insert(burnAAs, common.get_aaid_and_name('Bladed Song'))
table.insert(burnAAs, common.get_aaid_and_name('Dance of Blades'))
table.insert(burnAAs, common.get_aaid_and_name('Flurry of Notes'))
table.insert(burnAAs, common.get_aaid_and_name('Frenzied Kicks'))

--table.insert(burnAAs, common.get_aaid_and_name('Glyph of Destruction (115+)'))
--table.insert(burnAAs, common.get_aaid_and_name('Intensity of the Resolute'))

local burnDiscs = {}
table.insert(burnDiscs, common.get_discid_and_name('Thousand Blades'))
-- deftdance discipline

local mashAAs = {}
table.insert(mashAAs, common.get_aaid_and_name('Cacophony'))
table.insert(mashAAs, common.get_aaid_and_name('Boastful Bellow'))
table.insert(mashAAs, common.get_aaid_and_name('Lyrical Prankster'))
table.insert(mashAAs, common.get_aaid_and_name('Song of Stone'))
--table.insert(mashAAs, get_aaid_and_name('Vainglorious Shout'))

local mashAbilities = {}
table.insert(mashAbilities, 'Intimidation')
table.insert(mashAbilities, 'Kick')

local mashDiscs = {}
table.insert(mashDiscs, common.get_discid_and_name('Reflexive Rebuttal'))

local selos = common.get_aaid_and_name('Selo\'s Sonata')
-- Mana Recovery AAs
local rallyingsolo = common.get_aaid_and_name('Rallying Solo')
local rallyingcall = common.get_aaid_and_name('Rallying Call')
-- Mana Recovery items
--local item_feather = mq.TLO.FindItem('Unified Phoenix Feather')
--local item_horn = mq.TLO.FindItem('Miniature Horn of Unity') -- 10 minute CD
-- Agro
local fade = common.get_aaid_and_name('Fading Memories')
-- aa mez
local dirge = common.get_aaid_and_name('Dirge of the Sleepwalker')

local SETTINGS_FILE = ('%s/bardbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
brd.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.brd then return end
    if settings.brd.USESWARM ~= nil then OPTS.USESWARM = settings.brd.USESWARM end
    if settings.brd.RALLYGROUP ~= nil then OPTS.RALLYGROUP = settings.brd.RALLYGROUP end
    if settings.brd.USEFADE ~= nil then OPTS.USEFADE = settings.brd.USEFADE end
    if settings.brd.MEZST ~= nil then OPTS.MEZST = settings.brd.MEZST end
    if settings.brd.MEZAE ~= nil then OPTS.MEZAE = settings.brd.MEZAE end
    if settings.brd.USEEPIC ~= nil then OPTS.USEEPIC = settings.brd.USEEPIC end
    if settings.brd.BYOS ~= nil then OPTS.BYOS = settings.brd.BYOS end
end

brd.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), brd=OPTS})
end

local boastful_timer = timer:new(30)
local synergy_timer = timer:new(18)
local crescendo_timer = timer:new(50)
brd.reset_class_timers = function()
    boastful_timer:reset(0)
    synergy_timer:reset(0)
end

local function cast(spell_name, requires_target, requires_los)
    if not common.in_control() or (requires_los and not mq.TLO.Target.LineOfSight()) then return end
    if requires_target and mq.TLO.Target.ID() ~= state.get_assist_mob_id() then return end
    logger.printf('Casting \ar%s\ax', spell_name)
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    --mq.delay(200+mq.TLO.Spell(spell_name).MyCastTime(), function() return not mq.TLO.Me.Casting() end)
    mq.delay(3200, function() return not mq.TLO.Me.Casting() end)
    mq.cmd('/stopcast')
    if spell_name == spells['crescendo']['name'] then crescendo_timer:reset() end
end

local function cast_mez(spell_name)
    if not common.in_control() or not mq.TLO.Target.LineOfSight() then return end
    local mez_target_id = mq.TLO.Target.ID()
    logger.printf('Casting \ar%s\ax', spell_name)
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    assist.check_target(brd.reset_class_timers)
    if mq.TLO.Target.ID() ~= mez_target_id then
        mq.delay('1s')
        assist.attack()
    end
    --mq.delay(200+mq.TLO.Spell(spell_name).MyCastTime(), function() return not mq.TLO.Me.Casting() end)
    mq.delay(3200, function() return not mq.TLO.Me.Casting() end)
    mq.cmd('/stopcast')
end

local function check_mez()
    if OPTS.MEZAE then
        mez.do_ae(spells['mezae']['name'], cast)
    end
    if OPTS.MEZST then
        mez.do_single(spells['mezst']['name'], cast_mez)
    end
    assist.check_target(brd.reset_class_timers)
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    if config.get_use_alliance() then
        if mq.TLO.Spell(spells['alliance']['name']).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(spells['alliance']['name'])() and mq.TLO.Me.GemTimer(spells['alliance']['name'])() == 0  and not mq.TLO.Target.Buff(spells['alliance']['name'])() and mq.TLO.Spell(spells['alliance']['name']).StacksTarget() then
            cast(spells['alliance']['name'], true, true)
            return true
        end
    end
    return false
end

local function cast_synergy()
    if synergy_timer:timer_expired() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(spells['insult']['name'])() and mq.TLO.Me.GemTimer(spells['insult']['name'])() == 0 then
            if mq.TLO.Spell(spells['insult']['name']).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            cast(spells['insult']['name'], true, true)
            synergy_timer:reset()
            return true
        end
    end
    return false
end

local function is_dot_ready(spellId, spellName)
    local songDuration = 0
    --local remainingCastTime = 0
    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() ~= 0  then
        return false
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= state.get_assist_mob_id() or mq.TLO.Target.Type() == 'Corpse' then return false end

    songDuration = mq.TLO.Target.MyBuffDuration(spellName)()
    if not common.is_target_dotted_with(spellId, spellName) then
        -- target does not have the dot, we are ready
        logger.debug(state.get_debug(), 'song ready %s', spellName)
        return true
    else
        if not songDuration then
            logger.debug(state.get_debug(), 'song ready %s', spellName)
            return true
        end
    end

    return false
end

local function is_song_ready(spellId, spellName)
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < state.get_min_mana()) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.get_min_end()) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        return is_dot_ready(spellId, spellName)
    end

    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() > 0 then
        return false
    end
    if spellName == spells['crescendo']['name'] and (mq.TLO.Me.Buff(spells['crescendo']['name'])() or not crescendo_timer:timer_expired()) then
        -- buggy song that doesn't like to go on CD
        return false
    end

    local songDuration = mq.TLO.Me.Song(spellName).Duration()
    if not songDuration then
        logger.debug(state.get_debug(), 'song ready %s', spellName)
        return true
    else
        local cast_time = mq.TLO.Spell(spellName).MyCastTime()
        if songDuration < cast_time + 3000 then
            logger.debug(state.get_debug(), 'song ready %s', spellName)
        end
        return songDuration < cast_time + 3000
    end
end

local function find_next_song()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    for _,song in ipairs(songs[config.get_spell_set()]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local spell_id = song['id']
        local spell_name = song['name']
        if is_song_ready(spell_id, spell_name) then
            if spell_name ~= 'Composite Psalm' or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local function cycle_songs()
    if not mq.TLO.Me.Invis() then
        local spell = find_next_song() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            if mq.TLO.Spell(spell['name']).TargetType() == 'Single' and mq.TLO.Me.CombatState() == 'COMBAT' then
                cast(spell['name'], true, true) -- then cast the dot
            else
                cast(spell['name']) -- then cast the dot
            end
            return true
        end
    end
    return false
end

local fierceeye = common.get_aaid_and_name('Fierce Eye')
local function use_epic()
    local epic = mq.TLO.FindItem('=Blade of Vesagran')
    local fierceeye_rdy = mq.TLO.Me.AltAbilityReady(fierceeye['name'])()
    if epic.Timer() == '0' and fierceeye_rdy then
        common.use_aa(fierceeye)
        common.use_item(epic)
    end
end

local function mash()
    local cur_mode = config.get_mode()
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.CombatState() == 'COMBAT') then
    --if common.is_fighting() or assist.should_assist() then
        if OPTS.USEEPIC == 'always' then
            use_epic()
        elseif OPTS.USEEPIC == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')() then
            use_epic()
        end
        for _,aa in ipairs(mashAAs) do
            if aa ~= 'Boastful Bellow' or boastful_timer:timer_expired() then
                if common.use_aa(aa) and aa == 'Boastful Bellow' then
                    boastful_timer:reset()
                end
            end
        end
        for _,disc in ipairs(mashDiscs) do
            common.use_disc(disc)
        end
        for _,ability in ipairs(mashAbilities) do
            common.use_ability(ability)
        end
    end
end

local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met() then

        if OPTS.USEEPIC == 'burn' then
            use_epic()
        end

        --[[
        |===========================================================================================
        |Item Burn
        |===========================================================================================
        ]]--

        for _,item_id in ipairs(items) do
            local item = mq.TLO.FindItem(item_id)
            common.use_item(item)
        end

        --[[
        |===========================================================================================
        |Spell Burn
        |===========================================================================================
        ]]--

        for _,aa in ipairs(burnAAs) do
            common.use_aa(aa)
        end

        --[[
        |===========================================================================================
        |Disc Burn
        |===========================================================================================
        ]]--
        for _,disc in ipairs(burnDiscs) do
            common.use_disc(disc)
        end
    end
end

local function check_mana()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    local pct_end = mq.TLO.Me.PctEndurance()
    --if not common.is_fighting() and (pct_mana < 20 or pct_end < 20) then
    if mq.TLO.Me.CombatState() ~= 'COMBAT' and (pct_mana < 20 or pct_end < 20) then
        -- death bloom at some %
        common.use_aa(rallyingsolo)
    end
end

local check_aggro_timer = timer:new(5)
local function check_aggro()
    if config.get_mode():get_name() ~= 'manual' and OPTS.USEFADE and state.get_mob_count() > 0 and check_aggro_timer:timer_expired() then
        if (mq.TLO.Target() and mq.TLO.Me.PctAggro() >= 70) or mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or mq.TLO.Me.PctHPs() < 50 then
            common.use_aa(fade)
            check_aggro_timer:reset()
            mq.delay('1s')
            mq.cmd('/makemevis')
        end
    end
end

local function check_buffs()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    --if common.is_fighting() then return end
    if not common.clear_to_buff() then return end
    --if mq.TLO.SpawnCount(string.format('xtarhater radius %d zradius 50', config.get_camp_radius()))() > 0 then return end
    if not mq.TLO.Me.Aura(spells['aura']['name'])() then
        local restore_gem = nil
        if not mq.TLO.Me.Gem(spells['aura']['name'])() then
            restore_gem = mq.TLO.Me.Gem(1)()
            common.swap_spell(spells['aura']['name'], 1)
        end
        mq.delay('3s', function() return mq.TLO.Me.Gem(spells['aura']['name'])() and mq.TLO.Me.GemTimer(spells['aura']['name'])() == 0  end)
        cast(spells['aura']['name'])
        if restore_gem then
            common.swap_spell(restore_gem, 1)
        end
    end

    common.check_item_buffs()
end

local function pause_for_rally()
    if mq.TLO.Me.Song(rallyingsolo['name'])() or mq.TLO.Me.Buff(rallyingsolo['name'])() then
        if state.get_mob_count() >= 3 then
            return true
        elseif mq.TLO.Target() and mq.TLO.Target.Named() then
            return true
        else
            return false
        end
    else
        return false
    end
end

local check_spell_timer = timer:new(30)
local function check_spell_set()
    --if common.is_fighting() or mq.TLO.Me.Moving() or common.am_i_dead() or OPTS.BYOS then return end
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or OPTS.BYOS then return end
    if state.get_spellset_loaded() ~= config.get_spell_set() or check_spell_timer:timer_expired() then
        if config.get_spell_set() == 'melee' then
            if mq.TLO.Me.Gem(1)() ~= spells['aria']['name'] then common.swap_spell(spells['aria']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['arcane']['name'] then common.swap_spell(spells['arcane']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= spells['spiteful']['name'] then common.swap_spell(spells['spiteful']['name'], 3) end
            if mq.TLO.Me.Gem(4)() ~= spells['suffering']['name'] then common.swap_spell(spells['suffering']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['insult']['name'] then common.swap_spell(spells['insult']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['warmarch']['name'] then common.swap_spell(spells['warmarch']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['sonata']['name'] then common.swap_spell(spells['sonata']['name'], 7) end
            if mq.TLO.Me.Gem(8)() ~= spells['mezst']['name'] then common.swap_spell(spells['mezst']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['mezae']['name'] then common.swap_spell(spells['mezae']['name'], 9) end
            if mq.TLO.Me.Gem(10)() ~= spells['crescendo']['name'] then common.swap_spell(spells['crescendo']['name'], 10) end
            if mq.TLO.Me.Gem(11)() ~= spells['pulse']['name'] then common.swap_spell(spells['pulse']['name'], 11) end
            if not mq.TLO.Me.Gem(12)() or (mq.TLO.Me.Gem(12)() ~= 'Composite Psalm' and mq.TLO.Me.Gem(12)() ~= 'Dissident Psalm' and mq.TLO.Me.Gem(12)() ~= 'Dichotomic Psalm') then common.swap_spell(spells['composite']['name'], 12) end
            if mq.TLO.Me.Gem(13)() ~= spells['dirge']['name'] then common.swap_spell(spells['dirge']['name'], 13) end
            state.set_spellset_loaded(config.get_spell_set())
        elseif config.get_spell_set() == 'caster' then
            if mq.TLO.Me.Gem(1)() ~= spells['aria']['name'] then common.swap_spell(spells['aria']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['arcane']['name'] then common.swap_spell(spells['arcane']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= spells['firenukebuff']['name'] then common.swap_spell(spells['firenukebuff']['name'], 3) end
            if mq.TLO.Me.Gem(4)() ~= spells['suffering']['name'] then common.swap_spell(spells['suffering']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['insult']['name'] then common.swap_spell(spells['insult']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['warmarch']['name'] then common.swap_spell(spells['warmarch']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['firemagicdotbuff']['name'] then common.swap_spell(spells['firemagicdotbuff']['name'], 7) end
            if mq.TLO.Me.Gem(8)() ~= spells['mezst']['name'] then common.swap_spell(spells['mezst']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['mezae']['name'] then common.swap_spell(spells['mezae']['name'], 9) end
            if mq.TLO.Me.Gem(10)() ~= spells['crescendo']['name'] then common.swap_spell(spells['crescendo']['name'], 10) end
            if mq.TLO.Me.Gem(11)() ~= spells['pulse']['name'] then common.swap_spell(spells['pulse']['name'], 11) end
            if not mq.TLO.Me.Gem(12)() or (mq.TLO.Me.Gem(12)() ~= 'Composite Psalm' and mq.TLO.Me.Gem(12)() ~= 'Dissident Psalm' and mq.TLO.Me.Gem(12)() ~= 'Dichotomic Psalm') then common.swap_spell(spells['composite']['name'], 12) end
            if mq.TLO.Me.Gem(13)() ~= spells['dirge']['name'] then common.swap_spell(spells['dirge']['name'], 13) end
            state.set_spellset_loaded(config.get_spell_set())
        elseif config.get_spell_set() == 'meleedot' then
            if mq.TLO.Me.Gem(1)() ~= spells['aria']['name'] then common.swap_spell(spells['aria']['name'], 1) end
            if mq.TLO.Me.Gem(2)() ~= spells['chantflame']['name'] then common.swap_spell(spells['chantflame']['name'], 2) end
            if mq.TLO.Me.Gem(3)() ~= spells['chantfrost']['name'] then common.swap_spell(spells['chantfrost']['name'], 3) end
            if mq.TLO.Me.Gem(4)() ~= spells['suffering']['name'] then common.swap_spell(spells['suffering']['name'], 4) end
            if mq.TLO.Me.Gem(5)() ~= spells['insult']['name'] then common.swap_spell(spells['insult']['name'], 5) end
            if mq.TLO.Me.Gem(6)() ~= spells['warmarch']['name'] then common.swap_spell(spells['warmarch']['name'], 6) end
            if mq.TLO.Me.Gem(7)() ~= spells['chantdisease']['name'] then common.swap_spell(spells['chantdisease']['name'], 7) end
            if mq.TLO.Me.Gem(8)() ~= spells['mezst']['name'] then common.swap_spell(spells['mezst']['name'], 8) end
            if mq.TLO.Me.Gem(9)() ~= spells['mezae']['name'] then common.swap_spell(spells['mezae']['name'], 9) end
            if mq.TLO.Me.Gem(10)() ~= spells['crescendo']['name'] then common.swap_spell(spells['crescendo']['name'], 10) end
            if mq.TLO.Me.Gem(11)() ~= spells['pulse']['name'] then common.swap_spell(spells['pulse']['name'], 11) end
            if not mq.TLO.Me.Gem(12)() or (mq.TLO.Me.Gem(12)() ~= 'Composite Psalm' and mq.TLO.Me.Gem(12)() ~= 'Dissident Psalm' and mq.TLO.Me.Gem(12)() ~= 'Dichotomic Psalm') then common.swap_spell(spells['composite']['name'], 12) end
            if mq.TLO.Me.Gem(13)() ~= spells['dirge']['name'] then common.swap_spell(spells['dirge']['name'], 13) end
            state.set_spellset_loaded(config.get_spell_set())
        end
        check_spell_timer:reset()
    end
end

brd.setup_events = function()
    mez.setup_events()
end

brd.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'USEEPIC' then
            if EPIC_OPTS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                OPTS[opt] = new_value
            end
        elseif opt == 'SPELLSET' then
            if SPELLSETS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                config.set_spell_set(new_value)
            end
        elseif type(OPTS[opt]) == 'boolean' then
            if common.BOOL.FALSE[new_value] then
                logger.printf('Setting %s to: false', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = false end
            elseif common.BOOL.TRUE[new_value] then
                logger.printf('Setting %s to: true', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = true end
            end
        elseif type(OPTS[opt]) == 'number' then
            if tonumber(new_value) then
                logger.printf('Setting %s to: %s', opt, tonumber(new_value))
                if OPTS[opt] ~= nil then OPTS[opt] = tonumber(new_value) end
            end
        else
            logger.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), OPTS[opt])
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

local selos_timer = timer:new(30)
brd.main_loop = function()
    -- keep cursor clear for spell swaps and such
    if selos_timer:timer_expired() then
        common.use_aa(selos)
        selos_timer:reset()
    end
    -- ensure correct spells are loaded based on selected spell set
    check_spell_set()
    -- check whether we need to return to camp
    camp.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    assist.check_target(brd.reset_class_timers)
    -- check our surroundings for mobs to deal with
    camp.mob_radar()
    if not pause_for_rally() then
        -- check we have the correct target to attack
        check_mez()
        -- if we should be assisting but aren't in los, try to be?
        assist.attack()
        -- begin actual combat stuff
        assist.send_pet()
        if mq.TLO.Me.CombatState() ~= 'ACTIVE' and mq.TLO.Me.CombatState() ~= 'RESTING' then
            cycle_songs()
        end
        mash()
        -- pop a bunch of burn stuff if burn conditions are met
        try_burn()
        -- try not to run OOM
        check_aggro()
    end
    check_mana()
    check_buffs()
    common.rest()
    mq.delay(1)
end

brd.draw_skills_tab = function()
    config.set_spell_set(ui.draw_combo_box('Spell Set', config.get_spell_set(), SPELLSETS, true))
    OPTS.USEEPIC = ui.draw_combo_box('Epic', OPTS.USEEPIC, EPIC_OPTS, true)
    config.set_use_alliance(ui.draw_check_box('Alliance', '##alliance', config.get_use_alliance(), 'Use alliance spell'))
    OPTS.RALLYGROUP = ui.draw_check_box('Rallying Group', '##rallygroup', OPTS.RALLYGROUP, 'Use Rallying Group AA')
    OPTS.MEZST = ui.draw_check_box('Mez ST', '##mezst', OPTS.MEZST, 'Mez single target')
    OPTS.MEZAE = ui.draw_check_box('Mez AE', '##mezae', OPTS.MEZAE, 'Mez AOE')
    OPTS.USEFADE = ui.draw_check_box('Use Fade', '##usefade', OPTS.USEFADE, 'Fade when agro')
    OPTS.BYOS = ui.draw_check_box('BYOS', '##byos', OPTS.BYOS, 'Bring your own spells')
end

brd.draw_burn_tab = function()
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
end

return brd