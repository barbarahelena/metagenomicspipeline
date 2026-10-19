<!--
Thanks for contributing to the metagenomicspipeline!
Describe what the pull request changes and why. Delete the checklist items that do not apply.
See .github/CONTRIBUTING.md for how to run the checks.
-->

## PR checklist

- [ ] This comment contains a description of changes (with reason).
- [ ] The code lints: `nextflow lint .` reports no errors.
- [ ] The tests pass: `nf-test test --profile +docker`. If results change on purpose, the snapshot is updated (`--update-snapshot`) and its diff explained.
- [ ] New or changed code is covered by a test.
- [ ] New parameters are in `main.nf` (typed), `nextflow_schema.json` and `docs/parameters.md`.
- [ ] `docs/usage.md` and `docs/output.md` are updated.
- [ ] `CHANGELOG.md` is updated.
- [ ] New tools are cited in `CITATIONS.md`.
