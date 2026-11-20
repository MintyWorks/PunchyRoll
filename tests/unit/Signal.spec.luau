--!nocheck

const Harness = require("@tests/harness")
const Signal = require("@src/Signal")

const Test, Expect = Harness.Test, Harness.Expect

Test("Connect and Fire pass arguments", function()
	const signal = Signal.New()
	local total = 0
	signal:Connect(function(a, b)
		total += a + b
	end)

	signal:Fire(1, 2)
	signal:Fire(3, 4)
	Expect.Equal(total, 10)
end)

Test("Once fires a single time", function()
	const signal = Signal.New()
	local count = 0
	signal:Once(function()
		count += 1
	end)

	signal:Fire()
	signal:Fire()
	Expect.Equal(count, 1)
	Expect.Equal(signal:GetConnectionCount(), 0)
end)

Test("Disconnect stops delivery", function()
	const signal = Signal.New()
	local count = 0
	const connection = signal:Connect(function()
		count += 1
	end)

	signal:Fire()
	connection:Disconnect()
	signal:Fire()
	Expect.Equal(count, 1)
	Expect.False(connection.Connected)
end)

Test("disconnecting during a fire is safe", function()
	const signal = Signal.New()
	const order = {}
	local first
	first = signal:Connect(function()
		table.insert(order, "first")
		first:Disconnect()
	end)

	signal:Connect(function()
		table.insert(order, "second")
	end)

	signal:Fire()
	signal:Fire()
	Expect.Equal(table.concat(order, ","), "first,second,second")
end)

Test("a throwing handler does not stop the others", function()
	const signal = Signal.New()
	local reached = false
	local reported
	Signal.SetErrorReporter(function(message)
		reported = message
	end)

	signal:Connect(function()
		error("boom")
	end)

	signal:Connect(function()
		reached = true
	end)

	signal:Fire()
	Signal.SetErrorReporter(nil)
	Expect.True(reached)
	Expect.True(string.find(reported, "boom", 1, true))
end)

Test("connecting during a fire is delivered next time", function()
	const signal = Signal.New()
	local late = 0
	signal:Once(function()
		signal:Connect(function()
			late += 1
		end)
	end)

	signal:Fire()
	Expect.Equal(late, 0)
	signal:Fire()
	Expect.Equal(late, 1)
end)

Test("DisconnectAll and Destroy clear connections", function()
	const signal = Signal.New()
	local count = 0
	signal:Connect(function()
		count += 1
	end)

	signal:DisconnectAll()
	signal:Fire()
	Expect.Equal(count, 0)

	signal:Destroy()
	const late = signal:Connect(function()
		count += 1
	end)

	signal:Fire()
	Expect.Equal(count, 0)
	Expect.False(late.Connected)
end)

return nil
