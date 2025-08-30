local debugMode = true
local repo = GetResourceMetadata(GetCurrentResourceName(), "github", 0) or "https://github.com/Appercy/VersionChecker"
local scriptname = GetResourceMetadata(GetCurrentResourceName(), "name", 0) or GetCurrentResourceName()
local currentversion = GetResourceMetadata(GetCurrentResourceName(), "version")

if not repo or not scriptname or not currentversion then
    print("^1Error: Missing metadata in fxmanifest.^0")
    return
end

local owner, repoName = repo:match("https://github.com/([^/]+)/([^/]+)")
if not owner or not repoName then
    print("^1Error: Invalid GitHub repository URL.^0")
    return
end

local function compareVersions(a, b)
    local aParts = {}
    local bParts = {}
    for part in string.gmatch(a, "[^%.]+") do table.insert(aParts, part) end
    for part in string.gmatch(b, "[^%.]+") do table.insert(bParts, part) end
    for i = 1, 3 do
        local numA = tonumber(aParts[i]) or 0
        local numB = tonumber(bParts[i]) or 0
        if numA > numB then return 1 elseif numA < numB then return -1 end
    end
    return 0
end

local function daysAgo(dateString)
    -- Assumes dateString is in ISO 8601 format: "YYYY-MM-DDTHH:MM:SSZ" or "YYYY-MM-DD"
    local year, month, day, hour, min, sec
    local patternFull = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)Z"
    local patternShort = "(%d+)%-(%d+)%-(%d+)"
    year, month, day, hour, min, sec = dateString:match(patternFull)
    if not year then
        year, month, day = dateString:match(patternShort)
        hour, min, sec = 0, 0, 0
    end
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    hour = tonumber(hour)
    min = tonumber(min)
    sec = tonumber(sec)
    if not (year and month and day and hour and min and sec) then return "" end

    local updateTime = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
    })
    local now = os.time()
    local diff = math.floor((now - updateTime) / (60 * 60 * 24))
    if diff <= 0 then return "Today" end
    return diff .. " days ago"
end

local function checkVersion()
    local url = "https://api.github.com/repos/" .. owner .. "/" .. repoName .. "/contents/" .. scriptname
    PerformHttpRequest(url, function(statusCode, response)
        if statusCode == 200 then
            local highestVersion, versionFiles = currentversion, {}
            local files = json.decode(response)

            if files and type(files) == "table" then
                for _, file in ipairs(files) do
                    local version = file.name:match("(%d+%.%d+%.%d+)%.json$")
                    if version then table.insert(versionFiles, version) end
                end

                for _, version in ipairs(versionFiles) do
                    if compareVersions(version, highestVersion) > 0 then highestVersion = version end
                end

                if compareVersions(highestVersion, currentversion) > 0 then
                    local updateUrl = "https://raw.githubusercontent.com/" .. owner .. "/" .. repoName .. "/main/" .. scriptname .. "/" .. highestVersion .. ".json"
                    PerformHttpRequest(updateUrl, function(updateStatusCode, updateResponse)
                        if updateStatusCode == 200 then
                            local data = json.decode(updateResponse)
                            if data then
                                print("^2==============================^0")
                                print("^2   Update Available! ^0")
                                print("^2==============================^0")
                                print("^4Script Name: ^0" .. scriptname)
                                print("^4Current Version: ^0" .. currentversion)
                                print("^4Latest Version: ^0" .. highestVersion)
                                print("^4Last Updated: ^0" .. daysAgo(data.date) .. " (" .. data.date .. ")")
                                print("^4Changelog: ^0" .. data.changelog)
                                print("^2==============================^0")
                            else
                                print("^1Error: Invalid update details format.^0")
                            end
                        else
                            print("^1Error: Failed to retrieve update details. HTTP Status Code: " .. updateStatusCode .. "^0")
                        end
                    end, "GET", "", {["Content-Type"] = "application/json"})
                else
                    print("^4[Appercy Updater]^0 | ^2You are using the latest version (" .. currentversion .. ") of " .. scriptname .. ".^0")
                end
            else
                print("^1Error: Invalid response format from directory listing.^0")
            end
        else
            print("^1Error: Failed to list directory contents. HTTP Status Code: " .. statusCode .. "^0")
        end
    end, "GET", "", {["Content-Type"] = "application/json"})
end

checkVersion()
