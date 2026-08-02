-- ccasp/config.lua - Configuration utilities for reading/writing CCASP configs
local M = {}

-- Get the root CCASP config
local function get_ccasp()
  return require("ccasp")
end

-- Get the project root (detected at setup time, falls back to cwd)
local function get_root()
  local ccasp = get_ccasp()
  return (ccasp.config.project_root or vim.fn.getcwd()):gsub("\\", "/")
end

-- Get full path for a config file
function M.get_path(key)
  local ccasp = get_ccasp()
  local relative = ccasp.config.paths[key]
  if not relative then
    return nil
  end
  return get_root() .. "/" .. relative
end

-- Check if .claude directory exists
function M.has_claude_dir()
  return vim.fn.isdirectory(get_root() .. "/.claude") == 1
end

-- Read JSON file safely
function M.read_json(filepath)
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil, "File not found: " .. filepath
  end

  local content = table.concat(vim.fn.readfile(filepath), "\n")
  local ok, result = pcall(vim.fn.json_decode, content)
  if not ok then
    return nil, "Invalid JSON: " .. tostring(result)
  end
  return result, nil
end

-- Write JSON file with formatting
function M.write_json(filepath, data)
  local ok, encoded = pcall(vim.fn.json_encode, data)
  if not ok then
    return false, "Failed to encode JSON: " .. tostring(encoded)
  end

  -- Pretty print the JSON
  local formatted = M.format_json(encoded)

  local dir = vim.fn.fnamemodify(filepath, ":h")
  if vim.fn.isdirectory(dir) ~= 1 then
    vim.fn.mkdir(dir, "p")
  end

  local file = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file for writing"
  end

  file:write(formatted)
  file:close()
  return true, nil
end

-- Format JSON with indentation
function M.format_json(json_str)
  -- Use jq if available for proper formatting
  if vim.fn.executable("jq") == 1 then
    local result = vim.fn.system("echo " .. vim.fn.shellescape(json_str) .. " | jq '.'")
    if vim.v.shell_error == 0 then
      return result
    end
  end
  -- Fallback: basic formatting
  return json_str
end

-- Load settings.json
function M.load_settings()
  local path = M.get_path("settings")
  if not path then
    return {}
  end
  local data, err = M.read_json(path)
  if err then
    vim.notify("CCASP: " .. err, vim.log.levels.WARN)
    return {}
  end
  return data or {}
end

