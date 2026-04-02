function roiDir = ensure_roi_stream_path(baseDir)
%ENSURE_ROI_STREAM_PATH Add the shared roi_stream library folder to MATLAB path.

if nargin < 1
    baseDir = '';
end

% Live Editor / cell execution can report temporary helper paths via
% mfilename('fullpath'); resolve robustly from several anchors.
searchRoots = {};
if ~isempty(baseDir)
    if exist(baseDir, 'dir') == 7
        searchRoots{end+1} = baseDir; %#ok<AGROW>
    elseif exist(baseDir, 'file') == 2
        searchRoots{end+1} = fileparts(baseDir); %#ok<AGROW>
    end
end
searchRoots{end+1} = fileparts(mfilename('fullpath')); %#ok<AGROW>
searchRoots{end+1} = pwd; %#ok<AGROW>

[roiDir, tried] = find_roi_stream_dir(searchRoots);
if isempty(roiDir)
    error('roi_stream library folder not found. Tried:%s', tried);
end

if ~contains(path, roiDir)
    addpath(roiDir);
end
end

function [roiDir, tried] = find_roi_stream_dir(searchRoots)
roiDir = '';
triedDirs = {};

for i = 1:numel(searchRoots)
    root = searchRoots{i};
    if isempty(root) || exist(root, 'dir') ~= 7
        continue;
    end

    current = root;
    while true
        candidate = fullfile(current, 'roi_stream');
        triedDirs{end+1} = candidate; %#ok<AGROW>
        if exist(candidate, 'dir') == 7
            roiDir = candidate;
            tried = '';
            return;
        end

        parent = fileparts(current);
        if strcmp(parent, current)
            break;
        end
        current = parent;
    end
end

if isempty(triedDirs)
    tried = sprintf('\n  <none>');
else
    tried = sprintf('\n  %s', strjoin(unique(triedDirs, 'stable'), '\n  '));
end
end
