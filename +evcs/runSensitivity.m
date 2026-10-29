function S = runSensitivity(cov, tree, busXY, demand, roads, branches, opts, progressFcn)
%RUNSENSITIVITY Proposal 3.3.3: repeat the site-selection test with the bus
%layout randomly jumbled over the geographic layer.
%
%   S = evcs.runSensitivity(cov, tree, busXY, demand, roads, branches, opts)
%   S = evcs.runSensitivity(..., progressFcn)
%
%   Cases (evcs.sensitivityCases): the control, then opts.sensTrials random
%   jumbles for every magnitude in opts.sensMagnitudes_frac.  In a jumble
%   every bus moves magnitude * sqrt(coverage area) in its own random
%   direction (evcs.perturbLayout).  The geographic layer - coverage,
%   dwellings, EV demand and roads - is the same in every case; only the
%   buses, and therefore the electrical zones that decide which bus each
%   candidate site feeds, move.  Every case runs the full
%   evcs.runExperiment routine (opts.sensStationCounts x opts.sensRuns).
%
%   progressFcn(fractionDone, message) -> stop, as in runExperiment.
%
%   OUTPUT
%     S.table      proposal Table 5 in long form, one row per case and
%                  station count: Case, Name, Magnitude, Trial, M,
%                  F best/worst/mean, PL / AVDI / Davg / rho means, and
%                  SiteShift_m = how far the best placement moved from the
%                  control's best placement (mean distance from each site to
%                  the nearest site of the other placement, both ways)
%     S.summary    one row per magnitude and station count, over its trials:
%                  mean / min / max of F_mean, its change against the control
%                  (%), and the mean site shift
%     S.cases      the case list (Case, Name, Magnitude, Trial, Seed)
%     S.D_km       sqrt(coverage area): a jumble moves each bus Magnitude * D_km
%     S.results{c} runExperiment output of case c
%     S.busXY{c}   the layout of case c
%     S.cancelled, S.runtime_s

    if nargin < 8 || isempty(progressFcn), progressFcn = @(~, ~) false; end
    t0 = tic;
    quiet = opts; quiet.verbose = false;
    quiet.stationCounts = opts.sensStationCounts; quiet.runs = opts.sensRuns;

    cases = evcs.sensitivityCases(opts);
    nC = height(cases);
    S.cases = cases;
    S.results = cell(nC, 1); S.busXY = cell(nC, 1);
    S.cancelled = false;
    rows = {};

    for c = 1:nC
        if c == 1
            B = busXY;
        else
            B = evcs.perturbLayout(busXY, cov, cases.Magnitude(c), cases.Seed(c));
        end
        ctx = evcs.buildContext(cov, tree, B, demand, roads, branches, quiet);
        name = char(cases.Name(c));
        inner = @(fr, msg) progressFcn(((c - 1) + fr) / nC, sprintf('Case %d of %d (%s) - %s', c, nC, name, msg));
        R = evcs.runExperiment(ctx, quiet, inner);
        if R.cancelled
            S.cancelled = true;
            S.results = S.results(1:c - 1); S.busXY = S.busXY(1:c - 1);
            S.cases = cases(1:c - 1, :);
            break
        end
        S.results{c} = R; S.busXY{c} = B;
        if opts.verbose
            fprintf('  %-18s F best %s\n', name, mat2str(round(R.overall.F_best', 4)));
        end

        for j = 1:height(R.overall)
            if c == 1
                shift = 0;
            else
                shift = 1000 * siteShift(S.results{1}.best{j}.m.xy, R.best{j}.m.xy);
            end
            rows(end + 1, :) = {c, cases.Name(c), cases.Magnitude(c), cases.Trial(c), R.overall.M(j), ...
                R.overall.F_best(j), R.overall.F_worst(j), R.overall.F_mean(j), ...
                R.network.PL_mean_kW(j), R.network.AVDI_mean(j), R.spatial.Davg_mean_m(j), ...
                R.spatial.rho_mean(j), shift}; %#ok<AGROW>
        end
    end

    vn = {'Case', 'Name', 'Magnitude', 'Trial', 'M', 'F_best', 'F_worst', 'F_mean', ...
          'PL_mean_kW', 'AVDI_mean', 'Davg_mean_m', 'rho_mean', 'SiteShift_m'};
    if isempty(rows)
        S.table = cell2table(cell(0, numel(vn)), 'VariableNames', vn);
    else
        S.table = cell2table(rows, 'VariableNames', vn);
    end
    S.summary = summarise(S.table);
    S.D_km = cov.D;                       % jumble distance = Magnitude * D_km
    S.opts = quiet; S.opts.verbose = opts.verbose;
    S.runtime_s = toc(t0);
end


function T = summarise(tab)
% One row per (magnitude, M) over the trials, against the control.
    vn = {'Magnitude', 'M', 'Trials', 'F_mean', 'F_min', 'F_max', ...
          'dF_mean_pct', 'dF_min_pct', 'dF_max_pct', 'SiteShift_mean_m', 'SiteShift_max_m'};
    T = cell2table(cell(0, numel(vn)), 'VariableNames', vn);
    ctrl = tab(tab.Case == 1, :);
    P = tab(tab.Case > 1, :);
    if isempty(P) || isempty(ctrl), return; end
    rows = {};
    for m = unique(P.Magnitude)'
        for M = unique(P.M)'
            X = P(P.Magnitude == m & P.M == M, :);
            f0 = ctrl.F_mean(ctrl.M == M);
            if isempty(X) || isempty(f0), continue; end
            d = 100 * (X.F_mean - f0) / f0;
            rows(end + 1, :) = {m, M, height(X), mean(X.F_mean), min(X.F_mean), max(X.F_mean), ...
                mean(d), min(d), max(d), mean(X.SiteShift_m), max(X.SiteShift_m)}; %#ok<AGROW>
        end
    end
    T = cell2table(rows, 'VariableNames', vn);
end


function d = siteShift(A, B)
% Mean distance (km) from each site of A to the nearest site of B and from
% each site of B to the nearest of A - 0 when the placements coincide.
    D = sqrt((A(:, 1) - B(:, 1)').^2 + (A(:, 2) - B(:, 2)').^2);
    d = (mean(min(D, [], 2)) + mean(min(D, [], 1))) / 2;
end
