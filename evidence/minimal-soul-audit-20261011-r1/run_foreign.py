from pathlib import Path
import hashlib,json,re,subprocess,time
out=Path(__file__).resolve().parent
results=[]
for name in ['mutable_root_uid', 'forge_nested_witness', 'copy_edit_ticket', 'drop_edit_ticket', 'store_edit_ticket', 'valid_read_consumer']:
    path=out/'probes/foreign'/name
    cmd=['/opt/homebrew/bin/sui','move','build','--path',str(path),'-e','mainnet']
    t=time.monotonic()
    log=out/'logs'/('foreign-'+name+'.log')
    with log.open('w') as f: r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=90)
    data=log.read_text();errors=re.findall(r'error\[([^]]+)\]: ([^\n]+)',data)
    row={'name':name,'command':cmd,'exit_code':r.returncode,'elapsed_seconds':time.monotonic()-t,'first_error':errors[0] if errors else None,'log':str(log),'source_sha256':hashlib.sha256((path/'sources/probe.move').read_bytes()).hexdigest()}
    results.append(row);print(name,r.returncode,row['first_error'],flush=True)
(out/'foreign-results.json').write_text(json.dumps(results,indent=2)+'\n')
