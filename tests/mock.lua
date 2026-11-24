-- Mock test for Cyberslop Shard Log (run: luajit mock.lua <path to init.lua>, cwd = a temp dir)
-- ImGui stub + balance checks taken from the Quest Picker mock.
local MOD = arg[1] or "init.lua"

local pass, fail = 0, 0
local function ok(cond, name)
    if cond then pass = pass + 1 else fail = fail + 1; io.stdout:write("FAIL: " .. name .. "\n") end
end

-- ------------------------------------------------------------ CET globals
local handlers = {}
function registerForEvent(name, fn) handlers[name] = fn end
local logs = {}
spdlog = { info = function(s) logs[#logs + 1] = s end }
function print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end logs[#logs + 1] = table.concat(t, " ") end
function IsDefined(x) return x ~= nil end
json = {
    encode = function(t)
        local parts = {}
        for k, v in pairs(t) do parts[#parts + 1] = string.format("%q:%s", k, tostring(v)) end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
    end,
    decode = function(s)
        local t = {}
        for k, v in s:gmatch('"(%w+)":(%-?%d+)') do t[k] = tonumber(v) end
        return t
    end,
}
local NOW = 100
os.clock = function() return NOW end

local seq = 0
local function enumTable() return setmetatable({}, { __index = function(t, k) seq = seq + 1; rawset(t, k, seq); return seq end }) end
ImGuiCol = enumTable()
ImGuiStyleVar = enumTable()
ImGuiCond = { FirstUseEver = 4, Always = 1 }
ImGuiWindowFlags = { NoScrollbar = 8, NoScrollWithMouse = 16 }

-- ------------------------------------------------------------ fake redscript system
-- { hash, title, text, ts, flags (1 unread, 2 encrypted, 4 PL), group }
local SH = {
    { 101, "Night City Tourist Guide", "Welcome to NC.\r\n\r\nSee the sights.", 5000, 1, 2 },
    { 102, "Old Note", "A note.", 1000, 0, 4 },
    { -103, "Arasaka Memo", "Secret plans.", 9000, 1, 3 },
    { 104, "Locked Thing", "SECRET TEXT", -1, 3, 11 },
    { 105, "Poem", "roses", 8990, 4, 9 },
    { 107, "", "no title here", 9550, 0, 10 },
}
local GN = { "Literature & Fiction", "Night City People", "World", "Technology", "Notes", "Articles", "Leaflets",
    "Cyberpsychos", "Religion & Philosophy", "Poetry", "Others", "Encrypted" }
local CALLS = {}
local SYS = { gen = 1, now = 9600, refreshes = 0, fail = false, hashes = {}, times = {}, flags = {}, groups = {} }
local function find(h) for _, s in ipairs(SH) do if s[1] == h then return s end end end
function SYS:Generation() return self.gen end
function SYS:Now() return self.now end
function SYS:Refresh()
    self.refreshes = self.refreshes + 1
    if self.fail then error("journal exploded") end
    self.hashes, self.times, self.flags, self.groups = {}, {}, {}, {}
    for _, s in ipairs(SH) do
        self.hashes[#self.hashes + 1] = s[1]; self.times[#self.times + 1] = s[4]
        self.flags[#self.flags + 1] = s[5]; self.groups[#self.groups + 1] = s[6]
    end
    return #SH
end
function SYS:Hashes() return self.hashes end
function SYS:Times() return self.times end
function SYS:Flags() return self.flags end
function SYS:Groups() return self.groups end
function SYS:GroupNames() return GN end
function SYS:Title(h) self.titles = (self.titles or 0) + 1; local s = find(h); return s and s[2] or "" end
function SYS:Text(h) local s = find(h); if not s or s[5] % 4 >= 2 then return "" end; return s[3] end
function SYS:Match(n)
    CALLS[#CALLS + 1] = "match:" .. n
    n = n:lower()
    local out = {}
    for _, s in ipairs(SH) do
        if s[2]:lower():find(n, 1, true) or (s[5] % 4 < 2 and s[3]:lower():find(n, 1, true)) then out[#out + 1] = s[1] end
    end
    return out
end
function SYS:MarkRead(h, read)
    CALLS[#CALLS + 1] = "mark:" .. h .. ":" .. tostring(read)
    local s = find(h)
    if not s then return false end
    local unread = s[5] % 2
    if read then s[5] = s[5] - unread elseif unread == 0 then s[5] = s[5] + 1 end
    self.gen = self.gen + 1
    return true
end
local sysPresent, inGame = true, true
local PLAYER = {}
Game = {
    GetPlayer = function() return inGame and PLAYER or nil end,
    GetScriptableSystemsContainer = function() return { Get = function(self, name)
        assert(name == "CyberslopShardLogSystem", "system name")
        return sysPresent and SYS or nil
    end } end,
}

-- ------------------------------------------------------------ ImGui stub
local quiet = false
local imCalls = 0
local F = {}
local IN = { click = nil, hover = nil, input = nil, combo = false, availW = 560, availH = 640 }
local bal
local function resetFrame()
    F = { texts = {}, wrapped = {}, disabled = {}, colored = {}, buttons = {}, rows = {}, selectables = {} }
    bal = { col = 0, var = 0, win = 0, child = 0, clip = 0, combo = 0, scale = 1 }
end
resetFrame()
local cursorY, lastItem = 0, nil
local DL = {}
local Im = {}
function Im.GetTextLineHeight() return 18 end
function Im.CalcTextSize(s) return #s * 8, 18 end
function Im.GetContentRegionAvail() return IN.availW, IN.availH end
function Im.GetWindowSize() return IN.availW, 600 end
function Im.GetScrollY() return 0 end
function Im.GetWindowDrawList() return DL end
function Im.SetCursorPosY(y) cursorY = y end
function Im.GetCursorScreenPos() return 100, 100 + cursorY end
function Im.InvisibleButton(id, w, h)
    assert(w >= 1 and h >= 1, "zero-size InvisibleButton")
    lastItem = id
    if not quiet and id:sub(1, 6) == "##cslr" then F.rows[#F.rows + 1] = id end
    return IN.click == id
end
function Im.IsItemHovered() return IN.hover ~= nil and IN.hover == lastItem end
function Im.Button(label) lastItem = label; if not quiet then F.buttons[#F.buttons + 1] = label end; return IN.click == label end
function Im.InputTextWithHint(id, hint, text, n) lastItem = id; if IN.input then local t = IN.input; IN.input = nil; return t, true end; return text, false end
function Im.TextWrapped(s) assert(type(s) == "string", "TextWrapped string"); lastItem = s; if not quiet then F.wrapped[#F.wrapped + 1] = s end end
function Im.TextDisabled(s) lastItem = s; if not quiet then F.disabled[#F.disabled + 1] = s end end
function Im.TextColored(r, g, b, a, s) lastItem = s; if not quiet then F.colored[#F.colored + 1] = s end end
function Im.ImDrawListAddText(dl, x, y, col, s) assert(type(s) == "string", "AddText string"); if not quiet then F.texts[#F.texts + 1] = s end end
function Im.PushStyleColor(i, r, g, b, a) assert(type(i) == "number" and type(a) == "number", "PushStyleColor args"); bal.col = bal.col + 1 end
function Im.PopStyleColor(n) bal.col = bal.col - (n or 1) end
function Im.PushStyleVar(i, x, y) bal.var = bal.var + 1 end
function Im.PopStyleVar(n) bal.var = bal.var - (n or 1) end
function Im.Begin(name, flags) bal.win = bal.win + 1; return not IN.collapsed end
function Im.End() bal.win = bal.win - 1 end
function Im.BeginChild(id, w, h, border) bal.child = bal.child + 1; return true end
function Im.EndChild() bal.child = bal.child - 1 end
function Im.PushClipRect() bal.clip = bal.clip + 1 end
function Im.PopClipRect() bal.clip = bal.clip - 1 end
function Im.SetWindowFontScale(s) bal.scale = s end
function Im.BeginCombo(id, preview) lastItem = id; if not quiet then F.comboPreview = preview end; if IN.combo then bal.combo = bal.combo + 1; return true end; return false end
function Im.EndCombo() bal.combo = bal.combo - 1 end
-- CET's Selectable(label, selected) returns the (possibly toggled) selected state
function Im.Selectable(label, selected)
    if not quiet then F.selectables[#F.selectables + 1] = label end
    if IN.click == label then return not selected end
    return selected
end
ImGui = setmetatable({}, { __index = function(t, k)
    local f = Im[k] or function() end
    local w = function(...) imCalls = imCalls + 1; return f(...) end
    rawset(t, k, w)
    return w
end })

-- ------------------------------------------------------------ helpers
local cwdCfg = "config.json"
os.remove(cwdCfg)
assert(loadfile(MOD))()
handlers.onInit()

local function frame(inputs)
    resetFrame()
    for k, v in pairs(inputs or {}) do IN[k] = v end
    handlers.onDraw()
    IN.click, IN.hover, IN.combo = nil, nil, false
    local b = bal
    ok(b.col == 0 and b.var == 0 and b.win == 0 and b.child == 0 and b.clip == 0 and b.combo == 0 and b.scale == 1,
        string.format("balance col=%d var=%d win=%d child=%d clip=%d combo=%d scale=%s", b.col, b.var, b.win, b.child, b.clip, b.combo, tostring(b.scale)))
    return F
end
local function has(list, s) for _, v in ipairs(list) do if v == s then return true end end return false end
local function count(list, s) local n = 0 for _, v in ipairs(list) do if v == s then n = n + 1 end end return n end
local function idx(list, s) for i, v in ipairs(list) do if v == s then return i end end return nil end
local function inOrder(texts, names)
    local last = 0
    for _, n in ipairs(names) do
        local i = idx(texts, n)
        if not i or i <= last then return false, n end
        last = i
    end
    return true
end
local function callsStr() return table.concat(CALLS, ",") end
local function clearCalls() for i = #CALLS, 1, -1 do CALLS[i] = nil end end
local function errs() local n = 0 for _, l in ipairs(logs) do if l:find("error") then n = n + 1 end end return n end
local function rowOf(f, title)
    -- rows are drawn in order; title texts follow their row id, so map by order of appearance
    local titles = {}
    for _, t in ipairs(f.texts) do
        for _, s in ipairs(SH) do if t == (s[2] ~= "" and s[2] or "(untitled shard)") then titles[#titles + 1] = t end end
    end
    for i, t in ipairs(titles) do if t == title then return f.rows[i] end end
end

-- ------------------------------------------------------------ tests
-- T1 overlay closed: nothing at all
imCalls = 0
handlers.onDraw()
ok(imCalls == 0, "T1 closed overlay makes no ImGui calls")

-- T2 open: chips, order (encrypted first, then newest), labels
handlers.onOverlayOpen()
local f = frame()
ok(has(f.texts, "ALL 6") and has(f.texts, "NEW 3") and has(f.texts, "ENCRYPTED 1"), "T2 chip counts 6/3/1")
local good, miss = inOrder(f.texts, { "Locked Thing", "(untitled shard)", "Arasaka Memo", "Poem", "Night City Tourist Guide", "Old Note" })
ok(good, "T2 newest first, encrypted on top (" .. tostring(miss) .. ")")
ok(has(f.texts, "JUST NOW") and count(f.texts, "10 MIN AGO") == 2 and has(f.texts, "1 H AGO") and has(f.texts, "2 H AGO"), "T2 ago labels")
ok(has(f.texts, "ENCRYPTED"), "T2 encrypted label")
ok(count(f.texts, "NEW") == 2, "T2 NEW tag on the 2 unread readable shards (" .. count(f.texts, "NEW") .. ")")
ok(has(f.texts, "WORLD") and has(f.texts, "POETRY  |  PHANTOM LIBERTY") and has(f.texts, "OTHERS"), "T2 category lines")
ok(#f.rows == 6, "T2 6 rows drawn (" .. #f.rows .. ")")
ok(SYS.refreshes == 1, "T2 one refresh on open (" .. SYS.refreshes .. ")")
ok(errs() == 0, "T2 no errors logged")
local titlesRead = SYS.titles

-- T3 click the tourist guide: reading pane, marked read
clearCalls()
local r = rowOf(f, "Night City Tourist Guide")
frame({ click = r, hover = r })
f = frame()
ok(callsStr() == "mark:101:true", "T3 opening marks read (" .. callsStr() .. ")")
ok(has(f.wrapped, "Night City Tourist Guide"), "T3 reader title")
ok(has(f.wrapped, "Welcome to NC.") and has(f.wrapped, "See the sights.") and not has(f.wrapped, "Welcome to NC.\r"), "T3 text paragraphs")
ok(has(f.colored, "WORLD  |  ADDED 1 H AGO, 01:23"), "T3 meta line (" .. tostring(f.colored[1]) .. ")")
ok(has(f.buttons, "MARK UNREAD##csl_mr") and has(f.buttons, "CLOSE##csl_dc"), "T3 buttons")
ok(has(f.texts, "NEW 2") and count(f.texts, "NEW") == 1, "T3 NEW count down, tag gone")

-- T4 mark unread / read again
clearCalls()
frame({ click = "MARK UNREAD##csl_mr" })
f = frame()
ok(callsStr() == "mark:101:false" and has(f.buttons, "MARK READ##csl_mr") and has(f.texts, "NEW 3"), "T4 mark unread (" .. callsStr() .. ")")
frame({ click = "CLOSE##csl_dc" })
f = frame()
ok(not has(f.wrapped, "Night City Tourist Guide"), "T4 CLOSE hides the reader")

-- T5 New tab: read-now shards stay until the overlay closes
frame({ click = "##csl_t2" })
f = frame()
good, miss = inOrder(f.texts, { "Locked Thing", "Arasaka Memo", "Night City Tourist Guide" })
ok(good and #f.rows == 3, "T5 new tab rows (" .. #f.rows .. ", " .. tostring(miss) .. ")")
r = rowOf(f, "Arasaka Memo")
clearCalls()
frame({ click = r, hover = r })
NOW = NOW + 1
f = frame()
ok(callsStr() == "mark:-103:true", "T5 negative hash passed through (" .. callsStr() .. ")")
ok(has(f.texts, "Arasaka Memo") and #f.rows == 3, "T5 just-read shard stays in the New tab")
handlers.onOverlayClose()
handlers.onOverlayOpen()
f = frame()
ok(not has(f.texts, "Arasaka Memo") and #f.rows == 2, "T5 gone after reopening the overlay (" .. #f.rows .. ")")
ok(not has(f.buttons, "MARK ALL READ##csl_all"), "T5 no mark-all button (quest mods read the flag)")

-- T6 Encrypted tab: no mark, message instead of text
frame({ click = "##csl_t3" })
f = frame()
ok(#f.rows == 1 and has(f.texts, "Locked Thing"), "T6 encrypted tab")
clearCalls()
frame({ click = "##cslr0", hover = "##cslr0" })
f = frame()
ok(callsStr() == "", "T6 encrypted shard not marked (" .. callsStr() .. ")")
local encMsg = false
for _, s in ipairs(f.wrapped) do if s:find("^Encrypted%.") then encMsg = true end end
ok(encMsg and not has(f.wrapped, "SECRET TEXT"), "T6 encrypted message, no text")
ok(not has(f.buttons, "MARK READ##csl_mr") and not has(f.buttons, "MARK UNREAD##csl_mr"), "T6 no mark buttons")
ok(has(f.colored, "ENCRYPTED  |  IN YOUR INVENTORY"), "T6 encrypted meta")
frame({ click = "CLOSE##csl_dc" })
frame({ click = "##csl_t1" })

-- T7 search: titles at once, texts after the delay
clearCalls()
frame({ input = "memo" })
f = frame()
ok(#f.rows == 1 and has(f.texts, "Arasaka Memo"), "T7 title search instant (" .. #f.rows .. ")")
frame({ input = "sights" })
f = frame()
ok(#f.rows == 0 and has(f.disabled, "No shard matches the search."), "T7 text-only match not yet searched")
NOW = NOW + 1
frame()
f = frame()
ok(#f.rows == 1 and has(f.texts, "Night City Tourist Guide"), "T7 text match after the delay (" .. #f.rows .. ")")
ok(callsStr():find("match:sights") ~= nil, "T7 Match called (" .. callsStr() .. ")")
frame({ input = "SECRET" })
NOW = NOW + 1
frame()
f = frame()
ok(#f.rows == 1 and has(f.texts, "Arasaka Memo"), "T7 encrypted text not searchable (" .. #f.rows .. ")")
frame({ input = "" })
f = frame()
ok(#f.rows == 6, "T7 cleared search shows all")

-- T8 sort A-Z, saved
frame({ click = "NEWEST##csl_sort" })
f = frame()
good, miss = inOrder(f.texts, { "(untitled shard)", "Arasaka Memo", "Locked Thing", "Night City Tourist Guide", "Old Note", "Poem" })
ok(good and has(f.buttons, "A-Z##csl_sort"), "T8 A-Z order (" .. tostring(miss) .. ")")
frame({ click = "A-Z##csl_sort" })

-- T9 category combo
f = frame({ combo = true })
ok(has(f.selectables, "ALL CATEGORIES (6)") and has(f.selectables, "WORLD (1)##cslg2") and has(f.selectables, "ENCRYPTED (1)##cslg11"), "T9 combo entries")
ok(not has(f.selectables, "TECHNOLOGY (0)##cslg3") and #f.selectables == 7, "T9 only non-empty categories (" .. #f.selectables .. ")")
frame({ combo = true, click = "WORLD (1)##cslg2" })
f = frame()
ok(#f.rows == 1 and has(f.texts, "Night City Tourist Guide") and f.comboPreview == "WORLD", "T9 category filter")
frame({ combo = true }) -- the selected entry keeps returning true: must not re-trigger
f = frame()
ok(#f.rows == 1, "T9 selected entry stays")
local cfgText = io.open(cwdCfg, "r"):read("*a")
ok(cfgText:find('"group":2') ~= nil, "T9 category saved (" .. cfgText .. ")")
frame({ combo = true, click = "ALL CATEGORIES (6)" })
f = frame()
ok(#f.rows == 6, "T9 back to all")

-- T10 change detection: new shard on a generation bump; nothing without one; fallback after 15 s
local before = SYS.refreshes
NOW = NOW + 0.6
frame()
ok(SYS.refreshes == before, "T10 no refresh without a change")
table.insert(SH, { 108, "Fresh Loot", "brand new", 9600, 1, 5 })
SYS.gen = SYS.gen + 1
NOW = NOW + 0.6
frame()
f = frame()
good, miss = inOrder(f.texts, { "Locked Thing", "Fresh Loot", "(untitled shard)" })
ok(good and has(f.texts, "ALL 7"), "T10 new shard on top after the change (" .. tostring(miss) .. ")")
before = SYS.refreshes
NOW = NOW + 31
frame()
ok(SYS.refreshes == before + 1, "T10 fallback re-read after 30 s")
ok(SYS.titles == titlesRead + 1, "T10 titles cached (" .. SYS.titles .. " calls)")

-- T11 browsing tabs / scrolling marks nothing; only opened shards change
frame({ click = "##csl_t2" })
clearCalls()
for _ = 1, 3 do NOW = NOW + 0.6; frame() end
f = frame()
ok(callsStr() == "" and has(f.texts, "NEW 3"), "T11 nothing marked without opening (" .. callsStr() .. ")")
frame({ click = "##csl_t1" })

-- T12 refresh error: shown, logged once, back-off, recovery
SYS.fail = true
SYS.gen = SYS.gen + 1
NOW = NOW + 1
f = frame()
local shown = false
for _, s in ipairs(f.colored) do if s:find("journal exploded") then shown = true end end
ok(shown, "T12 error shown in the window")
NOW = NOW + 1
frame()
local n = 0
for _, l in ipairs(logs) do if l:find("journal exploded") then n = n + 1 end end
ok(n == 1, "T12 error logged once (" .. n .. ")")
SYS.fail = false
NOW = NOW + 6
f = frame()
shown = false
for _, s in ipairs(f.colored) do if s:find("journal exploded") then shown = true end end
ok(not shown and #f.rows > 0, "T12 recovers")

-- T13 days label
SYS.now = 9600 + 2 * 86400
SYS.gen = SYS.gen + 1
NOW = NOW + 1
f = frame()
ok(has(f.texts, "2 DAYS AGO"), "T13 days label")

-- T14 main menu, then no redscript part
inGame = false
NOW = NOW + 1
f = frame()
ok(has(f.disabled, "Load a save to see your shards.") and #f.rows == 0, "T14 main menu message")
inGame = true
sysPresent = false
NOW = NOW + 1
f = frame()
local missing = false
for _, s in ipairs(f.colored) do if s:find("Redscript part missing") then missing = true end end
ok(missing, "T14 missing redscript part reported")
sysPresent = true
NOW = NOW + 1
f = frame()
ok(#f.rows == 7, "T14 rows back (" .. #f.rows .. ")")

-- T15 closed overlay: no calls; garbage per open frame
handlers.onOverlayClose()
imCalls = 0
for _ = 1, 100 do handlers.onDraw() end
ok(imCalls == 0, "T15 closed overlay: no ImGui calls")
handlers.onOverlayOpen()
frame()
quiet = true
collectgarbage("collect")
collectgarbage("stop")
local kb = collectgarbage("count")
for _ = 1, 2000 do handlers.onDraw() end
local perFrame = (collectgarbage("count") - kb) / 2000
collectgarbage("restart")
io.stdout:write(string.format("garbage per open-overlay frame (no change, polls included): %.3f KB\n", perFrame))
ok(perFrame < 0.5, "T15 per-frame garbage below 0.5 KB")
collectgarbage("collect")
kb = collectgarbage("count")
collectgarbage("stop")
SYS.gen = SYS.gen + 1
NOW = NOW + 1
handlers.onDraw()
local perRefresh = collectgarbage("count") - kb
collectgarbage("restart")
io.stdout:write(string.format("garbage per refresh (7 shards): %.1f KB\n", perRefresh))
quiet = false

-- T16 narrow / wide layout
IN.availW = 400
f = frame()
r = rowOf(f, "Poem")
frame({ click = r, hover = r })
f = frame()
ok(has(f.wrapped, "Poem") and has(f.wrapped, "roses"), "T16 narrow layout reader")
IN.availW = 900
f = frame()
ok(has(f.wrapped, "Poem") and #f.rows == 7, "T16 wide layout reader beside the list")
IN.availW = 560

-- T17 collapsed: no reads; expanding reads at once
IN.collapsed = true
frame()
before = SYS.refreshes
for _ = 1, 4 do SYS.gen = SYS.gen + 1; NOW = NOW + 2; frame() end
ok(SYS.refreshes == before, "T17 collapsed: no refresh (" .. before .. " -> " .. SYS.refreshes .. ")")
IN.collapsed = false
frame()
frame()
ok(SYS.refreshes > before, "T17 expanded: read again")

-- T18 config reload (tab / sort / group)
frame({ click = "##csl_t2" })
frame({ click = "NEWEST##csl_sort" })
cfgText = io.open(cwdCfg, "r"):read("*a")
ok(cfgText:find('"tab":2') and cfgText:find('"sort":2') and cfgText:find('"group":%-1'), "T18 config written (" .. cfgText .. ")")

-- T19 a big journal: 400 shards
frame({ click = "##csl_t1" })
for i = 1, 400 do table.insert(SH, { 5000 + i, "Bulk Shard " .. i, "text " .. i, 1000 + i * 7, i % 3 == 0 and 1 or 0, i % 11 }) end
SYS.gen = SYS.gen + 1
NOW = NOW + 1
f = frame()
ok(has(f.texts, "ALL 407"), "T19 407 shards")
ok(#f.rows <= 30, "T19 only visible rows drawn (" .. #f.rows .. ")")
quiet = true
collectgarbage("collect")
kb = collectgarbage("count")
collectgarbage("stop")
SYS.gen = SYS.gen + 1
NOW = NOW + 1
local t0 = os.time()
handlers.onDraw()
perRefresh = collectgarbage("count") - kb
collectgarbage("restart")
io.stdout:write(string.format("garbage per refresh (407 shards): %.1f KB\n", perRefresh))
collectgarbage("collect")
collectgarbage("stop")
kb = collectgarbage("count")
for _ = 1, 2000 do handlers.onDraw() end
perFrame = (collectgarbage("count") - kb) / 2000
collectgarbage("restart")
io.stdout:write(string.format("garbage per open-overlay frame (407 shards): %.3f KB\n", perFrame))
ok(perFrame < 0.5, "T19 per-frame garbage below 0.5 KB")
quiet = false

ok(errs() == 1, "no unexpected errors (" .. errs() .. ")")
for _, l in ipairs(logs) do if l:find("error") and not l:find("journal exploded") then io.stdout:write("LOG: " .. l .. "\n") end end
io.stdout:write(string.format("mock: %d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
