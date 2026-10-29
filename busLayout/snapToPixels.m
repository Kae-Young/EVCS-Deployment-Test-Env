function Q = snapToPixels(cov, Q)
%SNAPTOPIXELS Move every bus onto the centre of a coverage pixel, no two
%buses on the same pixel.
%
%   Q = snapToPixels(cov, Q)      Q is 33x2 (km); all rows are snapped.
%
%   Why snap?
%   * It keeps every bus inside the coverage area (a bus in the sea or
%     outside the suburb makes no sense).
%   * Two buses on the same spot would split nothing between them: one of
%     them would get a zero-area zone and the gradient could never separate
%     them.  So each bus takes the nearest pixel that is still free.
%
%   Buses are processed in index order (substation first), each claiming its
%   nearest free pixel.

    taken = false(cov.N, 1);
    for k = 1:size(Q, 1)
        d2 = (cov.pix(:, 1) - Q(k, 1)).^2 + (cov.pix(:, 2) - Q(k, 2)).^2;
        d2(taken) = inf;                     % pixels already used by a bus
        [~, j] = min(d2);
        taken(j) = true;
        Q(k, :) = cov.pix(j, :);
    end
end
