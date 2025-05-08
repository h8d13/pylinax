# pylinax v25.05

## Define what
- Lookup table: Alpine, Deb, Arch
  - Package manager definitions
- Elevated Linux check
  - Platform checks 
- Parse `reqs.hl` file
  - Mark installations
  - Mark already installed
Format similar to `requirements.txt`:
```
cowsay
util-linux
pciutils
```

- Run bin `./scripts` alphabetically
- Single entry-point that takes perms as postfix (arg1)
Ex: `./run.sh sudo`

---

### End goal

Can customize a script to simply check it's in the right environment before running. 

For example:
- Package manager > Distro
- Check lspci outputs or needed HW probes
- Check we have a home dir for the user
- Then run appropriate scripts
  - Logical flow for scripts 
    - Make user changes first + Chown
    - Then root changes
    - Then any major and proper clean + reboot
