function means = roi_compute_means(f16, roi)
% ROI_COMPUTE_MEANS  Per-ROI mean on a uint16 frame using precomputed indices.
%   f16 : HxW uint16 image
%   roi : struct with fields .idx (cell) and .npix (uint32)

K = numel(roi.npix);
means = zeros(1, K, 'single');
for k = 1:K
    % Use a wide accumulator to avoid overflow (uint16 sums can be 1e8+)
    s = sum(f16(roi.idx{k}), 'double');
    means(k) = single(s / double(roi.npix(k)));
end
end
