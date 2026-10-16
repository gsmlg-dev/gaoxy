import subprocess,sys
p=subprocess.Popen([sys.executable,"-B","-c","import time; time.sleep(60)"],start_new_session=True)
print(p.pid,flush=True)
