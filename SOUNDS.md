# Sound assets

## Built-in animal clips

These are references to audio already installed with WoW, not redistributed sound files. FileDataIDs and filenames were checked against wowdev's [verified listfile release 202610182335](https://github.com/wowdev/wow-listfile/releases/tag/202610182335). File presence in a particular Forever client and audible playback still require an in-game check. Idle/fidget/short vocalizations are used where available; these are basic animal cues, not recordings specific to pet happiness.

The family ID is resolved to the client's localized name using [C_CreatureInfo.GetCreatureFamilyInfo](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_APIDocumentationGenerated/CreatureInfoDocumentation.lua). A family name is never taken from the pet's player-assigned name.

| Family ID | Animal family | FileDataID | Verified filename |
| --- | --- | --- | --- |
| 1 | Wolf | 564223 | `sound/creature/wolf/mwolffidget2a.ogg` |
| 2 | Cat | 562388 | `sound/creature/tiger/mtigerstand2a.ogg` |
| 3 | Spider | 561418 | `sound/creature/tarantula/mtarantulafidget2a.ogg` |
| 4 | Bear | 544959 | `sound/creature/bear/mbearaggroa.ogg` |
| 5 | Boar | 545134 | `sound/creature/boar/mwildboaraggro1.ogg` |
| 6 | Crocolisk | 544686 | `sound/creature/babycrocodile/babycrocodileclick1.ogg` |
| 7 | Carrion Bird | 545937 | `sound/creature/carrion/mcarrionaggroa.ogg` |
| 8 | Crab | 546432 | `sound/creature/crab/crabpreaggro.ogg` |
| 9 | Gorilla | 550961 | `sound/creature/gorilla/gorillastandvar3.ogg` |
| 11 | Raptor | 558881 | `sound/creature/raptorpet/raptorpetclickable_01.ogg` |
| 12 | Tallstrider | 561393 | `sound/creature/tallstrider/tallstriderpreaggroa.ogg` |
| 20 | Scorpid | 547809 | `sound/creature/durotarscorpion/pet_durotarscorpion_clickable01.ogg` |
| 21 | Turtle | 559872 | `sound/creature/seaturtle/seaturtlepreaggro.ogg` |
| 24 | Bat | 548728 | `sound/creature/felbat/felbatpreaggro.ogg` |
| 25 | Hyena | 552343 | `sound/creature/hyena/hyenapreaggroa.ogg` |
| 26 | Bird of Prey | 557971 | `sound/creature/owl/owlpreaggro.ogg` |
| 27 | Wind Serpent | 564133 | `sound/creature/windserpant/mwindserpantstand1a.ogg` |
| 45 | Core Hound | 546376 | `sound/creature/corehoundpet/corehoundpup_clickable_01.ogg` |
| 50 | Fox | 555465 | `sound/creature/mistfox/mistfox_preaggro_01.ogg` |
| — | Generic fallback | 567525 | `sound/interface/ieating1.ogg` |

## Original womp-womp clip

`Sounds/womp-womp.ogg` is a 1.85-second, mono, 44.1 kHz Vorbis clip synthesized for this addon. It is an original two-note sad-brass cue, with no third-party audio sample. The audio and its source generator are covered by the project's MIT license.

Rebuild with Python and FFmpeg installed:

```sh
python tools/generate_womp.py
```

The generator uses additive synthesis, falling pitch, a closing brass filter, short room reflections, and a conservative peak level. There is no speech. It is played once on a confirmed transition into Unhappy (red), not continuously while red. `/petxp sound off` silences both this clip and the animal cues.
