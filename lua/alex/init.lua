-- Order is important.

if not require("alex.environments").should_setup() then return end

require("alex.native")
require("alex.managers.lazy")
require("alex.keymaps").init()
