from pathlib import Path
import json,subprocess,time,re,hashlib
from datetime import datetime,timezone
out=Path(__file__).resolve().parent
root=out.parents[1]
results=[]
checks=[('production-build', ['move','build','--path',str(out/'package'),'-e','mainnet'],0,None),('combined-tests',['move','test','--path',str(out/'package'),'-e','mainnet'],0,None)]
expected={'mutable_root_uid':'EC04001','forge_nested_witness':'EC04001','copy_edit_ticket':'EC05001','drop_edit_ticket':'EC05001','store_edit_ticket':'EC05001','valid_read_consumer':None}
for name,code in expected.items():
 checks.append(('foreign-'+name,['move','build','--path',str(out/'foreign'/name),'-e','mainnet'],0 if code is None else 1,code))
for name,args,wanted,code in checks:
 cmd=['/opt/homebrew/bin/sui']+args
 start=datetime.now(timezone.utc).isoformat(); t=time.monotonic()
 p=subprocess.run(cmd,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 log=p.stdout; (out/'logs'/f'{name}.log').write_text(log)
 clean=re.sub(r'\x1b\[[0-9;]*m','',log)
 codes=sorted(set(re.findall(r'EC\d+',clean)))
 result={'name':name,'command':cmd,'started_at_utc':start,'elapsed_seconds':round(time.monotonic()-t,3),'exit_code':p.returncode,'expected_exit_code':wanted,'diagnostic_codes':codes,'expected_diagnostic':code,'matched_expectation':p.returncode==wanted and (code is None or code in codes),'summary':[line for line in clean.splitlines() if 'Test result:' in line],'pass_rows':len(re.findall(r'^\[\s*PASS\s*\]',clean,re.M)),'fail_rows':len(re.findall(r'^\[\s*FAIL\s*\]',clean,re.M)),'gas_limit_override':None}
 results.append(result)
 (out/'checks.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({k:result[k] for k in ['name','exit_code','matched_expectation','summary','diagnostic_codes']},ensure_ascii=False),flush=True)
 if not result['matched_expectation']:
  print(clean[-8000:],flush=True)
original=json.loads((out/'inputs.json').read_text())
integrity=[{'path':i['path'],'expected':i['sha256'],'actual':hashlib.sha256(Path(i['path']).read_bytes()).hexdigest()} for i in original['inputs']]
for i in integrity:i['matched']=i['expected']==i['actual']
module_unchanged=hashlib.sha256((root/'module.json').read_bytes()).hexdigest()==original['module_json_sha256_before']
(out/'integrity.json').write_text(json.dumps({'checks':integrity,'module_json_unchanged':module_unchanged,'all_input_bytes_unchanged':all(i['matched'] for i in integrity)},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'checks_matched':sum(r['matched_expectation'] for r in results),'checks_total':len(results),'all_inputs_unchanged':all(i['matched'] for i in integrity),'module_json_unchanged':module_unchanged}),flush=True)
