local js = require "js"

-- Save references to lua baselib functions used
local _G = _G
local load = load
local pack, unpack, tinsert, tremove = table.pack, table.unpack, table.insert, table.remove
local tostring = tostring
local traceback = debug.traceback
local xpcall = xpcall

local document = js.global.document
local hljs = js.global.hljs

local output = document:getElementById("fengari-console")
local input = document:getElementById("fengari-input")
local inputContainer = document:getElementById("fengari-input-container")
local inputPrefix = document:getElementById("fengari-input-prefix")
assert(output and input and inputContainer and inputPrefix)

local function triggerEvent(el, type)
    local e = document:createEvent("HTMLEvents")
    e:initEvent(type, false, true)
    el:dispatchEvent(e)
end

local history = {}
local historyIndex = nil
local historyLimit = 100

local multilineInstruction

_G._print = _G.print

_G.print = function(...)
    local toprint = pack(...)

    local line = document:createElement("pre")
    line.style["white-space"] = "pre-wrap"
    inputContainer.parentNode:insertBefore(line, inputContainer);

    for i = 1, toprint.n do
        if i ~= 1 then
            line:appendChild(document:createTextNode("\t"))
        end
        line:appendChild(document:createTextNode(tostring(toprint[i])))
    end

    output.scrollTop = output.scrollHeight
end

local function doREPL()
    do
        local line = document:createElement("span")
        line:appendChild(document:createTextNode(multilineInstruction and "... " or "→ "))
        local item = document:createElement("pre")
        item.className = "lua"
        item.style.padding = "0"
        item.style.display = "inline"
        item.style["white-space"] = "pre-wrap"
        item.textContent = input.value
        hljs:highlightBlock(item)
        line:appendChild(item)
        inputContainer.parentNode:insertBefore(line, inputContainer);
        inputContainer.parentNode:insertBefore(document:createElement("br"), inputContainer);
        output.scrollTop = output.scrollHeight
    end

    if input.value.length == 0 then
        return
    end

    local line = multilineInstruction and multilineInstruction .. input.value or input.value

    if history[#history] ~= line then
        tinsert(history, line)
        if #history > historyLimit then
            tremove(history, 1)
        end
    end

    local fn, err = load("return " .. line, "stdin")
    if not fn then
        fn, err = load(line, "stdin")
    end

    if fn then
        inputPrefix.textContent = "→ "
        multilineInstruction = nil

        local results = pack(xpcall(fn, traceback))
        if results[1] then
            if results.n > 1 then
                _G.print(unpack(results, 2, results.n))
            end
        else
            _G.print(results[2])
        end
    else
        -- Syntax error near <eof>
        if err:match("<eof>") or (err and multilineInstruction) then
            multilineInstruction = line .. "\n"
            inputPrefix.textContent = "→> "
        else
            _G.print(err)
        end
    end

    input.value = ""

    triggerEvent(output, "change")
end

local function historyPrevious()
    if historyIndex then
        if historyIndex > 1 then
            historyIndex = historyIndex - 1
        end
    else -- start with more recent history item
        local hist_len = #history
        if hist_len > 0 then
            historyIndex = hist_len
        end
    end
    input.value = history[historyIndex]
end

local function historyNext()
    local newvalue = ""
    if historyIndex then
        if historyIndex < #history then
            historyIndex = historyIndex + 1
            newvalue = history[historyIndex]
        else -- no longer in history
            historyIndex = nil
        end
    end
    input.value = newvalue
end

function input:onkeydown(e)
    if not e then
        e = js.global.event
    end

    local key = e.key or e.which
    if key == "Enter" and not e.shiftKey then
        historyIndex = nil
        doREPL()
        return false
    elseif key == "ArrowUp" or key == "Up" then
        local firstNewLine = input.value:find("\n")
        if not firstNewLine or input.selectionStart < firstNewLine then
            historyPrevious()
            return false
        end
    elseif key == "ArrowDown" or key == "Down" then
        local lastNewline = input:len() - input.value:reverse():find("\n")
        if not lastNewline or input.selectionStart > lastNewline then
            historyNext()
            return false
        end
    elseif key == "l"
        and e.ctrlKey
        and not e.shiftKey
        and not e.altKey
        and not e.metaKey
        and not e.isComposing then
        -- Ctrl+L clears screen like you would expect in a terminal
        output.innerHTML = ""
        _G.print(_G._COPYRIGHT)
        return false
    end
end

input:focus()

_G.print(_G._COPYRIGHT)
