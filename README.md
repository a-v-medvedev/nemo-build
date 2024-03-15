# nemo-build

`nemo-build` is a set of scripts based on the `dbscripts` project (it is a submodule for this project) to build NEMO ocean global circulation model code.

## Cloning

Use `--recursive` flag for `git clone` command:

```
git clone --recursive git@github.com:a-v-medvedev/nemo-build.git
```

If you cloned the repository without --recursive option, get the sub-modules afterwards:

```
git submodule update --init
```

## Basic setup

You have to make two symlinks before you start using the build system:

- the `env.sh` symlink must point to ine of `env-*.sh` files, that is the way to choose the machine-dependant confuguration.
- the `nemo-build.inc` symlink must point to one of the `nemo-build-*.sh` files to select NEMO version, build configuration, and test workload configuration details.


## Build routine

Two stages are meant:

1. Download stage
2. Build stage

They are separated for convenience: on many HPC systems there are restrictions on downloads from external resources.

To download the source code and input configuration files run:

```
./dnb.sh :d
```

To build and make the `sandbox` directory run:

```
./dnb.sh 
```

which is an equivalent of `./dnb.sh :ubi` if we have the `export DEFAULT_BUILD_MODE=":ubi"` setting in the `env.sh` file (which is recommended).

One can also rebuild `NEMO` code later using this command:

```
./dnb.sh nemo:bi 
```

The later procedure will rebuild nemo from source code keeping possible source code changes, whereas `./dnb.sh nemo:ubi` wipes the changes and rebuilds the `NEMO` source code from scratch unpacking the downloaded source code archive.


## Running the result


The binary is collected in the `sandbox` directory that is created after the "installation" stage of build. The test confuguration files together with initial and boundary conditions are also located in the `sandbox` directory.

The `psubmit.opt` file is generated to allow running the testcase using the `psubmit` tool if user prefers to use it (https://github.com/a-v-medvedev/psubmit). The `psubmit.opt` contents is generated based on the settings from `env.sh` file.






