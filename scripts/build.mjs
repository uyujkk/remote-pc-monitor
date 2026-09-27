import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
// Optional dependency path for development in an existing workspace.
const depRoot=process.env.MONITOR_NODE_DEPS || root;
const require=createRequire(path.join(depRoot,'package.json'));
const {build}=require('esbuild');
fs.mkdirSync(path.join(root,'static/assets'),{recursive:true});
await build({entryPoints:[path.join(root,'web/frontend.tsx')],bundle:true,minify:true,jsx:'automatic',nodePaths:[path.join(depRoot,'node_modules')],define:{'process.env.NODE_ENV':'"production"'},outfile:path.join(root,'static/assets/app.js'),target:['es2020'],legalComments:'external'});
fs.copyFileSync(path.join(root,'web/styles.css'),path.join(root,'static/assets/app.css'));
fs.writeFileSync(path.join(root,'static/index.html'),'<!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Remote PC Monitor</title><link rel="stylesheet" href="/assets/app.css"></head><body><div id="root"></div><script type="module" src="/assets/app.js"></script></body></html>');
console.log('Built static dashboard. No external CDN required.');
