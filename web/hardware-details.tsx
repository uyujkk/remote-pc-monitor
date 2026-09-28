import { Cpu } from "lucide-react";
import type { Sample } from "./model";

const text=(value:string|null|undefined)=>value?.trim()||"—";
const number=(value:number|null|undefined,unit:string)=>value==null?"—":`${Math.round(value)} ${unit}`;

export default function HardwareDetails({sample}:{sample:Sample|null}) {
  return <section className="panel hardware-panel"><div className="panel-head"><div><h2><Cpu size={18}/>配件型号</h2><p className="muted">由 Windows 硬件信息读取；不上传序列号</p></div></div>
    <dl className="hardware-list"><div><dt>处理器</dt><dd>{text(sample?.cpuName)}</dd></div><div><dt>主板</dt><dd>{text(sample?.motherboardName)}</dd></div><div><dt>显卡</dt><dd>{text(sample?.gpuName)}</dd></div><div><dt>内存模组</dt><dd>{sample?.memoryModules?.length?sample.memoryModules.map((module,index)=><span className="hardware-part" key={`${module.name}-${index}`}>{text(module.name)} · {number(module.capacityGb,"GB")}{module.speedMhz!=null?` · ${number(module.speedMhz,"MHz")}`:""}</span>):"—"}</dd></div><div><dt>物理磁盘</dt><dd>{sample?.storageModels?.length?sample.storageModels.map((disk,index)=><span className="hardware-part" key={`${disk.name}-${index}`}>{text(disk.name)} · {number(disk.sizeGb,"GB")}</span>):"—"}</dd></div><div><dt>CPU 温度来源</dt><dd>{text(sample?.cpuTempSource)}</dd></div></dl>
  </section>;
}
