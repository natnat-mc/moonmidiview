import band, rshift, lshift from bit32 or bit or require 'moonmidiview.bit'
import insert, remove, sort from table
import floor from math

merge = (tracks) ->
	evts = {}
	nevts = 0
	for tracki=1, #tracks
		track = tracks[tracki]
		for evt in *track
			import time from evt
			evts[time] or= {}
			evt.track = tracki - 1
			insert evts[time], evt
			nevts += 1

	io.stderr\write "#{nevts} events merged\n"

	evts

transformtrack = (track) ->
	evts, i = {}, 1
	time = 0
	note = (note, channel, velocity, on) ->
		i, evts[i] = i + 1, {
			type: on and 'noteon' or 'noteoff'
			:time
			:note
			:channel
			:velocity
		}
	uspqn = (uspqn) ->
		i, evts[i] = i + 1, {
			type: 'uspqn'
			:time
			:uspqn
		}

	for evt in *track
		time += evt.deltat
		if val = evt.uspqn
			uspqn val
		else
			hi = rshift evt.type, 4
			lo = band evt.type, 0xf
			if hi == 0x9
				note evt.note, lo, evt.val, evt.val != 0
			elseif hi == 0x8
				note evt.note, lo, 0, false

	io.stderr\write "#{i-1} events kept\n"

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
		for evt in *evts[tick]
			if uspqn = evt.uspqn
				uspt = uspqn / tpqn
	merged.times = times
	merged.timesrev = timesrev
	merged.alltimes = alltimes
	io.stderr\write "ticks converted to times\n"

getactivenotes = (data) ->
	import ticks, evts, times from data
	runningnotes = {}
	activenotes = {}
	notes, ni = {}, 1
	for tick in *ticks
		time = times[tick]
		for evt in *evts[tick]
			if evt.type == 'noteon'
				note =
					channel: evt.channel + evt.track * 16
					note: evt.note
					begintick: tick
					begintime: time
				notes[ni] = note
				insert runningnotes, ni
				ni += 1
			elseif evt.type == 'noteoff'
				channel = evt.channel + evt.track * 16
				local i
				for _i, _v in ipairs runningnotes
					v = notes[_v]
					if v.channel == channel and v.note == evt.note
						v.endtick = tick
						v.endtime = time
						i = _i
				remove runningnotes, i
		activenotes[tick] = [v for v in *runningnotes]
	error "Active notes at end of data" if #runningnotes != 0
	data.activenotes = activenotes
	data.notes = notes
	io.stderr\write "#{#data.notes} total notes\n"

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
	data.evts = nil
	data.tpqn = nil
	data
