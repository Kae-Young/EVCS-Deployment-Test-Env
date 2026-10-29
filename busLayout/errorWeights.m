function w = errorWeights(tree, opts)
%ERRORWEIGHTS Weight of each zone's error in the area objective.
%
%   w = errorWeights(tree, opts)       32x1, one weight per zone
%
%   The area part of the objective is   SSE = sum_k  w_k * e_k^2,
%   e_k = area share - target share of zone k, t_k = target share,
%   tbar = mean target = 1/32.  The tbar factors keep SSE on the same scale
%   in every mode (all modes agree when all targets are equal), so the
%   lambda and mu weights mean the same thing whichever mode is used.
%
%   opts.errorMode = 'balanced'   (default)
%       w_k = tbar / t_k        ->  SSE = tbar * sum_k e_k^2 / t_k
%       This is the chi-squared form: each squared miss is divided by the
%       size of the bus once.  A small bus's miss counts for more than a big
%       bus's miss of the same size in points, but a big bus is still held
%       to a sensible standard in points.
%
%   opts.errorMode = 'absolute'
%       w_k = 1                 ->  SSE = sum_k e_k^2
%       Every percentage point counts the same, so the optimiser works
%       hardest on the big buses and small buses can end up with zones
%       40-80% too big or small.
%
%   opts.errorMode = 'relative'
%       w_k = (tbar / t_k)^2    ->  SSE = tbar^2 * sum_k (e_k / t_k)^2
%       Purely relative.  Sounds ideal, but it makes errors on the two
%       11.3% buses almost free (weight 0.08), so they drift by 2-4 points
%       and drag the layout into poor shapes with sharp turns.
%
%   TEST RESULTS (six 874-dwelling areas, Townsville / Cairns / Ayr)
%                   worst bus relative dev.   average relative dev.
%       absolute          33.1 %                    8.4 %
%       relative          31.0 %                    8.6 %
%       balanced          18.8 %                    5.8 %
%   (averages over the six areas; all modes: 0 crossings)

    tbar = mean(tree.target);
    switch lower(opts.errorMode)
        case 'balanced'
            w = tbar ./ tree.target;
        case 'absolute'
            w = ones(size(tree.target));
        case 'relative'
            w = (tbar ./ tree.target).^2;
        otherwise
            error('errorWeights:mode', ...
                'opts.errorMode must be ''balanced'', ''absolute'' or ''relative''.');
    end
end
