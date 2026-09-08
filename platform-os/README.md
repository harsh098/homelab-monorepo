# Platform OS

This directory defines the bootable container (`bootc`) image for our platform VMs.

## Overview

By using `bootc`, we manage the entire operating system as an OCI container image. This replaces the generic Ubuntu cloud-init approach previously used in the `03-compute` layer.

### Benefits of this approach for Day 2 operations:
* **Native CVE Control:** Vulnerabilities are patched by updating the `Containerfile` and publishing a new image, utilizing standard container scanning and CI/CD workflows.
* **Immutable Infrastructure:** Each VM boots directly into an immutable, versioned state of the OS, eliminating configuration drift.
* **Streamlined Updates:** No more ad-hoc shell commands or complex configuration management playbooks needed for base OS patching.

## Building the Disk Image

Execute the `build-image.sh` script to build the bootable container image and generate a `qcow2` disk image suitable for hypervisor deployment.

```bash
./build-image.sh
```

The resulting `qcow2` will be deposited in the `output/` directory, ready to be referenced by the `03-compute` Terraform layer.
