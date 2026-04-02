classdef ExperimentalGUI_TTLtrig_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        STIMONLabel                     matlab.ui.control.Label
        PostStimPeriodsEditField        matlab.ui.control.NumericEditField
        PostStimPeriodsEditFieldLabel   matlab.ui.control.Label
        BaselinePeriodsEditField        matlab.ui.control.NumericEditField
        BaselinePeriodsEditFieldLabel   matlab.ui.control.Label
        NumberofPulsesEditField         matlab.ui.control.NumericEditField
        NumberofPulsesEditFieldLabel    matlab.ui.control.Label
        TimebwPulsessEditField          matlab.ui.control.NumericEditField
        TimebwPulsessEditFieldLabel     matlab.ui.control.Label
        PulseDurationmsEditField        matlab.ui.control.NumericEditField
        PulseDurationmsEditFieldLabel   matlab.ui.control.Label
        StartExperimentButton           matlab.ui.control.StateButton
        PreviewROIGUIButton             matlab.ui.control.Button
        LaserIntensitiesFileEditField   matlab.ui.control.EditField
        LaserIntensitiesFileEditFieldLabel  matlab.ui.control.Label
        CalMtxFileEditField             matlab.ui.control.EditField
        CalMtxFileEditFieldLabel        matlab.ui.control.Label
        TransCoordsFileEditField        matlab.ui.control.EditField
        TransCoordsFileEditFieldLabel   matlab.ui.control.Label
        CalibrationFilesLabel           matlab.ui.control.Label
        NALabel_2                       matlab.ui.control.Label
        TimeStartedLabel                matlab.ui.control.Label
        NALabel_3                       matlab.ui.control.Label
        StartingupLabel                 matlab.ui.control.Label
        CurrentrecordingdurationLabel   matlab.ui.control.Label
        StatusLabel                     matlab.ui.control.Label
        StimLogFilenameEditField        matlab.ui.control.EditField
        StimLogFilenameEditFieldLabel   matlab.ui.control.Label
        VideoFilenameEditField          matlab.ui.control.EditField
        VideoFilenameEditFieldLabel     matlab.ui.control.Label
        LoggingDirectoryEditField       matlab.ui.control.EditField
        LoggingDirectoryEditFieldLabel  matlab.ui.control.Label
        LoggingControlsLabel            matlab.ui.control.Label
        ROIStimOrderButtonGroup         matlab.ui.container.ButtonGroup
        EditField_2                     matlab.ui.control.NumericEditField
        msbwinburstEditField            matlab.ui.control.NumericEditField
        msbwinburstEditField_2Label     matlab.ui.control.Label
        inburstEditField                matlab.ui.control.NumericEditField
        inburstEditField_2Label         matlab.ui.control.Label
        BreakbwROIssEditField           matlab.ui.control.NumericEditField
        BreakbwROIssEditFieldLabel      matlab.ui.control.Label
        repeatedstimsateachROIButton    matlab.ui.control.RadioButton
        oneROIonlyButton                matlab.ui.control.RadioButton
        orderedButton                   matlab.ui.control.RadioButton
        randomButton                    matlab.ui.control.RadioButton
        LaserProtocolControlsLabel      matlab.ui.control.Label
    end

    
    properties (Access = private)
        v
        src
        dqIn
        dqOut
        outputs
        lsr
        posfullFilename
        pulse_log
        intensity_mat
        numROIs
        FrameRate
        bcam_log
        bcam_log_3
        bcam_log_4
        bcam_log_5
        bcam_log_6
        bcam_log_7
        hist
        bcamfullFilename
        scan_start
        roifullFilename
        previewVid
        previewFig
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            warning('off','all')
            addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'roi_stream'));

            % Set initial number of ROIs just for stim duration calculation, doesn't matter for actual experiment
            app.numROIs = 4;
            
            % Clear recording variables if they already exist
            if exist(app.v, 'var')
                delete(app.v)
            end
            if exist(app.dqIn, 'var')
                delete(app.dqIn)
            end
            if exist(app.dqIn, 'var')
                delete(app.dqOut)
            end

            % Get laser parameters
            app.lsr = lsrCtrlParams; % get class object with laser parameters

            % Set frame rate
            app.FrameRate = 80; % Hz

            est_dur = (app.BaselinePeriodsEditField.Value + (((app.PulseDurationmsEditField.Value/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
            app.NALabel_3.Enable = true;
            app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
            
            % Change label to idle
            app.StartingupLabel.Text = 'Idle';
            app.previewVid = [];
            app.previewFig = [];


        end

        function PreviewROIGUIButtonPushed(app, ~)
            if app.StartExperimentButton.Value
                errordlg('Stop the experiment before launching ROI preview.', 'Preview Unavailable');
                return;
            end
            if ~app.canLaunchPreview()
                return;
            end

            app.StartingupLabel.Text = 'Launching ROI preview...';
            drawnow

            try
                app.startROIPreview();
                app.StartingupLabel.Text = 'Idle';
            catch ME
                app.stopROIPreview();
                app.StartingupLabel.Text = 'Idle';
                errordlg(sprintf('ROI preview failed:\n%s', ME.message), 'Preview Error');
            end
        end

        % Selection changed function: ROIStimOrderButtonGroup
        function ROIStimOrderButtonGroupSelectionChanged(app, event)
            selectedButton = app.ROIStimOrderButtonGroup.SelectedObject;
            
            if selectedButton == app.oneROIonlyButton
                % Make select ROI field visible
                app.EditField_2.Enable = true;
                app.EditField_2.Editable = true;

                % Make break bw ROIs field invisible
                app.BreakbwROIssEditField.Enable = false;
                app.BreakbwROIssEditFieldLabel.Enable = false;
                app.BreakbwROIssEditField.Editable = false;

                % Make break bw ROIs field 0
                app.BreakbwROIssEditField.Value = 0;

                % Make recording duration reflect that only one ROI is
                % stimmed
                est_dur = (app.BaselinePeriodsEditField.Value + (((app.PulseDurationmsEditField.Value/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * 1) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);


            elseif selectedButton == app.repeatedstimsateachROIButton
                % Make break bw ROIs field visible
                app.BreakbwROIssEditField.Enable = true;
                app.BreakbwROIssEditFieldLabel.Enable = true;
                app.BreakbwROIssEditField.Editable = true;

                % Make # in burst field visible
                app.inburstEditField.Enable = true;
                app.inburstEditField_2Label.Enable = true;
                app.inburstEditField.Editable = true;

                % Make recording duration reflect that all ROIs are stimmed
                
                est_dur = (app.BaselinePeriodsEditField.Value + ((( ((app.PulseDurationmsEditField.Value+app.msbwinburstEditField.Value)*app.inburstEditField.Value/1000) + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                
            else
                % Make select ROI field invisible
                app.EditField_2.Enable = false;
                app.EditField_2.Editable = false;

                % Make break bw ROIs field invisible
                app.BreakbwROIssEditField.Enable = false;
                app.BreakbwROIssEditFieldLabel.Enable = false;
                app.BreakbwROIssEditField.Editable = false;

                % Make # in burst field invisible
                app.inburstEditField.Enable = false;
                app.inburstEditField_2Label.Enable = false;
                app.inburstEditField.Editable = false;

                % Make ms b/w pulses in burst field invisible
                app.msbwinburstEditField.Enable = false;
                app.msbwinburstEditField_2Label.Enable = false;
                app.msbwinburstEditField.Editable = false;

                % Make break bw ROIs field 0
                app.BreakbwROIssEditField.Value = 0;

                % Make recording duration reflect that all ROIs are
                % stimmed
                est_dur = (app.BaselinePeriodsEditField.Value + (((app.PulseDurationmsEditField.Value/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                

            end
        end

        % Value changed function: StartExperimentButton
        function StartExperimentButtonValueChanged(app, event)
            value = app.StartExperimentButton.Value;
            
            if value
                if ~isempty(app.previewVid)
                    try
                        if isvalid(app.previewVid)
                            app.StartExperimentButton.Value = false;
                            errordlg('Close the ROI preview before starting the experiment.', 'Preview Active');
                            return;
                        end
                    catch
                    end
                end
                pulse_times = [];
                runFailed = false;
                errMsg = '';
                try

                app.StartExperimentButton.Enable = "off";

                % Get everything ready according to set protocol values
                app.StartingupLabel.Text = 'Preparing for recording...';

                app.v = videoinput("hamamatsu", 1, "MONO16_BIN2x2_1152x1152_Fast");
                app.v.ROIPosition = [0 160 576 238]*2;
                app.src = getselectedsource(app.v);
                app.src.OutputTriggerKindOpt3 = "exposure";
                app.src.OutputTriggerPolarityOpt3 = "positive";
                app.src.OutputTriggerKindOpt2 = "exposure";
                app.src.OutputTriggerPolarityOpt2 = "positive";
                app.src.ExposureTime = round(1/app.FrameRate, 4);

                % Set up laser
                app.dqOut = daq("ni");
                app.dqIn = daq("ni");
                
                addinput(app.dqIn, "Dev1", "ai0", "Voltage"); % input channel receiving TTL pulses for stim
                addinput(app.dqIn, "Dev1", "ai29", "Voltage"); % input channel receiving photometry cam frame time stamps
                addinput(app.dqIn, "Dev1", "ai2", "Voltage"); % input channel receiving behavior cam frame timestamps
                addinput(app.dqIn, "Dev1", "ai4", "Voltage"); % input channel receiving analog output signal copy to get laser timestamps
                
                addoutput(app.dqOut, "Dev1", "ao0", "Voltage"); % output channel 1, corresponding to laser analog input
                addoutput(app.dqOut, "Dev1", "port0/line7", "Digital"); % digital output channel USER1, corresponding to laser digital input
                addoutput(app.dqOut, "Dev1", "ao2", "Voltage"); % output channel 3, corresponding to galvo X input
                addoutput(app.dqOut, "Dev1", "ao3", "Voltage"); % output channel 4, corresponding to galvo Y input

                app.outputs = [0 0 0 0]; % Voltages to set all NI DAQ outputs to. Maximum allowed voltage is 10 V
                write(app.dqOut, app.outputs)

                app.lsr = lsrCtrlParams; % get class object with laser parameters


                % Get video and laser logging ready
                fullFilename = fullfile(app.LoggingDirectoryEditField.Value, app.VideoFilenameEditField.Value+".avi");
               
                logfile = VideoWriter(fullFilename, "Grayscale AVI");
                app.v.LoggingMode = "disk";
                app.v.DiskLogger = logfile;

                app.posfullFilename = fullfile(app.LoggingDirectoryEditField.Value, app.StimLogFilenameEditField.Value+".mat");
                app.bcamfullFilename = fullfile(app.LoggingDirectoryEditField.Value, app.StimLogFilenameEditField.Value+"_bcam.mat");

                app.bcam_log_3 = [];
                app.bcam_log_4 = [];
                app.bcam_log_5 = [];
                app.bcam_log_6 = [];
                app.bcam_log_7 = [];

                app.hist = ones(1, app.dqIn.Rate); % to keep a running 1s time window of the history for stim purposes
                

                % Prepare laser pulse params
                app.lsr.numpulses = app.NumberofPulsesEditField.Value;        % number of pulses to do
                app.lsr.dutyCycle = app.PulseDurationmsEditField.Value/1000;      % how long is laser on during each pulse, sec
                app.lsr.pulseIntervalDur = app.TimebwPulsessEditField.Value;        % time between pulses, sec
                

                % Set NI DAQ scan rate to be 1/0.5ms always
                app.dqIn.Rate = 2000;
                app.dqOut.Rate = 2000;

                % Load calibration scipt and translated coordinate files
                load(app.CalMtxFileEditField.Value);
                load(app.TransCoordsFileEditField.Value, 'translated_coords');

                stimStem = string(app.StimLogFilenameEditField.Value);
                videoStem = string(app.VideoFilenameEditField.Value);
                roiCircles = translated_coords(:, 1:3);
                roiMeta = struct( ...
                    'stim_log_path', string(fullfile(app.LoggingDirectoryEditField.Value, stimStem + ".mat")), ...
                    'video_log_path', string(fullfile(app.LoggingDirectoryEditField.Value, videoStem + ".avi")), ...
                    'trans_coords_file', string(app.TransCoordsFileEditField.Value), ...
                    'calibration_file', string(app.CalMtxFileEditField.Value), ...
                    'laser_intensities_file', string(app.LaserIntensitiesFileEditField.Value), ...
                    'requested_frame_rate_hz', double(app.FrameRate), ...
                    'baseline_sec', double(app.BaselinePeriodsEditField.Value), ...
                    'post_stim_sec', double(app.PostStimPeriodsEditField.Value), ...
                    'pulse_duration_ms', double(app.PulseDurationmsEditField.Value), ...
                    'time_between_pulses_sec', double(app.TimebwPulsessEditField.Value), ...
                    'num_pulses', double(app.NumberofPulsesEditField.Value));

                app.roifullFilename = fullfile(app.LoggingDirectoryEditField.Value, stimStem + "_roi.h5");
                roi_attach_to_video(app.v, roiCircles, struct( ...
                    'H5Path', app.roifullFilename, ...
                    'Meta', roiMeta, ...
                    'PrintFPSPeriod', 2.0));
                

                % Load ROI laser intensity values
                load(app.LaserIntensitiesFileEditField.Value);
                app.intensity_mat = intensity_mat;

                % Find function to get galvo voltages from desired pixel location
                % This assumes a linear function, can change if non-linear
                px = polyfit(all_points(:,3), all_points(:,1),1);
                slopex = px(1,1);
                intx = px(1,2);

                py = polyfit(all_points(:,4), all_points(:,2),1);
                slopey = py(1,1);
                inty = py(1,2);

                % Save to lsr
                app.lsr.slopex = slopex;
                app.lsr.slopey = slopey;
                app.lsr.intx = intx;
                app.lsr.inty = inty;

                % Upload coords to lsr
                app.lsr.grid = [[1:size(translated_coords, 1)].' translated_coords]; % added indices in first column to keep track of permutations later

                % Convert all coordinates to galvo voltages
                galvo_coords = [];
                for i = 1:size(app.lsr.grid,1)
                    % Get desired pixel location
                    pix_y = app.lsr.grid(i, 2);
                    pix_x = app.lsr.grid(i, 3);

                    % Convert to voltage
                    gVx = (pix_y - app.lsr.intx)/app.lsr.slopex;
                    gVy = (pix_x - app.lsr.inty)/app.lsr.slopey;

                    % Save in matrix
                    galvo_coords = [galvo_coords; gVx gVy];
                end

                % Upload galvo voltages to lsr
                app.lsr.galvo_grid = [[1:size(galvo_coords, 1)].' galvo_coords]; % added indices in first column to keep track of permutations later


                % Make stim matrix to run at each TTL pulse
                app.numROIs = size(app.lsr.grid,1); %number of fibers
                gvs = app.lsr.galvo_grid; %array of galvo voltages for each fiber
                app.pulse_log = {}; % to log laser stims
                app.bcam_log = {}; % to log behavior cam frame time stamps

                if app.repeatedstimsateachROIButton.Value == true %if doing burst stim protocol

                    % Randomly permute ROI order
                    gvs = app.lsr.galvo_grid(randperm(size(app.lsr.galvo_grid,1)), :);

                    % Get analog laser intensities in same permuted order
                    ints = app.intensity_mat(gvs(:,1),:); % permute intensities in the same way as galvo voltages

                    for r = 1:app.numROIs
                        % Log repeated ROI in pulse log as a cycle,
                        % first two cells will log video/laser start times
                        
                        app.pulse_log{r+2} = repelem(app.lsr.grid(gvs(:,1)==r,:), app.NumberofPulsesEditField.Value*app.inburstEditField.Value, 1); % repeat single ROI by the number of pulses

                        if app.inburstEditField == 1
                            stim_op = repelem([ints(r,2), 1, gvs(r,2), gvs(r,3)], round(app.dqOut.Rate*app.lsr.dutyCycle), 1); %rows in matrix where laser is on (stim)
                            wait_op = repelem([0,0,gvs(r,2), gvs(r,3)], round(app.dqOut.Rate*app.lsr.pulseIntervalDur), 1); % hold laser off for time specified between stims
                        else
                            if app.msbwinburstEditField.Value ~= 0
                                stim_op1 = repelem([ints(r,2), 1, gvs(r,2), gvs(r,3)], round(app.dqOut.Rate*app.lsr.dutyCycle), 1); % first rows in matrix where laser is on (stim)
                                stim_op2 = repelem([0,0,gvs(r,2), gvs(r,3)], round(app.dqOut.Rate*(app.msbwinburstEditField.Value/1000)), 1);
                                stim_op = [stim_op1; stim_op2];
                                for i=1:(app.inburstEditField.Value-1)
                                    stim_op = [stim_op; stim_op1; stim_op2];
                                end
                            else
                                error("Error: ms b/w in pulses field should not be 0 here.")
                            end
                            wait_op = repelem([0,0,gvs(r,2), gvs(r,3)], round(app.dqOut.Rate*app.lsr.pulseIntervalDur)- size(stim_op,1), 1); % hold laser off for time specified between stims
                        end
                        for pul = 1:app.NumberofPulsesEditField.Value
                            if pul == app.NumberofPulsesEditField.Value && r ~= app.numROIs % if on the last pulse and not the last ROI
                                if app.BreakbwROIssEditField.Value ~= 0 % if break between ROIs specified, include it. otherwise, leave regular pulse interval
                                    wait_op = repelem([0,0,gvs(r+1,2),gvs(r+1,3)], app.dqOut.Rate*app.BreakbwROIssEditField.Value - size(stim_op,1), 1); % hold laser off, but with galvo set to next location, for the break bw ROI pulses specified
                                else % still change last wait_op to have next region
                                    wait_op = repelem([0,0,gvs(r+1,2), gvs(r+1,3)], round(app.dqOut.Rate*app.lsr.pulseIntervalDur)- size(stim_op,1), 1); % hold laser off for time specified between stims
                                end
                            end

                            app.outputs = [app.outputs; cat(1, stim_op, wait_op)]; %app.outputs will become full protocol matrix at the end


                        end
                        



                    end


                else % if not doing burst stim protocol


                    for n_cyc = 1:app.lsr.numpulses
                        if app.oneROIonlyButton.Value == true % if you only want to stimulate one region

                            r = cast(app.EditField_2.Value, "double");
                            

                            % Get laser intensities
                            ints = app.intensity_mat;

                            % Log ROI order for reference later
                            app.pulse_log{n_cyc+2} = app.lsr.grid(r,:); % log region coords

                            stim_op = repelem([ints(r,2), 1, gvs(r,2), gvs(r,3)], round(app.dqOut.Rate*app.lsr.dutyCycle), 1);
                            wait_op = repelem([0,0,0,0], round(app.dqOut.Rate*app.lsr.pulseIntervalDur)-size(stim_op,1), 1); % hold laser off for time specified
                            app.outputs = [app.outputs; cat(1,stim_op, wait_op)];


                        else
                            % Randomly permute ROI order for stim if applicable
                            if app.randomButton.Value == true
                                gvs = app.lsr.galvo_grid(randperm(size(app.lsr.galvo_grid,1)), :);
                            end

                            % Log ROI order for reference later
                            app.pulse_log{n_cyc+2} = app.lsr.grid(gvs(:,1),:); % permute pixel coordinates in the same way as galvo voltages, log

                            % Get laser intensities
                            ints = app.intensity_mat(gvs(:,1),:); % permute intensities in the same way as galvo voltages

                            % Make laser outputs for this cycle based on ROI order
                            for r = 1:app.numROIs
                                if r==1 && n_cyc ~= 1
                                    sz = size(app.outputs,1);
                                    app.outputs((sz - app.dqOut.Rate*app.lsr.pulseIntervalDur+1 +round(app.dqOut.Rate*app.lsr.dutyCycle)):end, :)= repelem([0,0,gvs(r,2),gvs(r,3)], sz - (sz - app.dqOut.Rate*app.lsr.pulseIntervalDur+1 +round(app.dqOut.Rate*app.lsr.dutyCycle))+1, 1); % if new cycle (and not first cycle), make sure laser moves to upcoming location in previous wait period
                                end

                                stim_op = repelem([ints(r,2), 1, gvs(r,2), gvs(r,3)], round(app.dqOut.Rate*app.lsr.dutyCycle), 1);

                                if r == app.numROIs
                                    wait_op = repelem([0,0,gvs(r,2),gvs(r,2)], round(app.dqOut.Rate*app.lsr.pulseIntervalDur)-size(stim_op,1), 1); % hold laser off for time specified
                                else
                                    wait_op = repelem([0,0,gvs(r+1,2),gvs(r+1,3)], round(app.dqOut.Rate*app.lsr.pulseIntervalDur)-size(stim_op,1), 1); % hold laser off, but with galvo set to next location, for time specified
                                end


                                app.outputs = [app.outputs; cat(1,stim_op,wait_op)];
                            end

                        end
                    end
                end

                app.outputs(1,:)=[]; % remove initial first row

                % Add baseline period onto stim matrix
                bl_op = repelem([0,0,0,0], app.dqOut.Rate*app.BaselinePeriodsEditField.Value, 1);
                app.outputs = cat(1, bl_op, app.outputs);

                % Add post stim period onto stim matrix
                ps_op = repelem([0,0,0,0], app.dqOut.Rate*app.PostStimPeriodsEditField.Value, 1);
                app.outputs = cat(1, app.outputs, ps_op); %app.outputs is now the stim protocol matrix that gets fed into the ni daq


                % Start recording
                app.v.FramesPerTrigger = Inf;

                % Set galvo to first ROI to prep
                write(app.dqOut, [0,0,app.outputs(1,3),app.outputs(1,4)]);

                % Start recording all voltage inputs
                start(app.dqIn, "Continuous");

                % Start video
                start(app.v);
                app.lsr.time_start_vid = datetime("now", 'Format', 'HH:mm:ss.SSSSSSSSS');
                app.StartingupLabel.Text = 'Recording...';
                app.NALabel_2.Enable = true;
                app.NALabel_2.Text = sprintf("%s", app.lsr.time_start_vid);

                app.StartExperimentButton.Text = 'Stop Experiment';
                app.StartExperimentButton.Enable = "on";

                isRunning = 1;
                firstStim = 1;
                noStimCheck = 1;
                while isRunning
                    pause(0.2)
                    [input_logs, timestamps, trigtime] = read(app.dqIn, 'all', "OutputFormat", "Matrix");

                    if firstStim
                        app.scan_start = datetime(trigtime,'ConvertFrom','datenum','Format','HH:mm:ss.SSSSSSSSS');
                    end
                    firstStim = 0;

                    % Get max last 200 scans to check over
                    if length(input_logs(:, 1)) > 200
                        markrs = input_logs((end-199):end,1) > 0.5;
                    else
                        markrs = input_logs(:, 1) > 0.5;

                    end

                    % Save other data continuously
                    app.bcam_log_3 = [app.bcam_log_3; timestamps];
                    app.bcam_log_4 = [app.bcam_log_4; input_logs(:, 1)];
                    app.bcam_log_5 = [app.bcam_log_5; input_logs(:, 2)];
                    app.bcam_log_6 = [app.bcam_log_6; input_logs(:, 3)];
                    app.bcam_log_7 = [app.bcam_log_7; input_logs(:, 4)];


                    % Update running stim input history window
                    app.hist = [app.hist((length(markrs)+1):end) markrs'];

                    % Check for 1 second of asocial first
                    if ~noStimCheck
                        if sum(app.hist) <= (app.dqIn.Rate*0.01) %if last second are mostly 0s, make no stim check true
                            noStimCheck = 1;
                        end
                    else
                        if any(markrs==1)
                            % Run stimulation
                            app.STIMONLabel.Visible = "on";
                            write(app.dqOut, app.outputs);
                            app.STIMONLabel.Visible = "off";

                            % Reset history to be all ones
                            app.hist = ones(1, app.dqIn.Rate);

                            % Reset no stim check back to false
                            noStimCheck= 0;
                        end
                    end

                    if ~app.StartExperimentButton.Value
                        isRunning = 0;
                    end
                end


                

                % Stop recording
                app.StartingupLabel.Text = 'Saving video...';
                app.StartExperimentButton.Enable = "off";

                stop(app.v);

                % Stop recording daq inputs
                [input_logs, timestamps, ~] = read(app.dqIn, 'all', "OutputFormat", "Matrix");
               

                % Save camera frame time stamp log
                app.StartingupLabel.Text = 'Saving behavior cam log...';
                drawnow
                
                
                app.bcam_log{3} = [app.bcam_log_3; timestamps];
                app.bcam_log{4} = [app.bcam_log_4; input_logs(:, 1)];
                app.bcam_log{5} = [app.bcam_log_5; input_logs(:, 2)];
                app.bcam_log{6} = [app.bcam_log_6; input_logs(:, 3)];
                app.bcam_log{7} = [app.bcam_log_7; input_logs(:, 4)];


                app.bcam_log{1} = app.lsr.time_start_vid;
                app.bcam_log{2} = app.scan_start;
                bcl = app.bcam_log;
                save(app.bcamfullFilename, "bcl");


                % Save laser stim log
                app.StartingupLabel.Text = 'Saving stim log...';
                drawnow

                
                pulse_times = timestamps(app.bcam_log{7} > (min(app.intensity_mat(:, 2))*0.7), :);
                pulse_times = pulse_times(1:(app.lsr.dutyCycle*app.dqOut.Rate):end);
                save("pulse_times.mat", 'pulse_times');
                if app.repeatedstimsateachROIButton.Value == true
                    for n=1:app.numROIs
                        app.pulse_log{n+2}(:, 5) = pulse_times((n-1)*app.lsr.numpulses*app.inburstEditField.Value+1:n*app.lsr.numpulses*app.inburstEditField.Value);
                    end
                else
                    if app.oneROIonlyButton.Value == true
                        for n=1:app.lsr.numpulses
                            app.pulse_log{n+2}(:, 5) = pulse_times(n);
                        end
                    else
                        for n=1:app.lsr.numpulses
                            app.pulse_log{n+2}(:, 5) = pulse_times((n-1)*app.numROIs+1:n*app.numROIs);
                        end
                    end
                end

                app.pulse_log{1} = app.lsr.time_start_vid;
                app.pulse_log{2} = app.scan_start;
                pl = app.pulse_log;
                save(app.posfullFilename, "pl");

                app.safeFinalizeROITrace(pulse_times);

                
                app.safeStopAndDeleteObjects();

                app.NALabel_2.Enable = "off";
                app.NALabel_2.Text = "N/A";


                % Change label to idle
                app.StartingupLabel.Text = 'Idle';


                % Change Button Label
                app.StartExperimentButton.Value = false;
                app.StartExperimentButton.Text = 'Start Experiment';
                app.StartExperimentButton.Enable = "on";

                

                % Check experiment button value
                if app.StartExperimentButton.Value
                    app.StartExperimentButton.Value = 0;
                end

                catch ME
                    runFailed = true;
                    errMsg = ME.message;
                end

                if runFailed
                    app.safeFinalizeROITrace(pulse_times, struct( ...
                        'run_failed', true, ...
                        'error_message', char(errMsg)));
                    app.safeStopAndDeleteObjects();
                    app.STIMONLabel.Visible = "off";
                    app.NALabel_2.Enable = "off";
                    app.NALabel_2.Text = "N/A";
                    app.StartingupLabel.Text = 'Idle';
                    app.StartExperimentButton.Value = false;
                    app.StartExperimentButton.Text = 'Start Experiment';
                    app.StartExperimentButton.Enable = "on";
                    errordlg(sprintf('Experiment aborted:\n%s', errMsg), 'Experiment Error');
                end

            end

            
        end

        function safeFinalizeROITrace(app, pulse_times, extraSummary)
            if nargin < 2
                pulse_times = [];
            end
            if nargin < 3 || isempty(extraSummary)
                extraSummary = struct();
            end

            if isempty(app.v)
                return;
            end
            try
                if isvalid(app.v)
                    try
                        stop(app.v);
                    catch
                    end

                    roiSummary = extraSummary;
                    if ~isempty(app.lsr) && isprop(app.lsr, 'time_start_vid') && ~isempty(app.lsr.time_start_vid)
                        roiSummary.video_start_time = char(app.lsr.time_start_vid);
                    end
                    if ~isempty(app.scan_start)
                        roiSummary.scan_start_time = char(app.scan_start);
                    end
                    if ~isempty(app.posfullFilename)
                        roiSummary.stim_log_path = char(app.posfullFilename);
                    end
                    if ~isempty(app.bcamfullFilename)
                        roiSummary.bcam_log_path = char(app.bcamfullFilename);
                    end

                    roi_finalize_from_video(app.v, roiSummary, pulse_times);
                end
            catch
            end
        end

        function safeStopAndDeleteObjects(app)
            if ~isempty(app.dqIn)
                try
                    stop(app.dqIn);
                catch
                end
            end
            if ~isempty(app.dqOut)
                try
                    stop(app.dqOut);
                catch
                end
            end

            if ~isempty(app.v)
                try
                    if isvalid(app.v)
                        delete(app.v);
                    end
                catch
                end
                app.v = [];
            end
            if ~isempty(app.dqIn)
                try
                    delete(app.dqIn);
                catch
                end
                app.dqIn = [];
            end
            if ~isempty(app.dqOut)
                try
                    delete(app.dqOut);
                catch
                end
                app.dqOut = [];
            end
        end

        function tf = canLaunchPreview(app)
            tf = false;
            if ~isfile(app.TransCoordsFileEditField.Value)
                errordlg('Translated coordinates file is missing or invalid.', 'Preview Unavailable');
                return;
            end

            if ~isempty(app.previewVid)
                try
                    if isvalid(app.previewVid)
                        errordlg('ROI preview is already running.', 'Preview Already Running');
                        return;
                    end
                catch
                end
            end

            tf = true;
        end

        function startROIPreview(app)
            data = load(app.TransCoordsFileEditField.Value, 'translated_coords');
            if ~isfield(data, 'translated_coords') || size(data.translated_coords, 2) < 3
                error('Translated coordinates file must contain translated_coords(:,1:3).');
            end

            roiCircles = data.translated_coords(:, 1:3);
            app.previewVid = videoinput("hamamatsu", 1, "MONO16_BIN2x2_1152x1152_Fast");
            app.previewVid.ROIPosition = [0 160 576 238] * 2;

            srcPreview = getselectedsource(app.previewVid);
            srcPreview.OutputTriggerKindOpt3 = "exposure";
            srcPreview.OutputTriggerPolarityOpt3 = "positive";
            srcPreview.ExposureTime = round(1 / app.FrameRate, 4);

            app.previewVid.TriggerRepeat = 0;
            app.previewVid.FramesPerTrigger = Inf;
            triggerconfig(app.previewVid, 'immediate');
            app.previewVid.LoggingMode = 'memory';

            roi_attach_to_video(app.previewVid, roiCircles, struct( ...
                'EnableLogging', false, ...
                'PrintFPSPeriod', 2.0));

            start(app.previewVid);
            app.previewFig = roi_stream_gui(app.previewVid, struct('PlotWindowSec', 30, ...
                'UpdatePeriod', 0.5, 'ImagePeriod', 0.25));
            set(app.previewFig, 'CloseRequestFcn', @(src, evt)app.onPreviewFigureClose(src, evt));
        end

        function onPreviewFigureClose(app, src, ~)
            if ~isempty(app.previewFig) && isequal(src, app.previewFig)
                app.previewFig = [];
            end
            if nargin >= 2 && ishghandle(src)
                try
                    set(src, 'CloseRequestFcn', '');
                    delete(src);
                catch
                end
            end
            app.stopROIPreview();
        end

        function stopROIPreview(app)
            if ~isempty(app.previewFig)
                try
                    if ishghandle(app.previewFig)
                        delete(app.previewFig);
                    end
                catch
                end
                app.previewFig = [];
            end

            if ~isempty(app.previewVid)
                try
                    if isvalid(app.previewVid)
                        try
                            stop(app.previewVid);
                        catch
                        end
                        delete(app.previewVid);
                    end
                catch
                end
                app.previewVid = [];
            end
        end

        % Value changed function: PulseDurationmsEditField
        function PulseDurationmsEditFieldValueChanged2(app, event)
            value = app.PulseDurationmsEditField.Value;

            if isempty(value)
                app.NALabel_3.Enable = false;
                app.NALabel_3.Text = 'N/A';
            elseif ~isempty(app.TimebwPulsessEditField.Value) && ~isempty(app.BaselinePeriodsEditField.Value) && ~isempty(app.NumberofPulsesEditField.Value) && ~isempty(app.BreakbwROIssEditField.Value) && ~isempty(app.PostStimPeriodsEditField.Value)
                est_dur = (app.BaselinePeriodsEditField.Value + (((value/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                
            end
        end

        % Value changed function: TimebwPulsessEditField
        function TimebwPulsessEditFieldValueChanged2(app, event)
            value = app.TimebwPulsessEditField.Value;

            if isempty(value)
                app.NALabel_3.Enable = false;
                app.NALabel_3.Text = 'N/A';
            elseif ~isempty(app.PulseDurationmsEditField.Value) && ~isempty(app.BaselinePeriodsEditField.Value) && ~isempty(app.NumberofPulsesEditField.Value) && ~isempty(app.BreakbwROIssEditField.Value) && ~isempty(app.PostStimPeriodsEditField.Value)
                est_dur = (app.BaselinePeriodsEditField.Value + (((app.PulseDurationmsEditField.Value/1000 + value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                
            end
        end

        % Value changed function: NumberofPulsesEditField
        function NumberofPulsesEditFieldValueChanged2(app, event)
            value = app.NumberofPulsesEditField.Value;

            if isempty(value)
                app.NALabel_3.Enable = false;
                app.NALabel_3.Text = 'N/A';
            elseif ~isempty(app.TimebwPulsessEditField.Value) && ~isempty(app.BaselinePeriodsEditField.Value) && ~isempty(app.PulseDurationmsEditField.Value) && ~isempty(app.BreakbwROIssEditField.Value) && ~isempty(app.PostStimPeriodsEditField.Value)
                est_dur = (app.BaselinePeriodsEditField.Value + (((app.PulseDurationmsEditField.Value/1000 + app.TimebwPulsessEditField.Value) * value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                
            end
        end

        % Value changed function: BaselinePeriodsEditField
        function BaselinePeriodsEditFieldValueChanged2(app, event)
            value = app.BaselinePeriodsEditField.Value;

            if isempty(value)
                app.NALabel_3.Enable = false;
                app.NALabel_3.Text = 'N/A';
            elseif ~isempty(app.TimebwPulsessEditField.Value) && ~isempty(app.PulseDurationmsEditField.Value) && ~isempty(app.NumberofPulsesEditField.Value) && ~isempty(app.BreakbwROIssEditField) && ~isempty(app.PostStimPeriodsEditField)
                est_dur = (value + (((app.PulseDurationmsEditField.Value/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                
            end
        end

        % Value changed function: TransCoordsFileEditField
        function TransCoordsFileEditFieldValueChanged(app, event)
            
            if ~isfile(app.TransCoordsFileEditField.Value)
                app.TransCoordsFileEditField.Value = "file does not exist!";
            end
        end

        % Value changed function: CalMtxFileEditField
        function CalMtxFileEditFieldValueChanged(app, event)
            
            if ~isfile(app.CalMtxFileEditField.Value)
                app.CalMtxFileEditField.Value = "file does not exist!";
            end
            
        end

        % Value changed function: LaserIntensitiesFileEditField
        function LaserIntensitiesFileEditFieldValueChanged(app, event)
            
            if ~isfile(app.LaserIntensitiesFileEditField.Value)
                app.LaserIntensitiesFileEditField.Value = "file does not exist!";
            end

        end

        % Value changed function: LoggingDirectoryEditField
        function LoggingDirectoryEditFieldValueChanged(app, event)
            
            if ~isfolder(app.LoggingDirectoryEditField.Value)
                app.LoggingDirectoryEditField.Value = "directory does not exist!";
            end
            
        end

        % Value changed function: BreakbwROIssEditField
        function BreakbwROIssEditFieldValueChanged(app, event)
            value = app.BreakbwROIssEditField.Value;

            if isempty(value)
                app.NALabel_3.Enable = false;
                app.NALabel_3.Text = 'N/A';
            elseif ~isempty(app.TimebwPulsessEditField.Value) && ~isempty(app.PulseDurationmsEditField.Value) && ~isempty(app.NumberofPulsesEditField.Value) && ~isempty(app.BaselinePeriodsEditField.Value) && ~isempty(app.PostStimPeriodsEditField.Value)
                est_dur = (app.BaselinePeriodsEditField.Value + (((app.PulseDurationmsEditField.Value/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                
            end
        end

        % Value changed function: PostStimPeriodsEditField
        function PostStimPeriodsEditFieldValueChanged(app, event)
            value = app.PostStimPeriodsEditField.Value;
            
            if isempty(value)
                app.NALabel_3.Enable = false;
                app.NALabel_3.Text = 'N/A';
            elseif ~isempty(app.TimebwPulsessEditField.Value) && ~isempty(app.PulseDurationmsEditField.Value) && ~isempty(app.NumberofPulsesEditField.Value) && ~isempty(app.BaselinePeriodsEditField.Value) && ~isempty(app.BreakbwROIssEditField.Value)
                est_dur = (app.BaselinePeriodsEditField.Value + (((app.PulseDurationmsEditField.Value/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + value)/60; %minutes
                
                    app.NALabel_3.Enable = true;
                    app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);

            end

        end

        % Value changed function: inburstEditField
        function inburstEditFieldValueChanged(app, event)
            value = app.inburstEditField.Value;
            
            if isempty(value)
                app.inburstEditField.Value = 1; % prevent this field from being empty
            elseif ~isempty(app.TimebwPulsessEditField.Value) && ~isempty(app.PulseDurationmsEditField.Value) && ~isempty(app.NumberofPulsesEditField.Value) && ~isempty(app.BaselinePeriodsEditField.Value) && ~isempty(app.PostStimPeriodsEditField.Value) && ~isempty(app.BreakbwROIssEditField.Value)
                est_dur = (app.BaselinePeriodsEditField.Value + ((( ((app.PulseDurationmsEditField.Value + app.msbwinburstEditField.Value)*value)/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes
                
                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);

            end

            % Make ms b/w pulses in burst field visible if value not equal to 1
            if value >1
                app.msbwinburstEditField.Enable = true;
                app.msbwinburstEditField_2Label.Enable = true;
                app.msbwinburstEditField.Editable = true;
                % Also change this field to different value so it's not 0
                % when value >1
                if app.msbwinburstEditField.Value ==0
                    app.msbwinburstEditField.Value = 1;
                end
            else
                app.msbwinburstEditField.Enable = false;
                app.msbwinburstEditField_2Label.Enable = false;
                app.msbwinburstEditField.Editable = false;
                % Also change this field back to default value
                app.msbwinburstEditField.Value = 0;
            end
        end

        % Value changed function: msbwinburstEditField
        function msbwinburstEditFieldValueChanged(app, event)
            value = app.msbwinburstEditField.Value;
            
            if isempty(value)
                app.msbwinburstEditField.Value = 0; % prevent this field from being empty
            end

            % if more than one pulse in burst, this value can't be zero
            if (app.inburstEditField.Value > 1) && (value ==0)
                app.msbwinburstEditField.Value = 1;
            end

            % Change predicted recording duration
            if ~isempty(value) && ~isempty(app.TimebwPulsessEditField.Value) && ~isempty(app.PulseDurationmsEditField.Value) && ~isempty(app.BreakbwROIssEditField.Value)
                est_dur = (app.BaselinePeriodsEditField.Value + ((( ((app.PulseDurationmsEditField.Value + value)*app.inburstEditField.Value)/1000 + app.TimebwPulsessEditField.Value) * app.NumberofPulsesEditField.Value + app.BreakbwROIssEditField.Value) * app.numROIs) - app.BreakbwROIssEditField.Value + app.PostStimPeriodsEditField.Value)/60; %minutes

                app.NALabel_3.Enable = true;
                app.NALabel_3.Text = sprintf("%.0f minutes %.02f seconds", floor(est_dur), (est_dur - floor(est_dur))*60);
                
            end

            

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 653 441];
            app.UIFigure.Name = 'MATLAB App';

            % Create LaserProtocolControlsLabel
            app.LaserProtocolControlsLabel = uilabel(app.UIFigure);
            app.LaserProtocolControlsLabel.FontSize = 14;
            app.LaserProtocolControlsLabel.FontWeight = 'bold';
            app.LaserProtocolControlsLabel.Position = [21 407 168 22];
            app.LaserProtocolControlsLabel.Text = 'Laser Protocol Controls:';

            % Create ROIStimOrderButtonGroup
            app.ROIStimOrderButtonGroup = uibuttongroup(app.UIFigure);
            app.ROIStimOrderButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ROIStimOrderButtonGroupSelectionChanged, true);
            app.ROIStimOrderButtonGroup.Title = 'ROI Stim. Order';
            app.ROIStimOrderButtonGroup.Position = [12 86 230 165];

            % Create randomButton
            app.randomButton = uiradiobutton(app.ROIStimOrderButtonGroup);
            app.randomButton.Text = 'random';
            app.randomButton.Position = [11 119 64 22];
            app.randomButton.Value = true;

            % Create orderedButton
            app.orderedButton = uiradiobutton(app.ROIStimOrderButtonGroup);
            app.orderedButton.Text = 'ordered';
            app.orderedButton.Position = [11 97 64 22];

            % Create oneROIonlyButton
            app.oneROIonlyButton = uiradiobutton(app.ROIStimOrderButtonGroup);
            app.oneROIonlyButton.Text = 'one ROI only';
            app.oneROIonlyButton.Position = [11 74 92 22];

            % Create repeatedstimsateachROIButton
            app.repeatedstimsateachROIButton = uiradiobutton(app.ROIStimOrderButtonGroup);
            app.repeatedstimsateachROIButton.Text = 'repeated stims at each ROI';
            app.repeatedstimsateachROIButton.Position = [12 50 168 22];

            % Create BreakbwROIssEditFieldLabel
            app.BreakbwROIssEditFieldLabel = uilabel(app.ROIStimOrderButtonGroup);
            app.BreakbwROIssEditFieldLabel.HorizontalAlignment = 'right';
            app.BreakbwROIssEditFieldLabel.Enable = 'off';
            app.BreakbwROIssEditFieldLabel.Position = [25 29 108 22];
            app.BreakbwROIssEditFieldLabel.Text = 'Break b/w ROIs (s):';

            % Create BreakbwROIssEditField
            app.BreakbwROIssEditField = uieditfield(app.ROIStimOrderButtonGroup, 'numeric');
            app.BreakbwROIssEditField.Limits = [0 Inf];
            app.BreakbwROIssEditField.ValueChangedFcn = createCallbackFcn(app, @BreakbwROIssEditFieldValueChanged, true);
            app.BreakbwROIssEditField.Editable = 'off';
            app.BreakbwROIssEditField.Enable = 'off';
            app.BreakbwROIssEditField.Position = [135 29 54 22];

            % Create inburstEditField_2Label
            app.inburstEditField_2Label = uilabel(app.ROIStimOrderButtonGroup);
            app.inburstEditField_2Label.HorizontalAlignment = 'right';
            app.inburstEditField_2Label.Enable = 'off';
            app.inburstEditField_2Label.Position = [11 5 54 22];
            app.inburstEditField_2Label.Text = '# in burst';

            % Create inburstEditField
            app.inburstEditField = uieditfield(app.ROIStimOrderButtonGroup, 'numeric');
            app.inburstEditField.Limits = [1 Inf];
            app.inburstEditField.RoundFractionalValues = 'on';
            app.inburstEditField.ValueChangedFcn = createCallbackFcn(app, @inburstEditFieldValueChanged, true);
            app.inburstEditField.Editable = 'off';
            app.inburstEditField.Enable = 'off';
            app.inburstEditField.Position = [70 5 21 22];
            app.inburstEditField.Value = 1;

            % Create msbwinburstEditField_2Label
            app.msbwinburstEditField_2Label = uilabel(app.ROIStimOrderButtonGroup);
            app.msbwinburstEditField_2Label.HorizontalAlignment = 'right';
            app.msbwinburstEditField_2Label.Enable = 'off';
            app.msbwinburstEditField_2Label.Position = [101 5 86 22];
            app.msbwinburstEditField_2Label.Text = 'ms b/w in burst';

            % Create msbwinburstEditField
            app.msbwinburstEditField = uieditfield(app.ROIStimOrderButtonGroup, 'numeric');
            app.msbwinburstEditField.Limits = [0 Inf];
            app.msbwinburstEditField.RoundFractionalValues = 'on';
            app.msbwinburstEditField.ValueChangedFcn = createCallbackFcn(app, @msbwinburstEditFieldValueChanged, true);
            app.msbwinburstEditField.Editable = 'off';
            app.msbwinburstEditField.Enable = 'off';
            app.msbwinburstEditField.Position = [194 5 29 22];

            % Create EditField_2
            app.EditField_2 = uieditfield(app.ROIStimOrderButtonGroup, 'numeric');
            app.EditField_2.Limits = [1 12];
            app.EditField_2.RoundFractionalValues = 'on';
            app.EditField_2.Position = [135 74 52 22];
            app.EditField_2.Value = 1;

            % Create LoggingControlsLabel
            app.LoggingControlsLabel = uilabel(app.UIFigure);
            app.LoggingControlsLabel.FontSize = 14;
            app.LoggingControlsLabel.FontWeight = 'bold';
            app.LoggingControlsLabel.Position = [281 407 125 22];
            app.LoggingControlsLabel.Text = 'Logging Controls:';

            % Create LoggingDirectoryEditFieldLabel
            app.LoggingDirectoryEditFieldLabel = uilabel(app.UIFigure);
            app.LoggingDirectoryEditFieldLabel.HorizontalAlignment = 'right';
            app.LoggingDirectoryEditFieldLabel.Position = [279 381 101 22];
            app.LoggingDirectoryEditFieldLabel.Text = 'Logging Directory';

            % Create LoggingDirectoryEditField
            app.LoggingDirectoryEditField = uieditfield(app.UIFigure, 'text');
            app.LoggingDirectoryEditField.CharacterLimits = [1 Inf];
            app.LoggingDirectoryEditField.ValueChangedFcn = createCallbackFcn(app, @LoggingDirectoryEditFieldValueChanged, true);
            app.LoggingDirectoryEditField.Placeholder = 'D:\new_FP_Polina\Recordings';
            app.LoggingDirectoryEditField.Position = [420 381 212 22];
            app.LoggingDirectoryEditField.Value = 'D:\new_FP_Polina\Recordings';

            % Create VideoFilenameEditFieldLabel
            app.VideoFilenameEditFieldLabel = uilabel(app.UIFigure);
            app.VideoFilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.VideoFilenameEditFieldLabel.Position = [281 349 87 22];
            app.VideoFilenameEditFieldLabel.Text = 'Video Filename';

            % Create VideoFilenameEditField
            app.VideoFilenameEditField = uieditfield(app.UIFigure, 'text');
            app.VideoFilenameEditField.CharacterLimits = [1 Inf];
            app.VideoFilenameEditField.Position = [420 349 212 22];

            % Create StimLogFilenameEditFieldLabel
            app.StimLogFilenameEditFieldLabel = uilabel(app.UIFigure);
            app.StimLogFilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.StimLogFilenameEditFieldLabel.Position = [280 319 105 22];
            app.StimLogFilenameEditFieldLabel.Text = 'Stim Log Filename';

            % Create StimLogFilenameEditField
            app.StimLogFilenameEditField = uieditfield(app.UIFigure, 'text');
            app.StimLogFilenameEditField.CharacterLimits = [1 Inf];
            app.StimLogFilenameEditField.Position = [420 319 212 22];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.Position = [342 90 41 22];
            app.StatusLabel.Text = 'Status:';

            % Create CurrentrecordingdurationLabel
            app.CurrentrecordingdurationLabel = uilabel(app.UIFigure);
            app.CurrentrecordingdurationLabel.FontWeight = 'bold';
            app.CurrentrecordingdurationLabel.Position = [11 47 162 22];
            app.CurrentrecordingdurationLabel.Text = 'Current recording duration:';

            % Create StartingupLabel
            app.StartingupLabel = uilabel(app.UIFigure);
            app.StartingupLabel.HorizontalAlignment = 'right';
            app.StartingupLabel.Position = [423 90 151 22];
            app.StartingupLabel.Text = 'Starting up...';

            % Create NALabel_3
            app.NALabel_3 = uilabel(app.UIFigure);
            app.NALabel_3.Enable = 'off';
            app.NALabel_3.Position = [12 12 291 41];
            app.NALabel_3.Text = 'N/A';

            % Create TimeStartedLabel
            app.TimeStartedLabel = uilabel(app.UIFigure);
            app.TimeStartedLabel.FontWeight = 'bold';
            app.TimeStartedLabel.Position = [342 70 82 22];
            app.TimeStartedLabel.Text = 'Time Started:';

            % Create NALabel_2
            app.NALabel_2 = uilabel(app.UIFigure);
            app.NALabel_2.HorizontalAlignment = 'right';
            app.NALabel_2.Enable = 'off';
            app.NALabel_2.Position = [343 69 231 22];
            app.NALabel_2.Text = 'N/A';

            % Create CalibrationFilesLabel
            app.CalibrationFilesLabel = uilabel(app.UIFigure);
            app.CalibrationFilesLabel.FontSize = 14;
            app.CalibrationFilesLabel.FontWeight = 'bold';
            app.CalibrationFilesLabel.Position = [281 286 117 22];
            app.CalibrationFilesLabel.Text = 'Calibration Files:';

            % Create TransCoordsFileEditFieldLabel
            app.TransCoordsFileEditFieldLabel = uilabel(app.UIFigure);
            app.TransCoordsFileEditFieldLabel.HorizontalAlignment = 'right';
            app.TransCoordsFileEditFieldLabel.Position = [280 256 102 22];
            app.TransCoordsFileEditFieldLabel.Text = 'Trans. Coords File';

            % Create TransCoordsFileEditField
            app.TransCoordsFileEditField = uieditfield(app.UIFigure, 'text');
            app.TransCoordsFileEditField.CharacterLimits = [5 Inf];
            app.TransCoordsFileEditField.ValueChangedFcn = createCallbackFcn(app, @TransCoordsFileEditFieldValueChanged, true);
            app.TransCoordsFileEditField.Placeholder = 'TranslatedCoords_020426.mat';
            app.TransCoordsFileEditField.Position = [420 256 212 22];
            app.TransCoordsFileEditField.Value = 'TranslatedCoords_020426.mat';

            % Create CalMtxFileEditFieldLabel
            app.CalMtxFileEditFieldLabel = uilabel(app.UIFigure);
            app.CalMtxFileEditFieldLabel.HorizontalAlignment = 'right';
            app.CalMtxFileEditFieldLabel.Position = [277 225 69 22];
            app.CalMtxFileEditFieldLabel.Text = 'Cal Mtx File';

            % Create CalMtxFileEditField
            app.CalMtxFileEditField = uieditfield(app.UIFigure, 'text');
            app.CalMtxFileEditField.CharacterLimits = [5 Inf];
            app.CalMtxFileEditField.ValueChangedFcn = createCallbackFcn(app, @CalMtxFileEditFieldValueChanged, true);
            app.CalMtxFileEditField.Placeholder = 'cal_mtx_020426.mat';
            app.CalMtxFileEditField.Position = [419 225 212 22];
            app.CalMtxFileEditField.Value = 'cal_mtx_020426.mat';

            % Create LaserIntensitiesFileEditFieldLabel
            app.LaserIntensitiesFileEditFieldLabel = uilabel(app.UIFigure);
            app.LaserIntensitiesFileEditFieldLabel.HorizontalAlignment = 'right';
            app.LaserIntensitiesFileEditFieldLabel.Position = [279 192 115 22];
            app.LaserIntensitiesFileEditFieldLabel.Text = 'Laser Intensities File';

            % Create LaserIntensitiesFileEditField
            app.LaserIntensitiesFileEditField = uieditfield(app.UIFigure, 'text');
            app.LaserIntensitiesFileEditField.CharacterLimits = [5 Inf];
            app.LaserIntensitiesFileEditField.ValueChangedFcn = createCallbackFcn(app, @LaserIntensitiesFileEditFieldValueChanged, true);
            app.LaserIntensitiesFileEditField.Placeholder = 'lsr_ints_020426.mat';
            app.LaserIntensitiesFileEditField.Position = [418 192 212 22];
            app.LaserIntensitiesFileEditField.Value = 'lsr_ints_020426.mat';

            % Create StartExperimentButton
            app.StartExperimentButton = uibutton(app.UIFigure, 'state');
            app.StartExperimentButton.ValueChangedFcn = createCallbackFcn(app, @StartExperimentButtonValueChanged, true);
            app.StartExperimentButton.Text = 'Start Experiment';
            app.StartExperimentButton.BackgroundColor = [0.7804 0.749 1];
            app.StartExperimentButton.FontSize = 14;
            app.StartExperimentButton.FontWeight = 'bold';
            app.StartExperimentButton.Position = [343 116 231 47];

            % Create PreviewROIGUIButton
            app.PreviewROIGUIButton = uibutton(app.UIFigure, 'push');
            app.PreviewROIGUIButton.ButtonPushedFcn = createCallbackFcn(app, @PreviewROIGUIButtonPushed, true);
            app.PreviewROIGUIButton.Text = 'Preview ROI GUI';
            app.PreviewROIGUIButton.Position = [343 168 231 22];

            % Create PulseDurationmsEditFieldLabel
            app.PulseDurationmsEditFieldLabel = uilabel(app.UIFigure);
            app.PulseDurationmsEditFieldLabel.HorizontalAlignment = 'right';
            app.PulseDurationmsEditFieldLabel.Position = [22 381 111 22];
            app.PulseDurationmsEditFieldLabel.Text = 'Pulse Duration (ms)';

            % Create PulseDurationmsEditField
            app.PulseDurationmsEditField = uieditfield(app.UIFigure, 'numeric');
            app.PulseDurationmsEditField.Limits = [1 Inf];
            app.PulseDurationmsEditField.RoundFractionalValues = 'on';
            app.PulseDurationmsEditField.ValueChangedFcn = createCallbackFcn(app, @PulseDurationmsEditFieldValueChanged2, true);
            app.PulseDurationmsEditField.Position = [161 381 62 20];
            app.PulseDurationmsEditField.Value = 5;

            % Create TimebwPulsessEditFieldLabel
            app.TimebwPulsessEditFieldLabel = uilabel(app.UIFigure);
            app.TimebwPulsessEditFieldLabel.HorizontalAlignment = 'right';
            app.TimebwPulsessEditFieldLabel.Position = [22 351 109 22];
            app.TimebwPulsessEditFieldLabel.Text = 'Time b/w Pulses (s)';

            % Create TimebwPulsessEditField
            app.TimebwPulsessEditField = uieditfield(app.UIFigure, 'numeric');
            app.TimebwPulsessEditField.Limits = [0 Inf];
            app.TimebwPulsessEditField.ValueChangedFcn = createCallbackFcn(app, @TimebwPulsessEditFieldValueChanged2, true);
            app.TimebwPulsessEditField.Position = [161 351 62 19];
            app.TimebwPulsessEditField.Value = 30;

            % Create NumberofPulsesEditFieldLabel
            app.NumberofPulsesEditFieldLabel = uilabel(app.UIFigure);
            app.NumberofPulsesEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofPulsesEditFieldLabel.Position = [20 319 100 22];
            app.NumberofPulsesEditFieldLabel.Text = 'Number of Pulses';

            % Create NumberofPulsesEditField
            app.NumberofPulsesEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumberofPulsesEditField.Limits = [0 Inf];
            app.NumberofPulsesEditField.RoundFractionalValues = 'on';
            app.NumberofPulsesEditField.ValueChangedFcn = createCallbackFcn(app, @NumberofPulsesEditFieldValueChanged2, true);
            app.NumberofPulsesEditField.Position = [161 319 62 19];
            app.NumberofPulsesEditField.Value = 1;

            % Create BaselinePeriodsEditFieldLabel
            app.BaselinePeriodsEditFieldLabel = uilabel(app.UIFigure);
            app.BaselinePeriodsEditFieldLabel.HorizontalAlignment = 'right';
            app.BaselinePeriodsEditFieldLabel.Position = [21 289 106 22];
            app.BaselinePeriodsEditFieldLabel.Text = 'Baseline Period (s)';

            % Create BaselinePeriodsEditField
            app.BaselinePeriodsEditField = uieditfield(app.UIFigure, 'numeric');
            app.BaselinePeriodsEditField.Limits = [0 Inf];
            app.BaselinePeriodsEditField.ValueChangedFcn = createCallbackFcn(app, @BaselinePeriodsEditFieldValueChanged2, true);
            app.BaselinePeriodsEditField.Position = [161 288 62 20];

            % Create PostStimPeriodsEditFieldLabel
            app.PostStimPeriodsEditFieldLabel = uilabel(app.UIFigure);
            app.PostStimPeriodsEditFieldLabel.HorizontalAlignment = 'right';
            app.PostStimPeriodsEditFieldLabel.Position = [20 256 112 22];
            app.PostStimPeriodsEditFieldLabel.Text = 'Post Stim Period (s)';

            % Create PostStimPeriodsEditField
            app.PostStimPeriodsEditField = uieditfield(app.UIFigure, 'numeric');
            app.PostStimPeriodsEditField.Limits = [0 Inf];
            app.PostStimPeriodsEditField.ValueChangedFcn = createCallbackFcn(app, @PostStimPeriodsEditFieldValueChanged, true);
            app.PostStimPeriodsEditField.Position = [161 256 62 22];

            % Create STIMONLabel
            app.STIMONLabel = uilabel(app.UIFigure);
            app.STIMONLabel.HorizontalAlignment = 'center';
            app.STIMONLabel.FontSize = 30;
            app.STIMONLabel.FontWeight = 'bold';
            app.STIMONLabel.FontColor = [1 0 0];
            app.STIMONLabel.Visible = 'off';
            app.STIMONLabel.Position = [387 27 133 40];
            app.STIMONLabel.Text = 'STIM ON';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ExperimentalGUI_TTLtrig_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            stopROIPreview(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
