// PROTOTYPE - NOT FOR PRODUCTION
// Self-check: renders every preset offline in headless Chromium and asserts it makes finite, non-silent,
// non-clipping audio; also checks note parsing and that held notes release. Run: node check.js
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + path.join(__dirname, 'index.html'));
  const res = await page.evaluate(async () => {
    const out = { hz: [Synth.hz('A4'), Synth.hz('C4'), Synth.hz('Eb3'), Synth.hz(69)], presets: {} };
    for (const name of Object.keys(new Synth(new OfflineAudioContext(2, 1, 44100)).presets)) {
      const ctx = new OfflineAudioContext(2, 44100 * 3, 44100), s = new Synth(ctx);
      s.play(name, name === 'kick' ? 'A1' : 'C4', 0.5);
      const d = (await ctx.startRendering()).getChannelData(0);
      let peak = 0, finite = true;
      for (const x of d) { if (!Number.isFinite(x)) finite = false; peak = Math.max(peak, Math.abs(x)); }
      out.presets[name] = { peak, finite };
    }
    // Held note: silent tail after stop() proves release works.
    const ctx = new OfflineAudioContext(1, 44100 * 3, 44100), s = new Synth(ctx);
    s.play('supersaw', 'C4', null).stop(0.5);
    const d = (await ctx.startRendering()).getChannelData(0);
    out.tail = Math.max(...d.slice(44100 * 2.5).map(Math.abs));
    return out;
  });

  const assert = (ok, msg) => { if (!ok) { console.error('FAIL', msg); process.exitCode = 1; } };
  const near = (a, b) => Math.abs(a - b) < 0.01;
  assert(near(res.hz[0], 440) && near(res.hz[1], 261.626) && near(res.hz[2], 155.563) && near(res.hz[3], 440), 'hz ' + res.hz);
  for (const [n, r] of Object.entries(res.presets)) {
    console.log(n.padEnd(9), 'peak', r.peak.toFixed(3));
    assert(r.finite && r.peak > 0.01 && r.peak <= 1, n);
  }
  assert(res.tail < 0.001, 'release tail ' + res.tail);

  await page.setViewportSize({ width: 800, height: 260 });
  const shot = path.join(__dirname, '../../production/qa/evidence/synth-demo.png');
  await page.screenshot({ path: shot });
  console.log(process.exitCode ? 'FAILED' : 'ALL PASS', '| screenshot', path.relative(process.cwd(), shot));
  await browser.close();
})();
