function hFig = roi_stream_gui(vid, opts)
% ROI_STREAM_GUI  Low-overhead GUI for roi_stream (image + traces).
%   hFig = roi_stream_gui(vid, struct('PlotWindowSec',60,'UpdatePeriod',1.0))
%
% Smoothness tactics:
%   - UI runs on a timer (no work in acquisition callback)
%   - Image updated via set(CData) at throttled cadence
%   - Trace decimation to MaxPlotPoints
%   - drawnow limitrate nocallbacks
%
% Expects vid.UserData fields created by roi_stream:
%   S.trace_capacity, S.trace_head, S.trace_t, S.trace_means
%   S.lastFrame (uint16), S.lastFrameTime, S.frametimes, S.framesSeen, S.framesDropped

% ---- Options
if nargin < 2, opts = struct(); end
opts = filldefaults(opts, struct( ...
    'PlotWindowSec', 60, ...
    'UpdatePeriod',  0.5, ...       % UI refresh period (s)
    'ImagePeriod',   0.5, ...       % image refresh period (s)
    'MaxPlotPoints', 2500, ...
    'CLim',          [0 65535] ...
));

% ---- Figure & axes
vr = vid.VideoResolution; W = vr(1); H = vr(2);
hFig = figure('Name','ROI Stream','NumberTitle','off','Color','w', ...
    'Units','normalized','Position',[0.08 0.08 0.84 0.80], ...
    'CloseRequestFcn', @onClose);

% Top status
statusTxt = uicontrol('Style','text','Units','normalized', ...
    'Position',[0.01 0.95 0.98 0.04], 'BackgroundColor','w', ...
    'HorizontalAlignment','left','FontWeight','bold', 'String','…');

% Left: image + ROI outlines
axImg = axes('Parent',hFig,'Units','normalized','Position',[0.04 0.28 0.34 0.66]);
colormap(axImg, gray(256));
imgH = imagesc(axImg, zeros(H,W,'uint16'), opts.CLim); %#ok<NASGU>
axis(axImg,'image'); set(axImg,'YDir','reverse'); title(axImg,'Latest frame');

% ROI circles (once)
S0 = get_user_state(vid);
K  = size(S0.roi.circles,1);
theta = linspace(0,2*pi,100);
roiCirc = gobjects(K,1);
for k = 1:K
    [xc,yc,r] = deal(S0.roi.circles(k,1), S0.roi.circles(k,2), S0.roi.circles(k,3));
    x = xc + r*cos(theta); y = yc + r*sin(theta);
    roiCirc(k) = line(axImg, x, y, 'Color',[0.7 0.7 0.7], 'LineWidth',1.0, 'HitTest','off');
end

% Right: traces
axTr = axes('Parent',hFig,'Units','normalized','Position',[0.42 0.28 0.56 0.66]);
hold(axTr,'on'); grid(axTr,'on'); box(axTr,'on');
xlabel(axTr,'Time (s)'); ylabel(axTr,'Mean intensity (a.u.)');
title(axTr,'ROI traces (last window)');
colors = lines(max(K,1));
ln = gobjects(K,1);
for k = 1:K
    ln(k) = plot(axTr, NaN, NaN, 'LineWidth',1.1, 'Color', colors(mod(k-1,size(colors,1))+1,:));
end

% Controls (window + ROI selection)
uicontrol('Style','text','Units','normalized','Position',[0.42 0.20 0.08 0.03], ...
    'String','Window (s):','BackgroundColor','w','HorizontalAlignment','left');
winEdit = uicontrol('Style','edit','Units','normalized','Position',[0.50 0.20 0.08 0.035], ...
    'String', num2str(opts.PlotWindowSec), 'Callback', @(~,~)refreshNow());

uicontrol('Style','text','Units','normalized','Position',[0.60 0.20 0.08 0.03], ...
    'String','Start (s):','BackgroundColor','w','HorizontalAlignment','left');
startSlider = uicontrol('Style','slider','Units','normalized','Position',[0.68 0.205 0.30 0.025], ...
    'Min',0, 'Max',max(1,opts.PlotWindowSec), 'Value',0, 'Callback', @(~,~)refreshNow());

