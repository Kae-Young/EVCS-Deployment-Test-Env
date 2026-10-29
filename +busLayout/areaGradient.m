function G = areaGradient(cov, busXY, tree, z, opts)
%AREAGRADIENT Gradient of SSE = sum(w .* (share - target).^2) with respect
%to the positions of the 32 loaded buses (w from errorWeights: by default
%tbar/target, so a small bus's error weighs more than a big bus's).
%
%   G = areaGradient(cov, busXY, tree, z, opts)     G is 33x2 (row 1 = 0)
%
%   THE IDEA
%   --------
%   Take two neighbouring zones i and j.  Their shared boundary is the
%   perpendicular bisector between buses i and j.  If bus i moves a little
%   (by delta), that boundary slides, and the area that changes hands between
%   the two zones is
%
%        dA_i = (L / d) * (m - x_i) . delta
%
%   where L = length of the shared boundary, d = distance between the two
%   buses, m = midpoint of the shared boundary, x_i = position of bus i.
%   (Moving bus i towards the boundary pushes the boundary away from it, so
%   zone i grows by half the distance moved, along the whole boundary.)
%   Whatever zone i gains on that boundary, zone j loses.
%
%   Applying the chain rule to SSE = sum_k w_k e_k^2 (e_k = A_k/A_tot - t_k)
%   gives, for every pair of neighbouring zones (i, j), with p_k = w_k e_k
%   (the "pressure" of zone k):
%
%        dSSE/dx_i += 2 (p_i - p_j) (L/d) (m - x_i) / A_tot
%        dSSE/dx_j += 2 (p_j - p_i) (L/d) (m - x_j) / A_tot
%
%   With the default weights a small bus's zone pushes harder for the same
%   error in points, because that error is a bigger fraction of it.
%
%   Reading it: if zone i is under more pressure than j (p_i > p_j), the gradient
%   points from bus i towards the shared boundary, so descending it moves
%   bus i AWAY from the boundary and hands area over to j.  Pairs whose
%   errors are equal exert no pull at all.
%
%   ON THE RASTER
%   -------------
%   Shared boundaries are found by comparing each pixel with its right and
%   upper neighbour: where the zone labels differ, that pixel edge is part of
%   the boundary between those two zones.  Counting those edges gives L
%   (times the pixel size, times pi/4 because a staircase of pixel edges is
%   longer than the straight line it approximates), and averaging their
%   positions gives m.

    [ny, nx] = size(cov.mask);
    nz = numel(tree.zoneIdx);
    Z = busXY(tree.zoneIdx, :);

    % Zone label image: 0 outside the coverage, 1..32 inside.
    L = zeros(ny, nx);
    L(cov.idx) = z.label;

    % ---- Horizontal neighbours (pixel (r,c) vs (r,c+1)).  The shared pixel
    %      edge sits at x = c*pixelSize_km, y = (r - 0.5)*pixelSize_km.
    A = L(:, 1:end - 1); B = L(:, 2:end);
    hit = A > 0 & B > 0 & A ~= B;
    [r, c] = find(hit);
    a1 = A(hit); b1 = B(hit);
    mx1 = c * cov.pixelSize_km;  my1 = (r - 0.5) * cov.pixelSize_km;

    % ---- Vertical neighbours (pixel (r,c) vs (r+1,c)).  Shared edge at
    %      x = (c - 0.5)*pixelSize_km, y = r*pixelSize_km.
    A = L(1:end - 1, :); B = L(2:end, :);
    hit = A > 0 & B > 0 & A ~= B;
    [r, c] = find(hit);
    a2 = A(hit); b2 = B(hit);
    mx2 = (c - 0.5) * cov.pixelSize_km;  my2 = r * cov.pixelSize_km;

    % ---- Collect every boundary edge under an unordered pair key (i < j).
    p = busLayout.errorWeights(tree, opts) .* z.err;      % weighted error ("pressure")
    zi = min([a1; a2], [b1; b2]);
    zj = max([a1; a2], [b1; b2]);
    mx = [mx1; mx2]; my = [my1; my2];
    G = zeros(size(busXY));
    if isempty(zi), return; end
    key = (zi - 1) * nz + zj;                    % unique id for pair (zi, zj)
    nKey = nz * nz;
    cnt = accumarray(key, 1,  [nKey 1]);         % boundary length in pixel edges
    sx  = accumarray(key, mx, [nKey 1]);         % for the boundary midpoint
    sy  = accumarray(key, my, [nKey 1]);

    pairs = find(cnt > 0);
    Gz = zeros(nz, 2);
    for q = pairs'
        i = floor((q - 1) / nz) + 1;             % decode key -> (i, j)
        j = q - (i - 1) * nz;
        Lij = cnt(q) * cov.pixelSize_km * opts.staircase;   % shared boundary length
        m   = [sx(q) sy(q)] / cnt(q);               % its midpoint
        d   = max(norm(Z(j, :) - Z(i, :)), 1e-9);   % distance between buses
        w   = 2 * (p(i) - p(j)) * Lij / d / cov.area;
        Gz(i, :) = Gz(i, :) + w * (m - Z(i, :));
        Gz(j, :) = Gz(j, :) - w * (m - Z(j, :));
    end
    G(tree.zoneIdx, :) = Gz;
end
