#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const root = process.cwd();

// Find most recent handover
const handoverDir = path.join(root, '01. Journal', 'handovers');
let lastHandover = '(no handover found)';
try {
  const files = fs.readdirSync(handoverDir)
    .filter(f => f.endsWith('.md'))
    .sort()
    .reverse();
  if (files.length > 0) {
    lastHandover = files[0].replace('.md', '');
  }
} catch (e) { /* dir may not exist yet */ }

// Count open QA issues across all surfaces
const surfaces = ['login','onboarding','my','likes','meeting','chat','lightning','billing','moderation'];
let openQA = 0;
for (const s of surfaces) {
  const qaDir = path.join(root, '02. Project', s, 'QA');
  try {
    const files = fs.readdirSync(qaDir).filter(f => f.endsWith('.md') && f !== 'QA.md');
    for (const f of files) {
      const content = fs.readFileSync(path.join(qaDir, f), 'utf8');
      if (content.includes('status: open')) openQA++;
    }
  } catch (e) { /* dir may not exist */ }
}

const msg = `Last handover: ${lastHandover} | Open QA: ${openQA}`;
process.stdout.write(msg);
