function file = saveResults(kind, data, ctx, opts, tag)
%SAVERESULTS Write EVCS results to the results folder (.xlsx + .mat).
%
%   file = evcs.saveResults('sites', R, ctx, opts)           runExperiment output
%   file = evcs.saveResults('sensitivity', S, ctx, opts)     runSensitivity output
%   file = evcs.saveResults(..., tag)     tag is added to the file name
%
%   Files go to opts.resultsDir (default <project>/results), named
%   evcs_<kind>[_tag]_<yyyyMMdd_HHmmss>.xlsx / .mat.  Returns the .xlsx path.
%
%   SHEETS
%     sites:        Network (Table 2), Spatial (Table 3), Overall (Table 4),
%                   BestRun, BestSites (every station of every best placement,
%                   with lat/lon), AllRuns (every PSO run), Demand
%     sensitivity:  Table5 (one row per case and station count), Summary
%                   (per jumble size over its trials), Cases, BestSites
%                   (best placement of every case and count)
%   The .mat holds the result struct and the demand.

    if nargin < 5, tag = ''; end
    dirOut = opts.resultsDir;
    if isempty(dirOut)
        dirOut = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
    end
    if ~isfolder(dirOut), mkdir(dirOut); end
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    if isempty(tag), base = sprintf('evcs_%s_%s', kind, stamp);
    else, base = sprintf('evcs_%s_%s_%s', kind, regexprep(tag, '[^\w-]', '_'), stamp); end
    file = fullfile(dirOut, [base '.xlsx']);
    demand = ctx.demand; %#ok<NASGU>

    switch kind
        case 'sites'
            R = data;
            writetable(R.network, file, 'Sheet', 'Network');
            writetable(R.spatial, file, 'Sheet', 'Spatial');
            writetable(R.overall, file, 'Sheet', 'Overall');
            writetable(R.bestRun, file, 'Sheet', 'BestRun');
            writetable(sitesTable(R, ctx, ''), file, 'Sheet', 'BestSites');
            all = cell(numel(R.runs), 1);
            for j = 1:numel(R.runs)
                T = R.runs{j}; T = addvars(T, repmat(R.overall.M(j), height(T), 1), 'Before', 1, 'NewVariableNames', 'M');
                all{j} = T;
            end
            writetable(vertcat(all{:}), file, 'Sheet', 'AllRuns');
            writetable(demandTable(ctx), file, 'Sheet', 'Demand');
            save(fullfile(dirOut, [base '.mat']), 'R', 'demand');
        case 'sensitivity'
            S = data;
            writetable(S.table, file, 'Sheet', 'Table5');
            writetable(S.summary, file, 'Sheet', 'Summary');
            writetable(S.cases, file, 'Sheet', 'Cases');
            parts = cell(numel(S.results), 1);
            for c = 1:numel(S.results)
                parts{c} = sitesTable(S.results{c}, ctx, S.cases.Name(c));
            end
            writetable(vertcat(parts{:}), file, 'Sheet', 'BestSites');
            writetable(demandTable(ctx), file, 'Sheet', 'Demand');
            save(fullfile(dirOut, [base '.mat']), 'S', 'demand');
        otherwise
            error('evcs:saveResults:kind', 'Unknown kind "%s".', kind);
    end
end


function T = sitesTable(R, ctx, caseName)
    rows = {};
    for j = 1:numel(R.best)
        m = R.best{j}.m;
        [lat, lon] = busLayout.toLatLon(ctx.cov, m.xy);
        for i = 1:numel(m.site)
            rows(end + 1, :) = {string(caseName), R.overall.M(j), i, lat(i), lon(i), m.busNo(i), ...
                m.S_kVA(i), m.customers(i)}; %#ok<AGROW>
        end
    end
    T = cell2table(rows, 'VariableNames', {'Case', 'M', 'Station', 'Lat', 'Lon', 'Bus', 'S_kVA', 'Customers'});
end


function T = demandTable(ctx)
    d = ctx.demand;
    [lat, lon] = busLayout.toLatLon(ctx.cov, d.xy);
    T = table((1:numel(lat))', lat, lon, d.nEV, d.weight, ...
        'VariableNames', {'Node', 'Lat', 'Lon', 'EVs', 'Customers'});
end
