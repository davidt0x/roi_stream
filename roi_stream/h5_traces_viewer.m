function h5_traces_viewer(h5path)
% Minimal viewer for HDF5 traces.
assert(exist(h5path,'file')==2, 'File not found: %s', h5path);

% --- Load datasets ---
info    = h5info(h5path);
t       = h5read(h5path,'/time');      t = t(:);
F       = h5read(h5path,'/roi/means'); % N x K
circles = h5read(h5path,'/roi/circles');
K = size(circles,1); N = numel(t);

% Optional ΔF/F (define DFF safely so callbacks never see it undefined)
hasDff = hasDatasetPath(h5path,'/roi/dff');
DFF    = [];
if hasDff
    try
        DFF = h5read(h5path,'/roi/dff');
    catch
        hasDff = false; DFF = [];
    end
end

% Root attrs & resolution
attrs = read_root_attrs(info);
WH = [];
if isfield(attrs,'resolution')
    WH = double(attrs.resolution(:)');
elseif isfield(attrs,'format')
    tok = regexp(string(attrs.format),'_(\d+)x(\d+)','tokens','once');
    if ~isempty(tok), WH = [str2double(tok{1}) str2double(tok{2})]; end
end
if isempty(WH), WH = [max(circles(:,1))*1.1, max(circles(:,2))*1.1]; end
W = WH(1); H = WH(2);

% --- UI ---
hFig = figure('Name',['H5 Viewer: ' h5path],'NumberTitle','off','Color','w',...
              'Units','normalized','Position',[0.08 0.08 0.84 0.80]);

metaStr = buildMetaSummary(attrs, N, K);
uicontrol('Style','text','Units','normalized','Position',[0.01 0.95 0.98 0.04],...
    'String',metaStr,'BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold');

% ROI map (left)
axMap = axes('Parent',hFig,'Units','normalized','Position',[0.04 0.26 0.34 0.64]);
axis(axMap,'ij'); axis(axMap,'image'); box(axMap,'on'); hold(axMap,'on');
xlim(axMap,[0.5 W+0.5]); ylim(axMap,[0.5 H+0.5]); title(axMap,'ROI map');
colormap(axMap, gray(256)); set(axMap,'YDir','reverse');

theta = linspace(0,2*pi,100);
colors = lines(max(K,1));
roiLines = gobjects(K,1);
for k=1:K
    xc=circles(k,1); yc=circles(k,2); r=circles(k,3);
    x = xc + r*cos(theta); y = yc + r*sin(theta);
    roiLines(k) = plot(axMap,x,y,'LineWidth',0.9,'Color',[0.6 0.6 0.6]);
end

% ROI selection list (bigger)
uicontrol('Style','text','Units','normalized','Position',[0.04 0.22 0.34 0.03],...
    'String','Selected ROI(s):','BackgroundColor','w','HorizontalAlignment','left');
roiList = uicontrol('Style','listbox','Units','normalized','Position',[0.04 0.04 0.34 0.18],...
    'String',arrayfun(@(k)sprintf('ROI %d',k),1:K,'UniformOutput',false),...
    'Max',max(2,K),'Min',0,'Value',1:min(10,K),...
    'Callback',@(~,~)onRoiSelectionChange());

% Trace axes (right)
axPlot = axes('Parent',hFig,'Units','normalized','Position',[0.42 0.28 0.56 0.62]);
grid(axPlot,'on'); box(axPlot,'on'); hold(axPlot,'on');
title(axPlot,'Traces'); xlabel(axPlot,'Time (s)'); ylabel(axPlot,'Mean intensity (a.u.)');

% Controls (right, under plot)
uicontrol('Style','text','Units','normalized','Position',[0.42 0.22 0.08 0.03],...
    'String','Signal:','BackgroundColor','w','HorizontalAlignment','left');
if hasDff, sigOpts = {'Raw means','ΔF/F'}; else, sigOpts = {'Raw means'}; end
sigPopup = uicontrol('Style','popupmenu','Units','normalized','Position',[0.50 0.22 0.12 0.035],...
    'String',sigOpts,'Value',1,'Callback',@(~,~)refreshPlot());

uicontrol('Style','text','Units','normalized','Position',[0.64 0.22 0.10 0.03],...
    'String','Window (s):','BackgroundColor','w','HorizontalAlignment','left');
winEdit = uicontrol('Style','edit','Units','normalized','Position',[0.74 0.22 0.08 0.035],...
    'String','60','Callback',@(~,~)refreshPlot());

uicontrol('Style','text','Units','normalized','Position',[0.42 0.16 0.08 0.03],...
    'String','Start (s):','BackgroundColor','w','HorizontalAlignment','left');
startSlider = uicontrol('Style','slider','Units','normalized','Position',[0.50 0.165 0.40 0.025],...
    'Min',t(1),'Max',t(end),'Value',max(t(1),t(end)-60),'Callback',@(~,~)refreshPlot());

uicontrol('Style','pushbutton','Units','normalized','Position',[0.92 0.22 0.06 0.035],...
    'String','Export CSV','Callback',@(~,~)doExport());

% Init
onRoiSelectionChange();  % highlights + plot

% ---- nested helpers ----
    function onRoiSelectionChange()
        sel = get(roiList,'Value'); if isempty(sel), sel = 1; end
        % Highlight selection on map
        for kk=1:K
            if ismember(kk, sel)
                set(roiLines(kk),'LineWidth',2.4,'Color',colors(mod(kk-1,size(colors,1))+1,:));
            else
                set(roiLines(kk),'LineWidth',0.9,'Color',[0.6 0.6 0.6]);
            end
        end
        refreshPlot();
    end

    function refreshPlot()
        cla(axPlot); hold(axPlot,'on'); grid(axPlot,'on');
        useDff = (hasDff && get(sigPopup,'Value')==2);
        Y = F; ylab = 'Mean intensity (a.u.)';
        if useDff, Y = DFF; ylab = 'ΔF/F'; end
        ylabel(axPlot, ylab);

        winSec = str2double(get(winEdit,'String')); if isnan(winSec)||winSec<=0, winSec = t(end)-t(1); end
        t0 = get(startSlider,'Value'); t0 = min(max(t0,t(1)), max(t(end)-winSec,t(1)));
        set(startSlider,'Value',t0);
        keep = t>=t0 & t<=t0+winSec; if ~any(keep), keep = true(size(t)); end

        sel = get(roiList,'Value'); if isempty(sel), sel = 1; end
        [tt, YY] = thin_for_plot(t(keep), Y(keep, sel), 8000);
        for i=1:numel(sel)
            plot(axPlot, tt, YY(:,i), 'LineWidth', 1.1, 'Color', colors(mod(sel(i)-1,size(colors,1))+1,:));
        end
        xlim(axPlot,[tt(1) tt(end)]);
        if all(isfinite(YY(:)))
            yl = [min(YY(:)), max(YY(:))]; if yl(1)==yl(2), yl = yl + [-1 1]; end
            dy = 0.05*max(1, yl(2)-yl(1)); ylim(axPlot,[yl(1)-dy yl(2)+dy]);
        end
        title(axPlot, sprintf('%s | t=%.2f–%.2f s | %d ROI(s)', ylab, tt(1), tt(end), numel(sel)));
        drawnow limitrate
    end

    function doExport()
        sel = get(roiList,'Value'); if isempty(sel), sel = 1; end
        useDff = (hasDff && get(sigPopup,'Value')==2);
        if useDff
            Y = DFF(:,sel);
        else
            Y = F(:,sel);
        end
        T = array2table([t, Y], 'VariableNames', ...
            [{'time_s'}, arrayfun(@(k) sprintf('%s_roi_%d', tern(useDff,'dff','mean'), k), sel, 'UniformOutput', false)]);
        [p,f] = fileparts(h5path);
        out = fullfile(p, sprintf('%s_export_%s.csv', f, tern(useDff,'dff','means')));
        try
            writetable(T, out);
            msgbox(sprintf('Saved: %s', out), 'Export','help');
        catch ME
            errordlg(sprintf('Export failed:\n%s', ME.message), 'Export');
        end
    end
end

% -------- utilities --------
function tf = hasDatasetPath(h5path, dsPath)
tf = false; try, h5info(h5path, dsPath); tf = true; catch, end
end

function attrs = read_root_attrs(info)
attrs = struct();
try
    for i = 1:numel(info.Attributes)
        nm = info.Attributes(i).Name; val = info.Attributes(i).Value;
        if isstring(val) || ischar(val), attrs.(nm) = char(string(val));
        elseif isnumeric(val), attrs.(nm) = val;
        else, attrs.(nm) = val;
        end
    end
catch
end
end

function s = buildMetaSummary(a, N, K)
parts = {};
if isfield(a,'adaptor'), parts{end+1} = sprintf('Adaptor: %s', string(a.adaptor)); end
if isfield(a,'format'),  parts{end+1} = sprintf('Format: %s', string(a.format)); end
if isfield(a,'resolution'), parts{end+1} = sprintf('Res: %dx%d', a.resolution(1), a.resolution(2)); end
if isfield(a,'start_iso8601'), parts{end+1} = sprintf('Start: %s', a.start_iso8601); end
if isfield(a,'end_iso8601'),   parts{end+1} = sprintf('End: %s', a.end_iso8601);   end
if isfield(a,'avg_fps'),       parts{end+1} = sprintf('Avg FPS: %.2f', a.avg_fps); end
if isfield(a,'frames_dropped'),parts{end+1} = sprintf('Dropped: %d', a.frames_dropped); end
parts{end+1} = sprintf('Rows: %d', N); parts{end+1} = sprintf('ROIs: %d', K);
s = strjoin(parts, ' | ');
end

function [tt, YY] = thin_for_plot(t, Y, maxN)
n = numel(t);
if n<=maxN, tt=t; YY=Y; return; end
step = ceil(n/maxN); idx = 1:step:n; tt = t(idx); YY = Y(idx,:);
end

function out = tern(cond, a, b)
if cond, out = a; else, out = b; end
end
