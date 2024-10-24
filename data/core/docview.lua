local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local translate = require "core.doc.translate"
local ime = require "core.ime"
local View = require "core.view"

local TILE_CHARACTERS, TILE_LINES = 80, 40

---@class core.docview : core.view
---@field super core.view
local DocView = View:extend()

DocView.context = "session"

local function move_to_line_offset(dv, line, col, offset)
  local xo = dv.last_x_offset
  if xo.line ~= line or xo.col ~= col then
    xo.offset = dv:get_col_x_offset(line, col)
  end
  xo.line = line + offset
  xo.col = dv:get_x_offset_col(line + offset, xo.offset)
  return xo.line, xo.col
end


function DocView:get_content_body_offset()
  local x, y = self:get_content_offset()
  return x + self:get_gutter_width(), y + style.padding.y
end

function DocView:get_tile_indexes(x, y)
  local h = self.tiles_metric.line_height * TILE_LINES
  local w = self.tiles_metric.char_width * TILE_CHARACTERS
  local x_o, y_o = self:get_content_body_offset()
  return math.floor((x - x_o) / w) + 1, math.floor((y - y_o) / h) + 1
end


function DocView:get_tile_size()
  return self.tiles_metric.char_width * TILE_CHARACTERS, self.tiles_metric.line_height * TILE_LINES
end


-- return true if text is too far-off in a tile on the right
function DocView:draw_line_content_text(font, text, x, y, color)
  local x_o, y_o = self:get_content_body_offset()
  local tile_w, tile_h = self:get_tile_size()
  local tile_i, tile_j = self:get_tile_indexes(x, y)

  if tile_j < 1 then return x, false end

  -- compute x_tile as the x coordinate of the left border of the tile
  local x_tile = x_o + tile_w * (tile_i - 1)
  local x_rlimit = self.position.x + self.size.x

  local x_text_end
  while x_tile < x_rlimit and (not x_text_end or x_tile < x_text_end) do
    if x_tile + tile_w > self.position.x then
      -- the tile is visible on the screen: get its surface and draw on it
      if tile_i > 0 then
        self:surface_for_content(tile_i, tile_j)
        x_text_end = renderer.draw_text(font, text, x, y, color)
      end
    end
    x_tile = x_tile + tile_w
    tile_i = tile_i + 1
  end

  return x_text_end, x_tile >= x_rlimit
end


function DocView:draw_line_content_rect(x, y, w, h, color)
  local x_o, y_o = self:get_content_body_offset()
  local tile_w, tile_h = self:get_tile_size()
  local tile_i, tile_j = self:get_tile_indexes(x, y)

  -- compute x_tile_s as the x coordinate of the left border of the tile
  local x_tile = x_o + tile_w * (tile_i - 1)

  while x_tile < self.position.x + self.size.x and x_tile < x + w do
    if x_tile + tile_w > self.position.x then
      -- the tile is visible on the screen: get its surface and draw on it
      self:surface_for_content(tile_i, tile_j)
      renderer.draw_rect(x, y, w, h, color)
    end
    x_tile = x_tile + tile_w
    tile_i = tile_i + 1
  end
end


