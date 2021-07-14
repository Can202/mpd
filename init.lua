
mpd_can={}


mpd_can.pause_between_songs=tonumber(minetest.settings:get("mpd_can_pause_between_songs")) or 30

--end config

mpd_can.modpath=minetest.get_modpath("mpd_can")
if not mpd_can.modpath then
	error("mpd_can mod folder has to be named 'mpd_can'!")
end
--{name, length, gain~1}
mpd_can.songs = {}
local sfile, sfileerr=io.open(mpd_can.modpath..DIR_DELIM.."songs.txt")
if not sfile then error("Error opening songs.txt: "..sfileerr) end
for linent in sfile:lines() do
	-- trim leading and trailing spaces away
	local line = string.match(linent, "^%s*(.-)%s*$")
	if line~="" and string.sub(line,1,1)~="#" then
		local name, timeMinsStr, timeSecsStr, gainStr, title = string.match(line, "^(%S+)%s+(%d+):([%d%.]+)%s+([%d%.]+)%s*(.*)$")
		local timeMins, timeSecs, gain = tonumber(timeMinsStr), tonumber(timeSecsStr), tonumber(gainStr)
		if title=="" then title = name end
		if name and timeMins and timeSecs and gain then
			mpd_can.songs[#mpd_can.songs+1]={name=name, length=timeMins*60+timeSecs, lengthhr=timeMinsStr..":"..timeSecsStr, gain=gain, title=title}
		else
			minetest.log("warning", "[mpd_can] Misformatted song entry in songs.txt: "..line)
		end
	end
end
sfile:close()

if #mpd_can.songs==0 then
	print("[mpd_can]no songs registered, not doing anything")
	return
end

mpd_can.storage = minetest.get_mod_storage()

mpd_can.handles={}

mpd_can.playing=false
mpd_can.id_playing=nil
mpd_can.song_time_left=nil
mpd_can.time_next=10 --sekunden
mpd_can.id_last_played=nil

minetest.register_globalstep(function(dtime)
	if mpd_can.playing then
		if mpd_can.song_time_left<=0 then
			mpd_can.stop_song()
			mpd_can.time_next=mpd_can.pause_between_songs
		else
			mpd_can.song_time_left=mpd_can.song_time_left-dtime
		end
	elseif mpd_can.time_next then
		if mpd_can.time_next<=0 then
			mpd_can.next_song()
		else
			mpd_can.time_next=mpd_can.time_next-dtime
		end
	end
end)
mpd_can.play_song=function(id)
	if mpd_can.playing then
		mpd_can.stop_song()
	end
	local song=mpd_can.songs[id]
	if not song then return end
	for _,player in ipairs(minetest.get_connected_players()) do
		local pname=player:get_player_name()
		local pvolume=tonumber(mpd_can.storage:get_string("vol_"..pname))
		if not pvolume then pvolume=1 end
		if pvolume>0 then
			local handle = minetest.sound_play(song.name, {to_player=pname, gain=song.gain*pvolume})
			if handle then
				mpd_can.handles[pname]=handle
			end
		end
	end
	mpd_can.playing=id
	--adding 2 seconds as security
	mpd_can.song_time_left = song.length + 2
end
mpd_can.stop_song=function()
	for pname, handle in pairs(mpd_can.handles) do
		minetest.sound_stop(handle)
	end
	mpd_can.id_last_played=mpd_can.playing
	mpd_can.playing=nil
	mpd_can.handles={}
	mpd_can.time_next=nil
end

mpd_can.next_song=function()
	local next
	repeat
		next=math.random(1,#mpd_can.songs)
	until #mpd_can.songs==1 or next~=mpd_can.id_last_played
	mpd_can.play_song(next)
end

mpd_can.song_human_readable=function(id)
	if not tonumber(id) then return "<error>" end
	local song=mpd_can.songs[id]
	if not song then return "<error>" end
	return id..": "..song.title.." ["..song.lengthhr.."]"
end

minetest.register_privilege("mpd_can", "may control the music player daemon (mpd_can) mod")

minetest.register_chatcommand("mpd_can_stop", {
	params = "",
	description = "Stop the song currently playing",
	privs = {mpd_can=true},
	func = function(name, param)
		mpd_can.stop_song()
	end,		
})
minetest.register_chatcommand("mpd_can_list", {
	params = "",
	description = "List all available songs and their IDs",
	privs = {mpd_can=true},
	func = function(name, param)
		for k,v in ipairs(mpd_can.songs) do
			minetest.chat_send_player(name, mpd_can.song_human_readable(k))
		end
	end,		
})
minetest.register_chatcommand("mpd_can_play", {
	params = "<id>",
	description = "Play the songs with the given ID (see ids with /mpd_can_list)",
	privs = {mpd_can=true},
	func = function(name, param)
		if param=="" then
			mpd_can.next_song()
			return true,"Playing: "..mpd_can.song_human_readable(mpd_can.playing)
		end
		id=tonumber(param)
		if id and id>0 and id<=#mpd_can.songs then
			mpd_can.play_song(id)
			return true,"Playing: "..mpd_can.song_human_readable(id)
		end
		return false, "Invalid song ID!"
	end,		
})
minetest.register_chatcommand("mpd_can_what", {
	params = "",
	description = "Display the currently played song.",
	privs = {mpd_can=true},
	func = function(name, param)
		if not mpd_can.playing then
			if mpd_can.time_next and mpd_can.time_next~=0 then
				return true,"Nothing playing, "..math.floor(mpd_can.time_next or 0).." sec. left until next song."
			else
				return true,"Nothing playing."
			end
		end
		return true,"Playing: "..mpd_can.song_human_readable(mpd_can.playing).."\nTime Left: "..math.floor(mpd_can.song_time_left or 0).." sec."
	end,		
})
minetest.register_chatcommand("mpd_can_next", {
	params = "[seconds]",
	description = "Start the next song, either immediately (no parameters) or after n seconds.",
	privs = {mpd_can=true},
	func = function(name, param)
		mpd_can.stop_song()
		if param and tonumber(param) then
			mpd_can.time_next=tonumber(param)
			return true,"Next song in "..param.." seconds!"
		else
			mpd_can.next_song()
			return true,"Next song started!"
		end
	end,		
})
minetest.register_chatcommand("mvolume", {
	params = "[volume level (0-1)]",
	description = "Set your background music volume. Use /mvolume 0 to turn off background music for you. Without parameters, show your current setting.",
	privs = {},
	func = function(pname, param)
		if not param or param=="" then
			local pvolume=tonumber(mpd_can.storage:get_string("vol_"..pname))
			if not pvolume then pvolume=0.5 end
			if pvolume>0 then
				return true, "Your music volume is set to "..pvolume.."."
			else
				if mpd_can.handles[pname] then
					minetest.sound_stop(mpd_can.handles[pname])
				end
				return true, "Background music is disabled for you. Use '/mvolume 1' to enable it again."
			end
		end
		local pvolume=tonumber(param)
		if not pvolume then
			return false, "Invalid usage: /mvolume [volume level (0-1)]"
		end
		pvolume = math.min(pvolume, 1)
		pvolume = math.max(pvolume, 0)
		mpd_can.storage:set_string("vol_"..pname, pvolume)
		if pvolume>0 then
			return true, "Music volume set to "..pvolume..". Change will take effect when the next song starts."
		else
			if mpd_can.handles[pname] then
				minetest.sound_stop(mpd_can.handles[pname])
			end
			return true, "Disabled background music for you. Use /mvolume to enable it again."
		end
	end,		
})

if vote then
	dofile(mpd_can.modpath..DIR_DELIM.."vote.lua")
end
