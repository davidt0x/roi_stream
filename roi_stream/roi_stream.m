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


if ~isfield(opts,'H5Path') || isempty(opts.H5Path)
    ts = string(datetime('now','TimeZone','local','Format','yyyyMMdd_HHmmss'));
    opts.H5Path = fullfile(pwd, "traces_" + ts + ".h5");
end
opts.Meta = struct('adaptor', string(adaptor), ...
                   'device_id', int32(deviceID), ...
                   'format', string(format));
info = roi_attach_to_video(vid, roiCircles, opts);

% ---- Start streaming and return handle
start(vid);

W = info.Resolution(1);
H = info.Resolution(2);
fprintf('[roi_stream] Started %s (device %d, format %s), %dx%d px\n', ...
    adaptor, deviceID, format, W, H);
fprintf('[roi_stream] %d circular ROI(s). FPS every %.1fs. Call stop_roi_stream(vid) to stop.\n', ...
    info.NumROIs, opts.PrintFPSPeriod);
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
