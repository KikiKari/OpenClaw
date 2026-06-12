-- OpenClaw nginx gateway routing plugin (ngx_lua / OpenResty)
local cjson = require "cjson"

local nodes = {
    "gateway1.openclaw.internal",
    "gateway2.openclaw.internal",
}

local function get_node()
    return nodes[math.random(#nodes)]
end

local target = get_node()
ngx.var.upstream = target
ngx.log(ngx.INFO, "OpenClaw routing to: " .. target)