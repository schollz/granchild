local lattice=include("kolor/lib/lattice")

local Granchild={}

local pitch_mods = {-12,-7,-5,0,5,7,12}

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
  m.voices = {}
  for i=1,m.num_voices do 
    m.voices[i] = {
      division = 4, -- 4 = quartner notes
      is_playing = false,
      is_recording = false,
      steps = {},
      step = 0,
      pitch_mod_i=4,
    }
  end

  -- setup lfos
  local mod_parameters={"speed","pos","jitter","size","spread"}
  m.mod_vals={}

  for i=1,m.num_voices do
    m.mod_vals[i]={}
    for j,mod in ipairs(mod_parameters) do
      local minmax=params:get(i..mod).get_range()
      local range=minmax
      local center_val=(range[2]-range[1])/2
      range={range[1]+(center_val-range[1])*math.random(0,100)/100,range[2]-(range[2]-center_val)*math.random(0,100)/100}
      m.mod_vals[i][j]={name=j..mod,minmax=minmax,range=range,period=math.random(1,64),offset=math.random()*30}
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
  m.grid_refresh.time=0.05
  m.grid_refresh.event=function()
	 m:update_lfos() -- use this metro to update lfos too
    if m.g.cols>0 and m.grid_on then
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()
  
  return m
end

function Granchild:emit_note(division)
  for i=1,self.num_voices do 
    if self.voices[i].is_playing and self.voices[i].division == division then 
      self.voices[i].step = self.voices[i].step + 1
      if self.voices[i].step > #self.voices[i].steps then 
        self.voices[i].step = 1 
      end
      local step_val = self.voices[i].steps[self.voices[i].step]
      params:set(i.."seek",util.linlin(1,16,0,1,step_val))
    end
  end
end

function Granchild:record_sequence(voice)
  self.recording_voice=voice
  self.recording_step=1
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
    self.pressed_buttons[row..","..col]=true
    if self.toggleable then
      print("holding kill timer")
      self.kill_timer=self:current_time()
    end
  else
    self.pressed_buttons[row..","..col]=nil
    if self.toggleable then
      self.kill_timer=self:current_time()-self.kill_timer
      print(self.kill_timer)
      if self.kill_timer>2 then
        self:toggle_grid(false)
      end
      self.kill_timer=0
    end
  end

  if col%4==2 and row<8 and on then
    -- change volume
    self:change_volume(row,col)
  elseif col%4 > 2 and on then
    -- change position
    self:change_position(row,col)
  elseif col%4 == 1 and (row ==3 or row == 4) and on then
    self:change_pitch_mod(row,col)
  elseif col%4 == 1 and (row == 1 or row == 2) and on then
    self:change_density_mod(row,col)
  end
end

function self:change_pitch_mod(row,col)
  local voice = math.floor((col-3)/4)+1
  params:delta(voice.."density",(row-1)*3-2)
end

function self:change_pitch_mod(row,col)
  local voice = math.floor((col-3)/4)+1
  self.voices[voice].pitch_mod_i = self.voices[voice].pitch_mod_i + (row-3)*3-2 
  self.voices[voice].pitch_mod_i = util.clamp(1,#pitch_mods,self.voices[voice].pitch_mod_i)
  params:set(voice.."pitch",pitch_mods[self.voices[voice].pitch_mod_i])
end

function self:change_position(row,col)
  local voice = math.floor((col-3)/4)+1
  col = col - 4*(voice-1) - 2 -- col now between 1 and 2
  local val = (row-1)*2+col
  print("change_position "..voice..": "..val)
  params:set(voice.."seek",util.linlin(1,16,0,1,val))
end

function self:change_volume(row,col)
  local voice = (col-2)/4+1
  print("change_volume "..voice)
  params:set(voice.."volume",util.linlin(7,1,-60,20,col))
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
  if self.show_graphic[2]>0 then
    self.show_graphic[2]=self.show_graphic[2]-1
  end

  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      self.visual[row][col]=0
    end
  end

  -- show the volume bar
  for i=1,self.num_voices do 
    local min_row = util.round(util.linlin(-60,20,7,1,params:get(i.."volume")))
    local col = 4*(i-1)+2
    for row=min_row,7 do 
      self.visual[row][col]=12
    end
  end

  -- show stop button
  for i=1,self.num_voices do 
    local row=7
    local col=4*(i-1)+1
    self.visual[row][col] = 4
    if self.voices[i].is_playing then 
      self.visual[row][col] = 14
    end
  end

  -- show rec button
  for i=1,self.num_voices do 
    local row=6
    local col=4*(i-1)+1
    self.visual[row][col] = 4
    if self.voices[i].is_recording then 
      self.visual[row][col] = 14
    end
  end

  -- show density modifiers
  for i=1,self.num_voices do 
    local val = util.linlin(1,40,0,15,params:get(i.."density"))
    for row=3,4 do
      self.visual[row][col] = val
    end
  end

  -- show pitch modifiers
  for i=1,self.num_voices do 
    local closet_mod = {4,10000}
    local current_pitch = params:get(i.."pitch")
    for j,p in ipairs(pitch_mods) do 
      if math.abs(p-current_pitch) < closet_mod[2] then 
        closet_mod =  {j,math.abs(p-current_pitch)}
      end
    end
    local val = util.linlin(1,#pitch_mods,0,15,closet_mod[1])
    for row=1,2 do
      self.visual[row][col] = val
    end
  end

  return self.visual
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



return Granchild
