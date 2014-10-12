local function log(name, value)
	if SendVarToRover then
		Print(name)
		SendVarToRover(name, value, 0)
	end
end

require "Window"
require "GameLib"
require "GroupLib"
require "ICCommLib"

local Options = Apollo.GetPackage("Vince:VRF:Options-1").tPackage
local ReadyCheck = Apollo.GetPackage("Vince:VRF:ReadyCheck-1").tPackage
local Member = Apollo.GetPackage("Vince:VRF:Member-1").tPackage
local ContextMenu = Apollo.GetPackage("Vince:VRF:ContextMenu-1").tPackage

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
local WrongInterruptBaseSpellIds = {
	[19190] = true -- Esper's Fade Out
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
	o.groupFrames = {}
	
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

--			[36573] = "IconSprites:Icon_ItemMisc_UI_Item_Potion_001", -- Liquid Focus - Reactive Strikethrough Boost
--
--			[37054] = "IconSprites:Icon_ItemMisc_potion_0002", -- Reactive Finesse Boost
--			[35062] = "IconSprites:Icon_ItemMisc_potion_0002", -- Reactive Brutality Boost
		},
		memberHeight = 26,
		memberWidth = 104,
		memberFont = "CRB_Interface9",
		memberColor = {a = 1, r = 1, g = 1, b = 1},
		memberOfflineTextColor = {a = 1, r = .1, g = .1, b = .1},
		memberDeadTextColor = {a = 1, r = .5, g = .5, b = .5},
		memberAggroTextColor = {a = 1, r = .86, g = .28, b = .28},
		memberLowHealthColor = {r = 1, g = 0, b = 0},
		memberHighHealthColor = {r = 0, g = 1, b = 0},
		memberShowClassIcon = false,
		memberShowTargetMarker = true,
		memberIconSizes = 16,
		memberSpaceBetween = 2,
        memberFillLeftToRight = true,
		memberOutOfRangeOpacity = .5,
		memberShieldsBelowHealth = false,
		memberShieldHeight = 1,
		memberAbsorbHeight = 1,
		memberShieldWidth = 16,
		memberAbsorbWidth = 16,
		memberColumns = 2,
		hintArrowOnHover = false,
		targetOnHover = false,
		sortBy = 1,
		colorBy = 1,
		padding = 5,
		groups = nil,
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
	Apollo.RegisterEventHandler("Group_MemberOrderChanged", "OnGroup_MemberOrderChanged", self)
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

	if GroupLib.InGroup() or GroupLib.InRaid() then
		self:Show()
	end

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
		self.wndMain:Invoke()
		self:OnMasterLootUpdate()

		if GroupLib.InGroup() or GroupLib.InRaid() then
			self:BuildMembers()
			self.timer:Start()
		else
			self:Hide()
		end
	else
		self:LoadXml("OnDocLoaded_Main")
	end
end

