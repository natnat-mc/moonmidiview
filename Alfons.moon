tasks:
	compile: =>
		sh 'moonc . && rm Alfons.lua'

	luapuc: =>
		sh 'rm test.mp4'
		sh 'time lua5.3 test.lua'
	luajit: =>
		sh 'rm test.mp4'
		sh 'time luajit test.lua'

	convert: =>
		sh 'convert -size `cat test.size` -depth 8 test.rgb -rotate -90 test.png'
	display: =>
		sh 'display test.png'

	dopuc: =>
		tasks.compile!
		tasks.luapuc!
	dojit: =>
		tasks.compile!
		tasks.luajit!

	allpuc: =>
		tasks.dopuc!
		tasks.convert!
	alljit: =>
		tasks.dojit!
		tasks.convert!
