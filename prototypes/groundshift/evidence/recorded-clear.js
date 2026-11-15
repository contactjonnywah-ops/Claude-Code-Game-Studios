// A recorded clear: plays the level's intended solution through the game's own keys.
const { chromium } = require('playwright');
const dir = process.argv[2];
(async () => {
  const b = await chromium.launch({ args: ['--enable-unsafe-swiftshader'] });
  const pg = await b.newPage({ viewport: { width: 1280, height: 720 } });
  pg.on('pageerror', e => console.log('ERR', e.message));
  await pg.goto('file://' + dir + '/index.html?manual=1&render=cheap');
  await pg.evaluate(() => {
    window.T = {
      aim(x, y, z) { const d = new THREE.Vector3(x, y, z).sub(eyePos(player.c)).normalize().applyQuaternion(qBase.clone().invert()); pitch = Math.asin(d.y); yaw = Math.atan2(-d.x, -d.z); },
      fire(x, y, z, n) { T.aim(x, y, z); game.press('KeyF'); game.step(n, false); },
      walk(x, y, z, cond, max = 900) { game.hold('KeyW', true); let i = 0; for (; i < max && !cond(); i++) { T.aim(x, y, z); game.step(1, false); } game.hold('KeyW', false); game.step(20, false); return i < max; },
      log(tag) { const p = player.c, c = cube.c; return `${tag}: room ${state.room} g ${state.gravity} deaths ${state.deaths} p ${p.x.toFixed(1)},${p.y.toFixed(1)},${p.z.toFixed(1)} cube ${c.x.toFixed(1)},${c.y.toFixed(1)},${c.z.toFixed(1)} plate ${state.plate} scene ${game.scene}`; },
    };
    game.press('Enter'); game.step(5, false);
  });
  const stage = async (tag, fn, shot) => {
    console.log(await pg.evaluate(`(${fn})(); T.log('${tag}')`));
    if (shot) { await pg.evaluate(() => game.step(0)); await pg.screenshot({ path: dir + '/evidence/' + shot + '.png' }); }
  };
  await stage('r1 ceiling', () => T.fire(0, 9, -11.5, 100));
  await stage('r1 over wall', () => T.walk(0, 8.4, -3, () => player.c.z > -5), 'room1-ceiling');
  await stage('r1 floor', () => T.fire(0, 0, -4.2, 100));
  await stage('r1 door', () => T.walk(0, 0.6, 5, () => player.c.z > 4));
  await stage('r2 deadly aim', () => { T.aim(0, 22, 5); game.step(1, false); return 0; }, 'room2-deadly');
  console.log('aim', JSON.stringify(await pg.evaluate(() => state.aim)));
  await stage('r2 wall', () => T.fire(-6, 3, 5, 90));
  await stage('r2 up wall', () => T.walk(-5.4, 40, 5, () => player.c.y > 19), 'room2-wall');
  await stage('r2 ceiling', () => T.fire(-3, 22, 5, 70));
  await stage('r2 over ledge', () => T.walk(20, 21.4, 5, () => player.c.x > 4));
  await stage('r2 ledge', () => T.fire(4, 16, 6.5, 90));
  await stage('r2 door', () => T.walk(4, 16.6, 30, () => player.c.z > 13.5), 'room3-start');
  await stage('r3 ceiling', () => T.fire(0, 25, 16, 100));
  await stage('r3 behind cube a', () => T.walk(-4.5, 24.4, 13.6, () => player.c.x < -4.3));
  await stage('r3 behind cube b', () => T.walk(-4.5, 24.4, 30, () => player.c.z > 15.9));
  await stage('r3 push x', () => T.walk(30, 24.4, 16, () => cube.c.x > 5.4), 'room3-push');
  await stage('r3 round a', () => T.walk(player.c.x, 24.4, -30, () => player.c.z < 14.2));
  await stage('r3 round b', () => T.walk(30, 24.4, 14.2, () => player.c.x > 5.3, 200));
  await stage('r3 push z', () => T.walk(5.4, 24.4, 60, () => cube.c.z > 25.4));
  await stage('r3 floor', () => T.fire(-2, 16, 18, 110), 'room3-plate');
  await stage('r3 to door a', () => T.walk(-2, player.c.y, 24.5, () => player.c.x < -1.8));
  await stage('r3 exit', () => T.walk(-2, 16.6, 40, () => game.scene === 'results'), 'results');
  console.log(JSON.stringify(await pg.evaluate(() => game.state.gained)));
  await b.close();
})();
