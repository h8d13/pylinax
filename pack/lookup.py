#!/bin/python3
# lookup.py
import os
import subprocess
import uuid

# Unified structure for package manager operations
pkg_managers = {
    "debian": {
        "pm": "apt",
        "install": "install",
        "remove": "remove",
        "args": "-y"
    },
    "arch": {
        "pm": "pacman",
        "install": "-S",
        "remove": "-R",
        "args": "--noconfirm"
    },
    "alpine": {
        "pm": "apk",
        "install": "add",
        "remove": "del",
        "args": "--nocache"
    }
}

head_reqs=f"./.reqs.hl"
head_dir="./.hl"
head_file=f"{head_dir}/.head"
script_dir= "./scripts"
y = uuid.uuid4()
x = str(y.int)[:6]
######################################
os.makedirs(head_dir, exist_ok=True)
os.makedirs(script_dir, exist_ok=True)


def rline(res):
    return res.strip()

def get_os_fields(field: str) -> str:
    try:
        result = subprocess.run(
            ["grep", "-oP", fr'(?<=^{field}=)[^\n]*', "/etc/os-release"],
            capture_output=True, text=True, check=True
        )
        return rline(result.stdout)
    except subprocess.CalledProcessError:
        return ""

dist_val = get_os_fields("ID")
dist_fam = get_os_fields("ID_LIKE")
print(f"DV:{dist_val} - DF:{dist_fam}")

def install_packs():
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

def is_installed(pkg, pm, dist_fam):
    if dist_fam == "debian":
        check_cmd = ["dpkg", "-l"]
    elif dist_fam == "arch":
        check_cmd = ["pacman", "-Qs", pkg]
    elif dist_fam == "alpine":
        check_cmd = ["apk", "list", "--installed"]
    else:
        return False
    
    try:
        result = subprocess.run(check_cmd, capture_output=True, text=True)
        return pkg in result.stdout
    except Exception as e:
        print(f"Check failed: {e}")
        return False




