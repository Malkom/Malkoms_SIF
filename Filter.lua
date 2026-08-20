local addonName, ns = ...
local L = ns.L

local _G = _G
local ipairs = ipairs
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

ns.active = false          -- class filter engaged
ns.selectedClass = nil     -- classFile or nil (all)
ns.list = nil              -- current class icon fileID list

local classDropdown

-- Optional ElvUI skinning
local E = _G.ElvUI and _G.ElvUI[1]
local S = E and E.GetModule and E:GetModule("Skins", true)

local function SkinDropdown(dd, native)
	if not S or not dd or dd.__msifSkinned then return end
	pcall(function()
		if native and S.HandleDropDownBox then
			S:HandleDropDownBox(dd, 150)
		elseif S.HandleButton then
			S:HandleButton(dd)
		end
	end)
	dd.__msifSkinned = true
end

--------------------------------------------------------------------------------
-- Apply / clear the class filter
--------------------------------------------------------------------------------

local function RefreshGrid(frame)
	if not (frame and frame.IconSelector) then return end
	if frame.IconSelector.UpdateSelections then
		frame.IconSelector:UpdateSelections()
	end
	if frame.ReevaluateSelectedIcon then
		frame:ReevaluateSelectedIcon()
	end
end

function ns.SetClass(classFile)
	ns.selectedClass = classFile
	if classFile then
		ns.active = true
		ns.list = ns.BuildClassIconList(classFile)
	else
		ns.active = false
		ns.list = nil
	end
	RefreshGrid(_G.GearManagerPopupFrame)
end

--------------------------------------------------------------------------------
-- Override the icon accessors so the grid shows our class list when active
--------------------------------------------------------------------------------

local function InstallOverrides(frame)
	frame.GetNumIcons = function(self)
		if ns.active and ns.list then return #ns.list end
		return (self.iconDataProvider and self.iconDataProvider:GetNumIcons()) or 0
	end
	frame.GetIconByIndex = function(self, index)
		if ns.active and ns.list then return ns.list[index] end
		return self.iconDataProvider and self.iconDataProvider:GetIconByIndex(index) or nil
	end
	frame.GetIndexOfIcon = function(self, icon)
		if ns.active and ns.list then
			for i, v in ipairs(ns.list) do
				if v == icon then return i end
			end
			return nil
		end
		return self.iconDataProvider and self.iconDataProvider:GetIndexOfIcon(icon) or nil
	end
end

--------------------------------------------------------------------------------
-- Class dropdown
--------------------------------------------------------------------------------

local function BuildMenu(_, rootDescription)
	rootDescription:CreateRadio(L["All classes"],
		function() return ns.selectedClass == nil end,
		function() ns.SetClass(nil); if classDropdown.GenerateMenu then classDropdown:GenerateMenu() end end)

	for _, c in ipairs(ns.GetClassList()) do
		local color = C_ClassColor and C_ClassColor.GetClassColor(c.file)
		local text = color and color:WrapTextInColorCode(c.name) or c.name
		rootDescription:CreateRadio(text,
			function() return ns.selectedClass == c.file end,
			function() ns.SetClass(c.file); if classDropdown.GenerateMenu then classDropdown:GenerateMenu() end end)
	end
end

local function CreateClassDropdown(frame)
	local anchor = frame.BorderBox and frame.BorderBox.IconTypeDropdown
	local parent = frame.BorderBox or frame

	local ok = pcall(function()
		classDropdown = CreateFrame("DropdownButton", "MalkomsSIFClassDropdown", parent, "WowStyle1DropdownTemplate")
	end)

	if ok and classDropdown and classDropdown.SetupMenu then
		classDropdown:SetWidth(150)
		if anchor then
			classDropdown:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
		else
			classDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -12)
		end
		classDropdown:SetupMenu(BuildMenu)
		SkinDropdown(classDropdown, true)
		return
	end

	-- Fallback: a plain button + MenuUtil context menu
	classDropdown = CreateFrame("Button", "MalkomsSIFClassDropdown", parent, "UIPanelButtonTemplate")
	classDropdown:SetSize(150, 22)
	if anchor then
		classDropdown:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
	else
		classDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -12)
	end
	local function currentText()
		if not ns.selectedClass then return L["All classes"] end
		for _, c in ipairs(ns.GetClassList()) do
			if c.file == ns.selectedClass then
				local color = C_ClassColor and C_ClassColor.GetClassColor(c.file)
				return color and color:WrapTextInColorCode(c.name) or c.name
			end
		end
		return L["Class"]
	end
	classDropdown:SetText(currentText())
	classDropdown.GenerateMenu = function() classDropdown:SetText(currentText()) end
	classDropdown:SetScript("OnClick", function()
		if not MenuUtil then return end
		MenuUtil.CreateContextMenu(classDropdown, function(_, root)
			root:CreateRadio(L["All classes"],
				function() return ns.selectedClass == nil end,
				function() ns.SetClass(nil); classDropdown:GenerateMenu(); return MenuResponse.Close end)
			for _, c in ipairs(ns.GetClassList()) do
				local color = C_ClassColor and C_ClassColor.GetClassColor(c.file)
				local text = color and color:WrapTextInColorCode(c.name) or c.name
				root:CreateRadio(text,
					function() return ns.selectedClass == c.file end,
					function() ns.SetClass(c.file); classDropdown:GenerateMenu(); return MenuResponse.Close end)
			end
		end)
	end)
	SkinDropdown(classDropdown, false)
end

--------------------------------------------------------------------------------
-- Setup / hook
--------------------------------------------------------------------------------

local function Setup()
	local frame = _G.GearManagerPopupFrame
	if not frame or ns.hooked then return ns.hooked end

	InstallOverrides(frame)
	CreateClassDropdown(frame)

	-- Skin the existing "All Icons/Items/Spells" dropdown too, for consistency.
	if S and frame.BorderBox and frame.BorderBox.IconTypeDropdown then
		pcall(function() S:HandleDropDownBox(frame.BorderBox.IconTypeDropdown, 150) end)
	end

	-- Reset to "all classes" every time the popup opens (Blizzard recreates the
	-- icon data provider on show), and refresh our dropdown display.
	hooksecurefunc(frame, "OnShow", function()
		ns.active = false
		ns.selectedClass = nil
		ns.list = nil
		if classDropdown then
			classDropdown:Show()
			if classDropdown.GenerateMenu then classDropdown:GenerateMenu() end
		end
	end)

	ns.hooked = true
	return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_LOGIN" then
		-- Talents/spec changed: drop the cached player-class icon list so it rebuilds.
		if ns.iconCache then wipe(ns.iconCache) end
		return
	end

	if Setup() then return end
	-- PaperDollFrame may not be loaded yet; retry a few times.
	local tries = 0
	local ticker
	ticker = C_Timer.NewTicker(1, function()
		tries = tries + 1
		if Setup() or tries >= 10 then
			if ticker then ticker:Cancel() end
		end
	end)
end)
