import band, rshift, lshift from bit32 or bit or require 'moonmidiview.bit'
import image from require 'moonmidiview.ffi'
import hsv2srgb, srgb2hsv from require 'moonmidiview.color'
import char, byte, sub, rep from string
import floor, ceil, max, huge from math
import concat from table

LINESPERFRAME = 1
NOTEWIDTH = 1
FPS = 60
COLORS = {'f00', '0f0', '00f', 'ff0', 'f0f', '0ff', 'f80', '8f0', 'f08', '80f', '0f8', '08f'}
KEYBOARDCOLORS = {'aaa', '555'}
BGCOLOR = '000'
VISIBLEFRAMES = 60
KEYBOARDHEIGHT = 10
GRADIENT = true
QUANTIZE = true
HOLLOW = false

hextable = {(tostring i), i for i=0, 9}
hextable.a = 10
hextable.b = 11
hextable.c = 12
hextable.d = 13
hextable.e = 14
hextable.f = 15

decodecolor = (clr) ->
	switch type clr
		when 'number'
			{(band 0xff, rshift clr, 16), (band 0xff, rshift clr, 8), (band 0xff, clr)}
		when 'table'
			error "Invalid color table format" unless #clr == 3
			clr
		when 'string'
			clr = clr\sub 2 if '#' == clr\sub 1, 1
			clr = clr\lower!
			if #clr == 3
				a, b, c = clr\byte 1, 3
				clr = char a, a, b, b, c, c
			error "Invalid color string format" unless #clr == 6 and clr\match '^[0-9a-f]+$'
			val = 0
			for i=1, 6
				val = 16 * val + hextable[clr\sub i, i]
			decodecolor val
		else
			error "Invalid type for color format"

frameno = (time, fps, st) ->
	t = time * fps / 1e6
	if st
		floor t
	else
		ceil t

