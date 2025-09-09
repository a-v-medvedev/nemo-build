# nemo-build

`nemo-build` is a set of scripts based on the `dbscripts` project (it is a submodule for this project) to build NEMO ocean global circulation model code. `dbscripts` is located here: https://github.com/a-v-medvedev/dbscripts.

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

You have to make one symlink before you start using the build system: the `machine.yaml` symlink must point to ine of `dnb-*.sh` files, that is the way to choose the machine-dependent confuguration. It is recommended also to make a custom `overrides.yaml` file based on the contents of `overrides_example.yaml`

## Build routine

Two stages are meant:

1. Download stage
2. Build stage

They are separated for convenience: on many HPC systems there are restrictions on downloads from external resources.

To download the source code and input configuration files run:

```
./dnb.sh :du
```

To build and make the `sandbox` directory run:

```
./dnb.sh 
```

which is an equivalent of `./dnb.sh :bi`.

One can also rebuild `NEMO` code later using this command:

```
./dnb.sh nemo:bi 
```

The later procedure will rebuild nemo from source code keeping possible source code changes, whereas `./dnb.sh nemo:ubi` wipes the changes and rebuilds the `NEMO` source code from scratch unpacking the downloaded source code archive.

More info on the `dnb.sh` contents and options can be found in the `dbscripts` README (https://github.com/a-v-medvedev/dbscripts).

## Running the result

The binary is collected in the `sandbox` directory that is created after the "installation" stage of build. The test confuguration files together with initial and boundary conditions are also located in the `sandbox` directory.

The `psubmit.opt` file is generated to allow running the testcase using the `psubmit` tool if user prefers to use it (https://github.com/a-v-medvedev/psubmit). The `psubmit.opt` contents is generated based on the settings from `dnb.yaml`, `machine.yaml` and `overrides.yaml` files.

