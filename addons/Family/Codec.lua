-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Turning a member's bulky data into something small, and back again.
--
-- Every stored record says which codec wrote it. That costs one short string per member and
-- buys two things: the compressed path can be added, changed or dropped without invalidating
-- what is already on disk, and a client missing the libraries can still read records written
-- by one that had them - or say plainly that it cannot, which is the point of §2.2.
--
-- The libraries are optional on purpose. They are third-party, they are fetched from their
-- own upstreams rather than vendored (HANDOFF §2), and Family has to be developable and
-- runnable before somebody has done that. Without them "plain" is used: the table is handed
-- to the game's own saved-variables writer as a table. It stores and reads back correctly at
-- full size - the record is intact, and only the compression is missing.

local _, Family = ...

local Codec = {}
Family.Codec = Codec

local PLAIN = "plain"
local SERIALIZED = "ld1" -- LibSerialize, then LibDeflate, then a printable encoding

local LibSerialize, LibDeflate

function Codec:Initialise()
	if LibStub then
		LibSerialize = LibStub:GetLibrary("LibSerialize", true)
		LibDeflate = LibStub:GetLibrary("LibDeflate", true)
	end
	self.compressing = (LibSerialize and LibDeflate) and true or false
	return self.compressing
end

function Codec:Preferred()
	return self.compressing and SERIALIZED or PLAIN
end

-- Returns codec name, encoded value. Never raises: a member record that will not encode is
-- worth keeping in whatever form it is in, rather than losing the scan.
function Codec:Encode(data)
	if not self.compressing then
		return PLAIN, data
	end

	local ok, encoded = pcall(function()
		local serialized = LibSerialize:Serialize(data)
		local compressed = LibDeflate:CompressDeflate(serialized, { level = 5 })
		return LibDeflate:EncodeForPrint(compressed)
	end)

	if not ok or not encoded then
		Family:Debug("compression failed, storing plain: %s", tostring(encoded))
		return PLAIN, data
	end
	return SERIALIZED, encoded
end

-- Returns the data, or nil plus a reason. A reason is not a failure to hide: the caller
-- shows it, because "recorded by a version with libraries this client does not have" is a
-- true and useful thing to tell somebody.
function Codec:Decode(codec, value)
	if codec == nil or codec == PLAIN then
		return value
	end

	if codec == SERIALIZED then
		if not (LibSerialize and LibDeflate) then
			return nil, "compressed record, and the compression libraries are not loaded"
		end
		local ok, result = pcall(function()
			local compressed = LibDeflate:DecodeForPrint(value)
			if not compressed then return nil end
			local serialized = LibDeflate:DecompressDeflate(compressed)
			if not serialized then return nil end
			local success, data = LibSerialize:Deserialize(serialized)
			if not success then return nil end
			return data
		end)
		if not ok or result == nil then
			return nil, "record could not be decoded"
		end
		return result
	end

	return nil, "unknown codec " .. tostring(codec)
end

--------------------------------------------------------------------------------------------
-- The wire
--
-- Storage may fall back to handing the game a plain table, because the game's own saved
-- variables writer knows what to do with one. The addon channel does not: it carries a
-- string and nothing else, so Wide Family (§6) cannot work without the libraries and says so
-- rather than half-working.
--
-- Encoded for print, not for WoW's addon channel. The two differ - the channel-safe encoding
-- packs tighter - and the print one is chosen because it survives being cut into pieces and
-- glued back together in a way the other is not guaranteed to.
--------------------------------------------------------------------------------------------

function Codec:CanTalk()
    return (LibSerialize and LibDeflate) and true or false
end

