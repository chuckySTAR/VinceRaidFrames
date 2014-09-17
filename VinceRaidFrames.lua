local function log(name, value)
	if SendVarToRover then
		Print(name)
		SendVarToRover(name, value, 0)
	end
end

require "Window"
require "GameLib"
require "GroupLib"

local Options = Apollo.GetPackage("Vince:VRF:Options-1").tPackage
local ReadyCheck = Apollo.GetPackage("Vince:VRF:ReadyCheck-1").tPackage
local Member = Apollo.GetPackage("Vince:VRF:Member-1").tPackage

local pairs = pairs
local ipairs = ipairs
local max = math.max
local min = math.min
local ceil = math.ceil
local floor = math.floor
local tinsert = table.insert

local ApolloLoadForm = Apollo.LoadForm
local GroupLibGetMemberCount = GroupLib.GetMemberCount
local GroupLibGetGroupMember = GroupLib.GetGroupMember
local GroupLibGetUnitForGroupMember = GroupLib.GetUnitForGroupMember
local GameLibGetPlayerUnit = GameLib.GetPlayerUnit
local GameLibCodeEnumVitalInterruptArmor = GameLib.CodeEnumVital.InterruptArmor
local UnitCodeEnumDispositionFriendly = Unit.CodeEnumDisposition.Friendly


local SortIdToName = {
	[1] = "SortByClass",
	[2] = "SortByRole",
	[3] = "SortByName",
	[4] = "SortByOrder"
}

local WrongInterruptSpellIds = {
	[33081] = true -- Esper's Fade Out
}


local VinceRaidFrames = {}
VinceRaidFrames.__index = VinceRaidFrames
function VinceRaidFrames:new(o)
	o = o or {}
    setmetatable(o, self)

	o.options = nil -- Options instance
	o.readyCheck = nil -- ReadyCheck instance
	o.onLoadDelayTimer = nil -- Dependencies in RegisterAddon do not *really* work
	o.timer = nil -- Refresh timer
	o.readyCheckActive = false -- Different view during ready check
	o.members = {}
	o.mobsInCombat = {}
	
	o.defaultSettings = {
		classColors = {
			[GameLib.CodeEnumClass.Warrior] = "F54F4F",
			[GameLib.CodeEnumClass.Engineer] = "EFAB48",
			[GameLib.CodeEnumClass.Esper] = "1591DB",
			[GameLib.CodeEnumClass.Medic] = "FFE757",
			[GameLib.CodeEnumClass.Stalker] = "D23EF4",
			[GameLib.CodeEnumClass.Spellslinger] = "98C723"
		},
		potions = {
			[36594] = "IconSprites:Icon_ItemMisc_potion_0001", -- Expert Insight Boost
			[38157] = "IconSprites:Icon_ItemMisc_potion_0001", -- Expert Grit Boost
			[36588] = "IconSprites:Icon_ItemMisc_potion_0002", -- Expert Moxie Boost
			[35028] = "IconSprites:Icon_ItemMisc_potion_0002", -- Expert Brutality Boost
			[36579] = "IconSprites:Icon_ItemMisc_potion_0003", -- Expert Tech Boost
			[36573] = "IconSprites:Icon_ItemMisc_UI_Item_Potion_001" -- Expert Finesse Boost
		},
		food = {
			[48443] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich", -- Exile Empanadas - 67 Moxie
			[48464] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[47542] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[47565] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48421] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48475] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48203] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48428] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48462] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48477] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48432] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[47923] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48473] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich",
			[48466] = "IconSprites:Icon_ItemMisc_UI_Item_Sammich"
		},
		memberHeight = 26,
		memberWidth = 100,
		memberFont = "CRB_Interface9",
		memberColor = {a = 1, r = 1, g = 1, b = 1},
		memberOfflineTextColor = {a = 1, r = .7, g = 0, b = 0},
		memberDeadTextColor = {a = 1, r = .5, g = .5, b = .5},
		memberBorderColor = "ff111111",
		memberBorderAggroColor = "ffaa0000",
		memberLowHealthColor = {a = 1, r = 1, g = 0, b = 0},
		memberHighHealthColor = {a = 1, r = 0, g = 1, b = 0},
		memberShowClassIcon = false,
		memberIconSizes = 16,
		memberMaxRows = 10,
		memberSpaceBetween = 2,
        memberFillLeftToRight = true,
		memberOutOfRangeOpacity = .5,
		memberShieldsBelowHealth = false,
		memberShieldHeight = 1,
		memberAbsorbHeight = 1,
		memberShieldWidth = 16,
		memberAbsorbWidth = 16,
		hintArrowOnHover = false,
		targetOnHover = false,
		sortBy = 1,
		colorBy = 1,
		categoryMaxRows = 7,
		
		padding = 5,
		refreshInterval = .3,
		interruptFlashDuration = 2.5
	}
	
	o.settings = setmetatable({}, {__index = o.defaultSettings})

    return o
