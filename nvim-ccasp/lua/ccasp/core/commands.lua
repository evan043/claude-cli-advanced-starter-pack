-- CCASP Commands Module
-- Scans and manages the active runtime's prompt directory
-- (.claude/commands for Claude, .codex/prompts for Codex)

local M = {}

-- Commands cache
local commands_cache = nil
local sections_cache = nil
local last_scan_time = 0
local last_commands_dir = nil -- track scanned dir to detect session switches

-- Command sections mapping (organized by developer workflow lifecycle)
-- Setup → Explore → Plan → Build → Refactor → Test → Deploy → Operate → Maintain
-- NOTE: Pattern order matters! More specific patterns should come before general ones
local nf = require("ccasp.ui.icons")

local SECTION_PATTERNS = {
  -- CORE NAVIGATION & ENTRY POINTS
  { name = nf.dashboard .. " NAVIGATION", pattern = "^menu$", order = 1 },
  { name = nf.dashboard .. " NAVIGATION", pattern = "^menu%-", order = 1 },
  { name = nf.dashboard .. " NAVIGATION", pattern = "^ccasp%-panel", order = 1 },
  { name = nf.dashboard .. " NAVIGATION", pattern = "^INDEX$", order = 1 },
  { name = nf.dashboard .. " NAVIGATION", pattern = "^README$", order = 1 },

  -- PROJECT INITIALIZATION & SETUP
  { name = nf.config .. " SETUP", pattern = "^init%-ccasp", order = 2 },
  { name = nf.config .. " SETUP", pattern = "^ccasp%-setup", order = 2 },
  { name = nf.config .. " SETUP", pattern = "^project%-implementation", order = 2 },
  { name = nf.config .. " SETUP", pattern = "^detect%-tech", order = 2 },
  { name = nf.config .. " SETUP", pattern = "^generate%-agents", order = 2 },
  { name = nf.config .. " SETUP", pattern = "^orchestration%-guide", order = 2 },

  -- EXPLORATION & DISCOVERY
  { name = nf.search .. " EXPLORE", pattern = "^project%-explorer", order = 3 },
  { name = nf.search .. " EXPLORE", pattern = "^codebase%-explorer", order = 3 },
  { name = nf.search .. " EXPLORE", pattern = "^explore%-mcp", order = 3 },
  { name = nf.search .. " EXPLORE", pattern = "^research%-", order = 3 },
  { name = nf.search .. " EXPLORE", pattern = "^context%-audit", order = 3 },
  { name = nf.search .. " EXPLORE", pattern = "^claude%-audit", order = 3 },

  -- PLANNING & ROADMAP
  { name = nf.model .. " PLANNING", pattern = "^phase%-dev%-plan", order = 4 },
  { name = nf.model .. " PLANNING", pattern = "^phase%-track", order = 4 },
  { name = nf.model .. " PLANNING", pattern = "^phase%-", order = 4 },
  { name = nf.model .. " PLANNING", pattern = "^roadmap%-edit", order = 4 },
  { name = nf.model .. " PLANNING", pattern = "^roadmap%-status", order = 4 },
  { name = nf.model .. " PLANNING", pattern = "^roadmap%-track", order = 4 },
  { name = nf.model .. " PLANNING", pattern = "^roadmap%-", order = 4 },
  { name = nf.model .. " PLANNING", pattern = "^create%-roadmap", order = 4 },

  -- AGENTS, SKILLS & AUTOMATION
  { name = nf.auto .. " AUTOMATION", pattern = "^create%-agent", order = 5 },
  { name = nf.auto .. " AUTOMATION", pattern = "^create%-skill", order = 5 },
  { name = nf.auto .. " AUTOMATION", pattern = "^create%-hook", order = 5 },
  { name = nf.auto .. " AUTOMATION", pattern = "^create%-smoke%-test", order = 5 },
  { name = nf.auto .. " AUTOMATION", pattern = "^create%-task%-list%-for%-issue", order = 5 },
  { name = nf.auto .. " AUTOMATION", pattern = "^create%-task%-list", order = 5 },

  -- TASKS, ISSUES & GITHUB FLOW
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-epic%-menu", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-epic%-status", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-menu%-issues%-list", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-project%-menu", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-task%-multiple", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-task%-start", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-task", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^github%-", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^create%-github%-epic", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^issue%-templates%-sync%-executor", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^issue%-templates%-sync", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^issue%-templates", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^pr%-merge", order = 6 },
  { name = nf.git_branch .. " GITHUB", pattern = "^pr%-", order = 6 },

  -- DEVELOPMENT & EXECUTION
  { name = nf.dev .. " DEVELOP", pattern = "^dev%-mode%-deploy%-to%-projects", order = 7 },
  { name = nf.dev .. " DEVELOP", pattern = "^dev%-mode%-merge", order = 7 },
  { name = nf.dev .. " DEVELOP", pattern = "^dev%-mode", order = 7 },
  { name = nf.dev .. " DEVELOP", pattern = "^ask%-claude", order = 7 },
  { name = nf.dev .. " DEVELOP", pattern = "^ralph$", order = 7 },

  -- REFACTORING & CODE HEALTH
  { name = nf.reload .. " REFACTOR", pattern = "^enhanced%-refactor%-analyze%-executor", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^enhanced%-refactor%-analyze", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^enhanced%-refactor", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^refactor%-analyze", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^refactor%-check", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^refactor%-cleanup", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^refactor%-prep", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^refactor%-workflow", order = 8 },
  { name = nf.reload .. " REFACTOR", pattern = "^refactor%-", order = 8 },

  -- TESTING & QUALITY
  { name = nf.test .. " TESTING", pattern = "^e2e%-test", order = 9 },
  { name = nf.test .. " TESTING", pattern = "^e2e%-", order = 9 },
  { name = nf.test .. " TESTING", pattern = "^golden%-master", order = 9 },

  -- DEPLOYMENT
  { name = nf.deploy .. " DEPLOY", pattern = "^deploy%-full", order = 10 },
  { name = nf.deploy .. " DEPLOY", pattern = "^deploy%-", order = 10 },
  { name = nf.deploy .. " DEPLOY", pattern = "^tunnel%-start", order = 10 },
  { name = nf.deploy .. " DEPLOY", pattern = "^tunnel%-stop", order = 10 },
  { name = nf.deploy .. " DEPLOY", pattern = "^tunnel%-", order = 10 },

  -- VISION MODE
  { name = nf.ai .. " VISION", pattern = "^vision%-init", order = 11 },
  { name = nf.ai .. " VISION", pattern = "^vision%-status", order = 11 },
  { name = nf.ai .. " VISION", pattern = "^vision%-adjust", order = 11 },
  { name = nf.ai .. " VISION", pattern = "^vision%-run", order = 11 },
  { name = nf.ai .. " VISION", pattern = "^vision%-dashboard", order = 11 },
  { name = nf.ai .. " VISION", pattern = "^vision%-", order = 11 },

  -- VDB (VECTOR/DATA/BRAIN)
  { name = nf.model .. " VDB", pattern = "^vdb%-execute%-next", order = 12 },
  { name = nf.model .. " VDB", pattern = "^vdb%-init", order = 12 },
  { name = nf.model .. " VDB", pattern = "^vdb%-scan", order = 12 },
  { name = nf.model .. " VDB", pattern = "^vdb%-status", order = 12 },
  { name = nf.model .. " VDB", pattern = "^vdb%-", order = 12 },

  -- HAPPY / UX FLOW
  { name = nf.primary .. " HAPPY", pattern = "^happy%-start%-cd", order = 13 },
  { name = nf.primary .. " HAPPY", pattern = "^happy%-start", order = 13 },
  { name = nf.primary .. " HAPPY", pattern = "^happy%-", order = 13 },

  -- UPDATES & MAINTENANCE
  { name = nf.reload .. " MAINTAIN", pattern = "^update%-check", order = 14 },
  { name = nf.reload .. " MAINTAIN", pattern = "^update%-smart", order = 14 },
  { name = nf.reload .. " MAINTAIN", pattern = "^update%-", order = 14 },

  -- CATCH-ALL (must be last)
  { name = nf.commands .. " OTHER", pattern = ".*", order = 99 },
}

-- Detect project root by walking up from a directory looking for .claude/
local function detect_root_from(start_dir)
  if not start_dir or start_dir == "" then return nil end
  local dir = start_dir:gsub("\\", "/")
  while true do
    if vim.fn.isdirectory(dir .. "/.claude") == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h"):gsub("\\", "/")
    if parent == dir then break end
    dir = parent
  end
  return nil
end

-- Get commands directory path, preferring the active session's project root.
-- Each terminal session may be in a different project directory, so we derive
-- the commands dir from the focused session's window-local cwd.
local function get_commands_dir()
  local runtime = require("ccasp.runtime")

  -- Try active session's window-local directory first
  local sessions_ok, sessions = pcall(require, "ccasp.sessions")
  if sessions_ok then
    local active = sessions.get_active()
    if active and active.winid and vim.api.nvim_win_is_valid(active.winid) then
      local ok, cwd = pcall(vim.fn.getcwd, 0, active.winid)
      if ok and cwd and cwd ~= "" then
        local root = detect_root_from(cwd)
        if root then
          -- Follow the runtime this session actually drives, so a Codex session
          -- lists .codex/prompts rather than .claude/commands.
          local session_runtime = active.runtime
            or runtime.from_command(active.command)
            or runtime.default(root)
          local dir = runtime.prompts_dir(root, session_runtime)
          if vim.fn.isdirectory(dir) == 1 then
            return dir
          end
        end
      end
    end
  end

  -- Fallback to global project root (detected at setup time)
  local ccasp = require("ccasp")
  local root = ccasp.config.project_root or vim.fn.getcwd()
  return runtime.prompts_dir(root, ccasp.config.runtime or runtime.default(root))
end

-- Extract frontmatter bounds from content
-- Generated command files carry a runtime-compatibility preamble ahead of the
-- real content. It is delimited by HTML comments but its body is plain markdown
-- (including its own `# Codex Runtime Compatibility` heading), so the whole
-- block has to go before frontmatter or the command's own heading can be read.
local GENERATED_BLOCKS = {
  "<!%-%- CCASP%-CODEX%-COMPAT:START %-%->.-<!%-%- CCASP%-CODEX%-COMPAT:END %-%->",
  "<!%-%- CODEX%-OVERRIDE:START %-%->.-<!%-%- CODEX%-OVERRIDE:END %-%->",
}

local function strip_leading_comments(content)
  local body = content
  for _, pattern in ipairs(GENERATED_BLOCKS) do
    body = body:gsub(pattern, "")
  end

  body = body:gsub("^%s+", "")
  while body:sub(1, 4) == "<!--" do
    local close = body:find("%-%->")
    if not close then break end
    body = body:sub(close + 3):gsub("^%s+", "")
  end
  return body
end

local function extract_frontmatter_content(content)
  local body = strip_leading_comments(content)

  local fm_start = body:find("^%-%-%-\n")
  if not fm_start then return nil end

  local fm_end = body:find("\n%-%-%-\n", 4)
  if not fm_end then return nil end

  return body:sub(4, fm_end - 1)
end

-- First markdown heading, used when a file has no usable frontmatter.
local function first_heading(content)
  for line in strip_leading_comments(content):gmatch("[^\n]+") do
    local heading = line:match("^#%s+(.+)$")
    if heading then return (heading:gsub("%s+$", "")) end
  end
  return nil
end

-- Parse description from frontmatter
local function parse_description(fm_content)
  local desc = fm_content:match("description:%s*([^\n]+)")
  return desc and desc:gsub("^%s+", ""):gsub("%s+$", "") or nil
end

-- Parse options from frontmatter
local function parse_options(fm_content)
  local options = {}
  if not fm_content:find("options:") then return options end

  local in_options = false
  for line in fm_content:gmatch("[^\n]+") do
    if line:match("^options:") then
      in_options = true
    elseif in_options then
      local label = line:match('label:%s*"([^"]+)"')
      if label then
        local option_desc = line:match('description:%s*"([^"]+)"')
        table.insert(options, { label = label, description = option_desc or "" })
      end
    end
  end
  return options
end

-- Parse command frontmatter
local function parse_frontmatter(content)
  local fm_content = extract_frontmatter_content(content)
  if not fm_content then return {} end

  return {
    description = parse_description(fm_content),
    options = parse_options(fm_content),
  }
end

-- Get section for a command
local function get_section(cmd_name)
  for _, section in ipairs(SECTION_PATTERNS) do
    if cmd_name:match(section.pattern) then
      return section.name, section.order
    end
  end
  return nf.commands .. " OTHER", 99
end

-- Initialize empty sections
local function init_sections()
  local sections = {}
  for _, section in ipairs(SECTION_PATTERNS) do
    if not sections[section.name] then
      sections[section.name] = { order = section.order, commands = {} }
    end
  end
  return sections
end

-- .ccasp/commands/<id>.yaml is the source of truth for the Codex support tier;
-- the rendered markdown does not currently carry it. Cached per project root.
local meta_cache = {}

local function load_command_meta(root)
  if meta_cache[root] then return meta_cache[root] end

  local meta = {}
  local dir = (root .. "/.ccasp/commands"):gsub("\\", "/")
  if vim.fn.isdirectory(dir) == 1 then
    local ok, entries = pcall(vim.fn.readdir, dir)
    if ok then
      for _, entry in ipairs(entries) do
        local id = entry:match("^(.+)%.ya?ml$")
        if id then
          local record = {}
          local read_ok, lines = pcall(vim.fn.readfile, dir .. "/" .. entry)
          if read_ok then
            local in_instructions = false
            for idx, line in ipairs(lines) do
              if line:match("^instructions:") then
                in_instructions = true
              elseif not in_instructions then
                local key, value = line:match("^([%w_]+):%s*(.+)$")
                if key then
                  record[key] = value:gsub('^"', ""):gsub('"$', ""):gsub("%s+$", "")
                end
              elseif not record.embedded_description then
                -- The legacy converter folded each command's original
                -- frontmatter into the instruction list. Recover the real
                -- description from there, re-joining YAML line wrapping.
                local embedded = line:match('^%s*%-?%s*"?description:%s*(.+)$')
                if embedded then
                  local text = embedded
                  local next_idx = idx + 1
                  while not text:match('"$') and lines[next_idx] do
                    local cont = lines[next_idx]:match("^%s+(.+)$")
                    if not cont or cont:match("^%-") then break end
                    text = text .. " " .. cont
                    next_idx = next_idx + 1
                  end
                  record.embedded_description = text:gsub('"$', ""):gsub("%s+$", "")
                end
              end
            end
          end
          meta[id] = record
        end
      end
    end
  end

  meta_cache[root] = meta
  return meta
end

-- Read command file and create entry
local function load_command_file(file, meta)
  local filename = vim.fn.fnamemodify(file, ":t:r")
  if filename:sub(1, 2) == "__" then return nil end

  local f = io.open(file, "r")
  if not f then return nil end

  local content = f:read("*all")
  f:close()

  local frontmatter = parse_frontmatter(content)
  local record = (meta and meta[filename]) or {}

  -- The generator stamps a placeholder description on converted commands, so
  -- prefer the description recovered from the original frontmatter over it.
  local description = frontmatter.description
  if (not description or description == "")
      and record.description
      and not record.description:match("^Converted from legacy") then
    description = record.description
  end
  if not description or description == "" then
    description = record.embedded_description
  end
  if not description or description == "" then
    description = first_heading(content) or record.title or ""
  end

  return {
    name = filename,
    path = file,
    description = description,
    options = frontmatter.options or {},
    section = get_section(filename),
    -- Matches the generator default in ccasp_cli/commands.py.
    codex_support = record.codex_support or "partial",
  }
end

-- Scan commands directory
function M.load_all()
  local dir = get_commands_dir()

  -- If the resolved directory changed (session switch), clear the cache
  if dir ~= last_commands_dir then
    commands_cache = nil
    sections_cache = nil
    last_commands_dir = dir
  end

  -- Return cached results if available (cleared on dir change or reload)
  if commands_cache then return commands_cache end

  if vim.fn.isdirectory(dir) ~= 1 then
    commands_cache, sections_cache = {}, {}
    return commands_cache
  end

  commands_cache = {}
  sections_cache = init_sections()

  -- Use readdir + filter instead of glob to avoid issues with special
  -- characters (parentheses, spaces) in directory paths on Windows
  local ok, entries = pcall(vim.fn.readdir, dir)
  if not ok then
    return commands_cache
  end

  -- Tier metadata is keyed off the project root, not the prompts dir, so both
  -- runtimes read the same .ccasp/commands/*.yaml source of truth.
  local ccasp_ok, ccasp = pcall(require, "ccasp")
  local meta_root = (ccasp_ok and ccasp.config and ccasp.config.project_root) or vim.fn.getcwd()
  local meta = load_command_meta(meta_root)

  for _, entry in ipairs(entries) do
    if entry:match("%.md$") then
      local file = dir .. "/" .. entry
      local cmd = load_command_file(file, meta)
      if cmd then
        commands_cache[cmd.name] = cmd
        if sections_cache[cmd.section] then
          table.insert(sections_cache[cmd.section].commands, cmd.name)
        end
      end
    end
  end

  for _, section in pairs(sections_cache) do
    table.sort(section.commands)
  end

  last_scan_time = os.time()
  return commands_cache
end

-- Get all commands
function M.get_all()
  if not commands_cache then
    M.load_all()
  end
  return commands_cache
end

-- Get a specific command
function M.get(name)
  if not commands_cache then
    M.load_all()
  end
  return commands_cache[name]
end

-- Get all sections with their commands
function M.get_sections()
  if not sections_cache then
    M.load_all()
  end

  -- Sort sections by order
  local sorted = {}
  for name, section in pairs(sections_cache) do
    if #section.commands > 0 then
      table.insert(sorted, {
        name = name,
        order = section.order,
        commands = section.commands,
      })
    end
  end

  table.sort(sorted, function(a, b)
    return a.order < b.order
  end)

  return sorted
end

-- Search commands
function M.search(query)
  if not commands_cache then
    M.load_all()
  end

  if not query or query == "" then
    return commands_cache
  end

  local results = {}
  local pattern = query:lower()

  for name, cmd in pairs(commands_cache) do
    local name_lower = name:lower()
    local desc_lower = (cmd.description or ""):lower()

    if name_lower:find(pattern, 1, true) or desc_lower:find(pattern, 1, true) then
      results[name] = cmd
    end
  end

  return results
end

-- Get sync status
function M.get_sync_status()
  -- Check if commands are loaded
  if not commands_cache then
    return "unknown"
  end

  -- Count commands
  local count = 0
  for _ in pairs(commands_cache) do
    count = count + 1
  end

  if count == 0 then
    return "empty"
  end

  return "synced"
end

-- Force reload
function M.reload()
  commands_cache = nil
  sections_cache = nil
  last_commands_dir = nil
  meta_cache = {}
  return M.load_all()
end

return M
