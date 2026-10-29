function [bestXY, info] = psoPolish(cov, seedXY, tree, opts)
%PSOPOLISH Optional particle-swarm polish of an already-corrected layout.
%
%   [busXY, info] = psoPolish(cov, seedXY, tree, opts)
%
%   Only worth using AFTER correctLayout.  In testing on six feeder-sized
%   areas it lowered F by 3-16% at about 4x the run time; a swarm started
%   from the raw graph layouts instead ended 5-6x worse than correctLayout.
%
%   HOW IT WORKS
%   ------------
%   Each particle is a complete layout: the 32 movable bus positions
%   (64 numbers).  Particle 1 starts exactly on seedXY; the others start on
%   seedXY plus random jitter of 1%, 3% or 10% of D, so the swarm explores
%   close to and a little further from the seed.
%
%   Every iteration each particle's velocity is updated as
%
%      v = w*v + c1*r1.*(ownBest - x) + c2*r2.*(swarmBest - x)
%
%   (inertia + pull towards the best layout this particle has seen + pull
%   towards the best layout any particle has seen; r1, r2 are random in
%   [0,1]).  Speed is capped at opts.psoVmaxFrac * D, positions are kept
%   inside the coverage's bounding box, and layouts are snapped onto
%   coverage pixels before scoring.
%
%   A swarm cannot repair a crossing the way correctLayout does, so instead
%   each crossing adds opts.psoCrossingPenalty to F - far more than any
%   crossing-free layout scores - which makes crossed layouts lose every
%   comparison.

    rng(opts.psoSeed);
    score = @(Xp) psoScore(Xp, seedXY, tree.zoneIdx, cov, tree, opts);
    nP = opts.psoParticles;
    mv = tree.zoneIdx;                           % movable rows
    lo = min(cov.pix, [], 1); hi = max(cov.pix, [], 1);
    vmax = opts.psoVmaxFrac * cov.D;

    X = zeros(numel(mv), 2, nP);
    for p = 1:nP
        if p == 1
            jitter = 0;
        else
            jitter = opts.psoJitterFrac(mod(p - 2, numel(opts.psoJitterFrac)) + 1) * cov.D;
        end
        X(:, :, p) = clampBox(seedXY(mv, :) + jitter * randn(numel(mv), 2), lo, hi);
    end
    V = zeros(size(X));

    f = zeros(nP, 1);
    for p = 1:nP, f(p) = score(X(:, :, p)); end
    pBest = X; pF = f;
    [gF, g] = min(pF); gBest = pBest(:, :, g);
    history = gF;

    for it = 1:opts.psoIterations
        for p = 1:nP
            r1 = rand(size(gBest)); r2 = rand(size(gBest));
            V(:, :, p) = opts.psoInertia * V(:, :, p) ...
                + opts.psoC1 * r1 .* (pBest(:, :, p) - X(:, :, p)) ...
                + opts.psoC2 * r2 .* (gBest - X(:, :, p));
            V(:, :, p) = min(max(V(:, :, p), -vmax), vmax);
            X(:, :, p) = clampBox(X(:, :, p) + V(:, :, p), lo, hi);
            fp = score(X(:, :, p));
            if fp < pF(p)
                pF(p) = fp; pBest(:, :, p) = X(:, :, p);
                if fp < gF, gF = fp; gBest = X(:, :, p); end
            end
        end
        history(end + 1) = gF; %#ok<AGROW>
        if opts.verbose && mod(it, 50) == 0
            fprintf('    PSO iteration %3d: best F = %.4e\n', it, gF);
        end
    end

    bestXY = seedXY; bestXY(mv, :) = gBest;
    bestXY = busLayout.snapToPixels(cov, bestXY);
    [info.F, z] = busLayout.layoutScore(cov, bestXY, tree, opts);
    info.sse = z.sse;
    info.history = history;
    info.crossings = busLayout.countCrossings(bestXY, tree);

end

function s = psoScore(Xp, seedXY, mv, cov, tree, opts)
% Score of one particle: F of its snapped layout plus the crossing penalty.
    particleXY = seedXY; particleXY(mv, :) = Xp;
    particleXY = busLayout.snapToPixels(cov, particleXY);
    s = busLayout.layoutScore(cov, particleXY, tree, opts) + ...
        opts.psoCrossingPenalty * busLayout.countCrossings(particleXY, tree);
end

function X = clampBox(X, lo, hi)
    X = min(max(X, lo), hi);
end
