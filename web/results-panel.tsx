import {CheckCircle2, CircleAlert, History} from 'lucide-react';
import type {AutoMas} from './model';
import {useLanguage} from './language';

export default function ResultsPanel({value,online,compact=false}:{value:AutoMas|null|undefined;online:boolean;compact?:boolean}){
 const {tr}=useLanguage();
 const results=value?.recentResults??[];
 const counts=value?.resultCounts;
 return <section className="panel results-panel">
  <div className="panel-head"><div><h2><History size={18}/>{tr('脚本执行结果','Script results')}</h2><p className="muted">{tr('最近 7 天的历史记录；最多每 5 分钟从本机 AUTO-MAS 刷新','Last 7 days of history; refreshed from local AUTO-MAS at most every 5 minutes')}{value?.historyUpdatedAt&&<> · {tr('上次读取','Last read')} {value.historyUpdatedAt}</>}</p></div></div>
  {(!online||value?.state==='unavailable'||value?.state==='starting')&&results.length>0&&<p className="results-stale">{tr('当前无法确认 AUTO-MAS 历史接口状态，以下是上次成功读取的结果。','AUTO-MAS history is not currently confirmed; these are the last successfully read results.')}</p>}
  {counts&&<div className="result-summary"><div><CheckCircle2 size={18}/><strong>{counts.done}</strong><span>{tr('已完成','Completed')}</span></div><div><CircleAlert size={18}/><strong>{counts.error}</strong><span>{tr('报错','Errors')}</span></div></div>}
  {results.length?<div className="results-list">{results.slice(0,compact?3:12).map((item,index)=><article className="result-row" key={`${item.at}-${index}`}><span className={`result-mark ${item.status==='DONE'?'done':'error'}`}>{item.status==='DONE'?<CheckCircle2 size={17}/>:<CircleAlert size={17}/>}</span><div><div className="result-title"><strong>{item.status==='DONE'?tr('执行完成','Completed'):tr('执行报错','Error')}</strong><time>{item.at}</time></div><p>{item.message||tr('此记录没有结果摘要','No result summary in this record')}</p></div></article>)}</div>:<p className="automas-empty result-empty">{!online?tr('电脑已停止上报，历史结果可能不是最新。','The PC stopped reporting; results may be stale.'):tr('最近 7 天没有可显示的执行结果，或采集端尚未更新。','No results in the last 7 days, or the collector has not updated yet.')}</p>}
  {compact&&results.length>3&&<p className="results-more">{tr(`还有 ${results.length-3} 条，请在侧边栏打开“执行结果”。`,`Open “Results” in the sidebar for ${results.length-3} more entries.`)}</p>}
  <p className="automas-foot">{tr('结果摘要来自 AUTO-MAS 历史接口，已限制长度并过滤常见路径和凭据。它不等同于实时任务进度；原始日志不会上传。','Summaries come from AUTO-MAS history, are length-limited and filtered for common paths and credentials. They do not show live progress; raw logs are not uploaded.')}</p>
 </section>;
}
