-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Wide Family, where the deciding is done.
--
-- The specification (§6) asks for a grid - members down one side, categories across the top,
-- individually tickable, with a visible count of what is currently shared - and that is what
-- this is. The shape is the point: a list of switches labelled "share possessions" would let
-- somebody agree to a thing without ever seeing the size of it, and a grid cannot be read
-- without seeing how many boxes are ticked.
--
-- Two things this panel is careful to say rather than imply:
--
--   **Nothing is shared until a box is ticked.** A new link shows an empty grid, and the
--   heading says so, because an empty grid and a grid nobody has scrolled to look at are the
--   same picture.
--
--   **The other side is somebody else's computer.** Family will not send what was not
--   granted, and asks the other end to forget what was withdrawn - but that last part is a
--   request to another program, not a lock. Saying so plainly is better than a padlock icon
--   that means less than it looks like.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 20
-- The member column. Narrow, because it holds one character's name and the word "Member",
-- and every pixel it does not need is a pixel the nine category columns do: "Possessions" and
-- "Reputations" are eleven letters each and they are what decides whether this grid fits.
local NAME_WIDTH = 92

-- The consent grid shares out the room it has, rather than assuming room it has not measured.
--
-- It was nine fixed columns of 74 beside a name column of 150, which is 816 pixels wide in a
-- list that is about 712. So Money - the ninth - was drawn off the end where nobody could tick
-- it, and Reputations was cut by the edge. The panel read as though money could not be shared
-- at all, which was not a decision anybody had taken; it was arithmetic.
local CELL_MIN = 58
local CELL_MAX = 92

-- Where the buttons on a row sit, said once.
--
-- A row's right-hand text ran the full width and the buttons were laid on top of it, so the
-- link rows read "sharing 1 member in 6 categori[Update now]h[Unlink]". Two numbers in two
-- places that had to agree and did not; now the room a row leaves is worked out from the
-- same geometry that puts the buttons there.
-- Between one column's heading and the next.
local COLUMN_GAP = 6

-- Where a borrowed member's name starts, clear of the tick box that makes them a sibling.
local SIBLING_INSET = 28

local BUTTON_W = 80
local BUTTON_GAP = 6
local BUTTON_NEAR = BUTTON_GAP
local BUTTON_FAR = BUTTON_NEAR + BUTTON_W + BUTTON_GAP
local BUTTON_ROOM = BUTTON_FAR + BUTTON_W + BUTTON_GAP

-- What a row's right-hand text clears normally: the scroll bar's own edge.
local RIGHT_INSET = 6