end

function VinceRaidFrames:Init()
    Apollo.RegisterAddon(self, true, "Vince Raid Frames", {"ErrorDialog", "InterfaceMenuList"})
end

function VinceRaidFrames:OnLoad()
	self.onLoadDelayTimer = ApolloTimer.Create(.5, true, "OnLoadForReal", self)
end

function VinceRaidFrames:OnLoadForReal()
	local errorDialog = Apollo.GetAddon("ErrorDialog")
	local interfaceMenuList = Apollo.GetAddon("InterfaceMenuList")
	if errorDialog and errorDialog.wndReportBug and interfaceMenuList and interfaceMenuList.wndMain then
		self.onLoadDelayTimer:Stop()
	else
		return
	end

	Options.parent = self
	Options.settings = self.settings
	ReadyCheck.callback = {"OnReadyCheckTimeout", self}

	Apollo.RegisterEventHandler("Group_Join", "OnGroup_Join", self)
	Apollo.RegisterEventHandler("Group_Left", "OnGroup_Left", self)
	Apollo.RegisterEventHandler("Group_Disbanded", "OnGroup_Disbanded", self)
	Apollo.RegisterEventHandler("Group_Add", "OnGroup_Add", self)
	Apollo.RegisterEventHandler("Group_Changed", "OnGroup_Changed", self)
	Apollo.RegisterEventHandler("Group_Remove", "OnGroup_Remove", self)
	Apollo.RegisterEventHandler("Group_ReadyCheck", "OnGroup_ReadyCheck", self)
	Apollo.RegisterEventHandler("Group_MemberFlagsChanged", "OnGroup_MemberFlagsChanged", self)
	Apollo.RegisterEventHandler("TargetUnitChanged", "OnTargetUnitChanged", self)
	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("ToggleVinceRaidFrames", "OnToggleVinceRaidFrames", self)
	Apollo.RegisterEventHandler("MasterLootUpdate", "OnMasterLootUpdate", self)

	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckMasterLoot", "OnUncheckMasterLoot", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckLeaderOptions", "OnUncheckLeaderOptions", self)

	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
	
	Apollo.RegisterEventHandler("CombatLogCCState", "OnCombatLogCCState", self)
	Apollo.RegisterEventHandler("CombatLogVitalModifier", "OnCombatLogVitalModifier", self)
	
	Apollo.RegisterSlashCommand("vrf", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("vinceraidframes", "OnSlashCommand", self)
	
	self.timer = ApolloTimer.Create(self.settings.refreshInterval, true, "OnRefresh", self)
	self.timer:Stop()
	
	self:Show()
	-- if GroupLib.InGroup() then
		-- self:Show()
	-- end
	
	-- ready check
	
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "Vince Raid Frames", {"ToggleVinceRaidFrames", "", "IconSprites:Icon_Windows_UI_CRB_Rival"})
	Event_FireGenericEvent("AddonFullyLoaded", {addon = self, strName = "VinceRaidFrames"})
end

function VinceRaidFrames:SetPlayerView()
	GroupLibGetMemberCount = function() return 1 end
	GroupLibGetGroupMember = function() return nil end
	GroupLibGetUnitForGroupMember = GameLib.GetPlayerUnit
end

function VinceRaidFrames:SetRaidView()
	GroupLibGetMemberCount = GroupLib.GetMemberCount
	GroupLibGetGroupMember = GroupLib.GetGroupMember
	GroupLibGetUnitForGroupMember = GroupLib.GetUnitForGroupMember
