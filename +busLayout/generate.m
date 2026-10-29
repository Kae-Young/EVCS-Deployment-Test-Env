function res = generate(cov, tree, opts)
%GENERATE Place the IEEE-33 buses over a coverage area.
%
%   res = generate(cov, tree, opts)
%
%   cov   coverage area   (coverageFromAddresses or coverageFromPolygon)
%   tree  feeder          (buildFeederTree)
%   opts  settings        (defaultOptions)
%
%   ALGORITHM
%   ---------
%     starts <- graphLayoutStarts      (up to 8 Kamada-Kawai drawings fitted
%                                       to the area, none with crossings)
%     for each start:
%         corrected <- correctLayout    (gradient descent on F, crossings
%                                       forbidden, sharp turns penalised)
%         if dwellings are counted and opts.useExactRefine:
%             corrected <- exactRefine(corrected)   (pattern search on the
%                                       EXACT dwelling counts)
%     best <- the layout with the lowest F (exact-count F when refined)
%     if opts.usePSO:  best <- psoPolish(best)  (then exactRefine again)
%
%   Refining every start, not just the best-looking one, matters: the
%   smoothed score used by correctLayout does not rank starts reliably once
%   exact counts are compared (in testing it lowered the worst bus's relative
%   deviation from 25% to 14% in one area).
%
%   RESULT FIELDS
%   -------------
%     res.busXY          33x2 bus positions (km, coverage frame)
%     res.lat/.lon   33x1 bus positions in degrees
%     res.nodeNo     33x1 IEEE node numbers (0 = substation)
%     res.zone       ny x nx image, 0 outside the coverage, otherwise the
%                    IEEE bus number (1..32) whose electrical zone it is
%     res.basis      'dwellings' (cov from addDwellings) or 'area'
%     res.share      32x1 share of buses 1..32: EXACT dwelling share
%                    (dwellings in the zone / all dwellings), or area share
%     res.count      32x1 dwellings in each zone (dwelling basis only)
%     res.nDwellings total dwellings in the coverage (dwelling basis only)
%     res.areaShare  32x1 share of the land area in each zone
%     res.target     32x1 load share of buses 1..32
%     res.err        share - target
%     res.maxAbsErr  worst bus error (fraction; x100 for percentage points)
%     res.meanRelErr mean |err| / target
%     res.maxRelErr  max  |err| / target   (worst bus relative to its own target)
%     res.crossings  number of crossing line pairs (0 expected)
%     res.sharpestTurn_deg   smallest parent-bus-child angle in the layout
%     res.lineLength_km      total feeder line length
%     res.F, res.parts       objective value and its terms
%     res.startTag   which start won;  res.startsF  F of every start
%     res.runtime_s

    t0 = tic;
    starts = busLayout.graphLayoutStarts(cov, tree, opts);
    if opts.verbose
        fprintf('  %d starting layouts (Kamada-Kawai variants without crossings)\n', numel(starts));
    end

    refine = opts.useExactRefine && isfield(cov, 'dwellXY') && ~isempty(cov.dwellXY);
    best = []; startsF = zeros(numel(starts), 1);
    for s = 1:numel(starts)
        [busXY, info] = busLayout.correctLayout(cov, starts(s).busXY, tree, opts);
        if refine
            hist = info.history; it = info.iterations;
            [busXY, info] = busLayout.exactRefine(cov, busXY, tree, opts);
            info.history = hist; info.iterations = it;
        end
        startsF(s) = info.F;
        if opts.verbose
            fprintf('    start %d (%s): F = %.4e after %3d iterations\n', ...
                s, starts(s).tag, info.F, info.iterations);
        end
        if isempty(best) || info.F < best.F
            best = struct('busXY', busXY, 'F', info.F, 'tag', starts(s).tag, 'history', info.history);
        end
    end

    if opts.usePSO
        if opts.verbose, fprintf('  PSO polish ...\n'); end
        [busXY, info] = busLayout.psoPolish(cov, best.busXY, tree, opts);
        if info.F < best.F
            best.busXY = busXY; best.F = info.F;
        end
    end

    if refine && opts.usePSO          % PSO works on the smoothed score: re-polish
        busXY = busLayout.exactRefine(cov, best.busXY, tree, opts);
        best.busXY = busXY;
    end

    % ---- Package the result.
    busXY = best.busXY;
    [F, z, parts] = busLayout.layoutScore(cov, busXY, tree, opts);
    res.busXY = busXY;
    [res.lat, res.lon] = busLayout.toLatLon(cov, busXY);
    res.nodeNo = tree.nodeNo;
    res.zone = zeros(size(cov.mask));
    res.zone(cov.idx) = tree.nodeNo(tree.zoneIdx(z.label));
    res.target = tree.target;
    res.areaShare = z.areaShare;
    if isfield(z, 'exactShare')
        % Dwelling basis: report the EXACT dwelling counts (the optimiser
        % worked on the smoothed density, see addDwellings).
        res.basis = 'dwellings';
        res.count = z.count;
        res.nDwellings = sum(z.count);
        res.droppedDwellings = cov.droppedDwellings;
        res.largestStack = cov.largestStack;
        res.share = z.exactShare;
    else
        res.basis = 'area';
        res.share = z.share;
    end
    res.err = res.share - res.target;
    res.maxAbsErr  = max(abs(res.err));
    res.meanRelErr = mean(abs(res.err) ./ res.target);
    res.maxRelErr  = max(abs(res.err) ./ res.target);
    res.crossings = busLayout.countCrossings(busXY, tree);
    [~, ang] = busLayout.turnPenalty(busXY, tree, opts);
    res.sharpestTurn_deg = min(ang(tree.triples(:, 4) == 0));
    d = busLayout.branchVectors(busXY, tree);
    res.lineLength_km = sum(sqrt(sum(d.^2, 2)));
    res.F = F; res.parts = parts;
    res.startTag = best.tag; res.startsF = startsF;
    res.history = best.history;
    res.runtime_s = toc(t0);

    if opts.verbose
        fprintf(['  best start %s: relative deviation max %.1f%% / mean %.1f%%, ' ...
                 'worst bus %.2f pp, crossings %d, sharpest turn %.0f deg, %.1f s\n'], ...
                 res.startTag, 100 * res.maxRelErr, 100 * res.meanRelErr, ...
                 100 * res.maxAbsErr, res.crossings, res.sharpestTurn_deg, res.runtime_s);
    end
end
