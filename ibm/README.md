# Generating configuration with Butane

The MachineConfig files in this directory were generated with Butane from other
files in this directory.

To generate after making changes to the source files run (From the root of this
repo):

```
butane -d ibm/ ibm/mc-45-worker-kata-remote-config-ibm.bu > ibm/mc-45-worker-kata-remote-config-ibm.yaml
butane -d ibm/ ibm/mc-55-kata-remote-ibm.bu > ibm/mc-55-kata-remote-ibm.yaml
```

Note: The MachineConfig resource here are not really usable with ROSA. See
details in the FINDINGS.md file.
