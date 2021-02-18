-- arngulator

engine.name = "ZGlut"

local mod_parameters = {"speed","pos","jitter","size","spread"}
local mod_vals = {}
local num_voices = 4

local function setup_params()
  params:add_separator("samples")
  
  for i=1,num_voices do
	params:add_group("sample "..i, 15)
    params:add_file(i .. "sample", i .. " sample")
    params:set_action(i .. "sample", function(file) engine.read(i, file) end)

    params:add_option(i .. "play", "play", {"off","on"}, 1)
    params:set_action(i .. "play", function(x) engine.gate(i, x-1) end)

    params:add_control(i .. "seek", "seek", controlspec.new(0, 1, "lin", 0.001, 0))
    params:set_action(i .. "seek", function(value)  engine.seek(i, util.clamp(value+params:get(i.."pos"),0,1)) end)

    params:add_taper(i .. "volume", i .. " volume", -60, 20, 0, 0, "dB")
    params:set_action(i .. "volume", function(value) engine.volume(i, math.pow(10, value / 20)) end)

    params:add_taper(i .. "density", i .. " density", 1, 40, 1, 1, "/beat")
    params:set_action(i .. "density", function(value) engine.density(i, value/(4*clock.get_beat_sec())) end)
  
    params:add_taper(i .. "pitch", i .. " pitch", -48, 48, 0, 0, "st")
    params:set_action(i .. "pitch", function(value) engine.pitch(i, math.pow(0.5, -value / 12)) end)
    
    params:add_taper(i .. "fade", i .. " att / dec", 1, 9000, 1000, 3, "ms")
    params:set_action(i .. "fade", function(value) engine.envscale(i, value / 1000) end)
    
    params:add_control(i .. "cutoff", "filter cutoff", controlspec.new(20, 20000, "exp", 0, 20000, "hz"))
    params:set_action(i .. "cutoff", function(value) engine.cutoff(i, value) end)
    
    params:add_control(i .. "q", "filter q", controlspec.new(0.00, 1.00, "lin", 0.01, 1))
    params:set_action(i .. "q", function(value) engine.q(i, value) end)

    params:add_control(i .. "send", "delay send", controlspec.new(0.0, 1.0, "lin", 0.01, .2))
    params:set_action(i .. "send", function(value) engine.send(i, value) end)
  
    -- these parameters oscillate

    params:add_taper(i .. "speed", i .. " speed", -10, 10, 0, 0, "%")
    params:set_action(i .. "speed", function(value) engine.speed(i, value / 100) end)
  
    params:add_control(i .. "pos", "pos", controlspec.new(-1/40, 1/40, "lin", 0.001, 0))
    params:set_action(i .. "pos", function(value)  engine.seek(i, util.clamp(value+params:get(i.."seek"),0,1)) end)
  
    params:add_taper(i .. "jitter", i .. " jitter", 0, 500, 0, 5, "ms")
    params:set_action(i .. "jitter", function(value) engine.jitter(i, value / 1000) end)
  
    params:add_taper(i .. "size", i .. " size", clock.get_beat_sec()/10*1000, 1.5*clock.get_beat_sec()*1000, 0.1, 5, "ms", 0.1/500)
    params:set_action(i .. "size", function(value) engine.size(i, value / 1000) end)

    params:add_taper(i .. "spread", i .. " spread", 0, 100, 0, 0, "%")
    params:set_action(i .. "spread", function(value) engine.spread(i, value / 100) end)

  end

  params:add_group("delay", 8)
  -- effect controls
  -- delay time
  params:add_control("delay_time", "*" .. "delay time", controlspec.new(0.0, 60.0, "lin", .01, 2.00, ""))
  params:set_action("delay_time", function(value) engine.delay_time(value) end)
  -- delay size
  params:add_control("delay_size", "*" .. "delay size", controlspec.new(0.5, 5.0, "lin", 0.01, 2.00, ""))
  params:set_action("delay_size", function(value) engine.delay_size(value) end)
  -- dampening 
  params:add_control("delay_damp", "*" .. "delay damp", controlspec.new(0.0, 1.0, "lin", 0.01, 0.10, ""))
  params:set_action("delay_damp", function(value) engine.delay_damp(value) end)
  -- diffusion
  params:add_control("delay_diff", "*" .. "delay diff", controlspec.new(0.0, 1.0, "lin", 0.01, 0.707, ""))
  params:set_action("delay_diff", function(value) engine.delay_diff(value) end)
  -- feedback
  params:add_control("delay_fdbk", "*" .. "delay fdbk", controlspec.new(0.00, 1.0, "lin", 0.01, 0.20, ""))
  params:set_action("delay_fdbk", function(value) engine.delay_fdbk(value) end)
  -- mod depth
  params:add_control("delay_mod_depth", "*" .. "delay mod depth", controlspec.new(0.0, 1.0, "lin", 0.01, 0.00, ""))
  params:set_action("delay_mod_depth", function(value) engine.delay_mod_depth(value) end)
  -- mod rate
  params:add_control("delay_mod_freq", "*" .. "delay mod freq", controlspec.new(0.0, 10.0, "lin", 0.01, 0.10, "hz"))
  params:set_action("delay_mod_freq", function(value) engine.delay_mod_freq(value) end)
  -- delay output volume
  params:add_control("delay_volume", "*" .. "delay output volume", controlspec.new(0.0, 1.0, "lin", 0, 1.0, ""))
  params:set_action("delay_volume", function(value) engine.delay_volume(value) end)


  params:bang()
end

function init() 
	-- TODO initialize LFO parameters for each parameter on each voice

	setup_params()
	setup_lfos()
	-- TODO constant loop for refreshing grid
end

function loop()
	-- update lfo for all active voices and all parameters
	update_lfos()
end


-- lfo stuff

local function setup_lfos()
	for i=1,num_voices do
		mod_vals[i] = {}
		for j,mod in ipairs(mod_parameters) do
			local minmax = params:get(i..mod).get_range()
			local range = minmax
			local center_val = (range[2]-range[1])/2
			range = {range[1]+(center_val-range[1])*math.random(1,100)/100,center_val+(center_val-range[2])*math.random(1,100)/100}
			mod_vals[i][j] = {name=j..mod,minmax=minmax,range=range,period=math.random(1,64),offset=math.random()*30}
		end
	end
end

local function update_lfos()
	for i=1,num_voices do
		if params:get(i.."play") == 2 then
			for j,m in ipairs(mod_vals[i]) do
				params:set(m.name,util.clamp(util.linlin(-1,1,m.range[1],m.range[2],calculate_lfo(m.period,m.offset)),m.minmax[1],m.minmax[2]))
			end
		end
	end
end

local function calculate_lfo(period_in_beats,offset)
  if period_in_beats==0 then
    return 1
  else
    return math.sin(2*math.pi*clock.get_beats()/period_in_beats+offset)
  end
end