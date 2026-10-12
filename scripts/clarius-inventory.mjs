// Reproducible public SDK surface inventory. This does not load a runtime or probe.
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export function exportsFromHeader(header, prefix) {
  const plain = header.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
  return [...plain.matchAll(new RegExp(`\\b${prefix.toUpperCase()}_EXPORT\\s+([^;]+);`, 'g'))]
    .map(m => m[1].replace(/\s+/g, ' ').trim())
    .map(signature => ({name: signature.match(new RegExp(`\\b(${prefix}\\w+)\\s*\\(`))?.[1], signature}))
    .filter(x => x.name).sort((a,b) => a.name.localeCompare(b.name));
}

const sources = [
  {sdk: 'solum', commit: '6d5c55fe49076e36eae3f63fa0dcf2d38dc4b328'},
  {sdk: 'cast', commit: '559717022388e2975e3e2826642d97879daa14a3'},
];

async function main() {
  const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
  const local = process.argv.includes('--local');
  const check = process.argv.includes('--check');
  const inventory = {schemaVersion: 1, hardwareVerified: false, sources: []};
  for (const source of sources) {
    const url = `https://raw.githubusercontent.com/clariusdev/${source.sdk}/${source.commit}/include/${source.sdk}/${source.sdk}.h`;
    const header = local ? await readFile(resolve(root, `.tools/clarius-${source.sdk}/include/${source.sdk}/${source.sdk}.h`), 'utf8') : await (async () => {
      const response = await fetch(url, {signal: AbortSignal.timeout(30000)});
      if (!response.ok) throw new Error(`SDK header download failed: ${response.status}`);
      return response.text();
    })();
    const functions = exportsFromHeader(header, source.sdk);
    if (!functions.length) throw new Error(`No exports found for ${source.sdk}`);
    inventory.sources.push({...source, url, functions: functions.map(f => ({...f, blueStatus: 'not-implemented', hardwareVerified: false}))});
  }
  const path = resolve(root, 'docs/clarius-sdk-inventory.json');
  const json = JSON.stringify(inventory, null, 2) + '\n';
  if (check) {
    if ((await readFile(path, 'utf8')).replace(/\r\n/g, '\n') !== json) throw new Error('SDK inventory differs from pinned public headers');
  } else {
    await mkdir(resolve(root, 'docs'), {recursive: true});
    await writeFile(path, json);
  }
  console.log(inventory.sources.map(s => `${s.sdk}: ${s.functions.length} documented C exports`).join('\n'));
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
