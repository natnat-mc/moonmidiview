-- imports
import p from require 'moon'
parse = require 'moonmidiview.parse'
transform = require 'moonmidiview.transform'
import linewise, video from require 'moonmidiview.render'

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

-- image
--image = linewise trans, OPTS
--import img, width, height from image
--fd = io.open 'test.rgb', 'wb'
--fd\write img
--fd\close!
--fd = io.open 'test.size', 'w'
--fd\write "#{width}x#{height}\n"
--fd\close!

-- video
--os.remove 'test.mp4'
--video = video image, OPTS, 'test.mp4'
--import filename, width, height, framelen from video

os.remove 'test.mp4'
video trans, OPTS, 'test.mp4'
