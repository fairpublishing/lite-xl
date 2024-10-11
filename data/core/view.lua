local core = require "core"
local config = require "core.config"
local common = require "core.common"
local Object = require "core.object"
local Scrollbar = require "core.scrollbar"

local View = Object:extend()

-- context can be "application" or "session". The instance of objects
-- with context "session" will be closed when a project session is
-- terminated. The context "application" is for functional UI elements.
View.context = "application"

function View:new()
  self.position = { x = 0, y = 0 }
  self.size = { x = 0, y = 0 }
  self.scroll = { x = 0, y = 0, to = { x = 0, y = 0 } }
  self.cursor = "arrow"
  self.scrollable = false
  self.v_scrollbar = Scrollbar({direction = "v"})
  self.h_scrollbar = Scrollbar({direction = "h"})
  self.current_scale = SCALE

  -- reference systems variables
  self.ref_system = { stack = { }, x = 0, y = 0 }
  self.named_ref_system = { }

  -- drawing surfaces variables
  self.named_surfaces = { }
  self.surface_to_draw = { }
end


function View:push_reference_system(dx, dy, name)
  table.insert(self.ref_system.stack, {dx, dy})
  self.ref_system.x, self.ref_system.y = self.ref_system.x + dx, self.ref_system.y + dy
  if name then
    self.named_ref_system[name] = { x = self.ref_system.x, y = self.ref_system.y }
  end
end


function View:pop_reference_system()
  dx, dy = table.unpack(table.remove(self.ref_system.stack))
  self.ref_system.x, self.ref_system.y = self.ref_system.x - dx, self.ref_system.y - dy
end


function View:get_screen_coordinates(x, y, name)
  local ref_system = name and self.named_ref_system[name] or self.ref_system
  return ref_system.x + x, ref_system.y + y
end


-- Ensure the surface is set to be actually "presented" and draw the
-- background when first used.
function View:set_surface_to_draw(surface, surface_id, x, y, w, h, background)
  if not self.surface_to_draw[surface_id] then
    -- If the surface_id was not in surface_to_draw that means it is the first time
    -- this surface is used in the draw() round: we take this opportunity to draw
    -- it background so that it is done only once for the draw() round.
    renderer.draw_rect(surface, 0, 0, w, h, background or style.background)
    local x_screen, y_screen = self:get_screen_coordinates(x, y)
    self.surface_to_draw[surface_id] = { surface = surface, x = x_screen, y = y_screen }
  end
end


function View:surface_for(name, w, h)
  local surface = self.named_surfaces[name]
  local surf_w, surf_h
  if surface then
    surf_w, surf_h = surface.get_size()
  end
  if not surface or surf_w ~= w or surf_h ~= h then
    surface = renderer.surface.create(0, 0, w, h)
    self.named_surfaces[name] = surface
  end
  return surface
end


function View:present_surfaces()
  for id, surface in pairs(self.surface_to_draw) do
    renderer.present_surface(surface.surface, surface.x, surface.y)
  end
  self.surface_to_draw = { }
end


function View:move_towards(t, k, dest, rate, name)
  if type(t) ~= "table" then
    return self:move_towards(self, t, k, dest, rate, name)
  end
  local val = t[k]
  local diff = math.abs(val - dest)
  if not config.transitions or diff < 0.5 or config.disabled_transitions[name] then
    t[k] = dest
  else
    rate = rate or 0.5
    if config.fps ~= 60 or config.animation_rate ~= 1 then
      local dt = 60 / config.fps
      rate = 1 - common.clamp(1 - rate, 1e-8, 1 - 1e-8)^(config.animation_rate * dt)
    end
    t[k] = common.lerp(val, dest, rate)
  end
  if diff > 1e-8 then
    core.redraw = true
  end
end


function View:try_close(do_close)
  do_close()
end


---@return string
function View:get_name()
  return "---"
end


---@return number
function View:get_scrollable_size()
  return math.huge
end

---@return number
function View:get_h_scrollable_size()
  return 0
end


---@param x number
---@param y number
---@return boolean
function View:scrollbar_overlaps_point(x, y)
  return not (not (self.v_scrollbar:overlaps(x, y) or self.h_scrollbar:overlaps(x, y)))
end


---@return boolean
function View:scrollbar_dragging()
  return self.v_scrollbar.dragging or self.h_scrollbar.dragging
end


---@return boolean
function View:scrollbar_hovering()
  return self.v_scrollbar.hovering.track or self.h_scrollbar.hovering.track
end


