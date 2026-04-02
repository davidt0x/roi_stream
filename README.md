# Photometric ROI Streaming (MATLAB)

This project provides a lightweight MATLAB pipeline for monitoring live camera feeds, extracting intensity traces from circular regions of interest (ROIs), and saving the results to disk for review. It was built around USB/`winvideo` and Hamamatsu/DCAM cameras, plotting traces in real time while logging to HDF5 for post-hoc analysis.

## Features
- Live frame acquisition through MATLAB's Image Acquisition Toolbox (via `videoinput`).
- Automatic frame-rate negotiation with best-effort 60 FPS setup and exposure tuning.
- Efficient circular ROI masking and per-frame mean intensity calculation.
- Real-time GUI (`roi_stream_gui`) with rolling trace buffers and preview frames.
- Streaming HDF5 writer (`H5TracesWriter`) capturing ROI means (and optional dF/F) along with metadata.
- Standalone HDF5 viewer (`h5_traces_viewer`) for quick trace inspection and CSV export.
- Stress-test helpers for randomized ROI layouts and OBS/virtual camera setups.

## Requirements
- MATLAB R2021a or newer (tested on desktop MATLAB).
- Image Acquisition Toolbox with the appropriate adaptor (`winvideo`, `hamamatsu`, or other supported drivers).
- HDF5 support (bundled with MATLAB) for reading/writing trace files.
- Optional: OBS or a comparable virtual camera driver for playing the supplied `test_circle_1280x720_60fps.mp4` test clip.

## Quick Start
1. **Define ROIs and start streaming**
   - Edit `run.m` to match your adaptor, device ID, and video format.
   - Specify your circular ROIs as `[xc yc r]` rows in pixels.
   - Run `run` from MATLAB. This bootstraps the `roi_stream/` library folder, calls `roi_stream`, launches the GUI, and begins logging frames.
2. **Let it run**
   - The GUI updates once per second by default. Frame-rate and drop statistics print to the MATLAB console.
3. **Stop the stream**
   - Call `stop_roi_stream(vid)` (already in `run.m`). This stops acquisition, flushes pending frames, and finalizes the HDF5 file (default name `traces_YYYYMMDD_HHMMSS.h5`).
4. **Review traces**
   - Run `h5_traces_viewer(trace_file_name)` to open the saved file. Use the listbox to toggle ROIs, adjust the time window, and export CSV snapshots.

## Useful Scripts & Functions
- `roi_stream/roi_stream.m`: main acquisition loop; computes ROI means and writes to disk.
- `roi_stream/stop_roi_stream.m`: halts acquisition and finalizes the HDF5 log.
- `roi_stream/roi_stream_gui.m`: live plot and preview UI (launched automatically in demos).
- `roi_stream/H5TracesWriter.m`: helper class that manages extendible HDF5 datasets.
- `roi_stream/h5_traces_viewer.m`: offline viewer for trace files with optional dF/F visualization.
- `run.m`: minimal example; define ROIs manually and stream from a chosen device.
- `run_random_rois.m`: generates non-overlapping random ROIs for stress-testing.
- `ensure_roi_stream_path.m`: adds the shared `roi_stream/` library folder to the MATLAB path for demos and tests.
- `scripts/make_test_video.m`: utilities for producing synthetic clips (for example, circles for OBS playback).
- `tests/test_roi_core.m` and `tests/test_roi_h5_writer.m`: hardware-free smoke tests for ROI math and HDF5 output.

## ROI and Device Tips
- Use `imaqhwinfo` in MATLAB to inspect available adaptors, devices, and formats.
- For `winvideo` sources, formats ending with `_WxH` often encode resolution (for example, `I420_1280x720`).
- `roi_stream` attempts to request 60 FPS and reduce camera exposure automatically; check console warnings if your device cannot honor those settings.
- ROI coordinates are 1-based and should remain inside the frame bounds. The randomized helper enforces margins and minimum center separation to prevent clipping.

## Working with HDF5 Outputs
- ROI circles are stored in `/roi/circles` (N by 3 doubles) and per-frame means in `/roi/means` (frames by ROIs, singles).
- Timestamps in seconds live in `/time`.
- Metadata such as adaptor, device ID, video format, resolution, and start/stop timestamps are written as root attributes.
- If you add dF/F calculations, provide them to `H5TracesWriter.append` and they will be stored in `/roi/dff`.

## Troubleshooting
- **No devices found**: Confirm the adaptor name is installed (`imaqhwinfo`). Some third-party drivers expose numeric or string device IDs; `roi_stream` auto-converts them.
- **Frame-rate below 60 FPS**: Ensure exposure is less than 1/60 s, and the camera driver actually supports the requested format at 60 Hz.
- **GUI not updating**: Confirm the video object remains valid (`isvalid(vid)`) and that frames continue to arrive (console FPS prints).
- **HDF5 file missing**: `stop_roi_stream` finalizes the file; if MATLAB errors beforehand, call `stop` on the video object and re-run the script.

## Roadmap
See `PLAN.md` for the ongoing refactor roadmap, including namespacing, test scaffolding, and packaging improvements.
