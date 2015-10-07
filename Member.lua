local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")
local Utilities = VinceRaidFrames.Utilities

local WindowLocationNew = WindowLocation.new
local SpellCodeEnumSpellClassDebuffDispellable = Spell.CodeEnumSpellClass.DebuffDispellable

local setmetatable = setmetatable
local ipairs = ipairs
local abs = math.abs
local floor = math.floor
local max = math.max

local ktIdToClassSprite =
{
	[GameLib.CodeEnumClass.Esper] 			= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Warrior] 		= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Icon_Windows_UI_CRB_Spellslinger",
}

local tTargetMarkSpriteMap = {
	"Icon_Windows_UI_CRB_Marker_Bomb",
	"Icon_Windows_UI_CRB_Marker_Ghost",
	"Icon_Windows_UI_CRB_Marker_Mask",
	"Icon_Windows_UI_CRB_Marker_Octopus",
	"Icon_Windows_UI_CRB_Marker_Pig",
	"Icon_Windows_UI_CRB_Marker_Chicken",
	"Icon_Windows_UI_CRB_Marker_Toaster",
	"Icon_Windows_UI_CRB_Marker_UFO"
}

local Potions = {
	[36594] = "IconSprites:Icon_ItemMisc_potion_0001", -- Expert Insight Boost
	[38157] = "IconSprites:Icon_ItemMisc_potion_0001", -- Expert Grit Boost
	[36588] = "IconSprites:Icon_ItemMisc_potion_0002", -- Expert Moxie Boost
	[35028] = "IconSprites:Icon_ItemMisc_potion_0002", -- Expert Brutality Boost
	[36579] = "IconSprites:Icon_ItemMisc_potion_0003", -- Expert Tech Boost
	[36573] = "IconSprites:Icon_ItemMisc_UI_Item_Potion_001", -- Expert Finesse Boost
	
	-- OLD Adventus Potions IDs
	[36595] = "IconSprites:Icon_ItemMisc_potion_0001", -- Adventus Insight Boost
	[38158] = "IconSprites:Icon_ItemMisc_potion_0001", -- Adventus Grit Boost
	[36589] = "IconSprites:Icon_ItemMisc_potion_0002", -- Adventus Moxie Boost
	[35029] = "IconSprites:Icon_ItemMisc_potion_0002", -- Adventus Brutality Boost
	[36580] = "IconSprites:Icon_ItemMisc_potion_0002", -- Adventus Tech Boost
	[36574] = "IconSprites:Icon_ItemMisc_UI_Item_Potion_001", -- Adventus Finesse Boost

	-- NEW Adventus Potions IDs
	[35022] = "IconSprites:Icon_ItemMisc_potion_0002", -- Adventus Critical Hit Rating Boost
	[35122] = "IconSprites:Icon_ItemMisc_potion_0001", -- Adventus Enduro Boost
	[38153] = "IconSprites:Icon_ItemMisc_potion_0001", -- Adventus Critical Mitigation Boost
	[36590] = "IconSprites:Icon_ItemMisc_potion_0001", -- Adventus Focus Recovery Boost
	[39715] = "IconSprites:Icon_ItemMisc_UI_Item_Potion_001", -- Adventus Crit Boost
	[36575] = "IconSprites:Icon_ItemMisc_potion_0003", -- Adventus Glance Boost
	[36584] = "IconSprites:Icon_ItemMisc_potion_0002", -- Adventus Multi-Hit Boost
	[35053] = "IconSprites:Icon_ItemMisc_UI_Item_Potion_001", -- Adventus Strikethrough Boost
	[36557] = "IconSprites:Icon_ItemMisc_potion_0002", -- Adventus Deflect Boost
	--			[36573] = "IconSprites:Icon_ItemMisc_UI_Item_Potion_001", -- Liquid Focus - Reactive Strikethrough Boost
	--
	--			[37054] = "IconSprites:Icon_ItemMisc_potion_0002", -- Reactive Finesse Boost
	--			[35062] = "IconSprites:Icon_ItemMisc_potion_0002", -- Reactive Brutality Boost
}

local FoodBuffName = GameLib.GetSpell(48443):GetName()

local Member = {}
Member.__index = Member
function Member:Init(parent)
	Apollo.LinkAddon(parent, self)

	self.previousTarget = nil
