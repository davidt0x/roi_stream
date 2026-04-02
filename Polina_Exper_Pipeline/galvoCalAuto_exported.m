classdef galvoCalAuto_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure  matlab.ui.Figure
        UIAxes_2  matlab.ui.control.UIAxes
        UIAxes    matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        points

    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Hide figures for now
            title(app.UIAxes, "Setting up ...");
            app.UIAxes_2.Visible = 'off';
            app.UIAxes.Visible = 'off';

            % Connect to camera
            v = videoinput("hamamatsu", 1, "MONO16_BIN2x2_1152x1152_Fast");
            % Crop the image frame
            v.ROIPosition = [0 160 576 238]*2;

            % Connect to laser
            dq = daq("ni");
            dq.Rate = 2000; % scans/sec. Not important here yet
            addoutput(dq, "Dev1", "ao0", "Voltage"); % output channel 1, corresponding to laser analog input
            addoutput(dq, "Dev1", "port0/line7", "Digital"); % digital output channel USER1, corresponding to laser digital input
            addoutput(dq, "Dev1", "ao2", "Voltage"); % output channel 3, corresponding to galvo X input
            addoutput(dq, "Dev1", "ao3", "Voltage"); % output channel 4, corresponding to galvo Y input

            % Set up some variables for later
            global lsr
            app.points = [];

            % Set grid over which to scan laser
            VxMin        = -2; % allowed range: -10 to 10.
            VxMax        = 3;
            VyMin        = -2.55;
            VyMax        = 2.5;
            GridSpacingx  = 0.5; % V, what you want voltage increments to be when running horizontally through the grid
            GridSpacingy  = 0.5; % V, what you want voltage increments to be when running vertically through the grid
            GridSizeX    = ((VxMax - VxMin)/GridSpacingx) + 1;
            GridSizeY    = ((VyMax - VyMin)/GridSpacingy) + 1;
            GalvoVoltage = {};

            % Set laser control outputs
            app.UIAxes.Visible = 'on';
            outputs(2) = 1; % digital laser voltage = on
            outputs(1) = 3; % analog laser voltage to high value

            % Loop through grid of galvo voltages
            for iX = 1:GridSizeX
                for iY = 1:GridSizeY
                    % Calculate Vx and Vy increments
                    Vx = (VxMax-VxMin)*(iX-1)/(GridSizeX-1) + VxMin;
                    Vy = (VyMax-VyMin)*(iY-1)/(GridSizeY-1) + VyMin;

                    % Set voltage for DAQ galvo output channels
                    outputs(3) = Vx;
                    outputs(4) = Vy;

                    % Turn laser on and take snapshot, then turn laser off
                    write(dq, outputs);
                    snapshot = getsnapshot(v);
                    write(dq, [0  0 Vx Vy]); % turn laser off but keep galvo position
                    img = imshow(snapshot, 'Parent', app.UIAxes);
                    hold(app.UIAxes, 'on');
                    title(app.UIAxes, 'Different positions of the beam are being scanned.')


                    % Find where laser point is on image
                    [nrows, ncols] = size(snapshot);
                    intensity_mask = zeros(nrows, ncols);
                    max_intensity = max(snapshot(:));
                    intensity_mask(snapshot > (floor(max_intensity/1000 - 1)*1000)) = 1; % floor max intensity to nearest thousand (minus 1000) and use as threshhold

                    intensity_mask(:, 1:floor(ncols/2)) = 0; % make sure no bleed through in green frame is being detected

                    imshow(imoverlay(snapshot, intensity_mask, 'red'), 'Parent', app.UIAxes); % show main laser region

                    [mask_ys, mask_xs] = find(intensity_mask ==1);
                    rmoutliers(mask_xs, 'median'); % filter out any extra bright artifacts not part of main laser point
                    rmoutliers(mask_ys, 'median'); % filter out any extra bright artifacts not part of main laser point
                    avg_mask_x = median(mask_xs);
                    avg_mask_y = median(mask_ys);


                    % Plot center of laser point
                    plot(app.UIAxes, avg_mask_x, avg_mask_y, 'g*', 'MarkerSize', 10)

                    % Save laser point center coordinates
                    insert = [avg_mask_x avg_mask_y Vx Vy];
                    app.points= [app.points; insert];

                    % Save grid voltages just in case
                    GalvoVoltage(iX, iY) = {[Vx, Vy]};




                end
            end
            % Change message
            title(app.UIAxes, 'Calibration function calculation...')

            % Turn laser off and set back to 0 galvo voltage
            write (dq,[0 0 0 0]);

            % Save grid voltages just in case
            lsr.GalvoVoltage = GalvoVoltage;

            % Save calibration matrix as file in directory
            all_points = app.points;
            filename = sprintf('cal_mtx_%s.mat', datetime('now','Format','MMddyy'));
            save(filename, 'all_points');
    
            % Use cal_mtx file to find linear function to get galvo voltages from desired pixel location
            px = polyfit(all_points(:,3), all_points(:,1),1);
            slopex = px(1,1);
            intx = px(1,2);

            py = polyfit(all_points(:,4), all_points(:,2),1);
            slopey = py(1,1);
            inty = py(1,2);

            % Save to lsr
            lsr.slopex = slopex;
            lsr.slopey = slopey;
            lsr.intx = intx;
            lsr.inty = inty;

            xgrid = (VxMin-1):GridSpacingx:VxMax;

            % Plot
            app.UIAxes.Visible = 'off';
            app.UIAxes_2.Visible = 'on';
            scatter(all_points(:,3), all_points(:,1), 'blue', 'Parent', app.UIAxes_2);
            hold on
            scatter(all_points(:,4), all_points(:,2), 'red', 'Parent', app.UIAxes_2);
            plot(xgrid, xgrid*slopex + intx, 'blue', 'Parent', app.UIAxes_2)
            plot(xgrid, xgrid*slopey + inty, 'red', 'Parent', app.UIAxes_2)

            % Convert all fiber coordinates to galvo voltages
            galvo_coords = [];
            for i = 1:size(lsr.grid,1)
                % Get desired pixel location
                pix_x = lsr.grid(i, 2) + 2*lsr.mids(1,1);
                pix_y = lsr.grid(i, 3) + 2*lsr.mids(1,2);

                % Convert to voltage
                gVx = (pix_x - lsr.intx)/lsr.slopex;
                gVy = (pix_y - lsr.inty)/lsr.slopey;

                % Save in matrix
                galvo_coords = [galvo_coords; gVx gVy];
            end

            % Upload galvo voltages to lsr
            lsr.galvo_grid = [[1:size(galvo_coords, 1)].' galvo_coords]; % added indices in first column to keep track of permutations later

            % Update
            title(app.UIAxes_2, 'Calculation done!')
            % closereq()
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 651 341];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [37 47 580 248];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.UIFigure);
            title(app.UIAxes_2, ' ')
            xlabel(app.UIAxes_2, ' ')
            ylabel(app.UIAxes_2, ' ')
            zlabel(app.UIAxes_2, ' ')
            app.UIAxes_2.Position = [37 47 580 248];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = galvoCalAuto_exported

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