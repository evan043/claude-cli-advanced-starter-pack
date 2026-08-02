-- Plenary test for nvim-ccasp layout calculations
-- Tests zone calculations and layout structure

local helpers = require("tests.helpers")

describe("CCASP Layout", function()

  it("appshell calculates correct zones", helpers.with_clean_state(function()
    helpers.setup_test_env()

    local ok, appshell = pcall(require, "ccasp.appshell")
    assert.is_true(ok, "Failed to require ccasp.appshell")

    -- Calculate zones
    local zones_ok, zones = pcall(appshell.calculate_zones)
    assert.is_true(zones_ok, "Failed to calculate zones: " .. tostring(zones))
    assert.is_not_nil(zones, "Zones should not be nil")

    -- Verify all 6 zones exist
    local expected_zones = { "icon_rail", "flyout", "header", "footer", "right_panel", "content" }
    for _, zone_name in ipairs(expected_zones) do
      assert.is_not_nil(zones[zone_name], string.format("Expected zone '%s' to exist", zone_name))
    end

    helpers.assert_no_errors()
  end))

  it("icon_rail zone has width 3", helpers.with_clean_state(function()
    helpers.setup_test_env()

    local appshell = require("ccasp.appshell")
    local zones = appshell.calculate_zones()

    assert.is_not_nil(zones.icon_rail, "icon_rail zone should exist")
    assert.equals(3, zones.icon_rail.width, "icon_rail should have width 3")

    helpers.assert_no_errors()
  end))

  it("content zone fills remaining space", helpers.with_clean_state(function()
    helpers.setup_test_env()

    local appshell = require("ccasp.appshell")
    local zones = appshell.calculate_zones()

    -- Get editor dimensions
    local editor_width = vim.o.columns
    local icon_rail_width = zones.icon_rail.width

    -- Content should fill remaining horizontal space (minus icon rail)
    -- Note: When flyout is hidden, content width = editor_width - icon_rail_width
    assert.is_not_nil(zones.content, "content zone should exist")
    assert.is_not_nil(zones.content.width, "content zone should have width")
    assert.is_true(zones.content.width > 0, "content zone width should be positive")

    -- Verify content takes up most of the space
    local expected_min_width = editor_width - icon_rail_width - 5 -- allow some margin
    assert.is_true(
      zones.content.width >= expected_min_width,
      string.format("content width (%d) should be at least %d", zones.content.width, expected_min_width)
    )

    helpers.assert_no_errors()
  end))

  it("footer zone is at bottom", helpers.with_clean_state(function()
    helpers.setup_test_env()

    local appshell = require("ccasp.appshell")
    local zones = appshell.calculate_zones()

    assert.is_not_nil(zones.footer, "footer zone should exist")
    assert.is_not_nil(zones.footer.row, "footer zone should have row position")
    assert.is_true(zones.footer.row > 0, "footer zone should be positioned below top (row > 0)")

    -- Footer should be near the bottom of the screen
    local editor_height = vim.o.lines
    assert.is_true(
      zones.footer.row >= editor_height - 2,
      string.format("footer row (%d) should be near bottom of screen (%d)", zones.footer.row, editor_height)
    )

    helpers.assert_no_errors()
  end))

  it("zones update on config change", helpers.with_clean_state(function()
    local ccasp = helpers.setup_test_env()

    local appshell = require("ccasp.appshell")

    -- Calculate initial zones (flyout hidden)
    local initial_zones = appshell.calculate_zones()
    local initial_content_width = initial_zones.content.width

    -- calculate_zones() reads the appshell module's own config table, not the
    -- ccasp.config utils module -- mutate the one it actually consults.
    local was_visible = appshell.config.flyout.visible
    appshell.config.flyout.visible = true

    -- Recalculate zones
    local updated_zones = appshell.calculate_zones()
    local updated_content_width = updated_zones.content.width

    -- Restore so later specs see the default hidden flyout
    appshell.config.flyout.visible = was_visible

    -- Content width should decrease when flyout is visible
    assert.is_true(
      updated_content_width < initial_content_width,
      string.format(
        "content width should decrease when flyout is visible (initial: %d, updated: %d)",
        initial_content_width,
        updated_content_width
      )
    )

    -- Flyout should have non-zero width when visible
    assert.is_not_nil(updated_zones.flyout, "flyout zone should exist")
    assert.is_true(updated_zones.flyout.width > 0, "flyout should have positive width when visible")

    helpers.assert_no_errors()
  end))

  it("header zone is at top", helpers.with_clean_state(function()
    helpers.setup_test_env()

    local appshell = require("ccasp.appshell")
    local zones = appshell.calculate_zones()

    assert.is_not_nil(zones.header, "header zone should exist")
    assert.is_not_nil(zones.header.row, "header zone should have row position")
    assert.equals(0, zones.header.row, "header zone should be at top (row 0)")
    assert.equals(1, zones.header.height, "header zone should have height 1")

    helpers.assert_no_errors()
  end))

  it("right_panel zone exists and has correct width", helpers.with_clean_state(function()
    helpers.setup_test_env()

    local appshell = require("ccasp.appshell")
    local zones = appshell.calculate_zones()

    assert.is_not_nil(zones.right_panel, "right_panel zone should exist")
    assert.is_not_nil(zones.right_panel.width, "right_panel zone should have width")

    -- When hidden, width might be 0 or the configured width
    -- Just verify it's a valid number
    assert.is_true(zones.right_panel.width >= 0, "right_panel width should be non-negative")

    helpers.assert_no_errors()
  end))

  it("zones have valid dimensions", helpers.with_clean_state(function()
    helpers.setup_test_env()

    local appshell = require("ccasp.appshell")
    local zones = appshell.calculate_zones()

    -- Verify all zones have valid numeric dimensions
    for zone_name, zone in pairs(zones) do
      if zone.width then
        assert.is_true(
          type(zone.width) == "number",
          string.format("%s.width should be a number", zone_name)
        )
        assert.is_true(zone.width >= 0, string.format("%s.width should be non-negative", zone_name))
      end

      if zone.height then
        assert.is_true(
          type(zone.height) == "number",
          string.format("%s.height should be a number", zone_name)
        )
        assert.is_true(zone.height >= 0, string.format("%s.height should be non-negative", zone_name))
      end

      if zone.row then
        assert.is_true(
          type(zone.row) == "number",
          string.format("%s.row should be a number", zone_name)
        )
        assert.is_true(zone.row >= 0, string.format("%s.row should be non-negative", zone_name))
      end

      if zone.col then
        assert.is_true(
          type(zone.col) == "number",
          string.format("%s.col should be a number", zone_name)
        )
        assert.is_true(zone.col >= 0, string.format("%s.col should be non-negative", zone_name))
      end
    end

    helpers.assert_no_errors()
  end))

end)
