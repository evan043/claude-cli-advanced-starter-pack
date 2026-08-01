-- CCASP Repo Launcher - Public API
-- Provides quick-launch of Claude CLI sessions in specific repo directories

local M = {}

-- Open the repo launcher (path input dialog)
function M.open_launcher()
  require("ccasp.repo_launcher.ui").open_path_dialog()
end

-- Open the repo browser (library panel)
function M.open_browser()
  require("ccasp.repo_launcher.ui").open_browser()
end

-- Quick-launch most recent repo (no UI, just opens it)
function M.quick_recent()
  local storage = require("ccasp.repo_launcher.storage")
  local recent = storage.get_recent(1)
  if #recent == 0 then
    vim.notify("No recent repos in library", vim.log.levels.INFO)
    return
  end
  M.open_repo(recent[1].path)
end

-- Open a specific repo path (core action).
-- runtime_name picks which agent CLI to launch; defaults to the configured one.
function M.open_repo(path, runtime_name)
  if vim.fn.isdirectory(path) == 0 then
    vim.notify("Directory not found: " .. path, vim.log.levels.ERROR)
    return
  end

  -- Add to library
  local storage = require("ccasp.repo_launcher.storage")
  storage.add(path)
  storage.prune()

  -- Spawn session at path
  local runtime = require("ccasp.runtime")
  local sessions = require("ccasp.sessions")
  local resolved = runtime.normalize(runtime_name) or runtime.default()
  sessions.spawn_at_path(path, {
    runtime = resolved,
    name = runtime.label(resolved),
  })
end

-- Open a repo, asking which agent to launch when more than one is installed.
function M.open_repo_pick(path)
  require("ccasp.runtime_picker").open({
    prompt = "New session type",
    on_select = function(name) M.open_repo(path, name) end,
  })
end

-- Open a specific repo path under the Happy wrapper instead of a bare CLI.
-- runtime_name picks which agent Happy drives -- `happy` for Claude,
-- `happy codex` for Codex -- and defaults to the configured runtime.
function M.open_repo_happy(path, runtime_name)
  if vim.fn.isdirectory(path) == 0 then
    vim.notify("Directory not found: " .. path, vim.log.levels.ERROR)
    return
  end

  local runtime = require("ccasp.runtime")
  local resolved = runtime.normalize(runtime_name) or runtime.default()

  if not runtime.happy_available() then
    vim.notify("Happy CLI not found in PATH (npm install -g happy-coder)", vim.log.levels.ERROR)
    return
  end

  -- Add to library
  local storage = require("ccasp.repo_launcher.storage")
  storage.add(path)
  storage.prune()

  -- Spawn session at path with Happy command, gold titlebar
  local sessions = require("ccasp.sessions")
  local titlebar = require("ccasp.session_titlebar")
  sessions.spawn_at_path(path, {
    command = runtime.happy_command(resolved),
    name = resolved == "claude" and "Happy" or ("Happy " .. runtime.label(resolved)),
    color_idx = titlebar.COLOR_GOLD,
  })
end

-- Launch a repo under Happy, asking which agent to drive when more than one
-- runtime is installed. Falls straight through when there is only one choice.
function M.open_repo_happy_pick(path)
  require("ccasp.runtime_picker").open({
    prompt = "Happy session type",
    happy = true,
    on_select = function(name) M.open_repo_happy(path, name) end,
  })
end

-- Open the Happy repo picker (select repo to launch Happy session)
function M.open_happy_picker()
  require("ccasp.repo_launcher.ui").open_happy_browser()
end

return M
