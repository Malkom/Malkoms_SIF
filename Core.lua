local addonName, ns = ...

local _G = _G
local ipairs = ipairs

ns.addonName = addonName

-- Localization
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L
if GetLocale() == "frFR" then
	L["All classes"] = "Toutes les classes"
	L["Class"] = "Classe"
end

--------------------------------------------------------------------------------
-- Iconic spell IDs per class. Their icons are resolved at runtime with
-- C_Spell.GetSpellTexture, so any invalid/outdated ID is simply skipped.
--------------------------------------------------------------------------------

ns.classSpells = {
	WARRIOR = {
		100, 78, 12294, 227847, 23922, 5308, 1680, 6673, 871, 12975, 23920,
		6552, 772, 6343, 18499, 1719, 355, 34428, 1464, 7384, 6572, 5246,
		1160, 107574, 190456, 228920, 18499, 46924,
	},
	PALADIN = {
		35395, 20271, 26573, 24275, 642, 633, 1022, 853, 31884, 82326, 19750,
		85673, 53385, 85256, 53600, 1044, 4987, 53563, 20473, 85222, 6940,
		190784, 255937, 96231, 24239, 62124,
	},
	HUNTER = {
		19434, 185358, 56641, 2643, 257044, 34026, 53351, 19574, 186257, 186265,
		781, 5384, 187650, 212431, 120360, 288613, 34477, 257284, 5116, 136,
		883, 195645, 271788, 193455, 187698,
	},
	ROGUE = {
		1752, 196819, 53, 8676, 408, 315496, 1856, 1784, 2983, 1766, 2094, 6770,
		36554, 1833, 703, 1943, 51723, 13877, 13750, 185313, 5277, 921, 185311,
		32645, 2098,
	},
	PRIEST = {
		585, 589, 8092, 32379, 15407, 34914, 232698, 17, 2060, 2061, 139, 596,
		2050, 132157, 47585, 586, 21562, 32375, 110744, 47540, 186263, 605,
		8122, 47788, 33076,
	},
	DEATHKNIGHT = {
		49998, 47541, 43265, 49143, 49020, 49184, 85948, 55090, 206930, 195182,
		49576, 48707, 48792, 42650, 46584, 47528, 45524, 55233, 49028, 51271,
		275699, 47568, 212552, 43265,
	},
	SHAMAN = {
		188196, 188443, 51505, 188389, 8042, 17364, 60103, 77472, 8004, 1064,
		61295, 974, 2825, 32182, 51514, 57994, 2645, 108271, 51533, 198067,
		198103, 370, 196840, 73920, 192058,
	},
	MAGE = {
		116, 133, 30451, 5143, 108853, 30455, 11366, 1953, 122, 45438, 118,
		2139, 190356, 2120, 1449, 190319, 12472, 12042, 12051, 30449, 55342,
		31661, 44457, 80353, 190336,
	},
	WARLOCK = {
		686, 29722, 116858, 348, 172, 980, 316099, 48181, 324536, 234153, 5782,
		688, 697, 691, 712, 755, 48018, 105174, 264178, 5740, 702, 710, 20707,
		6201, 111771,
		-- talents / signature abilities
		104316, 265187, 264119, 111898, 267171, 267211, 196277, 267217, 30146,
		205180, 264057, 152108, 63106, 205179, 6789, 5484, 17962, 333889, 278350,
	},
	MONK = {
		100780, 100784, 107428, 101546, 113656, 116670, 115151, 124682, 115175,
		109132, 115098, 322109, 119381, 115078, 115203, 115176, 121253, 115181,
		322507, 322101, 137639, 101643, 115546, 218164,
	},
	DRUID = {
		190984, 194153, 78674, 8921, 93402, 33917, 5221, 1079, 1822, 22568,
		106832, 213771, 8936, 774, 48438, 33763, 18562, 102351, 102342, 22812,
		61336, 5487, 768, 783, 24858, 339, 33786, 29166, 20484, 106898, 132469,
		78675,
	},
	DEMONHUNTER = {
		162243, 162794, 188499, 198013, 195072, 198793, 191427, 258920, 185123,
		203782, 228477, 263642, 247454, 203720, 204021, 204596, 189110, 278326,
		183752, 370965, 188501, 179057, 232893,
	},
	EVOKER = {
		361469, 357208, 362969, 356995, 359073, 357211, 355936, 367226, 355913,
		360995, 366155, 364343, 357210, 358267, 370665, 358385, 368970, 357214,
		363916, 374348, 374968, 364342, 374251, 372048,
	},
}

--------------------------------------------------------------------------------
-- Runtime helpers
--------------------------------------------------------------------------------

local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or _G.GetSpellTexture

-- Ordered list of {name, file} for the class dropdown.
function ns.GetClassList()
	local list = {}
	for i = 1, GetNumClasses() do
		local name, file = GetClassInfo(i)
		if name and file then
			list[#list + 1] = { name = name, file = file }
		end
	end
	return list
end

-- Gather ALL spell + talent icons for the PLAYER'S OWN class at runtime.
-- Only the player's class exposes this data (spellbook + active talent config).
function ns.GatherPlayerClassIcons()
	local icons, seen = {}, {}
	local function add(tex)
		if tex and not seen[tex] then
			seen[tex] = true
			icons[#icons + 1] = tex
		end
	end

	-- 1) Spellbook (known spells across all skill lines)
	pcall(function()
		if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
		local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if info and info.numSpellBookItems then
				for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
					add(C_SpellBook.GetSpellBookItemTexture(i, bank))
				end
			end
		end
	end)

	-- 2) Talent tree (all nodes/entries, chosen or not) for the active config
	pcall(function()
		if not (C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID) then return end
		local configID = C_ClassTalents.GetActiveConfigID()
		if not configID then return end
		local cfg = C_Traits.GetConfigInfo(configID)
		if not (cfg and cfg.treeIDs) then return end
		for _, treeID in ipairs(cfg.treeIDs) do
			for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
				local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
				if nodeInfo and nodeInfo.entryIDs then
					for _, entryID in ipairs(nodeInfo.entryIDs) do
						local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
						if entryInfo and entryInfo.definitionID then
							local def = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
							if def then
								local tex = def.overrideIcon
								if not tex and def.spellID and GetSpellTexture then
									tex = GetSpellTexture(def.spellID)
								end
								add(tex)
							end
						end
					end
				end
			end
		end
	end)

	return icons
end

-- Build the de-duplicated list of icon fileIDs for a class (cached).
-- Bundled spell icons for every class + full dynamic gathering for the player's own.
ns.iconCache = {}
function ns.BuildClassIconList(classFile)
	if ns.iconCache[classFile] then return ns.iconCache[classFile] end
	local seen, list = {}, {}
	local function add(tex)
		if tex and not seen[tex] then
			seen[tex] = true
			list[#list + 1] = tex
		end
	end

	for _, spellID in ipairs(ns.classSpells[classFile] or {}) do
		add(GetSpellTexture and GetSpellTexture(spellID))
	end

	local _, myClass = UnitClass("player")
	if classFile == myClass then
		local ok, dyn = pcall(ns.GatherPlayerClassIcons)
		if ok and dyn then
			for _, tex in ipairs(dyn) do add(tex) end
		end
	end

	ns.iconCache[classFile] = list
	return list
end
