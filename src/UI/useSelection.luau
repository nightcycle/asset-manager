--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local Selection = game:GetService("Selection")
return function(override: { Instance }?): { Instance }
	local selection, setSelection = React.useState(override or Selection:Get())
	React.useEffect(function(): (() -> ())?
		if override then
			return nil
		end
		setSelection(Selection:Get())
		local connection = Selection.SelectionChanged:Connect(function()
			setSelection(Selection:Get())
		end)
		return function()
			connection:Disconnect()
		end
	end, { override } :: { unknown })
	return override or selection
end