uicontrol('Style','text','Units','normalized','Position',[0.04 0.22 0.34 0.03],...
    'String','Selected ROI(s):','BackgroundColor','w','HorizontalAlignment','left');
roiList = uicontrol('Style','listbox','Units','normalized','Position',[0.04 0.06 0.34 0.16],...
    'String', arrayfun(@(k)sprintf('ROI %d',k),1:K,'UniformOutput',false), ...
    'Max',max(2,K),'Min',0,'Value',1:min(8,K), 'Callback', @onRoiSel);

% Remember GUI state
G = struct('lastImgUpdate', -inf, 'imgAx',axImg, 'traceAx',axTr, ...
    'imgHandle', imgH, 'ln', ln, 'roiCirc', roiCirc, ...
    'startSlider', startSlider, 'winEdit', winEdit, 'roiList', roiList, ...
    'statusTxt', statusTxt);
setappdata(hFig, 'roi_gui', G);

% ---- UI timer (decoupled from acquisition)
tm = timer('ExecutionMode','fixedSpacing', 'Period', max(0.1, opts.UpdatePeriod), ...
    'BusyMode','drop', 'TimerFcn', @onTick, 'StartDelay', opts.UpdatePeriod);
setappdata(hFig, 'roi_gui_timer', tm);
start(tm);

% ---- Nested callbacks
    function onTick(~,~)
        if ~ishandle(hFig) || ~isvalid(vid), safe_stop_timer(); return; end
        S = get_user_state(vid);
        if isempty(S), return; end

        % Update status
        fps = NaN; ft = S.frametimes;
        if numel(ft) >= 2, fps = (numel(ft)-1)/max(ft(end)-ft(1), eps); end
        set(statusTxt, 'String', sprintf('frames=%d   dropped=%d   inst FPS=%.1f', ...
            S.framesSeen, S.framesDropped, fps));

        % Update image at throttled cadence
        G = getappdata(hFig,'roi_gui');
        if (S.lastFrameTime - G.lastImgUpdate) >= opts.ImagePeriod && ~isempty(S.lastFrame)
            set(findobj(axImg,'Type','image'),'CData', S.lastFrame, 'CDataMapping','scaled');
            G.lastImgUpdate = S.lastFrameTime;
            setappdata(hFig,'roi_gui',G);
        end

        % Update traces
        update_traces(axTr, S, opts, ln, startSlider, winEdit, roiList);

        drawnow limitrate nocallbacks
    end

    function onRoiSel(~,~)
        sel = get(roiList,'Value'); if isempty(sel), sel = 1; end
        % highlight selected ROIs on image
        for kk = 1:K
            if ismember(kk, sel)
                set(roiCirc(kk),'LineWidth',2.2,'Color',colors(mod(kk-1,size(colors,1))+1,:));
            else
                set(roiCirc(kk),'LineWidth',1.0,'Color',[0.7 0.7 0.7]);
            end
        end
        refreshNow();
    end

    function refreshNow()
        if ~ishandle(hFig) || ~isvalid(vid), return; end
        S = get_user_state(vid);
        if isempty(S), return; end
        update_traces(axTr, S, opts, ln, startSlider, winEdit, roiList);
        drawnow limitrate nocallbacks
    end

    function onClose(~,~)
        safe_stop_timer();
        if isvalid(vid)
            try %#ok<TRYNC>
                % no-op: GUI shouldn’t stop acquisition
            end
        end
        delete(hFig);
    end

    function safe_stop_timer()
        tmr = getappdata(hFig,'roi_gui_timer');
        if isa(tmr,'timer') && isvalid(tmr)
            try, stop(tmr); delete(tmr); end %#ok<TRYNC>
        end
    end
end

% ---- Helpers (file-local) ------------------------------------------------

function update_traces(axTr, S, opts, ln, startSlider, winEdit, roiList)
% Read GUI controls
winSec = str2double(get(winEdit,'String'));
if isnan(winSec) || winSec <= 0, winSec = opts.PlotWindowSec; end

% Unwrap ring buffer -> linear arrays
[tt, YY] = ring_to_linear(S.trace_t, S.trace_means, S.trace_head, S.trace_capacity);
if isempty(tt) || all(~isfinite(tt))
    return;