end
function Member:new(unit, groupMember, parent)
	local o = {
		unit = unit,
		player = false,
		name = groupMember and groupMember.strCharacterName or unit:GetName(),
		groupMember = groupMember,
		version = nil, -- updated on iccomm messages
		frame = nil,
		draggable = false,
		parent = parent,
		xmlDoc = parent.xmlDoc,
		settings = parent.settings,
		classId = groupMember and groupMember.eClassId or unit:GetClassId(),
		classColor = nil,
		classIconPixie = nil,
		hasAggro = false,
		potionPixie = nil,
		foodPixie = nil,
		lastHealthColor = nil,
		lastFoodSprite = "",
		health = nil,
		flash = nil,
		text = nil,
		arrow = nil,
		interruptTimer = nil,
		dispelTimer = nil,
		outOfRange = false,
		dead = false,
		online = true,
		targeted = false,
		hovered = false,
		lastHealthAnchorPoint = -1,
		lastShieldAnchorPoint = -1,
		lastAbsorbAnchorPoint = -1
	}
	setmetatable(o, self)

	o:Build(parent.wndMain)

	return o
end

function Member:Build(parent)
	if self.unit and self.unit:IsThePlayer() then
		self.player = true
	end

	self.frame = Apollo.LoadForm(self.xmlDoc, "Member", parent, Member)

	self.classColor = self.settings.classColors[self.classId]
	self.lowHealthColor = {Utilities.RGB2HSV(self.settings.memberLowHealthColor.r, self.settings.memberLowHealthColor.g, self.settings.memberLowHealthColor.b)}
	self.highHealthColor = {Utilities.RGB2HSV(self.settings.memberHighHealthColor.r, self.settings.memberHighHealthColor.g, self.settings.memberHighHealthColor.b)}

	self.container = self.frame:FindChild("Container")
	self.overlay = self.frame:FindChild("Overlay")
	self.healthOverlay = self.frame:FindChild("HealthOverlay")
	self.health = self.frame:FindChild("HealthBar")
	self.shield = self.frame:FindChild("ShieldBar")
	self.absorb = self.frame:FindChild("AbsorbBar")
	self.flash = self.frame:FindChild("Flash")
	self.flash2 = self.frame:FindChild("Flash2")
	self.text = self.frame:FindChild("Text")
	self.arrow = self.frame:FindChild("Arrow")

	self:Arrange()
	self:ShowClassIcon(self.settings.memberShowClassIcon)

	self.text:SetFont(self.settings.memberFont)
	self:SetNameColor(self.settings.memberColor)

	self.frame:SetData(self)
	self.container:SetData(self)
	self.flash:Show(false, true)
	self.flash2:Show(false, true)
	self:UpdateReadyCheckMode()
	self:Refresh(self.unit, self.groupMember)

	if self.player then
		self.arrow:Show(false, true)
	end

	-- Todo: SetTarget() isn't updated on reloadui
end

function Member:SetName(name)
	self.text:SetText(name)
end

function Member:GetWidth()
	return self.settings.memberWidth + (self.settings.memberShowTargetMarker and 20 or 0)
end

function Member:GetHeight()
	return self.settings.memberHeight
end

