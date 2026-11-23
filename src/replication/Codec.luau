--!strict

--[[

                        ___                     
                       (   )                    
  .--.      .--.     .-.| |    .--.     .--.    
 /    \    /    \   /   \ |   /    \   /    \   
|  .-. ;  |  .-. ; |  .-. |  |  .-. ; |  .-. ;  
|  |(___) | |  | | | |  | |  |  | | | |  |(___) 
|  |      | |  | | | |  | |  |  |/  | |  |      
|  | ___  | |  | | | |  | |  |  ' _.' |  | ___  
|  '(   ) | '  | | | '  | |  |  .'.-. |  '(   ) 
'  `-' |  '  `-' / ' `-'  /  '  `-' / '  `-' |  
 `.__,'    `.__.'   `.__,'    `.__.'   `.__,'   
                                                                                         
   @MintyyWorks
   Notes: 
   - Idk if it wworks. on foenem 😭
]]

export type Op = "Play" | "Stop" | "StopAll" | "Pause" | "Resume" | "Seek" | "SetWeight" | "SetSpeed"

export type Command = {
	Op: Op,
	ClipId: number?,
	FadeTime: number?,
	Weight: number?,
	Speed: number?,
	StartTime: number?,
	Time: number?,
	Priority: number?,
	LoopMode: string?,
}

const VERSION = 1
const HEADER_SIZE = 11
const DEFAULT_PRIORITY = 127

const OP_CODES: { [string]: number } = {
	Play = 1,
	Stop = 2,
	StopAll = 3,
	Pause = 4,
	Resume = 5,
	Seek = 6,
	SetWeight = 7,
	SetSpeed = 8,
}

const OP_NAMES: { [number]: Op } = {
	[1] = "Play",
	[2] = "Stop",
	[3] = "StopAll",
	[4] = "Pause",
	[5] = "Resume",
	[6] = "Seek",
	[7] = "SetWeight",
	[8] = "SetSpeed",
}

const LOOP_CODES: { [string]: number } = {
	once = 1,
	clamp = 2,
	loop = 3,
	ping_pong = 4,
}

const LOOP_NAMES: { [number]: string } = {
	[1] = "once",
	[2] = "clamp",
	[3] = "loop",
	[4] = "ping_pong",
}

const PAYLOAD_SIZES: { [number]: number } = {
	[1] = 20,
	[2] = 6,
	[3] = 4,
	[4] = 2,
	[5] = 2,
	[6] = 6,
	[7] = 10,
	[8] = 10,
}

const Codec = {}

Codec.MaxCommands = 64

function Codec.Encode(commands: { Command }, timestamp: number): buffer
	assert(#commands <= 65535, "Too many commands in one batch")

	local size = HEADER_SIZE
	for _, command in commands do
		size += 1 + PAYLOAD_SIZES[OP_CODES[command.Op]]
	end

	const output = buffer.create(size)
	buffer.writeu8(output, 0, VERSION)
	buffer.writef64(output, 1, timestamp)
	buffer.writeu16(output, 9, #commands)

	local offset = HEADER_SIZE
	for _, command in commands do
		const code = OP_CODES[command.Op]
		buffer.writeu8(output, offset, code)
		offset += 1

		if code == 1 then
			buffer.writeu16(output, offset, command.ClipId or 0)
			buffer.writef32(output, offset + 2, command.FadeTime or 0)
			buffer.writef32(output, offset + 6, command.Weight or 1)
			buffer.writef32(output, offset + 10, command.Speed or 1)
			buffer.writef32(output, offset + 14, command.StartTime or -1)
			buffer.writeu8(output, offset + 18, if command.Priority then math.clamp(command.Priority, 0, DEFAULT_PRIORITY - 1) else DEFAULT_PRIORITY)
			buffer.writeu8(output, offset + 19, if command.LoopMode then LOOP_CODES[command.LoopMode] or 0 else 0)
		elseif code == 2 then
			buffer.writeu16(output, offset, command.ClipId or 0)
			buffer.writef32(output, offset + 2, command.FadeTime or 0)
		elseif code == 3 then
			buffer.writef32(output, offset, command.FadeTime or 0)
		elseif code == 4 or code == 5 then
			buffer.writeu16(output, offset, command.ClipId or 0)
		elseif code == 6 then
			buffer.writeu16(output, offset, command.ClipId or 0)
			buffer.writef32(output, offset + 2, command.Time or 0)
		else
			buffer.writeu16(output, offset, command.ClipId or 0)
			buffer.writef32(output, offset + 2, if code == 7 then command.Weight or 1 else command.Speed or 1)
			buffer.writef32(output, offset + 6, command.FadeTime or 0)
		end

		offset += PAYLOAD_SIZES[code]
	end

	return output
end

function Codec.Decode(input: buffer, maxClipId: number): (number?, { Command }?, string?)
	const length = buffer.len(input)
	if length < HEADER_SIZE then
		return nil, nil, "buffer too short"
	end

	if buffer.readu8(input, 0) ~= VERSION then
		return nil, nil, "unknown version"
	end

	const timestamp = buffer.readf64(input, 1)
	const count = buffer.readu16(input, 9)
	if count > Codec.MaxCommands then
		return nil, nil, "too many commands"
	end

	const commands: { Command } = {}
	local offset = HEADER_SIZE

	for _ = 1, count do
		if offset >= length then
			return nil, nil, "truncated"
		end

		const code = buffer.readu8(input, offset)
		const size = PAYLOAD_SIZES[code]
		const name = OP_NAMES[code]
		if not size or not name or offset + 1 + size > length then
			return nil, nil, "bad command"
		end

		offset += 1
		local command: Command = { Op = name }

		if code ~= 3 then
			const clipId = buffer.readu16(input, offset)
			if clipId < 1 or clipId > maxClipId then
				return nil, nil, "unknown clip"
			end

			command.ClipId = clipId
		end

		if code == 1 then
			const start = buffer.readf32(input, offset + 14)
			const priority = buffer.readu8(input, offset + 18)
			command.FadeTime = buffer.readf32(input, offset + 2)
			command.Weight = buffer.readf32(input, offset + 6)
			command.Speed = buffer.readf32(input, offset + 10)
			command.StartTime = if start < 0 then nil else start
			command.Priority = if priority == DEFAULT_PRIORITY then nil else priority
			command.LoopMode = LOOP_NAMES[buffer.readu8(input, offset + 19)]
		elseif code == 2 then
			command.FadeTime = buffer.readf32(input, offset + 2)
		elseif code == 3 then
			command.FadeTime = buffer.readf32(input, offset)
		elseif code == 6 then
			command.Time = buffer.readf32(input, offset + 2)
		elseif code == 7 then
			command.Weight = buffer.readf32(input, offset + 2)
			command.FadeTime = buffer.readf32(input, offset + 6)
		elseif code == 8 then
			command.Speed = buffer.readf32(input, offset + 2)
			command.FadeTime = buffer.readf32(input, offset + 6)
		end

		table.insert(commands, command)
		offset += size
	end

	return timestamp, commands, nil
end

return Codec
