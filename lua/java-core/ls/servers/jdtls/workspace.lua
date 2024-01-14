local util = require('lspconfig.util')

local join = util.path.join

local M = {}

local env = {
	HOME = vim.loop.os_homedir(),
	XDG_CACHE_HOME = os.getenv('XDG_CACHE_HOME'),
}

---Returns the default workspace directory
---@return string
function M.get_default_workspace()
	local cache_dir = env.XDG_CACHE_HOME and env.XDG_CACHE_HOME
		or join(env.HOME, '.cache')
  local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
	local path =
		join(cache_dir, 'nvim', 'jdtls', 'workspaces', 'common-workspace', project_name)

	return path
end

return M
