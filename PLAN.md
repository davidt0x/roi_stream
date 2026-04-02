# Refactor Plan for roi_stream

1. Catalog existing `.m` files by role (streaming control, ROI math, GUI, H5 I/O, demos) and note scripts that must become functions before packaging.
2. Introduce MATLAB package structure under `+roi_stream/` (subfolders such as `streaming`, `roi`, `io`, `gui` as helpful), move or wrap functions into namespaced entries, and update references to use the package namespace.
3. Convert runnable scripts into examples: place updated scripts in `examples/`, ensure they call into the `roi_stream` package entry points, and remove duplicated setup logic.
4. Establish `tests/` scaffolding with at least one smoke test (mocked or sample video) for `roi_stream` acquisition/output paths; relocate binary assets into `data/` or replace with download instructions.
5. Add project documentation: draft `README.md` covering purpose, MATLAB/toolbox requirements, setup, example usage, package layout, and GUI/viewer notes; include troubleshooting and data expectations.
6. Quality cleanup: run MATLAB `codeAnalyzer` / `checkcode`, address warnings, add clarifying comments where needed, and verify the GUI + streaming flows still operate end-to-end post-refactor.