--[[
Author: Starinnia
LeiShenConduits is an addon designed to track the power levels of Lei Shen's Conduits
contact: codemaster2010 AT gmail DOT com

Copyright (c) 2013 Michael J. Murray aka Lyte of Lothar(US)
All rights reserved unless otherwise explicitly stated.
]]

local addon = LibStub("AceAddon-3.0"):NewAddon("LeiShenConduits", "AceEvent-3.0", "AceTimer-3.0")

--upvalue globals used in health/ui updates
local format = string.format

local LEISHEN = 68397
local unlock = "Interface\\AddOns\\LeiShenConduits\\Textures\\un_lock"
local lock = "Interface\\AddOns\\LeiShenConduits\\Textures\\lock"

local function getCID(guid)
	return tonumber(guid:sub(6, 10), 16)
end

--forward declaration of the functions for the lock functions
local lockDisplay
local unlockDisplay
local updateLockButton
local toggleLock

function addon:OnInitialize()
	local defaults = {
		profile = {
			position = {},
			locked = false,
			width = 100,
			height = 122,
		},
	}
	self.db = LibStub("AceDB-3.0"):New("LeiShenConduitsDB", defaults, "Default")
	
	_G["SlashCmdList"]["LEISHENCONDUITS_MAIN"] = function(s)
		if self.ui:IsVisible() then
			self.ui:Hide()
		else
			self.ui:Show()
		end
	end
	
	_G["SLASH_LEISHENCONDUITS_MAIN1"] = "/conduits"
end

function addon:OnEnable()
	self:CreateUI()
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
end

function addon:OnDisable()
	self:UnregisterAllEvents()
	self.ui:Hide()
end

function addon:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
	if UnitExists("boss1") and getCID(UnitGUID("boss1")) == LEISHEN then
		--ignore LFR pulls
		local zone, _, diff = GetInstanceInfo()
		if diff == 7 then return end
		
		--reset on new fight
		self:RegisterEvent("UNIT_POWER")
		self:RegisterEvent("UNIT_POWERMAX", "UNIT_POWER")
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self.ui.North:SetText("North :: 0")
		self.ui.East:SetText("East :: 0")
		self.ui.South:SetText("South :: 0")
		self.ui.West:SetText("West :: 0")
		self.ui:Show()
	end
end

local nameLookup = {
	['Static Shock Conduit'] = "North",
	['Diffusion Chain Conduit'] = "East",
	['Overcharge Conduit'] = "South",
	['Bouncing Bolt Conduit'] = "West",
}

local allowedUnits = {['boss2'] = true, ['boss3'] = true, ['boss4'] = true, ['boss5'] = true,}
function addon:UNIT_POWER(event, unit)
	--update power levels
	if not allowedUnits[unit] then return end
	
	local name = UnitName(unit)
	local displayName = nameLookup[name]
	
	local text = self.ui[displayName]
	text:SetFormattedText("%s :: %d", displayName, UnitPower(unit))
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(_, _, subevent, _, _, _, _, _, dstGUID)
	if event == "UNIT_DIED" then
		if getCID(dstGUID) == LEISHEN then
			self:UnregisterAllEvents()
			self.ui:Hide()
		end 
	end
end

local function checkForWipe()
	local wiped = true
	local num = GetNumGroupMembers()
	
	for i = 1, num do
		local name = GetRaidRosterInfo(i)
		if UnitAffectingCombat(name) then
			wiped = false
			break
		end
	end
	
	if wiped then
		addon.ui:Hide()
		addon:UnregisterEvent("UNIT_POWER")
		addon:UnregisterEvent("UNIT_POWERMAX")
		addon:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		addon:UnregisterEvent("PLAYER_REGEN_ENABLED")
	else
		addon:ScheduleTimer(checkForWipe, 2)
	end
end

function addon:PLAYER_REGEN_ENABLED()
	if addon.ui:IsVisible() then
		checkForWipe()
	end
end

local function onDragStart(self) self:StartMoving() end
local function onDragStop(self)
	self:StopMovingOrSizing()
	local point, _, anchor, x, y = self:GetPoint()
	addon.db.profile.position.x = floor(x)
	addon.db.profile.position.y = floor(y)
	addon.db.profile.position.anchor = anchor
	addon.db.profile.position.point = point
end
local function OnDragHandleMouseDown(self) self.frame:StartSizing("BOTTOMRIGHT") end
local function OnDragHandleMouseUp(self) self.frame:StopMovingOrSizing() end
local function onResize(self, width, height)
	addon.db.profile.width = width
	addon.db.profile.height = height
end

local function lockDisplay()
	addon.ui:EnableMouse(false)
	addon.ui:SetMovable(false)
	addon.ui:SetResizable(false)
	addon.ui:RegisterForDrag()
	addon.ui:SetScript("OnSizeChanged", nil)
	addon.ui:SetScript("OnDragStart", nil)
	addon.ui:SetScript("OnDragStop", nil)
	addon.ui.drag:Hide()
end

