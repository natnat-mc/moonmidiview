import sub, byte from string
import lshift, rshift, band, tohex from bit32 or bit or require 'moonmidiview.bit'

tohex or= do
	hextable = {[0]: '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'}
	(num, n) ->
		s = ''
		while num != 0
			s = hextable[band num, 0xf] .. s
			num = rshift num, 4
		s = s\sub -n if n
		s

(buf) ->
	tracks = {}
	header = {}
	nevts = 0

	pos = 1
	fail = (msg) ->
		error "At offset 0x#{tohex pos-1}: #{msg}", 2
	reads = (n) ->
		pos += n
		sub buf, pos-n, pos-1
	readb = (n) ->
		pos += n
		byte buf, pos-n, pos-1
	skip = (n) ->
		pos += n
	read8 = ->
		readb 1
	read16 = ->
		hi, lo = readb 2
		(lshift hi, 8) + lo
	read24 = ->
		a, b, c = readb 3
		(lshift a, 16) + (lshift b, 8) + c
	read32 = ->
		a, b, c, d = readb 4
		(lshift a, 24) + (lshift b, 16) + (lshift c, 8) + d
	readvlen = ->
		b = readb 1
		v = band b, 0x7f
		while (band b, 0x80) == 0x80
			b = readb 1
			v = (lshift v, 7) + band b, 0x7f
		v
	checkr = (str) ->
		cnk = reads #str
		fail "Failed assertion for chunk: isn't #{str}" unless cnk == str

	do
		checkr "MThd"
		hlen = read32!
		fail "Invalid header length: #{hlen}" if hlen != 6
		fmt = read16!
		fail "Invalid MIDI format: #{fmt}" if fmt != 1 and fmt != 2 and fmt != 0
		ntrks = read16!
		division = read16!
		fail "Unsupported SMPTE/tpf" if (band division, 0x8000) == 1

		header.format = fmt
		header.tracks = ntrks
		header.tpqn = division

	for track=1, header.tracks
		events = {}

		eventi = 1
		event = (deltat, etype, evt) ->
			evt.deltat = deltat
			evt.type = etype
			events[eventi], eventi = evt, eventi + 1
			nevts += 1
			-- (require 'moon').p {:pos, :evt}
		meta = (deltat, mtype, evt) ->
			evt.meta = mtype
			event deltat, 0xff, evt

		checkr "MTrk"
		len = read32!
		endpos = pos + len
		local lastetype

		while true
			break if pos == endpos
			deltat = readvlen!
			etype = read8!
			etypehi = rshift etype, 4
			if etype == 0xf0 or etype == 0xf7
				event deltat, etype, sysex: reads readvlen!
			elseif etype == 0xff
				mtype = read8!
				mlen = readvlen!
				if mtype == 0x00
					meta deltat, mtype, seqnum: read16!
				elseif mtype == 0x01
					meta deltat, mtype, text: reads mlen
				elseif mtype == 0x02
					meta deltat, mtype, copyright: reads mlen
				elseif mtype == 0x03
					meta deltat, mtype, name: reads mlen
				elseif mtype == 0x04
					meta deltat, mtype, instrument: reads mlen
				elseif mtype == 0x05
					meta deltat, mtype, lyric: reads mlen
				elseif mtype == 0x2f
					meta deltat, mtype, end: true
				elseif mtype == 0x51
					meta deltat, mtype, uspqn: read24!
				elseif mtype == 0x58
					meta deltat, mtype, timesig: {readb 4}
				else
					meta deltat, mtype, unknown: reads mlen
			elseif etypehi == 0x8 or etypehi == 0x9 or etypehi == 0xa
				event deltat, etype, note: read8!, val: read8!
			elseif etypehi == 0xb
				event deltat, etype, controller: read8!, val: read8!
			elseif etypehi == 0xc
				event deltat, etype, program: read8!
			elseif etypehi == 0xd
				event deltat, etype, val: read8!
			elseif etypehi == 0xe
				event deltat, etype, val: (lshift read8!, 7) + read8!
			else
				fail "Unknown event, type 0x#{tohex etype}" unless lastetype
				lastetypehi = rshift lastetype, 4
				if lastetypehi == 0x8 or lastetypehi == 0x9 or lastetypehi == 0xa
					event deltat, lastetype, note: etype, val: read8!
				elseif lastetypehi == 0xb
					event deltat, lastetype, controller: etype, val: read8!
				elseif lastetypehi == 0xc
					event deltat, lastetype, program: etype
				elseif lastetypehi == 0xd
					event deltat, lastetype, val: etype
				elseif lastetypehi == 0xe
					event deltat, lastetype, val: (lshift etype, 7) + read8!
				else
					fail "Unsupported non-legit event #{tohex etype} after #{tohex lastetype}"
				etype = lastetype
			lastetype = etype

		tracks[track] = events

	io.stderr\write "#{header.tracks} tracks, #{nevts} events\n"

	{:header, :tracks}
