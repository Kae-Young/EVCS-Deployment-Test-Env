function txt = reports(kind, varargin)
%REPORTS Text summaries of EVCS results for the app's output box.
%
%   txt = evcs.reports('demand', demand, opts)
%   txt = evcs.reports('sites', R, ctx, savedFile)
%   txt = evcs.reports('sensitivity', S, savedFile)
%
%   TABLE LINES: a line starting with one TAB is a table row, with two TABs
%   a table header.  ui/outputBox.html shows them in a fixed-width font (the
%   tabs are not shown), so the columns line up.  In the command window the
%   tabs just indent the table.

    switch kind
        case 'demand',      txt = demandText(varargin{:});
        case 'sites',       txt = sitesText(varargin{:});
        case 'sensitivity', txt = sensText(varargin{:});
        otherwise, error('evcs:reports:kind', 'Unknown report "%s".', kind);
    end
end


function txt = demandText(d, o)
    L = {};
    L{end+1} = sprintf(['Synthetic EV demand seeded (seed %d): %d households -> %d vehicles -> %d EVs ' ...
        'at %d demand nodes (expected %.1f EVs).'], d.seed, d.nHouseholds, d.nVehicles, ...
        d.nEVtotal, numel(d.weight), d.expectedEV);
    L{end+1} = sprintf(['Probabilities: first vehicle %.1f%%, second vehicle %.1f%% (if a first), ' ...
        'each vehicle an EV %.1f%%. Customers counted per %s: %d in total.'], ...
        100 * o.pVehicle1, 100 * o.pVehicle2, 100 * o.pEV, o.customerUnit, d.NT);
    L{end+1} = sprintf('Households with 1 EV: %d, with 2 EVs: %d.', nnz(d.nEV == 1), nnz(d.nEV == 2));
    L{end+1} = 'The demand stays fixed for Identify EVCS Sites and the Sensitivity Analysis until it is seeded again.';
    txt = strjoin(L, newline);
end


function txt = sitesText(R, ctx, savedFile)
    o = R.opts;
    L = {};
    if R.cancelled, state = 'CANCELLED - partial results'; else, state = 'complete'; end
    L{end+1} = sprintf(['EVCS site selection %s in %.0f s: %d run(s) per station count, %d customers, ' ...
        '%d candidate road sites, %s distances.'], state, R.runtime_s, o.runs, ctx.NT, ctx.C, ctx.distanceType);
    L{end+1} = sprintf(['Base case (no EVCS): PL %.2f kW, AVDI %.4f, Vmin %.4f p.u.  Total capacity %g kVA ' ...
        '(%s sizing), weights [%s], rho = %s.'], R.base.PL_kW, R.base.AVDI, R.base.Vmin, ...
        o.totalCapacity_kVA, o.sizing, num2str(o.weights, '%g '), o.rhoMode);
    if nargin >= 3 && ~isempty(savedFile)
        L{end+1} = sprintf('Saved to %s', savedFile);
    end

    L{end+1} = ''; L{end+1} = 'Network objectives (Table 2)';
    f = '%-4s%10s%10s%10s | %9s%9s%9s';
    L{end+1} = [char([9 9]) sprintf(f, 'M', 'PL best', 'worst', 'mean', 'AVDI best', 'worst', 'mean')];
    for k = 1:height(R.network)
        r = R.network(k, :);
        L{end+1} = [char(9) sprintf('%-4d%10.2f%10.2f%10.2f | %9.4f%9.4f%9.4f', r.M, r.PL_best_kW, ...
            r.PL_worst_kW, r.PL_mean_kW, r.AVDI_best, r.AVDI_worst, r.AVDI_mean)]; %#ok<AGROW>
    end

    L{end+1} = ''; L{end+1} = 'Spatial objectives (Table 3) - Davg in metres, rho in customers per kVA';
    f = '%-4s%10s%10s%10s | %9s%9s%9s';
    L{end+1} = [char([9 9]) sprintf(f, 'M', 'Davg best', 'worst', 'mean', 'rho best', 'worst', 'mean')];
    for k = 1:height(R.spatial)
        r = R.spatial(k, :);
        L{end+1} = [char(9) sprintf('%-4d%10.0f%10.0f%10.0f | %9.4f%9.4f%9.4f', r.M, r.Davg_best_m, ...
            r.Davg_worst_m, r.Davg_mean_m, r.rho_best, r.rho_worst, r.rho_mean)]; %#ok<AGROW>
    end

    L{end+1} = ''; L{end+1} = 'Overall objective (Table 4)';
    L{end+1} = [char([9 9]) sprintf('%-4s%10s%10s%10s', 'M', 'F best', 'worst', 'mean')];
    for k = 1:height(R.overall)
        r = R.overall(k, :);
        L{end+1} = [char(9) sprintf('%-4d%10.4f%10.4f%10.4f', r.M, r.F_best, r.F_worst, r.F_mean)]; %#ok<AGROW>
    end

    % Sites of the placement drawn on the map
    j = find(R.overall.M == o.mapStations, 1);
    if isempty(j), j = height(R.overall); end
    if ~isempty(j)
        b = R.best{j}; m = b.m;
        [lat, lon] = busLayout.toLatLon(ctx.cov, m.xy);
        L{end+1} = '';
        L{end+1} = sprintf('Best placement for %d station(s) (run %d, shown on the map): F %.4f, PL %.2f kW, AVDI %.4f, Davg %.0f m, rho %.4f, Vmin %.4f', ...
            numel(m.site), b.seed, m.F, m.PL_kW, m.AVDI, 1000 * m.Davg_km, m.rho, m.Vmin);
        L{end+1} = [char([9 9]) sprintf('%-9s%11s%12s%6s%8s%11s%13s', 'Station', 'Latitude', 'Longitude', ...
            'Bus', 'kVA', 'Customers', 'Mean dist m')];
        for i = 1:numel(m.site)
            dm = mean(m.DN_km(m.assign == i)) * 1000;
            if isnan(dm), dm = 0; end
            L{end+1} = [char(9) sprintf('%-9d%11.5f%12.5f%6d%8.0f%11d%13.0f', i, lat(i), lon(i), ...
                m.busNo(i), m.S_kVA(i), m.customers(i), dm)]; %#ok<AGROW>
        end
    end
    txt = strjoin(L, newline);
