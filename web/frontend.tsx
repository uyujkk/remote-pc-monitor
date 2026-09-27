import React, {useEffect, useState} from 'react';
import {createRoot} from 'react-dom/client';
import Dashboard from './dashboard';

function App(){
 const [user,setUser]=useState<string|null>(null),[ready,setReady]=useState(false),[error,setError]=useState(''),[busy,setBusy]=useState(false);
 useEffect(()=>{fetch('/api/session').then(r=>{if(!r.ok)throw new Error();return r.json();}).then(d=>setUser(d.authenticated?d.username:null)).catch(()=>setError('无法连接服务器，请刷新重试。')).finally(()=>setReady(true));},[]);
 async function login(e:React.FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError('');const form=new FormData(e.currentTarget);try{const r=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.fromEntries(form))});if(!r.ok)throw new Error(r.status===429?'尝试次数过多，请 15 分钟后重试。':'用户名或密码不正确。');setUser(String(form.get('username')));}catch(e){setError(e instanceof Error?e.message:'登录失败');}finally{setBusy(false);}}
 if(!ready)return <main className="login">正在连接监控服务…</main>;
 if(user)return <Dashboard email={user}/>;
 return <main className="login"><section className="login-card"><div className="brand-icon">⌁</div><p className="eyebrow">REMOTE MONITOR</p><h1>电脑在远方，<br/>状态在眼前。</h1><p>登录查看硬件状态和历史曲线。</p><form onSubmit={login}><label>用户名<input name="username" autoComplete="username" required maxLength={64}/></label><label>密码<input name="password" type="password" autoComplete="current-password" required maxLength={256}/></label>{error&&<p role="alert" className="error-text">{error}</p>}<button className="primary" disabled={busy}>{busy?'正在登录…':'登录监控台'}</button></form><small>私人监控 · 数据仅登录后可见</small></section></main>;
}
createRoot(document.getElementById('root')!).render(<App/>);