local function unlockDisplay()
	addon.ui:EnableMouse(true)
	addon.ui:SetMovable(true)
	addon.ui:SetResizable(true)
	addon.ui:RegisterForDrag("LeftButton")
	addon.ui:SetScript("OnSizeChanged", onResize)
	addon.ui:SetScript("OnDragStart", onDragStart)
	addon.ui:SetScript("OnDragStop", onDragStop)
	addon.ui.drag:Show()
end

local function updateLockButton()
	if not addon.ui then return end
	addon.ui.lock:SetNormalTexture(addon.db.profile.locked and lock or unlock)
end

local function toggleLock()
	addon.db.profile.locked = not addon.db.profile.locked
	if addon.db.profile.locked then
		lockDisplay()
	else
		unlockDisplay()
	end
	updateLockButton()
end

local function onControlEnter(self)
	GameTooltip:ClearLines()
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	GameTooltip:AddLine(self.tooltipHeader)
	GameTooltip:AddLine(self.tooltipText, 1, 1, 1, 1)
	GameTooltip:Show()
end
local function onControlLeave() GameTooltip:Hide() end
local function closeWindow()
	addon.ui:Hide()
end

function addon:CreateUI()
	if self.ui then return end
	
	local f = CreateFrame("FRAME", nil, UIParent)
	f:SetWidth(self.db.profile.width)
	f:SetHeight(self.db.profile.height)
	f:SetClampedToScreen(true)
	f:SetMinResize(100, 60)
	
	f.bg = f:CreateTexture(nil, "PARENT")
	f.bg:SetAllPoints(f)
	f.bg:SetBlendMode("BLEND")
	f.bg:SetTexture(0, 0, 0, 0.5)
	
	if self.db.profile.position.x then
		f:SetPoint(self.db.profile.position.point, UIParent, self.db.profile.position.anchor, self.db.profile.position.x, self.db.profile.position.y)
	else
		f:SetPoint("CENTER")
	end
	
	f:SetScript("OnDragStart", onDragStart)
	f:SetScript("OnDragStop", onDragStop)
	f:SetScript("OnSizeChanged", onResize)
	
	f.close = CreateFrame("Button", nil, f)
	f.close:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -2, 2)
	f.close:SetHeight(16)
	f.close:SetWidth(16)
	f.close.tooltipHeader = "Close"
	f.close.tooltipText = "Closes the Conduit display."
	f.close:SetNormalTexture("Interface\\AddOns\\LeiShenConduits\\Textures\\close")
	f.close:SetScript("OnEnter", onControlEnter)
	f.close:SetScript("OnLeave", onControlLeave)
	f.close:SetScript("OnClick", closeWindow)

	f.lock = CreateFrame("Button", nil, f)
	f.lock:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 2)
	f.lock:SetHeight(16)
	f.lock:SetWidth(16)
	f.lock.tooltipHeader = "Toggle lock"
	f.lock.tooltipText = "Toggle whether or not the window should be locked or not."
	f.lock:SetScript("OnEnter", onControlEnter)
	f.lock:SetScript("OnLeave", onControlLeave)
	f.lock:SetScript("OnClick", toggleLock)
	
	f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.header:SetText("Conduits")
	f.header:SetPoint("BOTTOM", f, "TOP", 0, 4)
	
	f.North = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	f.North:SetFont("Fonts\\FRIZQT__.TTF", 12)
	f.North:SetText("")
	f.North:SetPoint("TOP", f, "TOP", 0, -10)
	
	f.East = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	f.East:SetFont("Fonts\\FRIZQT__.TTF", 12)
	f.East:SetText("")
	f.East:SetPoint("TOP", f, "TOP", 0, -25)
	
	f.South = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	f.South:SetFont("Fonts\\FRIZQT__.TTF", 12)
	f.South:SetText("")
	f.South:SetPoint("TOP", f, "TOP", 0, -40)
	
	f.West = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	f.West:SetFont("Fonts\\FRIZQT__.TTF", 12)
	f.West:SetText("")
	f.West:SetPoint("TOP", f, "TOP", 0, -55)
	
	f.drag = CreateFrame("Frame", nil, f)
	f.drag.frame = f
	f.drag:SetFrameLevel(f:GetFrameLevel() + 10)
	f.drag:SetWidth(16)
	f.drag:SetHeight(16)
	f.drag:SetPoint("BOTTOMRIGHT", f, -1, 1)
	f.drag:EnableMouse(true)
	f.drag:SetScript("OnMouseDown", OnDragHandleMouseDown)
	f.drag:SetScript("OnMouseUp", OnDragHandleMouseUp)
	f.drag:SetAlpha(0.5)
	
	f.drag.tex = f.drag:CreateTexture(nil, "BACKGROUND")
	f.drag.tex:SetTexture("Interface\\AddOns\\LeiShenConduits\\Textures\\draghandle")
	f.drag.tex:SetWidth(16)
	f.drag.tex:SetHeight(16)
	f.drag.tex:SetBlendMode("ADD")
	f.drag.tex:SetPoint("CENTER", f.drag)
	
	f:Hide()
	self.ui = f
	
	if self.db.profile.locked then
		lockDisplay()
	else
		unlockDisplay()
	end
	updateLockButton()
end
