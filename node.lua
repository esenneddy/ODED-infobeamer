--gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)
gl.setup(1024, 768)

local margin_top = math.floor(HEIGHT * 0.1)
local margin_bottom = math.floor(HEIGHT * 0.05)
local margin_left = math.floor(WIDTH * 0.1)
local margin_right = math.floor(WIDTH * 0.05)

font_background = resource.load_font("Lubalin Graph Bold.ttf")
font_foreground = resource.load_font("BundesSans-Regular.otf")
font_foreground_bold = resource.load_font("BundesSans-Bold.otf")

foreground_r = 0
foreground_g = 0.2
foreground_b = 0.6

slogan = "THW Detmold. Wir helfen."
slogan_height = 50

animation_duration = 1.5

display_max_events = 20

weekdays_de = {'So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'}

kopfzeile = resource.load_image("Kopfzeile.png")
wortbildmarke = resource.load_image("Wortbildmarke.png")
gelb = resource.load_image("Gelb.png")
linie = resource.load_image("Linie.png")
blau = resource.load_image("Blau.png")

local thw_blue = resource.create_colored_texture(0, 0.2, 0.6, 1)

local foreground_text_height = 42

local foreground_line_spacing = foreground_text_height + 25
local foreground_line_spacing_small = foreground_text_height + 5

local show_events = math.floor((HEIGHT-margin_top-margin_bottom-55)/(foreground_line_spacing + foreground_line_spacing_small))

foreground_start_y = margin_top + 55

local json = require "json"

local loaded_events
local events

util.file_watch("Termine.json", function(content)
    loaded_events = json.decode(content)
    events={}
    if (display_max_events < #loaded_events) then
      for i=1, display_max_events do
        events[i] = loaded_events[i]
      end
    else
      events = loaded_events
    end
end)

function draw_background()
  kopfzeile:draw(0, 0, WIDTH, 60) -- Blue bar
  wortbildmarke:draw(WIDTH-194-10, 10, WIDTH-10, 50) -- Zahnrad and Text
  gelb:draw(margin_left-60, margin_top, margin_left-30, margin_top+55) -- Yellow rectangle
  linie:draw(margin_left-30, margin_top, margin_left-27, HEIGHT) -- Dotted line
end

function parse_date(my_date)
  local pattern = "(%d+)-(%d+)-(%d+)"
  local xyear, xmonth, xday = my_date:match(pattern)
  return os.time({year = xyear, month = xmonth, day = xday})
end

function write_event_line(my_event, my_y, my_alpha)
	local my_event_string = ""
	if (my_event.start_date) then
    my_start_date = parse_date(my_event.start_date)
    local temp = os.date("*t", my_start_date)
		my_event_string = weekdays_de[temp['wday']] .. os.date(", %d.%m.", my_start_date)
	end
	if (my_event.end_date) then
    my_end_date = parse_date(my_event.end_date)
    local temp = os.date("*t", my_end_date)
		my_event_string = my_event_string .. " bis " .. weekdays_de[temp['wday']] .. os.date(", %d.%m.", my_end_date)
	end
	if (my_event.place) then
		my_event_string = my_event_string .. " (" .. my_event.place .. ")"
	end
  blau:draw(margin_left-27, math.floor(my_y+foreground_text_height/2)-math.floor(foreground_text_height/6), margin_left-27+math.floor(foreground_text_height/3), math.floor(my_y+foreground_text_height/2)+math.floor(foreground_text_height/6), my_alpha)
	font_foreground_bold:write(margin_left, my_y, my_event_string, foreground_text_height, foreground_r, foreground_g, foreground_b, my_alpha)
	my_y = my_y + foreground_line_spacing_small
	font_foreground:write(margin_left, my_y, my_event.description, foreground_text_height, foreground_r, foreground_g, foreground_b, my_alpha)
	my_y = my_y + foreground_line_spacing
	return my_y
end

function render_schedule()
	local y = foreground_start_y
	local now = sys.now()
	if (not first_run) then
		start_time = now
		state = 0
		first_element_shown = 1
		first_run = 1
	end
	local num_events = table.getn(events)
	if (num_events <= show_events) then
		for idx, event in ipairs(events) do
			y = write_event_line(event, y, 1)
		end
	else
		if (state == 1) then -- Fade out first line
			y = foreground_start_y
			y = write_event_line(events[first_element_shown], y, 1-(now-start_time)/animation_duration)
			if (first_element_shown<num_events) then
				for i=1, math.min(show_events-1, num_events-first_element_shown), 1 do
					y = write_event_line(events[first_element_shown+i], y, 1)
				end
			end
			if (now >= start_time + animation_duration) then
				if (first_element_shown >= num_events) then
					state = 4
					first_element_shown = 1
				else
					state = 2
				end
				start_time = now
			end
		elseif (state == 2) then -- Shift all remaining lines up
			y = foreground_start_y + foreground_line_spacing + foreground_line_spacing_small
			for i=1, math.min(show_events-1, num_events-first_element_shown), 1 do
				write_event_line(events[first_element_shown + i], y-((foreground_line_spacing+foreground_line_spacing_small)*(now-start_time)/animation_duration), 1)
				y = y + foreground_line_spacing + foreground_line_spacing_small
			end
			if (now >= start_time + animation_duration) then
				if (first_element_shown > num_events - show_events) then
					state = 1
				else
					state = 3
				end
				first_element_shown = first_element_shown + 1
				start_time = now
			end
		elseif (state == 3) then -- Fade in last line
			for i=0, math.min(show_events-2, num_events-first_element_shown+1), 1 do
				y = write_event_line(events[first_element_shown + i], y, 1)
			end
      local my_alpha = math.min((now-start_time)/animation_duration, 1)
			y = write_event_line(events[first_element_shown + show_events - 1], y, my_alpha)
			if (now >= start_time + 2*animation_duration) then
				state = 1
				start_time = now
			end
    elseif (state == 4) then -- Display Slogan
      local slogan_width = font_background:width(slogan, slogan_height)
      local hor_center = margin_left + math.floor((WIDTH-margin_right-margin_left)/2)
      local ver_center = margin_top + math.floor((HEIGHT-margin_bottom-margin_top)/2)
      local my_alpha
      if (now-start_time <= animation_duration) then
        my_alpha = (now-start_time)/animation_duration
      elseif (now-start_time >= 10-animation_duration) then
        my_alpha = 1-((now-start_time)-(10-animation_duration))/animation_duration
      else
        my_alpha = 1
      end
      font_background:write(hor_center-math.floor(slogan_width/2), ver_center-math.floor(slogan_height/2), slogan, slogan_height, foreground_r, foreground_g, foreground_b, my_alpha)
      if (now >= start_time + 10) then
        state = 0
        start_time = now
      end
		else -- state should be 0: Display first lines
			y = foreground_start_y
			for i=1, show_events, 1 do
				y = write_event_line(events[i], y, math.max(0, math.min(1, (now-start_time)/animation_duration+1-i)))
			end
			if (now >= start_time + animation_duration * show_events) then
				state = 1
				start_time = now
			end
		end
	end
end

function node.render()
	gl.clear(1, 1, 1, 1)
	draw_background()
	render_schedule()
end
