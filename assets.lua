-- Converted using Mokiros's Model to Script Version 3
-- Converted string size: 8604 characters
local function DecodeUnion(Values,Flags,Parse,data)
	local m = Instance.new("Folder")
	m.Name = "UnionCache ["..tostring(math.random(1,9999)).."]"
	m.Archivable = false
	m.Parent = game:GetService("ServerStorage")
	local Union,Subtract = {},{}
	if not data then
		data = Parse('B')
	end
	local ByteLength = (data % 4) + 1
	local Length = Parse('I'..ByteLength)
	local ValueFMT = ('I'..Flags[1])
	for i = 1,Length do
		local data = Parse('B')
		local part
		local isNegate = bit32.band(data,0b10000000) > 0
		local isUnion =  bit32.band(data,0b01000000) > 0
		if isUnion then
			part = DecodeUnion(Values,Flags,Parse,data)
		else
			local isMesh = data % 2 == 1
			local ClassName = Values[Parse(ValueFMT)]
			part = Instance.new(ClassName)
			part.Size = Values[Parse(ValueFMT)]
			part.Position = Values[Parse(ValueFMT)]
			part.Orientation = Values[Parse(ValueFMT)]
			if isMesh then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Values[Parse(ValueFMT)]
				mesh.Scale = Values[Parse(ValueFMT)]
				mesh.Offset = Values[Parse(ValueFMT)]
				mesh.Parent = part
			end
		end
		part.Parent = m
		table.insert(isNegate and Subtract or Union,part)
	end
	local first = table.remove(Union,1)
	if #Union>0 then
		first = first:UnionAsync(Union)
	end
	if #Subtract>0 then
		first = first:SubtractAsync(Subtract)
	end
	m:Destroy()
	return first
end