function Member:Arrange()
	self.frame:SetAnchorOffsets(0, 0, self:GetWidth() + self.settings.memberPaddingLeft + self.settings.memberPaddingRight, self:GetHeight() + self.settings.memberPaddingTop + self.settings.memberPaddingBottom)
	self.container:SetAnchorOffsets(self.settings.memberPaddingLeft, self.settings.memberPaddingTop, -self.settings.memberPaddingRight, self.settings.memberPaddingBottom)

	if self.settings.memberShieldsBelowHealth then
		local shieldHeight = self.settings.memberShowShieldBar and self.settings.memberShieldHeight or 0
		local absorbHeight = self.settings.memberShowAbsorbBar and self.settings.memberAbsorbHeight or 0

		self.frame:FindChild("Health"):SetAnchorOffsets(1, 1, -1, -1 - shieldHeight - absorbHeight)

		if self.settings.memberShowShieldBar then
			self.frame:FindChild("Shield"):Show(true, true)
			self.frame:FindChild("Shield"):SetAnchorPoints(0, 1, 1, 1)
			self.frame:FindChild("Shield"):SetAnchorOffsets(1, -1 - self.settings.memberShieldHeight, -1, -1)
		else
			self.frame:FindChild("Shield"):Show(false, true)
		end

		if self.settings.memberShowAbsorbBar then
			self.frame:FindChild("Absorption"):Show(true, true)
			self.frame:FindChild("Absorption"):SetAnchorPoints(0, 1, 1, 1)
			self.frame:FindChild("Absorption"):SetAnchorOffsets(1, -1 - self.settings.memberAbsorbHeight - shieldHeight, -1, -1 - shieldHeight)
		else
			self.frame:FindChild("Absorption"):Show(false, true)
		end
	else
		local shieldWidth = self.settings.memberShowShieldBar and self.settings.memberShieldWidth or 0
		local absorbWidth = self.settings.memberShowAbsorbBar and self.settings.memberAbsorbWidth or 0

		self.frame:FindChild("Health"):SetAnchorOffsets(1, 1, -1 - shieldWidth - absorbWidth, -1)

		if self.settings.memberShowShieldBar then
			self.frame:FindChild("Shield"):Show(true, true)
			self.frame:FindChild("Shield"):SetAnchorPoints(1, 0, 1, 1)
			self.frame:FindChild("Shield"):SetAnchorOffsets(-1 - self.settings.memberShieldWidth - absorbWidth, 1, -1 - absorbWidth, -1)
		else
			self.frame:FindChild("Shield"):Show(false, true)
		end

		if self.settings.memberShowAbsorbBar then
			self.frame:FindChild("Absorption"):Show(true, true)
			self.frame:FindChild("Absorption"):SetAnchorPoints(1, 0, 1, 1)
			self.frame:FindChild("Absorption"):SetAnchorOffsets(-1 - self.settings.memberAbsorbWidth, 1, -1, -1)
		else
			self.frame:FindChild("Absorption"):Show(false, true)
		end
	end
end

function Member:SetArrowRotation(rotation)
	self.arrow:SetRotation(rotation)
end

function Member:ShowArrow(show)
	self.arrow:Show(show)
end

function Member:SetAggro(aggro)
	self.hasAggro = aggro
	if aggro then
		self:SetNameColor(self.settings.memberAggroTextColor)
	else
		self:RefreshNameColor()
	end
end

function Member:ShowClassIcon(show)
	if show then
		self.classIconBGPixie = self.healthOverlay:AddPixie({
			cr = "ffffffff",
			strSprite = "AbilitiesSprites:spr_TierFrame",
			loc = {
				fPoints = {0, .5, 0, .5},
				nOffsets = {1, -9, 19, 9}
			}
		})
		self.classIconPixie = self.healthOverlay:AddPixie({
			cr = "ffffffff",
			strSprite = "IconSprites:" .. ktIdToClassSprite[self.classId],
			loc = {
				fPoints = {0, .5, 0, .5},
				nOffsets = {2, -8, 18, 8}
			}
		})
		self.text:SetAnchorOffsets(21, 0, 70, 0)
	else
		if self.classIconPixie then
			self.healthOverlay:DestroyPixie(self.classIconBGPixie)
			self.healthOverlay:DestroyPixie(self.classIconPixie)
			self.text:SetAnchorOffsets(5, 0, 70, 0)
			self.classIconPixie = nil
			self.classIconBGPixie = nil
		end
	end
end

function Member:UpdateColorBy(color)
	if not self.parent.readyCheckActive then
		if color == VinceRaidFrames.ColorBy.Class then
			self:SetHealthColor(self.classColor)
		elseif color == VinceRaidFrames.ColorBy.FixedColor then
			self:SetHealthColor(self.parent.settings.memberBackgroundColor)
		end
	end
end


