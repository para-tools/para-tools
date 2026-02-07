# para-tools

A collection of simple scripts for assisting with development on Linux platforms

These include:

| Tool                | Function                                                            |
|---------------------|---------------------------------------------------------------------|
| para-dir-hash       | Generates text hashes of directories that can be compared           |
| para-local-install  | A handy shortcut for installing a python script as a system command |

## Installing the latest version
<!-- markdown-link-check-disable-next-line -->
The latest version is at **[releases/latest](releases/latest)**

## What does 'para' mean ?

* From Greek: "beside," "alongside," or "beyond" (eg: parallel)
* From Latin: "shield against" or "protection"   (eg: parachute, parasol).
* From Finnish Mythology: A helpful house spirit who collects helpful titbits for the owner

It is the 'Finnish Mythology' usage that this archive is named after.


# Development Notes #

Note: These 'development notes' at the end are not included in the 'readme.md' that is installed.

## Coding styles ##

These are provided in the `.pre-commit-config.yaml`

To ensure that they are enforced:  `pre-commit install`

You can review at any time with `pre-commit run -a`

## Building Package & Installing ##

To create the debian package:
```shell
./do-create-deb-package.sh
```

The 'do-create-deb-package.sh' script will also give instructions on how to install the package afterwards.

## Future Roadmap ##

Adding tests
Collect other tools and include
