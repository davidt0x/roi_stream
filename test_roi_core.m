function test_roi_core()
% Tests core pieces without a camera:
%  1) uint16 mono frame with bright blob in ROI 1
%  2) uint8 RGB -> gray conversion with bright red blob in ROI 2
%  3) two frames with the bright blob moving (ROI 2 -> ROI 1)

H = 200; W = 300;
roiCircles = [60 80 20; 220 140 25];  % [xc yc r]
roi = build_circle_indices(H, W, roiCircles);

% Precompute coordinate grids once (H×W)
[xg, yg] = meshgrid(1:W, 1:H);

% --- (1) Pure uint16 mono: bright blob in ROI 1
f1 = zeros(H, W, 'uint16');
mask1 = ((xg - roiCircles(1,1)).^2 + (yg - roiCircles(1,2)).^2) <= roiCircles(1,3)^2;
f1(mask1) = 40000;
m1 = roi_compute_means(f1, roi);
assert(m1(1) > m1(2), 'ROI 1 should be brighter in test 1');

% --- (2) uint8 RGB -> gray: bright red blob in ROI 2
rgb = zeros(H, W, 3, 'uint8');
mask2 = ((xg - roiCircles(2,1)).^2 + (yg - roiCircles(2,2)).^2) <= roiCircles(2,3)^2;
rgb(:,:,1) = uint8(mask2) * 255;   % red channel = 255 inside ROI 2
f2 = to_uint16_gray(rgb);
m2 = roi_compute_means(f2, roi);
assert(m2(2) > m2(1), 'ROI 2 should be brighter after RGB->gray conversion');

% --- (3) Moving spot: frame A in ROI 2, frame B in ROI 1
fA = zeros(H, W, 'uint16'); fA(mask2) = 50000;
fB = zeros(H, W, 'uint16'); fB(mask1) = 50000;
mA = roi_compute_means(fA, roi);
mB = roi_compute_means(fB, roi);
assert(mA(2) > mA(1) && mB(1) > mB(2), 'Moving spot should swap which ROI is brighter');

disp('✅ test_roi_core passed');
end

function roi = build_circle_indices(H, W, circles)
% circles: Nx3 [xc, yc, r] (1-based pixel coords)
N = size(circles,1);
roi.idx = cell(N,1);
roi.npix = zeros(N,1,'uint32');
roi.circles = circles;
[xg, yg] = meshgrid(1:W, 1:H);
for k = 1:N
    xc = circles(k,1); yc = circles(k,2); r = circles(k,3);
    mask = (xg - xc).^2 + (yg - yc).^2 <= r.^2;
    roi.idx{k} = find(mask);
    roi.npix(k) = uint32(nnz(mask));
end
end
