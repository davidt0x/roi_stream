function f16 = to_uint16_gray(frame)
% Convert an image (uint8/uint16/single/double, gray or RGB) to uint16 grayscale [0..65535]
%
% No toolboxes required. Handles both 0..1 and 0..255/65535 inputs.

if ndims(frame) == 3
    % ----- RGB/Color -----
    switch class(frame)
        case 'uint8'
            % Y ≈ 0.299 R + 0.587 G + 0.114 B, in 0..255 → scale to 0..65535
            R = double(frame(:,:,1)); G = double(frame(:,:,2)); B = double(frame(:,:,3));
            Y = 0.2989360213*R + 0.5870430745*G + 0.1140209043*B;  % 0..255
            f16 = uint16(round(Y * 257));  % 255→65535

        case 'uint16'
            R = double(frame(:,:,1)); G = double(frame(:,:,2)); B = double(frame(:,:,3));
            Y = 0.2989360213*R + 0.5870430745*G + 0.1140209043*B;  % 0..65535
            Y = min(65535, max(0, Y));
            f16 = uint16(round(Y));

        otherwise  % single/double
            mx = max(frame(:));
            R = double(frame(:,:,1)); G = double(frame(:,:,2)); B = double(frame(:,:,3));
            if mx <= 1.0
                Y = 0.2989360213*R + 0.5870430745*G + 0.1140209043*B;  % 0..1
                f16 = uint16(round(Y * 65535));
            elseif mx <= 255
                Y = 0.2989360213*R + 0.5870430745*G + 0.1140209043*B;  % 0..255
                f16 = uint16(round(Y * 257));
            else
                Y = 0.2989360213*R + 0.5870430745*G + 0.1140209043*B;  % assume 0..65535
                Y = min(65535, max(0, Y));
                f16 = uint16(round(Y));
            end
    end
else
    % ----- Single-channel -----
    switch class(frame)
        case 'uint16'
            f16 = frame;
        case 'uint8'
            f16 = uint16(frame) * 257;   % 255→65535
        otherwise  % single/double
            mx = max(frame(:));
            if mx <= 1.0
                f16 = uint16(round(double(frame) * 65535));
            elseif mx <= 255
                f16 = uint16(round(double(frame) * 257));
            else
                f16 = uint16(round(min(65535, max(0, double(frame)))));
            end
    end
end
end
