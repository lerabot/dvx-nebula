toNum 	= function(num) return tonumber(num, 2) end
toHex   = function(num) return string.format("0x%02x", num) end
sleep 	= function(n) os.execute("sleep " .. tonumber(n)) end

local bit32 = require('bit32')
local I2C = require('periphery').I2C
-- Open i2c-0 controller
local i2c = I2C("/dev/i2c-10")
if i2c then
	print("Found the ADV7280")
end

local msgs = {}

local deviceAdress  = 0x21 --confirmed
local advRead 		= 0x43
local advWrite 		= 0x42
local vdpRead 		= 0x43
local vdpWrite 		= 0x42

local vppAddress    = 0x42



function setMainRegister()
	local v = toNum(00000000)
	i2c:transfer(deviceAdress, {{0x0E, v}})
	--print("MAIN REGISTER:")
end

function setSubMapRegister()
	local v = toNum(01000000)
	i2c:transfer(deviceAdress, {{0x0E, v}})
	--print("SUB 2 REGISTER:")
end

function setVDPRegister()
	local v = toNum(00100000)
	i2c:transfer(deviceAdress, {{0x0E, v}})
	--print("VDP REGISTER:")
end

function reset()
	local powerManagement 	= 0x0F
	local reset 			= 0x40

	-- Exit power down
	local msgs = {{powerManagement, 0x00}}
	i2c:transfer(deviceAdress, msgs)
	sleep(0.1)

	-- reset values
	msgs = {{powerManagement, reset}}
	i2c:transfer(deviceAdress, msgs)
	sleep(0.1)

	--set the VPP slave address to 84
	msgs 		= {{0xFD, 0x84}}
	i2c:transfer(deviceAdress, msgs)
end

function shutdown()
	
end

function showColorBar(mode)
	
	local mode = mode or "OFF"
	--local deviceAdress = advWrite
	i2c:transfer(deviceAdress, {{0x0E, 00}}) -- enter user sub map
	if mode == "ON" then
		i2c:transfer(deviceAdress, {{0x0C, 37}}) -- force free run
		i2c:transfer(deviceAdress, {{0x14, 11}}) -- free run  = color bar
	else 
		i2c:transfer(deviceAdress, {{0x0C, 36}})
	end
	sleep(0.1)
end

function readStatus()
	local status1Add = 0x10
	local msgs = {{status1Add}, {0x00, flags = I2C.I2C_M_RD}}
	i2c:transfer(deviceAdress, msgs)

	local data 		= msgs[2][1]
	local inlock 	= bit32.extract(data, 1)
	local lostlock 	= bit32.extract(data, 2)

	local format 	= bit32.extract(data, 4, 3)
	if format == 0 then format = "NTSC" end


	msgs = {{0x13}, {0x00, flags = I2C.I2C_M_RD}}
	i2c:transfer(deviceAdress, msgs)
	data = msgs[2][1]
	
	local freq = bit32.extract(data, 3)
	if freq == 1 then freq = "50Hz" else freq = "60Hz" end

	msgs = {{0x13}, {0x00, flags = I2C.I2C_M_RD}}
	i2c:transfer(deviceAdress, msgs)

	local interlaced 	= bit32.extract(msgs[2][1], 6)
	local fieldLength 	= bit32.extract(msgs[2][1], 5)
	local hz 			= bit32.extract(msgs[2][1], 2)

	if hz == 1 then 
		hz = "PAL"
	else
		hz = "NTSC"
	end

	print("FORMAT DETECTED " .. hz .. " = " .. format)
	print("INTERLACED " .. interlaced)
	print("FIELD OK " .. fieldLength)

end

function setInput(input)
	if input == nil then return end

	local inputSelect   = 0x00
	local inputSVid     = 0x08
	local inputComp     = 0x00

	print("Selecting " .. input .. " as input.")
	if input == "COMP" then input = inputComp end
	if input == "SVID" then input = inputSVid end

	-- Set the input to S-Video
	msgs = {{inputSelect, input}}
	i2c:transfer(deviceAdress, msgs)
end

