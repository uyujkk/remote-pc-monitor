import { Cpu } from "lucide-react";
import type { Sample } from "./model";
import {useLanguage} from './language';

const text=(value:string|null|undefined)=>value?.trim()||"—";
const number=(value:number|null|undefined,unit:string)=>value==null?"—":`${Math.round(value)} ${unit}`;

export default function HardwareDetails({sample}:{sample:Sample|null}) {
  const {tr}=useLanguage();
  return <section className="panel hardware-panel"><div className="panel-head"><div><h2><Cpu size={18}/>{tr('配件型号','Hardware models')}</h2><p className="muted">{tr('由 Windows 硬件信息读取；不上传序列号','Read from Windows hardware information; serial numbers are not uploaded')}</p></div></div>
    <dl className="hardware-list"><div><dt>{tr('处理器','Processor')}</dt><dd>{text(sample?.cpuName)}</dd></div><div><dt>{tr('主板','Motherboard')}</dt><dd>{text(sample?.motherboardName)}</dd></div><div><dt>{tr('显卡','Graphics card')}</dt><dd>{text(sample?.gpuName)}</dd></div><div><dt>{tr('内存模组','Memory modules')}</dt><dd>{sample?.memoryModules?.length?sample.memoryModules.map((module,index)=><span className="hardware-part" key={`${module.name}-${index}`}>{text(module.name)} · {number(module.capacityGb,"GB")}{module.speedMhz!=null?` · ${number(module.speedMhz,"MHz")}`:""}</span>):"—"}</dd></div><div><dt>{tr('物理磁盘','Physical disks')}</dt><dd>{sample?.storageModels?.length?sample.storageModels.map((disk,index)=><span className="hardware-part" key={`${disk.name}-${index}`}>{text(disk.name)} · {number(disk.sizeGb,"GB")}</span>):"—"}</dd></div><div><dt>{tr('CPU 温度来源','CPU temperature source')}</dt><dd>{text(sample?.cpuTempSource)}</dd></div></dl>
  </section>;
}
