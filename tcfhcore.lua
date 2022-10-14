local a,t=...
local f=CreateFrame("frame",a)
local CF,cfid,font,fonthash,hook,AceDB,LSM={},{},{},{},{}
local next,remove,select,type=next,table.remove,select,type
TCFH_DB=TCFH_DB or {}
TCFH_SV=TCFH_SV or {}
local DB,SV={},{}

local options={
	["fadetime"]=true,
	["fontflag"]=true,
	["fontsize"]=true,
	["font"]=true,
	["maxlines"]=true,
}
local fontflag={
	[1]="",
	[2]="OUTLINE",
	[3]="THICKOUTLINE",
	[4]="MONOCHROME",
	[5]="OUTLINE,THICKOUTLINE",
	[6]="OUTLINE,MONOCHROME",
	[7]="THICKOUTLINE,MONOCHROME",
	[9]="OUTLINE,THICKOUTLINE,MONOCHROME",
}
local flag={
	[1]="none",
	[2]="outline",
	[3]="thickoutline",
	[4]="monochrome",
	[5]="outline and thickoutline",
	[6]="outline and monochrome",
	[7]="thickoutline and monochrome",
	[9]="outline, thickoutline, and monochrome",
}

local function prnt(frame,message)
	if frame.historyBuffer:PushFront({message=message,r=1,g=1,b=1,extraData={[1]="temp",n=1},timestamp=GetTime()}) then
		if frame:GetScrollOffset()~=0 then
			frame:ScrollUp()
		end
		frame:MarkDisplayDirty()
	end
end
function t.print(message)
	if message=="frameid" then
		for frame,id in next,CF do
			prnt(frame,"ChatFrame"..id)
		end
	else
		prnt(DEFAULT_CHAT_FRAME,message)
	end
end

 -- CircularBuffer bug (feature?) due to modulus usage (CircularBuffer.lua:38,46,123), causing elements to be added at the back when buffer is full, screwing up saved data
function t.pushfront(frame)
	if frame==COMBATLOG then return end -- ensure Combat Log is ignored
	if not hook[frame] then
		hook[frame]=true -- hook only once, hook doesn't go away when temporary frames are closed (11+)
		hooksecurefunc(frame.historyBuffer,"PushFront",function(frame)
			while #frame.elements>frame.maxElements-5 do -- minimum of 2 less than max is needed, 5 to provide some buffer
				remove(frame.elements,1)
			end
			frame.headIndex=#frame.elements
		end)
	end
end

 -- called when a frame loads or settings change
function t.settings(frame)
	local nameorid=CF[frame]>NUM_CHAT_WINDOWS and frame.name or CF[frame]
	local fadetime,maxlines,font,fontsize,fontflag=frame:GetTimeVisible(),frame:GetMaxLines(),frame:GetFont() -- no defaults to prevent clashes with other chat addons
	frame:SetTimeVisible(SV[nameorid].fadetime or SV[0].fadetime or fadetime)
	frame:SetMaxLines((SV[nameorid].maxlines or (frame~=COMBATLOG and SV[0].maxlines) or maxlines)+(frame==COMBATLOG and 0 or 5)) -- actual max 5 higher to offset pushfront hook
	frame:SetFont(SV[nameorid].font or SV[0].font or font,SV[nameorid].fontsize or SV[0].fontsize or fontsize,SV[nameorid].fontflag or SV[0].fontflag or fontflag)
	FCF_SetChatWindowFontSize(nil,frame,SV[nameorid].fontsize or SV[0].fontsize or fontsize)
end

 -- element fading timestamp comes from GetTime() (ScrollingMessageFrame.lua:583), causing restored elements to effectively not fade if you restart your computer
function t.timestamps(frame)
	local nameorid,timestamp=CF[frame]>NUM_CHAT_WINDOWS and frame.name or CF[frame],GetTime()
	if DB[nameorid] then
		for element=#DB[nameorid],1,-1 do
			DB[nameorid][element].timestamp=timestamp
		end
	end
end

