function hFig = roi_stream_gui(vid, guiOpts)
% ROI_STREAM_GUI  Preview (≈1 Hz), ROI overlay, rolling traces, FPS label.
if nargin < 2, guiOpts = struct(); end
guiOpts = filldefaults(guiOpts, struct('PlotWindowSec',60, 'UpdatePeriod',1.0));

if ~isvalid(vid), error('Video object is not valid.'); end
S = vid.UserData;
vr = vid.VideoResolution; W = vr(1); H = vr(2);
K = size(S.trace_means,2);

% --- Figure & layout
hFig = figure('Name','ROI Stream Viewer', 'NumberTitle','off', ...
              'Color','w', 'Toolbar','none', 'MenuBar','none', ...
              'CloseRequestFcn', @(h,~) onClose(h));
colormap(hFig, gray(256));  % force grayscale at the figure level

t = tiledlayout(hFig,2,1,'Padding','compact','TileSpacing','compact');

% --- Preview axes
axImg = nexttile(t,1);
title(axImg,'Preview (~1 Hz)');
axImg.YDir = 'reverse';                              % image coordinates
axis(axImg,'image');                                 % preserve aspect ratio
set(axImg, 'DataAspectRatio',[1 1 1]);              % lock pixel aspect

% initialize with proper scaling; imshow keeps aspect & grayscale
imH = imshow(zeros(H,W,'uint16'), 'Parent', axImg, 'DisplayRange', [0 65535]);

hold(axImg,'on');
% draw circles
theta = linspace(0,2*pi,100);
colors = lines(max(K,1));
circH = gobjects(K,1);
for k=1:K
    xc = S.roi.circles(k,1); yc = S.roi.circles(k,2); r = S.roi.circles(k,3);
    x = xc + r*cos(theta);
    y = yc + r*sin(theta);
    circH(k) = plot(axImg, x, y, 'Color', colors(k,:), 'LineWidth', 1.25, ...
                    'HitTest','off', 'PickableParts','none');
end
hold(axImg,'off');

% --- Plot axes
axPlot = nexttile(t,2);
title(axPlot, sprintf('ROI Means (last %d s)', guiOpts.PlotWindowSec));
xlabel(axPlot, 'Time (s)'); ylabel(axPlot, 'Mean Intensity (a.u.)');
grid(axPlot,'on'); box(axPlot,'on'); hold(axPlot,'on');
lineH = gobjects(K,1);
for k=1:K
    lineH(k) = plot(axPlot, NaN, NaN, 'LineWidth', 1.2, 'Color', colors(k,:));
end
legend(axPlot, arrayfun(@(i)sprintf('ROI %d',i),1:K,'UniformOutput',false), ...
       'Location','northeastoutside');

% --- FPS label
fpsText = uicontrol('Style','text','Parent',hFig,'Units','normalized', ...
    'Position',[0.01 0.96 0.35 0.035], 'String','FPS: --', ...
    'BackgroundColor','w', 'HorizontalAlignment','left', 'FontWeight','bold');

% --- Timer
tm = timer('ExecutionMode','fixedSpacing', 'Period',guiOpts.UpdatePeriod, ...
           'TimerFcn', @(~,~) onTick(), 'StartDelay', guiOpts.UpdatePeriod);
start(tm);
guidata(hFig, struct('vid',vid,'axImg',axImg,'imH',imH,'lineH',lineH, ...
                     'fpsText',fpsText,'PlotWindowSec',guiOpts.PlotWindowSec,'timer',tm));

    function onTick()
        if ~isvalid(vid), return; end
        S = vid.UserData;

        % Update image (keep grayscale & aspect)
        if ~isempty(S.lastFrame)
            set(imH, 'CData', S.lastFrame);
            % optional: dynamic contrast — comment out if you prefer fixed [0,65535]
            % p = prctile(double(S.lastFrame(:)), [1 99]);
            % set(imH, 'DisplayRange', double(p));
            drawnow limitrate;
        end

        % FPS label
        fps = NaN; ft = S.frametimes;
        if numel(ft) >= 2, fps = (numel(ft)-1) / max(ft(end)-ft(1), eps); end
        set(fpsText, 'String', sprintf('FPS: %.1f   Frames: %d', fps, S.framesSeen));

        % Plot most recent traces
        [tvec, Y] = gather_recent_traces(S, guiOpts.PlotWindowSec);
        if ~isempty(tvec)
            for k=1:K
                set(lineH(k), 'XData', tvec, 'YData', Y(:,k));
            end
            xlim(axPlot, [max(0, tvec(end)-guiOpts.PlotWindowSec)  tvec(end)]);
            yl = [min(Y(:)), max(Y(:))];
            if all(isfinite(yl))
                if yl(1) == yl(2), yl = yl + [-1 1]; end
                dy = 0.05*max(1, yl(2)-yl(1));
                ylim(axPlot, [yl(1)-dy, yl(2)+dy]);
            end
        end
    end

    function onClose(h)
        try
            G = guidata(h);
            if isfield(G,'timer') && isvalid(G.timer)
                stop(G.timer); delete(G.timer);
            end
        catch
        end
        delete(h);
    end
end

% ---- helpers (local to this file) ----
function [tvec, Y] = gather_recent_traces(S, windowSec)
tvec = []; Y = [];
cap = S.trace_capacity; n = min(S.trace_head, cap);
if n == 0, return; end
idx  = mod((S.trace_head - n):(S.trace_head - 1), cap) + 1;
tall = S.trace_t(idx);
Yall = S.trace_means(idx, :);
if isempty(tall), return; end
tmax = tall(end);
keep = tall >= (tmax - windowSec);
tvec = tall(keep);
Y    = Yall(keep,:);
end

function d = filldefaults(d, defaults)
f = fieldnames(defaults);
for i=1:numel(f)
    k = f{i};
    if ~isfield(d,k) || isempty(d.(k)), d.(k) = defaults.(k); end
end
end
