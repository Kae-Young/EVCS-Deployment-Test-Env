function [F, m] = evaluate(ctx, x)
%EVALUATE Score one EVCS placement.
%
%   F      = evcs.evaluate(ctx, x)
%   [F, m] = evcs.evaluate(ctx, x)
%
%   x     1 x 2M station positions [x1 y1 x2 y2 ...] in km (coverage frame),
%         anywhere on the map - they are snapped to the nearest candidate
%         site (road point) first
%   F     combined objective, to be MAXIMISED (proposal 3.3.1):
%            F = w1*PL0/PL + w2*AVDI0/AVDI + w3*Dref/Davg + w4*rhoRef/rho
%   m     struct with every metric (only built when asked for)
%
%   STEPS
%   1. Snap each station to its nearest candidate site.
%   2. Each demand node uses the station with the shortest (road) distance
%      DN.  Davg = sum(customers * DN) / NT.
%   3. Station capacities S_i: totalCapacity/M each ('equal'), or in
%      proportion to customers served ('demand').
%   4. rho = max_i N_i / S_i  (customers per kVA at the busiest station).
%      NB the proposal's rho = sum_i N_i / S_i equals M*NT/Stotal for ANY
%      layout under equal sizing (sum_i N_i = NT), so it cannot guide the
%      search; opts.rhoMode = 'sum' reproduces it for comparison.
%   5. Each station is a constant-power load S_i at the bus of its
%      electrical zone; a forward-backward sweep gives PL and AVDI.

    o = ctx.opts;
    M = numel(x) / 2;
    P = reshape(x, 2, M)';

    % ---- 1. Snap (grid lookup; points off the grid are clamped to it).
    g = ctx.grid;
    ix = min(max(floor(P(:, 1) / g.h) + 1, 1), g.nx);
    iy = min(max(floor(P(:, 2) / g.h) + 1, 1), g.ny);
    c = ctx.snap(iy + (ix - 1) * g.ny);

    % ---- 2. Nearest station of every demand node.
    [DN, near] = min(ctx.Dcd(c, :), [], 1);
    Davg = max(sum(ctx.w .* DN) / ctx.NT, 1e-6);
    Ni = accumarray(near(:), ctx.w(:), [M 1]);

    % ---- 3. Capacities.
    switch o.sizing
        case 'equal',  S = repmat(o.totalCapacity_kVA / M, M, 1);
        case 'demand', S = o.totalCapacity_kVA * Ni / ctx.NT;
        otherwise, error('evcs:evaluate:sizing', 'Unknown sizing "%s".', o.sizing);
    end

    % ---- 4. Demand concentration.
    used = S > 0;
    switch o.rhoMode
        case 'max', rho = max(Ni(used) ./ S(used));
        case 'sum', rho = sum(Ni(used) ./ S(used));
        otherwise, error('evcs:evaluate:rho', 'Unknown rhoMode "%s".', o.rhoMode);
    end
    rho = max(rho, 1e-12);

    % ---- 5. Power flow with the stations as loads.
    bus = ctx.candBus(c);
    addP = accumarray(bus, S * o.evcsPF, [ctx.net.nBus 1]);
    addQ = accumarray(bus, S * sqrt(max(0, 1 - o.evcsPF^2)), [ctx.net.nBus 1]);
    pf = evcs.powerFlow(ctx.net, addP, addQ);

    f = [ctx.PL0 / pf.PL_kW, ctx.AVDI0 / pf.AVDI, ctx.Dref / Davg, ctx.rhoRef / rho];
    F = sum(o.weights .* f);

    if nargout > 1
        m.F = F; m.f = f;
        m.PL_kW = pf.PL_kW; m.AVDI = pf.AVDI; m.Davg_km = Davg; m.rho = rho;
        m.Vmin = pf.Vmin; m.VminBus = pf.VminBus;
        m.site = c; m.xy = ctx.candXY(c, :);
        m.busIdx = bus; m.busNo = ctx.tree.nodeNo(bus);
        m.S_kVA = S; m.customers = Ni;
        m.assign = near(:); m.DN_km = DN(:);
        m.pf = pf;
    end
end
