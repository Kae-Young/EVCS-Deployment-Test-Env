function cov = coverageFromAddresses(lat, lon, seedLatLon, nDwellings, opts)
%COVERAGEFROMADDRESSES Feeder-sized coverage area around a point.
%
%   cov = coverageFromAddresses(lat, lon, seedLatLon, nDwellings, opts)
%
%   lat, lon     address coordinates (e.g. G-NAF points, aliases removed)
%   seedLatLon   [lat lon] of the centre of the study area
%   nDwellings   how many addresses the feeder should serve
%                (tree.dwellings = 874 for IEEE-33 at 5 kVA ADMD)
%   opts         defaultOptions()
%
%   HOW THE AREA IS BUILT
%   ---------------------
%   1. Take the nDwellings addresses closest to the seed point.  This gives a
%      roughly round patch of suburb holding exactly the dwelling count the
%      feeder can supply.
%   2. Convert degrees to local kilometres (flat-earth approximation: fine
%      for areas a few km across).
%   3. Rasterise: lay a grid of square pixels over the patch and mark every
%      pixel that contains an address.
%   4. "Inflate" each marked pixel by a disc of opts.bufferRadius_km, so each
%      dwelling claims its block of land rather than a single point.
%   5. Morphological closing (inflate then deflate by opts.closeRadius_km)
%      to bridge streets and small parks between houses.
%   6. finishCoverage: fill enclosed holes, apply the optional coastline clip
%      and keep the largest connected piece.
%   7. addDwellings: the chosen addresses become the dwellings that zone
%      shares count (so each zone's share is its share of these dwellings).
%
%   The result is a struct describing the raster - see finishCoverage.

    lat = lat(:); lon = lon(:);
    ok = isfinite(lat) & isfinite(lon);
    lat = lat(ok); lon = lon(ok);

    % ---- 1-2. Local km coordinates centred on the seed, then the nearest N.
    lat0 = seedLatLon(1); lon0 = seedLatLon(2);
    [kx, ky] = busLayout.kmPerDegree(lat0);
    X = [(lon - lon0) * kx, (lat - lat0) * ky];
    [~, order] = sort(X(:, 1).^2 + X(:, 2).^2);
    n = min(nDwellings, numel(order));
    addr = X(order(1:n), :);
    addrLat = lat(order(1:n)); addrLon = lon(order(1:n));

    % ---- 3. Pixel grid over the patch (shifted so all coordinates >= 0).
    grid = busLayout.rasterGrid(addr, opts);
    addr = addr - grid.offset;
    pixelSize_km = grid.pixelSize_km;
    nx = grid.nx; ny = grid.ny;
    ix = min(max(floor(addr(:, 1) / pixelSize_km) + 1, 1), nx);   % column of each address
    iy = min(max(floor(addr(:, 2) / pixelSize_km) + 1, 1), ny);   % row (row 1 = south)
    occupied = false(ny, nx);
    occupied(sub2ind([ny nx], iy, ix)) = true;

    % ---- 4. Buffer each address.
    rb = max(1, round(opts.bufferRadius_km / pixelSize_km));
    mask = dilate(occupied, rb);

    % ---- 5. Close gaps.  Pad first so the deflate step does not eat the
    %      edges of the grid, then crop the padding off again.
    rc = max(1, round(opts.closeRadius_km / pixelSize_km));
    padded = false(ny + 2 * rc, nx + 2 * rc);
    padded(rc + 1:rc + ny, rc + 1:rc + nx) = mask;
    padded = erode(dilate(padded, rc), rc);
    mask = padded(rc + 1:rc + ny, rc + 1:rc + nx);

    % ---- 6. Holes, clip, largest piece, pixel list.
    geo = struct('lat0', lat0, 'lon0', lon0, 'kx', kx, 'ky', ky, 'offset', grid.offset);
    cov = busLayout.finishCoverage(mask, pixelSize_km, geo, opts);
    cov.addr = addr;                     % kept for plotting

    % ---- 7. Zone shares count these dwellings.
    cov = busLayout.addDwellings(cov, addrLat, addrLon, opts);
end


function out = dilate(mask, r)
% Binary dilation by a disc of radius r pixels: a pixel becomes true if any
% true pixel lies within r of it.  Done with a convolution so no Image
% Processing Toolbox is needed.
    out = conv2(double(mask), disc(r), 'same') > 0.5;
end

function out = erode(mask, r)
% Binary erosion by a disc: a pixel stays true only if the WHOLE disc around
% it is true (the convolution then equals the number of pixels in the disc).
    d = disc(r);
    out = conv2(double(mask), d, 'same') > sum(d(:)) - 0.5;
end

function d = disc(r)
    [xx, yy] = meshgrid(-r:r, -r:r);
    d = double(xx.^2 + yy.^2 <= r^2);
end
