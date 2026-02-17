local Cleanup = {}

function Cleanup.disconnectAll(connections)
	if type(connections) ~= "table" then
		return
	end
	for i = #connections, 1, -1 do
		local conn = connections[i]
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
		connections[i] = nil
	end
end

return Cleanup