function [Qbest, info] = correctLayout(cov, Q0, tree, opts)
%CORRECTLAYOUT Nudge buses until zone areas match load shares, without ever
%introducing a line crossing and while discouraging sharp turns.
%
%   [Q, info] = correctLayout(cov, Q0, tree, opts)
%
%   Q0    33x2 starting layout (km), already on coverage pixels
%   Q     best layout found
%   info  .F .sse .iterations .history (score per iteration) .crossings
%
%   ONE ITERATION
%   -------------
%   1. VORONOI   give every pixel to its nearest bus; measure each zone's
%                share and its error e = share - target.          (voronoiZones)
%   2. GRADIENT  work out which way each bus should move to reduce
%                    F = SSE + lambda*LINE + mu*TURN                (layoutScore)
%                - SSE part:  areaGradient (zones that are too big give area
%                  to neighbours that are too small; by default each
%                  miss is weighed against the size of its bus)
%                - LINE part: pulls each bus a little towards the buses it is
%                  connected to (keeps lines short)
%                - TURN part: turnPenalty gradient (opens up sharp angles)
%   3. STEP      move every bus downhill.  Each bus gets its OWN step size
%                (the Adam method, see below), because the gradient for
%                buses far from the worst zones is tiny: with one shared
%                step size those buses would move less than a pixel, the
%                snap would undo the move, and they would never improve.
%                Then snap all buses back onto distinct coverage pixels.
%   4. NO CROSSINGS  if the move created a crossing, halve the moves of the
%                buses on the crossing lines and try again; a bus whose move
%                has been halved below 10% of its size stays where it was.
%                If crossings remain after opts.repairTries attempts, the
%                whole step is rejected.  So the crossing count can never go
%                above the starting layout's (zero for our starts).
%   5. KEEP BEST keep the layout if F went down.  After opts.stepDecayEvery
%                iterations in a row without improvement, the step size is
%                reduced (x opts.stepDecay); after opts.patience without
%                improvement the search stops.
%
%   ADAM (Kingma & Ba, 2015), in one paragraph
%   ------------------------------------------
%   Instead of moving by "step * gradient", each coordinate of each bus moves
%   by roughly "step * sign of its recent average gradient".  m is a running
%   average of the gradient (momentum: smooths out the jittery raster
%   gradient) and v a running average of its square (its typical size).
%   Dividing m by sqrt(v) normalises every bus to about the same distance
%   per iteration, whatever the size of its gradient.  The (1 - beta^t)
%   terms correct the averages for starting at zero.

    Q = Q0;
    nCross0 = countCrossings(Q, tree);           % never allowed to increase
    step = opts.stepFrac * cov.D;                % km per iteration (initially)
    movable = tree.zoneIdx;                      % the substation stays put

    m = zeros(size(Q)); v = zeros(size(Q));      % Adam running averages
    b1 = opts.adamBeta1; b2 = opts.adamBeta2;

    [F, z] = layoutScore(cov, Q, tree, opts);
    Qbest = Q; Fbest = F; zbest = z;
    history = F; stall = 0; it = 0;

    while it < opts.maxIter
        it = it + 1;

        % ---- 2. Gradient of F.
        G = areaGradient(cov, Q, tree, z, opts);
        d = Q(tree.br(:, 2), :) - Q(tree.br(:, 1), :);         % child - parent
        Gline = zeros(size(Q));                                 % d(LINE)/dQ
        nb = size(tree.br, 1);
        for k = 1:nb
            Gline(tree.br(k, 2), :) = Gline(tree.br(k, 2), :) + 2 * d(k, :);
            Gline(tree.br(k, 1), :) = Gline(tree.br(k, 1), :) - 2 * d(k, :);
        end
        Gline = Gline / (nb * cov.D^2);
        [~, ~, Gturn] = turnPenalty(Q, tree, opts);
        G = G + opts.lambda * Gline + opts.mu * Gturn;
        G(1, :) = 0;                                            % substation fixed

        % ---- 3. Adam step, then snap to pixels.
        m = b1 * m + (1 - b1) * G;
        v = b2 * v + (1 - b2) * G.^2;
        mHat = m / (1 - b1^it);
        vHat = v / (1 - b2^it);
        target = Q;
        target(movable, :) = Q(movable, :) - step * mHat(movable, :) ./ (sqrt(vHat(movable, :)) + 1e-12);
        target = snapToPixels(cov, target);

        % ---- 4. Repair crossings by shrinking the offending moves.
        prop = target;
        frac = ones(tree.n, 1);                  % fraction of its move each bus keeps
        for tryNo = 1:opts.repairTries
            [nc, bad] = countCrossings(prop, tree);
            if nc <= nCross0, break; end
            bad = bad(any(prop(bad, :) ~= Q(bad, :), 2));   % only buses that moved
            if isempty(bad), break; end
            frac(bad) = frac(bad) / 2;
            frac(frac < 0.1) = 0;                % give up on that bus's move
            prop(bad, :) = Q(bad, :) + frac(bad) .* (target(bad, :) - Q(bad, :));
            prop = snapToPixels(cov, prop);
        end
        if countCrossings(prop, tree) > nCross0
            prop = Q;                            % reject the whole step
        end
        Q = prop;

        % ---- 5. Score and keep the best.
        [F, z] = layoutScore(cov, Q, tree, opts);
        history(end + 1) = F; %#ok<AGROW>
        if F < Fbest - 1e-10
            Qbest = Q; Fbest = F; zbest = z; stall = 0;
        else
            stall = stall + 1;
            if mod(stall, opts.stepDecayEvery) == 0
                step = step * opts.stepDecay;
            end
            if stall >= opts.patience, break; end
        end
    end

    info.F = Fbest;
    info.sse = zbest.sse;
    info.iterations = it;
    info.history = history;
    info.crossings = countCrossings(Qbest, tree);
end
