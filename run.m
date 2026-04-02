%%
ensure_roi_stream_path(fileparts(mfilename('fullpath')));

% --- Define your circular ROIs (centers & radii in pixels, 1-based)
roiCircles = [
    200 150 25   % ROI 1
    420 300 30   % ROI 2
];

% --- Stream options
streamOpts = struct( ...
    'EnableLogging', true, ...   % set true to write HDF5 traces
    'PrintFPSPeriod', 1.0, ...
    'TraceBufferSec', 600, ...
    'ReturnColorSpace', 'grayscale');

% --- Camera setup (matched to Polina GUI path)
vid = videoinput("hamamatsu", 1, "MONO16_BIN2x2_1152x1152_Fast");
vid.ROIPosition = [0 160 576 238] * 2;

src = getselectedsource(vid);
try, src.OutputTriggerKindOpt3 = "exposure"; catch, end
try, src.OutputTriggerPolarityOpt3 = "positive"; catch, end
try, src.OutputTriggerKindOpt2 = "exposure"; catch, end
try, src.OutputTriggerPolarityOpt2 = "positive"; catch, end
try, src.ExposureTime = round(1/80, 4); catch, end

vid.TriggerRepeat = 0;
vid.FramesPerTrigger = Inf;
triggerconfig(vid, 'immediate');
vid.LoggingMode = 'memory';

% Attach ROI extraction/logging and start
info = roi_attach_to_video(vid, roiCircles, streamOpts); %#ok<NASGU>
start(vid);

% 3) Launch the GUI (updates every second, plots last 60 s)
h = roi_stream_gui(vid, struct( ...
    'PlotWindowSec', 10, ...
    'UpdatePeriod', 1.0));


%%
% Let it run, then stop:
trace_file_name = stop_roi_stream(vid);

%%
%h5_traces_viewer(trace_file_name)
