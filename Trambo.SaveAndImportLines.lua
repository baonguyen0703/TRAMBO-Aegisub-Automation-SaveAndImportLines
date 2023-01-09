script_name="@TRAMBO: Save and Import Lines"
script_description="Save and import lines"
script_author="TRAMBO"
script_version="1.1.1" --fixed bug in checking and generating required files

include("Trambo.Library.lua") --ver1.5.1

save = "Save"
update = "Update"
cancel = "Cancel"
ok = "OK"
import = "Import"
manage = "Manage"
remove = "Remove"
rename = "Rename"

path_file = trambo .. "\\SaveLines_preset_path.txt"
default_preset_file = trambo .. "\\SaveLines Preset.txt"

namePat = "preset=(.-);"

sub=nil
sel=nil
act=nil
meta=nil
styles=nil

function main(sub_table, sel_table, active_line)
  sub = sub_table
  sel = sel_table
  act = active_line
  meta, styles = karaskel.collect_head(sub,false)
  ADD = aegisub.dialog.display
  
  check_folder(trambo)
  check_required_files({path_file,default_preset_file})
  presetPath = get_presetPath(path_file,default_preset_file)
  presetList = getPreset(presetPath,default_preset_file,namePat)
  table.sort(presetList)
  curPreset = presetList[1]
  
  sel = open_dialog(sub,sel,act)
  aegisub.set_undo_point(script_name)
  return sel
end

function open_dialog(sub,sel,act)
  presetList = getPreset(presetPath,default_preset_file,namePat)
  table.sort(presetList)
  GUI = updateGUI()

  GUI_save = 
  {
    { class = "label", x = 0, y = 0, width = 1, height = 1, label = "Name:"},
    { class = "edit", x = 1, y = 0, width = 2, height = 1, name = "presetName"}
  }

  buttons = {save,update,import,manage,cancel}
  buttons_save = {ok,cancel}
  buttons_manage = {remove,rename,"Choose File","Close"}
  choice,res = ADD(GUI,buttons)

  while choice == save or choice == update or choice == manage do
    if choice == save then
      local status = false
      local pass = true
      choice_save, res_save = ADD(GUI_save,buttons_save)
      if choice_save == ok then
        for i,v in ipairs(presetList) do 
          if v == res_save.presetName then
            local err = {{ class = "label", x = 0, y = 0, width = 1, height = 1, label = "This name already exists, please choose another name."}}
            ADD(err,{"Close"})
            pass = false
          end
        end
        if pass == true then
          savePreset(res_save.presetName)
          presetList = getPreset(presetPath,default_preset_file,namePat)
          curPreset = res_save.presetName
          table.sort(presetList)
          status = true
        end
      end
    elseif choice == update then
      curPreset = res.preset
      updatePreset(curPreset)
    elseif choice == manage then
      end_manage = false;
      while (not end_manage) do 
        GUI_manage = 
        {
          { class = "label", x = 0, y = 0, width = 1, height = 1, label = "Items"},
          { class = "dropdown", x = 1, y = 0, width = 2, height = 1, items = presetList, value = curPreset, name = "chosenPreset"},
          { class = "label", x = 0, y = 1, width = 1, height = 1, label = "Rename"},
          { class = "edit", x = 1, y = 1, width = 2, height = 1, name = "newName"}
        }
        choice_manage, res_manage = ADD(GUI_manage,buttons_manage)
        if choice_manage == remove then
          removePreset(res_manage.chosenPreset,presetPath,namePat)
          presetList = getPreset(presetPath,default_preset_file,namePat)
          curPreset = presetList[1]
          table.sort(presetList)
        elseif choice_manage == rename then
          renamePreset(res_manage.chosenPreset,res_manage.newName,presetPath,namePat)
          presetList = getPreset(presetPath,default_preset_file,namePat)
          curPreset = presetList[1]
          table.sort(presetList)
        elseif choice_manage == "Choose File" then
          local p = aegisub.dialog.open("Choose your file","","","Text files (.txt)|*.txt", false, true)
          if p then
            presetPath = p
            presetList = getPreset(presetPath,default_preset_file,namePat)
            curPreset = presetList[1]
            table.sort(presetList)
            local f = io.open(path_file,"w")
            f:write(p)
            f:close()
          end
        else
          end_manage = true;
        end

      end
    end
    GUI = updateGUI()
    choice, res = ADD(GUI,buttons)
  end
  if choice == import then
    curPreset = res.preset
    sel = loadPreset(curPreset,sub,sel,act)
  end

  return sel
end

function savePreset(name)

  local var_str = {"comment=", "start_time=", "end_time=","style=","actor=","margin_l=", "margin_r=","margin_t=","effect=","text="}
  local f = io.open(presetPath,"a")
  f:write("preset=" .. name .. ";e;")
  for si,li in ipairs(sel) do
    local line = sub[li]
    karaskel.preproc_line(sub, meta, styles, line)
    local var= {line.comment,line.start_time,line.end_time,line.style,line.actor,line.margin_l,line.margin_r,line.margin_t,line.effect,line.text}
    for i=1,#var,1 do
      if type(var[i]) == "string" then 
        var[i] = var[i]:gsub("\\","\\\\")
        f:write(var_str[i] .. "\'" .. tostring(var[i]) .. "\';e;")
      else
        f:write(var_str[i] .. tostring(var[i]) .. ";e;")
      end
    end
    f:write(";eol;")
  end
  f:write(";eop;\n") --end of preset
  f:close()
end

function loadPreset(p,sub,sel,act)
  insertedLine = sub[act]
  local f = io.open(presetPath,"r")

  for l in f:lines() do
    if l:match("preset=(.-);e;") == p then
      local temp = l:gsub("preset=.-;e;","",1)
      for v in temp:gmatch("(.-);eol;") do
        for q in v:gmatch("(.-);e;") do
          local fn = loadstring("insertedLine." .. q)
          fn()
        end
        sub.insert(act,insertedLine)
        act = act + 1
      end
      break

    end
  end

  f:close()
  return sel
end

function updatePreset(p)
  msg = [[Are you sure you want to update Preset "]] .. p .. [[" ?]]
  local updatePreset_GUI = {
    { class = "label", x=0, y=0, width=2, height=1, label=msg}
  }
  local updatePreset_buttons = {"YES","NO"}
  updatePreset_choice,updatePreset_res = ADD(updatePreset_GUI,updatePreset_buttons)
  if updatePreset_choice == "YES" then
    removePreset(p,presetPath,namePat)
    savePreset(p)
  end
end

function updateGUI()
  local g = 
  {
    { class = "label", x = 0, y = 0, width = 4, height = 1, label = "File Name: " .. presetPath:gsub("^.*\\","")},
    { class = "label", x = 0, y = 1, width = 1, height = 1, label = "Items"},
    { class = "dropdown", x = 1, y = 1, width = 4, height = 1, items = presetList, value = curPreset, name = "preset"},
  } 
  return g
end

--send to Aegisub's automation list
aegisub.register_macro(script_name,script_description,main,macro_validation)