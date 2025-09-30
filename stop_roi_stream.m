function filename = stop_roi_stream(vid)
if nargin < 1 || ~isvalid(vid), filename = ''; return; end
S = vid.UserData;
filename = '';
try, stop(vid); catch, end

elapsed = toc(S.tic0);
avgFPS  = S.framesSeen / max(elapsed, eps);

% Flush any remaining rows to disk via the writer
try
    if isfield(S,'h5w') && ~isempty(S.h5w)
        filename = char(S.h5w.path);
        if S.pending_n > 0
            S.h5w.append(S.pending_t(1:S.pending_n), S.pending_means(1:S.pending_n,:), []);
            S.pending_n = 0;
        end
        summary = struct( ...
            'end_iso8601',   char(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZ')), ...
            'frames_seen',   uint64(S.framesSeen), ...
            'frames_dropped',uint64(S.framesDropped), ...
            'elapsed_sec',   double(elapsed), ...
            'avg_fps',       double(avgFPS));
        S.h5w.finalize(summary);
        fprintf('[roi_stream] HDF5 saved: %s (rows=%d)\n', S.h5w.path, S.h5w.rows);
    end
catch ME
    warning('HDF5 finalize failed: %s', ME.message);
end

fprintf('[roi_stream] Stopped. Elapsed: %.3fs, frames: %d, avg FPS: %.2f\n', elapsed, S.framesSeen, avgFPS);
try, delete(vid); catch, end
end