function VinceRaidFrames:OnDocLoaded_Main()
	self.wndMain = ApolloLoadForm(self.xmlDoc, "VinceRaidFrames", nil, self)
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Vince Raid Frames"})

	self.wndGroups = self.wndMain:FindChild("Groups")
	self.wndGroupBagBtn = self.wndMain:FindChild("GroupBagBtn")
	self.wndRaidLeaderOptionsBtn = self.wndMain:FindChild("RaidLeaderOptionsBtn")
	self.wndRaidLeaderOptionsBtn = self.wndMain:FindChild("RaidLeaderOptionsBtn")
	self.wndRaidMasterLootBtn = self.wndMain:FindChild("RaidMasterLootBtn")
	self.wndRaidOptions = self.wndMain:FindChild("RaidOptions")
	self.wndMain:FindChild("RaidConfigureBtn"):AttachWindow(self.wndMain:FindChild("RaidOptions"))

	self.wndSelfConfigSetAsDPS = self.wndRaidOptions:FindChild("SelfConfigSetAsDPS")
	self.wndSelfConfigSetAsHealer = self.wndRaidOptions:FindChild("SelfConfigSetAsHealer")
	self.wndSelfConfigSetAsNormTank = self.wndRaidOptions:FindChild("SelfConfigSetAsNormTank")

	self.channel = ICCommLib.JoinChannel("VinceRaidFrames", "OnICCommMessageReceived", self)

	self.groupContextMenu = ContextMenu:new(self.xmlDoc, {
		{
			GetLabel = function ()
				return "Move Up"
			end,
			IsVisible = function (value)
				return value > 1 and value <= #self.settings.groups
			end,
			OnClick = function (value)
				if value <= 1 or value > #self.settings.groups then
					return
				end

				local tmp = self.settings.groups[value]
				self.settings.groups[value] = self.settings.groups[value - 1]
				self.settings.groups[value - 1] = tmp

				self:ShareGroupLayout()
				self:ArrangeMembers()
			end
		},
		{
			GetLabel = function ()
				return "Move Down"
			end,
			IsVisible = function (value)
				return value < #self.settings.groups and value >= 1
			end,
			OnClick = function (value)
				if value < 1 or value >= #self.settings.groups then
					return
				end

				local tmp = self.settings.groups[value]
				self.settings.groups[value] = self.settings.groups[value + 1]
				self.settings.groups[value + 1] = tmp

				self:ShareGroupLayout()
				self:ArrangeMembers()
			end
		},
		{
			GetLabel = function ()
				return "New Group"
			end,
			IsVisible = function ()
				return true
			end,
			OnClick = function (value)
				local group = {
					name = self:GetUniqueGroupName(),
					members = {}
				}
				tinsert(self.settings.groups, value, group)

				self:ArrangeMembers()

				local frame = self.groupFrames[group.name].frame
				local editBox = frame:FindChild("NameEditBox")
				frame:FindChild("Name"):Show(false, true)
				editBox:Show(true, true)
				editBox:SetFocus(true, true)
				editBox:SetText(group.name)
				editBox:SetData(group)
			end
		},
		{
			GetLabel = function ()
				return "Remove"
			end,
			IsVisible = function ()
				return #self.settings.groups > 1
			end,
			OnClick = function (value)
				if #self.settings.groups <= 1 then
					return
				end

				local index = value == #self.settings.groups and value - 1 or #self.settings.groups
				local newGroup = self.settings.groups[index].members
				for i, name in ipairs(self.settings.groups[value].members) do
					tinsert(newGroup, name)
				end
				table.remove(self.settings.groups, value)

				self:ShareGroupLayout()
				self:ArrangeMembers()
			end
		},
		{
			GetLabel = function ()
				return "Rename"
			end,
			IsVisible = function ()
				return true
			end,
			OnClick = function (value)
				local group = self.settings.groups[value]
				local frame = self.groupFrames[group.name].frame
				local editBox = frame:FindChild("NameEditBox")
				frame:FindChild("Name"):Show(false, true)
				editBox:Show(true, true)
				editBox:SetFocus(true, true)
				editBox:SetText(group.name)
				editBox:SetData(group)
			end
		}
	})
	
	self:Show()
end

function VinceRaidFrames:LoadXml(callback)
	if self.xmlDoc then
		self[callback](self)
	else
		self.xmlDoc = XmlDoc.CreateFromFile("VinceRaidFrames.xml")
		self.xmlDoc:RegisterCallback(callback, self)
		Apollo.LoadSprites("VinceRaidFramesSprites.xml", "VinceRaidFramesSprites")
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

function VinceRaidFrames:BuildMembers()
	local newMembers = {}
	local count = GroupLibGetMemberCount()
	for i = 1, count do
		local unit = GroupLibGetUnitForGroupMember(i)
		local groupMember = GroupLibGetGroupMember(i)
		local name = groupMember and groupMember.strCharacterName or unit:GetName() -- SetPlayerView only returns Unit and not a GroupMember
		local member = self.members[name]
		if not member then
			member = Member:new(unit, groupMember, self)
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
	local r1 = VinceRaidFrames.GetRoleAsNum(a)
	local r2 = VinceRaidFrames.GetRoleAsNum(b)
	return r1 == r2 and VinceRaidFrames.SortByName(a, b) or r1 > r2
