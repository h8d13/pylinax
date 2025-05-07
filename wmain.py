import subprocess, os
from pack.env import is_user

script_dir = "./scripts"
######################################
os.makedirs(script_dir, exist_ok=True)

def say_hello():
    subprocess.run(["echo", "Hello", is_user])

def check_home():
    subprocess.run(["ls", f"/home/{is_user}"])

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
