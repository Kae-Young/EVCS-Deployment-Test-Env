function ctx = buildContext(cov, tree, busXY, demand, roads, branches, opts)
%BUILDCONTEXT Precompute everything the PSO objective needs.
%
%   ctx = evcs.buildContext(cov, tree, busXY, demand, roads, branches, opts)
%
%   cov       coverage (busLayout)
%   tree      busLayout.buildFeederTree
%   busXY     33x2 bus layout (res.busXY from busLayout.generate, or a
%             perturbed copy from evcs.perturbLayout)
%   demand    evcs.seedDemand
%   roads     evcs.buildRoads ([] = straight-line distances)
%   branches  networkData33Bus branch table
%   opts      evcs.defaultOptions()
%
%   WHAT IS PRECOMPUTED
%   1. Candidate sites.  With roads: every road point inside the coverage
%      (road points are <= opts.roadStep_km apart).  Without: every coverage
%      pixel centre.  A station the PSO puts anywhere on the map is SNAPPED
%      to the nearest candidate (proposal 3.3.2).  The snap is a lookup
%      table over the whole raster grid, so it costs nothing per evaluation.
%   2. Distance from every candidate to every demand node, Dcd (C x K).
%      With roads it is the SHORTEST-PATH ROAD DISTANCE: from the demand
%      node's dwelling, straight to its nearest road point (the driveway),
%      then along the road graph to the candidate.  Without roads it is the
%      straight-line distance.
%   3. The bus each candidate connects to: the bus whose electrical zone
%      contains it (nearest loaded bus, the same rule voronoiZones uses for
%      the zones).  This is the link between the geographic and the
%      distribution layer: a station's load is added to that bus.
%   4. The base-case power flow (no EVCS) and the reference values used to
%      normalise the four objectives (see evcs.defaultOptions).

    t0 = tic;
    % ---- 1. Candidates.
    [ny, nx] = size(cov.mask);
    h = cov.pixelSize_km;
    if ~isempty(roads)
        ix = floor(roads.xy(:, 1) / h) + 1; iy = floor(roads.xy(:, 2) / h) + 1;
        on = ix >= 1 & ix <= nx & iy >= 1 & iy <= ny;
        inside = false(size(ix));
        inside(on) = cov.mask(sub2ind([ny nx], iy(on), ix(on)));
        candNode = find(inside);
        if isempty(candNode)
            error('evcs:buildContext:noRoads', 'No road points lie inside the coverage area.');
        end
        candXY = roads.xy(candNode, :);
    else
        candNode = [];
        candXY = cov.pix;
    end
    C = size(candXY, 1);

    % ---- Snap table: nearest candidate of every grid pixel centre.
    [gx, gy] = meshgrid(((1:nx) - 0.5) * h, ((1:ny) - 0.5) * h);
    g = [gx(:) gy(:)];
    snap = zeros(size(g, 1), 1);
    chunk = max(1, floor(2e7 / C));
    for a = 1:chunk:size(g, 1)
        b = min(a + chunk - 1, size(g, 1));
        d2 = (g(a:b, 1) - candXY(:, 1)').^2 + (g(a:b, 2) - candXY(:, 2)').^2;
        [~, snap(a:b)] = min(d2, [], 2);
    end

    % ---- 2. Candidate -> demand distances.
    K = size(demand.xy, 1);
    if ~isempty(roads)
        % nearest road point of every demand node (its "driveway")
        dn = zeros(K, 1); access = zeros(K, 1);
        for k = 1:K
            [d2, dn(k)] = min(sum((roads.xy - demand.xy(k, :)).^2, 2));
            access(k) = sqrt(d2);
        end
        Dnet = distances(roads.G, dn, candNode);          % K x C
        Dcd = Dnet.' + access.';                            % C x K
        distanceType = 'road';
    else
        Dcd = sqrt((candXY(:, 1) - demand.xy(:, 1)').^2 + (candXY(:, 2) - demand.xy(:, 2)').^2);
        distanceType = 'euclidean';
    end

    % ---- 3. Bus of each candidate (nearest loaded bus = its electrical zone).
    Z = busXY(tree.zoneIdx, :);
    d2 = (candXY(:, 1) - Z(:, 1)').^2 + (candXY(:, 2) - Z(:, 2)').^2;
    [~, zk] = min(d2, [], 2);
    candBus = tree.zoneIdx(zk); candBus = candBus(:);       % bus INDEX (1..33)

    % ---- 4. Network, base case and references.
    net = evcs.buildNetwork(tree, branches, opts);
    pf0 = evcs.powerFlow(net);

    ctx.cov = cov; ctx.tree = tree; ctx.busXY = busXY; ctx.demand = demand;
    ctx.roads = roads; ctx.distanceType = distanceType;
    ctx.candXY = candXY; ctx.candNode = candNode; ctx.C = C;
    ctx.snap = snap; ctx.grid = struct('nx', nx, 'ny', ny, 'h', h);
    ctx.Dcd = Dcd; ctx.candBus = candBus;
    ctx.w = demand.weight(:)'; ctx.NT = demand.NT;
    ctx.net = net; ctx.pf0 = pf0;
    ctx.PL0 = pf0.PL_kW; ctx.AVDI0 = pf0.AVDI;
    if isempty(opts.Dref_km), ctx.Dref = cov.D; else, ctx.Dref = opts.Dref_km; end
    ctx.rhoRef = demand.NT / opts.totalCapacity_kVA;
    ctx.bounds = [min(cov.pix, [], 1); max(cov.pix, [], 1)];   % [xmin ymin; xmax ymax]
    ctx.opts = opts;

    if opts.verbose
        fprintf('  Context: %d candidate sites, %d demand nodes, %s distances, %.1f s\n', ...
            C, K, distanceType, toc(t0));
        fprintf('  Base case (no EVCS): PL = %.2f kW, AVDI = %.4f, Vmin = %.4f p.u. at bus %d\n', ...
            pf0.PL_kW, pf0.AVDI, pf0.Vmin, pf0.VminBus);
    end
end
