------------------------------------------------------------------------------
-- GridStatusTankCooldown by Slaren
------------------------------------------------------------------------------
GridStatusTankCooldown = Grid:GetModule("GridStatus"):NewModule("GridStatusTankCooldown")
GridStatusTankCooldown.menuName = "Tanking cooldowns"

local tankingbuffs = {
	["DEATHKNIGHT"] = {
		48707, -- Anti-Magic Shell
		77535, -- Blood Shield
		49222, -- Bone Shield
		49028, -- Dancing Rune Weapon
		48792, -- Icebound Fortitude
		55233, -- Vampiric Blood
		114556, -- Purgatory
		194679, -- Rune Tap
	},
	["DEMONHUNTER"] = {
		198589, -- Blur
		196718, -- Darkness
		196555, -- Netherwalk
	},	
	["DRUID"] = {
		22812,  -- Barkskin
		102342, -- Ironbark
		61336,  -- Survival Instincts
	},
	["HUNTER"] = {
		199483, -- Camouflage
		186265, -- Aspect of Turtle
		109304, -- Exhilaration
	},
	["MAGE"] = {
		11426,  -- Ice Barrier
		45438,  -- Ice Block
		113862, -- Greater Invisibility
		66, 	-- Invisibility
	},
	["MONK"] = {
		115203, -- Fortifying Brew
		116849, -- Life Cocoon
		115176, -- Zen Meditation
		122470, -- Touch of Karma
	},
	["PALADIN"] = {
		31850,  --  Ardent Defender
		31821,  --  Aura Mastery
		498,    --  Divine Protection
		642,    --  Divine Shield
		86659,  --  Guardian of Ancient Kings
		1022,   --  Hand of Protection
		6940,   --  Blessing of Sacrifice
		204018, --  Blessing of Spellwarding
		209202, --  Eye of Tyr
		160387, --  Shield of Vengeance
	},
	["PRIEST"] = {
		47585,  -- Dispersion
		47788,  -- Guardian Spirit
		33206,  -- Pain Suppression
		81782,  -- Power Word: Barrier
		15286,  -- Vampiric Embrace
	},
	["ROGUE"] = {
		31224,  --  Cloak of Shadows
		5277,   --  Evasion
		1966,   --  Feint
		185311, -- Crimson Vial
		199754, -- Riposte
	},
	["SHAMAN"] = {
		108271, -- Astral Shift
		30823,  -- Shamanistic Rage
		98008,  -- Spirit Link Totem
		198938, -- Earthen Shield Totem
		207399, -- Ancestral Protection Totem
	},
	"WARLOCK"] = {
		108416, -- Dark Pact
		104773, -- Unending Resolve
	},
	["WARRIOR"] = {
		97462,  -- Commanding Shout
		118038, -- Die by the Sword
		184364, -- Enraged Regeneration
		190456, -- Ignore Pain
		198304, -- Intercept
		12975,  -- Last Stand
		203526, -- Neltharion's Fury (Artifact)
		2565,   -- Shield Block
		871,    -- Shield Wall
		23920,  -- Spell Reflection
	}
}

GridStatusTankCooldown.tankingbuffs = tankingbuffs

-- locals
local GridRoster = Grid:GetModule("GridRoster")
local GetSpellInfo = GetSpellInfo
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID

local settings
local spellnames = {}

GridStatusTankCooldown.defaultDB = {
	debug = false,
	alert_tankcd = {
		enable = true,
		color = { r = 1, g = 1, b = 0, a = 1 },
		priority = 99,
		range = false,
		showtextas = "caster",
		active_spellids =  { -- default spells
			31850,	-- Ardent Defender
			86659,	-- Guardian of Ancient Kings
			47788,	-- Guardian Spirit
			6940, 	-- Hand of Sacrifice
			48792, 	-- Icebound Fortitude
			33206,	-- Pain Suppression
			871,	-- Shield Wall
			61336,	-- Survival Instincts
			115203, -- Fortifying Brew
		},
		inactive_spellids = { -- used to remember priority of disabled spells
		}
	}
}