framecount = (data, fps) ->
	lasttick = data.ticks[#data.ticks]
	lasttime = data.times[lasttick]
	frameno lasttime, fps, false

getkeyboardcolor = (note, colors) ->
	{r, g, b} = colors[({1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 2, 1})[note % 12 + 1]]
	r, g, b

dooptions = (opts={}) ->
	switch opts.preset
		when '72p'
			opts.linesperframe = 2
			opts.notewidth = 1
			opts.keyboardheight = 8
			opts.fps = 60
			opts.visibleframes = floor (72-8) / 2
		when '144p'
			opts.linesperframe = 4
			opts.notewidth = 2
			opts.keyboardheight = 16
			opts.fps = 60
			opts.visibleframes = floor (144-16) / 4
		when '720p'
			opts.linesperframe = 10
			opts.notewidth = 10
			opts.keyboardheight = 40
			opts.fps = 60
			opts.visibleframes = floor (720-40) / 10
		when '1080p'
			opts.linesperframe = 15
			opts.notewidth = 15
			opts.keyboardheight = 60
			opts.fps = 60
			opts.visibleframes = floor (1080-60) / 15

	opts.linesperframe = LINESPERFRAME if opts.linesperframe == nil
	opts.colors = COLORS if opts.colors == nil
	opts.notewidth = NOTEWIDTH if opts.notewidth == nil
	opts.fps = FPS if opts.fps == nil
	opts.bgcolor = BGCOLOR if opts.bgcolor == nil
	opts.visibleframes = VISIBLEFRAMES if opts.visibleframes == nil
	opts.keyboardheight = KEYBOARDHEIGHT if opts.keyboardheight == nil
	opts.keyboardcolors = KEYBOARDCOLORS if opts.keyboardcolors == nil
	opts.gradient = GRADIENT if opts.gradient == nil
	opts.quantize = QUANTIZE if opts.quantize == nil
	opts.hollow = HOLLOW if opts.hollow == nil

	opts.hollow = false if opts.gradient

	opts.colors = [decodecolor c for c in *opts.colors]
	opts.bgcolor = decodecolor opts.bgcolor
	opts.keyboardcolors = [decodecolor c for c in *opts.keyboardcolors]

	opts

mkimage = (data, opts) ->
	import linesperframe, colors, notewidth, fps, bgcolor, gradient, quantize, hollow from dooptions opts
	numframes = framecount data, fps
	lasttime = data.times[data.ticks[#data.ticks]] + floor 1000/fps - 1
	firsttime = 0
	height = numframes * linesperframe
	width = 128 * notewidth

	gradient = false if notewidth < 3

	collectgarbage!
	collectgarbage!

	img = image width, height
	for note in data.notes\values!
		import note, begintime, endtime, channel from note
		beginy = floor begintime / lasttime * height
		endy = if quantize
			deltat = endtime - begintime
			len = floor deltat * height / lasttime
			if len==0
				beginy
			else
				beginy + len - 1
		else
			floor endtime / lasttime * height
		beginx = note * notewidth
		endx = beginx + notewidth - 1
		color = colors[channel % #colors + 1]

		if hollow or gradient
			for y=beginy, endy
				img\putt beginx, y, color
			if notewidth > 1
				for y=beginy, endy
					img\putt endx, y, color
			for x=beginx, endx
				img\putt x, beginy, color
				img\putt x, endy, color
			if gradient
				beginy += 1
				beginx += 1
				endx -= 1
				endy -= 1
				clen = endy - beginy + 1
				if beginy <= endy
					{sr, sg, sb} = color
					h, s, v = srgb2hsv sr, sg, sb
					for i=0, clen-1
						pct = i / clen / 2 + .25
						sr, sg, sb = hsv2srgb h, pct, 1-pct
						for x=beginx, endx
							img\put x, beginy+i, sr, sg, sb
		else
			for x=beginx, endx
				for y=beginy, endy
					img\putt x, y, color
	img\compile!

	{ :img, :numframes, :width, :height }

mkvideo = (data, opts, filename) ->
	freeimg = false
	if (type data) == 'table' and data.activenotes
		data = mkimage data, opts
		freeimg = true
	elseif (type data) != 'table' or not data.img
		error "Wrong format for data"
	import visibleframes, linesperframe, notewidth, keyboardheight, keyboardcolors from dooptions opts
	import img, numframes, width from data

	collectgarbage!
	collectgarbage!

	oneframe = width * linesperframe * 3
	framelen = oneframe * visibleframes
	ZERO = rep (char 0), framelen

	getnotecolor = (note, frame) ->
		img\get note*notewidth, frame*linesperframe

	height = linesperframe * visibleframes + keyboardheight
	fd = assert io.popen "ffmpeg -r 60 -pix_fmt rgb24 -s #{width}x#{height} -c:v rawvideo -f image2pipe -frame_size #{width*height*3} -i - -vf vflip -r 60 '#{filename}'", 'w'
	for i=0, numframes-1
		offset = i * oneframe + 1
		io.stderr\write "video frame #{i}/#{numframes-1}/#{i/(numframes-1)*100}% -> bytes #{offset-1}-#{offset+framelen-1} (#{framelen})/ #{#img}\n"

		if keyboardheight and keyboardheight > 0
			line, linei = {}, 1
			for note=0, 127
				r, g, b = getnotecolor note, i
				if r == 0 and g == 0 and b == 0
					r, g, b = getkeyboardcolor note, keyboardcolors
				b = rep (char r, g, b), notewidth
				line[linei], linei = b, linei + 1
			line = concat line
			assert fd\write rep line, keyboardheight

		frame = img\sub offset, framelen
		assert fd\write frame
		currlen = #frame
		if currlen < framelen
			pad = sub ZERO, currlen - framelen
			assert fd\write pad

		if i%1000 == 0
			collectgarbage!
			collectgarbage!
	fd\close!
	img\free! if freeimg

	framelen = width * height * 3
	{ :filename, :numframes, :width, :height, :framelen }

{
	:dooptions
	:mkimage, :mkvideo
}
