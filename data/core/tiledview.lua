local core = require "core"
local common = require "core.common"
local View = require "core.view"


local TiledView = View:extend()


local function compose_tile_id(tile_1, tile_2)
  return ":" .. tile_1 .. " " .. tile_2
end


function TiledView:new()
  TiledView.super.new(self)
  self.tiles_metric = { w = 0, h = 0 }
  self.used_tiles_ids = { }
  self.active_tiles = { }
end


function TiledView:present_surfaces()
  self:clear_unused_tiles()
  if self.named_surfaces[":1 1"] then
    renderer.debug_log_frame(self.named_surfaces[":1 1"])
  end
  TiledView.super.present_surfaces(self)
end


function TiledView:get_tile_indexes(x, y)
  local xo, yo = self.tiles_metric.x, self.tiles_metric.y
  local w, h = self.tiles_metric.w, self.tiles_metric.h
  return math.floor((x - xo) / w) + 1, math.floor((y - yo) / h) + 1
end


function TiledView:get_tile_size()
  return self.tiles_metric.w, self.tiles_metric.h
end


-- should be called only once for each tile at the beginning of the draw()
-- function
function TiledView:prepare_tile(tile_id, x, y, w, h, background)
  local surface = self.surface_from_list(self.named_surfaces, tile_id, x, y, w, h)
  renderer.set_current_surface(surface)
  renderer.begin_frame(surface, background)
  self:set_surface_to_draw(surface)
  self.used_tiles_ids[tile_id] = surface
  renderer.show_debug(surface, true)
end


-- We provide a surface to draw the content (document's text body) at the given tile
-- coordinates. We ensure the surface has the background set since the beginning.
function TiledView:surface_for_tile(tile_i, tile_j)
  local surface = self.named_surfaces[compose_tile_id(tile_i, tile_j)]
  renderer.set_current_surface(surface)
end


function TiledView:clear_unused_tiles()
  for id in pairs(self.named_surfaces) do
    if string.match(id, "^:") and not self.used_tiles_ids[id] then
      self.named_surfaces[id] = nil
    end
  end
end


function TiledView:setup_tiles_for_drawing()
  local metric = self.tiles_metric
  metric.x, metric.y = self:get_content_offset()
  metric.w, metric.h = 400, 600
  self.used_tiles_ids = { }
end


function TiledView:activate_tiles_for_region(x1, y1, x2, y2, background)
  local xo, yo = self.tiles_metric.x, self.tiles_metric.y
  local w, h = self.tiles_metric.w, self.tiles_metric.h

  -- compute min/max indexes of tiles needed to cover the region (x1, y1, x2, y2)
  local min_i, min_j = math.floor((x1 - xo) / w) + 1, math.floor((y1 - yo) / h) + 1
  local max_i, max_j = math.floor((x2 - xo) / w) + 1, math.floor((y2 - yo) / h) + 1

  -- prepare the tiles for drawing
  for i = min_i, max_j do
    local x = xo + (i - 1) * w
    for j = min_j, max_j do
      local y = yo + (j - 1) * h
      local tile_id = compose_tile_id(i, j)
      self:prepare_tile(tile_id, x, y, w, h, background)
    end
  end

  return xo + (min_i -1) * w, yo + (min_j - 1) * h, xo + max_i * w, yo + max_j * h
end


function TiledView:draw_text(font, text, x, y, color)
  local i, j = self:get_tile_indexes(x, y)
  local surface = self.named_surfaces[compose_tile_id(i, j)]
  local xp, yp = 0, y + font:get_height()
  if surface then
    renderer.set_current_surface(surface)
    xp = renderer.draw_text(font, text, x, y, color)
  else
    xp = x + font:get_width(text)
  end
  local ip, jp = self:get_tile_indexes(xp, yp)
  for jr = j, jp do
    for ir = i, ip do
      if ir > i or jr > j then
        surface = self.named_surfaces[compose_tile_id(ir, jr)]
        if surface then
          renderer.set_current_surface(surface)
          renderer.draw_text(font, text, x, y, color)
        end
      end
    end
  end
  return xp
end


function TiledView:draw_justified_text(font, color, text, align, x, y, w, h)
  local tw, th = font:get_width(text), font:get_height()
  if align == "center" then
    x = x + (w - tw) / 2
  elseif align == "right" then
    x = x + (w - tw)
  end
  y = y + common.round((h - th) / 2)
  return self:draw_text(font, text, x, y, color), y + th
end


function TiledView:draw_rect(x, y, w, h, color)
  local i, j = self:get_tile_indexes(x, y)
  local surface = self.named_surfaces[compose_tile_id(i, j)]
  if surface then
    renderer.set_current_surface(surface)
    renderer.draw_rect(x, y, w, h, color)
  end
  local ip = self:get_tile_indexes(x + w, y)
  for ir = i + 1, ip do
    surface = self.named_surfaces[compose_tile_id(ir, j)]
    if surface then
      renderer.set_current_surface(surface)
      renderer.draw_rect(x, y, w, h, color)
    end
  end
end


return TiledView
