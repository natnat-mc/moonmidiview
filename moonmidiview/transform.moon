import band, rshift, lshift from bit32 or bit or require 'moonmidiview.bit'
import NOTEON, NOTEOFF, USPQN, miditransevt, miditransnote, buffertype from require 'moonmidiview.ffi'
import insert, remove, sort from table
import floor from math

evtbuf = buffertype 'miditransevt_t'
notebuf = buffertype 'miditransote_t'

merge = (tracks) ->
	evts = {}
	nevts = 0
	for tracki=1, #tracks
		track = tracks[tracki]
		for evt in track\values!
			import time from evt
			evts[time] or= evtbuf!
			evt.track = tracki - 1
			evts[time]\push evt
			nevts += 1
		track\free!

	io.stderr\write "#{nevts} events merged\n"
	evts

transformtrack = (track) ->
	evts = evtbuf!
	time = 0
	local note, uspqn
	note = (note, channel, velocity, on) ->
		evts\push miditransevt
			type: on and NOTEON or NOTEOFF
			:time
			:note
			:channel
			:velocity
	uspqn = (uspqn) ->
		evts\push miditransevt
			type: USPQN
			:time
			:uspqn

	for evt in track\values!
		time += evt.deltat
		if evt.type == 0xff and evt.meta == 51
			uspqn evt.uspqn
		else
			hi = rshift evt.type, 4
			lo = band evt.type, 0xf
			if hi == 0x9
				note evt.note, lo, evt.val, evt.val != 0
			elseif hi == 0x8
				note evt.note, lo, 0, false

	io.stderr\write "#{evts.len} events kept\n"
	track\free!
	evts

tickstotimes = (merged) ->
	import ticks, evts, tpqn from merged
	uspqn = 1e6 / 120 * 60 -- default according to spec
	uspt = uspqn / tpqn
	times, timesrev, alltimes, lasttime, lasttick, i = {}, {}, {}, 0, 0, 1
	for tick in *ticks
		deltat = tick - lasttick
		lasttick = tick
		lasttime += floor deltat * uspt
		times[tick] = lasttime
		timesrev[lasttime] = tick
		alltimes[i], i = lasttime, i + 1
		for evt in evts[tick]\values!
			if evt.type == USPQN
				uspt = evt.uspqn / tpqn
	merged.times = times
	merged.timesrev = timesrev
	merged.alltimes = alltimes
	io.stderr\write "ticks converted to times\n"

getactivenotes = (data) ->
	import ticks, evts, times from data
	runningnotes = {}
	activenotes = {}
	notes = notebuf!
	for tick in *ticks
		time = times[tick]
		for evt in evts[tick]\values!
			if evt.type == NOTEON
				note = miditransnote
					channel: evt.channel + evt.track * 16
					note: evt.note
					begintick: tick
					begintime: time
				ni = notes\push note
				insert runningnotes, ni
			elseif evt.type == NOTEOFF
				channel = evt.channel + evt.track * 16
				local i
				for _i, _v in ipairs runningnotes
					v = notes\get _v
					if v.channel == channel and v.note == evt.note
						v.endtick = tick
						v.endtime = time
						i = _i
				remove runningnotes, i
		activenotes[tick] = [v for v in *runningnotes]
	error "Active notes at end of data" if #runningnotes != 0
	data.activenotes = activenotes
	data.notes = notes
	io.stderr\write "#{notes.len} total notes\n"

(midi) ->
	import tracks from midi
	import tpqn from midi.header
	evts = merge [transformtrack track for track in *tracks]
	ticks = [k for k in pairs evts]
	sort ticks
	ticksrev = {v, i for i, v in ipairs ticks}
	data = {:ticks, :ticksrev, :evts, :tpqn}
	tickstotimes data
	getactivenotes data
	evtp\free! for _, evtp in pairs evts
	data.evts = nil
	data.tpqn = nil
	collectgarbage()
	collectgarbage()
	data
