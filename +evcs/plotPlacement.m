function ax = plotPlacement(ctx, res, sol, ax, name)
%PLOTPLACEMENT Draw EVCS sites over the electrical zones, roads and demand.
%
%   evcs.plotPlacement(ctx, res, sol)            new figure
%   evcs.plotPlacement(ctx, res, sol, ax, name)  into existing axes
%
%   res  busLayout.generate result (zones and buses)
%   sol  evcs.pso solution
%
%   Zones/buses as in busLayout.plotLayout; roads in grey; each EV
%   household is a red dot (larger = 2 EVs) joined by a thin line to the
%   station it uses; stations are green stars labelled with their bus and
%   capacity.

    if nargin < 4 || isempty(ax)
        figure('Color', 'w', 'Position', [100 100 900 750]);
        ax = gca;
    end
    if ~isequal(res.busXY, ctx.busXY)
        res.busXY = ctx.busXY;      % perturbed layout: draw what was optimised
    end
    busLayout.plotLayout(ctx.cov, ctx.tree, res, ax);
    hold(ax, 'on');

    if ~isempty(ctx.roads)
        E = ctx.roads.G.Edges.EndNodes;
        xs = [ctx.roads.xy(E(:, 1), 1) ctx.roads.xy(E(:, 2), 1) nan(size(E, 1), 1)]';
        ys = [ctx.roads.xy(E(:, 1), 2) ctx.roads.xy(E(:, 2), 2) nan(size(E, 1), 1)]';
        plot(ax, xs(:), ys(:), '-', 'Color', [0.55 0.55 0.55 0.6], 'LineWidth', 0.8);
    end

    m = sol.m; d = ctx.demand;
    for k = 1:size(d.xy, 1)
        s = m.xy(m.assign(k), :);
        plot(ax, [d.xy(k, 1) s(1)], [d.xy(k, 2) s(2)], '-', 'Color', [0.85 0.2 0.2 0.35]);
    end
    plot(ax, d.xy(d.nEV == 1, 1), d.xy(d.nEV == 1, 2), 'o', 'MarkerSize', 4, ...
        'MarkerFaceColor', [0.85 0.15 0.15], 'MarkerEdgeColor', 'none');
    plot(ax, d.xy(d.nEV == 2, 1), d.xy(d.nEV == 2, 2), 'o', 'MarkerSize', 7, ...
        'MarkerFaceColor', [0.85 0.15 0.15], 'MarkerEdgeColor', 'k');
    plot(ax, m.xy(:, 1), m.xy(:, 2), 'p', 'MarkerSize', 18, ...
        'MarkerFaceColor', [0.1 0.75 0.3], 'MarkerEdgeColor', 'k', 'LineWidth', 1);
    for i = 1:size(m.xy, 1)
        text(ax, m.xy(i, 1), m.xy(i, 2), sprintf('   bus %d, %.0f kVA, %d cust.', ...
            m.busNo(i), m.S_kVA(i), m.customers(i)), 'FontSize', 8, 'FontWeight', 'bold', ...
            'Color', [0 0.35 0.1], 'VerticalAlignment', 'top');
    end
    hold(ax, 'off');

    t1 = sprintf('%d EVCS (%s distance): F = %.4f', numel(m.site), ctx.distanceType, m.F);
    t2 = sprintf('PL %.1f kW (base %.1f)   AVDI %.4f (base %.4f)   Vmin %.4f', ...
        m.PL_kW, ctx.PL0, m.AVDI, ctx.AVDI0, m.Vmin);
    t3 = sprintf('Davg %.0f m   rho %.4f cust/kVA   %d customers', ...
        1000 * m.Davg_km, m.rho, ctx.NT);
    if nargin >= 5 && ~isempty(name), tt = {name, t1, t2, t3}; else, tt = {t1, t2, t3}; end
    title(ax, tt, 'FontSize', 9, 'Color', 'k');
end
