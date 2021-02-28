-- granchild v1.2.0
-- granular sequencer
--
-- llllllll.co/t/granchild
--
-- thx @artfwo, @cfdrake, 
-- @justmat
--

engine.name="ZGlut"

local granchild=include("granchild/lib/granchild")

local position={1,1}
local press_positions={{0,0},{0,0}}
local norns_screen={}
local divisions={1,2,4,6,8,12,16}
local division_names={"2 wn","wn","hn","hn-t","qn","qn-t","eighth"}


local function setup_params()
  params:add_separator("samples")
  local num_voices=4
  local old_volume={0.25,0.25,0.25,0.25}
  for i=1,num_voices do
    params:add_group("sample "..i,16)
    params:add_file(i.."sample","sample")
    params:set_action(i.."sample",function(file)
      print("sample "..file)
      if file~="-" then
        engine.read(i,file)
        params:set(i.."play",2)
      end
    end)

    params:add_option(i.."play","play",{"off","on"},1)
    params:set_action(i.."play",function(x) engine.gate(i,x-1) end)

    params:add_control(i.."seek","seek",controlspec.new(0,1,"lin",0.001,0,"",0.001/1))
    params:set_action(i.."seek",function(value) engine.seek(i,util.clamp(value+params:get(i.."pos"),0,1)) end)

    params:add_control(i.."volume","volume",controlspec.new(0,1.0,"lin",0.05,0.25,"vol",0.05/1))
    params:set_action(i.."volume",function(value) 
      engine.volume(i,value) 
      -- turn off the delay if volume is zero
      if value == 0 then
        engine.send(i,0)
      elseif value > 0 and old_volume[i]==0 then 
        engine.send(i,params:get(i.."send"))
      end
      old_volume[i]=value
    end)

    params:add_control(i.."density","density",controlspec.new(1,40,"lin",1,12,"/beat",1/40))
    params:set_action(i.."density",function(value) engine.density(i,value/(4*clock.get_beat_sec())) end)

    params:add_control(i.."pitch","pitch",controlspec.new(-48,48,"lin",1,0,"note",1/96))
    params:set_action(i.."pitch",function(value) engine.pitch(i,math.pow(0.5,-value/12)) end)

    params:add_taper(i.."fade","att / dec",1,9000,1000,3,"ms")
    params:set_action(i.."fade",function(value) engine.envscale(i,value/1000) end)

    params:add_control(i.."cutoff","filter cutoff",controlspec.new(20,20000,"exp",0,20000,"hz"))
    params:set_action(i.."cutoff",function(value) engine.cutoff(i,value) end)

    params:add_control(i.."q","filter q",controlspec.new(0.00,1.00,"lin",0.01,1))
    params:set_action(i.."q",function(value) engine.q(i,value) end)

    params:add_control(i.."send","delay send",controlspec.new(0.0,1.0,"lin",0.01,0.2))
    params:set_action(i.."send",function(value) engine.send(i,value) end)

    params:add_control(i.."speed","speed",controlspec.new(-2.0,2.0,"lin",0.1,0,"",0.1/4))
    params:set_action(i.."speed",function(value) engine.speed(i,value) end)

    params:add_option(i.."division","division",division_names,5)
  params:set_action(i.."division",function(value) if granchild_grid~=nil then granchild_grid:set_division(i,divisions[value]) end end)

  params:add_control(i.."pos","pos",controlspec.new(-1/40,1/40,"lin",0.001,0))
  params:set_action(i.."pos",function(value) engine.seek(i,util.clamp(value+params:get(i.."seek"),0,1)) end)

  params:add_control(i.."size","size",controlspec.new(1,15,"lin",1,5,"",1/15))
  params:set_action(i.."size",function(value) engine.size(i,value*clock.get_beat_sec()/10) end)

  -- these parameters oscillate

  params:add_taper(i.."jitter","jitter",0,500,0,5,"ms")
  params:set_action(i.."jitter",function(value) engine.jitter(i,value/1000) end)

  params:add_taper(i.."spread","spread",0,100,0,0,"%")
  params:set_action(i.."spread",function(value) engine.spread(i,value/100) end)

  params:add_text(i.."pattern","pattern","")
  params:hide(i.."pattern")
  params:set_action(i.."pattern",function(value) if granchild_grid ~= nil then granchild_grid:set_steps(i,value) end end)
end