function Member:Refresh(unit, groupMember)
	self.groupMember = groupMember
	self.unit = unit and unit or self.unit

	local health
	local shield
	local absorb
	local wasOnline = self.online

	if groupMember then
		health = groupMember.nHealth / max(groupMember.nHealthMax, 1)
		shield = groupMember.nShield / max(groupMember.nShieldMax, 1)
		absorb = groupMember.nAbsorptionMax == 0 and 0 or groupMember.nAbsorption / groupMember.nAbsorptionMax

		self.dead = groupMember.nHealth == 0 and groupMember.nHealthMax ~= 0
		self.online = groupMember.bIsOnline
	else
		health = unit:GetHealth() / unit:GetMaxHealth()
		shield = unit:GetShieldCapacity() / unit:GetShieldCapacityMax()
		absorb = unit:GetAbsorptionMax() == 0 and 0 or unit:GetAbsorptionValue() / unit:GetAbsorptionMax()

		self.dead = unit:IsDead()
		self.online = true
	end

	self.outOfRange = true
	if self.parent.player and self.parent.player:IsDead() then
		self.outOfRange = false
	elseif unit and unit:IsValid() and self.parent.playerPos then
		local position = unit:GetPosition()
		if position then
			self.outOfRange = (self.parent.playerPos - Vector3.New(position)):Length() > self.settings.memberOutOfRange
		end
	end

	if not wasOnline and self.online then
		Event_FireGenericEvent("VinceRaidFrames_Group_Online", self.name)
	elseif wasOnline and not self.online then
		Event_FireGenericEvent("VinceRaidFrames_Group_Offline", self.name)
	end

	if self.outOfRange and not self.dead and self.online then
		self.frame:SetOpacity(self.settings.memberOutOfRangeOpacity, 5)
	else
		self.frame:SetOpacity(1, 5)
	end

	self:RefreshNameColor()
	self:RefreshTargetMarker(unit)

	if not self.parent.readyCheckActive and self.settings.colorBy == VinceRaidFrames.ColorBy.Health then
		self:SetHealthColor(Utilities.GetColorBetween(self.lowHealthColor, self.highHealthColor, health))
	end

    if self.settings.memberFillLeftToRight then
--		self.health:SetAnchorPoints(0, 0, health, 1)
--		self.shield:SetAnchorPoints(0, 0, shield, 1)
--		self.absorb:SetAnchorPoints(0, 0, absorb, 1)

		if health ~= self.lastHealthAnchorPoint then
			self.health:TransitionMove(WindowLocationNew({fPoints = {0, 0, health, 1}}), .075)
			self.lastHealthAnchorPoint = health
		end
		if shield ~= self.lastShieldAnchorPoint then
			self.shield:TransitionMove(WindowLocationNew({fPoints = {0, 0, shield, 1}}), .075)
			self.lastShieldAnchorPoint = shield
		end
		if absorb ~= self.lastAbsorbAnchorPoint then
			self.absorb:TransitionMove(WindowLocationNew({fPoints = {0, 0, absorb, 1}}), .075)
			self.lastAbsorbAnchorPoint = absorb
		end
	else
		self.health:SetAnchorPoints(1 - health, 0, 1, 1)
		self.shield:SetAnchorPoints(0, 0, 1 - shield, 1)
		self.absorb:SetAnchorPoints(0, 0, 1 - absorb, 1)
    end

	self:RefreshBuffs()

	if self.parent.readyCheckActive then
		if self.groupMember and self.groupMember.bHasSetReady then
			if not self.groupMember.bReady then
				self:SetHealthColor("ff0000")
			elseif not self.potionPixie or not self.foodPixie then
				self:SetHealthColor("ccff00")
			else
				self:SetHealthColor("00ff00")
			end
		end
	end
end

function Member:RefreshBuffs()
	local buffs
	if self.unit then
		buffs = self.unit:GetBuffs()
	end

	self:RefreshCleanseIndicator(self.settings.memberCleanseIndicator and buffs or nil)

	if self.parent.readyCheckActive or (self.settings.memberBuffIconsOutOfFight and not self.parent.inCombat) then
		self:RefreshBuffIcons(buffs)
	end
end

