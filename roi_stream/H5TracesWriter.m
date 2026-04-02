classdef H5TracesWriter < handle
    properties
        path        % char file path
        rows = 0    % total rows written
        K           % number of ROIs
        chunkFrames % HDF5 chunk length (rows)
        hasDff = false
    end

    methods
        function obj = H5TracesWriter(path, circles, meta, chunkFrames)
            % path: char/string or [] to autogen "traces_YYYYMMDD_HHMMSS.h5"
            % circles: Nx3 double [xc yc r]
            % meta: struct with fields (any subset is fine):
            %   adaptor, device_id, format, resolution([W H]),
            %   start_iso8601 (autofilled if missing)
            % chunkFrames: rows per chunk (default 240)

            if nargin < 4 || isempty(chunkFrames), chunkFrames = 240; end
            obj.chunkFrames = max(1, chunkFrames);

            if ~exist('path','var') || isempty(path)
                ts = string(datetime('now','TimeZone','local','Format','yyyyMMdd_HHmmss'));
                path = fullfile(pwd, "traces_" + ts + ".h5");
            end
            obj.path = char(path);

            if ~isfield(meta,'start_iso8601') || isempty(meta.start_iso8601)
                meta.start_iso8601 = char(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZ'));
            end

            % ROI geometry
            if isempty(circles) || size(circles,2) ~= 3
                error('circles must be Nx3 [xc yc r].');
            end
            obj.K = size(circles,1);

            % Fresh file
            if exist(obj.path,'file'), delete(obj.path); end

            % Datasets (extendible)
            h5create(obj.path, '/time',      [Inf 1],    'Datatype','double', 'ChunkSize',[obj.chunkFrames 1]);
            h5create(obj.path, '/roi/means', [Inf obj.K],'Datatype','single', 'ChunkSize',[obj.chunkFrames obj.K]);

            % Static datasets
            h5create(obj.path, '/roi/circles', size(circles), 'Datatype','double');
            h5write (obj.path, '/roi/circles', circles);

            % Root attributes
            meta.created_with = 'roi_stream matlab';
            fns = fieldnames(meta);
            for i = 1:numel(fns)
                h5writeatt(obj.path, '/', fns{i}, meta.(fns{i}));
            end
        end

        function append(obj, tvec, means, dff)
            % Append rows to /time and /roi/means (and /roi/dff if provided)
            if isempty(tvec), return; end
            n = numel(tvec);
            if size(means,1) ~= n
                error('means must have n rows to match tvec.');
            end
            start = obj.rows + 1;
            h5write(obj.path, '/time',      tvec(:),       [start 1], [n 1]);
            h5write(obj.path, '/roi/means', single(means), [start 1], [n obj.K]);

            if nargin >= 4 && ~isempty(dff)
                if ~obj.hasDff
                    h5create(obj.path, '/roi/dff', [Inf obj.K], 'Datatype','single', 'ChunkSize',[obj.chunkFrames obj.K]);
                    obj.hasDff = true;
                end
                h5write(obj.path, '/roi/dff', single(dff), [start 1], [n obj.K]);
            end

            obj.rows = obj.rows + n;
        end

        function finalize(obj, summary)
            % Write closing attributes (e.g., end_iso8601, frames_seen, dropped, elapsed_sec, avg_fps)
            if ~isfield(summary,'end_iso8601') || isempty(summary.end_iso8601)
                summary.end_iso8601 = char(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZ'));
            end
            summary.rows = uint64(obj.rows);
            fns = fieldnames(summary);
            for i = 1:numel(fns)
                h5writeatt(obj.path, '/', fns{i}, summary.(fns{i}));
            end
        end
    end
end
