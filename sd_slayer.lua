SD_SLAYER_LOADED = false

SD_SLAYER_VERSION = '0.0.2'

SD_SLAYER_SETTINGS = nil
SD_SLAYER_ACTIVE_NPCS = nil
SD_SLAYER_SKIPPED_NPCS = nil
SD_SLAYER_FRAME = nil
SD_SLAYER_FRAME_POS = nil
SD_SLAYER_ZONE = nil
SD_SLAYERS_EVENTS_BOUND = nil

function SD_SLAYER_ON_INIT(addon, frame)
  SD_SLAYERS_EVENTS_BOUND = false
  
  SD_SLAYER_FRAME = ui.GetFrame('sd_slayer');
  
  SD_SLAYER_LOAD_SETTINGS();
  
  if SD_SLAYER_LOADED == false then
    _G['SD_SLAYER_ON_CHAT_OLD'] = ui.Chat
    
    ui.Chat = SD_SLAYER_ON_CHAT
    
    CHAT_SYSTEM('-> sd_slayer');
    
    SD_SLAYER_LOADED = true;
  end
  
  if SD_SLAYER_SETTINGS.DISABLED == 1 then
    return;
  end
  
  SD_SLAYER_FRAME:SetMargin(
    0,
    SD_SLAYER_SETTINGS.POS_TOP,
    SD_SLAYER_SETTINGS.POS_RIGHT,
    0
  );
  
  if SD_SLAYER_SETTINGS.FRAME_LOCKED == 1 then
    SD_SLAYER_FRAME:EnableMove(0);
  end
  
  addon:RegisterMsg('UPDATE_ADVENTURE_BOOK', 'SD_SLAYER_ON_AJ_MSG'); 
  addon:RegisterMsg('MON_ENTER_SCENE', 'SD_SLAYER_ON_MON_ENTER');
  
  SD_SLAYER_FRAME:SetEventScript(ui.RBUTTONUP, 'SD_SLAYER_CTX_MENU');
  
  SD_SLAYERS_EVENTS_BOUND = true;
  
  local zone = GetZoneName();
  
  if SD_SLAYER_ZONE ~= zone then
    SD_SLAYER_ACTIVE_NPCS = {};
    SD_SLAYER_SKIPPED_NPCS = {};
  else
    SD_SLAYER_UPDATE_FRAME();
  end
  
  SD_SLAYER_ZONE = zone;
end

function SD_SLAYER_ON_CHAT(args)
  SD_SLAYER_ON_CHAT_OLD(args)
  
  args = args:gsub('^/[rwpysg] ', '')
  
  if string.sub(args, 1, 8) == '/slayer ' then
    args = args:gsub('/slayer ', '');
    
    if args == 'on' then
      SD_SLAYER_DISABLE(0);
    elseif args == 'version' then
      CHAT_SYSTEM(SD_SLAYER_VERSION);
    end
  end
  
  local f = GET_CHATFRAME();
  f:GetChild('mainchat'):ShowWindow(0);
  f:ShowWindow(0);
end

function SD_SLAYER_ON_MON_ENTER(frame, msg, str, handle)
  local actor = world.GetActor(handle);
  
  local clsid = actor:GetType();
  
  if SD_SLAYER_ACTIVE_NPCS[clsid] or SD_SLAYER_SKIPPED_NPCS[clsid] then
    return
  end
  
  local npc = GetClassByType('Monster', clsid);
  
  if npc.Journal ~= nil and npc.Journal ~= 'None' then
    SD_SLAYER_ACTIVE_NPCS[clsid] = npc;
  else
    SD_SLAYER_SKIPPED_NPCS[clsid] = true;
  end
  
  SD_SLAYER_UPDATE_FRAME();
end

function SD_SLAYER_ON_AJ_MSG(frame, msg, arg_str, arg_num)
  if msg ~= 'UPDATE_ADVENTURE_BOOK' then
    return
  end
  
  if arg_num == ABT_MON_KILL_COUNT then
    SD_SLAYER_UPDATE_FRAME();
  end
end

function SD_SLAYER_UPDATE_FRAME()
  local frame = SD_SLAYER_FRAME;
  
  local x = 0;
  local y = 0;
  
  for clsid, npc in pairs(SD_SLAYER_ACTIVE_NPCS) do
    local text = frame:CreateOrGetControl('richtext', clsid, 0, y, 0, 0);
    
    local count = GetMonKillCount(pc, clsid);
    
    local pts, max_pts, _ = _GET_ADVENTURE_BOOK_MONSTER_POINT(npc.MonRank == 'Boss', count);
    
    text:EnableHitTest(0);
    
    text:SetGravity(ui.RIGHT, ui.TOP);
    
    local str = string.format('{@st42b}%s × %d (%d / %d){/}', npc.Name, count, pts, max_pts);
    
    text:SetText(str);
    
    y = y + text:GetHeight();
    
    local w = text:GetWidth();
    
    if w > x then
      x = w;
    end
  end
  
  frame:Resize(x, y);