function Member:RefreshTargetMarker(unit)
	if unit and self.settings.memberShowTargetMarker then
		local sprite = tTargetMarkSpriteMap[unit:GetTargetMarker()]
		if sprite then
			if not self.targetMarkerFrame then
				self.targetMarkerFrame = Utilities.GetFrame(self.frame, self)
				self.targetMarkerFrame:SetBGColor("ffffffff")
				self.targetMarkerFrame:SetStyle("NoClip", true)
				self.targetMarkerFrame:SetStyle("Picture", true)
				self.targetMarkerFrame:SetStyle("NewWindowDepth", true)
				self.targetMarkerFrame:SetAnchorPoints(1, .5, 1, .5)
				self.targetMarkerFrame:SetAnchorOffsets(-22, -10, -2, 10)
				self.targetMarkerFrame:SetSprite(sprite)
			elseif sprite ~= self.targetMarkerFrame:GetSprite() then
				self.targetMarkerFrame:SetSprite(sprite)
			end
		elseif not sprite and self.targetMarkerFrame then
			self.targetMarkerFrame:Destroy()
			self.targetMarkerFrame = nil
		end
	elseif self.targetMarkerFrame then
		self.targetMarkerFrame:Destroy()
		self.targetMarkerFrame = nil
	end
end

function Member:RefreshCleanseIndicator(buffs)
	local canCleanse = false
	if buffs then
		for i, buff in ipairs(buffs.arHarmful) do
			if buff.splEffect:GetClass() == SpellCodeEnumSpellClassDebuffDispellable then
				canCleanse = true
				break
			end
		end
	end
	if canCleanse then
		self.container:SetBGColor("ffff0000")
	else
		self.container:SetBGColor("ff111111")
	end
end

function Member:RefreshBuffIcons(buffs)
	local potionFound = false
	local foodFound = false
	if buffs then
		for key, buff in ipairs(buffs.arBeneficial) do
			local potionSprite = Potions[buff.splEffect:GetId()]
			local foodSprite = buff.splEffect:GetName() == FoodBuffName and "IconSprites:Icon_ItemMisc_UI_Item_Sammich"
			if potionSprite then
				potionFound = true
				self:AddPotion(potionSprite)
			end
			if foodSprite then
				foodFound = true
				self:AddFood(foodSprite)
			end
			if potionFound and foodFound then
				break
			end
		end
	end
	if not potionFound then
		self:RemovePotion()
	end
	if not foodFound then
		self:RemoveFood()
	end
end

function Member:RefreshNameColor()
	if not self.hasAggro then
		if not self.online then
			self:SetNameColor(self.settings.memberOfflineTextColor)
		elseif self.dead then
			self:SetNameColor(self.settings.memberDeadTextColor)
		else
			self:SetNameColor(self.settings.memberColor)
		end
	end
end

function Member:SetNameColor(color)
    self.text:SetTextColor(color)
end

function Member:UpdateReadyCheckMode()
	if self.parent.readyCheckActive then
		self:SetHealthColor("cccccc")
	else
		self:UpdateColorBy(self.settings.colorBy)

		if not self.settings.memberBuffIconsOutOfFight then
			self:RemoveBuffIcons()
		end
	end
end

function Member:UpdateCombatMode()
	if self.parent.inCombat then
		self:RemoveBuffIcons()
	end
end

function Member:RemoveBuffIcons()
	self:RemovePotion()
	self:RemoveFood()
end

function Member:GetBuffIconOffsets(position)
	return -(position + 1) * self.settings.memberIconSizes - 1 -2 * position, -self.settings.memberIconSizes / 2, -position * self.settings.memberIconSizes - 1 -2 * position, self.settings.memberIconSizes / 2
end

function Member:AddPotion(sprite)
	if self.potionPixie then
		return
	end

	if self.foodPixie then
		self.overlay:UpdatePixie(self.foodPixie, {
			cr = "ffffffff",
			strSprite = self.lastFoodSprite,
			loc = {
				fPoints = {1, .5, 1, .5},
				nOffsets = {self:GetBuffIconOffsets(1)}
			}
		})
	end

	self.potionPixie = self.overlay:AddPixie({
		cr = "ffffffff",
		strSprite = sprite,
		loc = {
			fPoints = {1, .5, 1, .5},
			nOffsets = {self:GetBuffIconOffsets(0)}
		}
	})
end

function Member:AddFood(sprite)
	if self.foodPixie then
		return
	end
	self.lastFoodSprite = sprite

	local position = 0
	if self.potionPixie then
		position = position + 1
	end

	self.foodPixie = self.overlay:AddPixie({
		cr = "ffffffff",
		strSprite = sprite,
		loc = {
			fPoints = {1, .5, 1, .5},
			nOffsets = {self:GetBuffIconOffsets(position)}
		}
	})
end

