# Volume boost to 200%

Where mpv plays (Windows and Linux), the player's volume goes from 0% to 200%, as VLC's does. 100% is the film's own level. Anything above it is a boost, drawn in amber on the bar, and the control warns that it can distort. On Android (Media3) the volume still stops at 100%. The Android section below explains why.

## How mpv amplifies

mpv's `volume` property is a software gain on the decoded sound. 0 is silence and 100 leaves the level unchanged. mpv refuses any value above `volume-max`, which defaults to 130. Skrin sets `volume-max` to 200 in `BASE_MPV_OPTIONS` (`src/player/mpvOptions.ts`), and `engine.ts` `setVolume` sends the level with `set volume <n>` as before. There is no second audio path and no Web Audio.

mpv's volume follows a cubic curve: gain = (volume / 100)³. The boost is therefore stronger than the percentage suggests:

| Control | Amplitude | About |
|---|---|---|
| 100% | 1× | 0 dB |
| 150% | 3.4× | +10.6 dB |
| 200% | 8× | +18 dB |

Android's plugin already maps 0–100 onto the same cubic curve (`Media3Plugin.kt` `applyVolume`), so equal settings sound alike on both engines.

## Desktop implementation

- `src/player/volume.ts`: `VOLUME_NORMAL` (100) and `VOLUME_MAX` (200). `clampVolume(value, max)` keeps 5% steps between 0 and `max`. `savedVolume(max)` reads the remembered setting. A value saved by an older version (0–100) is read unchanged, and anything out of range is clamped. `volumeBar` and `levelOnBar` map between a level and a share of the bar.
- `src/player/engine.ts`: `volumeMax()` returns 200 on mpv and 100 on Media3. `setVolume` never sends Media3 more than 100.
- `src/player/useVolume.ts`: clamps every change (keys, wheel, remote, mouse drag) to `volumeMax()` and returns `max` for the control.
- `src/player/VolumeControl.tsx` + `src/ui/ui.css`: the bar is filled as `level / max`, so 200% fills the bar exactly and never overflows it. A mark at 100% shows the film's own level, and the part above it is amber. A boosted level also shows in amber, says ", boosted" in its accessible name, and adds a clipping warning to its tooltip and pop-up. The warning's space is kept whether or not it shows, so the bar stays still while a drag crosses 100%.

The keys are unchanged: `-`/`9` turn it down, `+`/`=`/`0` turn it up, `m` mutes, the mouse wheel works over the control and over the picture, and a remote uses Up/Down on the control. They now go up to 200%.

## Passthrough

When the sound goes to a receiver as an untouched bitstream (`audio-out-params/format` starts with `spdif-`, so `soundGoesUntouched()` is true), there is no PCM for mpv to amplify. In that case, as before:

- the control says "Use the receiver's volume", and the volume keys leave the level alone;
- no boost is shown or claimed;
- `audio-spdif` and the passthrough setup are untouched, so Dolby TrueHD, DTS-HD/DTS:X and Atmos still go out bit for bit.

The level stays saved. If a later film is decoded, it plays at that level, which may be a boost.

## Android (Media3): not boosted

`ExoPlayer.setVolume` takes a gain from 0 to 1. The plugin maps 0–100 onto it and clamps there, so Media3 has no gain above the film's level. On Android:

- `volumeMax()` is 100, so the control, keys and wheel stop at 100%. The page never shows a boost the sound does not get.
- `engine.setVolume` caps the value sent to `plugin:media3|set_volume` at 100, even if a level saved at 150% on a computer is somehow read.

Android support would need native work. One way is a custom Media3 `AudioProcessor` in the plugin's own `DefaultAudioSink`. It would apply the gain only to decoded PCM and do nothing when the sound leaves untouched or offloaded. `volumeMax()` would then return 200 on Media3 as well. None of this is implemented or tested.

## Clipping and distortion

Every boost raises peaks along with the quiet parts. A film mastered close to full scale clips at once above 100%, and on cubic gain 200% is +18 dB. Clipping sounds harsh and crackly and can strain small speakers. Skrin adds no limiter, because one would change the sound at every level and its effect on playback has not been tested. The control warns when the level is above 100%. The source files are never changed, and the gain only exists inside mpv's playback.

## Testing

Automated:

```
npm run check                                          # tsc, eslint, vitest
npx playwright test --project=edge e2e/player.e2e.ts e2e/mouse.e2e.ts e2e/android-player.e2e.ts
```

- `src/player/volume.test.ts`: 0, 50, 100, 150 and 200; below 0 and above 200; 5% steps; the remembered level (boosted, older 0–100 values, junk, out of range, and a 100% top); the bar's share at each level; and pointer height to level.
- `src/player/mpvOptions.test.ts`: `volume-max` equals `VOLUME_MAX`, and the base options add no audio filter or passthrough change.
- `e2e/player.e2e.ts` "the volume boost": keys up past 100 to the 200 cap and back, the saved setting, the level carried to the next episode, a click on the bar's middle (100) and top (200), and a receiver bitstream (no boost claimed, keys inert).
- `e2e/android-player.e2e.ts`: Media3 stays at 100 when turned up.

By hand, on a real build (not covered above, since the fake mpv does not enforce `volume-max`):

1. Play a quiet stereo file and turn the volume up to 150% and 200%. It should get louder. The log should show no `volume` errors.
2. Restart the app and confirm the level comes back.
3. Play a TrueHD/Atmos or DTS-HD file with passthrough on to a receiver. The control should say the receiver has the volume, and the receiver should still show the format.
