function stop_roi_stream(vid)
% STOP_ROI_STREAM  Gracefully stop and report average FPS.
if nargin < 1 || ~isvalid(vid), return; end
S = vid.UserData;
try, stop(vid); catch, end
try
    t = toc(S.tic0);
    fps = S.framesSeen / max(t, eps);
    fprintf('[roi_stream] Stopped. Elapsed: %.3fs, frames: %d, avg FPS: %.2f\n', ...
            t, S.framesSeen, fps);
catch
    fprintf('[roi_stream] Stopped.\n');
end
try, delete(vid); catch, end
end