end

function VinceRaidFrames:Show()
	if self.wndMain then
		if GroupLib.InGroup() then
			self:SetRaidView()
		else
			self:SetPlayerView()
		end
		
		self.wndMain:Invoke()
		
		self:BuildMemberFrames()
		self.timer:Start()
	else
		self:LoadXml("OnDocLoaded_Main")
	end
end

function VinceRaidFrames:OnDocLoaded_Main()
	self.wndMain = ApolloLoadForm(self.xmlDoc, "VinceRaidFrames", nil, self)
	self.wndMain:SetData(self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Vince Raid Frames"})

	self.wndGroupBagBtn = self.wndMain:FindChild("GroupBagBtn")
	self.wndRaidLeaderOptionsBtn = self.wndMain:FindChild("RaidLeaderOptionsBtn")
	self.wndRaidLeaderOptionsBtn = self.wndMain:FindChild("RaidLeaderOptionsBtn")
	self.wndRaidMasterLootBtn = self.wndMain:FindChild("RaidMasterLootBtn")
	self.wndRaidOptions = self.wndMain:FindChild("RaidOptions")
	self.wndMain:FindChild("RaidConfigureBtn"):AttachWindow(self.wndMain:FindChild("RaidOptions"))

	self.wndSelfConfigSetAsDPS = self.wndRaidOptions:FindChild("SelfConfigSetAsDPS")
	self.wndSelfConfigSetAsHealer = self.wndRaidOptions:FindChild("SelfConfigSetAsHealer")
	self.wndSelfConfigSetAsNormTank = self.wndRaidOptions:FindChild("SelfConfigSetAsNormTank")
	
	self:Show()
end

function VinceRaidFrames:LoadXml(callback)
	if self.xmlDoc then
		self[callback](self)
	else
		self.xmlDoc = XmlDoc.CreateFromFile("VinceRaidFrames.xml")
		self.xmlDoc:RegisterCallback(callback, self)
	end
end

function VinceRaidFrames:Hide()
	if self.wndMain then
		self.timer:Stop()
		self.wndMain:Close()
	end
end


function VinceRaidFrames:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Vince Raid Frames"})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndOptions, strName = "Vince Raid Frames Options"})
end

function VinceRaidFrames:OnDocLoaded_Options()
	Options:Show(self.xmlDoc)
end

function VinceRaidFrames:OnConfigure()
	self:LoadXml("OnDocLoaded_Options")
end

function VinceRaidFrames:OnGroup_ReadyCheck(index, message)
	ReadyCheck:Show(self.xmlDoc, index, message)
	self.readyCheckActive = true
	for name, member in pairs(self.members) do
		member:SetReadyCheckMode()
	end
end

function VinceRaidFrames:OnReadyCheckTimeout()
	log("readychecktimeout")
	self.readyCheckActive = false
	for name, member in pairs(self.members) do
		member:UnsetReadyCheckMode()
	end
end



function VinceRaidFrames:OnTargetUnitChanged(unit)
	if self.lastTarget then
		self.lastTarget:UnsetTarget()
		self.lastTarget = nil
	end
	if unit then
		local member = self.members[unit:GetName()]
		if member then
			self.lastTarget = member
			member:SetTarget()
		end
	end
end

function VinceRaidFrames:OnRefresh()
	local count = GroupLibGetMemberCount()
	for i = 1, count do
		local unit = GroupLibGetUnitForGroupMember(i)
		local groupMember = GroupLibGetGroupMember(i)
		local member = self.members[groupMember and groupMember.strCharacterName or (unit and unit:GetName())]
		if member then
			member:Refresh(self.readyCheckActive, unit, groupMember)
		end

		if i == 1 then
			if groupMember then
				self.wndRaidLeaderOptionsBtn:Show(groupMember.bIsLeader or groupMember.bRaidAssistant)
				self.wndRaidMasterLootBtn:Show(groupMember.bIsLeader)

--				self.wndSelfConfigSetAsDPS:SetCheck(groupMember.bDPS)
--				self.wndSelfConfigSetAsDPS:SetData(1)
--				self.wndSelfConfigSetAsHealer:SetCheck(groupMember.bHealer)
--				self.wndSelfConfigSetAsHealer:SetData(1)
--				self.wndSelfConfigSetAsNormTank:SetCheck(groupMember.bTank)
--				self.wndSelfConfigSetAsNormTank:SetData(1)
			else
				self.wndRaidLeaderOptionsBtn:Show(false)
				self.wndRaidMasterLootBtn:Show(false)
			end
		end
	end

	self:RefreshAggroIndicators()
end

function VinceRaidFrames:RefreshAggroIndicators()
	local aggroList = {}
	for id, mob in pairs(self.mobsInCombat) do
		local target = mob:GetTarget()
		if target then
			local member = self.members[target:GetName()]
			if member then
				aggroList[target:GetName()] = true
			end
		end
	end
	for name, member in pairs(self.members) do
		member:SetAggro(aggroList[name] or false)
	end
end

function VinceRaidFrames:BuildMemberFrames()
	local newMembers = {}
	local count = GroupLibGetMemberCount()
	for i = 1, count do
		local unit = GroupLibGetUnitForGroupMember(i)
		local groupMember = GroupLibGetGroupMember(i)
		local name = groupMember and groupMember.strCharacterName or unit:GetName() -- SetPlayerView only returns Unit and not a GroupMember
		local member = self.members[name]
		if not member then
			member = Member:new(unit, groupMember, self.settings, self.wndMain, self.xmlDoc)
			self.members[name] = member
		end
		newMembers[name] = true
	end
	-- Remove left members
	for name, member in pairs(self.members) do
		if not newMembers[name] then
			member:Destroy()
			self.members[name] = nil
		end
	end
	self:OnRefresh()
	self:ArrangeMembers()
end

function VinceRaidFrames.GetRoleAsNum(member)
	if member.groupMember.bTank then
		return 3
	elseif member.groupMember.bHealer then
		return 2
	end
	return 1
end

function VinceRaidFrames.SortByOrder(a, b)
	return a.groupMember.nOrder > b.groupMember.nOrder
end

function VinceRaidFrames.SortByRole(a, b)
	return VinceRaidFrames.GetRoleAsNum(a) > VinceRaidFrames.GetRoleAsNum(b)
end

function VinceRaidFrames.SortByName(a, b)
	return a.groupMember.strCharacterName < b.groupMember.strCharacterName
end

function VinceRaidFrames.SortByClass(a, b)
	return a.groupMember.eClassId > b.groupMember.eClassId
end

function VinceRaidFrames:ArrangeMembers()
	local members = self.ToList(self.members)
	local rows = self.settings.memberMaxRows
	local columns = ceil(#members / rows)
	local topPadding = 14
	
	-- In case of PlayerView the Member class has no groupMember attribute
	if #members > 1 then
		table.sort(members, self[SortIdToName[self.settings.sortBy]])
	end

	for i, member in ipairs(members) do
		local row = (i - 1) % rows
		local column = floor((i - 1) / rows)
		local left = self.settings.padding + column * (self.settings.memberWidth + self.settings.memberSpaceBetween)
		local top = topPadding + self.settings.padding + row * (self.settings.memberHeight + self.settings.memberSpaceBetween)
		member.frame:SetAnchorOffsets(left, top, left + self.settings.memberWidth, top + self.settings.memberHeight)
	end
	
	local left, top, right, bottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(left, top, left + 2 * self.settings.padding + columns * (self.settings.memberWidth + self.settings.memberSpaceBetween) - self.settings.memberSpaceBetween, top + 2 * self.settings.padding + min(self.settings.memberMaxRows, #members) * (self.settings.memberHeight + self.settings.memberSpaceBetween) - self.settings.memberSpaceBetween + topPadding)
end

function VinceRaidFrames:ArrangeMemberFrames()
	for name, member in pairs(self.members) do
		member:Arrange()
	end
end

function VinceRaidFrames:UpdateClassIcons()
	for name, member in pairs(self.members) do
		member:ShowClassIcon(self.settings.memberShowClassIcon)
	end
end

function VinceRaidFrames:UpdateColorBy()
	for name, member in pairs(self.members) do
		member:UpdateColorBy(self.settings.colorBy)
	end
end


function VinceRaidFrames:OnCombatLogCCState(e)
	if e.nInterruptArmorHit > 0 and e.unitCaster and not WrongInterruptSpellIds[e.splCallingSpell:GetId()] then
		local member = self.members[e.unitCaster:GetName()]
		if member then
			member:Interrupted(e.nInterruptArmorHit)
		end
	end
end

function VinceRaidFrames:OnCombatLogVitalModifier(e)
	if e.eVitalType == GameLibCodeEnumVitalInterruptArmor and e.unitCaster and e.nAmount < 0 then
		local member = self.members[e.unitCaster:GetName()]
		if member then
			member:Interrupted(e.nAmount * -1)
		end
	end
end


function VinceRaidFrames:OnUncheckLeaderOptions()
	if self.wndRaidLeaderOptionsBtn then
		self.wndRaidLeaderOptionsBtn:SetCheck(false)
	end
end

function VinceRaidFrames:OnUncheckMasterLoot()
	if self.wndRaidMasterLootBtn then
		self.wndRaidMasterLootBtn:SetCheck(false)
	end
end

function VinceRaidFrames:OnGroupBagBtn()
	Event_FireGenericEvent("GenericEvent_ToggleGroupBag")
end

function VinceRaidFrames:OnMasterLootUpdate()
	local tMasterLoot = GameLib.GetMasterLoot()
	local bShowMasterLoot = tMasterLoot and #tMasterLoot > 0
	self.wndGroupBagBtn:Show(bShowMasterLoot)
end

function VinceRaidFrames:OnRaidLeaderOptionsToggle(wndHandler, wndControl) -- RaidLeaderOptionsBtn
	Event_FireGenericEvent("GenericEvent_Raid_ToggleMasterLoot", false)
	Event_FireGenericEvent("GenericEvent_Raid_ToggleLeaderOptions", wndHandler:IsChecked())
end

function VinceRaidFrames:OnRaidMasterLootToggle(wndHandler, wndControl) -- RaidMasterLootBtn
	Event_FireGenericEvent("GenericEvent_Raid_ToggleMasterLoot", wndHandler:IsChecked())
	Event_FireGenericEvent("GenericEvent_Raid_ToggleLeaderOptions", false)
end

function VinceRaidFrames:OnRaidConfigureToggle(wndHandler, wndControl) -- RaidConfigureBtn
	if wndHandler:IsChecked() then
		Event_FireGenericEvent("GenericEvent_Raid_ToggleMasterLoot", false)
		Event_FireGenericEvent("GenericEvent_Raid_ToggleLeaderOptions", false)

		self:UpdateRoleButtons()
	end
end

function VinceRaidFrames:UpdateRoleButtons()
	local groupMember = GroupLibGetGroupMember(1)
	if groupMember and self.wndRaidOptions then
		self.wndRaidOptions:FindChild("SelfConfigReadyCheckLabel"):Show(groupMember.bIsLeader or groupMember.bMainTank or groupMember.bMainAssist or groupMember.bRaidAssistant)

		self.wndSelfConfigSetAsDPS:SetCheck(groupMember.bDPS)
		self.wndSelfConfigSetAsDPS:SetData(1)
		self.wndSelfConfigSetAsHealer:SetCheck(groupMember.bHealer)
		self.wndSelfConfigSetAsHealer:SetData(1)
		self.wndSelfConfigSetAsNormTank:SetCheck(groupMember.bTank)
		self.wndSelfConfigSetAsNormTank:SetData(1)

		local nLeft, nTop, nRight, nBottom = self.wndRaidOptions:GetAnchorOffsets()
		self.wndRaidOptions:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndRaidOptions:ArrangeChildrenVert(0))
	end
end

function VinceRaidFrames:OnConfigSetAsDPSToggle(wndHandler, wndControl)
	if wndHandler:IsChecked() then
		GroupLib.SetRoleDPS(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
	end
end

function VinceRaidFrames:OnConfigSetAsTankToggle(wndHandler, wndControl)
	if wndHandler:IsChecked() then
		GroupLib.SetRoleTank(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
	end
end

function VinceRaidFrames:OnConfigSetAsHealerToggle(wndHandler, wndControl)
	if wndHandler:IsChecked() then
		GroupLib.SetRoleHealer(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
	end
end

function VinceRaidFrames:OnStartReadyCheckBtn(wndHandler, wndControl) -- StartReadyCheckBtn
	if not self.readyCheckActive then
		local strMessage = self.wndMain:FindChild("RaidOptions:SelfConfigReadyCheckLabel:ReadyCheckMessageBG:ReadyCheckMessageEditBox"):GetText()
		if string.len(strMessage) <= 0 then
			strMessage = Apollo.GetString("RaidFrame_AreYouReady")
		end

		GroupLib.ReadyCheck(strMessage) -- Sanitized in code
		self.wndMain:FindChild("RaidConfigureBtn"):SetCheck(false)
		wndHandler:SetFocus() -- To remove out of edit box
		self.readyCheckActive = true
	end
end

function VinceRaidFrames:OnRaidLeaveShowPrompt(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("RaidConfigureBtn") then
		self.wndMain:FindChild("RaidConfigureBtn"):SetCheck(false)
	end
	Apollo.LoadForm(self.xmlDoc, "RaidLeaveYesNo", nil, self)
end

function VinceRaidFrames:OnRaidLeaveYes(wndHandler, wndControl)
	wndHandler:GetParent():Destroy()
	GroupLib.LeaveGroup()
end

function VinceRaidFrames:OnRaidLeaveNo(wndHandler, wndControl)
	wndHandler:GetParent():Destroy()
end

function VinceRaidFrames:IsUnitMob(unit)
	return unit ~= nil and unit:GetType() == "NonPlayer" and unit:GetDispositionTo(GameLibGetPlayerUnit()) ~= UnitCodeEnumDispositionFriendly
end

function VinceRaidFrames:OnUnitCreated(unit)
	if self:IsUnitMob(unit) and unit:IsInCombat() and unit:GetTarget() then
		self.mobsInCombat[unit:GetId()] = unit
	end
end

function VinceRaidFrames:OnUnitDestroyed(unit)
	if self.mobsInCombat[unit:GetId()] then
		self.mobsInCombat[unit:GetId()] = nil
	end
end
function VinceRaidFrames:OnUnitEnteredCombat(unit, bInCombat)
	if self.wndMain and unit:IsThePlayer() then
		self.readyCheckActive = false
		for name, member in pairs(self.members) do
			member:UnsetReadyCheckMode()
		end
	end

	if unit == nil or not unit:IsValid() then
		return
	end

	if self:IsUnitMob(unit) then
		self.mobsInCombat[unit:GetId()] = bInCombat and unit or nil
	end
end

function VinceRaidFrames:OnGroup_MemberFlagsChanged(...)
	self:UpdateRoleButtons()
	self:Show()
end

function VinceRaidFrames:OnGroup_Join(...)
	self:Show()
end

function VinceRaidFrames:OnGroup_Left(...)
	self:Show()
end

function VinceRaidFrames:OnGroup_Disbanded(...)
	self:Show()
end

function VinceRaidFrames:OnGroup_Add(...)
	self:Show()
end

function VinceRaidFrames:OnGroup_Changed(...)
	self:Show()
end

function VinceRaidFrames:OnGroup_Remove(...)
	self:Show()
end


function VinceRaidFrames:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	return self.settings
end

function VinceRaidFrames:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	self.settings = setmetatable(tSavedData, {__index = self.defaultSettings})
end



function VinceRaidFrames:OnDocLoaded_Toggle()
	Options:Toggle(self.xmlDoc)
end

function VinceRaidFrames:OnToggleVinceRaidFrames()
	self:LoadXml("OnDocLoaded_Toggle")
end

function VinceRaidFrames:OnSlashCommand()
	self:LoadXml("OnDocLoaded_Toggle")
end




function VinceRaidFrames.ToList(tbl)
	local list = {}
	for key, value in pairs(tbl) do
		tinsert(list, value)
	end
	return list
end



local VinceRaidFramesInst = VinceRaidFrames:new()
VinceRaidFramesInst:Init()
