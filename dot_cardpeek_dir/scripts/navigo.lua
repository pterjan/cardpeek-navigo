--
-- This file is part of Cardpeek, the smartcard reader utility.
--
-- Copyright 2009 by 'L1L1'
--
-- Cardpeek is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Cardpeek is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Cardpeek.  If not, see <http://www.gnu.org/licenses/>.
--

card.CLA=0x94 -- Class for navigo cards

require('lib.apdu')

LFI_LIST = {
  ["0002"] = "Unknown",
  ["2001"] = "Environement",
  ["2010"] = "Events logs",
  ["2020"] = "Contracts",
  ["2040"] = "Special events",
  ["2050"] = "Contract list",
  ["2069"] = "Counters"
}

TRANSPORT_LIST = {
  [1] = "Urban Bus",
  [2] = "Interurban Bus",
  [3] = "Metro",
  [4] = "Tram",
  [5] = "Train",
  [8] = "Parking"
}

TRANSITION_LIST = {
  [1] = "Entry",
  [2] = "Exit",
  [4] = "Inspection",
  [7] = "Interchange"
}

dofile "metro.lua"
dofile "banlieue.lua"

function en1543_parse(ctx,resp,context)
	ui.tree_append(ctx,true,resp,nil,nil,nil)
	if context == "Environement" then
		ui.tree_append(ctx,false,"Application Version Number", card.getbits(resp, 1, 3).."."..card.getbits(resp, 4, 3), nil, nil)
		local bitmap = card.getbits(resp, 7, 7)
		ui.tree_append(ctx,false,"Network Id", card.getbits(resp, 14, 24), nil, nil)
		ui.tree_append(ctx,false,"Application Issuer Id", card.getbits(resp, 38, 8), nil, nil)
                local days_since_1997 = card.getbits(resp, 46, 14)
		local date = os.date("%x", os.time{year=1997, month=1, day=1, hour=0} + days_since_1997*3600*24)
		ui.tree_append(ctx,false,"Application Validity End Date", date, nil, nil)
		local pos = 60
		if bit_and(bitmap, bit_shl(1, 3)) ~= 0 then
			ui.tree_append(ctx,false,"EnvPayMethod", card.getbits(resp, pos, 11), nil, nil)
			pos = pos + 11
		end
		if bit_and(bitmap, bit_shl(1, 4)) ~= 0 then
			ui.tree_append(ctx,false,"Authenticator", card.getbits(resp, pos, 16), nil, nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 5)) ~= 0 then
			ui.tree_append(ctx,false,"Select List", card.getbits(resp, pos, 32), nil, nil)
			pos = pos + 32
		end
		if bit_and(bitmap, bit_shl(1, 6)) ~= 0 then
			local databitmap = card.getbits(resp, pos, 2)
			pos = pos + 2
			if bit_and(databitmap,1) then
				ui.tree_append(ctx,false,"Data Card Status", card.getbits(resp, pos, 1), nil, nil)
				pos = pos + 1
			end
			if bit_and(databitmap,2) then
				ui.tree_append(ctx,false,"Data2", card.getbits(resp, pos, 29*4-pos+1), nil, nil)
			end
		end
	end
	if context == "Events logs" or context == "Special events" then

		local min_since_midnight = card.getbits(resp, 15, 11)
		local days_since_1997 = card.getbits(resp, 1, 14)
		local date = os.date("%x %X", os.time{year=1997, month=1, day=1, hour=0} + days_since_1997*3600*24+min_since_midnight*60)
		ui.tree_append(ctx,false,"Date",date,nil,nil)

		local bitmap = card.getbits(resp, 26, 28)
		local pos = 54
		if bit_and(bitmap, 1) ~= 0 then
			ui.tree_append(ctx,false,"Display Data",card.getbits(resp, pos, 8),nil,nil)
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 1)) ~= 0 then
			ui.tree_append(ctx,false,"Network Id",card.getbits(resp, pos, 24),nil,nil)
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 2)) ~= 0 then
			local transport_id = card.getbits(resp, pos, 4)
			local transition_id = card.getbits(resp, pos+4, 4)
			local transport = TRANSPORT_LIST[transport_id]
			if transport then
				ui.tree_append(ctx,false,"Transport",transport,nil,nil)
			else
				ui.tree_append(ctx,false,"Transport",transport_id,nil,nil)
			end
			local transition = TRANSITION_LIST[transition_id]
			if transition then
				ui.tree_append(ctx,false,"Event",transition,nil,nil)
			else
				ui.tree_append(ctx,false,"Event",transition_id,nil,nil)
			end
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 3)) ~= 0 then
			ui.tree_append(ctx,false,"Result",card.getbits(resp, pos, 8),nil,nil)
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 4)) ~= 0 then
			ui.tree_append(ctx,false,"Service Provider",card.getbits(resp, pos, 8),nil,nil)
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 5)) ~= 0 then
			ui.tree_append(ctx,false,"Notok Counter",card.getbits(resp, pos, 8),nil,nil)
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 6)) ~= 0 then
			ui.tree_append(ctx,false,"Serial Number",card.getbits(resp, pos, 24),nil,nil)
			pos = pos + 24
		end
		if bit_and(bitmap, bit_shl(1, 7)) ~= 0 then
			ui.tree_append(ctx,false,"Destination",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 8)) ~= 0 then
			LOC=ui.tree_append(ctx,true,"Location",card.getbits(resp, pos, 16),nil,nil)
			local sector_id = card.getbits(resp, pos, 7)
			local sector = BANLIEUE_LIST[sector_id]
			if not sector then
				sector = METRO_LIST[sector_id] 
			end
			if sector then
				if sector["name"] then
					ui.tree_append(LOC,false,"Sector",sector["name"],nil,nil)
				end
				local station_id = card.getbits(resp, 77, 5)
				station = sector[station_id]
				-- For some train stations in Paris we may lack the code while they are also metro station
				if not station then
					sector = METRO_LIST[sector_id]
					station = sector[station_id]
				end
				if station then
					ui.tree_append(LOC,false,"Station",station,nil,nil)
				end
			end
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 9)) ~= 0 then
			if LOC then
				ui.tree_append(LOC,false,"Gate",card.getbits(resp, pos, 8),nil,nil)
			else
				ui.tree_append(ctx,false,"Location Gate",card.getbits(resp, pos, 8),nil,nil)
			end
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 10)) ~= 0 then
			if LOC then
				ui.tree_append(LOC,false,"Device",card.getbits(resp, pos, 16),nil,nil)
			else
				ui.tree_append(ctx,false,"Device",card.getbits(resp, pos, 16),nil,nil)
			end
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 11)) ~= 0 then
			ui.tree_append(ctx,false,"Route Number",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 12)) ~= 0 then
			ui.tree_append(ctx,false,"Route Variant",card.getbits(resp, pos, 8),nil,nil)
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 13)) ~= 0 then
			ui.tree_append(ctx,false,"Journey Run",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 14)) ~= 0 then
			ui.tree_append(ctx,false,"Vehicle Id",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 15)) ~= 0 then
			ui.tree_append(ctx,false,"Vehicle Class",card.getbits(resp, pos, 8),nil,nil)
			pos = pos + 5
		end
		if bit_and(bitmap, bit_shl(1, 16)) ~= 0 then
			ui.tree_append(ctx,false,"Location Type",card.getbits(resp, pos, 5),nil,nil)
			pos = pos + 5
		end
		if bit_and(bitmap, bit_shl(1, 17)) ~= 0 then
			ui.tree_append(ctx,false,"Employee",card.getbits(resp, pos, 240),nil,nil)
			pos = pos + 240
		end
		if bit_and(bitmap, bit_shl(1, 18)) ~= 0 then
			ui.tree_append(ctx,false,"Location Reference",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 19)) ~= 0 then
			ui.tree_append(ctx,false,"Journey Interchanges",card.getbits(resp, pos, 8),nil,nil)
			pos = pos + 8
		end
		if bit_and(bitmap, bit_shl(1, 20)) ~= 0 then
			ui.tree_append(ctx,false,"Period Journeys",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 21)) ~= 0 then
			ui.tree_append(ctx,false,"Total Journeys",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 22)) ~= 0 then
			ui.tree_append(ctx,false,"Journey Distance",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 23)) ~= 0 then
			ui.tree_append(ctx,false,"Price Amount",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 24)) ~= 0 then
			ui.tree_append(ctx,false,"Price Unit",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 25)) ~= 0 then
			ui.tree_append(ctx,false,"Contract Pointer",card.getbits(resp, pos, 5),nil,nil)
			pos = pos + 5
		end
		if bit_and(bitmap, bit_shl(1, 26)) ~= 0 then
			ui.tree_append(ctx,false,"Authenticator",card.getbits(resp, pos, 16),nil,nil)
			pos = pos + 16
		end
		if bit_and(bitmap, bit_shl(1, 27)) ~= 0 then
			local databitmap = card.getbits(resp, pos, 5)
			pos = pos + 5
			if bit_and(databitmap, bit_shl(1, 0)) then
				local days_since_1997 = card.getbits(resp, pos, 14)
				pos = pos + 14
				local date = os.date("%x", os.time{year=1997, month=1, day=1, hour=0} + days_since_1997*3600*2)
				ui.tree_append(ctx,false,"Date First Stamp", date, nil, nil)
			end
			if bit_and(databitmap, bit_shl(1, 1)) then
				local min_since_midnight = card.getbits(resp, pos, 11)
				pos = pos + 11
				ui.tree_append(ctx,false,"Time First Stamp", math.floor(min_since_midnight/60)..":"..min_since_midnight%60, nil, nil)
			end
			if bit_and(databitmap, bit_shl(1, 2)) then
				local min_since_midnight = card.getbits(resp, pos, 1)
				ui.tree_append(ctx,false,"Simulation", card.getbits(resp, pos, 1), nil, nil)
				pos = pos + 1
			end
			if bit_and(databitmap, bit_shl(1, 3)) then
				ui.tree_append(ctx,false,"Trip", card.getbits(resp, pos, 2), nil, nil)
				pos = pos + 2
			end
			if bit_and(databitmap, bit_shl(1, 4)) then
				ui.tree_append(ctx,false,"Route Direction", card.getbits(resp, pos, 2), nil, nil)
				pos = pos + 2
			end
		end
	end
	if context == "Contracts" and card.getbits(resp, 1, 16) > 0 then
		local days_since_1997 = card.getbits(resp, 86, 14)
		local date = os.date("%x", os.time{year=1997, month=1, day=1, hour=0} + days_since_1997*3600*24)
		ui.tree_append(ctx,false,"Start",date,nil,nil)
		days_since_1997 = card.getbits(resp, 100, 14)
		date = os.date("%x", os.time{year=1997, month=1, day=1, hour=0} + days_since_1997*3600*24)
		ui.tree_append(ctx,false,"End",date,nil,nil)
		local zones = card.getbits(resp, 114, 8)
		local n = 8
		local maxzone = 0
		local minzone
		while n >= 1 do
			if zones >= 2^(n-1) then
				if maxzone == 0 then
					maxzone = n
				end
				zones = zones - 2^(n-1)
				if zones == 0 then
					minzone = n
				end
			end
			n = n - 1
		end
		ui.tree_append(ctx,false,"Zones",minzone.."-"..maxzone,nil,nil)
	end
