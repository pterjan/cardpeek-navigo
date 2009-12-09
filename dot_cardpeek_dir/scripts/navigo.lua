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
  "Bus",
  "Metro",
  "Train/RER"
}

TRANSITION_LIST = {
  [1] = "Entry",
  [2] = "Exit",
  [7] = "RER to Metro"
}

dofile "metro.lua"
dofile "banlieue.lua"

function en1543_parse(ctx,resp,context)
	ui.tree_append(ctx,true,resp,nil,nil,nil)
	if context == "Events logs" or context == "Special events" then

		local min_since_midnight = card.getbits(resp, 15, 11)
		local days_since_1997 = card.getbits(resp, 1, 14)
		local date = os.date("%x %X", os.time{year=1997, month=1, day=1, hour=0} + days_since_1997*3600*24+min_since_midnight*60)
		ui.tree_append(ctx,false,"Date",date,nil,nil)

		local transport_id = card.getbits(resp, 53, 4)
		local transport = TRANSPORT_LIST[transport_id+1]
		if transport then
			ui.tree_append(ctx,false,"Transport",transport,nil,nil)
		end

		local station

		if transport_id == 0 then
			if card.getbits(resp, 62, 7) == 1 then 
				ui.tree_append(ctx,false,"Bus line",card.getbits(resp, 110, 8), nil, nil)
			end
			local bus_id = card.getbits(resp, 121+card.getbits(resp, 41, 2)*16, 13)
			ui.tree_append(ctx,false,"Bus number", bus_id, nil, nil)
		end

		if transport_id > 0 then
			local transition_id = card.getbits(resp, 58, 4)
			local sector_id = card.getbits(resp, 70, 7)
			local sector
			if transport_id == 1 or (transport_id == 2 and transition_id == 7) then
				sector = METRO_LIST[sector_id]
				ui.tree_append(ctx,false,"Sector",sector["name"],nil,nil)
			end
			if transport_id == 2 then
				sector = BANLIEUE_LIST[sector_id]
				local network = BANLIEUE_NET_LIST[math.floor(sector_id/10)]
				if network then
					ui.tree_append(ctx,false,"Network",network,nil,nil)
				end
			end
			if sector then
				local station_id = card.getbits(resp, 77, 5)
				station = sector[station_id]
				if station then
					ui.tree_append(ctx,false,"Station",station,nil,nil)
				end
			end
			local transition = TRANSITION_LIST[transition_id]
			if transition then
				ui.tree_append(ctx,false,"Transition",transition,nil,nil)
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

