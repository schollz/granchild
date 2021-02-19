-- arngulator

engine.name = "ZGlut"

local granchild = include("granchild/lib/granchild")

local function setup_params()
  params:add_separator("samples")
  local num_voices = 4
  for i=1,num_voices do
	params:add_group("sample "..i, 15)
    params:add_file(i .. "sample", i .. " sample")
    params:set_action(i .. "sample", function(file) engine.read(i, file) end)

    params:add_option(i .. "play", "play", {"off","on"}, 1)
    params:set_action(i .. "play", function(x) engine.gate(i, x-1) end)

    params:add_control(i .. "seek", "seek", controlspec.new(0, 1, "lin", 0.001, 0,"",1/1000))
    params:set_action(i .. "seek", function(value)  engine.seek(i, util.clamp(value+params:get(i.."pos"),0,1)) end)

    params:add_control(i .. "volume", i .. " volume",  controlspec.new(0, 1.0, "lin", 0.1, 0.25, "vol",1/10))
    params:set_action(i .. "volume", function(value) engine.volume(i, value) end)

    params:add_control(i .. "density", i .. " density",  controlspec.new(1, 40, "exp", 1, 12, "/beat",1/40))
    params:set_action(i .. "density", function(value) engine.density(i, value/(4*clock.get_beat_sec())) end)
  
    params:add_control(i .. "pitch", i .. " pitch",  controlspec.new(-48, 48, "lin", 1, 0, "note",1/48))
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
  
    params:add_control(i .. "size", i .. " size", controlspec.new(1, 15, "lin", 1, 5,"",1/15))
    params:set_action(i .. "size", function(value) engine.size(i, value * clock.get_beat_sec()/10 ) end)

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
	setup_params()

  granchild_grid = granchild:new({grid_on=true,toggleable=true})
  -- local kolor = include("kolor/lib/kolor")
  -- kolor_grid = kolor:new({grid_on=false,toggleable=true})
  -- kolor_grid:toggle_grid(false)
  -- granchild_grid:toggle_grid(true)
  -- kolor_grid:set_toggle_callback(function()
  --   granchild_grid:toggle_grid()
  -- end)
  -- granchild_grid:set_toggle_callback(function()
  --   kolor_grid:toggle_grid()
  -- end)


	-- setup grid
  -- kolor_grid.lattice.hard_sync()
  -- granchild_grid.lattice.hard_sync()


  params:set("1sample",_path.audio.."tape/0027.wav")
  params:set("1play",2)
  params:set("2sample",_path.audio.."tape/0026.wav")
  params:set("2play",2)
end