function setMode(mode)
	local msgs = {}
	-- disable autodetect
	msgs = {{0x07, toNum(00000000)}}
	i2c:transfer(deviceAdress, msgs)

	if mode == "NTSC" then
		mode = toNum(01010100)
	elseif mode == "PAL" then
		mode = bit32.lshift(6, 4) -- NTSC M = 5 PAL = 6
	end

	mode = toNum(01010100)

	msgs = {{0x02, mode}}
	i2c:transfer(deviceAdress, msgs)
end

-- BT-656-3 or 656-4
function setFormat()
	-- set to BT.656-3 or-4 mode
	-- 0xB5 or 0x35

	-- DEFAULT PRODUCE A PERFECT FRAME?
	local bt6563 = toNum(00110101)
	local bt6564 = toNum(10110101)
	local msgs = {{0x04, bt6564}}
	i2c:transfer(deviceAdress, msgs)
end

function antialias(mode)
	local mode = mode or "OFF"
	local address = 0xF3

	if mode == "OFF" then mode = 0x00 end

	local msgs = {{address, mode}}
	i2c:transfer(deviceAdress, msgs)
end

function setProgressive(mode)
	local mode = mode or "OFF"

	
	setVDPRegister()

	-- reset I2P core
	msgs = {{0x41, toNum(00000001)}}
	i2c:transfer(vppAddress, msgs)
	sleep(0.1)

	-- enable (or disable core)
	if mode == "OFF" then
		msgs = {{0x55, toNum(00000000)}}
		i2c:transfer(vppAddress, msgs)
	else
		msgs = {{0x55, toNum(10000000)}}
		i2c:transfer(vppAddress, msgs)
	end


	if mode == "OFF" then
		msgs = {{0x5B, toNum(10000000)}}
		i2c:transfer(vppAddress, msgs)

	else
		msgs = {{0x5B, toNum(00000000)}}
		i2c:transfer(vppAddress, msgs)
	end
	--i2c:transfer(vppAddress, msgs)

	setMainRegister()
end

function automaticGainControl(mode)
	local mode = mode or "OFF"
	local m = mode

	local address = 0x2C
	if mode == "OFF" 	then mode = toNum(10001100) end
	if mode == "ON" 	then mode = toNum(10101110) end

	print("GAIN CONTROL VALUE : " .. m, mode)

	local msgs = {{address, mode}}
	i2c:transfer(deviceAdress, msgs)
end

function adaptiveContrast(mode)
	local mode = mode or "OFF"
	setSubMapRegister()

	local v = toNum(00000000)
	if mode == "ON" then v = toNum(10000000) end

	i2c:transfer(deviceAdress, {{0x80, v}})

	setMainRegister()
end

function resetContrast()
	-- gain = 2 (0xFF) seem to give the proper luma...
	-- gain = 1 (0x80) default
	local msgs = {{0x08, 0xFF}}
	i2c:transfer(deviceAdress, msgs)
end

function resetChroma()
	-- sets the chrome filter
	local filter = toNum(01010011)
	i2c:transfer(deviceAdress, {{0x17, filter}})

	-- set manual chroma gain
	i2c:transfer(deviceAdress, {{0x2D, 0x32}})
	i2c:transfer(deviceAdress, {{0x2E, 0x58}})

end

function setClamp(mode)
	local mode = mode or "OFF"
	local msgs = {{0x14, 0x00}}

	if mode == "ON" then
		msgs = toNum(00010000)
	end

	i2c:transfer(deviceAdress, {{0x14, 0x00}})
end

function setNoiseReduction(mode)
	-- this is total bullshit
	if 1 == 1 then return end

	--[[
	local mode = mode or "OFF"

	if mode == "ON" 	then mode = 1 end
	if mode == "OFF" 	then mode = 0 end

	local msgs = {{0x4D, mode}}
	i2c:transfer(deviceAdress, msgs)
	--]]
end

function checkLetterbox()
	i2c:transfer(deviceAdress, {{0x0E, 0x80}})
	i2c:transfer(deviceAdress, {{0x9C, 0x00}})
	i2c:transfer(deviceAdress, {{0x9C, 0xFF}})

	-- other shit for letterbox pixel and sync
	setMainRegister()
	i2c:transfer(deviceAdress, {{0x03, 0x0C}})
	i2c:transfer(deviceAdress, {{0x04, 0x07}})
	--i2c:transfer(deviceAdress, {{0x9C, 0xFF}})
	--i2c:transfer(deviceAdress, {{0x9C, 0xFF}})


