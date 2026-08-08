local U = require("alex.utils.lua")

-- TODO: This will break.
if not U.in_home_dir("Dev/Repos/lumen-labs-game") then
    return
end

require("alex.keymaps").godot()