local myoptions = {
	["gstcd_header_1"] = {
		type = "header",
		order = 200,
		name = "Options",
	},
	["showtextas"] = {
		order = 201,
		type = "select",
		name = "Show text as",
		desc = "Text to show when assigned to an indicator capable of displaying text",
		values = { ["caster"] = "Caster name", ["spell"] = "Spell name" },
		style = "radio",
		get = function() return GridStatusTankCooldown.db.profile.alert_tankcd.showtextas end,
		set = function(_, v) GridStatusTankCooldown.db.profile.alert_tankcd.showtextas = v end,
	},
	["gstcd_header_2"] = {
		type = "header",
		order = 203,
		name = "Spells",
	},
	["spells_description"] = {
		type = "description",
		order = 204,
		name = "Check the spells that you want GridStatusTankCooldown to keep track of. Their position on the list defines their priority in the case that a unit has more than one of them.",
	},
	["spells"] = {
		type = "input",
		order = 205,
		name = "Spells",
		control = "GSTCD-SpellsConfig",
	},
}

function GridStatusTankCooldown:OnInitialize()
	self.super.OnInitialize(self)

	for class, buffs in pairs(tankingbuffs) do
		for _, spellid in pairs(buffs) do
			local sname = GetSpellInfo(spellid)
			if not sname then print(spellid, ": Bad spellid") end
			spellnames[spellid] = sname or tostring(spellid)
		end
	end

	self:RegisterStatus("alert_tankcd", "Tanking cooldowns", myoptions, true)

	settings = self.db.profile.alert_tankcd

	-- delete old format settings
	if settings.spellids then
		settings.spellids = nil
	end

	-- remove old spellids
	for p, aspellid in ipairs(settings.active_spellids) do
		local found = false
		for class, buffs in pairs(tankingbuffs) do
			for _, spellid in pairs(buffs) do
				if spellid == aspellid then
					found = true
					break
				end
			end
		end

		if not found then
			table.remove(settings.active_spellids, p)
		end

		-- remove duplicates
		for i = #settings.active_spellids, p + 1, -1 do
			if settings.active_spellids[i] == aspellid then
				table.remove(settings.active_spellids, i)
			end
		end
	end
end

function GridStatusTankCooldown:OnStatusEnable(status)
	if status == "alert_tankcd" then
		self:RegisterEvent("UNIT_AURA", "ScanUnit")
		self:RegisterEvent("Grid_UnitJoined")
		-- self:ScheduleRepeatingEvent("GridStatusTankCooldown:UpdateAllUnits", self.UpdateAllUnits, 0.5, self)
		self:UpdateAllUnits()
	end
end

function GridStatusTankCooldown:OnStatusDisable(status)
	if status == "alert_tankcd" then
		self:UnregisterEvent("UNIT_AURA")
		self:UnregisterEvent("Grid_UnitJoined")

		--self:CancelScheduledEvent("GridStatusTankCooldown:UpdateAllUnits")
		self.core:SendStatusLostAllUnits("alert_tankcd")
	end
end

function GridStatusTankCooldown:Grid_UnitJoined(guid, unitid)
	self:ScanUnit("Grid_UnitJoined", unitid, guid)
end

function GridStatusTankCooldown:UpdateAllUnits()
	for guid, unitid in GridRoster:IterateRoster() do
		self:ScanUnit("UpdateAllUnits", unitid, guid)
	end
end

function GridStatusTankCooldown:ScanUnit(event, unitid, unitguid)
	unitguid = unitguid or UnitGUID(unitid)
	if not GridRoster:IsGUIDInRaid(unitguid) then
		return
	end

	for _, spellid in ipairs(settings.active_spellids) do
		local name, _, icon, count, _, duration, expirationTime, caster = UnitBuff(unitid, spellnames[spellid])

		-- Used to check for debuffs when Argent Defender was a debuff - it is not necessary anymore
		--[[
		if not name then
			name, _, icon, count, _, duration, expirationTime, caster = UnitDebuff(unitid, spellnames[spellid])
		end
		]]

		if name then
			local text
			if settings.showtextas == "caster" then
				if caster then
					text = UnitName(caster)
				end
			else
				text = name
			end

			self.core:SendStatusGained(unitguid,
						"alert_tankcd",
						settings.priority,
						(settings.range and 40),
						settings.color,
						text,
						0,							-- value
						nil,						-- maxValue
						icon,						-- icon
						expirationTime - duration,	-- start
						duration,					-- duration
						count)						-- stack
			return
		end
	end

	self.core:SendStatusLost(unitguid, "alert_tankcd")
end
