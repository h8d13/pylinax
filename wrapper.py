#!/bin/python3
## wrapper.py
from pack.env import is_admin, is_system, is_t_usr
from pack.hw import get_usr
from pack.lookup import install_packs, x
import subprocess

usr_info, is_root = get_usr() 

is_algod = is_admin and is_system == "Linux" #and is_root
# can add conditions for run here ^^
#print(f"EL: {is_algod}")

if is_algod:
    # Parse the .reqs.hl file and mark 0, 1 + install
    install_packs()

    from wmain import check_home, check_hw, _exec_scripts
    check_hw()
    # Perform actions based on hardware

    check_home()
    # If making user changes make sure to give back all perms.
    #######################################
    # If making root changes do them after user changes and giving back ownership 
    # Prereqs can be a_1 to a_x
    # Could for example write scripts as u_1 to u_x, then perms (see snippet bellow), then z_1 to z_x root changes.
    ## Simple: 1 rule: do all user home work, then give back recursive. 
    ## chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/
    
    ## Example work cowsay moo?
    subprocess.run(["/usr/games/cowsay", "Hellooo"], stdout=open("output.txt", "w"))
    subprocess.run(["echo", "Hmmoo",str(x)], stdout=open("output.txt", "a"))
    # Give back ownership to target user
    subprocess.run([f"chown", f"{is_t_usr}:{is_t_usr}", "output.txt"])

    _exec_scripts() 
    # Optional: uninstall for packages only needed once
    # for pack in packs:
    #     subprocess.run([pm_info["pm"], pm_info["remove"], pm_info["args"], pack])
    #      with open("./.hl/.head", "a") as f:
    #         f.write(f"{pack}: 0\n")
    #         print(f".head file updated for {pack}")

else:
    print("Run as admin/root on a Linux system.")
