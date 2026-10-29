function rootDir = setupPaths()
%SETUPPATHS Put the project's code folders on the MATLAB path.
%
%   rootDir = setupPaths()   returns the project folder (the one holding
%   this file).  Called by the app at startup and by the scripts.
%
%   PROJECT LAYOUT
%     EvcsPlanner.mlapp   the app
%     RegionLimits.mat    saved map regions (lat/lon limits)
%     +busLayout/         bus-layout method (called as busLayout.generate etc.)
%     gnaf/               G-NAF address loading and dwelling counting
%     network/            feeder test-system data (IEEE-33)
%     ui/                 dialogs, outputBox.html, icons
%     scripts/            worked examples (demoBusLayout)
%     data/               large / rebuildable data, not in git:
%                           australia_gnaf_core.psv, gnaf_master.mat,
%                           cache/<region>.mat

    rootDir = fileparts(mfilename('fullpath'));
    addpath(rootDir, ...
        fullfile(rootDir, 'gnaf'), ...
        fullfile(rootDir, 'network'), ...
        fullfile(rootDir, 'ui'));
end
