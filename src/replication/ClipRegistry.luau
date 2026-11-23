--!strict

const Clip = require("../Clip")
const Track = require("../Track")

type RegistryData = {
	Count: number,
	_clips: { Clip.Clip },
	_ids: { [string]: number },
	_options: { [string]: Track.TrackOptions },
}

const ClipRegistry = {}
ClipRegistry.__index = ClipRegistry

export type ClipRegistry = typeof(setmetatable({} :: RegistryData, ClipRegistry))

function ClipRegistry.New(clips: { Clip.Clip }, options: { [string]: Track.TrackOptions }?): ClipRegistry
	const sorted = table.clone(clips)
	table.sort(sorted, function(left: Clip.Clip, right: Clip.Clip)
		return left.Name < right.Name
	end)

	const ids: { [string]: number } = {}
	for index, clip in sorted do
		assert(ids[clip.Name] == nil, `Two clips share the name '{clip.Name}', replication needs unique names`)
		ids[clip.Name] = index
	end

	assert(#sorted <= 65535, "Too many clips for one registry")

	return setmetatable({
		Count = #sorted,
		_clips = sorted,
		_ids = ids,
		_options = options or {},
	}, ClipRegistry)
end

function ClipRegistry.GetId(self: ClipRegistry, clip: Clip.Clip | string): number?
	return self._ids[if type(clip) == "string" then clip else clip.Name]
end

function ClipRegistry.GetClip(self: ClipRegistry, id: number): Clip.Clip?
	return self._clips[id]
end

function ClipRegistry.GetOptions(self: ClipRegistry, clip: Clip.Clip): Track.TrackOptions?
	return self._options[clip.Name]
end

return ClipRegistry
