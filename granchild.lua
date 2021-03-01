-- granchild v1.3.0
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
local param_list={"overtones","subharmonics","sizelfo","densitylfo","speedlfo","volumelfo","spreadlfo","jitterlfo","spread","jitter","size","pos","q","division","speed","send","q","cutoff","fade","pitch","density","volume","seek","play","sample"}
local param_list_delay={"delay_volume","delay_mod_freq","delay_mod_depth","delay_fdbk","delay_diff","delay_damp","delay_size","delay_time"}

local function bang(scene)
  for i=1,4 do
    for _,param_name in ipairs(param_list) do
      local p=params:lookup_param(i..param_name..scene)
      p:bang()
    end
    local p=params:lookup_param(i.."pattern"..scene)
    p:bang()
  end
  for _,param_name in ipairs(param_list_delay) do
    local p=params:lookup_param(param_name..scene)
    p:bang()
  end
end

local function setup_params()
  params:add_separator("samples")
  local num_voices=4
  local old_volume={0.25,0.25,0.25,0.25}
  for i=1,num_voices do
    params:add_group("sample "..i,51)
    params:add_option(i.."scene","scene",{"a","b"},1)
    params:set_action(i.."scene",function(scene)
      for _,param_name in ipairs(param_list) do
        params:hide(i..param_name..(3-scene))
        params:show(i..param_name..scene)
        local p=params:lookup_param(i..param_name..scene)
        p:bang()
      end
      local p=params:lookup_param(i.."pattern"..scene)
      p:bang()
      if params:get(i.."pattern"..scene)=="" or params:get(i.."pattern"..scene)=="[]" then
        granchild_grid:toggle_playing_voice(i,false)
      end
      if _menu.rebuild_params~=nil then
        _menu.rebuild_params()
      end
    end)
    for scene=1,2 do
      params:add_file(i.."sample"..scene,"sample")
      params:set_action(i.."sample"..scene,function(file)
        print("sample "..file)
        if file~="-" then
          engine.read(i,file)
          params:set(i.."play"..scene,2)
          if params:get(i.."sample"..(3-scene))=="-" then
            -- load for other scene by default
            params:set(i.."sample"..(3-scene),file,true)
            params:set(i.."play"..(3-scene),2,true)
          end
        end
      end)

      params:add_option(i.."play"..scene,"play",{"off","on"},1)
      params:set_action(i.."play"..scene,function(x) engine.gate(i,x-1) end)

      params:add_control(i.."seek"..scene,"seek",controlspec.new(0,1,"lin",0.001,0,"",0.001/1))
      params:set_action(i.."seek"..scene,function(value) engine.seek(i,util.clamp(value+params:get(i.."pos"..scene),0,1)) end)

      params:add_control(i.."volume"..scene,"volume",controlspec.new(0,1.0,"lin",0.05,0.25,"vol",0.05/1))
      params:set_action(i.."volume"..scene,function(value)
        engine.volume(i,value)
        -- turn off the delay if volume is zero
        if value==0 then
          engine.send(i,0)
        elseif value>0 and old_volume[i]==0 then
          engine.send(i,params:get(i.."send"..scene))
        end
        old_volume[i]=value
      end)
      params:add_option(i.."volumelfo"..scene,"volume lfo",{"off","on"},1)

      params:add_control(i.."density"..scene,"density",controlspec.new(1,40,"lin",1,12,"/beat",1/40))
      params:set_action(i.."density"..scene,function(value) engine.density(i,value/(4*clock.get_beat_sec())) end)
      params:add_option(i.."densitylfo"..scene,"density lfo",{"off","on"},1)

      params:add_control(i.."pitch"..scene,"pitch",controlspec.new(-48,48,"lin",1,0,"note",1/96))
      params:set_action(i.."pitch"..scene,function(value) engine.pitch(i,math.pow(0.5,-value/12)) end)

      params:add_taper(i.."fade"..scene,"att / dec",1,9000,1000,3,"ms")
      params:set_action(i.."fade"..scene,function(value) engine.envscale(i,value/1000) end)

      params:add_control(i.."cutoff"..scene,"filter cutoff",controlspec.new(20,20000,"exp",0,20000,"hz"))
      params:set_action(i.."cutoff"..scene,function(value) engine.cutoff(i,value) end)

      params:add_control(i.."q"..scene,"filter q",controlspec.new(0.00,1.00,"lin",0.01,1))
      params:set_action(i.."q"..scene,function(value) engine.q(i,value) end)

      params:add_control(i.."send"..scene,"delay send",controlspec.new(0.0,1.0,"lin",0.01,0.2))
      params:set_action(i.."send"..scene,function(value) engine.send(i,value) end)

      params:add_control(i.."speed"..scene,"speed",controlspec.new(-2.0,2.0,"lin",0.1,0,"",0.1/4))
      params:set_action(i.."speed"..scene,function(value) engine.speed(i,value) end)
      params:add_option(i.."speedlfo"..scene,"speed lfo",{"off","on"},1)

      params:add_option(i.."division"..scene,"division",division_names,5)
      params:set_action(i.."division"..scene,function(value)
        if granchild_grid~=nil then
          granchild_grid:set_division(i,divisions[value])
        end
      end)

      params:add_control(i.."pos"..scene,"pos",controlspec.new(-1/40,1/40,"lin",0.001,0))
      params:set_action(i.."pos"..scene,function(value) engine.seek(i,util.clamp(value+params:get(i.."seek"..scene),0,1)) end)

      params:add_control(i.."size"..scene,"size",controlspec.new(1,15,"lin",1,5,"",1/15))
      params:set_action(i.."size"..scene,function(value) engine.size(i,value*clock.get_beat_sec()/10) end)
      params:add_option(i.."sizelfo"..scene,"size lfo",{"off","on"},1)


      params:add_taper(i.."jitter"..scene,"jitter",0,500,0,5,"ms")
      params:set_action(i.."jitter"..scene,function(value) engine.jitter(i,value/1000) end)
      params:add_option(i.."jitterlfo"..scene,"jitter lfo",{"off","on"},2)

      params:add_taper(i.."spread"..scene,"spread",0,100,0,0,"%")
      params:set_action(i.."spread"..scene,function(value) engine.spread(i,value/100) end)
      params:add_option(i.."spreadlfo"..scene,"spread lfo",{"off","on"},2)

      params:add_option(i.."overtones"..scene,"overtones",{"off","on"},1)
      params:set_action(i.."overtones"..scene,function(value) engine.overtones(i,value-1) end)

      params:add_option(i.."subharmonics"..scene,"subharmonics",{"off","on"},1)
      params:set_action(i.."subharmonics"..scene,function(value) engine.subharmonics(i,value-1) end)

      params:add_text(i.."pattern"..scene,"pattern","")
      params:hide(i.."pattern"..scene)
      params:set_action(i.."pattern"..scene,function(value)
        if granchild_grid~=nil then
          granchild_grid:set_steps(i,value)
        end
      end)
    end
  end



  params:add_group("delay",17)
  params:add_option("delayscene","scene",{"a","b"},1)
  params:set_action("delayscene",function(scene)
    for _,param_name in ipairs(param_list_delay) do
      params:hide(i..param_name..(3-scene))
      params:show(i..param_name..scene)
      local p=params:lookup_param(i..param_name..scene)
      p:bang()
    end
  end)
  for scene=1,2 do
    -- effect controls
    -- delay time
    params:add_control("delay_time"..scene,"*".."delay time",controlspec.new(0.0,60.0,"lin",.01,2.00,""))
    params:set_action("delay_time"..scene,function(value) engine.delay_time(value) end)
    -- delay size
    params:add_control("delay_size"..scene,"*".."delay size",controlspec.new(0.5,5.0,"lin",0.01,2.00,""))
    params:set_action("delay_size"..scene,function(value) engine.delay_size(value) end)
    -- dampening
    params:add_control("delay_damp"..scene,"*".."delay damp",controlspec.new(0.0,1.0,"lin",0.01,0.10,""))
    params:set_action("delay_damp"..scene,function(value) engine.delay_damp(value) end)
    -- diffusion
    params:add_control("delay_diff"..scene,"*".."delay diff",controlspec.new(0.0,1.0,"lin",0.01,0.707,""))
    params:set_action("delay_diff"..scene,function(value) engine.delay_diff(value) end)
    -- feedback
    params:add_control("delay_fdbk"..scene,"*".."delay fdbk",controlspec.new(0.00,1.0,"lin",0.01,0.20,""))
    params:set_action("delay_fdbk"..scene,function(value) engine.delay_fdbk(value) end)
    -- mod depth
    params:add_control("delay_mod_depth"..scene,"*".."delay mod depth",controlspec.new(0.0,1.0,"lin",0.01,0.00,""))
    params:set_action("delay_mod_depth"..scene,function(value) engine.delay_mod_depth(value) end)
    -- mod rate
    params:add_control("delay_mod_freq"..scene,"*".."delay mod freq",controlspec.new(0.0,10.0,"lin",0.01,0.10,"hz"))
    params:set_action("delay_mod_freq"..scene,function(value) engine.delay_mod_freq(value) end)
    -- delay output volume
    params:add_control("delay_volume"..scene,"*".."delay output volume",controlspec.new(0.0,1.0,"lin",0,1.0,""))
    params:set_action("delay_volume"..scene,function(value) engine.delay_volume(value) end)
  end

  -- hide scene 2 initially
  for i=1,4 do
    for _,param_name in ipairs(param_list) do
      params:hide(i..param_name.."2")
    end
  end
  for _,param_name in ipairs(param_list_delay) do
    params:hide(param_name.."2")
  end

  bang(1)
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

  params:set("1sample1",_path.audio.."splices/lr.wav")
  -- params:set("1sample1","/home/we/dust/audio/kolor/bank12/loop_break_bpm175.wav")
  -- params:set("1cutoff1",3000)
  -- params:set("1cutoff2",3000)
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
