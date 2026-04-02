function roi = roi_build_circle_indices(H, W, circles)
%ROI_BUILD_CIRCLE_INDICES Precompute linear indices for circular ROIs.
% circles: Nx3 [xc, yc, r] in 1-based pixel coordinates.

N = size(circles, 1);
roi.idx = cell(N, 1);
roi.npix = zeros(N, 1, 'uint32');
roi.circles = circles;

[xg, yg] = meshgrid(1:W, 1:H);
for k = 1:N
    xc = circles(k, 1);
    yc = circles(k, 2);
    r = circles(k, 3);
    mask = (xg - xc).^2 + (yg - yc).^2 <= r.^2;
    idx = find(mask);
    roi.idx{k} = idx;
    roi.npix(k) = uint32(numel(idx));
end
end
