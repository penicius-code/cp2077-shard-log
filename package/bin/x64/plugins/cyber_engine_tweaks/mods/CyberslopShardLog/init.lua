-- Cyberslop Shard Log 1.1.0 (2026-11-25)
-- Every shard V has, in one CET window, newest first: no categories to click through like the journal's Shards
-- screen. Tabs All / New (unread) / Encrypted, category filter, search (title instantly, shard text a moment later),
-- sort Newest / A-Z. A row shows the title, the category and how long ago (game time) the shard went into the
-- journal. Click a row: the text in the reading pane; that marks the shard read in the journal too (the journal does
-- the same when you select a shard). Mark unread / read button. No "mark all read": quest mods read that flag
-- (DedraLucy Part Two picks a branch by whether V read its shards), so only shards V opens get marked.
-- 1.1.0: shards with a voice recording (Shard Audio Framework + its AudioXL pack) carry an AUDIO tag; the reading
-- pane gets PLAY AUDIO / STOP AUDIO, and while a recording plays the bottom line shows it with a STOP button, so you
-- can keep browsing. Playing goes through the redscript system (same sound the framework's journal button plays).
-- The journal reads live in r6\scripts\CyberslopShardLog\CyberslopShardLog.reds (CyberslopShardLogSystem).
-- Cost: no onUpdate, no hooks, no keys. onDraw returns at once while the CET overlay is closed. While it is open and
-- the window expanded: one change check every 0.5 s (a counter the redscript side bumps on shard journal changes),
-- a full re-read after a change, on every overlay open and every 30 s; titles cached per shard; only the rows inside
-- the scroll view are drawn.

local VERSION = "1.1.0"
local SYS_NAME = "CyberslopShardLogSystem"
local CONFIG = "config.json"
local POLL = 0.5          -- s between change checks while the overlay is open
local FALLBACK = 30       -- s: full re-read even without a change signal
local SEARCH_DELAY = 0.25 -- s after the last key before the shard texts are searched
local WIDE = 820          -- content width from which the reading pane sits beside the list
local CUT = 9             -- cut corner of rows and chips, px
local TITLE_SCALE = 1.08
local AUDIO_GRACE = 1.5   -- s after PLAY before "not playing" is believed (the mp3 starts from disk)
local SAF_NAME = "ShardAudioFramework.SAFStateSystem"
local G_ENC = 11          -- group index of encrypted shards (redscript GroupNames order)

local TAB_ALL, TAB_NEW, TAB_ENC = 1, 2, 3
local TAB_ID = { "##csl_t1", "##csl_t2", "##csl_t3" }
local TAB_NAME = { "ALL", "NEW", "ENCRYPTED" }
local TAB_TIP = { "Every shard, newest first", "Unread shards (and shards read while the overlay is open)",
    "Encrypted shards in your inventory: crack them in the journal" }

-- draw-list colours (ImU32 = 0xAABBGGRR), same palette as Quest Picker (2.5 journal screen)
local function abgr(r, g, b, a)
    return math.floor((a or 1) * 255 + 0.5) * 16777216 + b * 65536 + g * 256 + r
end
local K = {
    rowBg = abgr(24, 18, 16, 0.92), rowBgHov = abgr(36, 27, 24, 0.95),
    rowLine = abgr(86, 66, 56, 0.9), rowLineHov = abgr(136, 108, 90, 1),
    newBg = abgr(40, 33, 14, 0.94), newLine = abgr(200, 168, 50, 0.9),
    sel = abgr(94, 246, 255, 0.85),
    title = abgr(98, 226, 240, 1), titleHov = abgr(150, 252, 255, 1), titleNew = abgr(252, 236, 160, 1),
    sub = abgr(150, 144, 136, 1), subHov = abgr(206, 200, 192, 1),
    ago = abgr(198, 236, 244, 1),
    yellow = abgr(250, 212, 30, 1), ink = abgr(26, 16, 6, 1),
    red = abgr(255, 78, 72, 1), cyanDim = abgr(94, 246, 255, 0.55),
    chipBg = abgr(30, 13, 12, 0.92), chipLine = abgr(100, 38, 34, 0.95),
    chipBgOn = abgr(8, 40, 44, 0.94), chipLineOn = abgr(94, 246, 255, 1),
}
local TAB_COL = { abgr(94, 246, 255, 1), K.yellow, K.red }

-- window palette (ImGui style colours, 0-255), pushed around this window only
local PAL = {
    { "Text", 215, 210, 200, 1 }, { "TextDisabled", 128, 116, 106, 1 },
    { "WindowBg", 13, 10, 9, 0.85 }, { "ChildBg", 0, 0, 0, 0 }, { "PopupBg", 16, 11, 10, 0.97 },
    { "Border", 112, 36, 32, 0.85 }, { "BorderShadow", 0, 0, 0, 0 },
    { "TitleBg", 28, 10, 9, 0.95 }, { "TitleBgActive", 96, 18, 16, 0.97 }, { "TitleBgCollapsed", 28, 10, 9, 0.8 },
    { "FrameBg", 22, 8, 8, 0.92 }, { "FrameBgHovered", 44, 14, 13, 0.95 }, { "FrameBgActive", 62, 18, 16, 1 },
    { "ScrollbarBg", 52, 12, 12, 0.55 }, { "ScrollbarGrab", 255, 75, 70, 0.95 },
    { "ScrollbarGrabHovered", 255, 112, 102, 1 }, { "ScrollbarGrabActive", 255, 140, 126, 1 },
    { "Button", 14, 44, 48, 0.92 }, { "ButtonHovered", 24, 72, 78, 0.96 }, { "ButtonActive", 38, 102, 110, 1 },
    { "Header", 14, 44, 48, 0.92 }, { "HeaderHovered", 24, 72, 78, 0.96 }, { "HeaderActive", 38, 102, 110, 1 },
    { "Separator", 112, 36, 32, 0.7 }, { "CheckMark", 94, 246, 255, 1 },
    { "ResizeGrip", 255, 75, 70, 0.25 }, { "ResizeGripHovered", 255, 75, 70, 0.6 },
    { "ResizeGripActive", 255, 75, 70, 0.9 }, { "TextSelectedBg", 94, 246, 255, 0.3 },
}

local cfg = { tab = TAB_ALL, sort = 1, group = -1 } -- sort 1 = newest first, 2 = A-Z; group -1 = all

-- state (one table keeps the upvalue count of the draw functions low)
local S = {
    overlay = false, shown = true, inGame = false, noSys = false, gen = -1, nextPoll = 0, nextFull = 0,
    needFull = true, now = 0, rows = {}, byHash = {}, view = {}, viewDirty = true,
    counts = { 0, 0, 0 }, chipLabel = { "ALL 0", "NEW 0", "ENCRYPTED 0" }, chipW = { 0, 0, 0 },
    groupNames = nil, groupCount = {}, groupLabel = {}, allLabel = "ALL CATEGORIES",
    search = "", searchLower = "", matchSet = nil, searchDue = nil,
    selected = nil, det = nil, readNow = {}, errMsg = nil, lastErr = nil, sortW = nil, comboW = nil,
    audio = nil, -- { hash, title, t0, len, label } while a recording started here plays
}
local agoCache, rowIds = {}, {}
local palFlat = nil

local function logLine(s)
    if spdlog and spdlog.info then spdlog.info("[CyberslopShardLog] " .. s) else print("[CyberslopShardLog] " .. s) end
end

local function valid(x)
    return x ~= nil and IsDefined(x)
end

-- ---------------------------------------------------------------- config

local function loadCfg()
    local f = io.open(CONFIG, "r")
    if not f then return end
    local s = f:read("*a")
    f:close()
    local ok, t = pcall(json.decode, s)
    if ok and type(t) == "table" then
        if type(t.tab) == "number" and t.tab >= 1 and t.tab <= 3 then cfg.tab = math.floor(t.tab) end
        if t.sort == 1 or t.sort == 2 then cfg.sort = t.sort end
        if type(t.group) == "number" and t.group >= -1 and t.group <= G_ENC then cfg.group = math.floor(t.group) end
    end
end

local function saveCfg()
    local f = io.open(CONFIG, "w")
    if f then
        f:write(json.encode(cfg))
        f:close()
    end
end

-- ---------------------------------------------------------------- reads

local function getSys()
    local sc = Game.GetScriptableSystemsContainer()
    if not sc then return nil end
    local s = sc:Get(SYS_NAME)
    if valid(s) then return s end
    return nil
end

-- "JUST NOW" / "12 MIN AGO" / "3 H AGO" / "2 DAYS AGO" (game time); cached with its width
local function agoOf(ts)
    local key, s
    if ts < 0 then
        key = -1
    elseif ts == 0 or S.now <= 0 then
        return "", 0
    else
        local d = S.now - ts
        if d < 120 then
            key = 0
        elseif d < 3600 then
            key = math.floor(d / 60)
        elseif d < 86400 then
            key = 1000 + math.floor(d / 3600)
        else
            key = 2000 + math.floor(d / 86400)
        end
    end
    local e = agoCache[key]
    if e then return e[1], e[2] end
    if key == -1 then
        s = "ENCRYPTED"
    elseif key == 0 then
        s = "JUST NOW"
    elseif key < 1000 then
        s = key .. " MIN AGO"
    elseif key < 2000 then
        s = (key - 1000) .. " H AGO"
    else
        s = (key - 2000) == 1 and "1 DAY AGO" or ((key - 2000) .. " DAYS AGO")
    end
    e = { s, (ImGui.CalcTextSize(s)) }
    agoCache[key] = e
    return e[1], e[2]
end

local function clockOf(ts)
    if ts <= 0 then return nil end
    return string.format("%02d:%02d", math.floor(ts / 3600) % 24, math.floor(ts / 60) % 60)
end

local function groupName(g)
    local n = S.groupNames
    return (n and n[g + 1]) or "SHARDS"
end

local function recount()
    local all, new, enc = #S.rows, 0, 0
    local gc = {}
    for i = 1, #S.rows do
        local r = S.rows[i]
        if r.unread then new = new + 1 end
        if r.enc then enc = enc + 1 end
        gc[r.group] = (gc[r.group] or 0) + 1
    end
    local c = S.counts
    if c[1] ~= all or c[2] ~= new or c[3] ~= enc or not S.chipLabel[1] then
        c[1], c[2], c[3] = all, new, enc
        for t = 1, 3 do S.chipLabel[t] = TAB_NAME[t] .. " " .. c[t] end
    end
    S.groupCount = gc
    S.groupLabel = {}
    S.allLabel = "ALL CATEGORIES (" .. all .. ")"
end

local function runSearch(sys)
    S.searchDue = nil
    if S.searchLower == "" then
        S.matchSet = nil
    else
        local m = sys:Match(S.search) or {}
        local set = {}
        for i = 1, #m do set[m[i]] = true end
        S.matchSet = set
    end
    S.viewDirty = true
end

local function refresh(sys, now)
    sys:Refresh()
    local H, T, Fl, G = sys:Hashes() or {}, sys:Times() or {}, sys:Flags() or {}, sys:Groups() or {}
    local nowTs = sys:Now() or 0
    if nowTs ~= S.now then
        S.now = nowTs
        for k in pairs(agoCache) do agoCache[k] = nil end
    end
    if not S.groupNames then
        local names = sys:GroupNames() or {}
        local up = {}
        for i = 1, #names do up[i] = string.upper(names[i]) end
        S.groupNames = up
    end
    local rows, seen, by = {}, {}, S.byHash
    for i = 1, #H do
        local h = H[i]
        local r = by[h]
        if not r then
            r = { hash = h }
            by[h] = r
        end
        if not r.title then
            local t = sys:Title(h)
            if type(t) ~= "string" or t == "" then t = "(untitled shard)" end
            r.title = t
            r.lower = string.lower(t)
        end
        local f = Fl[i] or 0
        r.unread = f % 2 == 1
        r.enc = math.floor(f / 2) % 2 == 1
        r.ep1 = math.floor(f / 4) % 2 == 1
        local voiced = math.floor(f / 8) % 2 == 1
        local g = G[i] or 10
        if r.group ~= g or r.voiced ~= voiced or not r.sub then
            r.group = g
            r.voiced = voiced
            r.sub = groupName(g) .. (r.ep1 and "  |  PHANTOM LIBERTY" or "") .. (voiced and "  |  AUDIO" or "")
        end
        r.ts = T[i] or 0
        r.ago, r.agoW = agoOf(r.ts)
        rows[#rows + 1] = r
        seen[h] = true
    end
    for h in pairs(by) do
        if not seen[h] then by[h] = nil end
    end
    S.rows = rows
    recount()
    if S.searchLower ~= "" then runSearch(sys) end
    S.viewDirty = true
    S.errMsg = nil
    S.nextFull = now + FALLBACK
    S.needFull = false
end

-- ---------------------------------------------------------------- audio

local function mmss(sec)
    sec = math.floor(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function audioLabel(a, pos)
    local s = "PLAYING: " .. a.title
    if a.len and a.len > 0 then
        if pos < 0 then pos = 0 elseif pos > a.len then pos = a.len end
        s = s .. "   " .. mmss(pos) .. " / " .. mmss(a.len)
    end
    a.label = s
end

-- Shard Audio Framework keeps "last key / stopped" in its own system (not reachable from redscript: the class is
-- not public). Kept in step here so its journal button and phone messages act on the recording started here, and
-- STOP here also ends one its journal button started. Best effort: without it play / stop still work.
local function safSync(sys, key)
    local ok, err = pcall(function()
        local sc = Game.GetScriptableSystemsContainer()
        local saf = sc and sc:Get(SAF_NAME)
        if not valid(saf) then return end
        if key then
            saf.m_lastLockeyStr = key
            saf.m_lastLockeyName = CName.new(key)
            saf.m_stopped = false
        else
            local last = saf.m_lastLockeyStr
            if type(last) == "string" and last ~= "" then sys:StopSound(last) end
            saf.m_stopped = true
        end
    end)
    if not ok and not S.safErr then
        S.safErr = true
        logLine("Shard Audio Framework state not synced: " .. tostring(err))
    end
end

local function stopAudio()
    local sys = getSys()
    if not sys then return end
    sys:StopAudio()
    safSync(sys, nil)
    S.audio = nil
end

local function playAudio(r)
    local sys = getSys()
    if not sys or not r then return end
    safSync(sys, nil) -- ends a recording the journal button started
    if sys:PlayAudio(r.hash) then
        local a = { hash = r.hash, title = r.title, t0 = os.clock(), len = sys:AudioLength() or 0 }
        audioLabel(a, 0)
        S.audio = a
        safSync(sys, sys:AudioKey(r.hash))
    else
        S.audio = nil
        S.errMsg = "Shard Log: no recording for this shard (AudioXL / Shard Audio pack missing?)"
    end
end

local function pollAudio(sys, now)
    local a = S.audio
    local h = sys:AudioPlaying() or 0
    if h ~= 0 then
        if not a or a.hash ~= h then
            local r = S.byHash[h]
            a = { hash = h, title = r and r.title or "shard", t0 = now - AUDIO_GRACE, len = sys:AudioLength() or 0 }
            S.audio = a
        end
        audioLabel(a, sys:AudioPosition() or 0)
    elseif a and now - a.t0 >= AUDIO_GRACE then
        S.audio = nil
    end
end

local function clearAll()
    S.audio = nil
    S.rows, S.det, S.selected, S.view = {}, nil, nil, {}
    S.byHash = {}
    S.gen = -1
    recount()
    S.viewDirty = true
end

local function poll(now)
    S.nextPoll = now + POLL
    S.inGame = valid(Game.GetPlayer())
    if not S.inGame then
        if S.gen ~= -1 or #S.rows > 0 then clearAll() end
        return
    end
    local sys = getSys()
    S.noSys = sys == nil
    if not sys then return end
    local g = sys:Generation()
    if g ~= S.gen or S.needFull or now >= S.nextFull then
        refresh(sys, now) -- an error leaves gen / needFull as they were: retried after the back-off
        S.gen = g
    elseif S.searchDue and now >= S.searchDue then
        runSearch(sys)
    end
    pollAudio(sys, now)
end

-- ---------------------------------------------------------------- actions

local function splitParas(text)
    local out = {}
    if type(text) ~= "string" or text == "" then return out end
    text = text:gsub("\r\n", "\n")
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = line end
    while #out > 0 and out[#out] == "" do out[#out] = nil end
    return out
end

local function markRead(r, read)
    local sys = getSys()
    if not sys or not r then return end
    if sys:MarkRead(r.hash, read) then
        r.unread = not read
        S.readNow[r.hash] = true
        recount()
        S.viewDirty = true
    end
end

local function openShard(r)
    local sys = getSys()
    if not sys then return end
    S.selected = r.hash
    local d = { hash = r.hash, title = r.title, enc = r.enc }
    local meta = groupName(r.group)
    if r.enc then
        meta = meta .. "  |  IN YOUR INVENTORY"
    elseif r.ts > 0 then
        local ago = agoOf(r.ts)
        meta = meta .. "  |  ADDED " .. (ago ~= "" and (ago .. ", ") or "") .. clockOf(r.ts)
    end
    if r.ep1 then meta = meta .. "  |  PHANTOM LIBERTY" end
    d.meta = meta
    if not r.enc then d.paras = splitParas(sys:Text(r.hash)) end
    S.det = d
    if r.unread and not r.enc then markRead(r, true) end
end

-- ---------------------------------------------------------------- view

local function inView(r, tab, grp, needle)
    if tab == TAB_NEW and not (r.unread or S.readNow[r.hash]) then return false end
    if tab == TAB_ENC and not r.enc then return false end
    if grp >= 0 and r.group ~= grp then return false end
    if needle ~= "" and not r.lower:find(needle, 1, true) and not (S.matchSet and S.matchSet[r.hash]) then
        return false
    end
    return true
end

local function cmpNewest(a, b)
    if a.enc ~= b.enc then return a.enc end
    if a.ts ~= b.ts then return a.ts > b.ts end
    if a.lower ~= b.lower then return a.lower < b.lower end
    return a.hash < b.hash
end

local function cmpAZ(a, b)
    if a.lower ~= b.lower then return a.lower < b.lower end
    return a.hash < b.hash
end

local function buildView()
    S.viewDirty = false
    local v, tab, grp, needle = {}, cfg.tab, cfg.group, S.searchLower
    local rows = S.rows
    for i = 1, #rows do
        local r = rows[i]
        if inView(r, tab, grp, needle) then v[#v + 1] = r end
    end
    table.sort(v, cfg.sort == 2 and cmpAZ or cmpNewest)
    S.view = v
end

-- ---------------------------------------------------------------- drawing helpers

local function rowId(i)
    local s = rowIds[i]
    if not s then
        s = "##cslr" .. i
        rowIds[i] = s
    end
    return s
end

local function cutFill(dl, x1, y1, x2, y2, c, col)
    ImGui.ImDrawListAddRectFilled(dl, x1, y1, x2, y2 - c, col)
    ImGui.ImDrawListAddRectFilled(dl, x1, y2 - c, x2 - c, y2, col)
    ImGui.ImDrawListAddTriangleFilled(dl, x2 - c, y2 - c, x2, y2 - c, x2 - c, y2, col)
end

local function cutLine(dl, x1, y1, x2, y2, c, col, th)
    x1, y1, x2, y2 = x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5
    ImGui.ImDrawListAddLine(dl, x1, y1, x2, y1, col, th)
    ImGui.ImDrawListAddLine(dl, x2, y1, x2, y2 - c, col, th)
    ImGui.ImDrawListAddLine(dl, x2, y2 - c, x2 - c, y2, col, th)
    ImGui.ImDrawListAddLine(dl, x2 - c, y2, x1, y2, col, th)
    ImGui.ImDrawListAddLine(dl, x1, y2, x1, y1, col, th)
end

-- data shard: a card with a cut top-right corner and two contacts at the bottom; a lock for encrypted ones
local function shardGlyph(dl, cx, cy, s, mode)
    local w = s * 0.62
    local x1, y1, x2, y2 = cx - w, cy - s, cx + w, cy + s
    local c = s * 0.5
    if mode == 1 then -- unread: filled yellow
        ImGui.ImDrawListAddRectFilled(dl, x1, y1 + c, x2, y2, K.yellow)
        ImGui.ImDrawListAddRectFilled(dl, x1, y1, x2 - c, y1 + c, K.yellow)
        ImGui.ImDrawListAddTriangleFilled(dl, x2 - c, y1, x2, y1 + c, x2 - c, y1 + c, K.yellow)
        ImGui.ImDrawListAddLine(dl, cx - w * 0.45, y2 - s * 0.35, cx - w * 0.45, y2 - 1, K.ink, 1.6)
        ImGui.ImDrawListAddLine(dl, cx + w * 0.15, y2 - s * 0.35, cx + w * 0.15, y2 - 1, K.ink, 1.6)
        return
    end
    local col = mode == 2 and K.red or K.cyanDim
    ImGui.ImDrawListAddLine(dl, x1, y1, x2 - c, y1, col, 1.5)
    ImGui.ImDrawListAddLine(dl, x2 - c, y1, x2, y1 + c, col, 1.5)
    ImGui.ImDrawListAddLine(dl, x2, y1 + c, x2, y2, col, 1.5)
    ImGui.ImDrawListAddLine(dl, x2, y2, x1, y2, col, 1.5)
    ImGui.ImDrawListAddLine(dl, x1, y2, x1, y1, col, 1.5)
    if mode == 2 then -- lock
        local lw = w * 0.62
        ImGui.ImDrawListAddRectFilled(dl, cx - lw, cy - s * 0.05, cx + lw, cy + s * 0.55, col)
        ImGui.ImDrawListAddLine(dl, cx - lw * 0.6, cy - s * 0.05, cx - lw * 0.6, cy - s * 0.42, col, 1.5)
        ImGui.ImDrawListAddLine(dl, cx - lw * 0.6, cy - s * 0.42, cx + lw * 0.6, cy - s * 0.42, col, 1.5)
        ImGui.ImDrawListAddLine(dl, cx + lw * 0.6, cy - s * 0.42, cx + lw * 0.6, cy - s * 0.05, col, 1.5)
    else
        ImGui.ImDrawListAddLine(dl, cx - w * 0.45, y2 - s * 0.35, cx - w * 0.45, y2 - 1, col, 1.4)
        ImGui.ImDrawListAddLine(dl, cx + w * 0.15, y2 - s * 0.35, cx + w * 0.15, y2 - 1, col, 1.4)
    end
end

-- ---------------------------------------------------------------- window parts

local function drawGroupCombo()
    local label = cfg.group >= 0 and groupName(cfg.group) or "ALL CATEGORIES"
    if ImGui.BeginCombo("##csl_grp", label) then
        if ImGui.Selectable(S.allLabel, cfg.group < 0) and cfg.group ~= -1 then
            cfg.group = -1
            S.viewDirty = true
            saveCfg()
        end
        local gc, gl = S.groupCount, S.groupLabel
        for g = 0, G_ENC do
            local n = gc[g]
            if n and n > 0 then
                local l = gl[g]
                if not l then
                    l = groupName(g) .. " (" .. n .. ")##cslg" .. g
                    gl[g] = l
                end
                if ImGui.Selectable(l, cfg.group == g) and cfg.group ~= g then
                    cfg.group = g
                    S.viewDirty = true
                    saveCfg()
                end
            end
        end
        ImGui.EndCombo()
    end
end

local function drawHeader(dl, lineH, chipH)
    local total = 0
    for t = 1, 3 do
        local w = ImGui.CalcTextSize(S.chipLabel[t]) + 22
        S.chipW[t] = w
        total = total + w + 6
    end
    for t = 1, 3 do
        local w = S.chipW[t]
        local x, y = ImGui.GetCursorScreenPos()
        if ImGui.InvisibleButton(TAB_ID[t], w, chipH) and cfg.tab ~= t then
            cfg.tab = t
            S.viewDirty = true
            saveCfg()
        end
        local hov = ImGui.IsItemHovered()
        if hov then ImGui.SetTooltip(TAB_TIP[t]) end
        local on = cfg.tab == t
        cutFill(dl, x, y, x + w, y + chipH, 6, on and K.chipBgOn or K.chipBg)
        cutLine(dl, x, y, x + w, y + chipH, 6, on and K.chipLineOn or (hov and K.rowLineHov or K.chipLine), on and 1.5 or 1)
        ImGui.ImDrawListAddText(dl, x + 11, y + (chipH - lineH) * 0.5, TAB_COL[t], S.chipLabel[t])
        ImGui.SameLine(0, 6)
    end
    if not S.comboW then S.comboW = ImGui.CalcTextSize("NIGHT CITY PEOPLE (999)") + 40 end
    local availW = ImGui.GetContentRegionAvail()
    local cw = availW < S.comboW and availW or S.comboW
    if cw < 80 then
        ImGui.NewLine()
        cw = S.comboW
    end
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, (chipH - lineH) * 0.5)
    ImGui.SetNextItemWidth(cw)
    drawGroupCombo()
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Journal category") end

    if not S.sortW then S.sortW = ImGui.CalcTextSize("NEWEST") + 22 end
    local w = ImGui.GetContentRegionAvail() - S.sortW - 6
    if w < 80 then w = 80 end
    ImGui.SetNextItemWidth(w)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, 0.66, 0.17, 0.15, 1)
    local txt, changed = ImGui.InputTextWithHint("##csl_search", "SEARCH TITLES AND TEXT", S.search, 80)
    ImGui.PopStyleColor(1)
    if changed and type(txt) == "string" and txt ~= S.search then
        S.search = txt
        S.searchLower = string.lower(txt)
        S.searchDue = os.clock() + SEARCH_DELAY
        if S.searchLower == "" then S.matchSet = nil end
        S.viewDirty = true
    end
    ImGui.SameLine(0, 6)
    if ImGui.Button(cfg.sort == 2 and "A-Z##csl_sort" or "NEWEST##csl_sort", S.sortW, chipH) then
        cfg.sort = 3 - cfg.sort
        S.viewDirty = true
        saveCfg()
    end
    ImGui.PopStyleVar(1)
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Sort: newest first / by title") end
end

local function drawRows()
    local view = S.view
    local n = #view
    if n == 0 then
        if not S.inGame then
            ImGui.TextDisabled("Load a save to see your shards.")
        elseif S.noSys then
            ImGui.TextColored(1, 0.35, 0.3, 1, "Redscript part missing: r6\\scripts\\CyberslopShardLog\\ (reinstall, restart the game).")
        elseif S.search ~= "" then
            ImGui.TextDisabled("No shard matches the search.")
        elseif cfg.tab == TAB_NEW then
            ImGui.TextDisabled("No unread shards.")
        elseif cfg.tab == TAB_ENC then
            ImGui.TextDisabled("No encrypted shards in your inventory.")
        else
            ImGui.TextDisabled("Nothing here.")
        end
        return
    end
    local dl = ImGui.GetWindowDrawList()
    local lineH = ImGui.GetTextLineHeight()
    local rowH = math.floor(lineH * 2 + 20)
    local pitch = rowH + 5
    local s = lineH * 0.55
    local w = ImGui.GetContentRegionAvail()
    if w < 60 then w = 60 end
    local scrollY = ImGui.GetScrollY()
    local _, winH = ImGui.GetWindowSize()
    local first = math.floor(scrollY / pitch)
    if first < 0 then first = 0 end
    local last = math.floor((scrollY + winH) / pitch)
    if last > n - 1 then last = n - 1 end
    if not S.newW then S.newW = ImGui.CalcTextSize("NEW") + 10 end
    for i = first, last do
        local r = view[i + 1]
        ImGui.SetCursorPosY(i * pitch)
        local x1, y1 = ImGui.GetCursorScreenPos()
        if ImGui.InvisibleButton(rowId(i), w, rowH) then openShard(r) end
        local hov = ImGui.IsItemHovered()
        local x2, y2 = x1 + w, y1 + rowH
        local fresh = r.unread and not r.enc
        cutFill(dl, x1, y1, x2, y2, CUT, fresh and K.newBg or (hov and K.rowBgHov or K.rowBg))
        cutLine(dl, x1, y1, x2, y2, CUT, fresh and K.newLine or (hov and K.rowLineHov or K.rowLine), 1)
        if r.hash == S.selected then cutLine(dl, x1 + 2, y1 + 2, x2 - 2, y2 - 2, CUT - 1, K.sel, 1) end
        shardGlyph(dl, x1 + 24, y1 + rowH * 0.5, s, r.enc and 2 or (r.unread and 1 or 0))

        local right = x2 - 14
        if r.ago and r.ago ~= "" then
            ImGui.ImDrawListAddText(dl, right - r.agoW, y1 + (rowH - lineH) * 0.5, r.enc and K.red or K.ago, r.ago)
            right = right - r.agoW - 12
        end
        if fresh then
            local bx, by = right - S.newW, y1 + (rowH - lineH) * 0.5 - 2
            cutFill(dl, bx, by, right, by + lineH + 4, 4, K.yellow)
            ImGui.ImDrawListAddText(dl, bx + 5, by + 2, K.ink, "NEW")
            right = bx - 10
        end
        local tx = x1 + 48
        local ty = y1 + (rowH - lineH * (1 + TITLE_SCALE) - 4) * 0.5
        ImGui.PushClipRect(tx, y1, right, y2, true)
        ImGui.SetWindowFontScale(TITLE_SCALE)
        ImGui.ImDrawListAddText(dl, tx, ty, hov and K.titleHov or (fresh and K.titleNew or K.title), r.title)
        ImGui.SetWindowFontScale(1)
        ImGui.ImDrawListAddText(dl, tx, ty + lineH * TITLE_SCALE + 4, hov and K.subHov or K.sub, r.sub)
        ImGui.PopClipRect()
    end
    ImGui.SetCursorPosY(n * pitch)
    ImGui.Dummy(1, 1)
end

local function drawDetails()
    local d = S.det
    if not d then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.47, 0.44, 1)
        ImGui.TextWrapped("Click a shard to read it. Opening a shard marks it read, in the journal too.")
        ImGui.PopStyleColor(1)
        return
    end
    ImGui.SetWindowFontScale(1.15)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.37, 0.96, 1, 1)
    ImGui.TextWrapped(d.title)
    ImGui.PopStyleColor(1)
    ImGui.SetWindowFontScale(1)
    ImGui.TextColored(0.86, 0.72, 0.25, 1, d.meta)
    ImGui.Spacing()
    local r = S.byHash[d.hash]
    if r and not d.enc then
        if r.unread then
            if ImGui.Button("MARK READ##csl_mr") then markRead(r, true) end
        else
            if ImGui.Button("MARK UNREAD##csl_mr") then markRead(r, false) end
        end
        ImGui.SameLine(0, 6)
        if r.voiced then
            if S.audio and S.audio.hash == r.hash then
                ImGui.PushStyleColor(ImGuiCol.Button, 0.42, 0.1, 0.09, 0.95)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.62, 0.15, 0.13, 1)
                local hit = ImGui.Button("STOP AUDIO##csl_au")
                ImGui.PopStyleColor(2)
                if hit then stopAudio() end
            else
                if ImGui.Button("PLAY AUDIO##csl_au") then playAudio(r) end
            end
            if ImGui.IsItemHovered() then ImGui.SetTooltip("Voice recording of this shard. It keeps playing while you browse.") end
            ImGui.SameLine(0, 6)
        end
    end
    if ImGui.Button("CLOSE##csl_dc") then
        S.selected, S.det = nil, nil
        return
    end
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    if d.enc then
        ImGui.PushStyleColor(ImGuiCol.Text, 1, 0.42, 0.38, 1)
        ImGui.TextWrapped("Encrypted. Crack it in the journal (Shards, Encrypted, Crack security); its text shows here after that.")
        ImGui.PopStyleColor(1)
        return
    end
    local paras = d.paras
    if #paras == 0 then
        ImGui.TextDisabled("(no text)")
        return
    end
    ImGui.PushStyleColor(ImGuiCol.Text, 0.82, 0.8, 0.76, 1)
    for i = 1, #paras do
        local p = paras[i]
        if p == "" then ImGui.Spacing() else ImGui.TextWrapped(p) end
    end
    ImGui.PopStyleColor(1)
