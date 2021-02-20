local lattice=include("kolor/lib/lattice")

local Granchild={}

local pitch_mods={-12,-7,-5,0,5,7,12}


function Granchild:new(args)
  local m=setmetatable({},{__index=Granchild})
  local args=args==nil and {} or args
  m.grid_on=args.grid_on==nil and true or args.grid_on
  m.toggleable=args.toggleable==nil and false or args.toggleable

  -- initiate the grid
  m.g=grid.connect()
  m.grid_width=16
  if m.g.cols==8 then
    m.grid_width=8
  end
  m.g.key=function(x,y,z)
    if m.g.cols>0 and m.grid_on then
      m:grid_key(x,y,z)
    end
  end
  print("grid columns: "..m.g.cols)

  -- allow toggling
  m.kill_timer=0

  -- setup visual
  m.visual={}
  for i=1,8 do
    m.visual[i]={}
    for j=1,m.grid_width do
      m.visual[i][j]=0
    end
  end

  -- debouncing and blinking
  m.blink_count=0
  m.blinky={}
  for i=1,m.grid_width do
    m.blinky[i]=1 -- 1 = fast, 16 = slow
  end

  -- keep track of pressed buttons
  m.pressed_buttons={}

  -- define num voices
  m.num_voices=4

  -- setup step sequencer
  m.voices={}
  for i=1,m.num_voices do
    m.voices[i]={
      division=4,-- 4 = quartner notes
      is_playing=false,
      is_recording=false,
      steps={},
      step=0,
      pitch_mod_i=4,
    }
  end

  -- setup lfos
  local mod_parameters={
    {name="jitter",range={5,50},lfo={32,64}},
    {name="spread",range={0,100},lfo={16,24}},
  }
  m.mod_vals={}

  for i=1,m.num_voices do
    m.mod_vals[i]={}
    for j,mod in ipairs(mod_parameters) do
      local minmax=mod.range
      local range=minmax
      -- local center_val=(range[2]-range[1])/2
      -- range={range[1]+(center_val-range[1])*math.random(0,100)/100,range[2]-(range[2]-center_val)*math.random(0,100)/100}
      m.mod_vals[i][j]={name=i..mod.name,minmax=minmax,range=range,period=math.random(mod.lfo[1],mod.lfo[2]),offset=math.random()*30}
    end
  end

  -- setup lattice
  -- lattice
  -- for keeping time of all the divisions
  m.lattice=lattice:new({
    ppqn=8
  })
  m.timers={}
  for division=1,16 do
    m.timers[division]={}
    m.timers[division].lattice=m.lattice:new_pattern{
      action=function(t)
        m:emit_note(division)
      end,
      division=1/division
    }
  end
  m.lattice:start()


  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=0.1
  m.grid_refresh.event=function()
    m:update_lfos() -- use this metro to update lfos too
    if m.grid_on then
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()

  -- metro for checking if keys are held to toggle re-presses
  m.key_held=metro.init()
  m.key_held.time=0.1
  m.key_held.event=function()
    -- only on column 1, 5, 9, 13
    local cols={1,5,9,13}
    local cur_time=m:current_time()
    for _,col in ipairs(cols) do
      for row=1,8 do
        if m.pressed_buttons[row..","..col]~=nil then
          local elapsed_time=cur_time-m.pressed_buttons[row..","..col]
          if elapsed_time>0.2 then
            m:key_press(row,col,true)
          end
        end
      end
    end
  end
  m.key_held:start()

  return m
end

function Granchild:emit_note(division)
  for i=1,self.num_voices do
    if self.voices[i].is_playing and self.voices[i].division==division then
      self.voices[i].step=self.voices[i].step+1
      if self.voices[i].step>#self.voices[i].steps then
        self.voices[i].step=1
      end
      local step_val=self.voices[i].steps[self.voices[i].step]
      params:set(i.."seek",util.linlin(1,21,0,1,step_val)+(math.random()-0.5)/100)
    end
  end
end

function Granchild:toggle_grid(on)
  if on==nil then
    self.grid_on=not self.grid_on
  else
    self.grid_on=on
  end
  if self.grid_on then
    self.g=grid.connect()
    self.g.key=function(x,y,z)
      print("granchild grid: ",x,y,z)
      if self.grid_on then
        self:grid_key(x,y,z)
      end
    end
  else
    if self.toggle_callback~=nil then
      self.toggle_callback()
    end
  end
