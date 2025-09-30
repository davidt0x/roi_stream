%% run_random_rois.m
% Stress-test the pipeline with many random circular ROIs.

% ---- Config ----
adaptor   = 'winvideo';
deviceID  = 2;                      % your OBS virtual cam device index
format    = 'I420_1280x720';        % keep matching your OBS canvas
N         = 24;                    % <— number of ROIs to generate
radiusPx  = [8 25];                 % [min max] radius in pixels
marginPx  = 6;                      % keep ROIs away from edges
minSepPx  = 4;                      % min center-to-center gap beyond radii (0 = allow overlap)
seed      = 42;                     % [] for non-reproducible

% GUI
guiOpts   = struct('PlotWindowSec', 60, 'UpdatePeriod', 1/30, 'ImagePeriod', 1/30);

% Streamer opts (extra fields are ignored if your roi_stream doesn’t use them)
streamOpts = struct('TraceBufferSec', 600, 'FramesPerChunk', 120);

% ---- Determine frame size from format or device ----
[W,H] = guess_dims_from_format_or_device(adaptor, deviceID, format);

% ---- Generate random ROIs within bounds ----
roiCircles = random_circles(W, H, N, radiusPx, marginPx, minSepPx, seed);

fprintf('Generated %d ROIs within %dx%d\n', size(roiCircles,1), W, H);

% ---- Start the stream + GUI ----
vid = roi_stream(adaptor, deviceID, format, roiCircles, streamOpts);
hGui = roi_stream_gui(vid, guiOpts); %#ok<NASGU>

%% ---------- helpers (local) ----------

function [W,H] = guess_dims_from_format_or_device(adaptor, deviceID, format)
% Try to parse "..._WxH" from the format string; if that fails, query device.
W = []; H = [];
tok = regexp(format, '_(\d+)x(\d+)', 'tokens', 'once');
if ~isempty(tok)
    W = str2double(tok{1}); H = str2double(tok{2});
end
if isempty(W) || isempty(H) || any(isnan([W H]))
    vtmp = [];
    try
        vtmp = videoinput(adaptor, deviceID, format);
        vr = vtmp.VideoResolution; W = vr(1); H = vr(2);
    catch
        warning('Could not query device for resolution; defaulting to 1280x720.');
        W = 1280; H = 720;
    end
    try, delete(vtmp); catch, end
end
end

function roiCircles = random_circles(W, H, N, radRange, margin, minSep, seed)
% Generate up to N circles [xc yc r] inside W×H with optional separation.
if nargin<7 || isempty(seed), rng('shuffle'); else, rng(seed); end
rmin = radRange(1); rmax = radRange(2);
roiCircles = zeros(N,3);
placed = 0; attempts = 0; maxAttempts = 300*N;

while placed < N && attempts < maxAttempts
    attempts = attempts + 1;
    r  = rmin + (rmax - rmin) * rand();
    xc = margin + r + (W - 2*(margin + r)) * rand();
    yc = margin + r + (H - 2*(margin + r)) * rand();
    % snap centers to integer pixels (optional, usually cleaner)
    xc = round(xc); yc = round(yc);
    if xc-r < 1 || xc+r > W || yc-r < 1 || yc+r > H
        continue; % safety, though we tried to keep within bounds
    end
    ok = true;
    if placed > 0 && minSep > 0
        d2 = (roiCircles(1:placed,1) - xc).^2 + (roiCircles(1:placed,2) - yc).^2;
        minCenterDist = roiCircles(1:placed,3) + r + minSep;
        ok = all(d2 >= (minCenterDist.^2));
    end
    if ok
        placed = placed + 1;
        roiCircles(placed,:) = [xc yc r];
    end
end

if placed < N
    warning('Placed %d/%d ROIs. Reduce minSep or radius, or use a larger frame.', placed, N);
    roiCircles = roiCircles(1:placed,:);
end
end
