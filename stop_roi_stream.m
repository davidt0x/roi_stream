function filename = stop_roi_stream(vid)
if nargin < 1 || ~isvalid(vid), filename = ''; return; end
S = vid.UserData;
filename = '';
try, stop(vid); catch, end
filename = roi_finalize_from_video(vid);
elapsed = toc(S.tic0);
avgFPS  = S.framesSeen / max(elapsed, eps);
if ~isempty(filename)
    fprintf('[roi_stream] HDF5 saved: %s\n', filename);
end
fprintf('[roi_stream] Stopped. Elapsed: %.3fs, frames: %d, avg FPS: %.2f\n', elapsed, S.framesSeen, avgFPS);
try, delete(vid); catch, end
end
