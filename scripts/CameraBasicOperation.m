%% Set-up camera control

%check the Hamamatsu adaptor is present
imaqhwinfo

% resets the image acquisition environment
imaqreset 

%%

%List all the adaptor options for image acquisition 
%HamamatsuAdaptorRunningOptions=imaqhwinfo("hamamatsu").DeviceInfo.SupportedFormats';
options = imaqhwinfo("winvideo").DeviceInfo.SupportedFormats'

%Below we create the video input
%At the ame time, we choose to acquire images with 16bits encoding, to bin pixels 2x2
%and use the "Fast" reading option (also the noisiest)
%vid = videoinput('hamamatsu',1,'MONO16_BIN2x2_1152x1152_Fast');
vid = videoinput('winvideo', 1, 'MJPG_1920x1080');

%vid.ROIPosition=[0 0 1280 720];

%triggerconfig(vid, 'immediate'); % waits for trigger(vid) command to collect frame

%get(vid)

vid.FramesPerTrigger = 10;

%Create the object that allows changing the camera settings
%src = getselectedsource(vid); 

%Configure the Camera Output 1 to generate a Firing signal. It will be fed
%into the Arduino that controls the LEDs
%src.OutputTriggerKindOpt1='exposure';
%src.OutputTriggerPolarityOpt1 = "positive";

%Set the "frame rate" (the exposure is actually different)
%src.ExposureTime=1/120; %for 80 Hz
%src.TriggerSource = 'internal';
%get(src)


%% Take a snapshot of the fibers
frame = getsnapshot(vid);
figure, imshow(frame);

%% Preview
numFrames = 1000; 
vid.FramesPerTrigger = numFrames;
start(vid)
a = figure;
while isvalid(a) 
    pause(.1)
    data = (getdata(vid, vid.FramesAvailable));
    imagesc(squeeze(data(:,:,1,1)))
    title(['Max Pixel is ' num2str(max(squeeze(data(:)))) ', Mean Pixel is ' num2str(mean(squeeze(data(:))), 3)])
    drawnow
end
stop(vid)

%% Acquisition writing directly images to the disk (TIFF format)

%first, make sure no data are present in the buffer
flushdata(vid);

% Set the number of frames to acquire
numFrames = 100; 
vid.FramesPerTrigger = numFrames;
%at 80Hz bin2x2,ROI is half the chip, 20min acquisition(144000frames=167GB)


% %Saving an acquisition as AVI (not recommended, i.e data loss)
% fullfilename="D:\CameraStream\08142025\test.avi";
% vid.LoggingMode="disk";
% vid.DiskLogger=VideoWriter(fullfilename,"Grayscale AVI");
% % Start the video input object to begin acquisition
% start(vid);


%Saving an acquisition as individual Tiff files (recommended option)
RootFileName='Frame_%06d.tiff';
folderToSaveTo='08192025';
% Ensure the output folder exists
if ~exist(folderToSaveTo, 'dir')
    mkdir(folderToSaveTo);
end

% where are the data going?
vid.LoggingMode="memory";
vid.DiskLogger=[];

%Starting acquisition
start(vid);
% The hardware does not start acquiring immediately, but the status of
% vid.running is already 'on'

LastImage = 0; % Initialize the counter for saved frames
while strcmp(vid.running,'on') 
    Facq=vid.FramesAcquired;

    % Process and save each frame as a TIFF file
    LoopLength=vid.FramesAvailable;
    if LoopLength>0
        for i = 1:LoopLength
        frameData = squeeze(getdata(vid, 1));
        LastImage=LastImage+1;
        %writing data to disk
        %imwrite(frameData, fullfile(folderToSaveTo, sprintf(RootFileName, LastImage)));
        %visualize acquisition progress
        %fprintf('\r Frames acquired: %6d  out of %6d', LastImage, numFrames);
        end
    end

    %check if finished
    if Facq==vid.FramesPerTrigger
        break;
    end
end

% stopping acquisition
stop(vid);
fprintf('\n') ;
disp('DONE');


%%  Clean up and release the video input object
delete(vid);
clear vid;