params:add_group("lfos",6)
params:add_option("jitterlfo","jitter",{"off","on"},2)
params:add_option("spreadlfo","spread",{"off","on"},2)
params:add_option("volumelfo","volume",{"off","on"},1)
params:add_option("speedlfo","speed",{"off","on"},1)
params:add_option("densitylfo","density",{"off","on"},1)
params:add_option("sizelfo","size",{"off","on"},1)


params:add_group("delay",8)
-- effect controls
-- delay time
params:add_control("delay_time","*".."delay time",controlspec.new(0.0,60.0,"lin",.01,2.00,""))
params:set_action("delay_time",function(value) engine.delay_time(value) end)
-- delay size
params:add_control("delay_size","*".."delay size",controlspec.new(0.5,5.0,"lin",0.01,2.00,""))
params:set_action("delay_size",function(value) engine.delay_size(value) end)
-- dampening
params:add_control("delay_damp","*".."delay damp",controlspec.new(0.0,1.0,"lin",0.01,0.10,""))
params:set_action("delay_damp",function(value) engine.delay_damp(value) end)
-- diffusion
params:add_control("delay_diff","*".."delay diff",controlspec.new(0.0,1.0,"lin",0.01,0.707,""))
params:set_action("delay_diff",function(value) engine.delay_diff(value) end)
-- feedback
params:add_control("delay_fdbk","*".."delay fdbk",controlspec.new(0.00,1.0,"lin",0.01,0.20,""))
params:set_action("delay_fdbk",function(value) engine.delay_fdbk(value) end)
-- mod depth
params:add_control("delay_mod_depth","*".."delay mod depth",controlspec.new(0.0,1.0,"lin",0.01,0.00,""))
params:set_action("delay_mod_depth",function(value) engine.delay_mod_depth(value) end)
-- mod rate
params:add_control("delay_mod_freq","*".."delay mod freq",controlspec.new(0.0,10.0,"lin",0.01,0.10,"hz"))
params:set_action("delay_mod_freq",function(value) engine.delay_mod_freq(value) end)
-- delay output volume
params:add_control("delay_volume","*".."delay output volume",controlspec.new(0.0,1.0,"lin",0,1.0,""))
params:set_action("delay_volume",function(value) engine.delay_volume(value) end)


params:bang()
end

function init()
  setup_params()

  granchild_grid=granchild:new({grid_on=true,toggleable=true})
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

  clock.run(function()
    while true do
      clock.sleep(1/10) -- refresh
      -- toggle norns screen between the granchild and kolor
      if granchild_grid.grid_on then
        norns_screen=granchild_grid.visual
      elseif kolor_grid~=nil and kolor_grid.grid_on then
        norns_screen=kolor_grid.visual
      end
      redraw()
    end
  end) -- start the grid redraw clock

  -- params:set("1sample",_path.audio.."splices/rach1.wav")
  -- params:set("2sample",_path.audio.."splices/glass2.wav")
  -- params:set("1cutoff",3000)
  --params:set("2cutoff",3000)
  --params:set("3cutoff",3000)
  -- params:set("volumelfo",2)
  --params:set("sizelfo",2)
  --params:set("densitylfo",2)
  --params:set("speedlfo",2)
end



function enc(k,d)
  if k==2 then
    position[1]=position[1]+d
    if position[1]>8 then
      position[1]=8
    elseif position[1]<1 then
      position[1]=1
    end
  elseif k==3 then
    position[2]=position[2]+d
    if position[2]>16 then
      position[2]=16
    elseif position[2]<1 then
      position[2]=1
    end
  end
end

function key(k,z)
  if k>1 then
    if z==1 then
      press_positions[k-1]={position[1],position[2]}
    end
    granchild_grid:key_press(press_positions[k-1][1],press_positions[k-1][2],z==1)
  end
end



function redraw()
  screen.clear()
  screen.level(0)
  screen.rect(1,1,128,64)
  screen.fill()

  if norns_screen~=nil and norns_screen[1]~=nil then
    local gd=norns_screen
    rows=#gd
    cols=#gd[1]
    for row=1,rows do
      for col=1,cols do
        if gd[row][col]~=0 then
          screen.level(gd[row][col])
          screen.rect(col*8-7,row*8-8+1,6,6)
          screen.fill()
        end
      end
    end
    screen.level(15)
    screen.rect(position[2]*8-7,position[1]*8-8+1,7,7)
    screen.stroke()
  end

  screen.update()
end

function rerun()
  norns.script.load(norns.state.script)
end