function Member:RemovePotion()
	if self.potionPixie then
		if self.foodPixie then
			self.overlay:UpdatePixie(self.foodPixie, {
				cr = "ffffffff",
				strSprite = self.lastFoodSprite,
				loc = {
					fPoints = {1, .5, 1, .5},
					nOffsets = {self:GetBuffIconOffsets(0)}
				}
			})
		end
		
		self.overlay:DestroyPixie(self.potionPixie)
		self.potionPixie = nil
	end
end

function Member:RemoveFood()
	if self.foodPixie then
		self.overlay:DestroyPixie(self.foodPixie)
		self.foodPixie = nil
	end
end

function Member:Interrupted(amount)
	if self.interruptTimer then
		self.interruptTimer:Start()
	else
		self.interruptTimer = ApolloTimer.Create(self.settings.interruptFlashDuration, false, "OnInterruptedEnd", self)
	end
	self.flash:Show(true, true)
end

function Member:Dispelled(amount)
	if self.dispelTimer then
		self.dispelTimer:Start()
	else
		self.dispelTimer = ApolloTimer.Create(self.settings.dispelFlashDuration, false, "OnDispelEnd", self)
	end
	self.flash2:Show(true, true)
end

function Member:UpdateHealthAlpha()
	if self.targeted then
		self:SetHealthAlpha("2x:bb")
	elseif self.hovered then
		self:SetHealthAlpha("2x:88")
	else
		self:SetHealthAlpha("ff")
	end
end

function Member:SetTarget()
	self.targeted = true
	self:UpdateHealthAlpha()
end

function Member:UnsetTarget()
	self.targeted = false
	self:UpdateHealthAlpha()
end

function Member:SetHealthColor(color)
	self.lastHealthColor = color
	self.health:SetBGColor((self.lastHealthAlpha or "ff") .. color)
end

function Member:SetHealthAlpha(alpha)
	self.lastHealthAlpha = alpha
	self.health:SetBGColor(alpha .. self.lastHealthColor)
end

function Member:OnDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	GroupLib.SwapOrder(wndHandler:GetData().groupMember.nMemberIdx, wndSource:GetData().groupMember.nMemberIdx)
end

function Member:OnQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType ~= "Member" then
		return Apollo.DragDropQueryResult.Ignore
	end
	return Apollo.DragDropQueryResult.Accept
end

function Member:OnQueryBeginDragDrop(wndHandler, wndControl, nX, nY)
	if wndHandler:GetData().parent.editMode or (GroupLib.AmILeader() and Apollo.IsAltKeyDown()) then
		Apollo.BeginDragDrop(wndControl, "Member", "sprResourceBar_Sprint_RunIconSilver", 0)
		return true
	end
	return false
end

function Member:OnMemberClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	self = wndHandler:GetData()
	if self.unit then
		self.previousTarget = self.unit
		GameLib.SetTargetUnit(self.unit)
	end
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		if self.unit and self.unit:IsValid() then
			Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", self.frame, self.name, self.unit)
		else
			Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", self.frame, self.name)
		end
	end
end

function Member:OnMouseEnter(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	self = wndHandler:GetData()
	self.hovered = true
	self:UpdateHealthAlpha()
	if self.unit then
		if self.settings.hintArrowOnHover then
			self.unit:ShowHintArrow()
		end
		if self.settings.targetOnHover then
			self.previousTarget = GameLib.GetPlayerUnit():GetTarget()
			GameLib.SetTargetUnit(self.unit)
		end
	end
end

function Member:OnMouseExit(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	self = wndHandler:GetData()
	self.hovered = false
	self:UpdateHealthAlpha()
	if self.settings.targetOnHover then
		GameLib.SetTargetUnit(self.previousTarget)
	end
end

function Member:OnMemberDown(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if wndHandler ~= wndControl or not wndHandler or not bDoubleClick then
		return
	end
	-- dbl click
end

function Member:OnInterruptedEnd()
	self.flash:Show(false)
end

function Member:OnDispelEnd()
	self.flash2:Show(false)
end

function Member:Hide()
	self.frame:Show(false, false)
end

function Member:Show()
	self.frame:Show(true, false)
end

function Member:Destroy()
	self.frame:Destroy()
end

VinceRaidFrames.Member = Member
