--- @type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'clr'
class.classOrder = {'heal', 'assist', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox')
class.addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox')

--class.addSpell('heal', {'Healing Light', 'Superior Healing', 'Light Healing', 'Minor Healing'}, {me=70, mt=70, other=50})
class.addSpell('remedy', {'Supernal Remedy', 'Remedy'}, {regular=true, panic=true, pet=60})
class.addSpell('aura', {'Aura of Divinity'}, {aura=true})
class.addSpell('yaulp', {'Yaulp VI'}, {combat=true, ooc=false, opt='USEYAULP'})
class.addSpell('armor', {'Armor of the Zealot'})
class.addSpell('hammerpet', {'Unswerving Hammer of Justice'}, {opt='USEHAMMER'})
class.addSpell('groupheal', {'Word of Replenishment', 'Word of Redemption'}, {threshold=3, group=true, pct=70})
class.addSpell('hot', {'Holy Elixir'}, {opt='USEHOT', hot=true})
class.addSpell('aego', {'Hand of Conviction', 'Hand of Virtue'})
class.addSpell('di', {'Divine Intervention'})
--common.getAA('Celestial Regeneration')
--common.getAA('Divine Arbitration')

local standard = {}

class.spellRotations = {
    standard=standard
}

table.insert(class.DPSAbilities, class.spells.hammerpet)

table.insert(class.healAbilities, common.getAA('Burst of Life', {panic=true}))
table.insert(class.healAbilities, common.getItem('Weighted Hammer of Conviction', {regular=true, panic=true, pet=60}))
--table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, common.getAA('Divine Arbitration', {panic=true}))
table.insert(class.healAbilities, class.spells.groupheal)
table.insert(class.healAbilities, class.spells.remedy)
table.insert(class.healAbilities, class.spells.hot)

table.insert(class.burnAbilities, common.getAA('Celestial Rapidity'))
table.insert(class.burnAbilities, common.getAA('Celestial Regeneration'))
table.insert(class.burnAbilities, common.getAA('Exquisite Benediction'))
table.insert(class.burnAbilities, common.getAA('Flurry of Life'))
table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Divinity'))
table.insert(class.burnAbilities, common.getAA('Healing Frenzy'))
table.insert(class.burnAbilities, common.getAA('Improved Twincast'))

--table.insert(class.burnAbilities, common.getAA('Focused Celestial Regeneration'))

-- Project Lazarus only
local aaAura = common.getAA('Spirit Mastery', {checkfor='Aura of Pious Divinity'})
if aaAura then
    table.insert(class.auras, aaAura)
else
    table.insert(class.auras, class.spells.aura)
end
table.insert(class.selfBuffs, class.spells.yaulp)
table.insert(class.selfBuffs, class.spells.armor)

class.rezAbility = common.getAA('Blessing of Resurrection')

class.aego = class.spells.aego
class.requestAliases.aego = 'aego'
class.di = class.spells.di
class.requestAliases.di = 'di'

return class