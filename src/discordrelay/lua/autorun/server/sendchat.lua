--[[
	Name: sendchat.lua
	Author: Roy (Christian Deacon)
	Description: Sends in-game messages to a specific Discord channel via web hook.
]]--

local g_sWebHook = "WEB_URL"
local g_sAPIKey = "STEAM_API_KEY"
local g_sPassword = "APASSWORD"
local g_tAvatars = {}
local g_tTries = {}

local function doHTTPPost(username, steamid, text)
	-- Send Web Hook.
	HTTP({
		url = g_sWebHook,
		method = "POST",
		parameters = {
			content = text,
			username = username,
			avatar_url = g_tAvatars[steamid],
			password = g_sPassword
		},
		success = function (code, body, headers) end,
		failed = function (reason) Msg(reason) end
	})
end

local function getAvatarURL(contents, size, tables, code, username, steamid, text)
	local temp = util.JSONToTable(contents)
	
	if istable(temp) then
		-- PrintTable(temp)
		g_tAvatars[temp["response"]["players"][1]["steamid"]] = temp["response"]["players"][1]["avatarmedium"]
	end
	
	-- Send the HTTP Post now since we have the avatar URL.
	doHTTPPost(username, steamid, text)
end

hook.Add("PlayerDisconnected", "PlayerDisconnectedDiscordBot", function (ply)
	-- Release the item.
	g_tAvatars[ply:SteamID64()] = nil
	g_tTries[ply:SteamID64()] = nil
end)

hook.Add("PlayerSay", "DiscordPlayerSay", function (ply, text, team)
	-- Check if it's a team message or not. If not, continue.
	if not team then
		-- Get username and Steam ID NOW so we won't risk losing this information later when we're doing POST/GET requests (I don't like passing the ply variable to on success HTTP callbacks :P). Ya feel me?
		local username = ply:Nick()
		local steamid = ply:SteamID64()
		
		-- Check for avatar URL.
		if not g_tAvatars[steamid] and (not g_tTries[steamid] or g_tTries[steamid] < 2) then
			-- Set default value :P
			g_tAvatars[steamid] = ""
			
			-- Send request to Steam API.
			http.Fetch("http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=" .. g_sAPIKey .. "&steamids=" .. steamid .. "&format=JSON", function (contents, size, tables, code) getAvatarURL(contents, size, tables, code, username, steamid, text) end, function (reason) Msg(reason); doHTTPPost(username, steamid, text) end)
			
			-- Set tries count.
			if g_tTries[steamid] then
				g_tTries[steamid] = g_tTries[steamid] + 1
			else
				g_tTries[steamid] = 1
			end
		else
			doHTTPPost(username, steamid, text)
		end
	end
end)