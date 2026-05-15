-- Order is important.

if not require("alex.environments").should_setup then
    return
end

require("alex.options")
require("alex.lazy")
require("alex.native")
require("alex.keymaps")