end

function process_calypso(cardenv)
	local APP
	local DF_NAME = "1TIC.ICA" 
	local lfi
	local lfi_desc
	local LFI
	local REC


	APP = ui.tree_append(cardenv,false,"application",DF_NAME,nil,nil)
	for lfi,lfi_desc in pairs(LFI_LIST) do
	        sw,resp = card.select_file("2000",8)
		if sw~=0x9000 then 
		        break
		end
		sw,resp = card.select_file(lfi,8)
		if sw==0x9000 then
	                local r
			LFI = ui.tree_append(APP,false,lfi_desc,lfi,nil,nil)
			for r=1,255 do
				sw,resp=card.read_record(0,r,0x1D)
				if sw ~= 0x9000 then
					break
				end
				REC = ui.tree_append(LFI,false,"record",r,card.bytes_size(resp),nil)	
				en1543_parse(REC,resp,lfi_desc)		
			end
		end
	end
end

card.connect()

CARD = card.tree_startup("CALYPSO")

atr = card.last_atr();
hex_card_num = card.bytes_substr(atr,card.bytes_size(atr)-7,4)
hex_card     = card.bytes_unpack(hex_card_num)
card_num     = (hex_card[1]*256*65536)+(hex_card[2]*65536)+(hex_card[3]*256)+hex_card[4]

ui.tree_append(CARD,false,"Card number",card_num,4,"hex: "..hex_card_num)

process_calypso(CARD)

card.disconnect()

