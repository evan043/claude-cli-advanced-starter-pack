-- Minimal init file for headless testing
-- Used by plenary.nvim test runner

-- Disable unnecessary features for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = false
vim.opt.writebackup = false

-- Basic options
vim.opt.termguicolors = true
vim.opt.hidden = true

-- Get the project root (3 levels up from this file)
local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local nvim_ccasp_dir = vim.fn.fnamemodify(test_dir, ":h")
local project_root = vim.fn.fnamemodify(nvim_ccasp_dir, ":h")

-- Add nvim-ccasp to runtimepath
vim.opt.runtimepath:prepend(nvim_ccasp_dir)

-- Detect and add plenary.nvim to runtimepath
local plenary_paths = {
  -- Windows paths
  vim.fn.expand("$LOCALAPPDATA/nvim-data/site/pack/*/start/plenary.nvim"),
  vim.fn.expand("$LOCALAPPDATA/nvim-data/site/pack/*/opt/plenary.nvim"),
  -- Unix-like paths
  vim.fn.expand("~/.local/share/nvim/site/pack/*/start/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/site/pack/*/opt/plenary.nvim"),
  -- XDG paths
  vim.fn.expand("$XDG_DATA_HOME/nvim/site/pack/*/start/plenary.nvim"),
  vim.fn.expand("$XDG_DATA_HOME/nvim/site/pack/*/opt/plenary.nvim"),
}

local plenary_found = false

for _, path_pattern in ipairs(plenary_paths) do
  local matches = vim.fn.glob(path_pattern, false, true)
  if matches and #matches > 0 then
    for _, match in ipairs(matches) do
      if vim.fn.isdirectory(match) == 1 then
        vim.opt.runtimepath:append(match)
        plenary_found = true
        break
      end
    end
    if plenary_found then break end
  end
end

if not plenary_found then
  -- Exit non-zero: a bare error() still leaves nvim exiting 0, so a skipped
  -- suite reads as a clean pass in CI.
  vim.api.nvim_err_writeln("plenary.nvim not found in standard locations. Please install it.")
  vim.cmd("cquit 1")
end

-- Load ccasp plugin
vim.cmd([[runtime! plugin/**/*.lua]])
vim.cmd([[runtime! plugin/**/*.vim]])

-- Set up test environment
vim.g.ccasp_test_mode = true

-- Print diagnostic info (useful for debugging)
if os.getenv("CCASP_TEST_VERBOSE") then
  print("=== CCASP Test Environment ===")
  print("Project root: " .. project_root)
  print("CCASP dir: " .. nvim_ccasp_dir)
  print("Test dir: " .. test_dir)
  print("Plenary found: " .. tostring(plenary_found))
  print("==============================")
end
