local log = require('java-core.utils.log')
local class = require('java-core.utils.class')
local async = require('java-core.utils.async')
local await = async.wait_handle_error

---@alias java-core.JdtlsRequestMethod
---| 'workspace/executeCommand'
---| 'java/inferSelection'
---| 'java/getRefactorEdit'
---| 'java/buildWorkspace'
---| 'java/checkConstructorsStatus'
---| 'java/generateConstructors'

---@alias jdtls.CodeActionCommand
---| 'extractVariable'
---| 'assignVariable'
---| 'extractVariableAllOccurrence'
---| 'extractConstant'
---| 'extractMethod'
---| 'extractField'
---| 'extractInterface'
---| 'changeSignature'
---| 'assignField'
---| 'convertVariableToField'
---| 'invertVariable'
---| 'introduceParameter'
---| 'convertAnonymousClassToNestedCommand'

---@class jdtls.RefactorWorkspaceEdit
---@field edit lsp.WorkspaceEdit
---@field command? lsp.Command
---@field errorMessage? string

---@class jdtls.SelectionInfo
---@field name string
---@field length number
---@field offset number
---@field params? string[]

---@class java-core.JdtlsClient
---@field client LspClient
local JdtlsClient = class()

function JdtlsClient:_init(client)
	self.client = client
end

---Sends a LSP request
---@param method java-core.JdtlsRequestMethod
---@param params lsp.LSPAny
---@param buffer? number
function JdtlsClient:request(method, params, buffer)
	log.debug('sending LSP request: ' .. method)

	return await(function(callback)
		local on_response = function(err, result)
			if err then
				log.error(method .. ' failed! arguments: ', params, ' error: ', err)
			else
				log.debug(method .. ' success! response: ', result)
			end

			callback(err, result)
		end

		return self.client.request(method, params, on_response, buffer)
	end)
end

---Sends a notification to LSP
---Returns true if the notification sent successfully
---@param method string
---@param params table
---@return boolean
function JdtlsClient:notify(method, params)
	log.debug('sending LSP notify: ' .. method)
	return self.client.notify(method, params)
end

---Executes a workspace/executeCommand and returns the result
---@param command string workspace command to execute
---@param params? lsp.LSPAny[]
---@param buffer? integer
---@return lsp.LSPAny
function JdtlsClient:workspace_execute_command(command, params, buffer)
	return self:request('workspace/executeCommand', {
		command = command,
		arguments = params,
	}, buffer)
end

---Returns more information about the object the cursor is on
---@param command jdtls.CodeActionCommand
---@param params lsp.CodeActionParams
---@param buffer? number
---@return jdtls.SelectionInfo[]
function JdtlsClient:java_infer_selection(command, params, buffer)
	return self:request('java/inferSelection', {
		command = command,
		context = params,
	}, buffer)
end

--- @class jdtls.VariableBinding
--- @field bindingKey string
--- @field name string
--- @field type string
--- @field isField boolean
--- @field isSelected? boolean

---@class jdtls.MethodBinding
---@field bindingKey string;
---@field name string;
---@field parameters string[];

---@class jdtls.JavaCheckConstructorsStatusResponse
---@field constructors jdtls.MethodBinding
---@field fields jdtls.MethodBinding

---@param params lsp.CodeActionParams
---@return jdtls.JavaCheckConstructorsStatusResponse
function JdtlsClient:java_check_constructors_status(params)
	return self:request('java/checkConstructorsStatus', params)
end

---@class jdtls.GenerateConstructorsParams
---@field context lsp.CodeActionParams
---@field constructors jdtls.MethodBinding[]
---@field fields jdtls.VariableBinding[]

---@param params jdtls.GenerateConstructorsParams
---@return lsp.WorkspaceEdit
function JdtlsClient:java_generate_constructor(params)
	return self:request('java/generateConstructors', params)
end

---Returns refactor details
---@param command jdtls.CodeActionCommand
---@param action_params lsp.CodeActionParams
---@param formatting_options lsp.FormattingOptions
---@param selection_info jdtls.SelectionInfo[];
---@param buffer? number
---@return jdtls.RefactorWorkspaceEdit
function JdtlsClient:java_get_refactor_edit(
	command,
	action_params,
	formatting_options,
	selection_info,
	buffer
)
	local params = {
		command = command,
		context = action_params,
		options = formatting_options,
		commandArguments = selection_info,
	}

	return self:request('java/getRefactorEdit', params, buffer)
end

---Compile the workspace
---@param is_full_compile boolean if true, a complete full compile of the
---workspace will be executed
---@param buffer number
---@return java-core.CompileWorkspaceStatus
function JdtlsClient:java_build_workspace(is_full_compile, buffer)
	---@diagnostic disable-next-line: param-type-mismatch
	return self:request('java/buildWorkspace', is_full_compile, buffer)
end

---Returns the decompiled class file content
---@param uri string uri of the class file
---@return string # decompiled file content
function JdtlsClient:java_decompile(uri)
	---@type string
	return self:workspace_execute_command('java.decompile', { uri })
end

function JdtlsClient:get_capability(...)
	local capability = self.client.server_capabilities

	for _, value in ipairs({ ... }) do
		if type(capability) ~= 'table' then
			log.fmt_warn('Looking for capability: %s in value %s', value, capability)
			return nil
		end

		capability = capability[value]
	end

	return capability
end

---comment
---@param settings JavaConfigurationSettings
---@return boolean
function JdtlsClient:workspace_did_change_configuration(settings)
	local params = { settings = settings }
	return self:notify('workspace/didChangeConfiguration', params)
end

---Returns true if the LS supports the given command
---@param command_name string name of the command
---@return boolean # true if the command is supported
function JdtlsClient:has_command(command_name)
	local commands = self:get_capability('executeCommandProvider', 'commands')

	if not commands then
		return false
	end

	return vim.tbl_contains(commands, command_name)
end

return JdtlsClient
