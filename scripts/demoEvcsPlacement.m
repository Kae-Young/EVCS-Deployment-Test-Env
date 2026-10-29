%DEMOEVCSPLACEMENT Seed EV demand and place charging stations with PSO (Kirwan).
%
%   Proposal sections 3.3.1-3.3.2.  Steps:
%     1. Bus layout over Kirwan, Townsville (as demoBusLayout; cached after
%        the first run in data/cache/Kirwan_layout.mat)
%     2. Seed synthetic EV demand from the area's dwellings
%     3. OSM roads (downloaded once, then cached)
%     4. Precompute candidates, road distances, zones, base power flow
%     5. One PSO run for 4 stations, plotted
%     6. Full experiment: 1..8 stations x 30 runs -> Tables 2-4
%     7. (example) sensitivity analysis - proposal 3.3.3

%% 0. Paths and options
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
rootDir = setupPaths();
lopts = busLayout.defaultOptions('verbose', false);
eopts = evcs.defaultOptions();
[branches, ~, buses] = networkData33Bus();
tree = busLayout.buildFeederTree(branches, buses, lopts);

%% 1. Bus layout (cached)
layoutFile = fullfile(rootDir, 'data', 'cache', 'Kirwan_layout.mat');
if isfile(layoutFile)
    load(layoutFile, 'cov', 'res');
else
    S = load(fullfile(rootDir, 'data', 'cache', 'Townsville.mat'), 'T');
    T = S.T;
    if ismember('IsAlias', T.Properties.VariableNames), T = T(~T.IsAlias, :); end
    cov = busLayout.coverageFromAddresses(T.Latitude, T.Longitude, [-19.303 146.722], tree.dwellings, lopts);
    res = busLayout.generate(cov, tree, lopts);
    save(layoutFile, 'cov', 'res');
end
fprintf('Layout: %.2f km^2, %d dwellings, worst bus %.2f pp\n', cov.area, cov.nDwellings, 100 * res.maxAbsErr);

%% 2. Synthetic EV demand (fixed seed - identical every run)
demand = evcs.seedDemand(cov, eopts);

%% 3. Roads
roads = evcs.buildRoads(cov, eopts);

%% 4. Context
ctx = evcs.buildContext(cov, tree, res.busXY, demand, roads, branches, eopts);

%% 5. One PSO run, 4 stations
sol = evcs.pso(ctx, 4, 1);
fprintf('4 EVCS: F = %.4f, PL = %.2f kW, AVDI = %.4f, Davg = %.0f m, rho = %.4f  (%d iterations)\n', ...
    sol.F, sol.m.PL_kW, sol.m.AVDI, 1000 * sol.m.Davg_km, sol.m.rho, sol.iterations);
evcs.plotPlacement(ctx, res, sol);
[lat, lon] = busLayout.toLatLon(cov, sol.m.xy);
disp(table((1:4)', lat, lon, sol.m.busNo, sol.m.S_kVA, sol.m.customers, ...
    'VariableNames', {'Station', 'Lat', 'Lon', 'Bus', 'S_kVA', 'Customers'}));

%% 6. Full experiment (proposal Tables 2-4)
R = evcs.runExperiment(ctx);
disp(R.network); disp(R.spatial); disp(R.overall); disp(R.bestRun);
save(fullfile(rootDir, 'data', 'cache', 'Kirwan_evcs_results.mat'), 'R', 'demand');
figure('Color', 'w', 'Position', [50 50 1500 800]);
tl = tiledlayout(2, 4, 'TileSpacing', 'compact');
for j = 1:numel(R.best)
    evcs.plotPlacement(ctx, res, R.best{j}, nexttile(tl));
end

%% 7. Sensitivity example
% One jumble: every bus moved 5% of the area's width in its own random direction
% busP = evcs.perturbLayout(res.busXY, cov, 0.05, 1);
% ctxP = evcs.buildContext(cov, tree, busP, demand, roads, branches, eopts);
% RP = evcs.runExperiment(ctxP);
% The whole analysis (control + sensTrials jumbles per size in sensMagnitudes_frac):
% S = evcs.runSensitivity(cov, tree, res.busXY, demand, roads, branches, eopts);
% disp(S.summary)
