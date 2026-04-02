% Load video + coordinate file
v = VideoReader("filename.avi"); % recording vid
translated_coords = load("array_with_ROI_centers.mat"); % .mat file with the following columns: ROI_center_X_in_pixels, ROI_center_Y_in_pixels, ROI_radius_in_pixels

nFrames = v.NumFrames;
nROI = 24;

%generate ROIs (75% of full fiber face)
roi_sz = 0.75;
for roi_n=1:nROI
    
    circ(roi_n) = drawcircle('Center',[translated_coords(roi_n,1), translated_coords(roi_n, 2)],...
        'Radius', roi_sz.*translated_coords(roi_n,3), 'Color', [237, 175, 184]./255,'FaceAlpha',0.33);
    BW(:,:,roi_n) = createMask(circ(roi_n));
    text(translated_coords(roi_n,1), translated_coords(roi_n, 2),sprintf('%d', roi_n), 'Color', 'white');
    
end

% set up variables for ROI mask
L = zeros(size(BW(:,:,1)));
for i = 1:nROI
    % Label the current mask with the current ROI ID
    currentMask = BW(:,:,i) > 0;
    L(currentMask) = i;
end

% Go through video and save ROI intensities to mean_pix_vals
mean_pix_vals = -1.*ones(nFrames, nROI);

for frame = 1:nFrames
    fr = read(v, frame);

    b=[];
    for j=1:nROI
        MaskROI=zeros(size(L));
        MaskROI(L==j)=1;
        MaskROI=uint8(MaskROI);
        a=fr.*MaskROI;
        b(:,j)=sum(a(:))/nnz(MaskROI); % avg pixel value in ROI
    end
    mean_pix_vals(frame, :) = b;

end
