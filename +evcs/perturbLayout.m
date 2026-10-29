function busXY = perturbLayout(busXY, cov, magFrac, seed)
%PERTURBLAYOUT Jumble the bus layout: move every bus in its own random direction.
%
%   busXY = evcs.perturbLayout(busXY, cov, magFrac, seed)
%
%   busXY    33x2 bus layout (km, coverage frame); row 1 = substation
%   cov      coverage (for its size)
%   magFrac  how far each bus moves, as a fraction of the coverage's width
%            D = sqrt(coverage area): every loaded bus (1..32) moves exactly
%            magFrac * D km
%   seed     random seed: the directions are drawn from their own stream, so
%            the same seed always gives the same jumble
%
%   Each bus gets an independent direction, uniform on 0..360 deg.  The
%   substation stays where it was placed: it carries no load and owns no
%   electrical zone, so moving it would change nothing.  Buses are not
%   held inside the coverage area; one pushed outside still owns the
%   coverage pixels nearest to it.
%
%   This tests proposal assumption 5 (where the zone boundaries are): the
%   geographic layer - coverage, dwellings, EV demand, roads - is untouched,
%   but the electrical zones, and hence which bus each candidate site feeds,
%   change.  Rebuild the context with the jumbled layout:
%       ctxP = evcs.buildContext(cov, tree, evcs.perturbLayout(res.busXY, cov, 0.05, 1), ...
%                                demand, roads, branches, opts);

    rs = RandStream('mt19937ar', 'Seed', seed);
    n = size(busXY, 1) - 1;
    theta = 2 * pi * rand(rs, n, 1);
    r = magFrac * cov.D;
    busXY(2:end, :) = busXY(2:end, :) + r * [cos(theta) sin(theta)];
end
