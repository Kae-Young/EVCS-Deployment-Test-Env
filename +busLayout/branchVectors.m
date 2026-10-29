function d = branchVectors(busXY, tree)
%BRANCHVECTORS Vector along every feeder line, from parent bus to child bus.
%
%   d = busLayout.branchVectors(busXY, tree)     d is 32x2 [dx dy] (km),
%   one row per line in tree.br.  Line lengths are vecnorm(d, 2, 2).
    d = busXY(tree.br(:, 2), :) - busXY(tree.br(:, 1), :);
end
