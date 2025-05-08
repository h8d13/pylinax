import subprocess
# Detect GPU using lspci
def get_gpu():
    gpu_info = subprocess.check_output("lspci | grep -i '3D\\|VGA'", shell=True).decode('utf-8')
    print(f"Detected GPU: {gpu_info}")
    return gpu_info

def get_ker():
    ker_info = subprocess.check_output("uname -r", shell=True).decode('utf-8')
    print(f"Detected KER: {ker_info}")
    return ker_info

# Detect CPU using lspci
def get_cpu():
    cpu_info = subprocess.check_output("lscpu | grep -E 'Model name|Socket|Thread|Core|CPU(s)'", shell=True).decode('utf-8')
    print(f"Detected CPU: {cpu_info}")
    return cpu_info

def get_mem():
    mem_info = subprocess.check_output("lsblk", shell=True).decode('utf-8')
    print(f"Detected MEM: {mem_info}")
    return mem_info

def get_usr():
    usr_info = subprocess.check_output("whoami", shell=True).decode('utf-8').strip()
    if usr_info == "root":
        is_root = True
    else:
        is_root = False
        
    print(f"USR: {usr_info}")
    print(f"ROOT: {is_root}")

    return usr_info, is_root
