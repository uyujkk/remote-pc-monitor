import React, {createContext, useContext, useEffect, useState} from 'react';
export type Language='zh-CN'|'en';
const Context=createContext<{language:Language;setLanguage:(value:Language)=>void}>({language:'zh-CN',setLanguage:()=>{}});
export function LanguageProvider({children}:{children:React.ReactNode}){
 const [language,setLanguage]=useState<Language>(()=>localStorage.getItem('monitor-language')==='en'?'en':'zh-CN');
 useEffect(()=>{document.documentElement.lang=language;localStorage.setItem('monitor-language',language)},[language]);
 return <Context.Provider value={{language,setLanguage}}>{children}</Context.Provider>;
}
export function useLanguage(){const {language,setLanguage}=useContext(Context);return {language,setLanguage,tr:(zh:string,en:string)=>language==='en'?en:zh,locale:language==='en'?'en-US':'zh-CN'};}
export function LanguageSwitch(){const {language,setLanguage}=useLanguage();return <div className="language-switch" role="group" aria-label="Language / 语言"><button type="button" aria-pressed={language==='zh-CN'} onClick={()=>setLanguage('zh-CN')}>中文</button><button type="button" aria-pressed={language==='en'} onClick={()=>setLanguage('en')}>English</button></div>}
