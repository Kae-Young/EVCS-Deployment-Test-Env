function cov = finishCoverage(mask, pixelSize_km, geo, opts)
%FINISHCOVERAGE Shared last steps for building a coverage raster.
%
%   cov = finishCoverage(mask, pixelSize_km, geo, opts)
%
%   1. Fill holes: any patch of non-coverage completely surrounded by
%      coverage (a park, a lake in the middle of the suburb) is added in.
%   2. Clip: if opts.clipLat/clipLon is given (e.g. a coastline polygon),
%      remove every pixel whose centre is outside it.
%   3. Keep only the largest connected piece, so the feeder area is one
%      continuous region.
%   4. List the coverage pixels and record how to convert km <-> degrees.
%
%   COVERAGE STRUCT FIELDS
%   ----------------------
%     cov.mask     ny x nx logical grid; row 1 = southern edge, column 1 =
%                  western edge (plot with "axis xy")
%     cov.pixelSize_km     pixel size (km)
%     cov.idx      linear indices of coverage pixels inside cov.mask
%     cov.pix      N x 2 [x y] centres of the coverage pixels (km)
%     cov.N        number of coverage pixels
%     cov.area     coverage area (km^2) = N * pixelSize_km^2
%     cov.D        sqrt(area) - the length scale used for step sizes and
%                  for making the line-length penalty scale-free
%     cov.geo      origin and scale for km <-> lat/lon (see toLatLon)

    [ny, nx] = size(mask);

    % ---- 1. Fill holes.  Label the NON-coverage pixels; any non-coverage
    %      component that touches the grid border is real outside, every other
    %      component is an enclosed hole.
    [bgLab, nBg] = labelComponents(~mask);
    border = unique([bgLab(1, :) bgLab(end, :) bgLab(:, 1)' bgLab(:, end)']);
    border = border(border > 0);
    holes = ~mask & ~ismember(bgLab, border) & bgLab > 0;
    mask = mask | holes;
    if nBg == 0, mask(:) = true; end

    % ---- 2. Optional clip polygon (degrees -> km in the same frame).
    if ~isempty(opts.clipLat)
        PX = (opts.clipLon(:) - geo.lon0) * geo.kx - geo.offset(1);
        PY = (opts.clipLat(:) - geo.lat0) * geo.ky - geo.offset(2);
        [CX, CY] = meshgrid(((1:nx) - 0.5) * pixelSize_km, ((1:ny) - 0.5) * pixelSize_km);
        mask = mask & inpolygon(CX, CY, PX, PY);
    end

    % ---- 3. Largest connected component.
    [lab, nLab] = labelComponents(mask);
    if nLab == 0
        error('finishCoverage:empty', 'Coverage area is empty.');
    end
    sizes = accumarray(lab(lab > 0), 1, [nLab 1]);
    [~, biggest] = max(sizes);
    mask = lab == biggest;

    % ---- 4. Pixel list.
    cov.mask = mask;
    cov.pixelSize_km = pixelSize_km;
    cov.idx  = find(mask);
    [iy, ix] = ind2sub([ny nx], cov.idx);
    cov.pix  = [(ix - 0.5) * pixelSize_km, (iy - 0.5) * pixelSize_km];
    cov.N    = numel(cov.idx);
    cov.area = cov.N * pixelSize_km^2;
    cov.D    = sqrt(cov.area);
    cov.geo  = geo;
end


function [lab, n] = labelComponents(mask)
% 4-connected component labelling by breadth-first flood fill (stands in for
% bwlabel, so no Image Processing Toolbox is needed).  lab is 0 outside the
% mask and 1..n inside, one label per connected piece.
    [ny, nx] = size(mask);
    lab = zeros(ny, nx);
    n = 0;
    queue = zeros(numel(mask), 1);
    for start = find(mask)'
        if lab(start) > 0, continue; end
        n = n + 1;
        lab(start) = n;
        queue(1) = start; head = 1; tail = 1;
        while head <= tail
            p = queue(head); head = head + 1;
            c = floor((p - 1) / ny) + 1;     % column of linear index p
            r = p - (c - 1) * ny;            % row of linear index p
            % the four edge-sharing neighbours of pixel (r, c)
            nb = [r - 1 c; r + 1 c; r c - 1; r c + 1];
            for k = 1:4
                rr = nb(k, 1); cc = nb(k, 2);
                if rr >= 1 && rr <= ny && cc >= 1 && cc <= nx
                    q = rr + (cc - 1) * ny;
                    if mask(q) && lab(q) == 0
                        lab(q) = n;
                        tail = tail + 1; queue(tail) = q;
                    end
                end
            end
        end
    end
end