-- The grid narrows to fit, but only so far, and past that it would run off the end again
-- silently - which is exactly how this was missed the first time. So it says so, the way the
-- summary's column sets do, and the harness reads what it says.
--
-- Not a check that can be made at the time of drawing: by then the number of categories is
-- fixed, the window's width is fixed, and all that is left is to overlap or to complain.
Family:OnDatabaseReady("ui.wide.fit", function()
    local room = (UI.CONTENT_W or 0) - (UI.SCROLLBAR_W or 0)
    local needed = NAME_WIDTH + #Family.Wide.CATEGORIES * CELL_MIN

    if room > 0 and needed > room then
        Family:Print(L["|cffffaa00the wide family grid needs %d pixels for %d categories "
            .. "and a row is %d, so its last column is drawn off the end|r"],
            needed, #Family.Wide.CATEGORIES, room)
    end
end)

--------------------------------------------------------------------------------------------

local function linkList()
    local list = {}
    for id, link in pairs(Family.Wide:Links()) do
        list[#list + 1] = { id = id, link = link }
    end
    table.sort(list, function(a, b)
        return tostring(a.link.name) < tostring(b.link.name)
    end)
    return list
end

local function ourMembers()
    local list = {}
    for memberKey, entry in pairs(Family.Database:Members()) do
        list[#list + 1] = { key = memberKey, meta = entry.meta or {} }
    end
    table.sort(list, function(a, b)
        local levelA, levelB = a.meta.level or 0, b.meta.level or 0
        if levelA ~= levelB then return levelA > levelB end
        return tostring(a.meta.name or a.key) < tostring(b.meta.name or b.key)
    end)
    return list
end

--------------------------------------------------------------------------------------------

local function build(frame)
    local chosen                     -- which link's grid is open, by family id
    local rows, cells, buttons = {}, {}, {}

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 4, -4)
    title:SetText(L["Wide Family"])

    -- Asking. A character name, because that is what one player knows about another - the
    -- family id is Family's business and nobody should ever have to see one.
    local ask = CreateFrame("EditBox", "FamilyWideAsk", frame, "InputBoxTemplate")
    ask:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -8)
    ask:SetSize(180, 20)
    ask:SetAutoFocus(false)

    local askButton = CreateFrame("Button", "FamilyWideAskButton", frame,
        "UIPanelButtonTemplate")
    askButton:SetSize(110, 22)
    askButton:SetPoint("LEFT", ask, "RIGHT", 10, 0)
    askButton:SetText(L["Ask to link"])
    UI:FitButton(askButton, 110)

    local askNote = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    askNote:SetPoint("LEFT", askButton, "RIGHT", 10, 0)
    askNote:SetPoint("RIGHT", -8, 0)
    askNote:SetJustifyH("LEFT")
    askNote:SetText(L["They must be online, and running Family. Nothing is sent until they "
        .. "accept, and nothing is shared until you say what may be."])

    askButton:SetScript("OnClick", function()
        local name = (ask:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return end

        local ok, why = Family.Wide:RequestLink(name)
        if ok then
            Family:Print(L["Asked |cffffd700%s|r to link. Nothing has been sent."], name)
            ask:SetText("")
        else
            Family:Print(L["|cffffaa00Could not ask: %s|r"], tostring(why))
        end
        frame:Refresh()
    end)

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", ask, "BOTTOMLEFT", -2, -8)
    status:SetPoint("RIGHT", -8, 0)
    status:SetJustifyH("LEFT")

    -- Automatic exchange, which is a preference and lives beside the thing it governs
    -- rather than three panels away in Options.
    local auto = CreateFrame("CheckButton", "FamilyWideAuto", frame, "UICheckButtonTemplate")
    auto:SetSize(22, 22)
    auto:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 2, -4)
    auto:SetScript("OnClick", function(self)
        Family.Wide:SetAutoUpdate(self:GetChecked() and true or false)
        frame:Refresh()
    end)

    local autoLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    autoLabel:SetPoint("LEFT", auto, "RIGHT", 2, 0)
    autoLabel:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    autoLabel:SetJustifyH("LEFT")
    autoLabel:SetText(L["Exchange automatically when a linked family comes online"])

    -- What the switch above does *not* do, said where somebody reading the switch will see
    -- it.
    --
    -- "Automatically" invites the reading that Family keeps two families in step while both
    -- are played, and it does not: linked records are a snapshot, refreshed when asked, and
    -- §6 is deliberate about that. Coming online is the only moment it happens by itself, so
    -- anything either of you has done since then is waiting for somebody to press a button.
    -- Left unsaid, the panel is quietly promising a freshness it never has.
    local autoNote = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    autoNote:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 24, 0)
    autoNote:SetPoint("RIGHT", -8, 0)
    autoNote:SetJustifyH("LEFT")
    autoNote:SetText(L["That is the only time it happens on its own. What you each see of the "
        .. "other is as it was at the last exchange - click |cffffd700Update now|r on a "
        .. "family's line to bring it up to date."])

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", autoNote, "BOTTOMLEFT", -26, -8)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)

    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(1, 1)
    scroll:SetScrollChild(list)
    UI:MakeScrollable(scroll)

    ----------------------------------------------------------------------------------------

    local function row(index)
        local existing = rows[index]
        if existing then return existing end

        local r = CreateFrame("Button", nil, list)
        r:SetHeight(ROW)
        r.text = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        r.text:SetPoint("LEFT", 4, 0)
        r.text:SetJustifyH("LEFT")
        r.right = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        r.right:SetPoint("RIGHT", -RIGHT_INSET, 0)
        r.right:SetJustifyH("RIGHT")
        r.right:SetWidth(300)
        UI:NoWrap(r.text, r.right)

        r:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

        -- Behind the tick boxes and the buttons, which sit on top of it.
        --
        -- A row spans the full width of the list, so it lies underneath every Accept,
        -- Decline, Ask again and Forget on this panel. Nothing said which of the two was in
        -- front: they are siblings created from pools in whatever order the sections happened
        -- to need them, and the game breaks that tie by creation order. The first draw that
        -- needed a row the pool had not built yet - a link arriving where there had only been
        -- buttons - put that row in front of buttons built earlier, and every button under it
        -- went dead while still drawing perfectly. Said outright now rather than left to the
        -- order the pools grew in.
        r:SetFrameLevel(list:GetFrameLevel() + 1)
        rows[index] = r
        return r
    end

    local function cell(index)
        local existing = cells[index]
        if existing then return existing end

        local box = CreateFrame("CheckButton", nil, list, "UICheckButtonTemplate")
        box:SetSize(20, 20)
        box:SetFrameLevel(list:GetFrameLevel() + 3)
        cells[index] = box
        return box
    end

    local function actionButton(index)
        local existing = buttons[index]
        if existing then return existing end

        local button = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
        button:SetSize(BUTTON_W, 18)
        button:SetFrameLevel(list:GetFrameLevel() + 3)
        buttons[index] = button
        return button
    end

    ----------------------------------------------------------------------------------------

    function frame:Refresh()
        local usedRows, usedCells, usedButtons = 0, 0, 0
        local y = 0

        list:SetWidth(math.max(scroll:GetWidth(), 200))
        auto:SetChecked(Family.Wide:AutoUpdate())

        -- One number, read by the column headings and by the tick boxes under them, so the
        -- two cannot come to disagree about where a column is.
        local cellWidth = math.floor(
            (list:GetWidth() - NAME_WIDTH - RIGHT_INSET) / #Family.Wide.CATEGORIES)
        if cellWidth < CELL_MIN then cellWidth = CELL_MIN end
        if cellWidth > CELL_MAX then cellWidth = CELL_MAX end

        local function nextRow(height)
            usedRows = usedRows + 1
            local r = row(usedRows)
            r:SetHeight(height or ROW)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            -- Put back exactly the way row() built it.
            --
            -- These rows come from a pool, so every one of them arrives wearing whatever the
            -- last section did to it, and this had been resetting the two things somebody
            -- happened to notice rather than all of them. What that looked like on screen:
            -- the column headings of the consent grid still drawn across the sentence about
            -- siblings, because nothing ever hid them; and a borrowed member called
            -- "Grella of Grella-Thunder..." because the row had last been a grid member and
            -- kept its narrow name column. A pooled widget has no memory worth trusting, so
            -- the reset is the whole of what a row is, not the parts that caused trouble.
            r.text:ClearAllPoints()
            r.text:SetPoint("LEFT", 4, 0)
            r.text:SetWidth(0)
            r.text:SetJustifyH("LEFT")
            r.text:SetText("")
            r.right:ClearAllPoints()
            r.right:SetPoint("RIGHT", -RIGHT_INSET, 0)
            r.right:SetWidth(300)
            r.right:SetText("")
            UI:NoWrap(r.text, r.right)
            -- The grid's column headings live on the row that carries them, and a row that
            -- is no longer that one must not still be showing them.
            if r.columns then
                for _, heading in ipairs(r.columns) do heading:Hide() end
            end
            -- Nothing to click until somebody says otherwise, so it neither highlights under
            -- the cursor nor takes a click meant for what is drawn over it. Most rows here
            -- are headings and explanations, which have been offering a highlight that led
            -- nowhere.
            r:SetScript("OnClick", nil)
            r:EnableMouse(false)
            r:Show()
            y = y + (height or ROW)
            return r
        end

        local function nextButton(label, at, onClick)
            usedButtons = usedButtons + 1
            local button = actionButton(usedButtons)
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", list, "TOPRIGHT", -at, -(y - ROW) - 1)
            button:SetText(label)
            button:SetScript("OnClick", onClick)
            button:Show()
            return button
        end

        ------------------------------------------------------------------------------------
        -- A client that cannot talk at all
        ------------------------------------------------------------------------------------

        if not Family.Codec:CanTalk() then
            -- Said outright rather than left as a link that never works. §2.2 applies to
            -- Family's own abilities as much as to its records.
            status:SetText(L["|cffffaa00Wide Family needs the serialisation libraries "
                .. "(LibSerialize and LibDeflate) and this client has neither loaded, so "
                .. "nothing can be sent or received.|r"])
            for index = 1, #rows do rows[index]:Hide() end
            for index = 1, #cells do cells[index]:Hide() end
            for index = 1, #buttons do buttons[index]:Hide() end
            list:SetHeight(1)
            return
        end

        ------------------------------------------------------------------------------------
        -- Somebody asking
        ------------------------------------------------------------------------------------

        local requests = Family.Wide:Requests()
        local waiting = 0
        for _ in pairs(requests) do waiting = waiting + 1 end

        if waiting > 0 then
            local heading = nextRow()
            heading.text:SetText(L["|cffffd700Waiting for you to answer|r"])
            y = y + 2

            for familyID, request in pairs(requests) do
                local r = nextRow()
                r.text:SetText(string.format(L["%s |cff888888asked %s|r"],
                    tostring(request.from), UI:Ago(request.at)))

                nextButton(L["Accept"], BUTTON_FAR, function()
                    Family.Wide:Accept(familyID)
                    frame:Refresh()
                end)
                nextButton(L["Decline"], BUTTON_NEAR, function()
                    Family.Wide:Decline(familyID)
                    frame:Refresh()
                end)
            end

            y = y + 10
        end

        ------------------------------------------------------------------------------------
        -- Whom we have asked, and have not heard back from
        --
        -- Shown because nothing else would be. A request that was never delivered produces no
        -- error and no reply - the addon channel acknowledges nothing (§11.1) - so without
        -- this the panel after asking looks exactly like the panel before asking, and the
        -- player is left to guess which one they are looking at.
        ------------------------------------------------------------------------------------

        local outgoing = Family.Wide:Outgoing()

        if #outgoing > 0 then
            local heading = nextRow()
            heading.text:SetText(L["|cffffd700Waiting for them to answer|r"])
            y = y + 2

            local anyUnanswered = false

            for _, ask in ipairs(outgoing) do
                local r = nextRow()
                r.text:SetText(string.format(L["%s |cff888888asked %s|r%s"],
                    ask.name, UI:Ago(ask.at),
                    ask.unanswered and L["   |cffffaa00no answer|r"] or ""))

                if ask.unanswered then anyUnanswered = true end

                nextButton(L["Ask again"], BUTTON_FAR, function()
                    Family.Wide:RequestLink(ask.name)
                    frame:Refresh()
                end)
                nextButton(L["Forget"], BUTTON_NEAR, function()
                    Family.Wide:Forget(ask.name)
                    frame:Refresh()
                end)
            end

            -- Three possibilities and no way to tell them apart from here, so all three are
            -- named rather than one being guessed at. The third is the one no addon can do
            -- anything about, and a player is better told than left retrying.
            if anyUnanswered then
                y = y + 6
                for _, line in ipairs({
                    L["|cff9d9d9dA request that does not arrive says nothing at all. "
                        .. "No answer means one of three things:|r"],
                    L["|cff9d9d9d   - they are offline, or not running Family|r"],
                    L["|cff9d9d9d   - their Family is too old to know how to answer|r"],
                    L["|cff9d9d9d   - the two of you cannot exchange addon messages at all, "
                        .. "which no addon can work around|r"],
                }) do
                    nextRow().text:SetText(line)
                end
            end

            y = y + 10
        end

        ------------------------------------------------------------------------------------
        -- The links
        ------------------------------------------------------------------------------------

        local links = linkList()

        if #links == 0 and #outgoing > 0 then
            status:SetText(string.format(#outgoing == 1
                and L["|cff9d9d9dNo families are linked yet. %d request sent and not "
                    .. "answered - a link exists only once they accept.|r"]
                or L["|cff9d9d9dNo families are linked yet. %d requests sent and not "
                    .. "answered - a link exists only once they accept.|r"], #outgoing))
        elseif #links == 0 then
            status:SetText(L["|cff9d9d9dNo families are linked. Type a character name above "
                .. "and ask - they will be asked to accept, and nothing is sent before "
                .. "they do.|r"])
        else
            local shared, boxes = 0, 0
            for _, entry in ipairs(links) do
                local members, grants = Family.Wide:CountGranted(entry.id)
                shared = shared + members
                boxes = boxes + grants
            end
            -- Three counts, three plurals, and no language forms all three the same way -
            -- so each is a whole clause of its own rather than a stem with a letter added.
            status:SetText(string.format(
                L["%s   |cff888888|||r   you are sharing %s across %s"],
                string.format(#links == 1 and L["|cffffd700%d|r linked family"]
                    or L["|cffffd700%d|r linked families"], #links),
                string.format(shared == 1 and L["|cffffd700%d|r member"]
                    or L["|cffffd700%d|r members"], shared),
                string.format(boxes == 1 and L["|cffffd700%d|r category"]
                    or L["|cffffd700%d|r categories"], boxes)))
        end

        ------------------------------------------------------------------------------------
        -- One family, one entry
        --
        -- This used to be two: the family's own line with the grid of what they may see, and
        -- a separate list at the foot of the panel of everyone every family shares with us.
        -- But a link is one family. Splitting it put the two halves of one relationship in
        -- two places, made the second one grow a column saying which family each row belonged
        -- to - a question that cannot arise once the rows are under the family - and left
        -- both halves fighting for the width of a row.
        --
        -- So: a line per family, and everything about that family underneath it when it is
        -- opened. What they may see of ours, then what they share of theirs.
        ------------------------------------------------------------------------------------

        -- The columns of both grids start here, so the two can be read against each other.
        local function columnHeadings(row, onClick, tip)
            row.columns = row.columns or {}

            for index, category in ipairs(Family.Wide.CATEGORIES) do
                local heading = row.columns[index]

                if not heading then
                    heading = CreateFrame("Button", nil, row)
                    heading:SetHeight(ROW - 4)
                    heading.text = heading:CreateFontString(nil, "ARTWORK",
                        "GameFontNormalSmall")
                    heading.text:SetAllPoints(heading)
                    heading.text:SetJustifyH("LEFT")
                    UI:NoWrap(heading.text)
                    heading:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
                    -- In front of the row it sits on, for the same reason every other
                    -- clickable thing in this list is.
                    heading:SetFrameLevel(list:GetFrameLevel() + 3)
                    row.columns[index] = heading
                end

                heading:ClearAllPoints()
                heading:SetPoint("LEFT", NAME_WIDTH + (index - 1) * cellWidth, 0)
                -- A gap, so that two long names - Possessions beside Equipment - are read
                -- as two words rather than one. The tick boxes keep the full column,
                -- because they are what the column is for.
                heading:SetWidth(cellWidth - COLUMN_GAP)
                heading.text:SetText((onClick and "|cffffd700" or "|cff9d9d9d")
                    .. category.label .. "|r")

                -- Lines of our own rather than an id for the client to describe: a
                -- category is Family's own idea and the game has never heard of it.
                UI:AttachTooltip(heading, function()
                    return nil, nil, { { category.label }, { tip(category) } }
                end)

                heading:SetScript("OnClick", onClick and function()
                    onClick(category)
                end or nil)
                heading:EnableMouse(true)
                heading:Show()
            end
        end

        for _, entry in ipairs(links) do
            local link = entry.link
            local members, grants = Family.Wide:CountGranted(entry.id)
            local open = (chosen == entry.id)

            local theirs = {}
            for _, member in ipairs(Family.Wide:BorrowedMembers()) do
                if member.family == entry.id then theirs[#theirs + 1] = member end
            end

            local r = nextRow(ROW + 2)
            r.text:SetText(string.format("|cffffd700%s|r  |cff66bbff%s|r  |cff888888%s|r",
                open and "-" or "+", tostring(link.name),
                link.version and string.format(L["Family %s"], tostring(link.version))
                    or L["version unknown"]))

            r:EnableMouse(true)
            r:SetScript("OnClick", function()
                chosen = (chosen ~= entry.id) and entry.id or nil
                frame:Refresh()
            end)

            nextButton(L["Update now"], BUTTON_FAR, function()
                local ok, count = Family.Wide:ExchangeWith(entry.id, "asked for")
                Family:Print(ok and L["Sent %d member(s) and asked for theirs."]
                    or L["Could not: %s"], count)
                frame:Refresh()
            end)

            nextButton(L["Unlink"], BUTTON_NEAR, function()
                UI:Confirm(string.format(L["End the link with %s?\n\nWhat they have shared "
                    .. "with you is forgotten here, and they are asked to forget what you "
                    .. "shared with them."], tostring(link.name)), function()
                    Family.Wide:Unlink(entry.id)
                    frame:Refresh()
                end)
            end)

            -- The state of the link, on a line of its own under the name.
            --
            -- It was on the same line, to the right, where it had to share the row with two
            -- buttons - so "last exchange 24 minutes ago" was cut to "last exchange 24...",
            -- losing the only part of it that carries the fact. A row with buttons on it has
            -- less width than a row without, and this needs the full width, so it gets a row
            -- without.
            local state = nextRow()
            state.text:SetPoint("RIGHT", -RIGHT_INSET, 0)
            state.text:SetText(link.problem
                and ("|cffffaa00" .. link.problem .. "|r")
                or string.format(
                    L["|cff888888you share %s in %s   |||   they share %d with you"
                    .. "   |||   last exchange %s%s|r"],
                    string.format(members == 1 and L["%d member"] or L["%d members"],
                        members),
                    string.format(grants == 1 and L["%d category"] or L["%d categories"],
                        grants),
                    #theirs,
                    link.lastExchange and UI:Ago(link.lastExchange) or L["never"],
                    open and "" or L["   |||   click the name to open"]))

            if open then
                y = y + 8

                ----------------------------------------------------------------------------
                -- What they may see of ours
                ----------------------------------------------------------------------------

                local mine = nextRow()
                mine.text:SetText(string.format(
                    L["|cffffd700What %s may see of your characters|r"],
                    tostring(link.name)))

                local explain = nextRow(ROW * 2)
                explain.text:SetPoint("RIGHT", -RIGHT_INSET, 0)
                explain.text:SetWordWrap(true)
                explain.text:SetText(L["|cff888888Nothing is ticked to begin with, and "
                    .. "unticking tells them to forget it. Click a category's name to tick "
                    .. "or clear that column for everybody at once.|r"])

                local everyMember = ourMembers()

                local labels = nextRow()
                labels.text:SetText(L["|cffffd700Member|r"])
                columnHeadings(labels, function(category)
                    local keys, allOn = {}, true
                    for _, member in ipairs(everyMember) do
                        keys[#keys + 1] = member.key
                        if not Family.Wide:Granted(entry.id, member.key, category.id) then
                            allOn = false
                        end
                    end
                    Family.Wide:GrantMany(entry.id, keys, category.id, not allOn)
                    frame:Refresh()
                end, function()
                    return string.format(#everyMember == 1
                        and L["|cff9d9d9dClick to tick or clear this column for all "
                            .. "%d member.|r"]
                        or L["|cff9d9d9dClick to tick or clear this column for all "
                            .. "%d members.|r"], #everyMember)
                end)

                for _, member in ipairs(everyMember) do
                    local memberRow = nextRow()
                    local red, green, blue = UI:ClassColour(member.meta.classFile)
                    memberRow.text:SetText(string.format("|cff%02x%02x%02x%s|r",
                        red * 255, green * 255, blue * 255,
                        member.meta.name or member.key))
                    memberRow.text:SetWidth(NAME_WIDTH - 8)

                    for index, category in ipairs(Family.Wide.CATEGORIES) do
                        usedCells = usedCells + 1
                        local box = cell(usedCells)
                        box:ClearAllPoints()
                        box:SetPoint("TOPLEFT", list, "TOPLEFT",
                            NAME_WIDTH + (index - 1) * cellWidth, -(y - ROW))
                        box:Enable()
                        box:SetChecked(
                            Family.Wide:Granted(entry.id, member.key, category.id))
                        box:SetScript("OnClick", function(self)
                            Family.Wide:Grant(entry.id, member.key, category.id,
                                self:GetChecked() and true or false)
                            frame:Refresh()
                        end)
                        box:Show()
                    end
                end

                ----------------------------------------------------------------------------
                -- What they share with us
                ----------------------------------------------------------------------------

                y = y + 12

                local ours = nextRow()
                ours.text:SetText(string.format(L["|cffffd700What %s shares with you|r"],
                    tostring(link.name)))

                if #theirs == 0 then
                    -- Said, rather than left as an empty space under a heading. Nothing
                    -- being shared and nothing having arrived yet look identical from here
                    -- and both are worth telling somebody about.
                    local none = nextRow()
                    none.text:SetText(L["|cff9d9d9dNothing yet. They choose this from their "
                        .. "own Wide Family panel, and it arrives at the next exchange.|r"])
                else
                    local why = nextRow(ROW * 2)
                    why.text:SetPoint("RIGHT", -RIGHT_INSET, 0)
                    why.text:SetWordWrap(true)
                    why.text:SetText(L["|cff888888The marks are what they share about each "
                        .. "one - theirs to change, not yours. Tick |cffffd700Sibling|r to "
                        .. "put one in your own summary, under their family, on the realm "
                        .. "they are on. That sends nothing: they have already shared "
                        .. "them.|r"])

                    local theirLabels = nextRow()
                    theirLabels.text:ClearAllPoints()
                    -- From the row's left edge, because the first word labels the tick box
                    -- at x=2 rather than the names at SIBLING_INSET, and bounded so that it
                    -- cannot reach the first column heading. nextRow gives a fresh row a
                    -- width of 0, which is a font string that grows as far as its text
                    -- needs - and "Sibling   Member" needed further than NAME_WIDTH, so it
                    -- was drawn straight through Possessions. The member rows below have
                    -- always been bounded; this row was the one that was not.
                    theirLabels.text:SetPoint("LEFT", 4, 0)
                    theirLabels.text:SetWidth(NAME_WIDTH - 4 - COLUMN_GAP)
                    theirLabels.text:SetText(L["|cffffd700Sibling  Member|r"])
                    columnHeadings(theirLabels, nil, function(category)
                        return L["|cff9d9d9dWhether they share this. Their decision, "
                            .. "taken on their own panel.|r"]
                    end)

                    for _, member in ipairs(theirs) do
                        local memberRow = nextRow()
                        local red, green, blue = UI:ClassColour(member.meta.classFile)

                        memberRow.text:ClearAllPoints()
                        memberRow.text:SetPoint("LEFT", SIBLING_INSET, 0)
                        memberRow.text:SetWidth(NAME_WIDTH - SIBLING_INSET - 4)
                        memberRow.text:SetText(string.format("|cff%02x%02x%02x%s|r",
                            red * 255, green * 255, blue * 255,
                            member.meta.name or member.key))

                        -- Their level and how old this is, on hover rather than across the
                        -- row. Written along the row it was drawn straight over the marks,
                        -- because the marks reach the right-hand edge and a right-aligned
                        -- caption starts wherever it likes.
                        UI:AttachTooltip(memberRow, function()
                            return nil, nil, {
                                { member.meta.name or member.key,
                                    string.format(L["|cff888888level %s|r"],
                                        tostring(member.meta.level or "?")) },
                                { string.format(L["|cff9d9d9das of %s|r"],
                                    member.seen and UI:Ago(member.seen) or L["unknown"]) },
                                { member.toldUs
                                    and L["|cff9d9d9dThey say which categories they "
                                        .. "share.|r"]
                                    or L["|cffffaa00Their Family is too old to say what it "
                                        .. "grants, so the marks are what has arrived.|r"] },
                            }
                        end)

                        for index, category in ipairs(Family.Wide.CATEGORIES) do
                            usedCells = usedCells + 1
                            local mark = cell(usedCells)
                            mark:ClearAllPoints()
                            mark:SetPoint("TOPLEFT", list, "TOPLEFT",
                                NAME_WIDTH + (index - 1) * cellWidth, -(y - ROW))
                            mark:SetChecked(
                                (member.received or {})[category.id] and true or false)
                            -- Reported, not offered. The game greys a disabled box, which
                            -- says "a state, not a switch" without a word being written.
                            mark:SetScript("OnClick", nil)
                            mark:Disable()
                            mark:Show()
                        end

                        usedCells = usedCells + 1
                        local box = cell(usedCells)
                        box:ClearAllPoints()
                        box:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -(y - ROW))
                        -- Enabled again: these come from the same pool as the greyed marks
                        -- beside them, and a box that was one of those is still disabled.
                        box:Enable()
                        box:SetChecked(member.sibling and true or false)
                        box:SetScript("OnClick", function(self)
                            Family.Wide:SetSibling(member.family, member.key,
                                self:GetChecked() and true or false)
                            frame:Refresh()
                            -- The summary is the screen this changes, and usually the one
                            -- that was open a moment ago.
                            if UI.UpdateBroker then UI:UpdateBroker() end
                        end)
                        box:Show()
                    end
                end

                y = y + 10
            end
        end

        -- Under the families, because it is about what ticking one of their boxes does and
        -- what unticking one can and cannot promise.
        if #links > 0 then
            y = y + 10
            local note = nextRow(ROW * 2)
            note.text:SetPoint("RIGHT", -RIGHT_INSET, 0)
            note.text:SetJustifyH("LEFT")
            note.text:SetWordWrap(true)
            note.text:SetText(L["|cff888888Family sends only what is ticked, and asks the "
                .. "other side to forget anything you untick. That last part is a request "
                .. "to another copy of Family on somebody else's computer - it is a promise "
                .. "kept honestly here, not a lock.|r"])
            y = y + 6
        end

        ------------------------------------------------------------------------------------

        for index = usedRows + 1, #rows do rows[index]:Hide() end
        for index = usedCells + 1, #cells do cells[index]:Hide() end
        for index = usedButtons + 1, #buttons do buttons[index]:Hide() end
        list:SetHeight(math.max(y, 1))
    end
end

-- The tab exists only where the feature does. Registered inside OnDatabaseReady because the
-- answer lives in saved data: by the time Family_UI's files run, Family's own ADDON_LOADED
-- has been and gone, so in the game this runs at once and the tab keeps its place in the
-- strip. Turning the feature on therefore wants a /reload, which is what the slash command
-- says.
--
-- Not a tab that says "unavailable": a panel advertising an untested consent feature invites
-- exactly the use it is being withheld from.
Family:OnDatabaseReady("ui.wide", function()
    if Family.Wide:Enabled() then
        UI:RegisterTab("wide", L["Wide Family"], build)
    end
end)