function t.ADDON_LOADED(addon)
	if addon==a then
		DB=TCFH_DB SV=TCFH_SV -- localize saved data
		if type(SV[0])~="table" then SV[0]={} end
		LSM=LibStub("LibSharedMedia-3.0",true)
		fonthash=LSM:HashTable("font")
		font=LSM:List("font")
		for frame,elements in next,DB do
			for element=#elements,1,-1 do
				if elements[element].extraData then
					for k,v in next,elements[element].extraData do
						if v=="temp" then remove(DB[frame],element) break end -- remove TCFH's entries
						 -- note to authors: passing "temp" in _any_ arg beyond the r,g,b args of AddMessage
						 -- will allow your message to also be removed upon chat restoration, if you so desire
						 -- examples: frame:AddMessage("message",r,g,b,"temp")
						 -- frame:AddMessage("message",r,g,b,chatTypeID,accessID,lineID,"temp")
					end
				end
			end
		end
		hooksecurefunc("FCF_SetWindowName",function(frame,name)
			local id=frame:GetID()
			CF[frame]=id -- main ChatFrame pointers
			cfid[id]=frame -- access by id, used for /tcfh and ordered iteration of t.missed
			if type(SV[id>NUM_CHAT_WINDOWS and name or id])~="table" then
				SV[id>NUM_CHAT_WINDOWS and name or id]={}
			end
		end)
		hooksecurefunc("FCFManager_RegisterDedicatedFrame",function(frame)
			if CF[frame]>NUM_CHAT_WINDOWS then
				t.pushfront(frame)
				t.settings(frame)
				if DB[frame.name] then
					t.timestamps(frame)
					frame.historyBuffer:ReplaceElements(DB[frame.name])
				end
			end
		end) -- restore any history for Pet Combat Log and whispers
		hooksecurefunc("FCFManager_UnregisterDedicatedFrame",function(frame)
			if CF[frame]>NUM_CHAT_WINDOWS then
				DB[frame.name]=frame.historyBuffer.elements
			end
		end) -- save any history for Pet Combat Log and whispers
		SLASH_TCFHCMD1="/tcfh"
		SlashCmdList.TCFHCMD=function(input)
			local c,g,n,r,amount,id=FONT_COLOR_CODE_CLOSE,GREEN_FONT_COLOR_CODE,NORMAL_FONT_COLOR_CODE,RED_FONT_COLOR_CODE
			local arg1,arg2,arg3=input:match("%W*(%w*)%W*(%w*)%W*(%w*)%W*")
			arg1,amount,id=strlower(arg1),tonumber(arg2),tonumber(arg3)
			if input:match("^%s*$") then
				t.print(g..":"..a..":"..c)
				t.print(n.." /tcfh"..c)
				t.print(" - prints this help text")
				t.print(n.." /tcfh show"..c)
				t.print(" - display missed text while loading")
				t.print(n.." /tcfh enable | /tcfh disable"..c)
				t.print(" - enable or disable showing missed text on load")
				t.print(n.." /tcfh option setting ChatFrameID"..c)
				t.print(" - options: fadetime, fontflag, fontsize, font, maxlines")
				t.print(" - fontflags: "..n.."1"..c.."=none, "..n.."2"..c.."=outline, "..n.."3"..c.."=thickoutline, "..n.."4"..c.."=monochrome")
				t.print(" - (add numbers together to combine fontflags)")
				t.print(n.." /tcfh frameid"..c)
				t.print(" - prints ChatFrameIDs for previous command")
				t.print(n.." /tcfh fonts"..c)
				t.print(" - prints available fonts (use number to select font)")
				t.print(n.." /tcfh undo option ChatFrameID"..c)
				t.print(" - removes option (there are no defaults)")
				t.print(" - "..n.."undo all"..c.." removes all options")
				t.print(" - "..r.."/reload"..c.." to remove TCFH's effects")
				t.print(" - leaving ChatFrameID out of above commands sets/removes the fallback")
				t.print(" - fallbacks apply to ChatFrames that don't have that setting")
				t.print(" = = = = = = = =")
			elseif arg1=="show" then
				t.showdisplay()
			elseif arg1=="enable" then
				SV[0].hide=nil
				t.print(a..": missed text window shows after loading")
			elseif arg1=="disable" then
				SV[0].hide=true
				t.print(a..": missed text window stays hidden")
			elseif arg1=="frameid" then
				t.print(arg1)
			elseif arg1=="fonts" then
				fonthash=LSM:HashTable("font")
				font=LSM:List("font")
				for i=1,#font do
					t.print(" "..i.." "..font[i])
				end
			elseif id and id<1 and (amount or options[arg2 or ""] or arg2=="all") then
				t.print(a..": ChatFrameID must be greater than 0")
			elseif arg1=="undo" and options[arg2 or ""] then
				if id and id<=NUM_CHAT_WINDOWS then
					SV[id][arg2]=nil
					t.print(a..": \""..cfid[id].name.."\" (ChatFrame"..id..") "..arg2.." deleted")
				elseif id and id>NUM_CHAT_WINDOWS and cfid[id] then
					SV[cfid[id].name][arg2]=nil
					t.print(a..": \""..cfid[id].name.."\" "..arg2.." deleted")
				elseif not id then
					SV[0][arg2]=nil
					t.print(a..": default "..arg2.." deleted")
				else
					t.print(a..": no settings to delete or frame not active")
				end
			elseif arg1=="undo" and arg2=="all" then
				if id and id<=NUM_CHAT_WINDOWS then
					SV[id]={}
					t.print(a..": \""..cfid[id].name.."\" (ChatFrame"..id..") all settings deleted")
				elseif id and id>NUM_CHAT_WINDOWS and cfid[id] then
					SV[cfid[id].name]={}
					t.print(a..": \""..cfid[id].name.."\" all settings deleted")
				elseif not id then
					SV[0]={}
					t.print(a..": all default settings deleted")
				else
					t.print(a..": no settings to delete or frame not active")
				end
			elseif amount and amount<1 and options[arg1] then
				t.print(a..": "..arg1.." must be greater than 0")
			elseif amount and ((arg1=="fontflag" and not fontflag[amount]) or (arg1=="font" and not fonthash[font[amount]])) then
				t.print(a..": "..arg1.." not valid")
			elseif amount and id and options[arg1] then
				if id<=NUM_CHAT_WINDOWS then
					SV[id][arg1]=arg1=="fontflag" and fontflag[amount] or arg1=="font" and fonthash[font[amount]] or amount
					t.print(a..": \""..cfid[id].name.."\" (ChatFrame"..id..") "..arg1.." now "..(arg1=="fontflag" and flag[amount] or arg1=="font" and font[amount] or amount))
				elseif id>NUM_CHAT_WINDOWS and cfid[id] then
					SV[cfid[id].name][arg1]=arg1=="fontflag" and fontflag[amount] or arg1=="font" and fonthash[font[amount]] or amount
					t.print(a..": \""..cfid[id].name.."\" "..arg1.." now "..(arg1=="fontflag" and flag[amount] or arg1=="font" and font[amount] or amount))
				else
					t.print(a..": ChatFrame"..id.." is not active")
				end
			elseif amount and options[arg1] then
				SV[0][arg1]=arg1=="fontflag" and fontflag[amount] or arg1=="font" and fonthash[font[amount]] or amount
				t.print(a..": default "..arg1.." now "..(arg1=="fontflag" and flag[amount] or arg1=="font" and font[amount] or amount))
			elseif input=="refresh" then
				-- intentionally left blank to trigger the settings loop below without printing anything
			else
				t.print(a.." did not recognize that")
			end
			for frame in next,CF do t.settings(frame) end
		end
	end
	f:UnregisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_ENTERING_WORLD") -- attempt to ensure TCFH is last to load
	local frames={GetFramesRegisteredForEvent("PLAYER_LEAVING_WORLD")}
	while frames[1]~=f do
		frames[1]:UnregisterEvent("PLAYER_LEAVING_WORLD")
		frames[1]:RegisterEvent("PLAYER_LEAVING_WORLD")
		remove(frames,1)
	end -- attempt to ensure TCFH is first to trigger upon UI unload
