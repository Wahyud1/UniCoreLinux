# UniCore .kext modules

This folder contains example .kext-style wrappers. A `.kext` in this project is a directory
with an `Info.plist` describing the bundle and a `module.ko` file which is either a real
kernel module or a symlink to a module shipped under `system/modules/`.

Example layout:

```
example.GPU.kext/
  Info.plist
  module.ko -> ../../system/modules/real-gpu.ko
```

The runtime loader `unicore-kextctl` (not included here) will `insmod` the `module.ko`.
For production, prefer proper kernel module packaging, DKMS, and module signing for Secure Boot.
