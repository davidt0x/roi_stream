%% make_test_video.m
% Generates a bouncing white circle on black background.
% Output: MP4 (H.264) 1280x720 @ 60 fps, ~15 seconds.

% ---- Config ----
outPath   = fullfile(pwd, 'test_circle_1280x720_60fps.mp4');
W = 1280; H = 720;              % resolution
fps = 60; durationSec = 15;     % frame rate & duration
R = 60;                         % circle radius (pixels)
speed = 420;                    % circle speed (pixels/second)

% ---- Derived ----
N = fps * durationSec;          % number of frames
vx = speed / fps; vy = 0.77*speed / fps;     % initial velocity (px/frame)
x = W/4; y = H/3;                             % initial position (float)
bg = uint8(0); fg = uint8(255);

% ---- Video writer ----
try
    vw = VideoWriter(outPath, 'MPEG-4');     % H.264 MP4
    vw.Quality = 95;
catch
    vw = VideoWriter(outPath, 'Uncompressed AVI'); % fallback
end
vw.FrameRate = fps;
open(vw);

% Prealloc helpers
img = zeros(H, W, 'uint8');
[Xfull, Yfull] = meshgrid(1:W, 1:H);  %#ok<NASGU>  % (unused, kept for quick tweaks)

% Bounding-box mask builder (avoids touching full frame each time)
for k = 1:N
    % Move
    x = x + vx;  y = y + vy;

    % Bounce on edges
    if x - R < 1,      x = 1 + R;      vx = -vx; end
    if x + R > W,      x = W - R;      vx = -vx; end
    if y - R < 1,      y = 1 + R;      vy = -vy; end
    if y + R > H,      y = H - R;      vy = -vy; end

    % Clear frame
    img(:) = bg;

    % Draw circle only within its bounding box for speed
    xmin = max(1, floor(x - R));  xmax = min(W, ceil(x + R));
    ymin = max(1, floor(y - R));  ymax = min(H, ceil(y + R));
    [xb, yb] = meshgrid(xmin:xmax, ymin:ymax);
    mask = (xb - x).^2 + (yb - y).^2 <= R^2;
    img(ymin:ymax, xmin:xmax) = uint8(mask) * fg;

    % Encode (VideoWriter expects RGB; replicate gray)
    writeVideo(vw, repmat(img, [1 1 3]));
end

close(vw);
fprintf('Wrote %s (%dx%d @ %d fps, %d frames)\n', outPath, W, H, fps, N);

% Tip: In OBS, add "Media Source" → pick this file → enable "Loop".
