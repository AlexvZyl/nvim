-- Order is important.

if not require("alex.environments").should_setup then
    return
end

require("alex.native.options")
require("alex.loader")
require("alex.native")
require("alex.keymaps").init()
