function sol = pso(ctx, M, seed, opts)
%PSO Place M charging stations with particle swarm optimisation.
%
%   sol = evcs.pso(ctx, M)            seed 1, ctx.opts
%   sol = evcs.pso(ctx, M, seed)
%   sol = evcs.pso(ctx, M, seed, opts)
%
%   Each particle is one complete placement: a 1 x 2M vector of station
%   coordinates [x1 y1 ... xM yM] in km.  Stations may be anywhere in the
%   coverage's bounding box; evaluate() snaps them to the nearest road
%   point.  Standard global-best PSO with Clerc-Kennedy constriction:
%
%     v <- w v + c1 r1 (pbest - x) + c2 r2 (gbest - x),  |v| <= vmax
%     x <- x + v,   clamped to the box (velocity zeroed on the wall)
%
%   Particles start on randomly chosen candidate sites, so every start is
%   feasible.  The run uses its own random stream (seed), so it is
%   repeatable and safe inside parfor.  Stops after opts.psoIterations or
%   opts.psoStall iterations without gbest improving.
%
%   OUTPUT
%     sol.x       best position (unsnapped), sol.F best objective
%     sol.m       evcs.evaluate metrics of the best position
%     sol.history gbest F per iteration, sol.iterations, sol.evals

    if nargin < 3 || isempty(seed), seed = 1; end
    if nargin < 4 || isempty(opts), opts = ctx.opts; end
    rs = RandStream('mt19937ar', 'Seed', seed);

    nP = opts.psoParticles; D = 2 * M;
    lo = repmat(ctx.bounds(1, :), 1, M);
    hi = repmat(ctx.bounds(2, :), 1, M);
    span = hi - lo;
    vmax = opts.psoVmaxFrac * span;

    % ---- Initialise on random candidate sites, random velocities.
    X = zeros(nP, D);
    for p = 1:nP
        c = randi(rs, ctx.C, M, 1);
        X(p, :) = reshape(ctx.candXY(c, :)', 1, D);
    end
    V = (2 * rand(rs, nP, D) - 1) .* vmax;

    Fp = zeros(nP, 1);
    for p = 1:nP, Fp(p) = evcs.evaluate(ctx, X(p, :)); end
    pbest = X; pbestF = Fp;
    [gF, gi] = max(pbestF); gbest = pbest(gi, :);

    hist = zeros(opts.psoIterations, 1);
    stall = 0; evals = nP;
    w = opts.psoInertia; c1 = opts.psoC1; c2 = opts.psoC2;
    for it = 1:opts.psoIterations
        r1 = rand(rs, nP, D); r2 = rand(rs, nP, D);
        V = w * V + c1 * r1 .* (pbest - X) + c2 * r2 .* (gbest - X);
        V = max(min(V, vmax), -vmax);
        X = X + V;
        out = X < lo | X > hi;
        X = max(min(X, hi), lo);
        V(out) = 0;

        for p = 1:nP
            Fp(p) = evcs.evaluate(ctx, X(p, :));
        end
        evals = evals + nP;
        better = Fp > pbestF;
        pbest(better, :) = X(better, :); pbestF(better) = Fp(better);
        [bF, bi] = max(pbestF);
        if bF > gF + 1e-12
            gF = bF; gbest = pbest(bi, :); stall = 0;
        else
            stall = stall + 1;
        end
        hist(it) = gF;
        if stall >= opts.psoStall, break; end
    end

    [sol.F, sol.m] = evcs.evaluate(ctx, gbest);
    sol.x = gbest; sol.M = M; sol.seed = seed;
    sol.history = hist(1:it); sol.iterations = it; sol.evals = evals;
end