end

local function reportError(where, err)
    local msg = tostring(err)
    S.errMsg = "Shard Log " .. where .. ": " .. msg
    if S.lastErr ~= msg then
        S.lastErr = msg
        logLine(where .. " error: " .. msg)
    end
end

local function listChild(w, h)
    if ImGui.BeginChild("##csl_list", w, h, false) then
        local ok, err = pcall(drawRows)
        if not ok then reportError("list", err) end
    end
    ImGui.EndChild()
end

local function detailsChild(w, h)
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.07, 0.05, 0.045, 0.9)
    if ImGui.BeginChild("##csl_det", w, h, true) then
        local ok, err = pcall(drawDetails)
        if not ok then reportError("reader", err) end
    end
    ImGui.EndChild()
    ImGui.PopStyleColor(1)
end

local function drawBody()
    local dl = ImGui.GetWindowDrawList()
    local lineH = ImGui.GetTextLineHeight()
    local chipH = math.floor(lineH + 14)
    drawHeader(dl, lineH, chipH)
    if S.errMsg then ImGui.TextColored(1, 0.35, 0.3, 1, S.errMsg) end
    if S.viewDirty then buildView() end
    ImGui.Spacing()
    local availW, availH = ImGui.GetContentRegionAvail()
    local footH = lineH + 6
    if availW >= WIDE then -- wide: reading pane always there, so the list never changes width under the mouse
        local lw = math.floor(availW * 0.45)
        listChild(lw, availH - footH)
        ImGui.SameLine(0, 10)
        detailsChild(0, availH - footH)
    elseif S.det then
        local dh = math.floor((availH - footH) * 0.55)
        listChild(0, availH - footH - dh - 8)
        detailsChild(0, dh)
    else
        listChild(0, availH - footH)
    end
    local a = S.audio
    if a then
        if ImGui.SmallButton("STOP##csl_as") then
            stopAudio()
        else
            ImGui.SameLine(0, 8)
            ImGui.TextColored(0.98, 0.83, 0.12, 1, a.label)
        end
    else
        ImGui.TextDisabled("Click a shard to read it. Times are game time since it went into the journal.")
    end
