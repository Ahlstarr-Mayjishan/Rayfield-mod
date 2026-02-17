local Destroy = {}

function Destroy.execute(element)
	if type(element) == "table" and type(element.Destroy) == "function" then
		return element:Destroy()
	end
end

return Destroy