end

function Granchild:set_toggle_callback(fn)
  self.toggle_callback=fn
end

function Granchild:grid_key(x,y,z)
  self:key_press(y,x,z==1)
  self:grid_redraw()
end

function Granchild:key_press(row,col,on)
  if on then
    self.pressed_buttons[row..","..col]=self:current_time()
    if row==8 and col==2 and self.toggleable then
      self.kill_timer=self:current_time()
    end
  else
    self.pressed_buttons[row..","..col]=nil
    if row==8 and col==2 and self.toggleable then
      self.kill_timer=self:current_time()-self.kill_timer
      if self.kill_timer>1 then
        print("switching!")
        self:toggle_grid(false)
      end
      self.kill_timer=0
    end
  end

  if (col%4==2 or col%4==3 or col%4==0) and row<8 and on then
    -- change position
    self:change_position(row,col)
  elseif col%4==1 and (row==1 or row==2) and on then
    self:change_density_mod(row,col)
  elseif col%4==1 and (row==3 or row==4) and on then
    self:change_size(row,col)
  elseif col%4==1 and (row==5 or row==6) and on then
    self:change_speed(row,col)
  elseif col%4==1 and (row==7 or row==8) and on then
    self:change_volume(row,col)
  elseif col%4==3 and row==8 and on then
    self:toggle_recording(col)
  elseif col%4==0 and row==8 and on then
    self:toggle_playing(col)
  end
end


function Granchild:toggle_recording(col)
  local voice=math.floor((col-1)/4)+1
  self.voices[voice].is_recording=not self.voices[voice].is_recording
  if self.voices[voice].is_recording then
    self.voices[voice].is_playing=false
  end
end

function Granchild:toggle_playing(col)
  local voice=math.floor((col-1)/4)+1
  self.voices[voice].is_playing=not self.voices[voice].is_playing
  if self.voices[voice].is_playing then
    self.voices[voice].is_recording=false
  end
end


function Granchild:change_density_mod(row,col)
  local voice=math.floor((col-1)/4)+1
  local diff=-1*((row-1)*2-1)
  params:delta(voice.."density",diff)
  print("change_density_mod "..voice.." "..diff.." "..params:get(voice.."density"))
end

function Granchild:change_size(row,col)
  local voice=math.floor((col-1)/4)+1
  local diff=-1*((row-3)*2-1)
  params:delta(voice.."size",diff)
  print("change_size "..voice.." "..diff.." "..params:get(voice.."size"))
end

function Granchild:change_speed(row,col)
  local voice=math.floor((col-1)/4)+1
  local diff=-1*((row-5)*2-1)
  params:delta(voice.."speed",diff)
  print("change_speed "..voice.." "..diff.." "..params:get(voice.."speed"))
end

function Granchild:change_volume(row,col)
  local voice=math.floor((col-1)/4)+1
  local diff=-1*((row-7)*2-1)
  params:delta(voice.."volume",diff)
  print("change_volume "..voice.." "..diff.." "..params:get(voice.."volume"))
end

