local Visibility = {}

function Visibility.show(element)
	if type(element) == "table" and type(element.Show) == "function" then
		return element:Show()
	end
end

function Visibility.hide(element)
	if type(element) == "table" and type(element.Hide) == "function" then
		return element:Hide()
	end
end

function Visibility.set(element, isVisible)
	if type(element) == "table" and type(element.SetVisible) == "function" then
		return element:SetVisible(isVisible)
	end
end

return Visibility