function test_roi_h5_writer()
%TEST_ROI_H5_WRITER Verify HDF5 trace output without camera or DAQ hardware.

ensure_roi_stream_path(fileparts(fileparts(mfilename('fullpath'))));

tmp = fullfile(tempdir, 'test_roi_writer.h5');
if exist(tmp, 'file')
    delete(tmp);
end

circles = [10 20 5; 40 50 6];
meta = struct('adaptor', "synthetic", 'format', "test", 'resolution', int32([64 64]));
h5w = H5TracesWriter(tmp, circles, meta, 4);

tvec = [0.0; 0.1; 0.2];
means = single([1 2; 3 4; 5 6]);
h5w.append(tvec, means, []);
h5w.finalize(struct('frames_seen', uint64(3), 'avg_fps', 10));

tread = h5read(tmp, '/time');
mread = h5read(tmp, '/roi/means');
cread = h5read(tmp, '/roi/circles');

assert(isequal(size(tread), [3 1]), 'Expected 3 time samples.');
assert(isequal(size(mread), [3 2]), 'Expected 3x2 mean matrix.');
assert(isequal(size(cread), [2 3]), 'Expected 2 ROI circles.');
assert(all(abs(double(tread(:)) - tvec) < 1e-9), 'Unexpected time vector.');
assert(all(abs(double(mread(:)) - double(means(:))) < 1e-6), 'Unexpected means matrix.');

disp('✅ test_roi_h5_writer passed');
end
