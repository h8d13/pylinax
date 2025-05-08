import subprocess, os
from pack.hw import get_cpu, get_gpu, get_mem, get_ker, get_usr
from pack.env import is_t_usr

script_dir= "./scripts"
######################################
os.makedirs(script_dir, exist_ok=True)

usr_info = get_usr()

def say_hello():    
    subprocess.run(["echo", "Hello", usr_info])

def check_home():
    home_dir=f"/home/{is_t_usr}"
    print(f"Target user? {is_t_usr}.")

    if os.path.isdir(home_dir):  # Check if the directory exists
        print(f"Home directory '{home_dir}' exists and is the correct target.")
        subprocess.run(["ls", home_dir])
    else:
        print(f"Home directory '{home_dir}' does not exist or is incorrect.")

def check_hw():
    get_cpu()
    get_gpu()
    get_ker()
    get_mem()

def _exec_scripts():
    ## Execute Shell Scripts
    if os.path.exists(script_dir):
        scripts = [script for script in os.listdir(script_dir) if script.endswith(".sh") and os.path.isfile(os.path.join(script_dir, script))]
        
        # Sort the scripts alphabetically
        scripts.sort()

        for script in scripts:
            script_path = os.path.join(script_dir, script)
            print(f"Executing script: {script}")
            try:
                subprocess.run(["bash", script_path], check=True)
                print(f"Successfully executed {script}")
            except subprocess.CalledProcessError as e:
                print(f"Error executing {script}: {e}")