end


function txt = sensText(S, savedFile)
    o = S.opts;
    L = {};
    if S.cancelled, state = 'CANCELLED - partial results'; else, state = 'complete'; end
    L{end+1} = sprintf('Sensitivity analysis %s in %.0f s: %d case(s), stations %s, %d run(s) each.', ...
        state, S.runtime_s, height(S.cases), mat2str(o.stationCounts), o.runs);
    mags = unique(S.cases.Magnitude(S.cases.Case > 1))';
    magTxt = strjoin(arrayfun(@(m) sprintf('%g%% (%.0f m)', 100 * m, 1000 * m * S.D_km), mags, ...
        'UniformOutput', false), ', ');
    if isempty(magTxt), magTxt = 'none finished'; end
    L{end+1} = sprintf(['Jumbles: every bus moved in its own random direction by %s of the coverage width ' ...
        '(sqrt of its area, %.2f km), %d random trial(s) each. Site shift = how far the best placement ' ...
        'moved from the control''s (mean nearest-site distance).'], magTxt, S.D_km, o.sensTrials);
    if nargin >= 2 && ~isempty(savedFile)
        L{end+1} = sprintf('Saved to %s (full Table 5 in long form)', savedFile);
    end
    if isempty(S.table), txt = strjoin(L, newline); return; end

    % Compact Table 5: F mean per case (rows) and station count (columns),
    % then the site shift for the map's station count.
    Ms = unique(S.table.M)';
    mapM = o.mapStations; if ~ismember(mapM, Ms), mapM = Ms(end); end
    L{end+1} = '';
    L{end+1} = sprintf('Overall objective F (mean of runs) and site shift for %d station(s)', mapM);
    head = sprintf('%-18s', 'Case');
    for M = Ms, head = [head sprintf('%8s', sprintf('M=%d', M))]; end %#ok<AGROW>
    head = [head sprintf('%14s', sprintf('shift m (M=%d)', mapM))];
    L{end+1} = [char([9 9]) head];
    for c = 1:height(S.cases)
        T = S.table(S.table.Case == c, :);
        row = sprintf('%-18s', char(S.cases.Name(c)));
        for M = Ms
            v = T.F_mean(T.M == M);
            if isempty(v), row = [row sprintf('%8s', '-')]; else, row = [row sprintf('%8.4f', v)]; end %#ok<AGROW>
        end
        v = T.SiteShift_m(T.M == mapM);
        if isempty(v), row = [row sprintf('%14s', '-')]; else, row = [row sprintf('%14.0f', v)]; end %#ok<AGROW>
        L{end+1} = [char(9) row]; %#ok<AGROW>
    end

    % Summary per jumble size, over its trials, against the control
    if ~isempty(S.summary)
        L{end+1} = '';
        L{end+1} = 'Change in mean F against the control (percent) and site shift, over the trials of each jumble size';
        L{end+1} = [char([9 9]) sprintf('%-10s%-5s%10s%10s%10s%14s%13s', 'Jumble', 'M', 'dF mean', ...
            'dF min', 'dF max', 'shift mean m', 'shift max m')];
        for k = 1:height(S.summary)
            r = S.summary(k, :);
            L{end+1} = [char(9) sprintf('%-10s%-5d%+10.2f%+10.2f%+10.2f%14.0f%13.0f', ...
                sprintf('%g%%', 100 * r.Magnitude), r.M, r.dF_mean_pct, r.dF_min_pct, r.dF_max_pct, ...
                r.SiteShift_mean_m, r.SiteShift_max_m)]; %#ok<AGROW>
        end
    end
    txt = strjoin(L, newline);
end
