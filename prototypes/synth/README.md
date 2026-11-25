<!-- PROTOTYPE - NOT FOR PRODUCTION -->
# Synth

**Hypothesis:** one dependency-free Web Audio file can produce rich music and SFX for a browser game.

**Status:** in-progress.

## Run
- Demo: open `index.html` in a browser.
- Self-check: `node check.js`. It renders every preset offline and asserts each one makes sound. It also saves a screenshot to `production/qa/evidence/synth-demo.png`.

## Use in a game
```html
<script src="synth.js"></script>
<script>
  const synth = new Synth();                      // call play() after a click/key: browsers block audio before one
  synth.play('laser', 'C5', 0.2);                 // preset, note (name or MIDI), seconds
  synth.play('pad', 'A3', 2, synth.now + 1);      // schedule 1 s ahead
  const v = synth.play('supersaw', 60, null);     // held note
  v.stop();
  synth.presets.myLead = { osc: [{ type: 'square', unison: 3, spread: 15 }], filter: { freq: 1500, env: 3000 } };
  synth.volume = 0.5;
</script>
```
The patch fields are listed in `DEFAULT` in `synth.js`: oscillators (each with unison, detune spread and octave), noise, FM, a pitch envelope, an amp ADSR, a filter with its own ADSR, an LFO (pitch, filter or amp), pan, and delay and reverb sends.

**Presets:** supersaw, pad, pluck, bass, keys, bell, kick, snare, hat, laser.

## Findings
None yet.
