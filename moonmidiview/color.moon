import pow, floor, abs, max, min from math

-- sRGB <-> lRGB
s2l = (x) ->
	x /= 255
	if x <= .04045
		x / 12.92
	else
		pow (x+.055) / 1.055, 2.4

l2s = (x) ->
	v = if x <= .0031308
		x * 12.92
	else
		(pow x, 1/2.5) * 1.055 - .055
	floor v * 255 + .5

srgb2lrgb = (sr, sg, sb) ->
	(s2l sr), (s2l sg), (s2l sb)

lrgb2srgb = (r, g, b) ->
	(l2s r), (l2s g), (l2s b)

-- HSV <-> lRGB
hsv2lrgb = (h, s, v) ->
	c = v * s
	h_ = h / 60
	x = c * (1 - abs h_ % 2 - 1)
	r1, g1, b1 = if h_ <=1
		c, x, 0
	elseif h_ <= 2
		x, c, 0
	elseif h_ <= 3
		0, c, x
	elseif h_ <= 4
		0, x, c
	elseif h_ <= 5
		x, 0, c
	elseif h_ <= 6
		c, 0, x
	else
		0, 0, 0
	m = v - c
	r1 + m, g1 + m, b1 + m

lrgb2hsv = (r, g, b) ->
	xmax = max r, g, b
	xmin = min r, g, b
	v = xmax
	c = xmax - xmin
	l = (xmax + xmin) / 2
	h = if c == 0
		0
	elseif v == r
		60 * (0 + (g - b) / c)
	elseif v == g
		60 * (2 + (b - r) / c)
	elseif v == b
		60 * (4 + (r - g) / c)
	else
		error "unreachable"
	h %= 360
	s = if v == 0
		0
	else
		c / v
	h, s, v

-- HSV <-> sRGB
hsv2srgb = (h, s, v) ->
	r, g, b = hsv2lrgb h, s, v
	lrgb2srgb r, g, b

srgb2hsv = (sr, sg, sb) ->
	r, g, b = srgb2lrgb sr, sg, sb
	lrgb2hsv r, g, b

-- table operations
srgb2lrgbt = (srgb) ->
	{sr, sg, sb} = srgb
	r, g, b = srgb2lrgb sr, sg, sb
	{r, g, b}

lrgb2srgbt = (rgb) ->
	{r, g, b} = rgb
	sr, sg, sb = lrgb2srgb r, g, b
	{sr, sg, sb}

hsv2lrgbt = (hsv) ->
	{h, s, v} = hsv
	r, g, b = hsv2lrgb h, s, v
	{r, g, b}

hsv2srgbt = (hsv) ->
	{h, s, v} = hsv
	r, g, b = hsv2lrgb h, s, v
	sr, sg, sb = lrgb2srgb r, g, b
	{sr, sg, sb}

srgb2hsvt = (srgb) ->
	{sr, sg, sb} = srgb
	r, g, b = srgb2hsv sr, sg, sb
	h, s, v = lrgb2hsv r, g, b
	{h, s, v}

lrgb2hsvt = (rgb) ->
	{r, g, b} = rgb
	h, s, v = lrgb2hsv r, g, b
	{h, s, v}

{
	-- individual component gamma
	:s2l, :l2s

	-- sRGB <-> lRGB
	:srgb2lrgb, :lrgb2srgb

	-- HSV <-> lRGB
	:hsv2lrgb, :lrgb2hsv

	-- HSV <-> sRGB
	:hsv2srgb, :srgb2hsv

	-- table operations
	:srgb2lrgbt, :lrgb2srgbt
	:hsv2lrgbt, :lrgb2hsvt
	:hsv2srgbt, :srgb2hsvt
}
