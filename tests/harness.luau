--!nocheck

type Case = { Name: string, Callback: () -> () }

const cases: { Case } = {}

const Harness = {}

function Harness.Test(name: string, callback: () -> ())
	table.insert(cases, { Name = name, Callback = callback })
end

function Harness.Run(filter: string?): boolean
	local passed = 0
	const failures = {}

	for _, case in cases do
		if filter and not string.find(case.Name, filter, 1, true) then
			continue
		end

		const success, message = xpcall(case.Callback, function(err)
			return debug.traceback(tostring(err), 2)
		end)

		if success then
			passed += 1
		else
			table.insert(failures, `FAIL {case.Name}\n{message}`)
		end
	end

	for _, failure in failures do
		print(failure)
	end

	print(`{passed} passed, {#failures} failed`)
	return #failures == 0
end

const Expect = {}

function Expect.Equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "values"} differ: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Expect.Near(actual: number, expected: number, epsilon: number?, label: string?)
	if math.abs(actual - expected) > (epsilon or 1e-5) then
		error(`{label or "numbers"} differ: expected {expected}, got {actual}`, 2)
	end
end

function Expect.VectorNear(actual: vector, expected: vector, epsilon: number?, label: string?)
	const limit = epsilon or 1e-5
	if math.abs(actual.x - expected.x) > limit or math.abs(actual.y - expected.y) > limit or math.abs(actual.z - expected.z) > limit then
		error(`{label or "vectors"} differ: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Expect.QuatNear(av: vector, aw: number, bv: vector, bw: number, epsilon: number?, label: string?)
	const dot = vector.dot(av, bv) + aw * bw
	if math.abs(math.abs(dot) - 1) > (epsilon or 1e-5) then
		error(`{label or "quaternions"} differ: ({tostring(av)}, {aw}) vs ({tostring(bv)}, {bw})`, 2)
	end
end

function Expect.CFrameNear(actual: CFrame, expected: CFrame, epsilon: number?, label: string?)
	if not actual:FuzzyEq(expected, epsilon or 1e-4) then
		error(`{label or "cframes"} differ: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Expect.True(value: any, label: string?)
	if not value then
		error(`{label or "value"} should be truthy`, 2)
	end
end

function Expect.False(value: any, label: string?)
	if value then
		error(`{label or "value"} should be falsy`, 2)
	end
end

function Expect.Throws(callback: () -> (), fragment: string?)
	const success, message = pcall(callback)
	if success then
		error("expected the call to throw", 2)
	end

	if fragment and not string.find(tostring(message), fragment, 1, true) then
		error(`error '{tostring(message)}' does not contain '{fragment}'`, 2)
	end
end

Harness.Expect = Expect

return Harness