-- Save settings.json
function M.save_settings(data)
  local path = M.get_path("settings")
  if not path then
    return false
  end
  local ok, err = M.write_json(path, data)
  if not ok then
    vim.notify("CCASP: " .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Load tech-stack.json
function M.load_tech_stack()
  local path = M.get_path("tech_stack")
  if not path then
    return {}
  end
  local data, err = M.read_json(path)
  if err then
    vim.notify("CCASP: " .. err, vim.log.levels.WARN)
    return {}
  end
  return data or {}
end

-- Save tech-stack.json
function M.save_tech_stack(data)
  local path = M.get_path("tech_stack")
  if not path then
    return false
  end
  local ok, err = M.write_json(path, data)
  if not ok then
    vim.notify("CCASP: " .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Load ccasp-state.json
function M.load_state()
  local path = M.get_path("state")
  if not path then
    return {}
  end
  local data, _ = M.read_json(path)
  return data or {}
end

-- Get nested value from table using dot notation
function M.get_nested(tbl, path)
  local keys = vim.split(path, ".", { plain = true })
  local current = tbl
  for _, key in ipairs(keys) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[key]
  end
  return current
end

-- Set nested value in table using dot notation
function M.set_nested(tbl, path, value)
  local keys = vim.split(path, ".", { plain = true })
  local current = tbl
  for i = 1, #keys - 1 do
    local key = keys[i]
    if type(current[key]) ~= "table" then
      current[key] = {}
    end
    current = current[key]
  end
  current[keys[#keys]] = value
  return tbl
end

-- Toggle boolean value at path
function M.toggle_nested(tbl, path)
  local current = M.get_nested(tbl, path)
  if type(current) == "boolean" then
    M.set_nested(tbl, path, not current)
    return not current
  elseif current == nil then
    M.set_nested(tbl, path, true)
    return true
  end
  return current
end

-- Load deploy-config.json
function M.load_deploy_config()
  local path = M.get_path("deploy_config")
  if not path then
    return M.get_deploy_defaults()
  end
  local data, err = M.read_json(path)
  if err then
    vim.notify("CCASP: " .. err, vim.log.levels.WARN)
    return M.get_deploy_defaults()
  end
  return data or M.get_deploy_defaults()
end

-- Save deploy-config.json
function M.save_deploy_config(data)
  local path = M.get_path("deploy_config")
  if not path then
    return false
  end
  local ok, err = M.write_json(path, data)
  if not ok then
    vim.notify("CCASP: " .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Get deploy config defaults
function M.get_deploy_defaults()
  return {
    version = "1.0.0",
    frontend = {
      cleanDist = true,
      fullRebuild = false,
      cacheBusting = true,
      verbose = false,
      buildCommand = "npm run build",
      outputDir = "dist",
      project = "eroland-me",
    },
    backend = {
      preDeployGitCheck = true,
      healthCheckUrl = "https://bo360-backend-production.up.railway.app/health",
      healthCheckTimeout = 30,
    },
    verification = {
      shaVerification = true,
      productionUrl = "https://eroland.me",
      hashAlgorithm = "sha256",
      compareFiles = { "index.html" },
      propagationDelay = 15,
    },
    notifications = {
      enabled = true,
      onSuccess = true,
      onFailure = true,
      method = "terminal",
    },
    rollback = {
      autoRollbackOnShaFailure = false,
      keepDeploymentCount = 3,
    },
  }
end

-- Get list of installed hooks
function M.get_hooks()
  local hooks_dir = get_root() .. "/.claude/hooks/tools"
  if vim.fn.isdirectory(hooks_dir) ~= 1 then
    return {}
  end

  local hooks = {}
  local files = vim.fn.glob(hooks_dir .. "/*.js", false, true)
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    table.insert(hooks, {
      name = name,
      path = file,
      enabled = true, -- Would check settings.json for actual state
    })
  end
  return hooks
end

-- Get list of installed commands for the active runtime
function M.get_commands()
  local runtime = require("ccasp.runtime")
  local root = get_root()
  local commands_dir = runtime.prompts_dir(root, runtime.default(root))
  if vim.fn.isdirectory(commands_dir) ~= 1 then
    return {}
  end

  local commands = {}
  local files = vim.fn.glob(commands_dir .. "/*.md", false, true)
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    -- Read first few lines for description
    local lines = vim.fn.readfile(file, "", 10)
    local desc = ""
    for _, line in ipairs(lines) do
      if line:match("^description:") then
        desc = line:gsub("^description:%s*", "")
        break
      end
    end
    table.insert(commands, {
      name = name,
      path = file,
      description = desc,
    })
  end
  return commands
end

-- Get list of installed skills
function M.get_skills()
  local skills_dir = get_root() .. "/.claude/skills"
  if vim.fn.isdirectory(skills_dir) ~= 1 then
    return {}
  end

  local skills = {}
  local dirs = vim.fn.glob(skills_dir .. "/*/", false, true)
  for _, dir in ipairs(dirs) do
    local name = vim.fn.fnamemodify(dir:gsub("/$", ""), ":t")
    local manifest_path = dir .. "skill.json"
    local skill_md = dir .. "skill.md"

    local skill = { name = name, path = dir }

    if vim.fn.filereadable(manifest_path) == 1 then
      local manifest, _ = M.read_json(manifest_path)
      if manifest then
        skill.description = manifest.description
        skill.version = manifest.version
        skill.category = manifest.category
      end
    end

    if vim.fn.filereadable(skill_md) == 1 then
      skill.entry_point = skill_md
    end

    table.insert(skills, skill)
  end
  return skills
end

-- Get token usage from cache
function M.get_token_usage()
  local cache_path = get_root() .. "/.claude/hooks/cache/token-usage.json"
  if vim.fn.filereadable(cache_path) ~= 1 then
    return nil
  end
  local data, _ = M.read_json(cache_path)
  return data
end

return M
