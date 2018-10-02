local myAddonName, L = ...
local cani = CreateFrame("Frame", "CanIGo", UIParent)
local lastChangedFrame = nil
local UnitInfo = UnitInfo
local UnitGUID = UnitGUID

local DRData = LibStub("DRData-1.0")

-- Default settings
cani.defaultSettings = {
	version = "0.5",
	draggable = true,
	position = nil,
	sound = false,
	iconSize = 32,
	iconBorder = 2,
	iconMargin = 1,
	scale = 1.5
}

-- Local settings that get replaced with saved settings
cani.settings = {}

-- Relevant Categories to track
cani.categories = {
	"stun",			-- stuns ...
	"root",			-- roots ...
	"disorient",  	-- fear, cyclone, etc.
	"incapacitate",	-- poly, trap, ...
}
cani.categorySpells = {
	stun = {408, "stun"},			-- stuns ...
	root = {339, "root"},			-- roots ...
	disorient = {5782, "fear"},  	-- fear, cyclone, etc.
	incapacitate = {118, "poly"},	-- poly, trap, ...
}

-- Units to track. Arena-Targets will only become available in arena.
cani.relevantUnits = {
	"player",
	"party1",
	"party2",
	"party3",
	"party4",
}
cani.playerGUID = nil

-- The castbar spots in use
cani.spots = {
}

-- Global eventhandler to call the eventhandlers defined by methodname.
function cani:OnEvent(event, ...)
	if self and self[event] then
		self[event](self, ...)
	end
end
cani:SetScript("OnEvent", cani.OnEvent)

