-- imports
import p from require 'moon'
parse = require 'moonmidiview.parse'
transform = require 'moonmidiview.transform'
import mkvideo from require 'moonmidiview.render'

-- options
OPTS =
	notewidth: 3
	linesperframe: 2
	visibleframes: 103
OPTS = preset: '1080p'

-- read stuff
filename = ...
filename or= '/home/codinget/tmp/U.N. Owen.mid'
fd = io.open filename, 'rb'
data = fd\read '*a'
fd\close!

-- parse
before = os.time!
midi = parse data
trans = transform midi
after = os.time!

-- build
os.remove 'test.mp4'
mkvideo trans, OPTS, 'test.mp4'
