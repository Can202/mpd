--mpd_can
--vote.lua - vote module to change songs

function mpd_can.vote_play(name, param)
	id=tonumber(param)
	if id and id>0 and id<=#mpd_can.songs then
		vote.new_vote(name, {
			description = "Play "..mpd_can.song_human_readable(id),
			help = "/yes or /no",
			duration = 20,
			perc_needed = 0.4,

			on_result = function(self, result, results)
				if result == "yes" then
					minetest.chat_send_all("Vote to play " .. mpd_can.song_human_readable(id) .. " passed " ..
							#results.yes .. " to " .. #results.no)
					mpd_can.play_song(id)
				else
					minetest.chat_send_all("Vote to play " .. mpd_can.song_human_readable(id) .. " failed " ..
							#results.yes .. " to " .. #results.no)
				end
			end,

			on_vote = function(self, name, value)
				minetest.chat_send_all(name .. " voted " .. value .. " to '" ..
						self.description .. "'")
			end,
		})
		return true
	end
	return false,"Invalid song ID! See available song IDs using /mpd_can_list"
end

minetest.register_chatcommand("vote_mpd_can_play", {
	func = mpd_can.vote_play
})

function mpd_can.vote_next(name, param)
	vote.new_vote(name, {
		description = "Play next song",
		help = "/yes or /no",
		duration = 20,
		perc_needed = 0.4,

		on_result = function(self, result, results)
			minetest.chat_send_all(result..dump(results))
			if result == "yes" then
				minetest.chat_send_all("Vote to play next song passed " ..
						#results.yes .. " to " .. #results.no)
				mpd_can.next_song()
			else
				minetest.chat_send_all("Vote to play next song failed " ..
						#results.yes .. " to " .. #results.no)
			end
		end,

		on_vote = function(self, name, value)
			minetest.chat_send_all(name .. " voted " .. value .. " to '" ..
					self.description .. "'")
		end
	})
	return true
end

minetest.register_chatcommand("vote_mpd_can_next", {
	func = mpd_can.vote_next
})

