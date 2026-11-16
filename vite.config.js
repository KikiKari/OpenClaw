import { defineConfig } from 'vite';
import { readdir, readFile } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import { gzipSync } from 'node:zlib';
const languages = ['javascript','perl5','powershell','python','shell','tcl','perl6','ruby','lua','go'];
export default defineConfig({build:{rollupOptions:{input:{main:'index.html',architecture:'3d.html'}}},plugins:[{name:'translation-catalog',async generateBundle(){
  const entries=[];
  async function walk(dir,language){for(const item of await readdir(dir,{withFileTypes:true})){const path=join(dir,item.name);if(item.isDirectory()) await walk(path,language);else if(item.isFile()) entries.push({language,path:relative(process.cwd(),path).split(sep).join('/'),content:await readFile(path,'utf8')});}}
  for(const language of languages) await walk(language,language);
  entries.sort((a,b)=>a.path.localeCompare(b.path));this.emitFile({type:'asset',fileName:'catalog.json.gz',source:gzipSync(JSON.stringify(entries))});}}]});