end

function t.MODIFIER_STATE_CHANGED()
	if t.pew and t.displayshown then
		t.displayclose:SetText(IsModifierKeyDown() and PET_DISMISS or CLOSE)
	end
end

function t.PLAYER_ENTERING_WORLD()
	if t.pew then return end

 -- testdb printing "OnDatabaseShutdown table: hexID" on logout/reload (LibDualSpec in certain addons)
 -- normally not seen by anyone, which is why this testdb survived live code, but saved into TCFH
	AceDB=LibStub("AceDB-3.0",true)
	if AceDB then
		for k,v in next,_G do
			if type(k)=="string" and type(v)=="table" and k:match("%stest$") then
				for adb in next,AceDB.db_registry do
					if adb.sv==v then
					 -- adb:UnregisterCallback("OnDatabaseShutdown") -- Ace doesn't like this
					 -- adb:UnregisterCallback(adb,"OnDatabaseShutdown") -- or this
						adb:UnregisterAllCallbacks(adb) -- okie dokie
					end
				end
			end
		end
	end

	for id=#cfid,1,-1 do
		t.settings(cfid[id]) -- include Combat Log in settings, but not saving/restoring
		if cfid[id]~=COMBATLOG then
			t.pushfront(cfid[id])
			t.timestamps(cfid[id])
			if id<=NUM_CHAT_WINDOWS and DB[id] and #DB[id]>0 then
				if #cfid[id].historyBuffer.elements>0 then
					t.missed=(t.missed and t.missed.."\n\n" or "")..cfid[id].name.." (ChatFrame"..id..")\n"
					local msgs,color,msg=cfid[id].historyBuffer.elements
					for i=1,#msgs do
						color=msgs[i].r and ("|cff%02x%02x%02x"):format(msgs[i].r*255,msgs[i].g*255,msgs[i].b*255)
						msg=(color or "")..(msgs[i].message):gsub("|r","|r"..(color or "")).."|r"
						t.missed=t.missed.."\n"..msg
					end
				end
				cfid[id].historyBuffer:ReplaceElements(DB[id])
			end -- restore any history for ChatFrame1-10 (excluding Combat Log)
		end
	end
	C_Timer.After(0,function() -- thank you to Overachiever for figuring this out (Overachiever.lua:1394)
		C_Timer.After(5,function()
			if t.missed and not SV[0].hide then
				t.showdisplay()
			end
		end)
	end)
	t.pew=true
