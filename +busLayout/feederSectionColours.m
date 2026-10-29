function [nodeColour, sectionOf, palette] = feederSectionColours(tree)
%FEEDERSECTIONCOLOURS One colour per feeder section (main feeder, then each
%lateral), shared by plotLayout and the app's map drawing.
%
%   [nodeColour, sectionOf, palette] = busLayout.feederSectionColours(tree)
%
%   sectionOf   n x 1, section number of each node (1 = main feeder,
%               2.. = laterals in order of their first bus)
%   palette     colour of each section, one row per section (the base
%               palette repeats if a feeder has more sections than colours)
%   nodeColour  n x 3, colour of each node's section
%
%   Tints for zone fills are made by the callers (e.g. 0.3*c + 0.7).

    base = [0.30 0.45 0.69;    % main feeder  - blue
            0.87 0.52 0.32;    % 1st lateral  - orange
            0.33 0.66 0.41;    % 2nd lateral  - green
            0.77 0.31 0.32;    % 3rd lateral  - red
            0.51 0.45 0.70;    % more, if a different feeder is used
            0.58 0.47 0.38];
    sections = unique(tree.lateral);             % 0 (main feeder) first
    [~, sectionOf] = ismember(tree.lateral, sections);
    palette = base(mod((1:numel(sections))' - 1, size(base, 1)) + 1, :);
    nodeColour = palette(sectionOf, :);
end
