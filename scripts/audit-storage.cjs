const fs = require('node:fs');
const path = require('node:path');

const args = process.argv.slice(2);
const outputIndex = args.indexOf('--output');
let outputPath;
if (outputIndex >= 0) {
  if (!args[outputIndex + 1]) throw new Error('--output requires a filename');
  outputPath = path.resolve(args[outputIndex + 1]);
  args.splice(outputIndex, 2);
}
if (!args.length) throw new Error('Supply one or more absolute local directory roots');
const roots = [...new Set(args.map(root => {
  if (!path.isAbsolute(root)) throw new Error('Absolute root required: ' + root);
  const resolved = path.resolve(root);
  let ancestor = resolved;
  while (ancestor) {
    if (fs.lstatSync(ancestor).isSymbolicLink()) throw new Error('Linked ancestor: ' + ancestor);
    const parent = path.dirname(ancestor);
    if (parent === ancestor) break;
    ancestor = parent;
  }
  if (!fs.statSync(resolved).isDirectory()) throw new Error('Directory required: ' + resolved);
  return resolved;
}))];
const directories = [], largeFiles = [], errors = [], skippedLinks = [];
const threshold = 200 * 1024 * 1024;
const interesting = /cache|logs?|temp|tmp|backup|release|node_modules|^\.venv$|upgrade|installer|previous/i;

function walk(directory, depth) {
  let entries;
  try { entries = fs.readdirSync(directory, { withFileTypes: true }); }
  catch (error) { errors.push({ path: directory, code: error.code }); return 0; }
  let bytes = 0;
  for (const entry of entries) {
    const fullPath = path.join(directory, entry.name);
    if (fullPath === outputPath) continue;
    if (entry.isSymbolicLink()) { skippedLinks.push(fullPath); continue; }
    if (entry.isDirectory()) { bytes += walk(fullPath, depth + 1); continue; }
    try {
      const stat = fs.statSync(fullPath);
      bytes += stat.size;
      if (stat.size >= threshold) largeFiles.push({ path: fullPath, bytes: stat.size, modified: stat.mtime.toISOString(), links: stat.nlink });
    } catch (error) { errors.push({ path: fullPath, code: error.code }); }
  }
  if (depth <= 2 || (bytes >= threshold && interesting.test(path.basename(directory)))) directories.push({ path: directory, bytes, depth });
  if (depth === 1) process.stderr.write(JSON.stringify({ progress: directory, bytes }) + '\n');
  return bytes;
}
for (const root of roots) walk(root, 0);
directories.sort((a, b) => b.bytes - a.bytes);
largeFiles.sort((a, b) => b.bytes - a.bytes);
const report = { timestamp: new Date().toISOString(), measure: 'logical bytes; nested roots and hardlinks can overlap', directories, largeFiles, errors, skippedLinks };
const json = JSON.stringify(report, null, 2);
if (outputPath) fs.writeFileSync(outputPath, json);
else process.stdout.write(json + '\n');
process.stderr.write(JSON.stringify({ completed: true, errors: errors.length, largeFiles: largeFiles.length }) + '\n');
