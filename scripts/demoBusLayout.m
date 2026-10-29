%DEMOBUSLAYOUT Worked example: lay the IEEE-33 feeder over part of Kirwan.
%
%   Run from anywhere (needs data/cache/Townsville.mat - load Townsville
%   in the app once to create it):
%
%       demoBusLayout
%
%   Steps:
%     1. Load the feeder and work out how many dwellings it can serve.
%     2. Load cached G-NAF addresses and build a feeder-sized coverage area
%        around a seed point.
%     3. Generate the layout and report how well areas match loads.
%     4. Plot it, and show per-bus area share vs load share.

%% 0. Paths
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
rootDir = setupPaths();

%% 1. Feeder
opts = busLayout.defaultOptions();                 % all settings, documented in that file
[branches, ~, buses] = networkData33Bus();
tree = busLayout.buildFeederTree(branches, buses, opts);
fprintf('IEEE-33 feeder: %.0f kW + j%.0f kvar -> serves ~%d dwellings at %g kVA each\n', ...
    sum(tree.P_kW), sum(tree.Q_kvar), tree.dwellings, opts.admd_kVA);

%% 2. Coverage area: the 874 addresses nearest a point in Kirwan, Townsville
S = load(fullfile(rootDir, 'data', 'cache', 'Townsville.mat'), 'T');
T = S.T;
if ismember('IsAlias', T.Properties.VariableNames)
    T = T(~T.IsAlias, :);                  % alias rows duplicate a real address
end
seed = [-19.303 146.722];                  % [lat lon] of the area's centre
cov = busLayout.coverageFromAddresses(T.Latitude, T.Longitude, seed, tree.dwellings, opts);
fprintf('Coverage: %.2f km^2 on a %.0f m raster (%d pixels)\n', cov.area, 1000 * cov.pixelSize_km, cov.N);

% To bound the area by a coastline instead, pass the polygon as a clip:
%   opts.clipLat = coastLat;  opts.clipLon = coastLon;
% or build the coverage straight from a boundary polygon:
%   cov = busLayout.coverageFromPolygon(polyLat, polyLon, opts);

%% 3. Layout
res = busLayout.generate(cov, tree, opts);

% Bus coordinates for overlaying on your map (node 0 = substation):
busTable = table(res.nodeNo, res.lat, res.lon, 'VariableNames', {'Node', 'Lat', 'Lon'});
disp(busTable(1:5, :));

%% 4. Plots
busLayout.plotLayout(cov, tree, res);

figure('Color', 'w');
bar(1:32, 100 * [res.target res.share]);
legend({'load share (target)', 'area share'}, 'Location', 'northwest');
xlabel('bus'); ylabel('% of total'); title('Area share vs load share');

%% Optional: PSO polish of the result (slower, small gain)
% opts.usePSO = true;
% res = busLayout.generate(cov, tree, opts);
