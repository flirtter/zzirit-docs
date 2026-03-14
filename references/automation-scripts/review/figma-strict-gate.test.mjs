import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const script = '/Users/user/zzirit-v2/scripts/review/figma-strict-gate.py';

function run(args) {
  const result = spawnSync('python3', [script, ...args], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout.trim());
}

test('strict gate verifies canonical reference with fresh route screenshot', () => {
  const payload = run([
    '--app-source',
    'simulator-fresh',
    '--app-fresh',
    'yes',
    '--app-route-accurate',
    'yes',
    '--figma-source',
    'cache',
    '--figma-path',
    '/Users/user/zzirit-v2/artifacts/figma-reference/cache/Zhys/20220-16941.png',
  ]);

  assert.equal(payload.status, 'verified');
  assert.equal(payload.reference_kind, 'canonical');
  assert.equal(payload.reason, 'none');
});

test('strict gate blocks fallback screenshot and proxy references', () => {
  const payload = run([
    '--app-source',
    'fallback-appium',
    '--app-fresh',
    'no',
    '--app-route-accurate',
    'no',
    '--figma-source',
    'provided',
    '--figma-path',
    '/Users/user/zzirit-v2/artifacts/ios-visual/onboarding-entry/proxy-screenshots/green.png',
  ]);

  assert.equal(payload.status, 'blocked');
  assert.equal(payload.reference_kind, 'non-canonical');
  assert.match(payload.reason, /figma-reference-not-canonical/);
  assert.match(payload.reason, /app-screenshot-not-fresh/);
  assert.match(payload.reason, /app-screenshot-not-route-accurate/);
});
