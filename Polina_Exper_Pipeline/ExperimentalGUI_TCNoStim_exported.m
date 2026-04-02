classdef ExperimentalGUI_TCNoStim_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        StartExperimentButton           matlab.ui.control.StateButton
        NALabel_2                       matlab.ui.control.Label
        TimeStartedLabel                matlab.ui.control.Label
        StartingupLabel                 matlab.ui.control.Label
        StatusLabel                     matlab.ui.control.Label
        VideoFilenameEditField          matlab.ui.control.EditField
        VideoFilenameEditFieldLabel     matlab.ui.control.Label
        LoggingDirectoryEditField       matlab.ui.control.EditField
        LoggingDirectoryEditFieldLabel  matlab.ui.control.Label
        LoggingControlsLabel            matlab.ui.control.Label
    end

    
    properties (Access = private)
        v
        src
        dqIn
        lsr
        numROIs
        FrameRate
        bcam_log
        bcamfullFilename
        
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            warning('off','all')

            % Change label to idle
            app.StartingupLabel.Text = 'Idle';


        end

        % Value changed function: StartExperimentButton
        function StartExperimentButtonValueChanged(app, event)
            value = app.StartExperimentButton.Value;
            
            if value


                app.StartExperimentButton.Enable = "off";
                app.LoggingDirectoryEditField.Enable = "off";
                app.VideoFilenameEditField.Enable = "off";

                % Get everything ready according to set protocol values
                app.StartingupLabel.Text = 'Preparing for recording...';

                app.numROIs = 12;

                app.FrameRate = 80; % Hz



                % Connect to camera
                app.v = videoinput("hamamatsu", 1, "MONO16_BIN2x2_1152x1152_Fast");
                app.v.ROIPosition = [0 160 576 238]*2;

                app.src = getselectedsource(app.v);
                app.src.OutputTriggerKindOpt1 = "exposure";
                app.src.OutputTriggerPolarityOpt1 = "positive";
                app.src.ExposureTime = 1/app.FrameRate;

                app.lsr = lsrCtrlParams;

                
                
                % Set up DAQ
                app.dqIn = daq("ni");
                
                addinput(app.dqIn, "Dev1", "ai29", "Voltage"); % input channel receiving photometry cam frame voltages
                addinput(app.dqIn, "Dev1", "ai2", "Voltage"); % input channel receiving behavior cam frame voltages
                addinput(app.dqIn, "Dev1", "ai27", "Voltage"); % input channel receiving voltage random LED in rig 
                app.dqIn.Rate = 2000;


                app.lsr = lsrCtrlParams; % get class object with laser parameters


                % Set up video recording
                fullFilename = fullfile(app.LoggingDirectoryEditField.Value, app.VideoFilenameEditField.Value+".avi");
                logfile = VideoWriter(fullFilename, "Grayscale AVI");
                app.v.LoggingMode = "disk";
                app.v.DiskLogger = logfile;
                app.v.FramesPerTrigger = Inf;

                % Set up bcam log
                app.bcamfullFilename = fullfile(app.LoggingDirectoryEditField.Value, app.VideoFilenameEditField.Value+"_bcam.mat");

                % Read in bcam log inputs continuously
                start(app.dqIn, "Continuous")
                app.StartingupLabel.Text = 'Recording...';

                % Start recording
                start(app.v);
                app.lsr.time_start_vid = datetime("now", 'Format', 'HH:mm:ss.SSSSSSSSS');
                
                app.NALabel_2.Enable = true;
                app.NALabel_2.Text = sprintf("%s", app.lsr.time_start_vid);
                

                app.StartExperimentButton.Text = 'Stop Experiment';
                app.StartExperimentButton.Enable = "on";


            else
                
                % Stop recording
                app.StartingupLabel.Text = 'Saving video...';
                app.StartExperimentButton.Enable = "off";

                stop(app.v);

                % Stop NI DAQ acquisition
                stop(app.dqIn);
                [input_logs, timestamps, trigtime] = read(app.dqIn, 'all', "OutputFormat", "Matrix");

                scan_start = datetime(trigtime,'ConvertFrom','datenum','Format','HH:mm:ss.SSSSSSSSS');
                
                
                % Same frame time stamp log
                app.StartingupLabel.Text = 'Saving behavior cam log...';
                drawnow

                app.bcam_log{3} = timestamps; % DAQinput time stamps
                app.bcam_log{4} = input_logs(:, 1); % photometry cam frame voltage trace
                app.bcam_log{5} = input_logs(:, 2); % behavior cam frame voltage trace
                app.bcam_log{6} = input_logs(:, 3); % rig random LED voltage trace

                app.bcam_log{1} = app.lsr.time_start_vid; % computer time of video start
                app.bcam_log{2} = scan_start; % DAQ time of scan start
                bcl = app.bcam_log;
                save(app.bcamfullFilename, "bcl");

                

                % Delete acquisition objects
                delete(app.v)
                delete(app.dqIn)

                % Change label to idle
                app.StartingupLabel.Text = 'Idle';
                app.NALabel_2.Enable = "off";
                app.NALabel_2.Text = "N/A";

                % Change Button Label
                app.StartExperimentButton.Text = 'Start Experiment';
                app.StartExperimentButton.Enable = "on";
                app.LoggingDirectoryEditField.Enable = "on";
                app.VideoFilenameEditField.Enable = "on";

            end

            
        end

        % Value changed function: LoggingDirectoryEditField
        function LoggingDirectoryEditFieldValueChanged(app, event)
            
            if ~isfolder(app.LoggingDirectoryEditField.Value)
                app.LoggingDirectoryEditField.Value = "directory does not exist!";
            end
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 476 242];
            app.UIFigure.Name = 'MATLAB App';

            % Create LoggingControlsLabel
            app.LoggingControlsLabel = uilabel(app.UIFigure);
            app.LoggingControlsLabel.FontSize = 14;
            app.LoggingControlsLabel.FontWeight = 'bold';
            app.LoggingControlsLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.LoggingControlsLabel.Position = [15 204 125 22];
            app.LoggingControlsLabel.Text = 'Logging Controls:';

            % Create LoggingDirectoryEditFieldLabel
            app.LoggingDirectoryEditFieldLabel = uilabel(app.UIFigure);
            app.LoggingDirectoryEditFieldLabel.HorizontalAlignment = 'right';
            app.LoggingDirectoryEditFieldLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.LoggingDirectoryEditFieldLabel.Position = [13 178 101 22];
            app.LoggingDirectoryEditFieldLabel.Text = 'Logging Directory';

            % Create LoggingDirectoryEditField
            app.LoggingDirectoryEditField = uieditfield(app.UIFigure, 'text');
            app.LoggingDirectoryEditField.CharacterLimits = [1 Inf];
            app.LoggingDirectoryEditField.ValueChangedFcn = createCallbackFcn(app, @LoggingDirectoryEditFieldValueChanged, true);
            app.LoggingDirectoryEditField.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.LoggingDirectoryEditField.Placeholder = 'F:\Stim Rig Data';
            app.LoggingDirectoryEditField.Position = [154 178 285 22];
            app.LoggingDirectoryEditField.Value = 'Z:\Vanessa\new_FP_Polina';

            % Create VideoFilenameEditFieldLabel
            app.VideoFilenameEditFieldLabel = uilabel(app.UIFigure);
            app.VideoFilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.VideoFilenameEditFieldLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.VideoFilenameEditFieldLabel.Position = [15 146 87 22];
            app.VideoFilenameEditFieldLabel.Text = 'Video Filename';

            % Create VideoFilenameEditField
            app.VideoFilenameEditField = uieditfield(app.UIFigure, 'text');
            app.VideoFilenameEditField.CharacterLimits = [1 Inf];
            app.VideoFilenameEditField.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.VideoFilenameEditField.Position = [154 146 285 22];
            app.VideoFilenameEditField.Value = 'tt';

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.StatusLabel.Position = [128 45 41 22];
            app.StatusLabel.Text = 'Status:';

            % Create StartingupLabel
            app.StartingupLabel = uilabel(app.UIFigure);
            app.StartingupLabel.HorizontalAlignment = 'right';
            app.StartingupLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.StartingupLabel.Position = [209 45 151 22];
            app.StartingupLabel.Text = 'Starting up...';

            % Create TimeStartedLabel
            app.TimeStartedLabel = uilabel(app.UIFigure);
            app.TimeStartedLabel.FontWeight = 'bold';
            app.TimeStartedLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.TimeStartedLabel.Position = [128 25 82 22];
            app.TimeStartedLabel.Text = 'Time Started:';

            % Create NALabel_2
            app.NALabel_2 = uilabel(app.UIFigure);
            app.NALabel_2.HorizontalAlignment = 'right';
            app.NALabel_2.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.NALabel_2.Enable = 'off';
            app.NALabel_2.Position = [129 24 231 22];
            app.NALabel_2.Text = 'N/A';

            % Create StartExperimentButton
            app.StartExperimentButton = uibutton(app.UIFigure, 'state');
            app.StartExperimentButton.ValueChangedFcn = createCallbackFcn(app, @StartExperimentButtonValueChanged, true);
            app.StartExperimentButton.Text = 'Start Experiment';
            app.StartExperimentButton.BackgroundColor = [0.7804 0.749 1];
            app.StartExperimentButton.FontSize = 14;
            app.StartExperimentButton.FontWeight = 'bold';
            app.StartExperimentButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.StartExperimentButton.Position = [129 71 231 47];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ExperimentalGUI_TCNoStim_exported

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

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end