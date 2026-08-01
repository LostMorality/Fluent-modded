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

local Registry = {}
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
	end
	return Res
end

local function InitSession()
	local Ok = pcall(function()
		local B = Fetch(RootUrl).Body or ""
		SessionId = B:match("\"FdrFJe\":\"(.-)\"")
		SessionBl  = B:match("\"cfb2h\":\"(.-)\"")
	end)
	return Ok and SessionId and SessionBl
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
	local Res = Fetch(Url, "POST", QStr({ ["f.req"] = HttpService:JSONEncode(Freq) }))
	local Ok, Out = pcall(function()
		local Arr = HttpService:JSONDecode((Res.Body or ""):match("%[.-%]\n"))
		return HttpService:JSONDecode(Arr[1][3])
	end)
	if not Ok then return nil end
	return Out[2][1][1][6][1][1]
end

local function TranslateText(Text, Lang)
	if Lang == "en" or not Text or Text == "" then return Text end
	local Prefix, Suffix, Inner = "", "", Text
	local Pre = Text:match("^(<[^>]+>)")
	if Pre then Prefix = Pre; Inner = Text:sub(#Pre + 1) end
	local Suf = Inner:match("(<[^>]+>)$")
	if Suf then Suffix = Suf; Inner = Inner:sub(1, #Inner - #Suf) end
	if Inner == "" then return Text end
	if not Cache[Lang] then Cache[Lang] = {} end
	if Cache[Lang][Inner] then return Prefix .. Cache[Lang][Inner] .. Suffix end
	local Result = TranslateRaw(Inner, Lang)
	if Result and Result ~= "" then
		Cache[Lang][Inner] = Result
		return Prefix .. Result .. Suffix
	end
	return Text
end

function LanguageManager:SetLibrary(Lib)
	self.Library = Lib
end

function LanguageManager:SetFolder(Folder)
	self.Folder = Folder
	self:BuildFolderTree()
end

function LanguageManager:BuildFolderTree()
	pcall(function()
		if not isfolder(self.Folder) then makefolder(self.Folder) end
		local Sub = self.Folder .. "/language"
		if not isfolder(Sub) then makefolder(Sub) end
	end)
end

function LanguageManager:Register(Element, Key, Original)
	if not Element or not Key or not Original or Original == "" then return end
	table.insert(Registry, { Element = Element, Key = Key, Original = Original })
end

function LanguageManager:RegisterDropdown(Dropdown, OriginalValues)
	table.insert(Registry, {
		IsDropdown = true,
		Element = Dropdown,
		Original = OriginalValues,
		Apply = function(Lang)
			local Translated = {}
			for _, V in ipairs(OriginalValues) do
				table.insert(Translated, TranslateText(V, Lang))
			end
			pcall(function()
				if Dropdown.SetValues then Dropdown:SetValues(Translated)
				else Dropdown.Values = Translated end
			end)
		end,
	})
end

function LanguageManager:ApplyAll(Lang)
	if not self.Enabled then return end
	Lang = Lang or CurrentLang
	IsTranslating = true
	for _, Entry in ipairs(Registry) do
		pcall(function()
			if Entry.Apply then
				Entry.Apply(Lang)
			else
				local Translated = TranslateText(Entry.Original, Lang)
				local Elem, K = Entry.Element, Entry.Key
				if K == "Title" and Elem.SetTitle then
					Elem:SetTitle(Translated)
				elseif K == "Description" and Elem.SetDesc then
					Elem:SetDesc(Translated)
				else
					pcall(function() Elem[K] = Translated end)
				end
			end
		end)
		task.wait()
	end
	CurrentLang = Lang
	IsTranslating = false
	if self.Library then
		self.Library:Notify({
			Title = "Language Manager",
			Content = "Interface translated to " .. Lang,
			SubContent = "Success",
			Duration = 3,
		})
	end
end

function LanguageManager:WrapSection(Section)
	local Wrapper = {}
	setmetatable(Wrapper, {
		__index = function(_, Method)
			local Orig = Section[Method]
			if type(Orig) ~= "function" then return Orig end
			return function(_, ...)
				local Args = { ... }
				local Elem = Orig(Section, ...)
				if type(Args[2]) == "table" then
					local Opts = Args[2]
					if Opts.Title and Opts.Title ~= "" then
						LanguageManager:Register(Elem, "Title", Opts.Title)
					end
					if Opts.Description and Opts.Description ~= "" then
						LanguageManager:Register(Elem, "Description", Opts.Description)
					end
					if Method == "AddDropdown" and type(Opts.Values) == "table" then
						LanguageManager:RegisterDropdown(Elem, Opts.Values)
					end
				end
				return Elem
			end
		end,
	})
	return Wrapper
end

function LanguageManager:BuildLanguageSection(Tab)
	assert(self.Library, "Must set LanguageManager.Library")

	local LangNames = {}
	local CodeByName = {}
	for _, Entry in ipairs(LangList) do
		table.insert(LangNames, Entry.Name)
		CodeByName[Entry.Name] = Entry.Code
	end

	local SelectedLang = "English"
	local SettingsPath = self.Folder .. "/language/settings.json"

	local function SaveSettings(Lang, Enabled)
		pcall(function()
			writefile(SettingsPath, HttpService:JSONEncode({ lang = Lang, enabled = Enabled }))
		end)
	end

	local function LoadSettings()
		local Ok, Data = pcall(function()
			return HttpService:JSONDecode(readfile(SettingsPath))
		end)
		if Ok and type(Data) == "table" then
			return Data.lang or "en", Data.enabled ~= false
		end
		return "en", true
	end

	local SavedLang, SavedEnabled = LoadSettings()
	CurrentLang = SavedLang
	self.Enabled = SavedEnabled

	for _, Entry in ipairs(LangList) do
		if Entry.Code == SavedLang then
			SelectedLang = Entry.Name
			break
		end
	end

	local Section = Tab:AddSection("Language Manager", "solar/translation-bold")
	Section:AddSpace({ Height = 20 })
	Section:AddDivider()
	Section:AddSpace({ Height = 12 })

	Section:AddToggle("LangManagerEnabled", {
		Title = "Enable Auto Translator",
		Description = "Automatically translate all UI text to the selected language",
		Icon = "solar/translation-bold",
		Default = SavedEnabled,
		Callback = function(Value)
			self.Enabled = Value
			SaveSettings(CurrentLang, Value)
			if Value then
				local Code = CodeByName[SelectedLang] or "en"
				task.spawn(function() self:ApplyAll(Code) end)
			else
				task.spawn(function() self:ApplyAll("en") end)
			end
		end,
	})

	Section:AddSpace({ Height = 12 })
	Section:AddDivider()
	Section:AddSpace({ Height = 12 })

	local LangDropdown = Section:AddDropdown("LangManagerDropdown", {
		ThemedDropdown = true,
		DropdownOutsideWindow = true,
		Search = true,
		IsManagerDropdown = true,
		Title = "Target Language",
		Description = "Language to translate UI into",
		Icon = "solar/globe-bold",
		Values = LangNames,
		Default = SelectedLang,
		Callback = function(Value)
			SelectedLang = Value
		end,
	})

	Section:AddSpace({ Height = 6 })

	local GrpBtns = Section:AddGroup({ Columns = 2, Gap = 6 })
	local ColApply = GrpBtns:AddElement()
	local ColReset = GrpBtns:AddElement()

	ColApply:AddButton({
		Title = "Apply",
		Description = "Translate UI to selected language",
		Icon = "solar/translation-bold",
		Callback = function()
			if IsTranslating then
				self.Library:Notify({ Title = "Language Manager", Content = "Translation in progress...", Duration = 2 })
				return
			end
			if not self.Enabled then
				self.Library:Notify({ Title = "Language Manager", Content = "Translator is disabled", Duration = 2 })
				return
			end
			local Code = CodeByName[SelectedLang] or "en"
			SaveSettings(Code, self.Enabled)
			task.spawn(function() self:ApplyAll(Code) end)
		end,
	})

	ColReset:AddButton({
		Title = "Reset",
		Description = "Restore original English strings",
		Icon = "solar/restart-bold",
		Callback = function()
			if IsTranslating then return end
			SaveSettings("en", self.Enabled)
			task.spawn(function()
				self:ApplyAll("en")
				SelectedLang = "English"
				pcall(function()
					if self.Library.Options.LangManagerDropdown then
						self.Library.Options.LangManagerDropdown:SetValue("English")
					end
				end)
			end)
		end,
	})

	Section:AddSpace({ Height = 20 })

	task.spawn(function()
		InitSession()
		if SavedEnabled and SavedLang ~= "en" then
			self:ApplyAll(SavedLang)
		end
	end)
end

return LanguageManager
