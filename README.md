# granchild

quantized granulation

https://vimeo.com/514823601

granchild is a granular grandchild. this script was born out of and inspired by @cfd90's clever [twine](https://llllllll.co/t/twine-random-granulator/41703) and @justmat's inspiring [mangl](https://llllllll.co/t/mangl/21066/307), both themselves based on @artfwo's amazing [glut](https://llllllll.co/t/glut/21175) script, which itself was inspired by @kasperskov's [grainfields](https://llllllll.co/t/grainfields-8-voice-granular-synthesizer-for-128-grids-m4l-update/5164). i consider this script to be a grandchild of glut, and child of the other two - using some ideas from twine (randomization in parameters) and some code from mangl (lfos, greyhole integration) and the engine of glut, to make a granular sequencer to fit my personal musical journey.

their are a lot of granulation scripts based on glut, here's what's different about *granchild*:

- "jitter" and "spread" of granulation always oscillate, with random frequencies
- "size" and "density" of granulation are quantized, and easily accessed (see layout)
- sequencer is quantized (using @tyleretters's lattice)
- voices limited to only 4
- samples mapped to 21 keys 
- can record live input

reference in that demo video above - here are the four samples used. first two are things i recorded with [mx.samples](https://llllllll.co/t/mx-samples/41400), the other two are samples @tehn included on the default norns:


### Requirements

- norns
- grid optional 

### Documentation

here's how the buttons are laid out. use e2 and e3 on the norns to move around and k2/k3 to toggle things. the grid just mirrors the norns screen, so this script works just fine without a grid.

![granchild_grid-01](https://user-images.githubusercontent.com/6550035/108640397-40e5b880-744e-11eb-93da-83bda151e44d.jpg)

_note:_ when you use the record button for live input, all recordings are automatically saved permanently in `~/dust/audio/granchild`.

### Install

from maiden:

```
;install https://github.com/schollz/granchild
```