-- Does the event-initialization and initializes the UI
function cani:init()
	
	self:RegisterEvent("PLAYER_LOGOUT")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	
	self:SetHeight(20)
	
	self.dragbar = self:CreateTexture(nil, "BACKGROUND")
	self.dragbar:SetTexture(0, 0, 0, 0.25)
	self.dragbar:SetAllPoints()
	self.text = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.text:SetPoint("center", 0, 0)
	self.text:SetText("Drag me")
	
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", self.StopMovingOrSizing)

	local iconTotal = (cani.settings.iconSize + 2 * cani.settings.iconBorder) * cani.settings.scale
	self:SetWidth((iconTotal) * #self.categories)
	for i = 1, #self.categories do
		local category = self.categories[i]
		self:createFrame(category, ( (i-1) * iconTotal))
	end
	DEFAULT_CHAT_FRAME:AddMessage("CanIGo loaded. Type /cani for help.")
end

-- Set the UI according to settings
function cani:update()
	if self.settings.position then
		self:SetPoint("BOTTOMLEFT", self.settings.position.left, self.settings.position.bottom)
	else
		self:SetPoint("CENTER", 0, 0)
	end
	self:setDraggable(self.settings.draggable)
	
	local iconTotal = (cani.settings.iconSize + 2 * cani.settings.iconBorder) * cani.settings.scale
	self:SetWidth((iconTotal) * #self.categories)
	for i = 1, #self.categories do
		local category = self.categories[i]
		self:updateFrame(category, ( (i-1) * iconTotal))
	end
end

-- Settings loaded
function cani:ADDON_LOADED(addonName)
	if addonName == myAddonName then
		if _G.CanIGoDB and _G.CanIGoDB.version then
			self.settings = CopyTable(_G.CanIGoDB)
		else
			self.settings = CopyTable(self.defaultSettings)
		end

		self:init()
		self:update()
	end
end

-- Save settings
function cani:PLAYER_LOGOUT()

	-- Update local settings

	self.settings.draggable = self:IsMouseEnabled()
	local rectLeft, rectBottom = self:GetRect()
	self.settings.position = {left = rectLeft, bottom = rectBottom}
	
	-- Save local settings to global database
	
	_G.CanIGoDB = self.settings
end

-- Make the Indicators draggable
function cani:setDraggable(enable)
	if enable then
		self:SetMovable(true)
		self:EnableMouse(true)
		self:RegisterForDrag("LeftButton")
		self.dragbar:SetAlpha(1)
		self.text:SetAlpha(1)
	else
		self:SetMovable(false)
		self:EnableMouse(false)
		self:RegisterForDrag()
		self.dragbar:SetAlpha(0)
		self.text:SetAlpha(0)
	end
end

-- Creates a castbar-frame
function cani:createFrame(category, offset)
	if not self.frame then
		self.frame = { }
	end

	self.frame[category] = CreateFrame("Frame", nil, self)
	self.frame[category].level = 0
	self.frame[category].color = self.frame[category]:CreateTexture(nil, "BACKGROUND")
	self.frame[category].icon = self.frame[category]:CreateTexture(nil, "OVERLAY")
	self.frame[category].text = self.frame[category]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.frame[category].timerText = self.frame[category]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	
	self:updateFrame(category, offset)
end

-- Position an Indicator-Frame
function cani:updateFrame(category, offset)

	local iconTotal = (cani.settings.iconSize + 2 * cani.settings.iconBorder) * cani.settings.scale
	local iconSize = cani.settings.iconSize * cani.settings.scale
	local iconMargin = cani.settings.iconMargin * cani.settings.scale
	local iconBorder = cani.settings.iconBorder * cani.settings.scale
	local categorySpell, categoryName = unpack(self.categorySpells[category])
	
	self.frame[category]:SetHeight(iconTotal)
	self.frame[category]:SetWidth(iconTotal)
	self.frame[category]:SetPoint("TOPLEFT", self, offset, -self:GetHeight())
	self.frame[category]:SetAlpha(0.2)
	
	self.frame[category].color:SetHeight(iconTotal)
	self.frame[category].color:SetWidth(iconTotal)
	self.frame[category].color:SetTexture(0.2, 0.2, 0.2, 1.0)
	self.frame[category].color:SetAllPoints()
	
	local texture = GetSpellTexture(categorySpell)
	self.frame[category].icon:SetWidth(iconSize)
	self.frame[category].icon:SetHeight(iconSize)
	self.frame[category].icon:SetPoint("TOPLEFT", self.frame[category], iconBorder, -iconBorder)
	self.frame[category].icon:SetTexture(texture)
	self.frame[category].icon:SetAlpha(0.5)
	
	local fontName, fontHeight = self.frame[category].text:GetFont()
	fontHeight = 12 * cani.settings.scale
	self.frame[category].text:SetFont(fontName, fontHeight)
	self.frame[category].text:SetText(categoryName)
	self.frame[category].text:SetTextColor(1,1,1)
	self.frame[category].text:SetPoint("CENTER", self.frame[category], 0)
	self.frame[category].text:SetAlpha(1)
	
	local fontName, fontHeight = self.frame[category].timerText:GetFont()
	fontHeight = 12 * cani.settings.scale
	self.frame[category].timerText:SetFont(fontName, fontHeight)
	self.frame[category].timerText:SetPoint("BOTTOM", self.frame[category], 0, - fontHeight - (iconBorder*iconMargin))
	self.frame[category].timerText:SetText("0")
	self.frame[category].timerText:SetAlpha(0)
	
end

-- Tests to see if player is in Arena
function cani:isInArena()
	local _, instanceType = IsInInstance()
	return instanceType == "arena" or false
end

-- Tests to see if there is a frame for the unit
function cani:getUnitName(unitGUID)
	if not self.playerGUID then	-- might not be initialized
		self.playerGUID = UnitGUID("player")
	end
	
	if (self.playerGUID == unitGUID) then
		return "player"
	end
	
	return nil
end

-- Tests to see uf Frame is relevant
function cani:isRelevantSpell(spellID)
	return spellID and self.relevantSpells[spellID] or false
end

-- A debuff was applied
function cani:debuffStarted(unitGUID, spellID)
	local unitName = self:getUnitName(unitGUID)
	if not unitName then return end
	local category = DRData:GetSpellCategory(spellID)
	if not category then return end
	if not self.frame[category] then return end
	
	--print (unitGUID.." got debuff "..spellID.." of category "..category)

	local text = "100%"
	local color = {0.2, 0.2, 0.2}
	local texture = GetSpellTexture(spellID)
	local level = self.frame[category].level
	level = level + 1
	
	if level >= 3 then -- completely DRed
		level = 3
		color = { 0.4, 0.1, 0.1 }
		text = "0%"
	elseif level == 2 then
		color = { 0.3, 0.3, 0.0 }
		text = "25%"
	elseif level == 1 then
		color = { 0.0, 0.1, 0.3 }
		text = "50%"
	end
	
	self.frame[category]:SetAlpha(1)
	self.frame[category].level = level
	self.frame[category].text:SetText(text)
	self.frame[category].color:SetTexture(color[1], color[2], color[3], 1)
	self.frame[category].color:SetAllPoints()
	self.frame[category].icon:SetTexture(texture)
end

--
function cani:debuffFaded(unitGUID, spellID)
	local unitName = self:getUnitName(unitGUID)
	if not unitName then return end
	local category = DRData:GetSpellCategory(spellID)
	if not category then return end
	if not self.frame[category] then return end
	
	--print (unitGUID.." lost debuff "..spellID.." of category "..category)
	
	-- start timer of 18 seconds
	
	local tracked = self.frame[category]
	tracked.timeLeft = 18
	tracked.timerText:SetText(tracked.timeLeft)
	tracked.timerText:SetAlpha(1)
	tracked:SetScript("OnUpdate", function(f, elapsed)
		f.timeLeft = f.timeLeft - elapsed
		if f.timeLeft <= 0 then
			tracked:SetScript("OnUpdate", nil)
			self:debuffEnded(unit, category)
		elseif f.timeLeft < 5 then
			local timerText = string.format("%.1f", f.timeLeft)
			f.timerText:SetText(timerText)
		else
			local timerText = string.format("%.0f", f.timeLeft)
			f.timerText:SetText(timerText)
		end
	end)
end

function cani:debuffEnded(unit, category)
	-- hide timer
	self.frame[category].level = 0
	self.frame[category].timerText:SetAlpha(0)
	local categorySpell, categoryName = unpack(self.categorySpells[category])
	self.frame[category].text:SetText(categoryName)
	local texture = GetSpellTexture(categorySpell)
	self.frame[category].icon:SetTexture(texture, 0.5)
	self.frame[category].color:SetTexture(0.2, 0.2, 0.2, 1.0)
	self.frame[category].color:SetAllPoints()
	self.frame[category]:SetAlpha(0.2)
end

-- Combat log
function cani:COMBAT_LOG_EVENT_UNFILTERED(timeStamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType)
	
	-- if not band(srcFlags, COMBATLOG_HOSTILE) == COMBATLOG_HOSTILE then return end
	
	local _, eventType, _, _, _, _, _, destGUID, _, _, _, spellID, spellName, _, auraType = CombatLogGetCurrentEventInfo()

	if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
		if auraType == "DEBUFF" then
		
			-- Debuff applied
			--print("Debuff applied to ",destName,"(",sourceGUID,"): ", spellName)
		
			self:debuffStarted(destGUID, spellID)
		end
	elseif eventType == "SPELL_AURA_REMOVED" then
		if auraType == "DEBUFF" then
			--print("Debuff removed from ",destName,"(",sourceGUID,"): ", spellName)

			self:debuffFaded(destGUID, spellID)
		end
	end
end

function cani:handleCommand(msg)
	print("Processing Command: ", msg)
	if strfind(msg, "test") then
		print("CanIGo testing")
		self:debuffStarted(UnitGUID("player"), 118)
		self:debuffFaded(UnitGUID("player"), 118)
	elseif strfind(msg, "lock") then
		if self:IsMouseEnabled() then
			print("CanIGo locked")
			self:setDraggable(false)
		else
			print("CanIGo unlocked")
			self:setDraggable(true)
		end
	elseif strfind(msg, "scale") then
		local _, scale = strsplit(" ", msg)
		if scale then
			scale = tonumber(scale)
			if scale then
				print("New Scale = ", scale)
				self.settings.scale = scale
				self:update()
			else
				print("Scale is not a number")
			end
		else
			print("Current Scale: ",self.settings.scale)
		end
	elseif strfind(msg, "reset") then
		self.settings = CopyTable(self.defaultSettings)
		self:update()
	else
		print("CanIGo available commands:")
		print("/cani test - Test the castbars")
		print("/cani lock - Show/Hide dragbar")
		print("/cani scale %f - Change the scale (default = 1.5). Omit the Parameter to see the current scale.")
		print("/cani reset - Reset settings to default")
	end
end

cani:RegisterEvent("ADDON_LOADED")
SLASH_CANI1 = "/cani"
SlashCmdList["CANI"] = function(msg)
	cani:handleCommand(msg)
end
