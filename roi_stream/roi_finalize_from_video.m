function filename = roi_finalize_from_video(vid, summary, pulse_times)
%ROI_FINALIZE_FROM_VIDEO Flush ROI trace buffers and finalize the HDF5 file.

filename = '';
if nargin < 2 || isempty(summary)
    summary = struct();
end
if nargin < 3
    pulse_times = [];
end
if nargin < 1 || isempty(vid) || ~isvalid(vid)
    return;
end

try
    S = vid.UserData;
catch
    return;
end

if ~isstruct(S) || ~isfield(S, 'h5w') || isempty(S.h5w)
    return;
end

filename = char(S.h5w.path);

elapsed = [];
avgFPS = [];
if isfield(S, 'tic0') && isfield(S, 'framesSeen')
    elapsed = toc(S.tic0);
    avgFPS = S.framesSeen / max(elapsed, eps);
end

try
    if isfield(S, 'pending_n') && S.pending_n > 0
        S.h5w.append(S.pending_t(1:S.pending_n), S.pending_means(1:S.pending_n, :), []);
        S.pending_n = 0;
    end

    if ~isfield(summary, 'end_iso8601') || isempty(summary.end_iso8601)
        summary.end_iso8601 = char(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSZ'));
    end
    if ~isfield(summary, 'frames_seen') && isfield(S, 'framesSeen')
        summary.frames_seen = uint64(S.framesSeen);
    end
    if ~isfield(summary, 'frames_dropped') && isfield(S, 'framesDropped')
        summary.frames_dropped = uint64(S.framesDropped);
    end
    if ~isfield(summary, 'elapsed_sec') && ~isempty(elapsed)
        summary.elapsed_sec = double(elapsed);
    end
    if ~isfield(summary, 'avg_fps') && ~isempty(avgFPS)
        summary.avg_fps = double(avgFPS);
    end

    S.h5w.finalize(summary);
    if ~isempty(pulse_times)
        write_pulse_times(filename, pulse_times);
    end
catch ME
    warning('HDF5 finalize failed: %s', ME.message);
end

vid.UserData = S;
end

function write_pulse_times(h5path, pulse_times)
pulse_times = double(pulse_times(:));
if isempty(pulse_times)
    return;
end

try
    h5info(h5path, '/events/pulse_times');
catch
    h5create(h5path, '/events/pulse_times', size(pulse_times), 'Datatype', 'double');
end
h5write(h5path, '/events/pulse_times', pulse_times);
end
