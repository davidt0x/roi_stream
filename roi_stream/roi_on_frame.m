function roi_on_frame(obj, ~)
%ROI_ON_FRAME Per-frame callback used by roi_stream and embedded pipelines.

S = obj.UserData;

frame = getdata(obj, 1, 'native');
% If callback processing falls behind acquisition, unread frames accumulate
% in the videoinput memory log and can eventually exhaust RAM. Drain any
% backlog after taking one frame so memory stays bounded.
backlog = obj.FramesAvailable;
if backlog > 0
    S.framesDropped = S.framesDropped + backlog;
    try
        flushdata(obj, 'triggers');
    catch
        try
            flushdata(obj);
        catch
        end
    end
end

if ndims(frame) == 3
    frame = mean(frame, 3);
end

f16 = to_uint16_gray(frame);
% Some devices/reporting paths (notably preview/cropped ROI streams) can
% produce frames whose size differs from attach-time VideoResolution.
% Rebuild indices from stored ROI circles when this happens, or when
% precomputed indices are out of bounds for the incoming frame.
[Hf, Wf] = size(f16);
if ~isfield(S, 'roi') || ~isfield(S.roi, 'circles')
    error('roi_stream:MissingROIState', 'ROI state missing from video UserData.');
end

frameShapeMismatch = ~isfield(S.roi, 'frame_size') || ~isequal(S.roi.frame_size, [Hf Wf]);
frameIndexOverflow = false;
if isfield(S.roi, 'max_idx')
    frameIndexOverflow = double(S.roi.max_idx) > numel(f16);
end

if frameShapeMismatch || frameIndexOverflow
    S.roi = roi_build_circle_indices(Hf, Wf, S.roi.circles);
    if ~isfield(S, 'warnedFrameSizeAdjust') || ~S.warnedFrameSizeAdjust
        fprintf('[roi_stream] Adjusted ROI indices for %dx%d frames.\n', Wf, Hf);
        S.warnedFrameSizeAdjust = true;
    end
end
means = roi_compute_means(f16, S.roi);

t = toc(S.tic0);
S.framesSeen = S.framesSeen + 1;
S.frametimes(end+1) = t;
if numel(S.frametimes) > S.maxFT
    S.frametimes = S.frametimes(end - S.maxFT + 1:end);
end

if (t - S.lastPrint) >= S.printEvery
    ft = S.frametimes;
    fps = NaN;
    if numel(ft) >= 2
        fps = (numel(ft) - 1) / max(ft(end) - ft(1), eps);
    end
    fprintf('[%7.3fs] FPS: %5.1f   frames=%d   dropped=%d\n', ...
        t, fps, S.framesSeen, S.framesDropped);
    S.lastPrint = t;
end

S.lastFrame = f16;
S.lastFrameTime = t;

cap = S.trace_capacity;
head = S.trace_head + 1;
if head > cap
    head = 1;
end
S.trace_head = head;
S.trace_t(head) = t;
S.trace_means(head, :) = means;

S.pending_n = S.pending_n + 1;
S.pending_t(S.pending_n) = t;
S.pending_means(S.pending_n, :) = means;

if S.loggingEnabled && S.pending_n >= S.framesPerChunk && ~isempty(S.h5w)
    S.h5w.append(S.pending_t(1:S.pending_n), S.pending_means(1:S.pending_n, :), []);
    S.pending_n = 0;
end

obj.UserData = S;
end
