identity = (...) -> ...

NOTEON, NOTEOFF, USPQN = 1, 2, 3

midiparseevt = identity
miditransevt = identity
miditransnote = identity

buffertype = do
	c = class
		new: =>
			@len = 0
		push: (e) =>
			@len += 1
			@[@len] = e
			@len
		free: =>

		values: =>
			i = 1
			->
				v = @[i]
				i += 1
				v

		get: (i) =>
			rawget @, i
			@[i]
		set: (i, e) =>
			rawset @, i, e

		__len: =>
			@len

	(tname) -> c

image = do
	import char, byte from string
	class
		new: (@w, @h) =>
			@data = {}
			z = char 0, 0, 0
			@data[i] = z for i=1, @w*@h
		put: (x, y, r, g, b) =>
			i = y*@w+x+1
			@data[i] = char r, g, b
		putt: (x, y, rgb) =>
			{r, g, b} = rgb
			@put x, y, r, g, b
		get: (x, y) =>
			byte @data[y*@w+x+1], 1, 3
		get_compiled: (x, y) =>
			i = (y*@w+x)*3 + 1
			byte @data, i, i+2
		sub: (st, len) =>
			@data\sub st, st+len-1
		compile: =>
			return if (type @data) == 'string'
			@data = table.concat @data, '', 1, @w*@h
			@get = @get_compiled
		free: =>

pcall ->
	ffi or= require 'ffi'
	error "no ffi implementation" unless ffi
	import C from ffi

	typedef = (name, code, mt) ->
		ffi.cdef "typedef #{code} #{name}"
		if mt
			ffi.metatype name, mt
		else
			ffi.typeof name

	ffi.cdef [[
		void* malloc(size_t);
		void* realloc(void*, size_t);
		void free(void*);
		void* memset(void*, int, size_t);
	]]

	midiparseevt = typedef 'midiparseevt_t', [[
		struct {
			uint32_t deltat;
			uint8_t type;
			uint8_t meta;
			union {
				struct {
					uint8_t val;
					uint8_t note;
				};
				struct {
					uint32_t uspqn;
				};
			};
		}
	]]
	miditransevt = typedef 'miditransevt_t', [[
		struct {
			uint32_t time;
			uint16_t track;
			uint8_t type;
			union {
				struct {
					uint32_t channel;
					uint8_t velocity;
					uint8_t note;
				};
				struct {
					uint32_t uspqn;
				};
			};
		}
	]]
	miditransnote = typedef 'miditransote_t', [[
		struct {
			uint32_t begintick;
			uint32_t begintime;
			uint32_t endtick;
			uint32_t endtime;
			uint32_t channel;
			uint8_t note;
			uint8_t velocity;
		}
	]]

	buffertype = (tname) ->
		size = ffi.sizeof tname
		buftype = ffi.typeof "#{tname}*"

		class
			new: =>
				rawset @, 'buf', ffi.cast buftype, C.malloc size
				rawset @, 'len', 0
				rawset @, 'alloc', 1
				error "Failed to allocate buffer" if (tonumber ffi.cast 'intptr_t', @buf) == 0
			free: =>
				return if @alloc == 0
				C.free @buf
				@alloc = 0
				@buf = nil
			__gc: =>
				@free!

			push: (e) =>
				if @len == @alloc
					alloc = @alloc * 2
					buf = ffi.cast buftype, C.realloc @buf, alloc * size
					error "Failed to resize buffer" if (tonumber ffi.cast 'intptr_t', buf) == 0
					@alloc = alloc
					@buf = buf

				@buf[@len] = e
				@len += 1
				@len

			values: =>
				i = 0
				l = @len
				b = @buf
				->
					if i == l
						nil
					else
						v = b[i]
						i += 1
						v

			get: (i) =>
				@buf[i-1]
			set: (i, e) =>
				@buf[i-1] = e

			__len: =>
				@len

	image = do
		ty = ffi.typeof 'unsigned char*'
		class
			new: (@w, @h) =>
				@data = ffi.cast ty, C.malloc @w*@h*3
				error "Failed to allocate buffer" if (tonumber ffi.cast 'intptr_t', @data) == 0
				C.memset @data, 0, @w*@h*3
			put: (x, y, r, g, b) =>
				i = (y*@w+x) * 3
				@data[i], @data[i+1], @data[i+2] = r, g, b
			putt: (x, y, rgb) =>
				{r, g, b} = rgb
				@put x, y, r, g, b
			get: (x, y) =>
				i = (y*@w+x) * 3
				@data[i], @data[i+1], @data[i+2]
			sub: (st, len) =>
				size = @w*@h*3
				ed = st+len-1
				if ed > size
					len -= (ed - size)
				ffi.string @data+(st-1), len
			compile: =>
			free: =>
				return if @data == nil
				C.free @data
				@data = nil
			__gc: =>
				@free!

	io.stderr\write "Using ffi types\n"

{
	:NOTEON, :NOTEOFF, :USPQN
	:miditransnote, :miditransevt, :midiparseevt
	:buffertype
	:image
}
