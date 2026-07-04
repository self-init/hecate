local stdio = {}

function stdio.print(text)
	return write(1, text)
end

function stdio.println(text)
	return stdio.print(text .. "\n")
end

return stdio
