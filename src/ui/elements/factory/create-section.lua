local CreateSection = {}

function CreateSection.execute(tabObject, ...)
	if type(tabObject) == "table" and type(tabObject.CreateSection) == "function" then
		return tabObject:CreateSection(...)
	end
	error("CreateSection.execute expects a tab object returned from :CreateTab")
end

return CreateSection