-- function Granchild:change_pitch_mod(row,col)
--   local voice =  math.floor((col-1)/4)+1
--   local diff = -1 * ((row-3)*2-1)
--   self.voices[voice].pitch_mod_i = self.voices[voice].pitch_mod_i + diff
--   self.voices[voice].pitch_mod_i = util.clamp(self.voices[voice].pitch_mod_i,1,#pitch_mods)
--   print(self.voices[voice].pitch_mod_i)
--   params:set(voice.."pitch",pitch_mods[self.voices[voice].pitch_mod_i])
--   print("change_pitch_mod "..voice.." "..diff.." "..params:get(voice.."pitch"))
-- end

function Granchild:change_position(row,col)
  local voice=math.floor((col-2)/4)+1
  col=col-4*(voice-1)-1 -- col now between 1 and 3
  local val=(row-1)*3+col
  if self.voices[voice].is_recording then
    table.insert(self.voices[voice].steps,val)
  end
  print("change_position "..voice..": "..val)
  params:set(voice.."seek",util.linlin(1,21,0,1,val)+(math.random()-0.5)/100)
end


function Granchild:get_visual()
  --- update the blinky thing
  self.blink_count=self.blink_count+1
  if self.blink_count>1000 then
    self.blink_count=0
  end
  for i,_ in ipairs(self.blinky) do
    if i==1 then
      self.blinky[i]=1-self.blinky[i]
    else
      if self.blink_count%i==0 then
        self.blinky[i]=0
      else
        self.blinky[i]=1
      end
    end
  end

  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      self.visual[row][col]=0
    end
  end

  -- show stop/play button
  for i=1,self.num_voices do
    local row=8
    local col=4*(i-1)+4
    self.visual[row][col]=4
    if self.voices[i].is_playing then
      self.visual[row][col]=14
    end
  end

  -- show rec button
  for i=1,self.num_voices do
    local row=8
    local col=4*(i-1)+3
    self.visual[row][col]=4
    if self.voices[i].is_recording then
      self.visual[row][col]=14
    end
  end

  -- show density modifiers
  for i=1,self.num_voices do
    local val=util.linlin(1,40,0,15,params:get(i.."density"))
    local col=4*(i-1)+1
    self.visual[1][col]=util.round(val)
    self.visual[2][col]=15-util.round(val)
  end

  -- show size modifiers
  for i=1,self.num_voices do
    local val=util.linlin(1,15,0,15,params:get(i.."size"))
    local col=4*(i-1)+1
    self.visual[3][col]=util.round(val)
    self.visual[4][col]=15-util.round(val)
  end

  -- show speed modifiers
  for i=1,self.num_voices do
    local val=util.linlin(-2,2,0,15,params:get(i.."speed"))
    local col=4*(i-1)+1
    self.visual[5][col]=util.round(val)
    self.visual[6][col]=15-util.round(val)
  end

  -- show the volume
  for i=1,self.num_voices do
    local val=util.linlin(0,1,0,15,params:get(i.."volume"))
    local col=4*(i-1)+1
    self.visual[7][col]=util.round(val)
    self.visual[8][col]=15-util.round(val)
  end

  -- -- show pitch modifiers
  -- for i=1,self.num_voices do
  --   local col=4*(i-1)+1
  --   local closet_mod = {4,10000}
  --   local current_pitch = params:get(i.."pitch")
  --   for j,p in ipairs(pitch_mods) do
  --     if math.abs(p-current_pitch) < closet_mod[2] then
  --       closet_mod =  {j,math.abs(p-current_pitch)}
  --     end
  --   end
  --   local val = util.linlin(1,#pitch_mods,0,15,closet_mod[1])
  --   for row=3,4 do
  --     self.visual[row][col] = util.round(val)
  --   end
  -- end

  -- show current step
  for i=1,self.num_voices do
    local step=self.voices[i].step
    if step>0 then
      for j=1,step do
        local row,col=self:pos_to_row_col((j-1)%21+1)
        self.visual[row][col]=self.visual[row][col]+3
        if self.visual[row][col]>15 then
          self.visual[row][col]=1
        end
      end
    end
  end
  -- show current position
  for i=1,self.num_voices do
    local pos=math.floor(util.round(util.linlin(0,1,1,21,params:get(i.."seek"))))
    local row,col=self:pos_to_row_col(pos)
    col=col+(i-1)*4
    self.visual[row][col]=15
  end

  return self.visual
end

function Granchild:pos_to_row_col(pos)
  local row=math.floor((pos-1)/3)+1
  local col=pos-(row-1)*3+1
  return row,col
end

function Granchild:current_time()
  return clock.get_beat_sec()*clock.get_beats()
end

function Granchild:grid_redraw()
  self.g:all(0)
  local gd=self:get_visual()
  for row=1,8 do
    for col=1,self.grid_width do
      if gd[row][col]~=0 then
        self.g:led(col,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end


-- lfo stuff
function Granchild:update_lfos()
  for i=1,self.num_voices do
    if params:get(i.."play")==2 then
      for j,m in ipairs(self.mod_vals[i]) do
        params:set(m.name,util.clamp(util.linlin(-1,1,m.range[1],m.range[2],self:calculate_lfo(m.period,m.offset)),m.minmax[1],m.minmax[2]))
      end
    end
  end
end

function Granchild:calculate_lfo(period_in_beats,offset)
  if period_in_beats==0 then
    return 1
  else
    return math.sin(2*math.pi*clock.get_beats()/period_in_beats+offset)
  end
end


return Granchild
