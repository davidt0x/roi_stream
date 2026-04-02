classdef calibrationGUIAuto_exported < matlab.ui.componentcontainer.ComponentContainer

    % Properties that correspond to underlying components
    properties (Access = private, Transient, NonCopyable)
        DoneButton_2        matlab.ui.control.Button
        DoneButton          matlab.ui.control.Button
        Label_2             matlab.ui.control.Label
        TakeSnapshotButton  matlab.ui.control.Button
        Label               matlab.ui.control.Label
        UIAxes              matlab.ui.control.UIAxes
    end

    properties (Access = private)
        img
        snapshot
        v
    end
    
    properties (Access = public)
        hCircles
        hText
        mids
        numCircles
        translated_coords
    end
    
    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function postSetupFcn(comp)
            % Make axes and later components invisible for now
            comp.UIAxes.Visible = 'off';
            comp.Label_2.Visible = 'off';
            comp.DoneButton.Visible = 'off';

            % Connect to camera
            v = videoinput("hamamatsu", 1, "MONO16_BIN2x2_1152x1152_Fast");

            % Crop the video saved after acquisition
            v.ROIPosition = [0 160 576 238]*2;
            
            % Save v variable
            comp.v = v;

            
        end

        % Button pushed function: TakeSnapshotButton
        function TakeSnapshotButtonPushed(comp, event)
            % Take snapshot
            snapshot = getsnapshot(comp.v);
            
            % Show image in GUI
            imshow(snapshot, 'Parent', comp.UIAxes);
            hold on


            % Show Done button and label
            comp.Label_2.Visible = 'on';
            comp.DoneButton.Visible = 'on';

            % Save snapshot to global var
            comp.snapshot = snapshot;

        end

        % Button pushed function: DoneButton
        function DoneButtonPushed(comp, event)
            % Disable buttons
            comp.DoneButton.Enable = "off";
            comp.TakeSnapshotButton.Enable = "off";

            % Run automatic fiber detection from snapshot
            % Detect fibers, find centers
            half = 1152/2;
            [centersL,radiiL] = imfindcircles(comp.snapshot(:, 1:half), [60 100],"ObjectPolarity","bright");
            [centers,radii] = imfindcircles(comp.snapshot(:, half:end), [60 100],"ObjectPolarity","bright");
            centers(:, 1) = centers(:, 1) + half; % necessary adjustment
            
            % Find both rightmost fibers
            [~,Lr_fib_idx] = max(centersL(:,1));
            [~,Rr_fib_idx] = max(centers(:,1));

            % Find midpoint between these fibers
            xL = centersL(Lr_fib_idx, 1);
            yL = centersL(Lr_fib_idx, 2);
            xR = centers(Rr_fib_idx, 1);
            yR = centers(Rr_fib_idx, 2);

            vert_mid = (yR - yL)/2;
            horz_mid = (xR - xL)/2;


            % Translate all left fibers
            translated_coords= [centersL(:,1)+horz_mid, centersL(:,2)+vert_mid, radiiL];
            comp.mids = [horz_mid vert_mid];


            % Log these coords
            translated_coords= [centersL(:,1) centersL(:,2), radiiL];
            numROIs = size(translated_coords, 1);

            % Make them a consistent order
            % Find topmost left fiber
            [~, top_fib_idx] = max(translated_coords(:, 2));
            top_fib = translated_coords(top_fib_idx, :);
            % Find rightmost left fiber
            [~, right_fib_idx] = max(translated_coords(:, 1));
            right_fib = translated_coords(right_fib_idx, :);
            % Find bottommost left fiber
            [~, bottom_fib_idx] = min(translated_coords(:, 2));
            bottom_fib = translated_coords(bottom_fib_idx, :);
            % Find leftmost left fiber
            [~, left_fib_idx] = min(translated_coords(:, 1));
            left_fib = translated_coords(left_fib_idx, :);

            if numROIs > 6
                % Use these to find inner vs outer fibers on the patchcord
                [inp, onp] = inpolygon(translated_coords(:,1), translated_coords(:,2), [top_fib(:,1), right_fib(:,1), bottom_fib(:,1), left_fib(:,1)], [top_fib(:,2), right_fib(:,2), bottom_fib(:,2), left_fib(:,2)]);
                points_in = translated_coords(logical(inp-onp), :);
                points_out = translated_coords(~logical(inp-onp), :); 
              
                % Sort inner and outer fibers in CW order about ~center point of
                % left fiber bundle
                avg_bundle_centerx = (right_fib(:,1) - left_fib(:,1))/2 + left_fib(:,1);
                avg_bundle_centery = (top_fib(:,2) - bottom_fib(:,2))/2 + bottom_fib(:,2);
                theta_in = cart2pol(points_in(:,1)-avg_bundle_centerx, points_in(:,2)-avg_bundle_centery);
                theta_in_wrapped = mod(theta_in, 2*pi);
                theta_in_wrapped(theta_in_wrapped==0 & theta_in>0) = 2*pi;
                [~, sortIdx_in] = sort(theta_in_wrapped, 'ascend');
                cw_points_in = points_in(sortIdx_in, :);
    
                theta_out = cart2pol(points_out(:,1)-avg_bundle_centerx, points_out(:,2)-avg_bundle_centery);
                theta_out_wrapped = mod(theta_out, 2*pi);
                theta_out_wrapped(theta_out_wrapped==0 & theta_out>0) = 2*pi;
                [~, sortIdx_out] = sort(theta_out_wrapped, 'ascend');
                cw_points_out = points_out(sortIdx_out, :);

                %Put points back into a similar format as before
                %translated_coords_sorted = [cw_points_out_x, cw_points_out_y; cw_points_in_x, cw_points_in_y];
                comp.translated_coords = [cw_points_out; cw_points_in];
                


            else

                % Sort ROIs in CW order about ~center point of left fiber bundle
                avg_bundle_centerx = (right_fib(:,1) - left_fib(:,1))/2 + left_fib(:,1);
                avg_bundle_centery = (top_fib(:,2) - bottom_fib(:,2))/2 + bottom_fib(:,2);
                
                theta_out = cart2pol(translated_coords(:,1)-avg_bundle_centerx, translated_coords(:,2)-avg_bundle_centery);
                theta_out_wrapped = mod(theta_out, 2*pi);
                theta_out_wrapped(theta_out_wrapped==0 & theta_out>0) = 2*pi;
                [~, sortIdx_out] = sort(theta_out_wrapped, 'ascend');
                
                comp.translated_coords = translated_coords(sortIdx_out, :);
                


            end
            
            % Display circles and allow user to change them as needed
            comp.numCircles = size(comp.translated_coords,1);
            comp.hCircles = gobjects(comp.numCircles,1);
            comp.hText = gobjects(comp.numCircles,1);
            listeners = cell(comp.numCircles,1);

            % Create interactive circles
            for k = 1:comp.numCircles
                comp.hCircles(k) = drawcircle('Center', comp.translated_coords(k,1:2), ...
                    'Radius', comp.translated_coords(k, 3), ...
                    'Color', 'blue', ...
                    'Parent', comp.UIAxes);

                % Add labels to keep track of roi #
                comp.hText(k) = text(comp.translated_coords(k,1), comp.translated_coords(k,2), ...
                    sprintf('%d',k), ...
                    'Color','white', ...
                    'FontSize',12, ...
                    'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'VerticalAlignment','middle', ...
                    'PickableParts','none', ...
                    'Parent', comp.UIAxes);
                % hText.Units = 'pixels'; % should keep label same size

                % Make text label update with dragging
                listeners{k} = addlistener(comp.hCircles(k), 'ROIMoved', @(src,evt) updateLabel(src,comp.hText(k)));

            end

            function updateLabel(circleHandle,textHandle)
                textHandle.Position = circleHandle.Center;
            end


            % Change instructions
            comp.Label.Text = "Move or resize ROIs as needed. Press 'Done' when finished.";
            comp.Label_2.Visible = 'off';
            comp.DoneButton.Visible = "off";
            comp.TakeSnapshotButton.Visible = "off";
            comp.DoneButton_2.Visible = "on";
            comp.DoneButton_2.Enable = "on";

            


        end

        % Button pushed function: DoneButton_2
        function DoneButton_2Pushed(comp, event)
            % Get current circle coords
            deleted_circs = [];

            for k = 1:comp.numCircles
                try
                    comp.translated_coords(k,1:2) = comp.hCircles(k).Center;
                    comp.translated_coords(k, 3) = comp.hCircles(k).Radius;
                catch % if circle was deleted
                    deleted_circs = [deleted_circs k];
                end
            end

            % If some deleted circles, delete their rows from translated_coords
            comp.translated_coords(deleted_circs, :) = [];
            translated_coords = comp.translated_coords;
            mids = comp.mids;
            
            % Save translated_coords as file in directory
            filename1 = sprintf('TranslatedCoords_%s.mat', datetime('now','Format','MMddyy'));
            save(filename1, 'translated_coords');
            filename2 = sprintf('mids_%s.mat', datetime('now','Format','MMddyy'));
            save(filename2, 'mids');

            % Close GUI
            closereq();
        end
    end

    methods (Access = protected)
        
        % Code that executes when the value of a property is changed
        function update(comp)
            % Use this function to update the underlying components
            
        end

        % Create the underlying components
        function setup(comp)

            comp.Position = [1 1 635 393];

            % Create UIAxes
            comp.UIAxes = uiaxes(comp);
            comp.UIAxes.PlotBoxAspectRatio = [2.42016809325895 1 2.42016809325895];
            comp.UIAxes.Position = [24 49 592 285];

            % Create Label
            comp.Label = uilabel(comp);
            comp.Label.FontSize = 14;
            comp.Label.Position = [29 333 596 46];
            comp.Label.Text = {'Hold end of fiber to a white light source such as a computer screen or lightbulb and press the '; 'button below when ready. Press the button again to retake.'};

            % Create TakeSnapshotButton
            comp.TakeSnapshotButton = uibutton(comp, 'push');
            comp.TakeSnapshotButton.ButtonPushedFcn = matlab.apps.createCallbackFcn(comp, @TakeSnapshotButtonPushed, true);
            comp.TakeSnapshotButton.Position = [489 326 103 25];
            comp.TakeSnapshotButton.Text = 'Take Snapshot';

            % Create Label_2
            comp.Label_2 = uilabel(comp);
            comp.Label_2.FontSize = 14;
            comp.Label_2.Position = [30 30 596 46];
            comp.Label_2.Text = {'When you''re satisfied with the snapshot (fibers are bright and visible), press "Done". '; ''};

            % Create DoneButton
            comp.DoneButton = uibutton(comp, 'push');
            comp.DoneButton.ButtonPushedFcn = matlab.apps.createCallbackFcn(comp, @DoneButtonPushed, true);
            comp.DoneButton.Position = [490 15 103 25];
            comp.DoneButton.Text = 'Done';

            % Create DoneButton_2
            comp.DoneButton_2 = uibutton(comp, 'push');
            comp.DoneButton_2.ButtonPushedFcn = matlab.apps.createCallbackFcn(comp, @DoneButton_2Pushed, true);
            comp.DoneButton_2.Enable = 'off';
            comp.DoneButton_2.Visible = 'off';
            comp.DoneButton_2.Position = [489 326 103 25];
            comp.DoneButton_2.Text = 'Done';
            
            % Execute the startup function
            postSetupFcn(comp)
        end
    end
end