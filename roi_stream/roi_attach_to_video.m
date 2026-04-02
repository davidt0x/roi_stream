function info = roi_attach_to_video(vid, roiCircles, opts)
%ROI_ATTACH_TO_VIDEO Attach ROI extraction + HDF5 logging to a videoinput.
%
% info = roi_attach_to_video(vid, roiCircles, opts)
%   vid: existing configured videoinput object
%   roiCircles: Nx3 [xc yc r] in image coordinates
%   opts.H5Path: output HDF5 file path
%   opts.Meta: struct of extra root attributes
%   opts.EnableLogging: when false, skip HDF5 creation and run in preview mode

if nargin < 3
    opts = struct();
end

opts = filldefaults(opts, struct( ...
    'FramesPerChunk', 120, ...
    'PrintFPSPeriod', 1.0, ...
    'TraceBufferSec', 600, ...
    'ReturnColorSpace', 'grayscale', ...
    'EnableLogging', true, ...
    'H5Path', '', ...
    'Meta', struct()));

if nargin < 2 || isempty(roiCircles) || size(roiCircles, 2) ~= 3
    error('roiCircles must be Nx3 [xc yc r].');
end

try
    if ~isempty(opts.ReturnColorSpace)
        vid.ReturnedColorSpace = opts.ReturnColorSpace;
    end
catch
    try
        vid.ReturnedColorspace = opts.ReturnColorSpace;
    catch
    end
end

vr = vid.VideoResolution;
W = vr(1);
H = vr(2);
roi = roi_build_circle_indices(H, W, roiCircles);

S = struct();
try
    oldUserData = vid.UserData;
    if isstruct(oldUserData)
        S = oldUserData;
    end
catch
end

S.roi = roi;
S.tic0 = tic;
S.lastPrint = 0;
S.printEvery = opts.PrintFPSPeriod;
S.framesSeen = 0;
S.framesDropped = 0;
S.frametimes = [];
S.maxFT = max(2 * opts.FramesPerChunk, 300);

S.framesPerChunk = opts.FramesPerChunk;
S.pending_n = 0;
S.pending_t = zeros(opts.FramesPerChunk, 1, 'double');
S.pending_means = zeros(opts.FramesPerChunk, numel(roi.npix), 'single');

S.lastFrame = [];
S.lastFrameTime = 0;

cap = max(60 * opts.TraceBufferSec, 6000);
K = numel(roi.npix);
S.trace_capacity = cap;
S.trace_head = 0;
S.trace_t = nan(cap, 1);
S.trace_means = nan(cap, K, 'single');

S.h5w = [];
S.roi_trace_path = '';
S.loggingEnabled = logical(opts.EnableLogging);

if S.loggingEnabled
    if isempty(opts.H5Path)
        ts = string(datetime('now', 'TimeZone', 'local', 'Format', 'yyyyMMdd_HHmmss'));
        opts.H5Path = fullfile(pwd, "traces_" + ts + ".h5");
    end

    meta = collect_video_meta(vid, W, H);
    meta = merge_structs(meta, opts.Meta);
    if ~isfield(meta, 'start_iso8601') || isempty(meta.start_iso8601)
        meta.start_iso8601 = char(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSZ'));
    end

    S.h5w = H5TracesWriter(opts.H5Path, roi.circles, meta, 240);
    S.roi_trace_path = char(S.h5w.path);
end

vid.UserData = S;
vid.FramesAcquiredFcnCount = 1;
vid.FramesAcquiredFcn = @roi_on_frame;

info = struct('H5Path', S.roi_trace_path, 'NumROIs', K, 'Resolution', [W H], ...
    'LoggingEnabled', S.loggingEnabled);
end

function d = filldefaults(d, defaults)
fns = fieldnames(defaults);
for i = 1:numel(fns)
    name = fns{i};
    if ~isfield(d, name) || isempty(d.(name))
        d.(name) = defaults.(name);
    end
end
end

function out = merge_structs(base, extra)
out = base;
if ~isstruct(extra)
    return;
end

fns = fieldnames(extra);
for i = 1:numel(fns)
    out.(fns{i}) = extra.(fns{i});
end
end

function meta = collect_video_meta(vid, W, H)
meta = struct();
meta.resolution = int32([W H]);

try
    adaptor = vid.AdaptorName;
    if ~isempty(adaptor)
        meta.adaptor = string(adaptor);
    end
catch
end

try
    deviceID = vid.DeviceID;
    if ~isempty(deviceID)
        meta.device_id = int32(deviceID);
    end
catch
end

try
    fmt = vid.VideoFormat;
    if ~isempty(fmt)
        meta.format = string(fmt);
    end
catch
end
end