end

local function pushPalette()
    if not palFlat then
        palFlat = {}
        for _, e in ipairs(PAL) do
            local idx = ImGuiCol[e[1]]
            if idx then
                palFlat[#palFlat + 1] = idx
                palFlat[#palFlat + 1] = e[2] / 255
                palFlat[#palFlat + 1] = e[3] / 255
                palFlat[#palFlat + 1] = e[4] / 255
                palFlat[#palFlat + 1] = e[5]
            end
        end
    end
    for i = 1, #palFlat, 5 do
        ImGui.PushStyleColor(palFlat[i], palFlat[i + 1], palFlat[i + 2], palFlat[i + 3], palFlat[i + 4])
    end
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 6)
    return #palFlat / 5, 3
end

-- ---------------------------------------------------------------- events

registerForEvent("onInit", function()
    local ok, err = pcall(loadCfg)
    if not ok then logLine("config not read: " .. tostring(err)) end
    logLine("loaded " .. VERSION)
end)

registerForEvent("onOverlayOpen", function()
    S.overlay = true
    S.needFull = true
    S.nextPoll = 0
end)

registerForEvent("onOverlayClose", function()
    S.overlay = false
    if next(S.readNow) then
        S.readNow = {}
        S.viewDirty = true
    end
end)

registerForEvent("onDraw", function()
    if not S.overlay then return end
    local now = os.clock()
    if S.shown and now >= S.nextPoll then
        local ok, err = pcall(poll, now)
        if not ok then
            reportError("refresh", err)
            S.nextPoll = now + 5
        end
    end
    local nCol, nVar = pushPalette()
    ImGui.SetNextWindowSize(620, 720, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSizeConstraints(380, 300, 6000, 4000)
    local shown = ImGui.Begin("Shard Log##CyberslopShardLog", ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse)
    if shown and not S.shown then S.nextPoll = 0 end -- just expanded: check the journal next frame
    S.shown = shown and true or false
    if shown then
        local ok, err = pcall(drawBody)
        if not ok then reportError("draw", err) end
    end
    ImGui.End()
    ImGui.PopStyleVar(nVar)
    ImGui.PopStyleColor(nCol)
end)
