#!/bin/python3
## wmain.py
import subprocess, os
from pack.hw import get_cpu, get_gpu, get_ker, get_usr
from pack.env import is_t_usr
from pack.lookup import script_dir

def check_home():
    home_dir=f"/home/{is_t_usr}"
    print(f"Target user: {is_t_usr}")

    if os.path.isdir(home_dir):  # Check if the directory exists
        print(f"Home directory '{home_dir}' exists.")
        #subprocess.run(["ls", home_dir])
    else:
        print(f"Home directory '{home_dir}' does not exist or is incorrect.")

def check_hw():
    cpu_info = get_cpu()
    if 'Intel' in cpu_info:
        print("CPU Vendor: Intel")
    elif 'AMD' in cpu_info:
        print("CPU Vendor: AMD")
    else:
        print("Unknown CPU Vendor")

    # We can get additional info 

    gpu_info = get_gpu()

    # bit of a mess but should do the job to detect hybrid setups or single gpus 

    if 'Nvidia' in gpu_info and 'Intel' in gpu_info:
        print("GPU Vendor: Hybrid (Intel + Nvidia)")
    elif 'AMD' in gpu_info and 'Radeon' in gpu_info:
        print("GPU Vendor: Hybrid (AMD + Radeon)")
    elif 'Intel' in gpu_info and 'AMD' in gpu_info:
        print("GPU Vendor: Hybrid (Intel + AMD)")
    elif 'Intel' in gpu_info:
        print("GPU Vendor: Intel")
    elif 'AMD' in gpu_info:
        print("GPU Vendor: AMD")
    elif 'Nvidia' in gpu_info:
        print("GPU Vendor: Nvidia")
    else:
        print("Unknown GPU Vendor")

    get_ker()

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
