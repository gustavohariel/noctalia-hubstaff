-- Hubstaff bar widget for Noctalia v5 (scripted-widget API).
--
-- Install:
--   cp hubstaff.lua hubstaff-window.sh ~/.config/noctalia/scripts/
--   chmod +x ~/.config/noctalia/scripts/hubstaff-window.sh
--
-- Register in noctalia config (TOML):
--   [widget.hubstaff]
--   type   = "scripted"
--   script = "~/.config/noctalia/scripts/hubstaff.lua"
--   hot_reload = true
--
-- Settings (cliPath, clientPath, windowScript, refreshIntervalSec) are
-- exposed through Noctalia's settings UI via the manifest below.
--
-- Differences from the v4 plugin:
--   * No popup panel — v5 scripted widgets are bar-only. Use clicks for
--     control: left = start/stop, right = toggle Hubstaff window.
--   * No Settings.qml — settings are declared in `barWidget.define`.
--   * JSON parsing happens in a `jq` pipeline because Luau has no JSON
--     helper and the v5 runtime is async-only.

barWidget.define({
    label = "Hubstaff",
    icon = "clock",
    description = "Hubstaff timer in the bar with Start/Stop controls.",
    pickable = true,
    settings = {
        { key = "cliPath", type = "string", label = "Hubstaff CLI path",
          default = "/home/realgh/Hubstaff/HubstaffCLI.bin.x86_64" },
        { key = "clientPath", type = "string", label = "Hubstaff client path",
          default = "/home/realgh/Hubstaff/HubstaffClient.bin.x86_64" },
        { key = "windowScript", type = "string",
          label = "Window helper script (hubstaff-window.sh)",
          default = "~/.config/noctalia/scripts/hubstaff-window.sh" },
        { key = "refreshIntervalSec", type = "int",
          label = "Poll interval (seconds)",
          default = 5, min = 2, max = 60 },
    },
})

-- ----- state -----
local hubstaffRunning = false
local isRunning = false
local projectName = ""
local trackedTodaySec = 0     -- server-reported tracked_today at last anchor
local baseEpoch = 0           -- os.time() when trackedTodaySec was anchored
local lastPollEpoch = 0
local pollInflight = false
local lastError = ""

-- ----- helpers -----

local function shq(s)
    return "'" .. (s or ""):gsub("'", "'\\''") .. "'"
end

local function expand(path)
    if not path or path == "" then return "" end
    if path:sub(1, 2) == "~/" then
        local home = noctalia.getenv("HOME") or ""
        return home .. path:sub(2)
    end
    return path
end

local function split(str, sep)
    local out, last = {}, 1
    while true do
        local i, j = str:find(sep, last, true)
        if not i then
            table.insert(out, str:sub(last))
            return out
        end
        table.insert(out, str:sub(last, i - 1))
        last = j + 1
    end
end

local function parseHMS(s)
    local parts = split(s or "", ":")
    local h, m, sec = 0, 0, 0
    if #parts == 3 then
        h = tonumber(parts[1]) or 0
        m = tonumber(parts[2]) or 0
        sec = tonumber(parts[3]) or 0
    elseif #parts == 2 then
        m = tonumber(parts[1]) or 0
        sec = tonumber(parts[2]) or 0
    elseif #parts == 1 then
        sec = tonumber(parts[1]) or 0
    end
    return h * 3600 + m * 60 + sec
end

local function formatHMS(total)
    if total < 0 then total = 0 end
    local h = math.floor(total / 3600)
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
    return string.format("%d:%02d:%02d", h, m, s)
end

local function elapsedSeconds()
    if not isRunning then return trackedTodaySec end
    local delta = os.time() - baseEpoch
    if delta < 0 then delta = 0 end
    return trackedTodaySec + delta
end

local function render()
    if not hubstaffRunning then
        barWidget.setVisible(false)
        return
    end
    barWidget.setVisible(true)
    barWidget.setGlyph(isRunning and "stop" or "media-play")
    barWidget.setGlyphColor(isRunning and "primary" or "onSurfaceVariant")
    barWidget.setText(formatHMS(elapsedSeconds()))
end

-- ----- CLI calls -----

