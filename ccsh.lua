local args = {...}

local bExit = false
local format = "§f&0{:if shellFail then return '§e' else return '&9' end:}[@{:=os.computerID():}{:if shell.dir() ~= '' then return ' ' end:}{PATH}]§f&0 "
local issue = "§f&0&4{:=os.version():} + &9ccsh {:=ccsh.version:}§f&0"
local history = {}
local cols = {}

for i = 0, 15 do -- enums?
    cols[string.format("%x", i)] = 2^i
end

if not fs.exists(".ccsh") then
    fs.makeDir(".ccsh")
    fs.makeDir(".ccsh/bin")
end

if fs.exists(".ccsh/history") then
    for line in io.lines(".ccsh/history") do
        history[#history+1] = line
    end
end

if not fs.exists(".ccsh/format") then
    local f = fs.open(".ccsh/format", "w")
    f.write(format)
    f.close()
end

if not fs.exists(".ccsh/issue") then
    local f = fs.open(".ccsh/issue", "w")
    f.write(issue)
    f.close()
end

local function replace(str, i, j, r)
    return str:sub(1, i-1) .. tostring(r) .. str:sub(j+1)
end

local function writeStyle(style, env)
    env = env or getfenv()
    -- Parse variables
    style = style:gsub("{PATH}", shell.dir())
    style = style:gsub("{TIME}", textutils.formatTime(os.time()))
    style = style:gsub("{TIME24}", textutils.formatTime(os.time(), true))
    
    -- Execute Lua variables
    repeat
        local s, e = style:find("{:.-:}")
        if s then
            local code = style:sub(s+2, e-2)
            code = code:gsub("^=", "return ")
            local func, err = load(code, "=&e(ccsh lua)", "t", env)
            if func then
                local ok, ret = pcall(func)
                if not ok then
                    ret = "&d" .. tostring(ret)
                end
                style = replace(style, s, e, ret or "")
            else
                style = replace(style, s, e, err .. "&e")
            end
        end
    until not s
    
    local escaped = false
    local i = 1
    while i <= #style do
       local char = style:sub(i,i)
       if escaped then
           write(char)
           escaped = false
       elseif char == "&" then
           local col = style:sub(i+1, i+1)
           if cols[col] then
               term.setTextColor(cols[col])
           end
           i = i + 1
       elseif char == "\167" then
           local col = style:sub(i+1, i+1)
           if cols[col] then
                term.setBackgroundColor(cols[col])
           end
           i = i + 1
       elseif char == "\\" then
           escaped = true
       else
           write(char)
       end
       i = i+1
    end
end

local function parseCommand(str, tEnv)
    -- Execute Lua variables
    repeat
        local s, e = str:find("{:.-:}")
        if s then
            local code = str:sub(s+2, e-2)
            code = code:gsub("^=", "return ")
            local func, err = load(code, "=(ccsh lua)", "t", env)
            if func then
                local ok, ret = pcall(func)
                if not ok then
                    ret = tostring(ret)
                end
                str = replace(str, s, e, ret or "")
            else
                str = replace(str, s, e, err or "Unknown error")
            end
        end
    until not s
    return str
end

function shell.exit()
   bExit = true 
end

local tEnv = {
    shellFail = false,
    ccsh = {
        version = "0.1",
        args = args,
    }
}
setmetatable(tEnv, {__index=getfenv()})

local f = fs.open(".ccsh/format", "r")
format = f.readLine()
f.close()

local f = fs.open(".ccsh/issue", "r")
issue = f.readLine()
f.close()

shell.setPath(shell.path() .. ":/.ccsh/bin")

writeStyle(issue, tEnv)
print()

if args[1] then
    tEnv.shellFail = not shell.run(unpack(args))
else
    if fs.exists(".ccsh/rc") then
        for line in io.lines(".ccsh/rc") do
            local parsed = parseCommand(line)
            if line:match("%S") then
                tEnv.shellFail = not shell.run(parsed)
            end
        end
    end
end

while not bExit do
    writeStyle(format, tEnv)
    local input
    if settings.get("shell.autocomplete") then
        input = read(nil, history, shell.complete)
    else
        input = read(nil, history)
    end
    
    local parsed = parseCommand(input)
    
    if input:match("%S") then
        if history[#history] ~= input then
            table.insert(history, input)
            local f = fs.open("/.ccsh/history", "a")
            f.write(input .. "\n")
            f.close()
        end
    
        tEnv.shellFail = not shell.run(parsed)
    end
end
