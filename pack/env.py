#!/bin/python3
## env.py
import os
import sys
import platform

### ADMIN + USER ###
is_admin = None

if os.getuid() == 0:
    is_admin = True
    is_t_usr = (os.getlogin())
    print(f"Target user? {is_t_usr}.")
else:
    is_admin = False
    print(f"Admin? {is_admin}. Please run elevated.")

### VENV + V + CWD ###
is_venv = sys.prefix != getattr(sys, "base_prefix", sys.prefix)
print(f"VENV: {is_venv}")
is_python = platform.python_version()
print(f"PV: {is_python}")
is_cwd=os.getcwd()

### PLAT ###
is_system = platform.system() 
print(f'ST: {is_system}')




