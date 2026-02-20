-- Rayfield Element Factories Module
-- Handles tab creation and all element factories

local ElementsModule = {}

function ElementsModule.init(ctx)
	local self = {}

	-- Inject dependencies
	self.TweenService = ctx.TweenService
	self.Animation = ctx.Animation or ctx.TweenService
	self.RunService = ctx.RunService
	self.UserInputService = ctx.UserInputService
	self.HttpService = ctx.HttpService
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements
	self.Rayfield = ctx.Rayfield
	self.RayfieldLibrary = ctx.RayfieldLibrary
	self.Icons = ctx.Icons
	self.getIcon = ctx.getIcon
	self.getAssetUri = ctx.getAssetUri
	self.getSelectedTheme = ctx.getSelectedTheme
	self.rayfieldDestroyed = ctx.rayfieldDestroyed
	self.getMinimised = ctx.getMinimised or function() return false end
	self.getSetting = ctx.getSetting
	self.bindTheme = ctx.bindTheme
	self.SaveConfiguration = ctx.SaveConfiguration
	self.makeElementDetachable = ctx.makeElementDetachable
	-- Improvement 4: Add safe fallbacks for critical dependencies
	self.keybindConnections = ctx.keybindConnections or {} -- Fallback to empty table
	self.getDebounce = ctx.getDebounce or function() return false end
	self.setDebounce = ctx.setDebounce or function(val) end

	self.useMobileSizing = ctx.useMobileSizing

	-- Window Settings (passed from CreateWindow)
	local Settings = ctx.Settings or {}

	-- Module state
	local FirstTab = false

	-- Extract code starts here

		local function CreateTab(Name, Image, Ext)
			local SDone = false
			local TabButton = self.TabList.Template:Clone()
			TabButton.Name = Name
			TabButton.Title.Text = Name
			TabButton.Parent = self.TabList
			TabButton.Title.TextWrapped = false
			TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 30, 0, 30)
	
			if Image and Image ~= 0 then
				if typeof(Image) == 'string' and self.Icons then
					local asset = self.getIcon(Image)
	
					TabButton.Image.Image = 'rbxassetid://'..asset.id
					TabButton.Image.ImageRectOffset = asset.imageRectOffset
					TabButton.Image.ImageRectSize = asset.imageRectSize
				else
					TabButton.Image.Image = self.getAssetUri(Image)
				end
	
				TabButton.Title.AnchorPoint = Vector2.new(0, 0.5)
				TabButton.Title.Position = UDim2.new(0, 37, 0.5, 0)
				TabButton.Image.Visible = true
				TabButton.Title.TextXAlignment = Enum.TextXAlignment.Left
				TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 52, 0, 30)
			end
	
	
	
			TabButton.BackgroundTransparency = 1
			TabButton.Title.TextTransparency = 1
			TabButton.Image.ImageTransparency = 1
			TabButton.UIStroke.Transparency = 1

			local TabHoverGlow = Instance.new("UIStroke")
			TabHoverGlow.Name = "HoverGlow"
			TabHoverGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			TabHoverGlow.Thickness = 2.8
			TabHoverGlow.Transparency = 1
			TabHoverGlow.Color = Color3.fromRGB(110, 175, 240)
			TabHoverGlow.Parent = TabButton
	
			TabButton.Visible = not Ext or false
	
			-- Create self.Elements Page
			local TabPage = self.Elements.Template:Clone()
			TabPage.Name = Name
			TabPage.Visible = true
	
			TabPage.LayoutOrder = #self.Elements:GetChildren() or Ext and 10000
	
			for _, TemplateElement in ipairs(TabPage:GetChildren()) do
				if TemplateElement.ClassName == "Frame" and TemplateElement.Name ~= "Placeholder" then
					TemplateElement:Destroy()
				end
			end

			TabPage.Parent = self.Elements

			local tabRecord = {
				Name = Name,
				Ext = Ext and true or false,
				TabButton = TabButton,
				TabPage = TabPage,
				DefaultVisible = TabButton.Visible,
				IsSplit = false,
				SplitPanelId = nil,
				SuppressNextClick = false,
				IsSettings = (Name == "Rayfield Settings" and Ext == true)
			}
			local tabHover = false
			
			-- Reactive coloring for TabPage elements
			TabPage.ChildAdded:Connect(function(Element)
				if Element.ClassName == "Frame" and Element.Name ~= "Placeholder" and Element.Name ~= "SectionSpacing" and Element.Name ~= "Divider" and Element.Name ~= "SectionTitle" and Element.Name ~= "SearchTitle-fsefsefesfsefesfesfThanks" then
					self.bindTheme(Element, "BackgroundColor3", "ElementBackground")
					-- Guard: not all frames have a UIStroke child
					if Element:FindFirstChildWhichIsA("UIStroke") then
						self.bindTheme(Element.UIStroke, "Color", "ElementStroke")
					end
				end
			end)
			
			if not FirstTab and not Ext then
				self.Elements.UIPageLayout.Animated = false
				self.Elements.UIPageLayout:JumpTo(TabPage)
				self.Elements.UIPageLayout.Animated = true
			end
	
			self.bindTheme(TabButton.UIStroke, "Color", "TabStroke")
	
			local function UpdateTabColors()
				TabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
				TabHoverGlow.Color = self.getSelectedTheme().SliderProgress or self.getSelectedTheme().TabStroke
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					tabHover = false
					TabButton.UIStroke.Thickness = 1
					TabHoverGlow.Transparency = 1
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected
					TabButton.Image.ImageColor3 = self.getSelectedTheme().SelectedTabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().SelectedTabTextColor
				else
					if not tabHover then
						TabButton.UIStroke.Thickness = 1
						TabHoverGlow.Transparency = 1
					end
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackground
					TabButton.Image.ImageColor3 = self.getSelectedTheme().TabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().TabTextColor
				end
			end

			local function applyTabHoverVisual(duration)
				if tabRecord.IsSplit then
					return
				end
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					return
				end

				local tweenDuration = duration or 0.16
				local theme = self.getSelectedTheme() or {}
				local targetBackgroundTransparency = tabHover and 0.58 or 0.7
				local targetStrokeTransparency = tabHover and 0.32 or 0.5
				local targetStrokeThickness = tabHover and 1.2 or 1
				local targetStrokeColor = tabHover and (theme.SliderProgress or theme.TabStroke) or theme.TabStroke
				local targetGlowTransparency = tabHover and 0.84 or 1
				local targetGlowThickness = tabHover and 3.3 or 2.8
				local targetGlowColor = theme.SliderProgress or theme.TabStroke
				local targetTextTransparency = tabHover and 0.05 or 0.2
				local targetImageTransparency = tabHover and 0.05 or 0.2

				self.Animation:Create(TabButton, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = targetBackgroundTransparency}):Play()
				self.Animation:Create(TabButton.UIStroke, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = targetStrokeTransparency,
					Thickness = targetStrokeThickness,
					Color = targetStrokeColor
				}):Play()
				self.Animation:Create(TabHoverGlow, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = targetGlowTransparency,
					Thickness = targetGlowThickness,
					Color = targetGlowColor
				}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = targetTextTransparency}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = targetImageTransparency}):Play()
			end

			-- Listen for theme changes to update tab colors
			local themeValueFolder = self.Main:FindFirstChild("ThemeValues")
			if themeValueFolder then
				themeValueFolder:FindFirstChild("Background").Changed:Connect(UpdateTabColors)
			end
			
			self.Elements.UIPageLayout:GetPropertyChangedSignal("CurrentPage"):Connect(UpdateTabColors)
	
	
			-- Animate
			task.wait(0.1)
			if FirstTab or Ext then
				TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackground
				TabButton.Image.ImageColor3 = self.getSelectedTheme().TabTextColor
				TabButton.Title.TextColor3 = self.getSelectedTheme().TabTextColor
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
				self.Animation:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
				TabHoverGlow.Transparency = 1
			elseif not Ext then
				FirstTab = Name
				TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected
				TabButton.Image.ImageColor3 = self.getSelectedTheme().SelectedTabTextColor
				TabButton.Title.TextColor3 = self.getSelectedTheme().SelectedTabTextColor
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
				TabHoverGlow.Transparency = 1
			end
	
			local function activateTab(ignoreMinimisedCheck)
				if tabRecord.IsSplit then return false end
				if not ignoreMinimisedCheck and self.getMinimised() then return false end

				tabHover = false
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextColor3 = self.getSelectedTheme().SelectedTabTextColor}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageColor3 = self.getSelectedTheme().SelectedTabTextColor}):Play()
				TabButton.UIStroke.Thickness = 1
				TabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
				TabHoverGlow.Transparency = 1

				for _, OtherTabButton in ipairs(self.TabList:GetChildren()) do
					if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton ~= TabButton and OtherTabButton.Name ~= "Placeholder" and OtherTabButton.Visible then
						self.Animation:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().TabBackground}):Play()
						self.Animation:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextColor3 = self.getSelectedTheme().TabTextColor}):Play()
						self.Animation:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageColor3 = self.getSelectedTheme().TabTextColor}):Play()
						self.Animation:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
						self.Animation:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
						self.Animation:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
						self.Animation:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
						OtherTabButton.UIStroke.Thickness = 1
						OtherTabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
						local otherGlow = OtherTabButton:FindFirstChild("HoverGlow")
						if otherGlow and otherGlow:IsA("UIStroke") then
							otherGlow.Transparency = 1
						end
					end
				end

				if self.Elements.UIPageLayout.CurrentPage ~= TabPage then
					self.Elements.UIPageLayout:JumpTo(TabPage)
				end

				return true
			end

			tabRecord.Activate = activateTab

			TabButton.Interact.MouseEnter:Connect(function()
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					return
				end
				tabHover = true
				applyTabHoverVisual(0.14)
			end)

			TabButton.Interact.MouseLeave:Connect(function()
				tabHover = false
				UpdateTabColors()
				applyTabHoverVisual(0.14)
			end)
	
			TabButton.Interact.MouseButton1Click:Connect(function()
				if tabRecord.SuppressNextClick then
					tabRecord.SuppressNextClick = false
					return
				end

				activateTab(false)
			end)
	
			-- Preserve module context for Tab:Create* methods where `self` is Tab.
			local Tab = setmetatable({}, { __index = self })
			Tab.__TabRecord = tabRecord
			function Tab:GetInternalRecord()
				return tabRecord
			end
			tabRecord.Tab = Tab
	
			-- Element tracking system for extended API
			local TabElements = {} -- Stores all elements created in this tab
			local TabSections = {}-- Stores all sections created in this tab
	
			-- Helper function to add extended API to all elements
			local function addExtendedAPI(elementObject, elementName, elementType, guiObject)
				local detachable = self.makeElementDetachable and self.makeElementDetachable(guiObject, elementName, elementType) or nil
	
				-- Destroy with tracking removal
				local originalDestroy = elementObject.Destroy
				elementObject.Destroy = function(self)
					if detachable and detachable.Destroy then
						detachable.Destroy()
					end
					if originalDestroy then
						originalDestroy(self)
					end
					-- Remove from tracking
					for i, element in ipairs(TabElements) do
						if element.Object == elementObject then
							table.remove(TabElements, i)
							break
						end
					end
				end
	
				-- Visibility methods
				function elementObject:Show()
					guiObject.Visible = true
				end
	
				function elementObject:Hide()
					guiObject.Visible = false
				end
	
				function elementObject:SetVisible(visible)
					guiObject.Visible = visible
				end
	
				function elementObject:GetParent()
					return Tab
				end
	
				if detachable then
					function elementObject:Detach(position)
						return detachable.Detach(position)
					end
	
					function elementObject:Dock()
						return detachable.Dock()
					end
	
					function elementObject:GetRememberedState()
						return detachable.GetRememberedState()
					end
	
					function elementObject:IsDetached()
						return detachable.IsDetached()
					end
				end
	
				-- Add metadata
				elementObject.Name = elementName
				elementObject.Type = elementType
	
				-- Add to tracking
				table.insert(TabElements, {
					Name = elementName,
					Type = elementType,
					Object = elementObject,
					GuiObject = guiObject
				})
	
				return elementObject
			end
	
			-- Tab utility functions
			function Tab:GetElements()
				return TabElements
			end
	
			function Tab:FindElement(name)
				for _, element in ipairs(TabElements) do
					if element.Name == name then
						return element.Object
					end
				end
				return nil
			end
	
			function Tab:Clear()
				-- Snapshot elements and clear tracking first to avoid
				-- concurrent modification (custom Destroy also removes from TabElements)
				local snapshot = {}
				for i, element in ipairs(TabElements) do
					snapshot[i] = element
				end
				-- Clear tracking table before destroying to prevent index corruption
				for i = #TabElements, 1, -1 do
					TabElements[i] = nil
				end
				-- Now safely destroy each element
				for _, element in ipairs(snapshot) do
					if element.Object and element.Object.Destroy then
						element.Object:Destroy()
					end
				end
			end
	
			-- Button
			function Tab:CreateButton(ButtonSettings)
				local ButtonValue = {}
	
				local Button = self.Elements.Template.Button:Clone()
				Button.Name = ButtonSettings.Name
				Button.Title.Text = ButtonSettings.Name
				Button.Visible = true
				Button.Parent = TabPage
	
				Button.BackgroundTransparency = 1
				Button.UIStroke.Transparency = 1
				Button.Title.TextTransparency = 1
	
				self.Animation:Create(Button, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Button.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Button.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
	
				Button.Interact.MouseButton1Click:Connect(function()
					local Success, Response = pcall(ButtonSettings.Callback)
					-- Prevents animation from trying to play if the button's callback called RayfieldLibrary:Destroy()
					if self.rayfieldDestroyed() then
						return
					end
					if not Success then
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Button.Title.Text = "Callback Error"
						print("Rayfield | "..ButtonSettings.Name.." Callback Error " ..tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Button.Title.Text = ButtonSettings.Name
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					else
						if not ButtonSettings.Ext then
							self.SaveConfiguration(ButtonSettings.Name..'\n')
						end
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						task.wait(0.2)
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end
				end)
	
				Button.MouseEnter:Connect(function()
					self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.7}):Play()
				end)
	
				Button.MouseLeave:Connect(function()
					self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
				end)
	
				function ButtonValue:Set(NewButton)
					Button.Title.Text = NewButton
					Button.Name = NewButton
				end
	
				function ButtonValue:Destroy()
					Button:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ButtonValue, ButtonSettings.Name, "Button", Button)
	
				return ButtonValue
			end
	
			-- ColorPicker
			function Tab:CreateColorPicker(ColorPickerSettings) -- by Throit
				ColorPickerSettings.Type = "ColorPicker"
				local ColorPicker = self.Elements.Template.ColorPicker:Clone()
				local Background = ColorPicker.CPBackground
				local Display = Background.Display
				local Main = Background.MainCP
				local Slider = ColorPicker.ColorSlider
				ColorPicker.ClipsDescendants = true
				ColorPicker.Name = ColorPickerSettings.Name
				ColorPicker.Title.Text = ColorPickerSettings.Name
				ColorPicker.Visible = true
				ColorPicker.Parent = TabPage
				ColorPicker.Size = UDim2.new(1, -10, 0, 45)
				Background.Size = UDim2.new(0, 39, 0, 22)
				Display.BackgroundTransparency = 0
				self.Main.MainPoint.ImageTransparency = 1
				ColorPicker.Interact.Size = UDim2.new(1, 0, 1, 0)
				ColorPicker.Interact.Position = UDim2.new(0.5, 0, 0.5, 0)
				ColorPicker.RGB.Position = UDim2.new(0, 17, 0, 70)
				ColorPicker.HexInput.Position = UDim2.new(0, 17, 0, 90)
				self.Main.ImageTransparency = 1
				Background.BackgroundTransparency = 1
	
				for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
					if rgbinput:IsA("Frame") then
						rgbinput.BackgroundColor3 = self.getSelectedTheme().InputBackground
						rgbinput.UIStroke.Color = self.getSelectedTheme().InputStroke
					end
				end
	
				ColorPicker.HexInput.BackgroundColor3 = self.getSelectedTheme().InputBackground
				ColorPicker.HexInput.UIStroke.Color = self.getSelectedTheme().InputStroke
	
				local opened = false 
				local mouse = Players.LocalPlayer:GetMouse()
				self.Main.Image = "http://www.roblox.com/asset/?id=11415645739"
				local mainDragging = false 
				local sliderDragging = false 
				ColorPicker.Interact.MouseButton1Down:Connect(function()
					task.spawn(function()
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						task.wait(0.2)
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end)
	
					if not opened then
						opened = true 
						self.Animation:Create(Background, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 18, 0, 15)}):Play()
						task.wait(0.1)
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 120)}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 173, 0, 86)}):Play()
						self.Animation:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.289, 0, 0.5, 0)}):Play()
						self.Animation:Create(ColorPicker.RGB, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 40)}):Play()
						self.Animation:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 73)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0.574, 0, 1, 0)}):Play()
						self.Animation:Create(self.Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
						self.Animation:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default and 0.25 or 0.1}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
					else
						opened = false
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 45)}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 39, 0, 22)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 1, 0)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
						self.Animation:Create(ColorPicker.RGB, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 70)}):Play()
						self.Animation:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 90)}):Play()
						self.Animation:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
						self.Animation:Create(self.Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						self.Animation:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
					end
	
				end)
	
				self.UserInputService.InputEnded:Connect(function(input, gameProcessed) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						local wasDragging = mainDragging or sliderDragging
						mainDragging = false
						sliderDragging = false
						if wasDragging and not ColorPickerSettings.Ext then
							self.SaveConfiguration()
						end
					end end)
				self.Main.MouseButton1Down:Connect(function()
					if opened then
						mainDragging = true 
					end
				end)
				self.Main.MainPoint.MouseButton1Down:Connect(function()
					if opened then
						mainDragging = true 
					end
				end)
				Slider.MouseButton1Down:Connect(function()
					sliderDragging = true 
				end)
				Slider.SliderPoint.MouseButton1Down:Connect(function()
					sliderDragging = true 
				end)
				local h,s,v = ColorPickerSettings.Color:ToHSV()
				local color = Color3.fromHSV(h,s,v) 
				local hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
				ColorPicker.HexInput.InputBox.Text = hex
				local function setDisplay()
					--Main
					self.Main.MainPoint.Position = UDim2.new(s,-self.Main.MainPoint.AbsoluteSize.X/2,1-v,-self.Main.MainPoint.AbsoluteSize.Y/2)
					self.Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
					Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
					Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
					--Slider 
					local x = h * Slider.AbsoluteSize.X
					Slider.SliderPoint.Position = UDim2.new(0,x-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
					Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h,1,1)
					local color = Color3.fromHSV(h,s,v) 
					local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
					ColorPicker.HexInput.InputBox.Text = hex
				end
				setDisplay()
				ColorPicker.HexInput.InputBox.FocusLost:Connect(function()
					if not pcall(function()
							local r, g, b = string.match(ColorPicker.HexInput.InputBox.Text, "^#?(%w%w)(%w%w)(%w%w)$")
							local rgbColor = Color3.fromRGB(tonumber(r, 16),tonumber(g, 16), tonumber(b, 16))
							h,s,v = rgbColor:ToHSV()
							hex = ColorPicker.HexInput.InputBox.Text
							setDisplay()
							ColorPickerSettings.Color = rgbColor
						end) 
					then 
						ColorPicker.HexInput.InputBox.Text = hex 
					end
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
					local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					if not ColorPickerSettings.Ext then
						self.SaveConfiguration()
					end
				end)
				--RGB
				local function rgbBoxes(box,toChange)
					local value = tonumber(box.Text) 
					local color = Color3.fromHSV(h,s,v) 
					local oldR,oldG,oldB = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					local save 
					if toChange == "R" then save = oldR;oldR = value elseif toChange == "G" then save = oldG;oldG = value else save = oldB;oldB = value end
					if value then 
						value = math.clamp(value,0,255)
						h,s,v = Color3.fromRGB(oldR,oldG,oldB):ToHSV()
	
						setDisplay()
					else 
						box.Text = tostring(save)
					end
					local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					if not ColorPickerSettings.Ext then
						self.SaveConfiguration(ColorPickerSettings.Flag..'\n'..tostring(ColorPickerSettings.Color))
					end
				end
				ColorPicker.RGB.RInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.RInput.InputBox,"R")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
				ColorPicker.RGB.GInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.GInput.InputBox,"G")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
				ColorPicker.RGB.BInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.BInput.InputBox,"B")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
	
				local prevH, prevS, prevV = h, s, v
				self.RunService.RenderStepped:connect(function()
					if mainDragging then
						local localX = math.clamp(mouse.X-self.Main.AbsolutePosition.X,0,self.Main.AbsoluteSize.X)
						local localY = math.clamp(mouse.Y-self.Main.AbsolutePosition.Y,0,self.Main.AbsoluteSize.Y)
						self.Main.MainPoint.Position = UDim2.new(0,localX-self.Main.MainPoint.AbsoluteSize.X/2,0,localY-self.Main.MainPoint.AbsoluteSize.Y/2)
						s = localX / self.Main.AbsoluteSize.X
						v = 1 - (localY / self.Main.AbsoluteSize.Y)
						local color = Color3.fromHSV(h,s,v)
						Display.BackgroundColor3 = color
						self.Main.MainPoint.ImageColor3 = color
						Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
						local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
						ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
						ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
						ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
						ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
						ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
						if h ~= prevH or s ~= prevS or v ~= prevV then
							prevH, prevS, prevV = h, s, v
							pcall(ColorPickerSettings.Callback, color)
						end
					end
					if sliderDragging then
						local localX = math.clamp(mouse.X-Slider.AbsolutePosition.X,0,Slider.AbsoluteSize.X)
						h = localX / Slider.AbsoluteSize.X
						local color = Color3.fromHSV(h,s,v)
						local hueColor = Color3.fromHSV(h,1,1)
						Display.BackgroundColor3 = color
						Slider.SliderPoint.Position = UDim2.new(0,localX-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
						Slider.SliderPoint.ImageColor3 = hueColor
						Background.BackgroundColor3 = hueColor
						self.Main.MainPoint.ImageColor3 = color
						local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
						ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
						ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
						ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
						ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
						ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
						if h ~= prevH or s ~= prevS or v ~= prevV then
							prevH, prevS, prevV = h, s, v
							pcall(ColorPickerSettings.Callback, color)
						end
					end
				end)
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and ColorPickerSettings.Flag then
						self.RayfieldLibrary.Flags[ColorPickerSettings.Flag] = ColorPickerSettings
					end
				end
	
				function ColorPickerSettings:Set(RGBColor)
					ColorPickerSettings.Color = RGBColor
					h,s,v = ColorPickerSettings.Color:ToHSV()
					color = Color3.fromHSV(h,s,v)
					setDisplay()
				end
	
				ColorPicker.MouseEnter:Connect(function()
					self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
				end)
	
				ColorPicker.MouseLeave:Connect(function()
					self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
						if rgbinput:IsA("Frame") then
							rgbinput.BackgroundColor3 = self.getSelectedTheme().InputBackground
							rgbinput.UIStroke.Color = self.getSelectedTheme().InputStroke
						end
					end
	
					ColorPicker.HexInput.BackgroundColor3 = self.getSelectedTheme().InputBackground
					ColorPicker.HexInput.UIStroke.Color = self.getSelectedTheme().InputStroke
				end)
	
				function ColorPickerSettings:Destroy()
					ColorPicker:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ColorPickerSettings, ColorPickerSettings.Name, "ColorPicker", ColorPicker)
	
				return ColorPickerSettings
			end
	
			-- Section
			function Tab:CreateSection(SectionName)
	
				local SectionValue = {}
	
				if SDone then
					local SectionSpace = self.Elements.Template.SectionSpacing:Clone()
					SectionSpace.Visible = true
					SectionSpace.Parent = TabPage
				end
	
				local Section = self.Elements.Template.SectionTitle:Clone()
				Section.Title.Text = SectionName
				Section.Visible = true
				Section.Parent = TabPage
	
				Section.Title.TextTransparency = 1
				self.Animation:Create(Section.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.4}):Play()
	
				function SectionValue:Set(NewSection)
					Section.Title.Text = NewSection
				end
	
				function SectionValue:Destroy()
					Section:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(SectionValue, SectionName, "Section", Section)
	
				SDone = true
	
				return SectionValue
			end
	
			-- Divider
			function Tab:CreateDivider()
				local DividerValue = {}
	
				local Divider = self.Elements.Template.Divider:Clone()
				Divider.Visible = true
				Divider.Parent = TabPage
	
				Divider.Divider.BackgroundTransparency = 1
				self.Animation:Create(Divider.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
	
				function DividerValue:Set(Value)
					Divider.Visible = Value
				end
	
				function DividerValue:Destroy()
					Divider:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(DividerValue, "Divider", "Divider", Divider)
	
				return DividerValue
			end
	
			-- Label
			function Tab:CreateLabel(LabelText, Icon, Color, IgnoreTheme)
				local LabelValue = {}
	
				local Label = self.Elements.Template.Label:Clone()
				Label.Title.Text = LabelText
				Label.Visible = true
				Label.Parent = TabPage
	
				Label.BackgroundColor3 = Color or self.getSelectedTheme().SecondaryElementBackground
				Label.UIStroke.Color = Color or self.getSelectedTheme().SecondaryElementStroke
	
				if Icon then
					if typeof(Icon) == 'string' and self.Icons then
						local asset = self.getIcon(Icon)
	
						Label.Icon.Image = 'rbxassetid://'..asset.id
						Label.Icon.ImageRectOffset = asset.imageRectOffset
						Label.Icon.ImageRectSize = asset.imageRectSize
					else
						Label.Icon.Image = self.getAssetUri(Icon)
					end
				else
					Label.Icon.Image = "rbxassetid://" .. 0
				end
	
				if Icon and Label:FindFirstChild('Icon') then
					Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
					Label.Title.Size = UDim2.new(1, -100, 0, 14)
	
					if Icon then
						if typeof(Icon) == 'string' and self.Icons then
							local asset = self.getIcon(Icon)
	
							Label.Icon.Image = 'rbxassetid://'..asset.id
							Label.Icon.ImageRectOffset = asset.imageRectOffset
							Label.Icon.ImageRectSize = asset.imageRectSize
						else
							Label.Icon.Image = self.getAssetUri(Icon)
						end
					else
						Label.Icon.Image = "rbxassetid://" .. 0
					end
	
					Label.Icon.Visible = true
				end
	
				Label.Icon.ImageTransparency = 1
				Label.BackgroundTransparency = 1
				Label.UIStroke.Transparency = 1
				Label.Title.TextTransparency = 1
	
				self.Animation:Create(Label, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = Color and 0.8 or 0}):Play()
				self.Animation:Create(Label.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = Color and 0.7 or 0}):Play()
				self.Animation:Create(Label.Icon, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
				self.Animation:Create(Label.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = Color and 0.2 or 0}):Play()	
	
				function LabelValue:Set(NewLabel, Icon, Color)
					Label.Title.Text = NewLabel
	
					if Color then
						Label.BackgroundColor3 = Color or self.getSelectedTheme().SecondaryElementBackground
						Label.UIStroke.Color = Color or self.getSelectedTheme().SecondaryElementStroke
					end
	
					if Icon and Label:FindFirstChild('Icon') then
						Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
						Label.Title.Size = UDim2.new(1, -100, 0, 14)
	
						if Icon then
							if typeof(Icon) == 'string' and self.Icons then
								local asset = self.getIcon(Icon)
	
								Label.Icon.Image = 'rbxassetid://'..asset.id
								Label.Icon.ImageRectOffset = asset.imageRectOffset
								Label.Icon.ImageRectSize = asset.imageRectSize
							else
								Label.Icon.Image = self.getAssetUri(Icon)
							end
						else
							Label.Icon.Image = "rbxassetid://" .. 0
						end
	
						Label.Icon.Visible = true
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Label.BackgroundColor3 = IgnoreTheme and (Color or Label.BackgroundColor3) or self.getSelectedTheme().SecondaryElementBackground
					Label.UIStroke.Color = IgnoreTheme and (Color or Label.BackgroundColor3) or self.getSelectedTheme().SecondaryElementStroke
				end)
	
				function LabelValue:Destroy()
					Label:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(LabelValue, LabelText, "Label", Label)
	
				return LabelValue
			end
	
			-- Paragraph
			function Tab:CreateParagraph(ParagraphSettings)
				local ParagraphValue = {}
	
				local Paragraph = self.Elements.Template.Paragraph:Clone()
				Paragraph.Title.Text = ParagraphSettings.Title
				Paragraph.Content.Text = ParagraphSettings.Content
				Paragraph.Visible = true
				Paragraph.Parent = TabPage
	
				Paragraph.BackgroundTransparency = 1
				Paragraph.UIStroke.Transparency = 1
				Paragraph.Title.TextTransparency = 1
				Paragraph.Content.TextTransparency = 1
	
				Paragraph.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
				Paragraph.UIStroke.Color = self.getSelectedTheme().SecondaryElementStroke
	
				self.Animation:Create(Paragraph, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Paragraph.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Paragraph.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
				self.Animation:Create(Paragraph.Content, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
				function ParagraphValue:Set(NewParagraphSettings)
					Paragraph.Title.Text = NewParagraphSettings.Title
					Paragraph.Content.Text = NewParagraphSettings.Content
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Paragraph.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
					Paragraph.UIStroke.Color = self.getSelectedTheme().SecondaryElementStroke
				end)
	
				function ParagraphValue:Destroy()
					Paragraph:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ParagraphValue, ParagraphSettings.Title, "Paragraph", Paragraph)
	
				return ParagraphValue
			end
	
			-- Input
			function Tab:CreateInput(InputSettings)
				local ctx = self
				local Input = self.Elements.Template.Input:Clone()
				Input.Name = InputSettings.Name
				Input.Title.Text = InputSettings.Name
				Input.Visible = true
				Input.Parent = TabPage
	
				Input.BackgroundTransparency = 1
				Input.UIStroke.Transparency = 1
				Input.Title.TextTransparency = 1
	
				Input.InputFrame.InputBox.Text = InputSettings.CurrentValue or ''
	
				self.bindTheme(Input.InputFrame, "BackgroundColor3", "InputBackground")
				self.bindTheme(Input.InputFrame.UIStroke, "Color", "InputStroke")
	
				self.Animation:Create(Input, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Input.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Input.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	
	
				Input.InputFrame.InputBox.PlaceholderText = InputSettings.PlaceholderText
				Input.InputFrame.Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)
	
				Input.InputFrame.InputBox.FocusLost:Connect(function()
					local Success, Response = pcall(function()
						InputSettings.Callback(Input.InputFrame.InputBox.Text)
						InputSettings.CurrentValue = Input.InputFrame.InputBox.Text
					end)
	
					if not Success then
						self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						self.Animation:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Input.Title.Text = "Callback Error"
						print("Rayfield | "..InputSettings.Name.." Callback Error " ..tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Input.Title.Text = InputSettings.Name
						self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end
	
					if InputSettings.RemoveTextAfterFocusLost then
						Input.InputFrame.InputBox.Text = ""
					end
	
					if not InputSettings.Ext then
						self.SaveConfiguration()
					end
				end)
	
				Input.MouseEnter:Connect(function()
					self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
				end)
	
				Input.MouseLeave:Connect(function()
					self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)
	
				Input.InputFrame.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
					self.Animation:Create(Input.InputFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)}):Play()
				end)
	
				function InputSettings:Set(text)
					Input.InputFrame.InputBox.Text = text
					InputSettings.CurrentValue = text
	
					local Success, Response = pcall(function()
						InputSettings.Callback(text)
					end)
	
					if not InputSettings.Ext then
						ctx.SaveConfiguration()
					end
				end
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and InputSettings.Flag then
						self.RayfieldLibrary.Flags[InputSettings.Flag] = InputSettings
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Input.InputFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
					Input.InputFrame.UIStroke.Color = self.getSelectedTheme().InputStroke
				end)
	
				function InputSettings:Destroy()
					Input:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(InputSettings, InputSettings.Name, "Input", Input)
	
				return InputSettings
			end
	
			-- Dropdown
			function Tab:CreateDropdown(DropdownSettings)
				local ctx = self
				local Dropdown = self.Elements.Template.Dropdown:Clone()
				local function normalizeDropdownOptions(rawOptions)
					local normalized = {}
					if type(rawOptions) ~= "table" then
						if rawOptions ~= nil then
							table.insert(normalized, tostring(rawOptions))
						end
						return normalized
					end
					if #rawOptions > 0 then
						for _, option in ipairs(rawOptions) do
							if option ~= nil then
								table.insert(normalized, tostring(option))
							end
						end
						return normalized
					end
					for _, option in pairs(rawOptions) do
						if option ~= nil then
							table.insert(normalized, tostring(option))
						end
					end
					return normalized
				end

				DropdownSettings.Options = normalizeDropdownOptions(DropdownSettings.Options)
				if string.find(DropdownSettings.Name,"closed") then
					Dropdown.Name = "Dropdown"
				else
					Dropdown.Name = DropdownSettings.Name
				end
				Dropdown.Title.Text = DropdownSettings.Name
				Dropdown.Visible = true
				Dropdown.Parent = TabPage
	
				Dropdown.Size = UDim2.new(1, -10, 0, 45)
				Dropdown.List.Visible = false
				Dropdown.List.ScrollBarImageTransparency = 1
				local function normalizeCurrentOption(rawSelection, allowFallbackToFirst)
					local normalized = {}
					if type(rawSelection) == "string" then
						table.insert(normalized, rawSelection)
					elseif type(rawSelection) == "table" then
						if #rawSelection > 0 then
							for _, value in ipairs(rawSelection) do
								if value ~= nil then
									table.insert(normalized, tostring(value))
								end
							end
						else
							for _, value in pairs(rawSelection) do
								if value ~= nil then
									table.insert(normalized, tostring(value))
								end
							end
						end
					elseif rawSelection ~= nil then
						table.insert(normalized, tostring(rawSelection))
					end

					local filtered = {}
					local seen = {}
					for _, option in ipairs(normalized) do
						local optionName = tostring(option)
						if table.find(DropdownSettings.Options, optionName) and not seen[optionName] then
							seen[optionName] = true
							table.insert(filtered, optionName)
							if not DropdownSettings.MultipleOptions then
								break
							end
						end
					end

					if #filtered == 0 and allowFallbackToFirst and not DropdownSettings.MultipleOptions and DropdownSettings.Options[1] ~= nil then
						filtered = { tostring(DropdownSettings.Options[1]) }
					end

					return filtered
				end

				local function updateSelectedTextFromCurrent()
					if DropdownSettings.MultipleOptions then
						if #DropdownSettings.CurrentOption == 1 then
							Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
						elseif #DropdownSettings.CurrentOption == 0 then
							Dropdown.Selected.Text = "None"
						else
							Dropdown.Selected.Text = "Various"
						end
					else
						Dropdown.Selected.Text = DropdownSettings.CurrentOption[1] or "None"
					end
				end

				local function updateOptionVisuals()
					for _, droption in ipairs(Dropdown.List:GetChildren()) do
						if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" then
							if table.find(DropdownSettings.CurrentOption, droption.Name) then
								droption.BackgroundColor3 = self.getSelectedTheme().DropdownSelected
							else
								droption.BackgroundColor3 = self.getSelectedTheme().DropdownUnselected
							end
						end
					end
				end

				local function applySelectionState(rawSelection, allowFallbackToFirst)
					DropdownSettings.CurrentOption = normalizeCurrentOption(rawSelection, allowFallbackToFirst ~= false)
					updateSelectedTextFromCurrent()
					updateOptionVisuals()
				end

				applySelectionState(DropdownSettings.CurrentOption, true)

				self.bindTheme(Dropdown.Toggle, "ImageColor3", "TextColor")
				
				-- Reactive coloring for Dropdown options
				Dropdown.List.ChildAdded:Connect(function(Option)
					if Option.ClassName == "Frame" and Option.Name ~= "Placeholder" then
						if table.find(DropdownSettings.CurrentOption, Option.Name) then
							self.bindTheme(Option, "BackgroundColor3", "DropdownSelected")
						else
							self.bindTheme(Option, "BackgroundColor3", "DropdownUnselected")
						end
						self.bindTheme(Option.UIStroke, "Color", "ElementStroke")
					end
				end)
	
				Dropdown.Toggle.Rotation = 180
	
				Dropdown.Interact.MouseButton1Click:Connect(function()
					self.Animation:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
					task.wait(0.1)
					self.Animation:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					if self.getDebounce() then return end
					if Dropdown.List.Visible then
						self.setDebounce(true)
						self.Animation:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 45)}):Play()
						for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
							if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "Placeholder" then
								self.Animation:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
								self.Animation:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								self.Animation:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
							end
						end
						self.Animation:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 1}):Play()
						self.Animation:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 180}):Play()
						task.wait(0.35)
						Dropdown.List.Visible = false
						self.setDebounce(false)
					else
						self.Animation:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 180)}):Play()
						Dropdown.List.Visible = true
						self.Animation:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 0.7}):Play()
						self.Animation:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 0}):Play()	
						for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
							if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "Placeholder" then
								if DropdownOpt.Name ~= Dropdown.Selected.Text then
									self.Animation:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
								end
								self.Animation:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
								self.Animation:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
							end
						end
					end
				end)
	
				Dropdown.MouseEnter:Connect(function()
					if not Dropdown.List.Visible then
						self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					end
				end)
	
				Dropdown.MouseLeave:Connect(function()
					self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)
	
				local function SetDropdownOptions()
					local listTemplate = Dropdown.List:FindFirstChild("Template")
					if not listTemplate then
						warn("Rayfield | Dropdown template not found for " .. tostring(DropdownSettings.Name))
						return
					end

					for _, optionObject in ipairs(Dropdown.List:GetChildren()) do
						if optionObject.ClassName == "Frame" and optionObject.Name ~= "Placeholder" and optionObject.Name ~= "Template" then
							optionObject:Destroy()
						end
					end

					for _, Option in ipairs(DropdownSettings.Options) do
						local optionName = tostring(Option)
						local DropdownOption = listTemplate:Clone()
						DropdownOption.Name = optionName
						DropdownOption.Title.Text = optionName
						DropdownOption.Parent = Dropdown.List
						DropdownOption.Visible = true
	
						DropdownOption.BackgroundTransparency = 1
						DropdownOption.UIStroke.Transparency = 1
						DropdownOption.Title.TextTransparency = 1
	
						--local Dropdown = Tab:CreateDropdown({
						--	Name = "Dropdown Example",
						--	Options = {"Option 1","Option 2"},
						--	CurrentOption = {"Option 1"},
						--  MultipleOptions = true,
						--	Flag = "Dropdown1",
						--	Callback = function(TableOfOptions)
	
						--	end,
						--})
	
	
						DropdownOption.Interact.ZIndex = 50
						DropdownOption.Interact.MouseButton1Click:Connect(function()
							if not DropdownSettings.MultipleOptions and table.find(DropdownSettings.CurrentOption, optionName) then 
								return
							end
	
							if table.find(DropdownSettings.CurrentOption, optionName) then
								table.remove(DropdownSettings.CurrentOption, table.find(DropdownSettings.CurrentOption, optionName))
								if DropdownSettings.MultipleOptions then
									if #DropdownSettings.CurrentOption == 1 then
										Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
									elseif #DropdownSettings.CurrentOption == 0 then
										Dropdown.Selected.Text = "None"
									else
										Dropdown.Selected.Text = "Various"
									end
								else
									Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
								end
							else
								if not DropdownSettings.MultipleOptions then
									table.clear(DropdownSettings.CurrentOption)
								end
								table.insert(DropdownSettings.CurrentOption, optionName)
								if DropdownSettings.MultipleOptions then
									if #DropdownSettings.CurrentOption == 1 then
										Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
									elseif #DropdownSettings.CurrentOption == 0 then
										Dropdown.Selected.Text = "None"
									else
										Dropdown.Selected.Text = "Various"
									end
								else
									Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
								end
								self.Animation:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								self.Animation:Create(DropdownOption, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().DropdownSelected}):Play()
								self.setDebounce(true)
							end


							local Success, Response = pcall(function()
								DropdownSettings.Callback(DropdownSettings.CurrentOption)
							end)

							if not Success then
								self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
								self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								Dropdown.Title.Text = "Callback Error"
								print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
								warn('Check docs.sirius.menu for help with Rayfield specific development.')
								task.wait(0.5)
								Dropdown.Title.Text = DropdownSettings.Name
								self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
								self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
							end

							for _, droption in ipairs(Dropdown.List:GetChildren()) do
								if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" and not table.find(DropdownSettings.CurrentOption, droption.Name) then
									self.Animation:Create(droption, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().DropdownUnselected}):Play()
								end
							end
							if not DropdownSettings.MultipleOptions then
								task.wait(0.1)
								self.Animation:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 45)}):Play()
								for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
									if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "Placeholder" then
										self.Animation:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
										self.Animation:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
										self.Animation:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
									end
								end
								self.Animation:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 1}):Play()
								self.Animation:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 180}):Play()
								task.wait(0.35)
								Dropdown.List.Visible = false
							end
							self.setDebounce(false)
							if not DropdownSettings.Ext then
								self.SaveConfiguration()
							end
						end)
	
						self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
							DropdownOption.UIStroke.Color = self.getSelectedTheme().ElementStroke
						end)
					end
				end
				SetDropdownOptions()
	
				for _, droption in ipairs(Dropdown.List:GetChildren()) do
					if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" then
						if not table.find(DropdownSettings.CurrentOption, droption.Name) then
							droption.BackgroundColor3 = self.getSelectedTheme().DropdownUnselected
						else
							droption.BackgroundColor3 = self.getSelectedTheme().DropdownSelected
						end
	
						self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
							if not table.find(DropdownSettings.CurrentOption, droption.Name) then
								droption.BackgroundColor3 = self.getSelectedTheme().DropdownUnselected
							else
								droption.BackgroundColor3 = self.getSelectedTheme().DropdownSelected
							end
						end)
					end
				end
	
				local function emitDropdownCallback(payload)
					local Success, Response = pcall(function()
						DropdownSettings.Callback(payload or DropdownSettings.CurrentOption)
					end)
					if not Success then
						ctx.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						ctx.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Dropdown.Title.Text = "Callback Error"
						print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Dropdown.Title.Text = DropdownSettings.Name
						ctx.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = ctx.getSelectedTheme().ElementBackground}):Play()
						ctx.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end
				end

				function DropdownSettings:Set(NewOption)
					applySelectionState(NewOption, true)
					emitDropdownCallback(DropdownSettings.CurrentOption)
					if not DropdownSettings.Ext then
						self.SaveConfiguration()
					end
				end
	
				function DropdownSettings:Refresh(optionsTable) -- updates a dropdown with new options from optionsTable
					DropdownSettings.Options = normalizeDropdownOptions(optionsTable)
					for _, option in Dropdown.List:GetChildren() do
						if option.ClassName == "Frame" and option.Name ~= "Placeholder" and option.Name ~= "Template" then
							option:Destroy()
						end
					end
					Dropdown.List.Visible = false
					Dropdown.Size = UDim2.new(1, -10, 0, 45)
					Dropdown.Toggle.Rotation = 180
					Dropdown.List.ScrollBarImageTransparency = 1
					SetDropdownOptions()
					applySelectionState(DropdownSettings.CurrentOption, true)
				end
	
				function DropdownSettings:Clear()
					applySelectionState({}, false)
					emitDropdownCallback(DropdownSettings.CurrentOption)
					if not DropdownSettings.Ext then
						self.SaveConfiguration()
					end
				end
	
				function DropdownSettings:Destroy()
					Dropdown:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(DropdownSettings, DropdownSettings.Name, "Dropdown", Dropdown)
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and DropdownSettings.Flag then
						self.RayfieldLibrary.Flags[DropdownSettings.Flag] = DropdownSettings
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Dropdown.Toggle.ImageColor3 = self.getSelectedTheme().TextColor
					self.Animation:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)
	
				return DropdownSettings
			end
	
			-- Keybind
			function Tab:CreateKeybind(KeybindSettings)
				local ctx = self
				local CheckingForKey = false
				local Keybind = self.Elements.Template.Keybind:Clone()
				Keybind.Name = KeybindSettings.Name
				Keybind.Title.Text = KeybindSettings.Name
				Keybind.Visible = true
				Keybind.Parent = TabPage
	
				Keybind.BackgroundTransparency = 1
				Keybind.UIStroke.Transparency = 1
				Keybind.Title.TextTransparency = 1
	
				Keybind.KeybindFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
				Keybind.KeybindFrame.UIStroke.Color = self.getSelectedTheme().InputStroke
	
				self.Animation:Create(Keybind, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Keybind.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Keybind.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	
	
				Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
				Keybind.KeybindFrame.Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)
	
				Keybind.KeybindFrame.KeybindBox.Focused:Connect(function()
					CheckingForKey = true
					Keybind.KeybindFrame.KeybindBox.Text = ""
				end)
				Keybind.KeybindFrame.KeybindBox.FocusLost:Connect(function()
					CheckingForKey = false
					if Keybind.KeybindFrame.KeybindBox.Text == nil or Keybind.KeybindFrame.KeybindBox.Text == "" then
						Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
						if not KeybindSettings.Ext then
							self.SaveConfiguration()
						end
					end
				end)
	
				Keybind.MouseEnter:Connect(function()
					self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
				end)
	
				Keybind.MouseLeave:Connect(function()
					self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)
	
				local connection = self.UserInputService.InputBegan:Connect(function(input, processed)
					if CheckingForKey then
						if input.KeyCode ~= Enum.KeyCode.Unknown then
							local SplitMessage = string.split(tostring(input.KeyCode), ".")
							local NewKeyNoEnum = SplitMessage[3]
							Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeyNoEnum)
							KeybindSettings.CurrentKeybind = tostring(NewKeyNoEnum)
							Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
							if not KeybindSettings.Ext then
								self.SaveConfiguration()
							end
	
							if KeybindSettings.CallOnChange then
								KeybindSettings.Callback(tostring(NewKeyNoEnum))
							end
						end
					elseif not KeybindSettings.CallOnChange and KeybindSettings.CurrentKeybind ~= nil and (input.KeyCode == Enum.KeyCode[KeybindSettings.CurrentKeybind] and not processed) then -- Test
						local Held = true
						local Connection
						Connection = input.Changed:Connect(function(prop)
							if prop == "UserInputState" then
								Connection:Disconnect()
								Held = false
							end
						end)
	
						if not KeybindSettings.HoldToInteract then
							local Success, Response = pcall(KeybindSettings.Callback)
							if not Success then
								self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
								self.Animation:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								Keybind.Title.Text = "Callback Error"
								print("Rayfield | "..KeybindSettings.Name.." Callback Error " ..tostring(Response))
								warn('Check docs.sirius.menu for help with Rayfield specific development.')
								task.wait(0.5)
								Keybind.Title.Text = KeybindSettings.Name
								self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
								self.Animation:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
							end
						else
							task.wait(0.25)
							if Held then
								local Loop; Loop = self.RunService.Stepped:Connect(function()
									if not Held then
										KeybindSettings.Callback(false) -- maybe pcall this
										Loop:Disconnect()
									else
										KeybindSettings.Callback(true) -- maybe pcall this
									end
								end)
							end
						end
					end
				end)
				table.insert(self.keybindConnections, connection)

				Keybind.KeybindFrame.KeybindBox:GetPropertyChangedSignal("Text"):Connect(function()
					self.Animation:Create(Keybind.KeybindFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)}):Play()
				end)
	
				function KeybindSettings:Set(NewKeybind)
					Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeybind)
					KeybindSettings.CurrentKeybind = tostring(NewKeybind)
					Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
					if not KeybindSettings.Ext then
						ctx.SaveConfiguration()
					end
	
					if KeybindSettings.CallOnChange then
						KeybindSettings.Callback(tostring(NewKeybind))
					end
				end
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and KeybindSettings.Flag then
						self.RayfieldLibrary.Flags[KeybindSettings.Flag] = KeybindSettings
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Keybind.KeybindFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
					Keybind.KeybindFrame.UIStroke.Color = self.getSelectedTheme().InputStroke
				end)
	
				function KeybindSettings:Destroy()
					Keybind:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(KeybindSettings, KeybindSettings.Name, "Keybind", Keybind)
	
				return KeybindSettings
			end
	
			-- Toggle
			function Tab:CreateToggle(ToggleSettings)
				local ctx = self
				local ToggleValue = {}
	
				local Toggle = self.Elements.Template.Toggle:Clone()
				Toggle.Name = ToggleSettings.Name
				Toggle.Title.Text = ToggleSettings.Name
				Toggle.Visible = true
				Toggle.Parent = TabPage
	
				Toggle.BackgroundTransparency = 1
				Toggle.UIStroke.Transparency = 1
				Toggle.Title.TextTransparency = 1
				self.bindTheme(Toggle.Switch, "BackgroundColor3", "ToggleBackground")
	
				if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
					Toggle.Switch.Shadow.Visible = false
				end
	
				self.Animation:Create(Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Toggle.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	
	
				local function UpdateToggleColors()
					if ToggleSettings.CurrentValue == true then
						Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleEnabledStroke
						Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleEnabled
						Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleEnabledOuterStroke
					else
						Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleDisabledStroke
						Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleDisabled
						Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleDisabledOuterStroke
					end
				end

				-- Reactive Toggle Colors
				local themeValueFolder = self.Main:FindFirstChild("ThemeValues")
				if themeValueFolder then
					themeValueFolder:FindFirstChild("Background").Changed:Connect(UpdateToggleColors)
				end
				
				UpdateToggleColors()
	
				Toggle.MouseEnter:Connect(function()
					self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
				end)
	
				Toggle.MouseLeave:Connect(function()
					self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)
	
				Toggle.Interact.MouseButton1Click:Connect(function()
					if ToggleSettings.CurrentValue == true then
						ToggleSettings.CurrentValue = false
						self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
						self.Animation:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleDisabledStroke}):Play()
						self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = self.getSelectedTheme().ToggleDisabled}):Play()
						self.Animation:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleDisabledOuterStroke}):Play()
						self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()	
					else
						ToggleSettings.CurrentValue = true
						self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
						self.Animation:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleEnabledStroke}):Play()
						self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = self.getSelectedTheme().ToggleEnabled}):Play()
						self.Animation:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleEnabledOuterStroke}):Play()
						self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()		
					end
	
					local Success, Response = pcall(function()
						if debugX then warn('Running toggle \''..ToggleSettings.Name..'\' (Interact)') end
	
						ToggleSettings.Callback(ToggleSettings.CurrentValue)
					end)
	
					if not Success then
						self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Toggle.Title.Text = "Callback Error"
						print("Rayfield | "..ToggleSettings.Name.." Callback Error " ..tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Toggle.Title.Text = ToggleSettings.Name
						self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end
	
					if not ToggleSettings.Ext then
						self.SaveConfiguration()
					end
				end)
	
				function ToggleSettings:Set(NewToggleValue)
					if NewToggleValue == true then
						ToggleSettings.CurrentValue = true
						ctx.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = ctx.getSelectedTheme().ElementBackgroundHover}):Play()
						ctx.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = ctx.getSelectedTheme().ToggleEnabledStroke}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = ctx.getSelectedTheme().ToggleEnabled}):Play()
						ctx.Animation:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = ctx.getSelectedTheme().ToggleEnabledOuterStroke}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()	
						ctx.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = ctx.getSelectedTheme().ElementBackground}):Play()
						ctx.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()	
					else
						ToggleSettings.CurrentValue = false
						ctx.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = ctx.getSelectedTheme().ElementBackgroundHover}):Play()
						ctx.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = ctx.getSelectedTheme().ToggleDisabledStroke}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = ctx.getSelectedTheme().ToggleDisabled}):Play()
						ctx.Animation:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = ctx.getSelectedTheme().ToggleDisabledOuterStroke}):Play()
						ctx.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
						ctx.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = ctx.getSelectedTheme().ElementBackground}):Play()
						ctx.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()	
					end
	
					local Success, Response = pcall(function()
						if debugX then warn('Running toggle \''..ToggleSettings.Name..'\' (:Set)') end
	
						ToggleSettings.Callback(ToggleSettings.CurrentValue)
					end)
	
					if not Success then
						ctx.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						ctx.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Toggle.Title.Text = "Callback Error"
						print("Rayfield | "..ToggleSettings.Name.." Callback Error " ..tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Toggle.Title.Text = ToggleSettings.Name
						ctx.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = ctx.getSelectedTheme().ElementBackground}):Play()
						ctx.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end
	
					if not ToggleSettings.Ext then
						ctx.SaveConfiguration()
					end
				end
	
				if not ToggleSettings.Ext then
					if Settings.ConfigurationSaving then
						if Settings.ConfigurationSaving.Enabled and ToggleSettings.Flag then
							self.RayfieldLibrary.Flags[ToggleSettings.Flag] = ToggleSettings
						end
					end
				end
	
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Toggle.Switch.BackgroundColor3 = self.getSelectedTheme().ToggleBackground
	
					if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
						Toggle.Switch.Shadow.Visible = false
					end
	
					task.wait()
	
					if not ToggleSettings.CurrentValue then
						Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleDisabledStroke
						Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleDisabled
						Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleDisabledOuterStroke
					else
						Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleEnabledStroke
						Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleEnabled
						Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleEnabledOuterStroke
					end
				end)
	
				function ToggleSettings:Destroy()
					Toggle:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ToggleSettings, ToggleSettings.Name, "Toggle", Toggle)
	
				return ToggleSettings
			end
	
			-- Slider
			function Tab:CreateSlider(SliderSettings)
				local ctx = self
				local SLDragging = false
				local Slider = self.Elements.Template.Slider:Clone()
				Slider.Name = SliderSettings.Name
				Slider.Title.Text = SliderSettings.Name
				Slider.Visible = true
				Slider.Parent = TabPage
	
				Slider.BackgroundTransparency = 1
				Slider.UIStroke.Transparency = 1
				Slider.Title.TextTransparency = 1
	
				if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
					Slider.Main.Shadow.Visible = false
				end
	
				self.bindTheme(Slider.Main, "BackgroundColor3", "SliderBackground")
				self.bindTheme(Slider.Main.UIStroke, "Color", "SliderStroke")
				self.bindTheme(Slider.Main.Progress.UIStroke, "Color", "SliderStroke")
				self.bindTheme(Slider.Main.Progress, "BackgroundColor3", "SliderProgress")
	
				self.Animation:Create(Slider, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Slider.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Slider.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	
	
				Slider.Main.Progress.Size =	UDim2.new(0, Slider.Main.AbsoluteSize.X * ((SliderSettings.CurrentValue + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (SliderSettings.CurrentValue / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0)
	
				if not SliderSettings.Suffix then
					Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue)
				else
					Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue) .. " " .. SliderSettings.Suffix
				end
	
				Slider.MouseEnter:Connect(function()
					self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
				end)
	
				Slider.MouseLeave:Connect(function()
					self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)
	
				Slider.Main.Interact.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then 
						self.Animation:Create(Slider.Main.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						self.Animation:Create(Slider.Main.Progress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						SLDragging = true 
					end 
				end)
	
				Slider.Main.Interact.InputEnded:Connect(function(Input) 
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then 
						self.Animation:Create(Slider.Main.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
						self.Animation:Create(Slider.Main.Progress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.3}):Play()
						SLDragging = false 
					end 
				end)
	
				Slider.Main.Interact.MouseButton1Down:Connect(function(X)
					local Current = Slider.Main.Progress.AbsolutePosition.X + Slider.Main.Progress.AbsoluteSize.X
					local Start = Current
					local Location = X
					local sliderProgressTween = nil
					local sliderProgressTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
					local Loop; Loop = self.RunService.Stepped:Connect(function()
						if SLDragging then
							Location = self.UserInputService:GetMouseLocation().X
							Current = Current + 0.025 * (Location - Start)
	
							if Location < Slider.Main.AbsolutePosition.X then
								Location = Slider.Main.AbsolutePosition.X
							elseif Location > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
								Location = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
							end
	
							if Current < Slider.Main.AbsolutePosition.X + 5 then
								Current = Slider.Main.AbsolutePosition.X + 5
							elseif Current > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
								Current = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
							end
	
							if Current <= Location and (Location - Start) < 0 then
								Start = Location
							elseif Current >= Location and (Location - Start) > 0 then
								Start = Location
							end
							if sliderProgressTween then
								sliderProgressTween:Cancel()
							end
							sliderProgressTween = self.Animation:Create(Slider.Main.Progress, sliderProgressTweenInfo, {Size = UDim2.new(0, Current - Slider.Main.AbsolutePosition.X, 1, 0)})
							sliderProgressTween:Play()
							local NewValue = SliderSettings.Range[1] + (Location - Slider.Main.AbsolutePosition.X) / Slider.Main.AbsoluteSize.X * (SliderSettings.Range[2] - SliderSettings.Range[1])
	
							NewValue = math.floor(NewValue / SliderSettings.Increment + 0.5) * (SliderSettings.Increment * 10000000) / 10000000
							NewValue = math.clamp(NewValue, SliderSettings.Range[1], SliderSettings.Range[2])
	
							if not SliderSettings.Suffix then
								Slider.Main.Information.Text = tostring(NewValue)
							else
								Slider.Main.Information.Text = tostring(NewValue) .. " " .. SliderSettings.Suffix
							end
	
							if SliderSettings.CurrentValue ~= NewValue then
								local Success, Response = pcall(function()
									SliderSettings.Callback(NewValue)
								end)
								if not Success then
									self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
									self.Animation:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
									Slider.Title.Text = "Callback Error"
									print("Rayfield | "..SliderSettings.Name.." Callback Error " ..tostring(Response))
									warn('Check docs.sirius.menu for help with Rayfield specific development.')
									task.wait(0.5)
									Slider.Title.Text = SliderSettings.Name
									self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
									self.Animation:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
								end
	
								SliderSettings.CurrentValue = NewValue
								if not SliderSettings.Ext then
									self.SaveConfiguration()
								end
							end
						else
							self.Animation:Create(Slider.Main.Progress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, Location - Slider.Main.AbsolutePosition.X > 5 and Location - Slider.Main.AbsolutePosition.X or 5, 1, 0)}):Play()
							Loop:Disconnect()
						end
					end)
				end)
	
				function SliderSettings:Set(NewVal)
					local NewVal = math.clamp(NewVal, SliderSettings.Range[1], SliderSettings.Range[2])
	
					ctx.Animation:Create(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, Slider.Main.AbsoluteSize.X * ((NewVal + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (NewVal / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0)}):Play()
					Slider.Main.Information.Text = tostring(NewVal) .. " " .. (SliderSettings.Suffix or "")
	
					local Success, Response = pcall(function()
						SliderSettings.Callback(NewVal)
					end)
	
					if not Success then
						ctx.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						ctx.Animation:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Slider.Title.Text = "Callback Error"
						print("Rayfield | "..SliderSettings.Name.." Callback Error " ..tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Slider.Title.Text = SliderSettings.Name
						ctx.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = ctx.getSelectedTheme().ElementBackground}):Play()
						ctx.Animation:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end
	
					SliderSettings.CurrentValue = NewVal
					if not SliderSettings.Ext then
						ctx.SaveConfiguration()
					end
				end
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and SliderSettings.Flag then
						self.RayfieldLibrary.Flags[SliderSettings.Flag] = SliderSettings
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
						Slider.Main.Shadow.Visible = false
					end
	
					Slider.Main.BackgroundColor3 = self.getSelectedTheme().SliderBackground
					Slider.Main.UIStroke.Color = self.getSelectedTheme().SliderStroke
					Slider.Main.Progress.UIStroke.Color = self.getSelectedTheme().SliderStroke
					Slider.Main.Progress.BackgroundColor3 = self.getSelectedTheme().SliderProgress
				end)
	
				function SliderSettings:Destroy()
					Slider:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(SliderSettings, SliderSettings.Name, "Slider", Slider)
	
				return SliderSettings
			end

			local function normalizeBarSettings(rawSettings, defaults)
				local settings = rawSettings or {}
				settings.Name = settings.Name or defaults.name
				settings.Range = settings.Range or {0, 100}

				local rangeMin = tonumber(settings.Range[1]) or 0
				local rangeMax = tonumber(settings.Range[2]) or 100
				if rangeMax <= rangeMin then
					rangeMax = rangeMin + 1
				end
				settings.Range = {rangeMin, rangeMax}

				settings.Increment = tonumber(settings.Increment) or 1
				if settings.Increment <= 0 then
					settings.Increment = 1
				end

				local currentValue = tonumber(settings.CurrentValue)
				if currentValue == nil then
					currentValue = rangeMin
				end
				settings.CurrentValue = math.clamp(currentValue, rangeMin, rangeMax)

				if type(settings.Callback) ~= "function" then
					settings.Callback = function() end
				end

				if settings.Draggable == nil then
					settings.Draggable = defaults.draggable
				end

				settings.Type = defaults.typeName
				return settings
			end

			local function createCustomBar(rawSettings, customOptions)
				local ctx = self
				customOptions = customOptions or {}
				local barSettings = normalizeBarSettings(rawSettings, {
					name = customOptions.defaultName or "Bar",
					draggable = customOptions.defaultDraggable ~= false,
					typeName = customOptions.typeName or "Bar"
				})
				local showText = customOptions.showText == true
				local statusMode = customOptions.statusMode == true
				local barMin = barSettings.Range[1]
				local barMax = barSettings.Range[2]
				local barDragging = false

				local Bar = self.Elements.Template.Slider:Clone()
				Bar.Name = barSettings.Name
				Bar.Title.Text = barSettings.Name
				Bar.Visible = true
				Bar.Parent = TabPage

				Bar.BackgroundTransparency = 1
				Bar.UIStroke.Transparency = 1
				Bar.Title.TextTransparency = 1

				local BarMain = Bar.Main
				local BarProgress = BarMain.Progress
				local BarValueLabel = BarMain.Information

				if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
					BarMain.Shadow.Visible = false
				end

				self.bindTheme(BarMain, "BackgroundColor3", "SliderBackground")
				self.bindTheme(BarMain.UIStroke, "Color", "SliderStroke")
				self.bindTheme(BarProgress.UIStroke, "Color", "SliderStroke")
				self.bindTheme(BarProgress, "BackgroundColor3", "SliderProgress")

				self.Animation:Create(Bar, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Bar.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

				if showText then
					BarValueLabel.Visible = true
					if statusMode then
						BarValueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
						BarValueLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
						BarValueLabel.Size = UDim2.new(1, -8, 1, 0)
						BarValueLabel.TextXAlignment = Enum.TextXAlignment.Center
						BarValueLabel.TextYAlignment = Enum.TextYAlignment.Center
						BarValueLabel.ZIndex = BarProgress.ZIndex + 2
						BarValueLabel.TextStrokeTransparency = 0.7
						if barSettings.TextSize then
							BarValueLabel.TextSize = barSettings.TextSize
						end
					end
				else
					BarValueLabel.Visible = false
					BarValueLabel.TextTransparency = 1
				end

				local function ensureCorner(target, radiusPx)
					local corner = target:FindFirstChildWhichIsA("UICorner")
					if not corner then
						corner = Instance.new("UICorner")
						corner.Parent = target
					end
					corner.CornerRadius = UDim.new(0, radiusPx)
				end

				local function applyBarGeometry()
					local desiredHeight = tonumber(barSettings.Height) or tonumber(barSettings.BarHeight)
					if statusMode and not desiredHeight and barSettings.AutoHeight ~= false then
						local textSize = tonumber(barSettings.TextSize) or (BarValueLabel and BarValueLabel.TextSize or 14)
						desiredHeight = math.clamp(math.floor(textSize + 12), 26, 44)
					end

					if desiredHeight then
						desiredHeight = math.max(12, math.floor(desiredHeight))
						local baseYOffset = BarMain.Position.Y.Offset
						if baseYOffset <= 0 then
							baseYOffset = 24
						end
						BarMain.Size = UDim2.new(BarMain.Size.X.Scale, BarMain.Size.X.Offset, 0, desiredHeight)
						Bar.Size = UDim2.new(1, -10, 0, baseYOffset + desiredHeight + 10)
					end

					if statusMode or barSettings.Roundness then
						local roundness = tonumber(barSettings.Roundness)
						if not roundness then
							local sourceHeight = BarMain.Size.Y.Offset
							roundness = math.max(6, math.floor(sourceHeight / 2))
						end
						ensureCorner(BarMain, roundness)
						ensureCorner(BarProgress, roundness)
					end
				end

				applyBarGeometry()

				local function formatBarText(value)
					if not showText then
						return ""
					end

					local percent = ((value - barMin) / (barMax - barMin)) * 100
					if type(barSettings.TextFormatter) == "function" then
						local ok, custom = pcall(barSettings.TextFormatter, value, barMax, percent)
						if ok and custom ~= nil then
							return tostring(custom)
						end
					end

					local defaultText = tostring(value) .. "/" .. tostring(barMax)
					if barSettings.Suffix and tostring(barSettings.Suffix) ~= "" then
						defaultText = defaultText .. " " .. tostring(barSettings.Suffix)
					end
					return defaultText
				end

				local function valueToWidth(value)
					local width = BarMain.AbsoluteSize.X
					if width <= 0 then
						return 0
					end
					local ratio = math.clamp((value - barMin) / (barMax - barMin), 0, 1)
					local result = width * ratio
					if ratio > 0 and result < 5 then
						result = 5
					end
					return result
				end

				local function applyVisualValue(value, animate)
					local targetWidth = valueToWidth(value)
					if animate then
						self.Animation:Create(BarProgress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, targetWidth, 1, 0)}):Play()
					else
						BarProgress.Size = UDim2.new(0, targetWidth, 1, 0)
					end

					if showText and BarValueLabel then
						BarValueLabel.Text = formatBarText(value)
					end
				end

				local function triggerCallback(nextValue)
					local Success, Response = pcall(function()
						barSettings.Callback(nextValue)
					end)

					if not Success then
						self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Bar.Title.Text = "Callback Error"
						print("Rayfield | " .. barSettings.Name .. " Callback Error " .. tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Bar.Title.Text = barSettings.Name
						self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end

					return Success
				end

				local function normalizeValue(rawValue)
					local value = math.clamp(tonumber(rawValue) or barMin, barMin, barMax)
					value = math.floor((value / barSettings.Increment) + 0.5) * barSettings.Increment
					value = math.floor((value * 10000000) + 0.5) / 10000000
					return math.clamp(value, barMin, barMax)
				end

				local function applyBarValue(rawValue, opts)
					opts = opts or {}
					local nextValue = normalizeValue(rawValue)
					local changed = barSettings.CurrentValue ~= nextValue
					applyVisualValue(nextValue, opts.animate ~= false)

					if changed or opts.forceCallback then
						local callbackSuccess = triggerCallback(nextValue)
						barSettings.CurrentValue = nextValue

						if callbackSuccess and opts.persist and not barSettings.Ext then
							self.SaveConfiguration()
						end
					end
				end

				applyVisualValue(barSettings.CurrentValue, false)
				task.defer(function()
					if Bar and Bar.Parent then
						applyVisualValue(barSettings.CurrentValue, false)
					end
				end)

				Bar.MouseEnter:Connect(function()
					self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
				end)

				Bar.MouseLeave:Connect(function()
					self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
				end)

				BarMain.Interact.InputBegan:Connect(function(Input)
					if not barSettings.Draggable then
						return
					end
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						self.Animation:Create(BarMain.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						self.Animation:Create(BarProgress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						barDragging = true
					end
				end)

				BarMain.Interact.InputEnded:Connect(function(Input)
					if not barSettings.Draggable then
						return
					end
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						self.Animation:Create(BarMain.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
						self.Animation:Create(BarProgress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.3}):Play()
						barDragging = false
					end
				end)

				BarMain.Interact.MouseButton1Down:Connect(function(mouseX)
					if not barSettings.Draggable then
						return
					end

					local currentX = BarProgress.AbsolutePosition.X + BarProgress.AbsoluteSize.X
					local startX = currentX
					local locationX = mouseX
					local progressTween = nil
					local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

					local loopConn
					loopConn = self.RunService.Stepped:Connect(function()
						if barDragging then
							locationX = self.UserInputService:GetMouseLocation().X
							currentX = currentX + 0.025 * (locationX - startX)

							local minX = BarMain.AbsolutePosition.X
							local maxX = BarMain.AbsolutePosition.X + BarMain.AbsoluteSize.X

							if locationX < minX then
								locationX = minX
							elseif locationX > maxX then
								locationX = maxX
							end

							if currentX < minX + 5 then
								currentX = minX + 5
							elseif currentX > maxX then
								currentX = maxX
							end

							if (currentX <= locationX and (locationX - startX) < 0) or (currentX >= locationX and (locationX - startX) > 0) then
								startX = locationX
							end

							if progressTween then
								progressTween:Cancel()
							end
							progressTween = self.Animation:Create(BarProgress, tweenInfo, {Size = UDim2.new(0, currentX - minX, 1, 0)})
							progressTween:Play()

							local nextValue = barMin + ((locationX - minX) / math.max(1, BarMain.AbsoluteSize.X)) * (barMax - barMin)
							if barSettings.CurrentValue ~= normalizeValue(nextValue) then
								applyBarValue(nextValue, {animate = false, persist = true})
							end
						else
							self.Animation:Create(BarProgress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
								Size = UDim2.new(0, locationX - BarMain.AbsolutePosition.X > 5 and locationX - BarMain.AbsolutePosition.X or 5, 1, 0)
							}):Play()

							if loopConn then
								loopConn:Disconnect()
							end
						end
					end)
				end)

				function barSettings:Set(NewVal)
					applyBarValue(NewVal, {animate = true, persist = true, forceCallback = true})
				end

				function barSettings:Get()
					return barSettings.CurrentValue
				end

				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and barSettings.Flag then
						self.RayfieldLibrary.Flags[barSettings.Flag] = barSettings
					end
				end

				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
						BarMain.Shadow.Visible = false
					end

					BarMain.BackgroundColor3 = self.getSelectedTheme().SliderBackground
					BarMain.UIStroke.Color = self.getSelectedTheme().SliderStroke
					BarProgress.UIStroke.Color = self.getSelectedTheme().SliderStroke
					BarProgress.BackgroundColor3 = self.getSelectedTheme().SliderProgress
					if showText and BarValueLabel then
						BarValueLabel.TextColor3 = self.getSelectedTheme().TextColor
					end
				end)

				function barSettings:Destroy()
					Bar:Destroy()
				end

				addExtendedAPI(barSettings, barSettings.Name, customOptions.typeName or "Bar", Bar)
				return barSettings
			end

			function Tab:CreateTrackBar(TrackBarSettings)
				return createCustomBar(TrackBarSettings, {
					defaultName = "Track Bar",
					defaultDraggable = true,
					showText = false,
					statusMode = false,
					typeName = "TrackBar"
				})
			end

			function Tab:CreateStatusBar(StatusBarSettings)
				return createCustomBar(StatusBarSettings, {
					defaultName = "Status Bar",
					defaultDraggable = false,
					showText = true,
					statusMode = true,
					typeName = "StatusBar"
				})
			end

			function Tab:CreateDragBar(settings)
				return self:CreateTrackBar(settings)
			end

			function Tab:CreateSliderLite(settings)
				return self:CreateTrackBar(settings)
			end

			function Tab:CreateInfoBar(settings)
				return self:CreateStatusBar(settings)
			end

			function Tab:CreateSliderDisplay(settings)
				return self:CreateStatusBar(settings)
			end
	
			self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
				TabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
	
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected
					TabButton.Image.ImageColor3 = self.getSelectedTheme().SelectedTabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().SelectedTabTextColor
				else
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackground
					TabButton.Image.ImageColor3 = self.getSelectedTheme().TabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().TabTextColor
				end
			end)
	
			return Tab
		end

	
	-- Export function
	self.CreateTab = CreateTab
	self.getFirstTab = function() return FirstTab end
	
	return self
end

return ElementsModule