-- We provide a surface to draw the content (document's text body) at the given tile
-- coordinates. We ensure the surface has the background set since the beginning.
function DocView:surface_for_content(tile_i, tile_j)
  local x_o, y_o = self:get_content_body_offset()
  local w, h = self.tiles_metric.char_width * TILE_CHARACTERS, self.tiles_metric.line_height * TILE_LINES
  local x, y = x_o + (tile_i - 1) * w, y_o + (tile_j - 1) * h

  -- identify the list of surfaces for the column identified by tile_i
  local column_surfaces = self.content_surfaces[tile_i]
  if not column_surfaces then
    column_surfaces = { }
    self.content_surfaces[tile_i] = column_surfaces
  end

  local surface = self.surface_from_list(column_surfaces, tile_j, x, y, w, h)
  -- FIXME: it can be expensive to generate this id string every time
  local tile_id = string.format("c %d %d", tile_i, tile_j)
  self:set_surface_to_draw(surface, tile_id, style.background)
end


function DocView:surface_for_gutter(tile_j)
  local _, y_o = self:get_content_offset()
  local x_o = common.round(self.position.x)
  local w, h = self.tiles_metric.gutter_width, self.tiles_metric.line_height * TILE_LINES
  local x, y = x_o, y_o + (tile_j - 1) * h
  local surface = self.surface_from_list(self.gutter_surfaces, tile_j, x, y, w, h)
  local tile_id = string.format("g %d", tile_j)
  self:set_surface_to_draw(surface, tile_id, style.background)
end


function DocView:setup_tiles_for_drawing()
  local new_lh = self:get_line_height()
  local new_cw = math.ceil(self:get_font():get_width(' '))
  local new_gw, gpad = self:get_gutter_width()
  -- FIXME: include also the surface scale here

  if new_lh ~= self.tiles_metric.line_height or new_cw ~= self.tiles_metric.char_width then
    self.content_surfaces = { }
    self.gutter_surfaces = { }
  elseif new_gw ~= self.tiles_metric.gutter_width then
    self.gutter_surfaces = { }
  end
  self.tiles_metric.line_height  = new_lh
  self.tiles_metric.char_width   = new_cw
  self.tiles_metric.gutter_width = new_gw

  self.surface_to_draw = { }
end


DocView.translate = {
  ["previous_page"] = function(doc, line, col, dv)
    local min, max = dv:get_visible_line_range()
    return line - (max - min), 1
  end,

  ["next_page"] = function(doc, line, col, dv)
    if line == #doc.lines then
      return #doc.lines, #doc.lines[line]
    end
    local min, max = dv:get_visible_line_range()
    return line + (max - min), 1
  end,

  ["previous_line"] = function(doc, line, col, dv)
    if line == 1 then
      return 1, 1
    end
    return move_to_line_offset(dv, line, col, -1)
  end,

  ["next_line"] = function(doc, line, col, dv)
    if line == #doc.lines then
      return #doc.lines, math.huge
    end
    return move_to_line_offset(dv, line, col, 1)
  end,
}


function DocView:new(doc)
  DocView.super.new(self)
  self.cursor = "ibeam"
  self.scrollable = true
  self.doc = assert(doc)
  self.font = "code_font"
  self.last_x_offset = {}
  self.ime_selection = { from = 0, size = 0 }
  self.ime_status = false
  self.hovering_gutter = false
  self.tiles_metric = { line_height = 0, char_width = 0, gutter_width = 0 }
  self.content_surfaces = { }
  self.gutter_surfaces = { }
  self.v_scrollbar:set_forced_status(config.force_scrollbar_status)
  self.h_scrollbar:set_forced_status(config.force_scrollbar_status)
end


function DocView:try_close(do_close)
  if self.doc:is_dirty()
  and #core.get_views_referencing_doc(self.doc) == 1 then
    core.command_view:enter("Unsaved Changes; Confirm Close", {
      submit = function(_, item)
        if item.text:match("^[cC]") then
          do_close()
        elseif item.text:match("^[sS]") then
          self.doc:save()
          do_close()
        end
      end,
      suggest = function(text)
        local items = {}
        if not text:find("^[^cC]") then table.insert(items, "Close Without Saving") end
        if not text:find("^[^sS]") then table.insert(items, "Save And Close") end
        return items
      end
    })
  else
    do_close()
  end
end


function DocView:get_name()
  local post = self.doc:is_dirty() and "*" or ""
  local name = self.doc:get_name()
  return name:match("[^/%\\]*$") .. post
end


function DocView:get_filename()
  if self.doc.abs_filename then
    local post = self.doc:is_dirty() and "*" or ""
    return common.home_encode(self.doc.abs_filename) .. post
  end
  return self:get_name()
end


function DocView:get_scrollable_size()
  if not config.scroll_past_end then
    local _, _, _, h_scroll = self.h_scrollbar:get_track_rect()
    return self:get_line_height() * (#self.doc.lines) + style.padding.y * 2 + h_scroll
  end
  return self:get_line_height() * (#self.doc.lines - 1) + self.size.y
end

function DocView:get_h_scrollable_size()
  return math.huge
end


function DocView:get_font()
  return style[self.font]
end


function DocView:get_line_height()
  return math.floor(self:get_font():get_height() * config.line_height)
end


function DocView:get_gutter_width()
  local padding = style.padding.x * 2
  return self:get_font():get_width(#self.doc.lines) + padding, padding
end


function DocView:get_line_screen_position(line, col)
  local x, y = self:get_content_body_offset()
  local lh = self:get_line_height()
  y = y + (line-1) * lh
  if col then
    return x + self:get_col_x_offset(line, col), y
  else
    return x, y
  end
end


function DocView:get_line_text_y_offset()
  local lh = self:get_line_height()
  local th = self:get_font():get_height()
  return (lh - th) / 2
end


function DocView:get_visible_line_range()
  local x, y, x2, y2 = self:get_content_bounds()
  local lh = self:get_line_height()
  local minline = math.max(1, math.floor((y - style.padding.y) / lh) + 1)
  local maxline = math.min(#self.doc.lines, math.floor((y2 - style.padding.y) / lh) + 1)
  return minline, maxline
end


function DocView:get_col_x_offset(line, col)
  local default_font = self:get_font()
  local _, indent_size = self.doc:get_indent_info()
  default_font:set_tab_size(indent_size)
  local column = 1
  local xoffset = 0
  for _, type, text in self.doc.highlighter:each_token(line) do
    local font = style.syntax_fonts[type] or default_font
    if font ~= default_font then font:set_tab_size(indent_size) end
    local length = #text
    if column + length <= col then
      xoffset = xoffset + font:get_width(text)
      column = column + length
      if column >= col then
        return xoffset
      end
    else
      for char in common.utf8_chars(text) do
        if column >= col then
          return xoffset
        end
        xoffset = xoffset + font:get_width(char)
        column = column + #char
      end
    end
  end

  return xoffset
end


function DocView:get_x_offset_col(line, x)
  local line_text = self.doc.lines[line]

  local xoffset, last_i, i = 0, 1, 1
  local default_font = self:get_font()
  local _, indent_size = self.doc:get_indent_info()
  default_font:set_tab_size(indent_size)
  for _, type, text in self.doc.highlighter:each_token(line) do
    local font = style.syntax_fonts[type] or default_font
    if font ~= default_font then font:set_tab_size(indent_size) end
    local width = font:get_width(text)
    -- Don't take the shortcut if the width matches x,
    -- because we need last_i which should be calculated using utf-8.
    if xoffset + width < x then
      xoffset = xoffset + width
      i = i + #text
    else
      for char in common.utf8_chars(text) do
        local w = font:get_width(char)
        if xoffset >= x then
          return (xoffset - x > w / 2) and last_i or i
        end
        xoffset = xoffset + w
        last_i = i
        i = i + #char
      end
    end
  end

  return #line_text
end


function DocView:resolve_screen_position(x, y)
  local ox, oy = self:get_line_screen_position(1)
  local line = math.floor((y - oy) / self:get_line_height()) + 1
  line = common.clamp(line, 1, #self.doc.lines)
  local col = self:get_x_offset_col(line, x - ox)
  return line, col
end


function DocView:scroll_to_line(line, ignore_if_visible, instant)
  local min, max = self:get_visible_line_range()
  if not (ignore_if_visible and line > min and line < max) then
    local x, y = self:get_line_screen_position(line)
    local _, _, _, scroll_h = self.h_scrollbar:get_track_rect()
    self.scroll.to.y = math.max(0, y - (self.size.y - scroll_h) / 2)
    if instant then
      self.scroll.y = self.scroll.to.y
    end
  end
end


function DocView:scroll_to_make_visible(line, col)
  local _, oy = self:get_content_offset()
  local _, ly = self:get_line_screen_position(line, col)
  local lh = self:get_line_height()
  local _, _, _, scroll_h = self.h_scrollbar:get_track_rect()
  self.scroll.to.y = common.clamp(self.scroll.to.y, ly - oy - self.size.y + scroll_h + lh * 2, ly - oy - lh)
  local gw = self:get_gutter_width()
  local xoffset = self:get_col_x_offset(line, col)
  local xmargin = 3 * self:get_font():get_width(' ')
  local xsup = xoffset + gw + xmargin
  local xinf = xoffset - xmargin
  local _, _, scroll_w = self.v_scrollbar:get_track_rect()
  local size_x = math.max(0, self.size.x - scroll_w)
  if xsup > self.scroll.x + size_x then
    self.scroll.to.x = xsup - size_x
  elseif xinf < self.scroll.x then
    self.scroll.to.x = math.max(0, xinf)
  end
end

function DocView:on_mouse_moved(x, y, ...)
  DocView.super.on_mouse_moved(self, x, y, ...)

  self.hovering_gutter = false
  local gw = self:get_gutter_width()

  if self:scrollbar_hovering() or self:scrollbar_dragging() then
    self.cursor = "arrow"
  elseif gw > 0 and x >= self.position.x and x <= (self.position.x + gw) then
    self.cursor = "arrow"
    self.hovering_gutter = true
  else
    self.cursor = "ibeam"
  end

  if self.mouse_selecting then
    local l1, c1 = self:resolve_screen_position(x, y)
    local l2, c2, snap_type = table.unpack(self.mouse_selecting)
    if keymap.modkeys["ctrl"] then
      if l1 > l2 then l1, l2 = l2, l1 end
      self.doc.selections = { }
      for i = l1, l2 do
        self.doc:set_selections(i - l1 + 1, i, math.min(c1, #self.doc.lines[i]), i, math.min(c2, #self.doc.lines[i]))
      end
    else
      if snap_type then
        l1, c1, l2, c2 = self:mouse_selection(self.doc, snap_type, l1, c1, l2, c2)
      end
      self.doc:set_selection(l1, c1, l2, c2)
    end
  end
end


function DocView:mouse_selection(doc, snap_type, line1, col1, line2, col2)
  local swap = line2 < line1 or line2 == line1 and col2 <= col1
  if swap then
    line1, col1, line2, col2 = line2, col2, line1, col1
  end
  if snap_type == "word" then
    line1, col1 = translate.start_of_word(doc, line1, col1)
    line2, col2 = translate.end_of_word(doc, line2, col2)
  elseif snap_type == "lines" then
    col1, col2 = 1, math.huge
  end
  if swap then
    return line2, col2, line1, col1
  end
  return line1, col1, line2, col2
end


function DocView:on_mouse_pressed(button, x, y, clicks)
  if button ~= "left" or not self.hovering_gutter then
    return DocView.super.on_mouse_pressed(self, button, x, y, clicks)
  end
  local line = self:resolve_screen_position(x, y)
  if keymap.modkeys["shift"] then
    local sline, scol, sline2, scol2 = self.doc:get_selection(true)
    if line > sline then
      self.doc:set_selection(sline, 1, line,  #self.doc.lines[line])
    else
      self.doc:set_selection(line, 1, sline2, #self.doc.lines[sline2])
    end
  else
    if clicks == 1 then
      self.doc:set_selection(line, 1, line, 1)
    elseif clicks == 2 then
      self.doc:set_selection(line, 1, line, #self.doc.lines[line])
    end
  end
  return true
end


function DocView:on_mouse_released(...)
  DocView.super.on_mouse_released(self, ...)
  self.mouse_selecting = nil
end


function DocView:on_text_input(text)
  self.doc:text_input(text)
end

function DocView:on_ime_text_editing(text, start, length)
  self.doc:ime_text_editing(text, start, length)
  self.ime_status = #text > 0
  self.ime_selection.from = start
  self.ime_selection.size = length

  -- Set the composition bounding box that the system IME
  -- will consider when drawing its interface
  local line1, col1, line2, col2 = self.doc:get_selection(true)
  local col = math.min(col1, col2)
  self:update_ime_location()
  self:scroll_to_make_visible(line1, col + start)
end

---Update the composition bounding box that the system IME
---will consider when drawing its interface
function DocView:update_ime_location()
  if not self.ime_status then return end

  local line1, col1, line2, col2 = self.doc:get_selection(true)
  local x, y = self:get_line_screen_position(line1)
  local h = self:get_line_height()
  local col = math.min(col1, col2)

  local x1, x2 = 0, 0

  if self.ime_selection.size > 0 then
    -- focus on a part of the text
    local from = col + self.ime_selection.from
    local to = from + self.ime_selection.size
    x1 = self:get_col_x_offset(line1, from)
    x2 = self:get_col_x_offset(line1, to)
  else
    -- focus the whole text
    x1 = self:get_col_x_offset(line1, col1)
    x2 = self:get_col_x_offset(line2, col2)
  end

  ime.set_location(x + x1, y, x2 - x1, h)
end

function DocView:update()
  -- scroll to make caret visible and reset blink timer if it moved
  local line1, col1, line2, col2 = self.doc:get_selection()
  if (line1 ~= self.last_line1 or col1 ~= self.last_col1 or
      line2 ~= self.last_line2 or col2 ~= self.last_col2) and self.size.x > 0 then
    if core.active_view == self and not ime.editing then
      self:scroll_to_make_visible(line1, col1)
    end
    core.blink_reset()
    self.last_line1, self.last_col1 = line1, col1
    self.last_line2, self.last_col2 = line2, col2
  end

  -- update blink timer
  if self == core.active_view and not self.mouse_selecting then
    local T, t0 = config.blink_period, core.blink_start
    local ta, tb = core.blink_timer, system.get_time()
    if ((tb - t0) % T < T / 2) ~= ((ta - t0) % T < T / 2) then
      core.redraw = true
    end
    core.blink_timer = tb
  end

  self:update_ime_location()

  DocView.super.update(self)
end


function DocView:draw_line_highlight(y)
  local gw = self.tiles_metric.gutter_width
  local tile_w = self:get_tile_size()
  local x = self:get_content_body_offset()
  local w = math.ceil((self.scroll.x + self.size.x - gw) / tile_w) * tile_w
  local h = self.tiles_metric.line_height
  self:draw_line_content_rect(x, y, w, h, style.line_highlight)
end


function DocView:draw_line_text(line, x, y)
  local default_font = self:get_font()
  local tx, ty = x, y + self:get_line_text_y_offset()
  local last_token = nil
  local tokens = self.doc.highlighter:get_line(line).tokens
  local tokens_count = #tokens
  if string.sub(tokens[tokens_count], -1) == "\n" then
    last_token = tokens_count - 1
  end

  local is_off_screen_right
  for tidx, type, text in self.doc.highlighter:each_token(line) do
    local color = style.syntax[type]
    local font = style.syntax_fonts[type] or default_font
    -- do not render newline, fixes issue #1164
    if tidx == last_token then text = text:sub(1, -2) end
    tx, is_off_screen_right = self:draw_line_content_text(font, text, tx, ty, color)
    if is_off_screen_right then break end
  end
  return self:get_line_height()
end

function DocView:draw_caret(x, y)
    local w, h = style.caret_width, self.tiles_metric.line_height
    self:set_surface_for("cursor", x, y, w, h)
end

function DocView:draw_line_body(line, x, y)
  -- draw highlight if any selection ends on this line
  local draw_highlight = false
  local hcl = config.highlight_current_line
  if hcl ~= false then
    for lidx, line1, col1, line2, col2 in self.doc:get_selections(false) do
      if line1 == line then
        if hcl == "no_selection" then
          if (line1 ~= line2) or (col1 ~= col2) then
            draw_highlight = false
            break
          end
        end
        draw_highlight = true
        break
      end
    end
  end
  if draw_highlight and core.active_view == self then
    self:draw_line_highlight(y)
  end

  -- draw selection if it overlaps this line
  local lh = self.tiles_metric.line_height
  for lidx, line1, col1, line2, col2 in self.doc:get_selections(true) do
    if line >= line1 and line <= line2 then
      local text = self.doc.lines[line]
      if line1 ~= line then col1 = 1 end
      if line2 ~= line then col2 = #text + 1 end
      local x1 = x + self:get_col_x_offset(line, col1)
      local x2 = x + self:get_col_x_offset(line, col2)
      if x1 ~= x2 then
        self:draw_line_content_rect(x1, y, x2 - x1, lh, style.selection)
      end
    end
  end

  -- draw line's text
  return self:draw_line_text(line, x, y)
end


function DocView:draw_line_gutter(line, x, y, width)
  local color = style.line_number
  for _, line1, _, line2 in self.doc:get_selections(true) do
    if line >= line1 and line <= line2 then
      color = style.line_number2
      break
    end
  end
  x = x + style.padding.x
  local lh = self.tiles_metric.line_height
  local _, tile_j = self:get_tile_indexes(x, y)
  self:surface_for_gutter(tile_j)
  common.draw_text(self:get_font(), color, line, "right", x, y, width, lh)
  return lh
end


function DocView:draw_ime_decoration(line1, col1, line2, col2)
  local x, y = self:get_line_screen_position(line1)
  local line_size = math.max(1, SCALE)
  local lh = self.tiles_metric.line_height

  -- Draw IME underline
  local x1 = self:get_col_x_offset(line1, col1)
  local x2 = self:get_col_x_offset(line2, col2)
  -- FIXME: we have a problem here: we need to allocate a surface to draw IME
  --        stuff but I don't know how large it need to get.
  -- local surface = self:surface_for("ime", ???)
  renderer.draw_rect(x + math.min(x1, x2), y + lh - line_size, math.abs(x1 - x2), line_size, style.text)

  -- Draw IME selection
  local col = math.min(col1, col2)
  local from = col + self.ime_selection.from
  local to = from + self.ime_selection.size
  x1 = self:get_col_x_offset(line1, from)
  if from ~= to then
    x2 = self:get_col_x_offset(line1, to)
    line_size = style.caret_width
    renderer.draw_rect(x + math.min(x1, x2), y + lh - line_size, math.abs(x1 - x2), line_size, style.caret)
  end
  self:draw_caret(x + x1, y)
end


function DocView:draw_overlay()
  if core.active_view == self then
    local minline, maxline = self:get_visible_line_range()
    -- draw caret if it overlaps this line
    local T = config.blink_period
    for _, line1, col1, line2, col2 in self.doc:get_selections() do
      if line1 >= minline and line1 <= maxline
      and system.window_has_focus() then
        if false and ime.editing then
          self:draw_ime_decoration(line1, col1, line2, col2)
        else
          if config.disable_blink
          or (core.blink_timer - core.blink_start) % T < T / 2 then
            self:draw_caret(self:get_line_screen_position(line1, col1))
          end
        end
      end
    end
  end
end


function DocView:draw()
  self:setup_tiles_for_drawing()
  local _, indent_size = self.doc:get_indent_info()
  self:get_font():set_tab_size(indent_size)

  local visible_minline, visible_maxline = self:get_visible_line_range()
  local lh = self.tiles_metric.line_height

  -- Compute minlines and maxlines rounded in a way to complete the corresponding
  -- tiles.
  -- Compute first min and max tile_i, j indexes corresponding to tiles visible
  -- on the screen.
  -- TODO: computations befor for min/max tile can be done with a single function
  -- call.
  local min_tile_j = math.floor((visible_minline - 1) / TILE_LINES)
  local max_tile_j = math.floor((visible_maxline - 1) / TILE_LINES + 1)
  local min_tile_i = self:get_tile_indexes(self.position.x, 0)
  local max_tile_i = self:get_tile_indexes(self.position.x + self.size.x, 0)
  local minline = math.max(1, min_tile_j * TILE_LINES + 1)
  local maxline = math.min(#self.doc.lines, max_tile_j * TILE_LINES)

  if min_tile_j <= 1 then
    local x_o, y_o = self:get_content_offset()
    self:set_surface_for("ypad", x_o, y_o, self.size.x, style.padding.y, style.background)
  end

  -- Ensure surfaces visible on the screen are "presented" to be drawn
  for tile_j = min_tile_j + 1, max_tile_j + 1 do
    for tile_i = min_tile_i, max_tile_i do
      self:surface_for_content(tile_i, tile_j)
    end
  end

  local x, y = self:get_line_screen_position(minline)
  local gw, gpad = self:get_gutter_width()
  for i = minline, maxline do
    y = y + (self:draw_line_gutter(i, self.position.x, y, gpad and gw - gpad or gw) or lh)
  end

  local pos = self.position
  x, y = self:get_line_screen_position(minline)
  -- the clip below ensure we don't write on the gutter region. On the
  -- right side it is redundant with the Node's clip.
  core.push_clip_rect(pos.x + gw, pos.y, self.size.x - gw, self.size.y)
  for i = minline, maxline do
    y = y + (self:draw_line_body(i, x, y) or lh)
  end
  self:draw_overlay()
  core.pop_clip_rect()

  self:draw_scrollbar()
  self:present_surfaces()
end


return DocView
