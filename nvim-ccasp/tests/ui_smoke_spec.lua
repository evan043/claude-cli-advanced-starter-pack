-- Plenary test for nvim-ccasp UI smoke tests
-- Tests basic UI operations: setup, open, toggle, close

local helpers = require("tests.helpers")

describe("CCASP UI Smoke Test", function()

  it("setup loads without errors", helpers.with_clean_state(function()
    local ok, ccasp = pcall(require, "ccasp")
    assert.is_true(ok, "Failed to require ccasp")

    local setup_ok, setup_err = pcall(ccasp.setup, {
      layout = "appshell",
      appshell = {
        icon_rail = { width = 3, visible = true },
        flyout = { width = 30, visible = false },
        header = { height = 1, visible = true },
        footer = { height = 1, visible = true },
        right_panel = { width = 40, visible = false },
      },
    })

    assert.is_true(setup_ok, "Setup failed: " .. tostring(setup_err))
    helpers.assert_no_errors()
  end))

  it("open creates appshell chrome", helpers.with_clean_state(function()
    local ccasp = helpers.setup_test_env()

    -- Open the appshell
    local open_ok, open_err = pcall(ccasp.open)
    assert.is_true(open_ok, "Open failed: " .. tostring(open_err))

    -- Wait for UI to render
    local ui_ready = helpers.wait_for(function()
      local windows = helpers.get_all_windows()
      return #windows > 0
    end, 1000, 50)

    assert.is_true(ui_ready, "UI did not render in time")

    -- Check that we have windows (icon_rail, header, etc.)
    local windows = helpers.get_all_windows()
    assert.is_true(#windows > 0, "Expected at least one window after open")

    helpers.assert_no_errors()
  end))

  it("toggle_flyout opens flyout window", helpers.with_clean_state(function()
    local ccasp = helpers.setup_test_env()

    -- Open appshell first
    pcall(ccasp.open)
    helpers.wait_for(function()
      return #helpers.get_all_windows() > 0
    end, 1000, 50)

    -- Get initial window count
    local initial_windows = helpers.get_float_windows()
    local initial_count = #initial_windows

    -- Toggle flyout for terminal section
    local toggle_ok, toggle_err = pcall(ccasp.appshell.toggle_flyout, "terminal")
    assert.is_true(toggle_ok, "Toggle flyout failed: " .. tostring(toggle_err))

    -- Wait for flyout to appear
    local flyout_opened = helpers.wait_for(function()
      local current_windows = helpers.get_float_windows()
      return #current_windows > initial_count
    end, 1000, 50)

    assert.is_true(flyout_opened, "Flyout window did not appear")
    helpers.assert_no_errors()
  end))

  it("toggle_flyout close works", helpers.with_clean_state(function()
    local ccasp = helpers.setup_test_env()

    -- Open appshell
    pcall(ccasp.open)
    helpers.wait_for(function()
      return #helpers.get_all_windows() > 0
    end, 1000, 50)

    -- Open flyout
    pcall(ccasp.appshell.toggle_flyout, "terminal")
    local flyout_opened = helpers.wait_for(function()
      local windows = helpers.get_float_windows()
      for _, win in ipairs(windows) do
        if string.match(win.bufname or "", "flyout") or string.match(win.filetype or "", "flyout") then
          return true
        end
      end
      return false
    end, 1000, 50)

    -- Get window count with flyout open
    local windows_with_flyout = helpers.get_float_windows()
    local count_with_flyout = #windows_with_flyout

    -- Toggle flyout again to close
    local close_ok, close_err = pcall(ccasp.appshell.toggle_flyout, "terminal")
    assert.is_true(close_ok, "Toggle flyout close failed: " .. tostring(close_err))

    -- Wait for flyout to close
    local flyout_closed = helpers.wait_for(function()
      local current_windows = helpers.get_float_windows()
      return #current_windows < count_with_flyout
    end, 1000, 50)

    assert.is_true(flyout_closed, "Flyout window did not close")
    helpers.assert_no_errors()
  end))

  it("close tears down cleanly", helpers.with_clean_state(function()
    local ccasp = helpers.setup_test_env()

    -- Open appshell
    pcall(ccasp.open)
    helpers.wait_for(function()
      return #helpers.get_all_windows() > 0
    end, 1000, 50)

    -- Close appshell
    local close_ok, close_err = pcall(ccasp.close)
    assert.is_true(close_ok, "Close failed: " .. tostring(close_err))

    -- Wait for cleanup
    vim.wait(100)

    -- Check that floating windows are cleaned up
    local float_windows = helpers.get_float_windows()
    assert.equals(0, #float_windows, "Expected no floating windows after close")

    helpers.assert_no_errors()
  end))

end)
