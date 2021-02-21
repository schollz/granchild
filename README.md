# granchild

sequence sample granules

https://vimeo.com/514823601

granchild is a granular grandchild. this script was born out of and inspired by @cfdrake's clever [twine](https://llllllll.co/t/twine-random-granulator/41703) and @justmat's inspiring [mangl](https://llllllll.co/t/mangl/21066/307), both themselves based on @artfwo's amazing [glut](https://llllllll.co/t/glut/21175) script, which itself was inspired by @kasperskov's [granfields](https://llllllll.co/t/grainfields-8-voice-granular-synthesizer-for-128-grids-m4l-update/5164). i consider this script to be a grandchild of @artfwo's script, and child of the other two - merging some of the things from @cfdrake's twine (randomization in parameters) and some things from @justmat's script (lfos, greyhole integration), to make a granular sequencer exactly how i envision.

there are a lot of granulation scripts based on glut now, here's what's different about *granchild* (these differences are mainly due to morphing the script to fit my personal musical journey):

- "jitter" and "spread" of granulation always oscillate, with random frequencies
- "size" and "density" of granulation are quantized, and easily accessed (see layout)
- sequencer is quantized (using @tyleretter's lattice)
- voices limited to only 4

### Requirements

- norns
- grid optional 

### Documentation

here's how the buttons are laid out. use e2 and e3 on the norns to move around and k2/k3 to toggle things. the grid just mirrors the norns screen, so this script works just fine without a grid.

![granchild_grid-01](https://user-images.githubusercontent.com/6550035/108614271-f6146400-73ad-11eb-99e8-6bddeae8f892.jpg)


### Install

from maiden:

```
;install https://github.com/schollz/granchild
```