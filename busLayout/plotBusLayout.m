function ax = plotBusLayout(cov, tree, res, ax, name)
%PLOTBUSLAYOUT Draw the electrical zones, feeder lines and buses.
%
%   plotBusLayout(cov, tree, res)        new figure
%   plotBusLayout(cov, tree, res, ax)    into existing axes
%   plotBusLayout(cov, tree, res, ax, name)   with a name above the stats
%
%   Zones are shaded by feeder section (main feeder and each lateral get
%   their own colour) with white zone boundaries; addresses are grey dots;
%   the substation is a yellow square.  Axes are in km.

    if nargin < 4 || isempty(ax)
        figure('Color', 'w');
        ax = gca;
    end
    hold(ax, 'on');

    % ---- Colour per feeder section.
    palette = [0.30 0.45 0.69;    % main feeder
               0.87 0.52 0.32;    % 1st lateral
               0.33 0.66 0.41;    % 2nd lateral
               0.77 0.31 0.32;    % 3rd lateral
               0.51 0.45 0.70;    % more, if a different feeder is used
               0.58 0.47 0.38];
    secs = unique(tree.lateral);                 % 0 first = main feeder
    secOf = zeros(tree.n, 1);
    for s = 1:numel(secs)
        secOf(tree.lateral == secs(s)) = mod(s - 1, size(palette, 1)) + 1;
    end

    % ---- Zone image: light section colour, white boundaries and outside.
    [ny, nx] = size(cov.mask);
    zoneIdxImg = zeros(ny, nx);
    zoneIdxImg(cov.idx) = res.zone(cov.idx) + 1;            % IEEE no. -> index
    edge = false(ny, nx);
    edge(:, 2:end) = edge(:, 2:end) | zoneIdxImg(:, 2:end) ~= zoneIdxImg(:, 1:end - 1);
    edge(2:end, :) = edge(2:end, :) | zoneIdxImg(2:end, :) ~= zoneIdxImg(1:end - 1, :);
    img = ones(ny, nx, 3);
    for ch = 1:3
        layer = ones(ny, nx);
        col = palette(:, ch) * 0.3 + 0.7;                    % 30% tint
        layer(cov.idx) = col(secOf(zoneIdxImg(cov.idx)));
        layer(edge & cov.mask) = 1;
        img(:, :, ch) = layer;
    end
    W = nx * cov.cell; H = ny * cov.cell;
    image(ax, [cov.cell / 2, W - cov.cell / 2], [cov.cell / 2, H - cov.cell / 2], img);
    set(ax, 'YDir', 'normal');

    % ---- Coverage outline, addresses, lines, buses.
    contour(ax, ((1:nx) - 0.5) * cov.cell, ((1:ny) - 0.5) * cov.cell, ...
            double(cov.mask), [0.5 0.5], 'Color', [0.4 0.4 0.4]);
    if isfield(cov, 'addr') && ~isempty(cov.addr)
        plot(ax, cov.addr(:, 1), cov.addr(:, 2), '.', 'Color', [0.45 0.45 0.45], 'MarkerSize', 3);
    end
    Q = res.Q;
    for k = 1:size(tree.br, 1)
        plot(ax, Q(tree.br(k, :), 1), Q(tree.br(k, :), 2), '-', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.2);
    end
    for k = tree.zoneIdx
        plot(ax, Q(k, 1), Q(k, 2), 'o', 'MarkerSize', 5, 'MarkerEdgeColor', 'k', ...
             'MarkerFaceColor', palette(secOf(k), :));
        text(ax, Q(k, 1), Q(k, 2), sprintf('  %d', tree.nodeNo(k)), 'FontSize', 7, ...
             'VerticalAlignment', 'bottom', 'Color', 'k');
    end
    plot(ax, Q(1, 1), Q(1, 2), 's', 'MarkerSize', 8, 'MarkerEdgeColor', 'k', ...
         'MarkerFaceColor', [1 0.85 0.1]);

    % ---- 500 m scale bar.
    x0 = 0.04 * W; y0 = 0.03 * H;
    plot(ax, [x0 x0 + 0.5], [y0 y0], 'k-', 'LineWidth', 3);
    text(ax, x0 + 0.25, y0, '500 m', 'HorizontalAlignment', 'center', ...
         'VerticalAlignment', 'bottom', 'FontSize', 7, 'Color', 'k');

    axis(ax, 'equal'); axis(ax, [0 W 0 H]);
    % Explicit colours so the plot reads the same under light or dark themes.
    set(ax, 'XTick', [], 'YTick', [], 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    box(ax, 'on');
    line1 = sprintf('%.2f km^2   worst bus %.2f pp   mean rel. err %.1f%%', ...
        cov.area, 100 * res.maxAbsErr, 100 * res.meanRelErr);
    line2 = sprintf('crossings %d   sharpest turn %.0f%s   lines %.1f km', ...
        res.crossings, res.sharpestTurn_deg, char(176), res.lineLength_km);
    if nargin >= 5 && ~isempty(name)
        title(ax, {name, line1, line2}, 'FontSize', 9, 'Color', 'k');
    else
        title(ax, {line1, line2}, 'FontSize', 9, 'Color', 'k');
    end
    hold(ax, 'off');
end
