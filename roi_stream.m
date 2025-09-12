function vid = roi_stream(adaptor, deviceID, format, roiCircles, opts)
% ROI_STREAM  Online circular-ROI intensity extraction with FPS + GUI support.
%
% vid = roi_stream(adaptor, deviceID, format, roiCircles, opts)
%   adaptor: 'winvideo' or 'hamamatsu'
%   deviceID: numeric ID ([] to auto-pick)
%   format: format string ('' to auto-pick)
%   roiCircles: Nx3 [xc, yc, r] (1-based pixels)
%   opts.FramesPerChunk   (default 120)   % aggregation cadence (hook for file I/O)
%   opts.PrintFPSPeriod   (default 1.0)   % seconds between FPS logs
%   opts.ReturnColorSpace (default 'grayscale')
%   opts.TraceBufferSec   (default 600)   % ~10 min ring buffer for GUI plot (60 Hz)
%
% Call stop_roi_stream(vid) to stop.

if nargin < 5, opts = struct(); end
opts = filldefaults(opts, struct('FramesPerChunk',120, ...
                                 'PrintFPSPeriod',1.0, ...
                                 'ReturnColorSpace','grayscale', ...
                                 'TraceBufferSec',600));

% ---- Auto-pick device/format if not provided
if nargin < 2 || isempty(deviceID), deviceID = auto_pick_device(adaptor); end
if nargin < 3 || isempty(format),   format   = auto_pick_format(adaptor, deviceID); end

% ---- Create video input
vid = videoinput(adaptor, deviceID, format);
vid.TriggerRepeat    = 0;
vid.FramesPerTrigger = inf;
triggerconfig(vid,'immediate');
vid.LoggingMode = 'memory';
try
    vid.ReturnedColorspace = opts.ReturnColorSpace;
catch
    % Some adaptors don't support ReturnedColorspace; handled below
end

% Request high-FPS + disable low-light/auto exposure
try
    disable_low_light_compensation(vid);   % uses the live handle, no reopen
catch ME
    fprintf('[roi_stream] LLC/60fps tuning skipped: %s\n', ME.message);
end

src = getselectedsource(vid);
try, set(src,'FrameRate'), end   % see available values
try, disp(get(src,'FrameRate')), end


% --- Try to set 60 fps on the source if the driver exposes it
src = getselectedsource(vid);
try
    % Most winvideo sources expose enumerated strings for FrameRate
    vals = set(src, 'FrameRate');  % cellstr of allowed values OR numeric scalar
    if iscell(vals)
        % try exact '60.0000', fallback to any '60'ish
        pick = find(strcmp(vals,'60.0000') | strcmp(vals,'60'), 1);
        if isempty(pick)
            % try the highest available
            [~, pick] = max(str2double(regexprep(vals,'[^0-9\.]','')));
        end
        src.FrameRate = vals{pick};
    else
        % numeric property
        src.FrameRate = 60;
    end
    fprintf('[roi_stream] Requested FrameRate=%s\n', string(get(src,'FrameRate')));
catch ME
    fprintf('[roi_stream] FrameRate not settable on this source (%s)\n', ME.identifier);
end

% Exposure must be < 1/60 s for the camera to actually deliver 60 fps
try
    if isprop(src,'ExposureMode'), src.ExposureMode = 'Manual'; end
catch, end
try
    % Property name varies; try a few common ones
    if isprop(src,'ExposureTime')      % seconds
        src.ExposureTime = min(getfield(propinfo(src,'ExposureTime'),'Constrange').Max, 1/120);
    elseif isprop(src,'Exposure')      % units vary; set small
        src.Exposure = min(src.Exposure, 5);
    elseif isprop(src,'Shutter')       % milliseconds often
        src.Shutter = min(src.Shutter, 8);
    end
catch
    % okay if we can't set it here
end


% ---- Precompute circular ROI indices
vr = vid.VideoResolution;  % [W H]
W = vr(1); H = vr(2);
roi = build_circle_indices(H, W, roiCircles);  % .idx (cell), .npix (uint32), .circles

% ---- Initialize per-stream state (stored in UserData)
S = struct();
S.roi = roi;

S.tic0        = tic;       % wall clock start
S.lastPrint   = 0;         % last FPS print (s)
S.printEvery  = opts.PrintFPSPeriod;
S.framesSeen  = 0;
S.framesDropped = 0;       % placeholder for future drop-accounting
S.frametimes  = [];        % recent times for instantaneous FPS calc
S.maxFT       = max(2*opts.FramesPerChunk, 300);

% chunk buffer (optional write hook)
S.framesPerChunk = opts.FramesPerChunk;
S.pending_n      = 0;
S.pending_t      = zeros(opts.FramesPerChunk,1,'double');
S.pending_means  = zeros(opts.FramesPerChunk, numel(roi.npix), 'single');

% preview frame (read by GUI timer)
S.lastFrame      = [];     % uint16, HxW
S.lastFrameTime  = 0;

