function z = voronoiZones(cov, busXY, tree)
%VORONOIZONES Raster Voronoi diagram: give every coverage pixel to its nearest bus.
%
%   z = voronoiZones(cov, busXY, tree)
%
%   cov   coverage struct (coverageFromAddresses / coverageFromPolygon)
%   busXY     33x2 bus positions in km (row 1 = substation, ignored here)
%   tree  buildFeederTree()
%
%   WHY A RASTER?
%   A true Voronoi diagram is unbounded and has to be clipped to an irregular
%   coverage boundary - fiddly and slow.  Instead every pixel simply looks up
%   its nearest bus.  A zone's share is then the sum of its pixels' weights
%   (cov.weight) over the total: pixel AREA by default, or the (smoothed)
%   number of DWELLINGS per pixel once addDwellings has been applied.  This
%   works for any boundary shape (coastlines, holes, odd shapes).
%
%   OUTPUT
%     z.label    N x 1, zone number (1..32) of each coverage pixel; zone k
%                belongs to bus index tree.zoneIdx(k), i.e. IEEE bus k
%     z.share    32 x 1, each zone's share of the total weight (area or
%                smoothed dwellings) - what the optimiser works on
%     z.areaShare  32 x 1, each zone's share of the land area
%     z.count    32 x 1, EXACT number of dwellings in each zone (dwelling
%                basis only; each dwelling point goes to its nearest bus)
%     z.exactShare 32 x 1, z.count / total dwellings (dwelling basis only)
%     z.err      32 x 1, share - target   (positive = zone too big)
%     z.sse      sum(err.^2)              (unweighted; layoutScore applies
%                                          the errorWeights for the objective)
%     z.maxAbs   max |err|                (worst bus, as a fraction)
%     z.meanRel  mean |err| / target      (typical error relative to target)
%     z.maxRel   max  |err| / target      (worst bus relative to its target)

    Z = busXY(tree.zoneIdx, :);                 % positions of the 32 loaded buses
    nz = size(Z, 1);

    % Nearest-bus search by brute force: for each bus, the squared distance
    % from every pixel; keep the running minimum.  32 passes over ~40 000
    % pixels is fast and needs no toolbox (knnsearch would also work).
    best = inf(cov.N, 1);
    z.label = ones(cov.N, 1);
    for k = 1:nz
        d2 = (cov.pix(:, 1) - Z(k, 1)).^2 + (cov.pix(:, 2) - Z(k, 2)).^2;
        closer = d2 < best;
        best(closer) = d2(closer);
        z.label(closer) = k;
    end

    if isfield(cov, 'weight')
        z.share = accumarray(z.label, cov.weight, [nz 1]) / cov.totalWeight;
    else                                     % coverage built before weights existed
        z.share = accumarray(z.label, 1, [nz 1]) / cov.N;
    end
    z.areaShare = accumarray(z.label, 1, [nz 1]) / cov.N;

    % Exact dwelling counts: every dwelling point to its nearest bus.
    if isfield(cov, 'dwellXY') && ~isempty(cov.dwellXY)
        bestD = inf(size(cov.dwellXY, 1), 1);
        lab = ones(size(cov.dwellXY, 1), 1);
        for k = 1:nz
            d2 = (cov.dwellXY(:, 1) - Z(k, 1)).^2 + (cov.dwellXY(:, 2) - Z(k, 2)).^2;
            closer = d2 < bestD;
            bestD(closer) = d2(closer);
            lab(closer) = k;
        end
        z.count = accumarray(lab, 1, [nz 1]);
        z.exactShare = z.count / size(cov.dwellXY, 1);
    end
    z.err     = z.share - tree.target;
    z.sse     = sum(z.err.^2);
    z.maxAbs  = max(abs(z.err));
    z.meanRel = mean(abs(z.err) ./ tree.target);
    z.maxRel  = max(abs(z.err) ./ tree.target);
end
