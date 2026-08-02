local LanguageManager = {}
LanguageManager.Folder = "FluentSettings"
LanguageManager.Library = nil
LanguageManager.Enabled = true

local HttpService = game:GetService("HttpService")

local LangList = {
	{ Code = "en",    Name = "English" },
	{ Code = "id",    Name = "Indonesian" },
	{ Code = "ms",    Name = "Malay" },
	{ Code = "tl",    Name = "Filipino" },
	{ Code = "jw",    Name = "Javanese" },
	{ Code = "su",    Name = "Sundanese" },
	{ Code = "zh-cn", Name = "Chinese Simplified" },
	{ Code = "zh-tw", Name = "Chinese Traditional" },
	{ Code = "ja",    Name = "Japanese" },
	{ Code = "ko",    Name = "Korean" },
	{ Code = "ar",    Name = "Arabic" },
	{ Code = "de",    Name = "German" },
	{ Code = "es",    Name = "Spanish" },
	{ Code = "fr",    Name = "French" },
	{ Code = "it",    Name = "Italian" },
	{ Code = "pt",    Name = "Portuguese" },
	{ Code = "ru",    Name = "Russian" },
	{ Code = "tr",    Name = "Turkish" },
	{ Code = "vi",    Name = "Vietnamese" },
	{ Code = "th",    Name = "Thai" },
	{ Code = "hi",    Name = "Hindi" },
	{ Code = "uk",    Name = "Ukrainian" },
	{ Code = "pl",    Name = "Polish" },
	{ Code = "nl",    Name = "Dutch" },
	{ Code = "sv",    Name = "Swedish" },
}

local SkipKeys = {
	LangManagerEnabled = true,
	LangManagerDropdown = true,
	SaveManager_ConfigName = true,
	SaveManager_ConfigList = true,
	FB_ConfigName = true,
	FB_ConfigList = true,
}

local Originals = {}
local RealOptions = {}
local Cache = {}
local IsTranslating = false
local CurrentLang = "en"

local GoogleV = isfile and isfile("googlev.txt") and readfile("googlev.txt") or ""
local RpcId = "MkEWBc"
local RootUrl = "https://translate.google.com/"
local ExecUrl = "https://translate.google.com/_/TranslateWebserverUi/data/batchexecute"
local SessionId, SessionBl, ReqId = nil, nil, math.random(1000, 9999)

local function DoRequest(Opt)
	local Fn = (syn and syn.request) or http_request or request
	if Fn then return Fn(Opt) end
	return HttpService:RequestAsync(Opt)
end

local function QStr(Data)
	local S = ""
	for K, V in next, Data do
		if type(V) == "table" then
			for _, Vv in next, V do
				S ..= "&" .. HttpService:UrlEncode(K) .. "=" .. HttpService:UrlEncode(Vv)
			end
		else
			S ..= "&" .. HttpService:UrlEncode(K) .. "=" .. HttpService:UrlEncode(V)
		end
	end
	return S:sub(2)
end

local function HandleConsent(Body)
	local T = {}
	for Tag in Body:gmatch("<input type=\"hidden\" name=\".-\" value=\".-\">") do
		local K, V = Tag:match("<input type=\"hidden\" name=\"(.-)\" value=\"(.-)\">")
		T[K] = V
	end
	GoogleV = T.v or ""
	if writefile then writefile("googlev.txt", GoogleV) end
end

local function Fetch(Url, Method, Body)
	Method = Method or "GET"
	local Res = DoRequest({
		Url = Url,
		Method = Method,
		Headers = { cookie = "CONSENT=YES+" .. GoogleV },
		Body = Body,
	})
	local B = type(Res.Body) == "string" and Res.Body or ""
	if B:match("https://consent.google.com/s") then
		HandleConsent(B)
		Res = DoRequest({ Url = Url, Method = "GET", Headers = { cookie = "CONSENT=YES+" .. GoogleV } })
		B = type(Res.Body) == "string" and Res.Body or ""
	end
	return B
end

local function InitSession()
	local Ok = pcall(function()
		local B = Fetch(RootUrl)
		SessionId = B:match("\"FdrFJe\":\"(.-)\"")
		SessionBl  = B:match("\"cfb2h\":\"(.-)\"")
	end)
	return Ok and SessionId ~= nil and SessionBl ~= nil
end

local function TranslateRaw(Text, Target)
	if not SessionId or not SessionBl then
		if not InitSession() then return nil end
	end
	ReqId += 10000
	local Data = { { Text, "auto", Target, true }, { nil } }
	local Freq = { { { RpcId, HttpService:JSONEncode(Data), nil, "generic" } } }
	local Url = ExecUrl .. "?" .. QStr({
		rpcids = RpcId,
		["f.sid"] = SessionId,
		bl = SessionBl,
		hl = "en",
		_reqid = ReqId - 10000,
		rt = "c",
	})
	local Body = Fetch(Url, "POST", QStr({ ["f.req"] = HttpService:JSONEncode(Freq) }))
	local Ok, Out = pcall(function()
		local Arr = HttpService:JSONDecode(Body:match("%[.-%]\n"))
		return HttpService:JSONDecode(Arr[1][3])
	end)
	if not Ok or not Out then return nil end
	return Out[2][1][1][6][1][1]
