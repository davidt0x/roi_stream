function roi_on_frame(obj, ~)
%ROI_ON_FRAME Per-frame callback used by roi_stream and embedded pipelines.

S = obj.UserData;

frame = getdata(obj, 1, 'native');
if ndims(frame) == 3
    frame = mean(frame, 3);
end

f16 = to_uint16_gray(frame);
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
