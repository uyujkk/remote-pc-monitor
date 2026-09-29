// The 64-byte key is generated in this browser and included in the collector
// configuration downloaded locally. It is never sent to the receiver API.
const STORAGE='remote-monitor-result-key-v1';
const valid=(key:string)=>/^[a-f0-9]{128}$/.test(key);
const bytes=(hex:string)=>Uint8Array.from(hex.match(/../g)!,part=>parseInt(part,16));

export function getResultKey():string|null{
 try{const value=localStorage.getItem(STORAGE);return value&&valid(value)?value:null}catch{return null}
}
export function ensureResultKey():string{
 const previous=getResultKey();if(previous)return previous;
 const random=crypto.getRandomValues(new Uint8Array(64));
 const key=Array.from(random,byte=>byte.toString(16).padStart(2,'0')).join('');
 localStorage.setItem(STORAGE,key);
 window.dispatchEvent(new Event('monitor-key-changed'));
 return key;
}
export function importResultKey(value:string):void{
 const key=value.trim().toLowerCase();if(!valid(key))throw new Error('Invalid key');
 localStorage.setItem(STORAGE,key);
 window.dispatchEvent(new Event('monitor-key-changed'));
}
export async function decryptResult(message:string,at:string,status:string,keyHex:string):Promise<string>{
 if(!valid(keyHex)||!message.startsWith('v1.'))throw new Error('Invalid encrypted result');
 const packet=Uint8Array.from(atob(message.slice(3)),char=>char.charCodeAt(0));
 if(packet.length<64||(packet.length-48)%16!==0)throw new Error('Invalid encrypted result');
 const content=packet.slice(0,-32),tag=packet.slice(-32),iv=content.slice(0,16),cipher=content.slice(16);
 const prefix=new TextEncoder().encode(`v1|${at}|${status}|`);
 const signed=new Uint8Array(prefix.length+content.length);signed.set(prefix);signed.set(content,prefix.length);
 const macKey=await crypto.subtle.importKey('raw',bytes(keyHex).slice(32).buffer,{name:'HMAC',hash:'SHA-256'},false,['verify']);
 if(!await crypto.subtle.verify('HMAC',macKey,tag.buffer,signed.buffer))throw new Error('Authentication failed');
 const aesKey=await crypto.subtle.importKey('raw',bytes(keyHex).slice(0,32).buffer,'AES-CBC',false,['decrypt']);
 const plain=await crypto.subtle.decrypt({name:'AES-CBC',iv:iv.buffer},aesKey,cipher.buffer);
 return new TextDecoder('utf-8',{fatal:true}).decode(plain);
}