end

function SD_SLAYER_CTX_MENU(frame, msg, arg_str, arg_num)
  local ctx = ui.CreateContextMenu('SD_SLAYER_CTX', '', 0, 0, 0, 0);

  if SD_SLAYER_SETTINGS.FRAME_LOCKED == 1 then
    ui.AddContextMenuItem(ctx, 'Unlock Frame', 'SD_SLAYER_SET_FRAME_LOCK(0)');
  else
    ui.AddContextMenuItem(ctx, 'Lock Frame', 'SD_SLAYER_SET_FRAME_LOCK(1)');
  end
  
  ui.AddContextMenuItem(ctx, 'Disable', 'SD_SLAYER_ON_DISABLE_CLICK');
  
  ui.OpenContextMenu(ctx);
end

function SD_SLAYER_DISABLE(flag)
  if flag == 0 then
    if SD_SLAYERS_EVENTS_BOUND == false then
      CHAT_SYSTEM('sd_slayer will be enabled the next time you load a map.');
    else
      SD_SLAYER_FRAME:ShowWindow(1);
    end
  else
    SD_SLAYER_FRAME:ShowWindow(0);
  end
  
  SD_SLAYER_SETTINGS.DISABLED = flag;
  
  SD_SLAYER_SAVE_SETTINGS();
end

function SD_SLAYER_SET_FRAME_LOCK(flag, init)
  SD_SLAYER_SETTINGS.FRAME_LOCKED = flag;
  
  if flag == 1 then
    SD_SLAYER_FRAME:EnableMove(0);
  else
    SD_SLAYER_FRAME:EnableMove(1);
  end
  
  if not init then
    SD_SLAYER_SAVE_SETTINGS();
  end
end

function SD_SLAYER_SAVE_SETTINGS()
  local f = nil;

  local status, err = pcall(function()
    f = io.open('☢sd_slayer.ini', 'w')
    
    if SD_SLAYER_SETTINGS.DISABLED == 1 then
      f:write(string.format("DISABLED=1\n"));
    end
    
    if SD_SLAYER_SETTINGS.POS_TOP ~= nil then
      f:write(string.format("POS_TOP=%d\n", SD_SLAYER_SETTINGS.POS_TOP));
    end
    
    if SD_SLAYER_SETTINGS.POS_RIGHT ~= nil then
      f:write(string.format("POS_RIGHT=%d\n", SD_SLAYER_SETTINGS.POS_RIGHT));
    end
    
    if SD_SLAYER_SETTINGS.FRAME_LOCKED == 1 then
      f:write(string.format("FRAME_LOCKED=1\n"));
    end
    
    f:close();
  end)

  if not status then
    if f ~= nil then
      f:close();
    end
    
    CHAT_SYSTEM("Couldn't save the settings file: " .. err);
  end
end

function SD_SLAYER_ON_DISABLE_CLICK()
  ui.MsgBox('Are you sure?{nl}Use {#00A550}{ol}/slayer on{/}{/}  to enable it again.', 'SD_SLAYER_DISABLE(1)', 'None');
end

function SD_SLAYER_ON_DRAG_START()
  SD_SLAYER_FRAME_POS = SD_SLAYER_FRAME:GetMargin();
end

function SD_SLAYER_ON_DRAG_END()
  local pos = SD_SLAYER_FRAME:GetMargin();
  
  if pos.top ~= SD_SLAYER_FRAME_POS.top or pos.right ~= SD_SLAYER_FRAME_POS.right then
    SD_SLAYER_SETTINGS.POS_TOP = pos.top;
    SD_SLAYER_SETTINGS.POS_RIGHT = pos.right;
    
    SD_SLAYER_SAVE_SETTINGS();
  end
end

function SD_SLAYER_LOAD_SETTINGS()
  SD_SLAYER_SETTINGS = {
    DISABLED = 0,
    FRAME_LOCKED = 0,
    POS_TOP = 365,
    POS_RIGHT = 35
  };
  
  local f = nil;
  
  local status, err = pcall(function()
    f = io.open('☢sd_slayer.ini', 'r')
    
    if f == nil then
      return;
    end
    
    local data = f:read('*all');
    
    for line in data:gmatch("[^\n]+") do
      local idx = string.find(line, '=');
      
      if idx then
        local prop = string.sub(line, 0, idx - 1);
        local value = string.sub(line, idx + 1);
        
        SD_SLAYER_SETTINGS[prop] = tonumber(value);
      end
    end
    
    f:close();
  end)

  if not status then
    if f ~= nil then
      f:close();
    end
    
    CHAT_SYSTEM("Couldn't read the settings file: " .. err);
  end
end
