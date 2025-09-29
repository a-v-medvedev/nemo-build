# nemo-build

`nemo-build` is a set of scripts based on the `dbscripts` project (it is a submodule for this project) to build NEMO ocean global circulation model code. `dbscripts` is located here: https://github.com/a-v-medvedev/dbscripts.

## Prerequisites:

The `yq` utility, can be downloaded like this:

```
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/bin/yq
```

The `psubmit` utility, can be cloned from Git repository and manually copied to ~/bin:

```
git clone https://github.com/a-v-medvedev/psubmit.git
```


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

### >> machine symlink

Make a symlimk to a machine file, for example:

`ln -s dnb-mn5-acc.yaml machine.yaml`

Here the files named `dnb-XXX.yaml` are assumed to be individual files collecting the settings special to a certain HPC system.

### >> build-specific overrides

The optional `overrides.yaml` can be created to specify some build options and/or specifically override some of the `dnb.yaml` and/or `machine.yaml` settings, if needed. In practical sense, we can choose with-gpu or without-gpu build options, reproducible or optimized build options, switch on and off the NVTX-based profiling, etc. There is an `overrides-example.yaml` file with some comments, use it a reference to create your own `overrides.yaml`. This example contains two parts: for community NEMO 4 and for comunity NEMO 5, choose one that is relevant to you.

It is recommended always to use the `DNB_SANDBOX_SUBDIR` variable to set a particular subdirectory name for each build type. For example, it is handy to have `nemo.gpu` and `nemo.cpu` subdirectories to sort out the GPU-enables build from CPU-only. This adds more structure to the work at runtime.

### >> download stage

Run: `./dnb.sh :du` to download and unpack source code archives.

### >> build stage

Run: `./dnb.sh` to build everything.

which is an equivalent of `./dnb.sh :bi`. The later procedure will rebuild nemo from source code keeping possible source code changes, whereas `./dnb.sh nemo:ubi` wipes the changes and rebuilds the `NEMO` source code from scratch unpacking the downloaded source code archive.

More info on the `dnb.sh` contents and options can be found in the `dbscripts` README (https://github.com/a-v-medvedev/dbscripts).


### >> run the test case

Execute the benchmark on a machine:

- go to the `sandbox` directory,
- run: `./psubmit.sh -u SUBDIR`
- check out the results in the `results.XXXXXX` directory, where `XXXXXX` stands for slurm job id

This way of executing will run NEMO with ORCA2 input on a single node with the default parallel configuration. You may change many parameters of parallel execution (number of nodes, number of MPI ranks per node, number of OpenMP threads, and many more) using the `psubmit.sh` command line (see `https://github.com/a-v-medvedev/psubmit/blob/master/README.md`). The `psubmit.opt` containing the defaults is created automatically by `dnb.sh` based on corresponding yaml files contents. The `psubmit.opt` contents is generated based on the settings from `dnb.yaml`, `machine.yaml` and `overrides.yaml` files.