end

local function Tt(Text, Lang)
	if not Text or Text == "" or Lang == "en" then return Text end
	local Pre, Suf, Inner = "", "", Text
	local P = Text:match("^(<[^>]+>)")
	if P then Pre = P; Inner = Text:sub(#P + 1) end
	local S = Inner:match("(<[^>]+>)$")
	if S then Suf = S; Inner = Inner:sub(1, #Inner - #S) end
	if Inner == "" then return Text end
	if not Cache[Lang] then Cache[Lang] = {} end
	if Cache[Lang][Inner] then return Pre .. Cache[Lang][Inner] .. Suf end
	local R = TranslateRaw(Inner, Lang)
	if R and R ~= "" then
		Cache[Lang][Inner] = R
		return Pre .. R .. Suf
	end
	return Text
end

local function HookElement(Key, Elem)
	if SkipKeys[Key] then return end
	if Originals[Key] then return end
	Originals[Key] = {}
	local E = Originals[Key]

	local OrigSetTitle = Elem.SetTitle
	if OrigSetTitle then
		Elem.SetTitle = function(Self, Text)
			if not E.Title then E.Title = Text end
			return OrigSetTitle(Self, Text)
		end
	end

	local OrigSetDesc = Elem.SetDesc
	if OrigSetDesc then
		Elem.SetDesc = function(Self, Text)
			if not E.Desc and Text and Text ~= "" then E.Desc = Text end
			return OrigSetDesc(Self, Text)
		end
	end

	local OrigSetValues = Elem.SetValues
	if OrigSetValues then
		if not E.Values and type(Elem.Values) == "table" and #Elem.Values > 0 then
			local Copy = {}
			for _, V in ipairs(Elem.Values) do table.insert(Copy, V) end
			E.Values = Copy
		end
		Elem.SetValues = function(Self, NewVals)
			return OrigSetValues(Self, NewVals)
		end
	end
end

local function InstallOptionsProxy(Lib)
	RealOptions = Lib.Options
	local Proxy = setmetatable({}, {
		__index = RealOptions,
		__newindex = function(_, Key, Elem)
			RealOptions[Key] = Elem
			if type(Elem) == "table" and not SkipKeys[Key] then
				task.defer(function()
					HookElement(Key, Elem)
				end)
			end
		end,
		__len = function() return #RealOptions end,
		__next = function(_, K) return next(RealOptions, K) end,
	})
	Lib.Options = Proxy
end

function LanguageManager:SetLibrary(Lib)
	self.Library = Lib
	InstallOptionsProxy(Lib)
end

function LanguageManager:SetFolder(Folder)
	self.Folder = Folder
	pcall(function()
		if not isfolder(Folder) then makefolder(Folder) end
		local Sub = Folder .. "/language"
		if not isfolder(Sub) then makefolder(Sub) end
	end)
end

local function SaveSettings(Lang, Enabled)
	pcall(function()
		writefile(
			LanguageManager.Folder .. "/language/settings.json",
			HttpService:JSONEncode({ lang = Lang, enabled = Enabled })
		)
	end)
end

local function LoadSettings()
	local Ok, Data = pcall(function()
		return HttpService:JSONDecode(readfile(LanguageManager.Folder .. "/language/settings.json"))
	end)
	if Ok and type(Data) == "table" then
		return Data.lang or "en", Data.enabled ~= false
	end
	return "en", true
end

function LanguageManager:ApplyAll(Lang)
	if not self.Enabled or not self.Library then return end
	Lang = Lang or CurrentLang
	IsTranslating = true

	for Key, Elem in next, RealOptions do
		if SkipKeys[Key] then continue end
		local E = Originals[Key]
		if not E then continue end

		pcall(function()
			if E.Title and Elem.SetTitle then
				Elem:SetTitle(Tt(E.Title, Lang))
			end
		end)

		pcall(function()
			if E.Desc and Elem.SetDesc then
				Elem:SetDesc(Tt(E.Desc, Lang))
			end
		end)

		pcall(function()
			if Elem.SetValues and type(Elem.Values) == "table" and #Elem.Values > 0 then
				if not E.Values then
					local Copy = {}
					for _, V in ipairs(Elem.Values) do table.insert(Copy, V) end
					E.Values = Copy
				end
				local OldToNew = {}
				local Translated = {}
				for _, V in ipairs(E.Values) do
					local TV = Tt(V, Lang)
					table.insert(Translated, TV)
					OldToNew[V] = TV
				end
				Elem:SetValues(Translated)
				pcall(function()
					if not Elem.Multi then
						if Elem.Value and OldToNew[Elem.Value] then
							Elem.Value = OldToNew[Elem.Value]
						end
					else
						if type(Elem.Value) == "table" then
							local New = {}
							for K in next, Elem.Value do
								local TV = OldToNew[K]
								if TV then New[TV] = true end
							end
							Elem.Value = New
						end
					end
					Elem:Display()
				end)
			end
		end)

		task.wait()
	end

	CurrentLang = Lang
	IsTranslating = false
	SaveSettings(Lang, self.Enabled)

	self.Library:Notify({
		Title = "Language Manager",
		Content = "Interface translated to " .. Lang,
		SubContent = "Success",
		Duration = 3,
	})
end

function LanguageManager:ResetAll()
	if not self.Library then return end

	for Key, Elem in next, RealOptions do
		if SkipKeys[Key] then continue end
		local E = Originals[Key]
		if not E then continue end

		pcall(function()
			if E.Title and Elem.SetTitle then Elem:SetTitle(E.Title) end
		end)
		pcall(function()
			if E.Desc and Elem.SetDesc then Elem:SetDesc(E.Desc) end
		end)
		pcall(function()
			if E.Values and Elem.SetValues then
				Elem:SetValues(E.Values)
				pcall(function()
					if not Elem.Multi then
						if E.SelectedValue then Elem.Value = E.SelectedValue end
					else
						if type(E.SelectedValue) == "table" then
							local Copy = {}
							for K, V in next, E.SelectedValue do Copy[K] = V end
							Elem.Value = Copy
						end
					end
					Elem:Display()
				end)
			end
		end)

		task.wait()
	end

	CurrentLang = "en"
	SaveSettings("en", self.Enabled)
end

function LanguageManager:BuildLanguageSection(Tab)
	assert(self.Library, "Must set LanguageManager.Library")

	local LangNames = {}
	local CodeByName = {}
	for _, Entry in ipairs(LangList) do
		table.insert(LangNames, Entry.Name)
		CodeByName[Entry.Name] = Entry.Code
	end

	local SavedLang, SavedEnabled = LoadSettings()
	CurrentLang = SavedLang
	self.Enabled = SavedEnabled

	local DefaultName = "English"
	for _, Entry in ipairs(LangList) do
		if Entry.Code == SavedLang then DefaultName = Entry.Name; break end
	end

	local SelectedLang = DefaultName

	local Section = Tab:AddSection("Language Manager", "solar/translation-bold")

	Section:AddToggle("LangManagerEnabled", {
		Title = "Enable Translator",
		Description = "Translate all UI text to the selected language",
		Icon = "solar/translation-bold",
		Default = SavedEnabled,
		Callback = function(Value)
			self.Enabled = Value
			if Value then
				local Code = CodeByName[SelectedLang] or "en"
				SaveSettings(Code, true)
				if Code ~= "en" then
					task.spawn(function() self:ApplyAll(Code) end)
				end
			else
				SaveSettings("en", false)
				task.spawn(function() self:ResetAll() end)
			end
		end,
	})

	Section:AddDropdown("LangManagerDropdown", {
		ThemedDropdown = true,
		DropdownOutsideWindow = true,
		Search = true,
		IsManagerDropdown = true,
		Title = "Target Language",
		Description = "Language to translate UI into",
		Icon = "solar/globe-bold",
		Values = LangNames,
		Default = DefaultName,
		Callback = function(Value)
			SelectedLang = Value
			if not self.Enabled then return end
			local Code = CodeByName[Value] or "en"
			SaveSettings(Code, self.Enabled)
			if Code == "en" then
				task.spawn(function() self:ResetAll() end)
			else
				task.spawn(function() self:ApplyAll(Code) end)
			end
		end,
	})

	local Grp = Section:AddGroup({ Columns = 2, Gap = 6 })
	local ColApply = Grp:AddElement()
	local ColReset = Grp:AddElement()

	ColApply:AddButton({
		Title = "Apply",
		Description = "Apply translation to all UI elements",
		Icon = "solar/translation-bold",
		Callback = function()
			if IsTranslating then
				self.Library:Notify({ Title = "Language Manager", Content = "Translation in progress", Duration = 2 })
				return
			end
			if not self.Enabled then
				self.Library:Notify({ Title = "Language Manager", Content = "Translator is disabled", Duration = 2 })
				return
			end
			local Code = CodeByName[SelectedLang] or "en"
			task.spawn(function() self:ApplyAll(Code) end)
		end,
	})

	ColReset:AddButton({
		Title = "Reset",
		Description = "Restore all original UI strings",
		Icon = "solar/restart-bold",
		Callback = function()
			if IsTranslating then return end
			task.spawn(function() self:ResetAll() end)
		end,
	})

	task.spawn(function()
		InitSession()
		if SavedEnabled and SavedLang ~= "en" then
			task.wait(1)
			self:ApplyAll(SavedLang)
		end
	end)
end

return LanguageManager