local function pollStatus()
    if pollInflight then return end
    local cli = expand(barWidget.getConfig("cliPath", ""))
    if cli == "" then
        lastError = "CLI path not set"
        hubstaffRunning = false
        return
    end
    pollInflight = true
    -- jq distills the JSON into a tab-delimited record so we don't have to
    -- parse JSON from Luau. Format:
    --   OK\t<tracking-bool>\t<project-name>\t<tracked-today-HMS>
    --   ERR\t<message>
    -- Empty stdout (e.g. jq missing, CLI crashed) is treated as "daemon down".
    local jq = [[jq -r 'if .error then "ERR\t" + .error ]]
            .. [[else "OK\t" + (.tracking|tostring) + "\t" ]]
            .. [[+ (.active_project.name // "") + "\t" ]]
            .. [[+ (.active_project.tracked_today // "0:00:00") end' 2>/dev/null]]
    local pipeline = shq(cli) .. " status 2>/dev/null | " .. jq
    noctalia.runAsync("sh -c " .. shq(pipeline), function(r)
        pollInflight = false
        lastPollEpoch = os.time()
        local out = ((r and r.stdout) or ""):gsub("%s+$", "")
        if out == "" then
            hubstaffRunning = false
            isRunning = false
            projectName = ""
            trackedTodaySec = 0
            lastError = ""
            return
        end
        local parts = split(out, "\t")
        local kind = parts[1]
        if kind == "ERR" then
            local err = parts[2] or ""
            if err:find("Could not connect", 1, true) then
                -- Daemon down → tear down and hide the widget.
                hubstaffRunning = false
                isRunning = false
                projectName = ""
                trackedTodaySec = 0
                lastError = ""
            else
                -- Daemon up but timer can't report (e.g. signed out). Stay
                -- visible so the user can open the window from the bar.
                hubstaffRunning = true
                isRunning = false
                projectName = ""
                trackedTodaySec = 0
                if err ~= lastError then
                    noctalia.notifyError("Hubstaff", err)
                end
                lastError = err
            end
            return
        elseif kind == "OK" then
            hubstaffRunning = true
            local newRunning = (parts[2] == "true")
            projectName = parts[3] or ""
            local newSec = parseHMS(parts[4] or "0:00:00")
            local projected = elapsedSeconds()
            local stateChanged = newRunning ~= isRunning
            local drift = math.abs(newSec - projected)
            -- Re-anchor sparingly: only on first load, state change, while
            -- stopped, or when display has drifted >2s from the server.
            -- Re-anchoring on every poll causes visible "tick stalls".
            local shouldAnchor = baseEpoch == 0
                or stateChanged
                or not newRunning
                or drift > 2
            isRunning = newRunning
            if shouldAnchor then
                trackedTodaySec = newSec
                baseEpoch = os.time()
            end
            lastError = ""
        end
    end)
end

local function actionStart()
    local cli = expand(barWidget.getConfig("cliPath", ""))
    if cli == "" then return end
    noctalia.runAsync(shq(cli) .. " resume", function(_)
        pollStatus()
    end)
end

local function actionStop()
    local cli = expand(barWidget.getConfig("cliPath", ""))
    if cli == "" then return end
    noctalia.runAsync(shq(cli) .. " stop", function(_)
        pollStatus()
    end)
end

local function actionToggleWindow()
    local script = expand(barWidget.getConfig("windowScript", ""))
    local client = expand(barWidget.getConfig("clientPath", ""))
    if script == "" or client == "" then
        noctalia.notifyError("Hubstaff", "Window script or client path not set")
        return
    end
    noctalia.runAsync("sh " .. shq(script) .. " state", function(r)
        local state = ((r and r.stdout) or ""):gsub("%s+$", "")
        if state == "tiling" then
            noctalia.runAsync("sh " .. shq(script) .. " hide")
        else
            noctalia.runAsync("sh " .. shq(script) .. " open " .. shq(client))
        end
    end)
end

-- ----- framework callbacks -----

function update()
    local now = os.time()
    local interval = barWidget.getConfig("refreshIntervalSec", 5)
    if interval < 2 then interval = 2 end
    if now - lastPollEpoch >= interval then
        pollStatus()
    end
    render()
end

function onClick()
    if not hubstaffRunning then return end
    if isRunning then actionStop() else actionStart() end
end

function onRightClick()
    actionToggleWindow()
end