local function Decode(str)
	local StringLength = #str
	
	-- Base64 decoding
	do
		local decoder = {}
		for b64code, char in pairs(('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='):split('')) do
			decoder[char:byte()] = b64code-1
		end
		local n = StringLength
		local t,k = table.create(math.floor(n/4)+1),1
		local padding = str:sub(-2) == '==' and 2 or str:sub(-1) == '=' and 1 or 0
		for i = 1, padding > 0 and n-4 or n, 4 do
			local a, b, c, d = str:byte(i,i+3)
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
			t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8),bit32.extract(v,0,8))
			k = k + 1
		end
		if padding == 1 then
			local a, b, c = str:byte(n-3,n-1)
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
			t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8))
		elseif padding == 2 then
			local a, b = str:byte(n-3,n-2)
			local v = decoder[a]*0x40000 + decoder[b]*0x1000
			t[k] = string.char(bit32.extract(v,16,8))
		end
		str = table.concat(t)
	end
	
	local Position = 1
	local function Parse(fmt)
		local Values = {string.unpack(fmt,str,Position)}
		Position = table.remove(Values)
		return table.unpack(Values)
	end
	
	local Settings = Parse('B')
	local Flags = Parse('B')
	Flags = {
		--[[ValueIndexByteLength]] bit32.extract(Flags,6,2)+1,
		--[[InstanceIndexByteLength]] bit32.extract(Flags,4,2)+1,
		--[[ConnectionsIndexByteLength]] bit32.extract(Flags,2,2)+1,
		--[[MaxPropertiesLengthByteLength]] bit32.extract(Flags,0,2)+1,
		--[[Use Double instead of Float]] bit32.band(Settings,0b1) > 0
	}
	
	local ValueFMT = ('I'..Flags[1])
	local InstanceFMT = ('I'..Flags[2])
	local ConnectionFMT = ('I'..Flags[3])
	local PropertyLengthFMT = ('I'..Flags[4])
	
	local ValuesLength = Parse(ValueFMT)
	local Values = table.create(ValuesLength)
	local CFrameIndexes = {}
	
	local ValueDecoders = {
		--!!Start
		[1] = function(Modifier)
			return Parse('s'..Modifier)
		end,
		--!!Split
		[2] = function(Modifier)
			return Modifier ~= 0
		end,
		--!!Split
		[3] = function()
			return Parse('d')
		end,
		--!!Split
		[4] = function(_,Index)
			table.insert(CFrameIndexes,{Index,Parse(('I'..Flags[1]):rep(3))})
		end,
		--!!Split
		[5] = {CFrame.new,Flags[5] and 'dddddddddddd' or 'ffffffffffff'},
		--!!Split
		[6] = {Color3.fromRGB,'BBB'},
		--!!Split
		[7] = {BrickColor.new,'I2'},
		--!!Split
		[8] = function(Modifier)
			local len = Parse('I'..Modifier)
			local kpts = table.create(len)
			for i = 1,len do
				kpts[i] = ColorSequenceKeypoint.new(Parse('f'),Color3.fromRGB(Parse('BBB')))
			end
			return ColorSequence.new(kpts)
		end,
		--!!Split
		[9] = function(Modifier)
			local len = Parse('I'..Modifier)
			local kpts = table.create(len)
			for i = 1,len do
				kpts[i] = NumberSequenceKeypoint.new(Parse(Flags[5] and 'ddd' or 'fff'))
			end
			return NumberSequence.new(kpts)
		end,
		--!!Split
		[10] = {Vector3.new,Flags[5] and 'ddd' or 'fff'},
		--!!Split
		[11] = {Vector2.new,Flags[5] and 'dd' or 'ff'},
		--!!Split
		[12] = {UDim2.new,Flags[5] and 'di2di2' or 'fi2fi2'},
		--!!Split
		[13] = {Rect.new,Flags[5] and 'dddd' or 'ffff'},
		--!!Split
		[14] = function()
			local flags = Parse('B')
			local ids = {"Top","Bottom","Left","Right","Front","Back"}
			local t = {}
			for i = 0,5 do
				if bit32.extract(flags,i,1)==1 then
					table.insert(t,Enum.NormalId[ids[i+1]])
				end
			end
			return Axes.new(unpack(t))
		end,
		--!!Split
		[15] = function()
			local flags = Parse('B')
			local ids = {"Top","Bottom","Left","Right","Front","Back"}
			local t = {}
			for i = 0,5 do
				if bit32.extract(flags,i,1)==1 then
					table.insert(t,Enum.NormalId[ids[i+1]])
				end
			end
			return Faces.new(unpack(t))
		end,
		--!!Split
		[16] = {PhysicalProperties.new,Flags[5] and 'ddddd' or 'fffff'},
		--!!Split
		[17] = {NumberRange.new,Flags[5] and 'dd' or 'ff'},
		--!!Split
		[18] = {UDim.new,Flags[5] and 'di2' or 'fi2'},
		--!!Split
		[19] = function()
			return Ray.new(Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')),Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')))
		end
		--!!End
	}
	
	for i = 1,ValuesLength do
		local TypeAndModifier = Parse('B')
		local Type = bit32.band(TypeAndModifier,0b11111)
		local Modifier = (TypeAndModifier - Type) / 0b100000
		local Decoder = ValueDecoders[Type]
		if type(Decoder)=='function' then
			Values[i] = Decoder(Modifier,i)
		else
			Values[i] = Decoder[1](Parse(Decoder[2]))
		end
	end
	
	for i,t in pairs(CFrameIndexes) do
		Values[t[1]] = CFrame.fromMatrix(Values[t[2]],Values[t[3]],Values[t[4]])
	end
	
	local InstancesLength = Parse(InstanceFMT)
	local Instances = {}
	local NoParent = {}
	
	for i = 1,InstancesLength do
		local ClassName = Values[Parse(ValueFMT)]
		local obj
		local MeshPartMesh,MeshPartScale
		if ClassName == "UnionOperation" then
			obj = DecodeUnion(Values,Flags,Parse)
			obj.UsePartColor = true
		elseif ClassName:find("Script") then
			obj = Instance.new("Folder")
			Script(obj,ClassName=='ModuleScript')
		elseif ClassName == "MeshPart" then
			obj = Instance.new("Part")
			MeshPartMesh = Instance.new("SpecialMesh")
			MeshPartMesh.MeshType = Enum.MeshType.FileMesh
			MeshPartMesh.Parent = obj
		else
			obj = Instance.new(ClassName)
		end
		local Parent = Instances[Parse(InstanceFMT)]
		local PropertiesLength = Parse(PropertyLengthFMT)
		local AttributesLength = Parse(PropertyLengthFMT)
		Instances[i] = obj
		for i = 1,PropertiesLength do
			local Prop,Value = Values[Parse(ValueFMT)],Values[Parse(ValueFMT)]
			
			local dont = false
			-- ok this looks awful
			if MeshPartMesh then
				if Prop == "MeshId" then
					MeshPartMesh.MeshId = Value
					dont = true
				elseif Prop == "TextureID" then
					MeshPartMesh.TextureId = Value
					dont = true
				elseif Prop == "Size" then
					if not MeshPartScale then
						MeshPartScale = Value
					else
						MeshPartMesh.Scale = Value / MeshPartScale
					end
				elseif Prop == "MeshSize" then
					if not MeshPartScale then
						MeshPartScale = Value
						MeshPartMesh.Scale = obj.Size / Value
					else
						MeshPartMesh.Scale = MeshPartScale / Value
					end
					dont = true
				end
			end
			
			if(not dont)then
				obj[Prop] = Value
			end
		end
		if MeshPartMesh then
			if MeshPartMesh.MeshId=='' then
				if MeshPartMesh.TextureId=='' then
					MeshPartMesh.TextureId = 'rbxasset://textures/meshPartFallback.png'
				end
				MeshPartMesh.Scale = obj.Size
			end
		end
		for i = 1,AttributesLength do
			obj:SetAttribute(Values[Parse(ValueFMT)],Values[Parse(ValueFMT)])
		end
		if not Parent then
			table.insert(NoParent,obj)
		else
			obj.Parent = Parent
		end
	end
	
	local ConnectionsLength = Parse(ConnectionFMT)
	for i = 1,ConnectionsLength do
		local a,b,c = Parse(InstanceFMT),Parse(ValueFMT),Parse(InstanceFMT)
		Instances[a][Values[b]] = Instances[c]
	end
	
	return NoParent
