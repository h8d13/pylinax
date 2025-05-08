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

My thought is that then it would work with doas, or any other permissions framework. 

---

### End goal

Can customize a script to simply check it's in the right environment before running. 

For example:
- Platform types
- Check we have a home dir for the user
- Check lspci outputs or needed HW probes
- Then run appropriate scripts

