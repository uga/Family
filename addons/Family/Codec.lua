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

function Codec:ToWire(data)
    if not self:CanTalk() then
        return nil, "the serialisation libraries are not loaded"
    end

    local ok, encoded = pcall(function()
        local serialized = LibSerialize:Serialize(data)
        local compressed = LibDeflate:CompressDeflate(serialized, { level = 5 })
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