end

% Window selection
tEnd = tt(end);
% Ensure slider has increasing bounds
set(startSlider,'Min',0, 'Max', max(tEnd, eps));
t0 = get(startSlider,'Value');
t0 = min(max(t0, 0), max(tEnd - winSec, 0));
set(startSlider,'Value', t0);

keep = (tt >= t0) & (tt <= (t0 + winSec));
if ~any(keep)
    % Fallback: show last handful of samples
    keep = max(1, numel(tt)-100):numel(tt);
end

ttw = tt(keep); YYw = YY(keep,:);

% Decimate for plotting
[ttw, YYw] = thin_for_plot(ttw, YYw, opts.MaxPlotPoints);

% Selected ROIs
sel = get(roiList,'Value'); if isempty(sel), sel = 1; end
sel = sel(sel >= 1 & sel <= size(YYw,2));  % guard

% Update line objects (hide unselected for speed)
for k = 1:numel(ln)
    if ismember(k, sel) && ~isempty(ttw)
        set(ln(k),'XData', ttw, 'YData', YYw(:,k), 'Visible','on');
    else
        set(ln(k),'Visible','off');
    end
end

% ---- Safe axis limits ----
% X limits
if isempty(ttw) || ~all(isfinite([ttw(1) ttw(end)]))
    % keep existing limits
else
    x1 = ttw(1); x2 = ttw(end);
    if ~(isfinite(x1) && isfinite(x2)) || (x2 <= x1)
        % enforce a tiny positive span
        span = max(1e-3, winSec*0.1);
        x2 = x1 + span;
    end
    try, xlim(axTr, [x1 x2]); end %#ok<TRYNC>
end

% Y limits
yv = YYw(:, sel);
yv = yv(isfinite(yv));
if ~isempty(yv)
    y1 = min(yv); y2 = max(yv);
    if y2 <= y1
        pad = max(1, abs(y1)*0.05);
        y1 = y1 - pad; y2 = y2 + pad;
    else
        pad = 0.05*(y2 - y1);
        y1 = y1 - pad; y2 = y2 + pad;
    end
    if isfinite(y1) && isfinite(y2) && (y2 > y1)
        try, ylim(axTr, [y1 y2]); end %#ok<TRYNC>
    end
end
end

function [tt, YY] = thin_for_plot(t, Y, maxN)
% Robust thinning that preserves endpoints and tolerates NaNs.
t = t(:);
if isempty(t) || numel(t) <= 1
    tt = t; YY = Y; return;
end
% Ensure strictly increasing numeric time
good = isfinite(t);
t  = t(good);
Y  = Y(good, :);
if isempty(t)
    tt = t; YY = Y; return;
end
n = numel(t);
if n <= maxN
    tt = t; YY = Y; return;
end
% Uniform pick including first/last
idx = unique([1, round(linspace(1, n, maxN)), n]);
tt  = t(idx);
YY  = Y(idx, :);
end

function [tt, YY] = ring_to_linear(tRing, yRing, head, cap)
% Convert ring buffer (cap×1, cap×K) to linear arrays in time order
if head <= 0 || all(isnan(tRing))
    tt = []; YY = [];
    return;
end
if head < cap && ~isnan(tRing(head+1))
    % wrapped (there is data after head)
end
idx = 1:cap;
valid = ~isnan(tRing);
if ~any(valid)
    tt = []; YY = []; return;
end
% Build order: (head-cap+1 ... head) modulo cap
order = [head+1:cap, 1:head];
order = order(valid(order));
tt = tRing(order);
YY = yRing(order, :);
% Ensure strictly increasing
[tt, order2] = sort(tt);
YY = YY(order2, :);
end

function S = get_user_state(vid)
S = struct();
try
    if isvalid(vid)
        Ud = vid.UserData;
        if ~isempty(Ud), S = Ud; end
    end
catch
end
end

function d = filldefaults(d, defaults)
f = fieldnames(defaults);
for i=1:numel(f)
    k = f{i};
    if ~isfield(d,k) || isempty(d.(k)), d.(k) = defaults.(k); end
end
end