-- A short mark that changes when the thing does, and does not otherwise.
--
-- For deciding whether something is worth sending again, and for nothing else. It is never sent:
-- each side works one out about its own data and compares it only against what it itself last
-- sent.
--
-- **Its own walk, with the keys sorted**, and that is the whole reason this is not three lines
-- over `LibSerialize:Serialize`. That library writes a table by walking `pairs`, and `pairs` has
-- no order: the thing being fingerprinted here is built fresh on every exchange, so two runs
-- over identical data can lay the keys out differently and produce two different strings. A mark
-- that changes when nothing has is a mark that never matches, and the saving it was written for
-- would quietly never happen. Written the first way and caught by its own check.
--
-- A number, folded over the keys and the leaves. A collision means one member's record is not
-- sent when it should have been, which the far side repairs by asking; paying for a real digest
-- of every member on every exchange to make that rarer is the wrong trade.
local FINGERPRINT_DEPTH = 12

local function fold(sum, text)
    for index = 1, #text do
        sum = (sum * 31 + text:byte(index)) % 4294967291
    end
    return sum
end

local function mark(sum, value, depth)
    local kind = type(value)

    if kind == "table" then
        if depth > FINGERPRINT_DEPTH then return fold(sum, "deep") end

        -- Sorted, so that the answer is about the data and not about how the table happens to
        -- be laid out. Keys of two types cannot be compared, so the type goes into the sort
        -- as well as into the fold.
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(a, b)
            local left, right = type(a), type(b)
            if left ~= right then return left < right end
            if left == "number" then return a < b end
            return tostring(a) < tostring(b)
        end)

        sum = fold(sum, "{")
        for _, key in ipairs(keys) do
            sum = fold(sum, type(key) .. ":" .. tostring(key) .. "=")
            sum = mark(sum, value[key], depth + 1)
        end
        return fold(sum, "}")
    end

    return fold(sum, kind .. ":" .. tostring(value))
end

function Codec:Fingerprint(data)
    return tostring(mark(0, data, 0))
end

-- `level` is deflate's, and it is the caller's business because the trade is theirs.
--
-- Measured 2026-09-08 on a bundle of seventy shared characters: level 5 costs 577 ms to pack
-- and 195 KB, level 1 costs 225 ms and 211 KB, level 9 costs 4.8 seconds and 174 KB. So the
-- step from 1 to 5 buys eight per cent of the bytes for two and a half times the work, and 9
-- is not a trade at all.
--
-- Five stays the default, because most of what crosses is small and packing it is not felt.
-- The one caller that asks for something else is a Wide Family exchange, where the body can be
-- hundreds of kilobytes and the client is a game: a fifth of a second matters there, and eight
-- per cent more of a transfer that takes minutes anyway does not. Nothing about the reader
-- changes - a deflate stream says how it was packed.
function Codec:ToWire(data, level)
    if not self:CanTalk() then
        return nil, "the serialisation libraries are not loaded"
    end

    local ok, encoded = pcall(function()
        local serialized = LibSerialize:Serialize(data)
        local compressed = LibDeflate:CompressDeflate(serialized,
            { level = tonumber(level) or 5 })
        return LibDeflate:EncodeForPrint(compressed)
    end)

    if not ok or not encoded then return nil, "could not be encoded" end
    return encoded
end

function Codec:FromWire(text)
    if not self:CanTalk() then
        return nil, "the serialisation libraries are not loaded"
    end
    if type(text) ~= "string" or text == "" then return nil, "nothing arrived" end

    -- Whatever arrives came from somebody else's client and may be any shape at all,
    -- including a version of Family that did not exist when this was written. It is decoded
    -- inside a pcall for the same reason a file from a stranger is: being wrong about it must
    -- not be fatal.
    local ok, result = pcall(function()
        local compressed = LibDeflate:DecodeForPrint(text)
        if not compressed then return nil end
        local serialized = LibDeflate:DecompressDeflate(compressed)
        if not serialized then return nil end
        local success, data = LibSerialize:Deserialize(serialized)
        if not success then return nil end
        return data
    end)

    if not ok or type(result) ~= "table" then return nil, "could not be decoded" end
    return result
end
