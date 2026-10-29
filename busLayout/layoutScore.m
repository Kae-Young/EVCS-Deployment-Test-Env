function [F, z, parts] = layoutScore(cov, Q, tree, opts)
%LAYOUTSCORE Objective value of a layout (lower is better).
%
%   [F, z, parts] = layoutScore(cov, Q, tree, opts)
%
%        F = SSE + lambda * LINE + mu * TURN
%
%   SSE   sum over the 32 zones of w_k * (area share - load share)^2, with
%         the weights w_k from errorWeights.  By default (errorMode
%         'balanced') each squared miss is divided by the bus's target
%         share, so small buses are not neglected in favour of big ones.
%         This is the actual goal.  E.g. SSE = 1e-4 means a typical zone is
%         off by about 0.2 percentage points.
%   LINE  mean over the 32 lines of (length / D)^2, D = sqrt(coverage area).
%         Dividing by D makes it independent of how big the area is.  It
%         stops the correction stretching lines across the map to fix areas.
%   TURN  turnPenalty: how far turns and splits fall short of their limits.
%
%   Crossings are not part of F: correctLayout simply never accepts a layout
%   with more crossings than it started with.  (psoPolish adds a large fixed
%   penalty per crossing instead, because a swarm cannot "undo" a move.)
%
%   parts holds each term separately for reporting.

    z = voronoiZones(cov, Q, tree);
    d = Q(tree.br(:, 2), :) - Q(tree.br(:, 1), :);
    parts.sse  = sum(errorWeights(tree, opts) .* z.err.^2);
    parts.line = mean(sum(d.^2, 2)) / cov.D^2;
    parts.turn = turnPenalty(Q, tree, opts);
    F = parts.sse + opts.lambda * parts.line + opts.mu * parts.turn;
end
