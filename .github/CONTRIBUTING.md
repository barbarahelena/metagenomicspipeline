# Contributing to the metagenomicspipeline

Suggestions and fixes are welcome. Open an [issue](https://github.com/barbarahelena/metagenomicspipeline/issues) to report a bug or discuss a change, or a pull request against the `dev` branch.

## Before you open a pull request

The pipeline uses Nextflow's static types and needs Nextflow 26.10.0 or later.

```bash
nextflow lint .                          # syntax and type errors
nf-test test --profile +docker           # the test suite (add ,+arm on an Apple Silicon Mac)
```

CI runs both, on the minimum supported Nextflow version and the latest stable release.

If a change is meant to alter results, update the expected results with `nf-test test --profile +docker --update-snapshot` and explain the diff of `tests/default.nf.test.snap` in the pull request. The test data is a simulated mock gut community; see [assets/testdata/README.md](../assets/testdata/README.md).

## Conventions

- **Processes** are typed (`nextflow.enable.types = true`): typed inputs, outputs as records, and the tool version in a `topic:` section sent to the `versions` topic, e.g.

  ```nextflow
  topic:
  tuple(task.process, 'fastp', eval('fastp --version 2>&1 | sed -e "s/fastp //g"')) >> 'versions'
  ```

  Do not use `eval()` in processes with `storeDir` (the database downloads): it fails when the task is taken from the store.
- **Every process has a `stub:` block**, so the stub tests can check that all steps are wired correctly.
- **Containers and conda environments** are set in `conf/modules.config`, resources by label in `conf/base.config`.
- **Parameters** are declared, typed, in the `params` block of `main.nf`, and described in `nextflow_schema.json` and `docs/parameters.md`. Parameters that config files read (such as `outdir`) are also set in `nextflow.config`.
- **Results** are published through the `output` block in `main.nf`: add new result files to a workflow `emit:` channel, not with `publishDir`.
- **Reproducibility**: steps that take files from several samples get them sorted by name, and multi-threaded tools must not change the order of reads (see `--reorder` in Bowtie2), because subsampling depends on it.
- The modules in `modules/nf-core` and subworkflows in `subworkflows/nf-core` come from [nf-core/modules](https://github.com/nf-core/modules); update them with `nf-core modules update` rather than editing them.