end


local Objects = Decode('AEBsASEGRm9sZGVyIQROYW1lIQdFbXBlcm9yIQhNZXNoUGFydCEITGVmdCBBcm0hCEFuY2hvcmVkIiEKQnJpY2tDb2xvcgfHACEGQ0ZyYW1lBBQARQFGASEKQ2FuQ29sbGlkZQIhCENhblRvdWNoIQVDb2xvcgZjX2IhCE1hdGVyaWFsAwAAAAAAgJhAIQhQb3NpdGlv'
..'bgqEhU5B5GiOQGRG08AhBFNpemUKAACAPwAAAEAAAIA/IQZNZXNoSWQhHXJieGFzc2V0Oi8vZm9udHMvbGVmdGFybS5tZXNoIQhNZXNoU2l6ZSEITGVmdCBMZWcEHABFAUYBCoSFXkHI0RxAZEbTwCEdcmJ4YXNzZXQ6Ly9mb250cy9sZWZ0bGVnLm1lc2ghCVJpZ2h0'
..'IEFybQQgAEUBRgEKhIV+QeRojkBkRtPAIR5yYnhhc3NldDovL2ZvbnRzL3JpZ2h0YXJtLm1lc2ghBEJlYW0hBkNoYWluMiELQXR0YWNobWVudDAhC0F0dGFjaG1lbnQxKAIAAAAAAA3/AACAPwAN/yEKQ3VydmVTaXplMAMAAAAAAADwPyEKQ3VydmVTaXplMQMAAAAA'
..'AADwvyENTGlnaHRFbWlzc2lvbiEOTGlnaHRJbmZsdWVuY2UDAAAAAAAA4D8hB1RleHR1cmUhF3JieGFzc2V0aWQ6Ly80NTI3NDY1MTE0IQ1UZXh0dXJlTGVuZ3RoAwAAAAAAAABAIQxUZXh0dXJlU3BlZWQDAAAAoJmZ2T8hDFRyYW5zcGFyZW5jeSkCAAAAAAAAAAAA'
..'AAAAAACAPwAAAAAAAAAAIQZXaWR0aDAhBldpZHRoMSEKQXR0YWNobWVudAQ6AEUBRgEKAAAAAM3MzL4zMzO/IQtBdHRhY2htZW50MgQ9AEUBRgEKAAAAAM3MzL4zMzM/IQZDaGFpbjEhBU1vZGVsIQpIYW5kQ2Fubm9uIQpXb3JsZFBpdm90BEcBSAFJASEEUGFydCEL'
..'QmFja1N1cmZhY2UDAAAAAAAAJEAhDUJvdHRvbVN1cmZhY2UH6wMETwBKAUsBBhERESEMRnJvbnRTdXJmYWNlIQtMZWZ0U3VyZmFjZQMAAAAAAAByQCELT3JpZW50YXRpb24KAAAAAAAANEMAADRDCoKLfkE0JIc/YgbvwCEMUmlnaHRTdXJmYWNlIQhSb3RhdGlvbgoA'
..'ADRDAAAAAAAAAAAKmplZPq5HgT2amVk+IQpUb3BTdXJmYWNlIQxDeWxpbmRlck1lc2ghDlVuaW9uT3BlcmF0aW9uBy8BBFsASAFJAQYAELAKAAC0QgAAAAAAAAAACoKLfkEKkh9A/p/awAoAAoA+bmbGP/7MMEAhDFVzZVBhcnRDb2xvcgoAAEA+0cyMPmZmZj4Kgot+'
..'QReSWUAx09/ACgAAgD8AAIA/AACAPwoAAAAAAAAAAAAAAAAKAACAPpeZKT+Ymbk+CoKLfkFRxU5AzGzMwAoAALTCAAA0QwAAAAAKLzNjPzIz8z4AAEA+CoKLfkHoXkRAM9PrwAoAAAAAAAC0wgAAtEIKAQCAPtDM7D4BAIA+CoKLfkGsKztAxWzewAqbmVk+x8zsPhIA'
..'gD4Kgot+QYn4SUDJbN7ACgAAgD4AAIA+AACAPgqCi35BHVeeP8Vs5cAKlpnRPwAAgD4AAIA+CoKLfkEgkgtAyGzlwAqCi35BVcVYQNFs3sAKAAC0QgAANEMAAAAACszMzD2YmSk/EgCAPgqCi35BLpJdQM9szMAKAACAPpiZKT+Ymbk+CoKLfkHwXmxAzGzMwCEEV2Vs'
..'ZCECQzEETAFNAU4BIQVQYXJ0MCEFUGFydDEETwFQAVEBBFIBUwFUASEGQlRXZWxkBFUBSAFJAQcaAASCAFYBVwEGGyo1CoqLfkFZxVJAMtPawAoAALTCAAC0wgAAAAAKRgCYPwwAyD8AAKA+CpqZGT6ZmRk/MzODPgqCi35B515eQMtsy8AKMzODPpiZGT9mZqY+CoKL'
..'fkGoK09AzWzLwAozM4M+YWZmPgIAAD4Kgot+QWvFQED8n9jACjMzgz6ZmRk/zMysPgqCi35BnvhtQNNsy8AK//8PP/v/3z4AAKA+CoKLfkFGxT5AM9PswAozM4M+YWZmPjQz8z4Kgot+Qaf4U0D9n9jAB/MDBJQAWAFZAQYAIGAK8qV+QWLFIkA209nACgAAtMIAAAAA'
..'AAA0QwqAg10/BgDwP4ZmQkAKMDOzPpyZ2T41M3M+CoKLfkFlxVJA0GzHwAowM7M+l5nZPjIzAz8Kgot+QRmSc0DQbMfACjAzsz7KzAw+lZk5PwqCi35BFV9WQDTTwsAKAAC0wgAAAAAAAAAACsvMDD4CAOA+QTOzPgqCi35BYMVeQJk5x8AKMDOzPpiZGT5hZhY/CoKL'
..'fkHWK3FAnzm+wAowM7M+l5kZPpGZ+T4Kgot+QWHFTkCfOb7AIQ9Db3JuZXJXZWRnZVBhcnQK/MrMPTDKzD7TyMw9CpC5ekHZLNk/KNbtwAoAAPBBSgxwwfT90UIK0sjMPTDKzD79ysw9Cg4gekHt4eM/5Y7swAqTGGPCfb8swkRL5EIK/crMPS/KzD7SyMw9CtN7ekEf'
..'SOo/GDzvwAoMAvDBff8kQ/r+0cIK08jMPS/KzD79ysw9CmsVe0Fhk98/YoPwwAqHFmNCns8IQ0pM5MIK5WGBQWa/HEBsuvDACilc9sEAQBxDg0DfQgrSyMw9L8rMPv7KzD0KsX+BQZzbIUAA3O7ACsP1U8LdJGBByXbzwgrfOIFB55QeQPJX7MAKHVr2QfT9vcGJQd/C'
..'CtLIzD0vysw+/crMPQoHG4FBrngZQFM27sAKw/VTQu78JcNSePNCCkRmZj75/38+MzOzPgqCi35BxStXQPuf8MAKMzOzPgYAgD6amZk+CoKLfkGw+GdAAqDwwAozM7M+pZlZPs3M7D4Kgot+QXHFYkCZOenACjMzsz7LzOw+zMyMPgqCi35ByytHQJ857cAKzcxMPcvM'
..'zD3MzEw+CvV4gEGk+EdAmDn2wAr3/38/AACAPwAAgD8KzcxMPcvMzD3NzEw9CvF4gEGT+D9Aljn2wAr3/38/AACAP/X/fz8KGiV8QZP4P0CWOfbACholfEGk+EdAmDn2wApx/389jJlZPjMzsz4Kgot+QY74UUCbOenACjMzsz54ZuY9ZmamPgqCi35B/l4yQPqf5cAK'
..'f/9/PdH/fz0zM7M+CoKLfkGM+ClAymzowAozM7M+MjMzPjIzMz4Kgot+QVVXlj/6n+bACsjMzD8wM7M+MzOzPgqCi35BoIrxP2gG78AKMzOzPj0zMz5sZuY9CoKLfkEtvtA/BKDmwArMzEw+zcxMPc3MTD0Kgot+QeK9vD+WOffAAwAAAAAAABhACgAAgD/z/z8/9f//'
..'PgrNzEw9y8zMPQAAgD4K9XiAQQ3x3z+TOfbACurxfkHivbw/ljn3wAoAAIA/+v8/P+v//z4KGiV8QQ3x3z+TOfbACjMzsz44M9M+aGaGPgqCi35BDF80QGAG7sAK8/+fPiMzMz4zM7M+CoKLfkGtirU/8p/mwAoaJX5B4r28P5Y598AKAAAAAAAAtEIAALTCCszMTD71'
..'/389l5mZPQqCi35B+r28P/6f9cAKAACAPvX/fz0AAIA+CoKLfkE8JIc/YAbvwAMAAAAAAAAQQAozM7M+PTMzPpyZ2T4Kgot+QQZfGkD+n+bACgAAgD7MzMw9zcxMPQr1eIBBRvG/P5o59sAKAACAPwAAgD/6/38/Cs3MTD3LzMw9yMzMPQrxeIBBmoqpP4s59sAKAACA'
..'PsjMzD3NzEw9CholfEFG8b8/mjn2wCEESG9sZQMAAAAAAAAAAAT3AFoBWwEKeIZ+QV5whj/a9u7ACs3MzD3NzMw9zczMPQRcAV0BXgEhBVNwaWtlBP0AXwFgAQoAAHDBAAAAAAAAcMIKqnWDQXTFkUAxWtjACszMzD4yMzM/zMzMPgrMyEw+vjAzPxnNTD4KQA+DQYdG'
..'lUB++tXAChkEcMEAAAAAAABwwgoZzUw+vzAzP8zITD4KENyDQUXsj0BIi9TACqAaY0I5tINC+n7hwQoZzUw+vjAzP8zITD4KUw+DQc2ek0AIKdzACqAaY8LHS+TC4XrhQQrMyEw+vzAzPxnNTD4KE9yDQSlEjkC+udrACjEIcEG+/zPDAABwQgQNAWEBYgEKAACWQgAA'
..'AAAAAHDCCqp1g0F0xaFAlcDOwArMyEw+vjAzPxjNTD4KQA+DQcFln0CCP8vACn3/lUJvEgM7+v5vwgoQ3INBi/adQMSZ0MAKfT9PQY8iFUP0vaRCClMPg0FLlKVAPOfMwAp9P0/Bhev2wfq+pMIKE9yDQQElpEDgQdLACvr+lcK4/jPD4fpvQgRjAWQBZQEEZgFnAWgB'
..'IQlSaWdodCBMZWcEGwFFAUYBCoSFbkHI0RxAZEbTwCEecmJ4YXNzZXQ6Ly9mb250cy9yaWdodGxlZy5tZXNoIQVUb3JzbwQfAUUBRgEKhIVmQeRojkBkRtPACgAAAEAAAABAAACAPwQjAWkBagEKAAAAgAAAAAAAALRCCgAAAAAAAAC/AAAAPwQlAUUBRgEKAAAAAAAA'
..'AAAAAIBAIQVDaGFpbiEKRmFjZUNhbWVyYSEIU2VnbWVudHMDAAAAAAAANEAhC1RleHR1cmVNb2RlKQIAAAAAAAAAAAAAAAAAAIA/AACAPwAAAAAhBEhlYWQELgFFAUYBCoSFZkHeaL5AZEbTwAqamZk/mpmZP5qZmT8hGnJieGFzc2V0Oi8vZm9udHMvaGVhZC5tZXNo'
..'Ch5TmT8N6Zk/HlOZPwQ0AWsBRgEKAAAAgAAAoMIAAAAACpqZmb7NzMw+zcxMvigCAAAAAAAA/wAAgD8AAP8DAAAAQDMz4z8EOAFFAUYBCpqZmb6amdk/AAAAvyELQXR0YWNobWVudDQEOwFFAUYBCpqZmT6amdk/AAAAvwMAAABAMzPjvyELQXR0YWNobWVudDMEQAFs'
..'AUYBCgAAAIAAAMjCAAAAAAqamZk+zczMPs3MTL4hB1JlbW90ZXMhC1JlbW90ZUV2ZW50IQlLZXlfTW91c2UhBkNhbWVyYQoAAIA/AAAAAAAAAAAKAAAAAAAAgD8AAAAACoSFfkHoaI5AZEbTwAr//38/AAAAAC3eTLIKLt5MMqZ39zQAAIA/Cv3/fz8AAAAAK95Msgrk'
..'pd8nAACAv9O7CzUKAAAAAC0zI7/e/7c/Cv7/fz8AAAAAAAAAAAoAAAAAAAAAMwAAgD8KAIDTO22ZKb+OZr6/Cv7/f78AAAAAAAAAAAoAAAAAAAAAMwAAgL8KPjMPwJSZIT8AAAA3CgAAAAAAAAAA/v9/vwoAAIC/AAAAAAAAAAAKAEChOrezuD/itiI/CuSl36cAAIA/'
..'07sLtQou3kyypnfntAAAgL8K+/9/vwAAAIAp3kwyCi7eTDKmd9c0AACAPwr+/38/IN7MpQ4AACcKIN7MpQAAgD8AAACzCgDAv7qQM2s+e3/6vwr//38/Lt5MMgHY0icKAAAAAKZ39zQAAIC/Cv///z7vJVa/7IVlPgrXs10/6kb3PuaDBL4K/v//PuqFZb7vJVa/Ctaz'
..'XT/lgwQ+6kb3PgoAUw6+QJsGv/QYAT4K////PtezXT8AAAAACu8lVr/qRvc+54OEPgoAnAy8gOEZvxhADD8K/v//PtazXT8AAAAACuqFZb7lgwQ+60Z3vwouvTuzAACAPwAAAAAKAACAvy69O7MAAAAACs/QMT4AAAAAXRx8PwrV0DG+AAAAAFwcfD8oAQAAAQACAAMA'
..'AQABAAAEAAIMAAIABQAGAAcACAAJAAoACwAMAA0ADgANAA8AEAARABIAEwAUABUAFgAXABgAGQAWAAQAAgwAAgAaAAYABwAIAAkACgAbAAwADQAOAA0ADwAQABEAEgATABwAFQAWABcAHQAZABYABAACDAACAB4ABgAHAAgACQAKAB8ADAANAA4ADQAPABAAEQASABMA'
..'IAAVABYAFwAhABkAFgAiAAUMAAIAIwAPACYAJwAoACkAKgArACgALAAtAC4ALwAwADEAMgAzADQANQA2ADMANwAzADgABQIACgA5ABMAOgA4AAUDAAIAOwAKADwAEwA9ACIABQwAAgA+AA8AJgAnACoAKQAoACsAKAAsAC0ALgAvADAAMQAyADMANAA1ADYAMwA3ADMA'
..'PwAFAgACAEAAQQBCAEMAChAARABFAEYARQAIAEcACgBIAAwADQAOAA0ADwBJAEoARQBLAEUAEQBMAE0ATgATAE8AUABFAFEAUgAVAFMAVABFAFUACwAAVgBACgFDAF4AXwBaADEAYABhAAFDAGIAYwBkADEAYABhAABDAGUAZgBnAAFDAGgAaQBkADEAYABhAABDAGoA'
..'awBnAAFDAGwAbQBkADEAYABhAABDAG4AbwBnAAFDAGgAcABxADEAYABhAABDAHIAcwBnAAFDAHQAdQBxADEAYABhAAoLAAgAVwAKAFgADAANAA4ADQAPAFkAEQASAE0AWgATAFsAUQBaABUAXABdAAcAdgANAQB3AHgAdgANAQB3AHsAdgANAQB3AHwAdgANAgACAH0A'
..'dwB+AFYAQAYAQwCFAIYAZwABQwCHAIgAZAAxAGAAYQABQwCJAIoAZAAxAGAAYQABQwCLAIwAcQAxAGAAYQAAQwCNAI4AZwABQwCPAJAAcQAxAGAAYQAKCgAIAH8ACgCAAAwADQAOAA0ADwCBABEAEgBNAGcAEwCCAFEAgwAVAIQAVgBABUAGAUMAlwCYAGQAMQBgAGEA'
..'AUMAmQCaAHEAMQBgAGEAAUMAmwCcAJ0AMQBgAGEAAEMAngCfAGcAAUMAoAChAFoAMQBgAGEAAUMAogCjAGQAMQBgAGEAQAQApAClAKYApwAApACoAKkAqgAApACrAKwArQAApACuAK8AsABABACkAKsAsQCyAACkALMAtAC1AACkAKsAtgC3AACkALgAuQC6AEAJAEMA'
..'uwC8AGcAAUMAvQC+AHEAMQBgAGEAAUMAvwDAAFoAMQBgAGEAAUMAwQDCAGQAMQBgAGEAAUMAwwDEAHEAMQDFAGEAAUMAxgDHAJ0AMQDIAGEAAUMAxgDJAJ0AMQDIAGEAAUMAwwDKAHEAMQDFAGEAAEMAywDMAGcAQBIBQwDNAM4AWgAxAGAAYQAAQwDPANAAZwABQwDR'
..'ANIAZAAxAGAAYQAAQwDTANQAZwABQwDVANYAWgAxAGAAYQABQwDXANgAZwDZANoAYQABQwDbANwAcQAxAMUAYQABQwDXAN0AZwAxAN4AYQABQwDbAN8AcQAxAMUAYQABQwDgAOEAcQAxAGAAYQAAQwDiAOMAZwABQwDXAOQA5QAxAN4AYQAAQwDmAOcAZwABQwDoAOkA'
..'TgDqAGAAYQABQwDrAOwAZAAxAGAAYQABQwDtAO4AZwDZAO8AYQABQwDwAPEAnQAxAMUAYQABQwDyAPMAZwDZAO8AYQAKCgAIAJEACgCSAAwADQAOAA0ADwCTABEAEgBNAGQAEwCUAFEAlQAVAJYAQwAKCQACAPQARgD1AAoA9gAMAA0ADgANABMA9wAVAPgAVAD1ADQA'
..'KAB2AAoBAHcA+QBWAEAEAKQA/wAAAQEBAKQAAgEDAQQBAKQABQEGAQcBAKQACAEJAQoBBQwAAgD6AAgAkQAKAPsADAANAA4ADQAPAJMAEQASAE0A/AATAP0AUQD8ABUA/gBdAAcAVgBABACkAA4BDwEQAQCkAAUBEQESAQCkAAUBEwEUAQCkAP8AFQEWAQUMAAIA+gAI'
..'AJEACgALAQwADQAOAA0ADwCTABEAEgBNAAwBEwANAVEADAEVAP4AXQAHAHYABQIAAgB9AHcAFwF2AAUCAAIAfQB3ABgBBAACDAACABkBBgAHAAgACQAKABoBDAANAA4ADQAPABAAEQASABMAGwEVABYAFwAcARkAFgAEAAIMAAIAHQEGAAcACACRAAoAHgEMAA0ADgAN'
..'AA8AkwARABIAEwAfARUAIAEXACEAGQAWADgAGwMACgAhAU0AIgETACMBOAAbAwACADsACgAkARMAJQEiABsMAAIAJgEPACYAJwAqACkAKAAnAQcAKwAoACgBKQEuAC8AMAAxACoBKAA0ACsBNwD1AAQAAgwAAgAsAQYABwAIAAkACgAtAQwADQAOAA0ADwAQABEAEgAT'
..'AC4BFQAvARcAMAEZADEBOAAfAwAKADIBTQAzARMANAEiAB8KAAIAPgAPADUBJwAqACkANgEnAQcAKwAoAC4ALwAqASgANAArATcA9QA4AB8DAAIAOwAKADcBEwA4ATgAHwMAAgA5AQoAOgETADsBIgAfCgACACMADwA1AScAKgApADwBJwEHACsAKAAuAC8AKgEoADQA'
..'KwE3APUAOAAfBAACAD0BCgA+AU0APwETAEABAQABAQACAEEBQgEmAQACAEMBQgEmAQACAEQBGAYkAAcGJQAICSQACAklAAcOeQALDnoADQ95AAsPegATEHkACxB6ABIReQANEXoAFBV5AAUVegANGHkABRh6ABYZeQAFGXoAFx4kABweJQAdISQAICElACIkJAAlJCUA'
..'Iw==')
for _,obj in pairs(Objects) do
	obj.Parent = script or workspace
end
