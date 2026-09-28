import { useState } from "react";
import { Activity, ChevronRight, RefreshCw } from "lucide-react";
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid } from "recharts";
import type { Row } from "./model";
import {useLanguage} from './language';

const metrics = [
  {key:"cpu",label:"CPU 使用率",unit:"%",color:"#60a5fa",kind:"percent"},
  {key:"memory",label:"内存使用率",unit:"%",color:"#ad96ff",kind:"percent"},
  {key:"gpu",label:"GPU 使用率",unit:"%",color:"#39d7c2",kind:"percent"},
  {key:"cpuTemp",label:"CPU 温度",unit:"°C",color:"#ffbd69",kind:"temperature"},
  {key:"gpuTemp",label:"GPU 温度",unit:"°C",color:"#f586ad",kind:"temperature"},
  {key:"gpuPowerW",label:"显卡功耗",unit:"W",color:"#f0a86b",kind:"power"},
  {key:"netDown",label:"下载速度",unit:"MB/s",color:"#53c8ef",kind:"rate"},
] as const;
type Key = typeof metrics[number]["key"];

function axisRange(values:number[], kind:string):[number,number] {
  const low=Math.min(...values), high=Math.max(...values);
  if(kind==="percent") return [0,Math.min(100,Math.max(10,Math.ceil(high*1.15/10)*10))];
  if(kind==="temperature") return [Math.max(0,Math.floor((low-5)/10)*10),Math.ceil((high+5)/10)*10];
  if(kind==="power") return [0,Math.max(25,Math.ceil(high*1.15/25)*25)];
  const top=high<1?Math.ceil(high*1.3*10)/10:Math.ceil(high*1.2);
  return [0,Math.max(.1,top)];
}

export default function TrendChart({history,range,setRange,demo,loading,refresh,showDemo}:{history:Row[];range:number;setRange:(n:number)=>void;demo:boolean;loading:boolean;refresh:()=>void;showDemo:()=>void}) {
  const {tr,locale}=useLanguage();
  const [key,setKey]=useState<Key>("cpu");
  const metric=metrics.find(item=>item.key===key)!;
  const values=history.map(row=>row[key]).filter((value):value is number=>typeof value==="number"&&Number.isFinite(value));
  const domain=values.length?axisRange(values,metric.kind):[0,100] as [number,number];
  const last=values.at(-1), minimum=values.length?Math.min(...values):null, maximum=values.length?Math.max(...values):null;
  const decimals=metric.kind==="rate"?2:1;
  const format=(value:number|null|undefined)=>value==null?"—":value.toFixed(decimals);
  const label=(item:typeof metrics[number])=>tr(item.label,({cpu:'CPU usage',memory:'Memory usage',gpu:'GPU usage',cpuTemp:'CPU temperature',gpuTemp:'GPU temperature',gpuPowerW:'GPU power',netDown:'Download speed'} as Record<Key,string>)[item.key]);
  return <section className="panel history">
    <div className="panel-head"><div><h2>{tr('运行趋势','Performance history')}</h2><p className="muted">{demo?tr('模拟历史曲线','Simulated history'):tr(`最近 ${range===168?'7 天':`${range} 小时`} · 按接收时间显示`,`Last ${range===168?'7 days':`${range} hours`} · by received time`)}</p></div><div className="segmented">{[1,24,168].map(hours=><button key={hours} aria-pressed={range===hours} className={range===hours?"selected":""} onClick={()=>setRange(hours)}>{hours===168?tr('7 天','7 days'):tr(`${hours} 小时`,`${hours} hour${hours===1?'':'s'}`)}</button>)}</div></div>
    <div className="chart-tabs" role="group" aria-label={tr('选择趋势指标','Select a chart metric')}>{metrics.map(item=><button key={item.key} aria-pressed={key===item.key} className={key===item.key?"selected":""} onClick={()=>setKey(item.key)}><i style={{background:item.color}}/>{label(item)}</button>)}</div>
    <div className="chart">{values.length?<ResponsiveContainer width="100%" height="100%"><AreaChart data={history} margin={{top:14,right:18,left:4,bottom:4}}><defs><linearGradient id="trend-fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor={metric.color} stopOpacity={.27}/><stop offset="100%" stopColor={metric.color} stopOpacity={0}/></linearGradient></defs><CartesianGrid stroke="#304057" vertical={false} strokeDasharray="4 5"/><XAxis dataKey="t" type="number" domain={["dataMin","dataMax"]} tickFormatter={value=>new Date(value).toLocaleString(locale,range===168?{month:"numeric",day:"numeric"}:{hour:"2-digit",minute:"2-digit"})} tick={{fill:"#9aabc1",fontSize:12}} tickLine={false} axisLine={false} minTickGap={42}/><YAxis domain={domain} width={58} tickFormatter={value=>`${value}${metric.unit}`} tick={{fill:"#9aabc1",fontSize:12}} tickLine={false} axisLine={false} allowDecimals={metric.kind==="rate"}/><Tooltip contentStyle={{background:"#172233",border:"1px solid #39485d",borderRadius:10,color:"#edf3fd"}} labelFormatter={value=>new Date(Number(value)).toLocaleString(locale)} formatter={value=>[`${format(Number(value))} ${metric.unit}`,label(metric)]}/><Area type="linear" dataKey={key} stroke={metric.color} fill="url(#trend-fill)" strokeWidth={2} dot={false} activeDot={{r:4}} isAnimationActive={false} connectNulls={false}/></AreaChart></ResponsiveContainer>:<div className="empty-chart"><Activity size={32}/><h3>{history.length?tr('此项指标暂不可用','Metric unavailable'):tr('还没有监控记录','No monitoring history yet')}</h3><p>{history.length?tr('采集程序未读取到该传感器；旧版本的显卡功耗记录也不会补齐。','The collector could not read this sensor. Older GPU power history cannot be restored.'):tr('接入电脑开始记录，或切换演示查看图表效果。','Connect a PC to begin recording, or open the demo.')}</p><button onClick={()=>history.length?setKey('cpu'):showDemo()}>{history.length?tr('查看 CPU 曲线','View CPU chart'):tr('查看演示','View demo')}<ChevronRight size={15}/></button></div>}</div>
    <div className="chart-footer"><div className="chart-summary"><span><i style={{background:metric.color}}/>{label(metric)} · {metric.unit}</span>{values.length>0&&<span>{tr('最新','Latest')} {format(last)} · {tr('最低','Min')} {format(minimum)} · {tr('最高','Max')} {format(maximum)} <span className="chart-scale">{domain[0]>0?tr('纵轴缩放','Scaled axis'):tr('纵轴从 0 开始','Axis starts at 0')}</span></span>}</div><button onClick={refresh} disabled={loading||demo}><RefreshCw size={14}/>{loading?tr('更新中','Updating'):tr('刷新数据','Refresh')}</button></div>
  </section>;
}