end

function t.PLAYER_LEAVING_WORLD()
	for frame,id in next,CF do
		if frame~=COMBATLOG then
			DB[id>NUM_CHAT_WINDOWS and frame.name or id]=frame.historyBuffer.elements
		end
	end -- save any history for all ChatFrames (excluding Combat Log)
end

function t.PLAYER_REGEN_DISABLED() -- check for Combat Log hook every time player enters combat
	if not TCFHCOMBATLOGHOOKED and COMBATLOG and hook[COMBATLOG] then
		t.print(a..": "..NORMAL_FONT_COLOR_CODE..COMBAT_LOG.." was changed to a frame with a hook, which will impact fps in combat"..FONT_COLOR_CODE_CLOSE)
		t.print(a..": "..NORMAL_FONT_COLOR_CODE.."Please "..RED_FONT_COLOR_CODE.."/reload"..NORMAL_FONT_COLOR_CODE.." at your earliest convenience to remove the hook"..FONT_COLOR_CODE_CLOSE)
		TCFHCOMBATLOGHOOKED="TCFHCOMBATLOGHOOKED" -- full warning only once
	elseif TCFHCOMBATLOGHOOKED then
		t.print(a..": "..NORMAL_FONT_COLOR_CODE..COMBAT_LOG.." is still hooked, please "..RED_FONT_COLOR_CODE.."/reload"..FONT_COLOR_CODE_CLOSE)
	end -- secondary Combat Log warning
end
 -- only time it could be hooked is if a player decides to move the Combat Log from ChatFrame2 to another ChatFrame while TCFH is active
 -- the performance drop is very noticeable and still occurs to a lesser extent if the hook has an "if COMBATLOG then return" line

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MODIFIER_STATE_CHANGED")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:SetScript("OnEvent",function(_,event,...)t[event](...)end)
