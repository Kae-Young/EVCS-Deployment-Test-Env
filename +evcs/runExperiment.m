function R = runExperiment(ctx, opts, progressFcn)
%RUNEXPERIMENT Proposal 3.3.2 test routine: 1..8 stations x 30 PSO runs.
%
%   R = evcs.runExperiment(ctx)          uses ctx.opts
%   R = evcs.runExperiment(ctx, opts)
%   R = evcs.runExperiment(ctx, opts, progressFcn)
%
%   progressFcn (optional) is called after every PSO run as
%       stop = progressFcn(fractionDone, message)
%   and the experiment stops early (R.cancelled = true, tables hold only the
%   station counts finished so far) if it returns true.  The app uses this
%   for its progress bar and Cancel button.
%
%   For every station count M in opts.stationCounts, PSO is run opts.runs
%   times (seeds 1..runs, so results are repeatable) on the SAME demand and
%   layout.  The best, worst and mean of each metric over the runs fill
%   proposal Tables 2-4.  "Best" is the lowest PL / AVDI / Davg / rho and the
%   highest F, each taken independently over the runs.
%
%   OUTPUT
%     R.network    Table 2:  M, PL best/worst/mean, AVDI best/worst/mean
%     R.spatial    Table 3:  M, Davg best/worst/mean (m), rho best/worst/mean
%     R.overall    Table 4:  M, F best/worst/mean
%     R.bestRun    metrics of the single best-F run for each M (the
%                  placement drawn on the map)
%     R.best{j}    that run's full PSO solution (evcs.pso output)
%     R.runs{j}    all runs' metrics for station count j (table)
%     R.runtime_s

    if nargin < 2 || isempty(opts), opts = ctx.opts; end
    if nargin < 3 || isempty(progressFcn), progressFcn = @(~, ~) false; end
    Ms = opts.stationCounts(:)'; nR = opts.runs;
    t0 = tic;
    R.cancelled = false; nDone = 0;
    R.runs = cell(numel(Ms), 1); R.best = cell(numel(Ms), 1);
    net = zeros(numel(Ms), 7); spa = zeros(numel(Ms), 7); ovr = zeros(numel(Ms), 4);
    bestRows = zeros(numel(Ms), 9);

    for j = 1:numel(Ms)
        M = Ms(j);
        sols = cell(nR, 1);
        if opts.useParallel
            parfor r = 1:nR
                sols{r} = evcs.pso(ctx, M, r, opts);
            end
            R.cancelled = progressFcn(j / numel(Ms), sprintf('%d station(s): %d runs done', M, nR));
        else
            for r = 1:nR
                sols{r} = evcs.pso(ctx, M, r, opts);
                R.cancelled = progressFcn(((j - 1) * nR + r) / (numel(Ms) * nR), ...
                    sprintf('%d station(s): run %d of %d', M, r, nR));
                if R.cancelled, break; end
            end
        end
        if R.cancelled, break; end
        nDone = j;
        m = cellfun(@(s) s.m, sols);
        T = table((1:nR)', [m.F]', [m.PL_kW]', [m.AVDI]', 1000 * [m.Davg_km]', [m.rho]', [m.Vmin]', ...
            cellfun(@(s) s.iterations, sols), ...
            'VariableNames', {'Run', 'F', 'PL_kW', 'AVDI', 'Davg_m', 'rho', 'Vmin', 'Iterations'});
        R.runs{j} = T;
        net(j, :) = [M bwm(T.PL_kW, 'min') bwm(T.AVDI, 'min')];
        spa(j, :) = [M bwm(T.Davg_m, 'min') bwm(T.rho, 'min')];
        ovr(j, :) = [M bwm(T.F, 'max')];
        [~, b] = max(T.F);
        R.best{j} = sols{b};
        bestRows(j, :) = [M T.F(b) T.PL_kW(b) T.AVDI(b) T.Davg_m(b) T.rho(b) T.Vmin(b) b ...
                          numel(unique(sols{b}.m.site))];
        if opts.verbose
            fprintf('  M = %d: F best %.4f / mean %.4f / worst %.4f   (%.0f s so far)\n', ...
                M, ovr(j, 2), ovr(j, 4), ovr(j, 3), toc(t0));
        end
    end

    keep = 1:nDone;
    net = net(keep, :); spa = spa(keep, :); ovr = ovr(keep, :); bestRows = bestRows(keep, :);
    R.runs = R.runs(keep); R.best = R.best(keep);
    R.network = array2table(net, 'VariableNames', {'M', 'PL_best_kW', 'PL_worst_kW', 'PL_mean_kW', ...
        'AVDI_best', 'AVDI_worst', 'AVDI_mean'});
    R.spatial = array2table(spa, 'VariableNames', {'M', 'Davg_best_m', 'Davg_worst_m', 'Davg_mean_m', ...
        'rho_best', 'rho_worst', 'rho_mean'});
    R.overall = array2table(ovr, 'VariableNames', {'M', 'F_best', 'F_worst', 'F_mean'});
    R.bestRun = array2table(bestRows, 'VariableNames', {'M', 'F', 'PL_kW', 'AVDI', 'Davg_m', ...
        'rho', 'Vmin', 'Run', 'DistinctSites'});
    R.opts = opts;
    R.base = struct('PL_kW', ctx.PL0, 'AVDI', ctx.AVDI0, 'Vmin', ctx.pf0.Vmin);
    R.runtime_s = toc(t0);
end


function v = bwm(x, bestIs)
% [best worst mean]
    if strcmp(bestIs, 'min'), v = [min(x) max(x) mean(x)];
    else,                     v = [max(x) min(x) mean(x)];
    end
end
