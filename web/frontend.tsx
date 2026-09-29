import React, {useEffect, useState} from 'react';
import {createRoot} from 'react-dom/client';
import Dashboard from './dashboard';
import {LanguageProvider, LanguageSwitch, useLanguage} from './language';

function App(){
 const {tr}=useLanguage();
 const [user,setUser]=useState<string|null>(null),[ready,setReady]=useState(false),[error,setError]=useState<'connection'|'limit'|'credentials'|'login'|''>(''),[busy,setBusy]=useState(false),[totpRequired,setTotpRequired]=useState(false);
 useEffect(()=>{fetch('/api/session').then(r=>{if(!r.ok)throw new Error();return r.json()}).then(d=>{setUser(d.authenticated?d.username:null);setTotpRequired(!!d.totpEnabled)}).catch(()=>setError('connection')).finally(()=>setReady(true))},[]);
 async function login(e:React.FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError('');const form=new FormData(e.currentTarget);try{const r=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.fromEntries(form))});if(!r.ok)throw new Error(r.status===429?'limit':'credentials');setUser(String(form.get('username')))}catch(e){setError(e instanceof Error&&['limit','credentials'].includes(e.message)?e.message as 'limit'|'credentials':'login')}finally{setBusy(false)}}
 if(!ready)return <main className="login">{tr('正在连接监控服务…','Connecting to the monitor…')}</main>;
 if(user)return <Dashboard email={user}/>;
 const messages={connection:tr('无法连接服务器，请刷新重试。','Cannot reach the server. Please refresh.'),limit:tr('尝试次数过多，请 15 分钟后重试。','Too many attempts. Try again in 15 minutes.'),credentials:tr('用户名、密码或动态码不正确。','Incorrect username, password or authenticator code.'),login:tr('登录失败。','Sign-in failed.')};
 return <main className="login"><section className="login-card"><div className="login-top"><div className="brand-icon">⌁</div><LanguageSwitch/></div><p className="eyebrow">REMOTE MONITOR</p><h1>{tr('电脑在远方，','Your PC is remote,')}<br/>{tr('状态在眼前。','its status is here.')}</h1><p>{tr('登录查看硬件状态、运行任务和历史趋势。','Sign in to view hardware, running tasks and history.')}</p><form onSubmit={login}><label>{tr('用户名','Username')}<input name="username" autoComplete="username" required maxLength={64}/></label><label>{tr('密码','Password')}<input name="password" type="password" autoComplete="current-password" required maxLength={256}/></label>{totpRequired&&<label>{tr('验证器动态码','Authenticator code')}<input name="totp" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required maxLength={6}/></label>}{error&&<p role="alert" className="error-text">{messages[error]}</p>}<button className="primary" disabled={busy}>{busy?tr('正在登录…','Signing in…'):tr('登录监控台','Sign in')}</button></form><small>{tr('私人监控 · 数据仅登录后可见','Private monitoring · data is visible after sign-in')}</small></section></main>;
}
createRoot(document.getElementById('root')!).render(<LanguageProvider><App/></LanguageProvider>);
