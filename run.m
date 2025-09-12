% --- Define your circular ROIs (centers & radii in pixels, 1-based)
roiCircles = [
    200 150 25   % ROI 1
    420 300 30   % ROI 2
];

% --- WINVIDEO (e.g., generic USB camera)
vid = roi_stream('winvideo', 2, 'I420_1280x720', roiCircles);  % auto-picks device & format

% --- or HAMAMATSU (DCAM adaptor)
% vid = roi_stream('hamamatsu', [], '', roiCircles);

% 3) Launch the GUI (updates every second, plots last 60 s)
h = roi_stream_gui(vid, struct('PlotWindowSec',60, 'UpdatePeriod',1.0));

%%
run_random_rois

%%
% Let it run, then stop:
stop_roi_stream(vid);
