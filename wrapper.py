#!/bin/python3
## wrapper.py
from pack.env import is_cwd, is_admin, is_python, is_system, is_venv
from pack.lookup import rline, get_os_fields, pkg_managers, is_installed
import subprocess, os
import random, uuid

head_dir="./.hl"
head_file=f"{head_dir}/.head"
head_reqs=f"./.reqs.hl"

######################################
os.makedirs(head_dir, exist_ok=True)
y = uuid.uuid4()
x = str(y.int)[:6]

is_algod = is_admin and is_system == "Linux" 
print(f"EL: {is_algod}")

if is_algod:
    dist_val = get_os_fields("ID")
    dist_fam = get_os_fields("ID_LIKE")

    print(f"DV:{dist_val} - DF:{dist_fam}")

    if dist_fam in pkg_managers:
        pm_info = pkg_managers[dist_fam]

        # Read package names from .reqs.hl file
        try:
            with open(head_reqs, "r") as f:
                packs = f.read().splitlines()
        except FileNotFoundError:
            print(f"{head_reqs} file not found. Please create it with package names.")
            exit(1)

        for pack in packs:
            pack = pack.strip()  # Split by " " empty space 
            if pack:  # Ignore empty lines
                if not is_installed(pack, pm_info["pm"], dist_fam):
                    # if not installed we write 0 to file, install then write 1
                    print(f"Installing: {pack}")
                    with open(head_file, "a") as f:
                        status = 0
                        f.write(f"MN:{x} - {pack}: {status}\n")

                    try:
                        subprocess.run([pm_info["pm"], pm_info["install"], pm_info["args"], pack])
                        with open(head_file, "a") as f:
                            status = 1
                            f.write(f"MN:{x} - {pack}: {status}\n")

                    except subprocess.CalledProcessError as e:
                        print(f"Failed to install {pack}: {e}")
            
                else:
                    # was already installed write a 1 directly
                    print(f"Already installed: {pack}")
                    with open(head_file, "a") as f:
                        status = 1
                        f.write(f"MN:000000 - {pack}: 1\n")


        from wmain import say_hello, check_home, check_hw, _exec_scripts
        say_hello()
        check_home()

        # If making user changes make sure to give back all perms.
        #######################################
        # If making root changes do them after user changes and giving back ownership 
        # Could for example write scripts as u_1 to u_x, then perms (see snippet bellow), then z_1 to z_x root changes.
        ## chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/
        # And prereqs can be 0 or a. 

        check_hw()
        
        ## Example work
        subprocess.run([f"/usr/games/cowsay", "Hellooo"], stdout=open("output.txt", "w"))
        subprocess.run(["echo", "Hmmoo",str(random.randint(0, 31))], stdout=open("output.txt", "a"))

        _exec_scripts() 

        # Optional: uninstall
        # for pack in packs:
        #     subprocess.run([pm_info["pm"], pm_info["remove"], pm_info["args"], pack])
        #      with open("./.hl/.head", "a") as f:
        #         f.write(f"{pack}: 0\n")
        #         print(f".head file updated for {pack}")

    else:
        print("Not implemented for this distro family.")

else:
    print("Run as root on a Linux system.")