% rolling trace buffer (GUI plot reads this)
cap = max(60 * opts.TraceBufferSec, 6000);  % ensure sensible minimum
K   = numel(roi.npix);
S.trace_capacity = cap;
S.trace_head     = 0;                       % 0-based count, 1..cap indices used
S.trace_t        = nan(cap,1);              % seconds since start
S.trace_means    = nan(cap,K,'single');

vid.UserData = S;

% ---- Register callback (1 call per acquired frame)
vid.FramesAcquiredFcnCount = 1;
vid.FramesAcquiredFcn      = @onFrame;

% ---- Start streaming and return handle
start(vid);

fprintf('[roi_stream] Started %s (device %d, format %s), %dx%d px\n', ...
    adaptor, deviceID, format, W, H);
fprintf('[roi_stream] %d circular ROI(s). FPS every %.1fs. Call stop_roi_stream(vid) to stop.\n', ...
    numel(roi.npix), S.printEvery);
end


function onFrame(obj, ~)
% One invocation per acquired frame.
S = obj.UserData;

% -- Get one frame in native class
frame = getdata(obj, 1, 'native');

% -- Ensure single-channel
if ndims(frame) == 3
    frame = mean(frame, 3);  % fast luma
end

% -- Convert to uint16
f16   = to_uint16_gray(frame);          % robust, no clipping/scale surprises

% -- ROI means (masked sums)
means = roi_compute_means(f16, S.roi);  % single row vector, per-ROI means

% ---- Diagnostics: is the image changing?
if ~isfield(S,'debug_crc'), S.debug_crc = uint64(0); S.static_count = 0; end
crc = uint64(sum(uint64(f16(1:8:end, 1:8:end)), 'all'));  % light-weight checksum
if crc == S.debug_crc
    S.static_count = S.static_count + 1;
else
    S.static_count = 0;
    S.debug_crc = crc;
end

% -- Timing/FPS
t = toc(S.tic0);
S.framesSeen = S.framesSeen + 1;
S.frametimes(end+1) = t; %#ok<AGROW>
if numel(S.frametimes) > S.maxFT
    S.frametimes = S.frametimes(end-S.maxFT+1:end);
end
if (t - S.lastPrint) >= S.printEvery
    ft = S.frametimes;
    fps = NaN;
    if numel(ft) >= 2, fps = (numel(ft)-1) / max(ft(end)-ft(1), eps); end
    fprintf('[%7.3fs] FPS: %5.1f   frames=%d   dropped=%d\n', ...
        t, fps, S.framesSeen, S.framesDropped);
    S.lastPrint = t;
end

% -- Update preview frame
S.lastFrame     = f16;
S.lastFrameTime = t;

% -- Update ring buffer for traces
cap  = S.trace_capacity;
head = S.trace_head + 1;
if head > cap, head = 1; end
S.trace_head     = head;
S.trace_t(head)  = t;
S.trace_means(head,:) = means;

% -- Optional: append to in-memory chunk (hook for file writing)
S.pending_n = S.pending_n + 1;
S.pending_t(S.pending_n) = t;
S.pending_means(S.pending_n,:) = means;
if S.pending_n >= S.framesPerChunk
    % >>> PLACEHOLDER for writing S.pending_t/measures to disk
    S.pending_n = 0;
end

obj.UserData = S;   % write back
end


% ---------- helpers ----------

function d = filldefaults(d, defaults)
f = fieldnames(defaults);
for i=1:numel(f)
    k = f{i};
    if ~isfield(d,k) || isempty(d.(k)), d.(k) = defaults.(k); end
end
end

function deviceID = auto_pick_device(adaptor)
info = imaqhwinfo(adaptor);
if isempty(info.DeviceIDs)
    error('No devices found for adaptor "%s".', adaptor);
end
deviceID = info.DeviceIDs{1};
if iscell(deviceID), deviceID = deviceID{1}; end
if ischar(deviceID), deviceID = str2double(deviceID); end
end

function format = auto_pick_format(adaptor, deviceID)
ainfo = imaqhwinfo(adaptor, deviceID);
fmts = ainfo.SupportedFormats;
if isempty(fmts)
    error('Adaptor "%s" device %d has no reported formats.', adaptor, deviceID);
end
mono = contains(fmts, {'MONO16','Mono16','GRAY','Y800','Mono8'}, 'IgnoreCase', true);
idx = find(mono, 1); if isempty(idx), idx = 1; end
format = fmts{idx};
end

function roi = build_circle_indices(H, W, circles)
% circles: Nx3 [xc, yc, r] (1-based)
N = size(circles,1);
roi.idx = cell(N,1);
roi.npix = zeros(N,1,'uint32');
roi.circles = circles;
[xg, yg] = meshgrid(1:W, 1:H);
for k = 1:N
    xc = circles(k,1); yc = circles(k,2); r = circles(k,3);
    mask = (xg - xc).^2 + (yg - yc).^2 <= r.^2;
    idx = find(mask);
    roi.idx{k} = idx;
    roi.npix(k) = uint32(numel(idx));
end
end
