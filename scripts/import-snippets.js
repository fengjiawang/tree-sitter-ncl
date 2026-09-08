#!/usr/bin/env node
// One-time migration: the resulting project data is self-contained at runtime.
const fs = require('node:fs');
const path = require('node:path');
const input = process.argv[2];
if (!input) {
  console.error('Usage: node scripts/import-snippets.js <NCL snippet directory>');
  process.exit(1);
}
const entries = [];
for (const category of ['keywords', 'function', 'customs', 'resources', 'color_table', 'font']) {
  const source = JSON.parse(fs.readFileSync(path.join(input, category + '.json'), 'utf8'));
  for (const [name, definition] of Object.entries(source)) {
    let body = Array.isArray(definition.body) ? definition.body.join('\n') : definition.body;
    // Fix known language errors in the migrated copy; never edit the originals.
    if (category === 'keywords' && name === 'dowhile') body = body.replace(/^do \(/, 'do while (');
    if (category === 'keywords' && name === 'Module documentation header') body = body.replace(/^!/gm, ';');
    for (const trigger of [].concat(definition.prefix)) {
      entries.push({ trigger, name, category, body, description: definition.description || name });
    }
  }
}
const output = path.join(__dirname, '../data/ncl-snippets.json');
fs.writeFileSync(output, JSON.stringify({
  source: 'Migrated NCL templates; runtime does not read the original snippet directory',
  entries,
}, null, 2) + '\n');
console.log(`Imported ${entries.length} snippet triggers into data/ncl-snippets.json`);
