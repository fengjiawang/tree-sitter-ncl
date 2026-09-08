#!/usr/bin/env node
// Refresh the checked-in vocabulary from the user's reference files.
// This script only reads the supplied Neovim configuration.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const [snippets, plugin] = process.argv.slice(2);
if (!snippets || !plugin) {
  console.error('Usage: node scripts/import-vocabulary.js <ncl snippets directory> <ncl.lua>');
  process.exit(1);
}
const read = name => JSON.parse(fs.readFileSync(path.join(snippets, name + '.json'), 'utf8'));
const lua = fs.readFileSync(plugin, 'utf8');
function luaWords(group) {
  const match = lua.match(new RegExp(group + '\\s*=\\s*\\[\\[([\\s\\S]*?)\\]\\]'));
  if (!match) throw new Error('Missing vocabulary group: ' + group);
  return match[1].trim().split(/\s+/);
}
const sorted = names => [...new Set(names)].sort();
const data = {
  source: 'NCL VS Code snippets and lua/plugins/ncl.lua; snapshot, not a language specification',
  functions: sorted([...Object.keys(read('function')), ...luaWords('nclFunction')]),
  customFunctions: sorted(luaWords('nclFunctionCustomized')),
  resources: sorted(Object.keys(read('resources')).map(name => name.replace(/^@/, ''))),
  colors: sorted(Object.keys(read('color_table'))),
  fonts: sorted(Object.keys(read('font'))),
};
fs.mkdirSync(path.join(root, 'data'), { recursive: true });
fs.writeFileSync(path.join(root, 'data/ncl-vocabulary.json'), JSON.stringify(data, null, 2) + '\n');
console.log(Object.fromEntries(Object.entries(data).filter(([, v]) => Array.isArray(v)).map(([k, v]) => [k, v.length])));