end

function VinceRaidFrames.SortByName(a, b)
	return a.groupMember.strCharacterName < b.groupMember.strCharacterName
end

function VinceRaidFrames.SortByClass(a, b)
	local r1 = a.groupMember.eClassId
	local r2 = b.groupMember.eClassId
	return r1 == r2 and VinceRaidFrames.SortByName(a, b) or r1 > r2
end

function VinceRaidFrames:ArrangeMembers()
	if not GroupLib.InGroup() then
		return
	end
	if not self.settings.groups then
		self:CreateDefaultGroups()
	end

	self:NormalizeGroups()
	self:BuildGroups()

	local lastGroup = self.settings.groups[#self.settings.groups].name
	local memberGroupMap = self:BuildMemberToGroupMap()
	-- add members to their group frames
	for name, member in pairs(self.members) do
		local group = memberGroupMap[name]
		tinsert(self.groupFrames[group and group or lastGroup].members, member)
	end
	-- sort every group
	for name, group in pairs(self.groupFrames) do
		table.sort(group.members, self[SortIdToName[self.settings.sortBy]])
	end

	local topPadding = 20
	local groupHeaderHeight = 15
	local accHeight = topPadding
	for i, group in ipairs(self.settings.groups) do
		local groupFrame = self.groupFrames[group.name]
		groupFrame.frame:SetAnchorOffsets(0, accHeight, 0, accHeight + groupHeaderHeight)
		accHeight = accHeight + groupHeaderHeight

		if groupFrame.frame:FindChild("Btn"):IsChecked() then
			for j, member in ipairs(groupFrame.members) do
				member:Hide()
			end
		else
			for j, member in ipairs(groupFrame.members) do
				local row = floor((j - 1) / self.settings.memberColumns)
				local left = ((j - 1) % self.settings.memberColumns) * member:GetWidth()
				member:Show()
				member.frame:SetAnchorOffsets(left, accHeight + row * member:GetHeight(), left + member:GetWidth(), accHeight + (row + 1) * member:GetHeight())
			end

			if #groupFrame.members > 0 then
				accHeight = accHeight + ceil(#groupFrame.members / self.settings.memberColumns) * groupFrame.members[1]:GetHeight()
			end
		end
	end

	local _, member = next(self.members)
	local left, top, right, bottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(left, top, left + self.settings.memberColumns * (member and member:GetWidth() or 140), top + accHeight + self.settings.padding)
end

function VinceRaidFrames:BuildGroups()
	local newGroups = {}
	for i, group in ipairs(self.settings.groups) do
		local groupFrame = self.groupFrames[group.name]
		if not groupFrame then
			local frame = ApolloLoadForm(self.xmlDoc, "Group", self.wndMain, self)
			frame:FindChild("Name"):SetText(" " .. group.name)
			frame:FindChild("Btn"):SetData(group.name)
			groupFrame = {
				frame = frame
			}
			frame:SetData(groupFrame)
			self.groupFrames[group.name] = groupFrame
		end
		groupFrame.index = i
		groupFrame.members = {}
		newGroups[group.name] = true
	end

	for name, frame in pairs(self.groupFrames) do
		if not newGroups[name] then
			self.groupFrames[name].frame:Destroy()
			self.groupFrames[name] = nil
		end
	end
end

function VinceRaidFrames:BuildMemberToGroupMap()
	local map = {}
	for i, group in ipairs(self.settings.groups) do
		for j, name in ipairs(group.members) do
			map[name] = group.name
		end
	end
	return map
end

-- rename same groups, remove members who are in more than one group, add missing members
function VinceRaidFrames:NormalizeGroups()
	local members = {}
	local groupNames = {}
	for i, group in ipairs(self.settings.groups) do
		if groupNames[group.name] then
			group.name = self:GetUniqueGroupName()
		else
			groupNames[group.name] = true
		end

		for j = #group.members, 1, -1 do
			if members[group.members[j]] then
				table.remove(group.members, j)
			else
				members[group.members[j]] = true
			end
		end
	end

	for name, member in pairs(self.members) do
		if not members[name] then
			tinsert(self.settings.groups[#self.settings.groups].members, name)
		end
	end
end

function VinceRaidFrames:MoveMemberToGroup(memberName, groupName)
	self:RemoveMemberFromGroup(memberName)
	self:AddMemberToGroup(memberName, groupName)
	self:ArrangeMembers()
end

function VinceRaidFrames:AddMemberToGroup(memberName, groupName)
	for i, group in ipairs(self.settings.groups) do
		if group.name == groupName then
			tinsert(group.members, memberName)
			return
		end
	end
end

function VinceRaidFrames:RemoveMemberFromGroup(memberName)
	for i, group in ipairs(self.settings.groups) do
		for j, name in ipairs(group.members) do
			if name == memberName then
				table.remove(group.members, j)
				return
			end
		end
	end
end

function VinceRaidFrames:CreateDefaultGroups()
	self.settings.groups = {
		{
			name = "Raid",
			members = {}
		}
	}
	for name, member in pairs(self.members) do
		tinsert(self.settings.groups[1].members, name)
	end
end

--function VinceRaidFrames:CreateDefaultGroups()
--	local tanks = {
--		name = "Tanks",
--		members = {}
--	}
--	local healers = {
--		name = "Healers",
--		members = {}
--	}
--	local dps = {
--		name = "DPS",
--		members = {}
--	}
--	self.settings.groups = {tanks, healers, dps}
--	for name, member in pairs(self.members) do
--		tinsert(member.groupMember.bTank and tanks.members or (member.groupMember.bHealer and healers.members or dps.members), name)
--	end
--end

function VinceRaidFrames:ValidateGroups(groups)
	if type(groups) ~= "table" or #groups < 1 then
		return false
	end
	for i, group in ipairs(groups) do
		if type(group) ~= "table" or type(group.name) ~= "string" or type(group.members) ~= "table" then
			return false
		end
		for j, name in ipairs(group.members) do
			if type(name) ~= "string" then
				return false
			end
		end
	end
	return true
end

function VinceRaidFrames:IsLeader(name)
	for i = 1, GroupLibGetMemberCount() do
		local member = GroupLibGetGroupMember(i)
		if member.strCharacterName == name and member.bIsLeader then
			return true
		end
	end
	return false
end

function VinceRaidFrames:ShareGroupLayout()
	self.channel:SendMessage(self.settings.groups)
end

function VinceRaidFrames:IsUniqueGroupName(name)
	return not self.groupFrames[name]
end

function VinceRaidFrames:GetUniqueGroupName()
	local groupNames = {}
	for i, group in ipairs(self.settings.groups) do
		groupNames[group.name] = true
	end

	if not groupNames.Raid then
		return "Raid"
	end
	local i = 1
	while true do
		if not groupNames["Raid" .. i] then
			return "Raid" .. i
		end
		i = i + 1
	end
end

--function VinceRaidFrames:OnICCommMessageReceived(channel, message)
function VinceRaidFrames:OnICCommMessageReceived(channel, message, sender)
	if self:IsLeader(sender) and self:ValidateGroups(message) then
		self.settings.groups = message
		self:ArrangeMembers()
	end
end

function VinceRaidFrames:OnGroupToggle()
	self:ArrangeMembers()
end

function VinceRaidFrames:OnGroupMouseBtnUp(wndHandler, wndControl, eMouseButton)
	if GroupLib.AmILeader() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self.groupContextMenu:Show(wndHandler:GetParent():GetData().index)
	end
end

function VinceRaidFrames:OnDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	self:MoveMemberToGroup(wndSource:GetData().name, wndHandler:GetData())
	self:ShareGroupLayout()
end

function VinceRaidFrames:OnQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType ~= "Member" then
		return Apollo.DragDropQueryResult.Ignore
	end
	return Apollo.DragDropQueryResult.Accept
end

function VinceRaidFrames:OnGroupNameEditBoxClose(wndHandler, wndControl, strText)
	self:OnGroupNameEditBoxReturn(wndHandler, wndControl, wndHandler:GetText())
end
function VinceRaidFrames:OnGroupNameEditBoxReturn(wndHandler, wndControl, strText)
	if wndHandler:GetData().name == strText or self:IsUniqueGroupName(strText) then
		wndHandler:Show(false, true)
		wndHandler:GetParent():FindChild("Name"):Show(true, true)
		wndHandler:GetData().name = strText
		self:ShareGroupLayout()
		self:ArrangeMembers()
	else
		wndHandler:Show(true, true)
	end
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
	if e.nInterruptArmorHit > 0 and e.unitCaster and not WrongInterruptBaseSpellIds[e.splCallingSpell:GetBaseSpellId()] then
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
	local checked = wndHandler:IsChecked()
	if checked then
		Event_FireGenericEvent("GenericEvent_Raid_ToggleMasterLoot", false)
		Event_FireGenericEvent("GenericEvent_Raid_ToggleLeaderOptions", false)

		self:UpdateRoleButtons()

		if GroupLib.AmILeader() then
			self:MakeMembersDraggable(true)
		end

		local nLeft, nTop, nRight, nBottom = self.wndRaidOptions:GetAnchorOffsets()
		self.wndRaidOptions:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndRaidOptions:ArrangeChildrenVert(0))
	else
		self:MakeMembersDraggable(false)
	end
end

function VinceRaidFrames:MakeMembersDraggable(value)
	for name, member in pairs(self.members) do
		member:SetDraggable(value)
	end
end

function VinceRaidFrames:UpdateRoleButtons()
	local groupMember = GroupLibGetGroupMember(1)
	if groupMember and self.wndRaidOptions then
		local lead = groupMember.bIsLeader or groupMember.bMainTank or groupMember.bMainAssist or groupMember.bRaidAssistant
		self.wndRaidOptions:FindChild("SelfConfigReadyCheckLabel"):Show(lead)
		self.wndRaidOptions:FindChild("RaidTools"):Show(lead)

		self.wndSelfConfigSetAsDPS:SetCheck(groupMember.bDPS)
		self.wndSelfConfigSetAsDPS:SetData(1)
		self.wndSelfConfigSetAsHealer:SetCheck(groupMember.bHealer)
		self.wndSelfConfigSetAsHealer:SetData(1)
		self.wndSelfConfigSetAsNormTank:SetCheck(groupMember.bTank)
		self.wndSelfConfigSetAsNormTank:SetData(1)
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

function VinceRaidFrames:OnGrantMarks()
	for i = 2, GroupLibGetMemberCount() do
		if not GroupLibGetGroupMember(i).bCanMark then
			GroupLib.SetCanMark(i, true)
		end
	end
end

function VinceRaidFrames:OnRevokeMarks()
	for i = 2, GroupLibGetMemberCount() do
		if GroupLibGetGroupMember(i).bCanMark then
			GroupLib.SetCanMark(i, false)
		end
	end
end

function VinceRaidFrames:OnClearMarks()
	GameLib.ClearAllTargetMarkers()
end

function VinceRaidFrames:OnGroup_MemberFlagsChanged(...)
	self:UpdateRoleButtons()
	self:Show()
end

function VinceRaidFrames:OnGroup_MemberOrderChanged(...)
	self:OnRefresh()
	self:ArrangeMembers()
end

function VinceRaidFrames:OnGroup_Add(name)
	tinsert(self.settings.groups[#self.settings.groups].members, name)
	self:Show()
end

function VinceRaidFrames:OnGroup_Remove(name) -- someone leaves
	self:RemoveMemberFromGroup(name)
	self:Show()
end

function VinceRaidFrames:OnGroup_Join(...)
	self.settings.groups = nil
	self:Show()
end

function VinceRaidFrames:OnGroup_Left(...) -- player leaves
	self.settings.groups = nil
	self:Show()
end

function VinceRaidFrames:OnGroup_Disbanded(...)
	self:Show()
end

function VinceRaidFrames:OnGroup_Changed(...)
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
