function cov = addDwellings(cov, lat, lon, opts)
%ADDDWELLINGS Make zone shares count dwellings instead of area.
%
%   cov = busLayout.addDwellings(cov, lat, lon, opts)
%
%   cov       coverage area (coverageFromPolygon / coverageFromAddresses)
%   lat, lon  dwelling coordinates (e.g. G-NAF addresses inside the area,
%             aliases removed)
%   opts      defaultOptions()  (uses opts.dwellingSmooth_km)
%
%   WHY
%   The goal is that each bus's electrical zone captures the same share of
%   the area's DWELLINGS as that bus carries of the feeder's load (dwellings
%   stand in for load).  Without this step every pixel counts the same, i.e.
%   zone shares are shares of land area.
%
%   WHAT IT ADDS TO cov
%     cov.dwellXY       M x 2 dwelling positions (km, coverage frame).  Used to
%                       count dwellings per zone EXACTLY (voronoiZones).
%     cov.weight        N x 1 dwellings per coverage pixel, SMOOTHED (see below).
%                       Used for the optimiser's shares and gradient.
%     cov.totalWeight   sum(cov.weight) = number of dwellings M
%     cov.basis         'dwellings'  (finishCoverage sets 'area')
%     cov.nDwellings    M  (dwellings inside the coverage)
%     cov.droppedDwellings  dwellings left out because they lie outside the
%                       coverage area (see below)
%     cov.largestStack  most dwellings sharing one exact location.  G-NAF lists
%                       every unit of a block at the same point; a Voronoi zone
%                       cannot split such a stack, so a stack bigger than a
%                       bus's target makes that bus's share unreachable.
%
%   WHY SMOOTH?
%   Dwellings are points.  If every point sat in a single pixel, a zone's
%   dwelling count would only change when its boundary jumped over a house,
%   so the gradient (how a bus should move) would be zero almost everywhere
%   and spiky at houses.  Spreading each dwelling as a small Gaussian blob
%   (standard deviation opts.dwellingSmooth_km, ~25 m, about one house lot)
%   gives a smooth dwelling DENSITY the optimiser can follow.  The blur is
%   "normalised" to the coverage mask, so no dwelling leaks outside the area
%   and the total stays exactly M.  Reported results always use the exact
%   point counts, not the smoothed ones.
%
%   Dwellings that fall just outside the coverage pixels (e.g. on the edge of
%   a drawn polygon) are counted in the nearest coverage pixel.  Dwellings
%   further than opts.bufferRadius_km (or 2 pixels, if larger) from the
%   coverage are left out: they belong to land that is not in the study area
%   (e.g. a separate cluster that finishCoverage dropped), and piling them onto
%   the edge would hand one zone a large, fake group of dwellings.

    lat = lat(:); lon = lon(:);
    ok = isfinite(lat) & isfinite(lon);
    xy = busLayout.fromLatLon(cov, lat(ok), lon(ok));

    % ---- Nearest coverage pixel of every dwelling (brute force; few points).
    [ny, nx] = size(cov.mask);
    h = cov.pixelSize_km;
    pixOf = zeros(size(xy, 1), 1); dist = zeros(size(xy, 1), 1);
    for k = 1:size(xy, 1)
        [d2, pixOf(k)] = min((cov.pix(:, 1) - xy(k, 1)).^2 + (cov.pix(:, 2) - xy(k, 2)).^2);
        dist(k) = sqrt(d2);
    end
    keep = dist <= max(opts.bufferRadius_km, 2 * h);
    xy = xy(keep, :); pixOf = pixOf(keep);
    M = size(xy, 1);
    if M == 0
        error('busLayout:addDwellings:none', 'No dwellings lie inside the coverage area.');
    end

    % ---- Raw counts on the grid, then normalised Gaussian smoothing.
    counts = zeros(ny, nx);
    counts(cov.idx) = accumarray(pixOf, 1, [cov.N 1]);
    s = max(opts.dwellingSmooth_km / h, 0.5);            % sigma in pixels
    r = ceil(3 * s);
    g = exp(-((-r:r) / s).^2 / 2); g = g / sum(g);        % 1-D Gaussian (separable)
    blur = @(A) conv2(g, g, A, 'same');
    num = blur(counts);                                   % blurred dwellings
    den = blur(double(cov.mask));                         % how much of each blob stays inside
    dens = zeros(ny, nx);
    dens(cov.mask) = num(cov.mask) ./ max(den(cov.mask), 1e-12);
    w = dens(cov.idx);
    w = w * (M / sum(w));                                 % total exactly M

    cov.dwellXY = xy;
    cov.weight = w;
    cov.totalWeight = M;
    cov.basis = 'dwellings';
    cov.nDwellings = M;
    cov.droppedDwellings = nnz(~keep);
    [~, ~, g] = unique(round(xy * 1e5), 'rows');   % same point to ~1 cm
    cov.largestStack = max(accumarray(g, 1));
end