end

-- :I2P YC In Ain3,4, 480p/576p MIPI Out:
local seq = {
	{0x42, 0x0F, 0x00},
	{0x42, 0x00, 0x09},
	{0x42, 0x0E, 0x80},
	{0x42, 0x9C, 0x00},
	{0x42, 0x9C, 0xFF},
	{0x42, 0x0E, 0x00},
	{0x42, 0x0E, 0x80},
	{0x42, 0x04, 0x57},
	{0x42, 0x13, 0x00},
	{0x42, 0x1D, 0xC0},
	{0x42, 0x53, 0xCE},
	{0x42, 0x80, 0x51},
	{0x42, 0x81, 0x51},
	{0x42, 0x82, 0x68},
	{0x42, 0xFD, 0x84},
	{0x84, 0xA3, 0x00}, --
	{0x84, 0x5B, 0x00}, --i2p core
	{0x84, 0x55, 0x80}, --
	{0x42, 0xFE, 0x88},
	{0x88, 0x01, 0x20},
	{0x88, 0x02, 0x28},
	{0x88, 0x03, 0x38},
	{0x88, 0x04, 0x30},
	{0x88, 0x05, 0x30},
	{0x88, 0x06, 0x80},
	{0x88, 0x07, 0x70},
	{0x88, 0x08, 0x50},
	{0x88, 0xDE, 0x02},
	{0x88, 0xD2, 0xF7},
	{0x88, 0xD8, 0x65},
	{0x88, 0xE0, 0x09},
	{0x88, 0x2C, 0x00},
	{0x88, 0x1D, 0x80},
	{0x88, 0x00, 0x00},
}

function run(seq)
	for i, v in ipairs(seq) do
		print(i)
		i2c:transfer(v[1]/2, {{v[2], v[3]}})
	end
end

function readTest1()
	local msgs = {{0x0F}, {0x00, flags = I2C.I2C_M_RD}}
	i2c:transfer(deviceAdress, msgs)
	print("Test read 0x00 " .. toHex(msgs[2][1]))

	msgs = {{0x10}, {0x00, flags = I2C.I2C_M_RD}}
	i2c:transfer(deviceAdress, msgs)
	print("Test read 0x4D " .. toHex(msgs[2][1]))

	msgs = {{0x12}, {0x00, flags = I2C.I2C_M_RD}}
	i2c:transfer(deviceAdress, msgs)
	print("Test read 0x00 " .. toHex(msgs[2][1]))

	msgs = {{0x13}, {0x00, flags = I2C.I2C_M_RD}}
	i2c:transfer(deviceAdress, msgs)
	print("Test read 0xED " .. toHex(msgs[2][1]))

end


reset()
sleep(0.5)

setMode("NTSC")
checkLetterbox()

setInput("SVID")
setFormat() 

readStatus()

automaticGainControl("OFF") --doesn't affect color
adaptiveContrast("OFF") -- doesn't seem to affect color

resetContrast() -- ok for color
resetChroma() -- ok for color

--antialias("OFF")
--setNoiseReduction("OFF")


--setProgressive("OFF")
--setProgressive("OFF")
--setProgressive("OFF")
--setProgressive("OFF")




--readTest1()

i2c:close()

-- ffmpeg -f v4l2 -video_size 720x480 -i /dev/video0 -c:v h264_v4l2m2m -pix_fmt yuv420p -vf "crop=720:480:0:0" -b:v 8M  output-h264.mp4

--[[
If you want to test whether Unicam is happy, then have 
	
	v4l2-ctl --stream-mmap=3 --stream-count=100000 --stream-to=/dev/null

running instead of VLC. It prints a < for every buffer received, so you can see if what is considered to be valid data is being received when you reconnect the video source.

]]

--[[

gst-launch-1.0 -vvv v4l2src norm=NTSC ! video/x-raw,format=UYVY,width=720,height=576 ! videocrop left=8 right=8 ! v4l2convert ! video/x-raw,format=RGBA! capssetter join=true replace=false caps="video/x-raw,framerate=60/1,colorimetry=1:1:5:1" ! v4l2h264enc ! video/x-h264,level="(string)3.1" ! filesink location="output.mp4"

]]