function [busXY, info] = exactRefine(cov, busXY, tree, opts)
%EXACTREFINE Final polish on the EXACT dwelling counts (dwelling basis only).
%
%   [busXY, info] = busLayout.exactRefine(cov, busXY, tree, opts)
%
%   WHY
%   correctLayout follows a smoothed dwelling density (addDwellings), because
%   exact counts give no usable gradient.  But a zone of 10-20 houses is only
%   ~100 m across, so the smoothing blurs dwellings across zone boundaries:
%   a zone can look right on the density map yet hold several dwellings too
%   many or too few.  This step fixes that by optimising the real counts.
%
%   HOW (pattern search, one bus at a time)
%   ---------------------------------------
%   score = same F as layoutScore, but with each zone's share = its EXACT
%           dwelling count / all dwellings.  Counting is cheap: every dwelling
%           point is given to its nearest bus (no raster needed).
%
%   step <- opts.refineStepFrac * D
%   repeat
%       for each bus 1..32:
%           try moving it by step in 8 directions (N, NE, E, ... ), each move
%           snapped to a free coverage pixel
%           take the first move that lowers the score and adds no crossing
%       if no bus could improve: halve step
%   until step < one pixel, or opts.refineMaxEvals score evaluations
%
%   A move only counts if it changes which bus some dwelling is nearest to,
%   so the search naturally works dwelling by dwelling at the end.

    if ~isfield(cov, 'dwellXY') || isempty(cov.dwellXY)
        info = struct('F', NaN, 'evals', 0, 'moves', 0); return
    end
    P = cov.dwellXY; M = size(P, 1);
    w = busLayout.errorWeights(tree, opts);
    nCross0 = busLayout.countCrossings(busXY, tree);
    taken = false(cov.N, 1);
    for k = 1:tree.n                              % pixels already holding a bus
        [~, j] = min((cov.pix(:, 1) - busXY(k, 1)).^2 + (cov.pix(:, 2) - busXY(k, 2)).^2);
        taken(j) = true;
    end

    dirs = [1 0; 1 1; 0 1; -1 1; -1 0; -1 -1; 0 -1; 1 -1];
    dirs = dirs ./ sqrt(sum(dirs.^2, 2));
    step = opts.refineStepFrac * cov.D;
    minStep = cov.pixelSize_km;
    F = scoreExact(busXY);
    F0 = F; evals = 1; moves = 0;

    while step >= minStep && evals < opts.refineMaxEvals
        improved = false;
        for b = tree.zoneIdx
            for dk = 1:size(dirs, 1)
                % candidate position: step along this direction, on a free pixel
                target = busXY(b, :) + step * dirs(dk, :);
                d2 = (cov.pix(:, 1) - target(1)).^2 + (cov.pix(:, 2) - target(2)).^2;
                d2(taken) = inf;
                [~, j] = min(d2);
                cand = busXY; cand(b, :) = cov.pix(j, :);
                if busLayout.countCrossings(cand, tree) > nCross0, continue; end
                Fc = scoreExact(cand); evals = evals + 1;
                if Fc < F - 1e-12
                    % accept: free the old pixel, take the new one
                    [~, jOld] = min((cov.pix(:, 1) - busXY(b, 1)).^2 + (cov.pix(:, 2) - busXY(b, 2)).^2);
                    taken(jOld) = false; taken(j) = true;
                    busXY = cand; F = Fc; moves = moves + 1; improved = true;
                    break
                end
            end
        end
        if ~improved, step = step / 2; end
    end
    info = struct('F', F, 'F0', F0, 'evals', evals, 'moves', moves);

    % ---- score with exact counts (same terms as layoutScore) -------------
    function s = scoreExact(Q)
        Z = Q(tree.zoneIdx, :);
        best = inf(M, 1); lab = ones(M, 1);
        for k2 = 1:size(Z, 1)
            dd = (P(:, 1) - Z(k2, 1)).^2 + (P(:, 2) - Z(k2, 2)).^2;
            c = dd < best; best(c) = dd(c); lab(c) = k2;
        end
        e = accumarray(lab, 1, [size(Z, 1) 1]) / M - tree.target;
        dv = busLayout.branchVectors(Q, tree);
        s = sum(w .* e.^2) + opts.lambda * mean(sum(dv.^2, 2)) / cov.D^2 + ...
            opts.mu * busLayout.turnPenalty(Q, tree, opts);
    end
end