---@param button core.view.mousebutton
---@param x number
---@param y number
---@param clicks integer
---return boolean
function View:on_mouse_pressed(button, x, y, clicks)
  if not self.scrollable then return end
  local result = self.v_scrollbar:on_mouse_pressed(button, x, y, clicks)
  if result then
    if result ~= true then
      self.scroll.to.y = result * self:get_scrollable_size()
    end
    return true
  end
  result = self.h_scrollbar:on_mouse_pressed(button, x, y, clicks)
  if result then
    if result ~= true then
      self.scroll.to.x = result * self:get_h_scrollable_size()
    end
    return true
  end
end


---@param button core.view.mousebutton
---@param x number
---@param y number
function View:on_mouse_released(button, x, y)
  if not self.scrollable then return end
  self.v_scrollbar:on_mouse_released(button, x, y)
  self.h_scrollbar:on_mouse_released(button, x, y)
end


---@param x number
---@param y number
---@param dx number
---@param dy number
function View:on_mouse_moved(x, y, dx, dy)
  if not self.scrollable then return end
  local result
  if self.h_scrollbar.dragging then goto skip_v_scrollbar end
  result = self.v_scrollbar:on_mouse_moved(x, y, dx, dy)
  if result then
    if result ~= true then
      self.scroll.to.y = result * self:get_scrollable_size()
      if not config.animate_drag_scroll then
        self:clamp_scroll_position()
        self.scroll.y = self.scroll.to.y
      end
    end
    -- hide horizontal scrollbar
    self.h_scrollbar:on_mouse_left()
    return true
  end
  ::skip_v_scrollbar::
  result = self.h_scrollbar:on_mouse_moved(x, y, dx, dy)
  if result then
    if result ~= true then
      self.scroll.to.x = result * self:get_h_scrollable_size()
      if not config.animate_drag_scroll then
        self:clamp_scroll_position()
        self.scroll.x = self.scroll.to.x
      end
    end
    return true
  end
end


function View:on_mouse_left()
  if not self.scrollable then return end
  self.v_scrollbar:on_mouse_left()
  self.h_scrollbar:on_mouse_left()
end


---@param filename string
---@param x number
---@param y number
---@return boolean
function View:on_file_dropped(filename, x, y)
  return false
end


---@param text string
function View:on_text_input(text)
  -- no-op
end


function View:on_ime_text_editing(text, start, length)
  -- no-op
end


---@param y number @Vertical scroll delta; positive is "up"
---@param x number @Horizontal scroll delta; positive is "left"
---@return boolean @Capture event
function View:on_mouse_wheel(y, x)
  -- no-op
end

---Can be overriden to listen for scale change events to apply
---any neccesary changes in sizes, padding, etc...
---@param new_scale number
---@param prev_scale number
function View:on_scale_change(new_scale, prev_scale) end

function View:get_content_bounds()
  local x = self.scroll.x
  local y = self.scroll.y
  return x, y, x + self.size.x, y + self.size.y
end


function View:get_content_offset()
  local x = common.round(self.position.x - self.scroll.x)
  local y = common.round(self.position.y - self.scroll.y)
  return x, y
end


function View:get_content_rel_offset()
  local x = common.round(-self.scroll.x)
  local y = common.round(-self.scroll.y)
  return x, y
end


function View:clamp_scroll_position()
  local max = self:get_scrollable_size() - self.size.y
  self.scroll.to.y = common.clamp(self.scroll.to.y, 0, max)

  max = self:get_h_scrollable_size() - self.size.x
  self.scroll.to.x = common.clamp(self.scroll.to.x, 0, max)
end


function View:update_scrollbar()
  local v_scrollable = self:get_scrollable_size()
  self.v_scrollbar:set_size(self.position.x, self.position.y, self.size.x, self.size.y, v_scrollable)
  self.v_scrollbar:set_percent(self.scroll.y/v_scrollable)
  self.v_scrollbar:update()

  local h_scrollable = self:get_h_scrollable_size()
  self.h_scrollbar:set_size(self.position.x, self.position.y, self.size.x, self.size.y, h_scrollable)
  self.h_scrollbar:set_percent(self.scroll.x/h_scrollable)
  self.h_scrollbar:update()
end


function View:update()
  if self.current_scale ~= SCALE then
    self:on_scale_change(SCALE, self.current_scale)
    self.current_scale = SCALE
  end

  self:clamp_scroll_position()
  self:move_towards(self.scroll, "x", self.scroll.to.x, 0.3, "scroll")
  self:move_towards(self.scroll, "y", self.scroll.to.y, 0.3, "scroll")
  if not self.scrollable then return end
  self:update_scrollbar()
end


---@param color renderer.color
-- function View:draw_background(color)
--   local x, y = self.position.x, self.position.y
--   local w, h = self.size.x, self.size.y
--   renderer.draw_rect(x, y, w, h, color)
-- end


function View:draw_scrollbar()
  self.v_scrollbar:draw()
  self.h_scrollbar:draw()
end


function View:draw()
end


return View
