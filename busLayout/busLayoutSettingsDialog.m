function fig = busLayoutSettingsDialog(opts, parentFig, onApply)
%BUSLAYOUTSETTINGSDIALOG Dialog for editing the bus-layout settings.
%
%   busLayoutSettingsDialog(opts, parentFig, onApply)
%   fig = busLayoutSettingsDialog(...)
%
%   opts       current settings (busLayoutOptions) shown in the dialog
%   parentFig  figure to centre the dialog over (or [])
%   onApply    function handle, called as onApply(newOpts) when the user
%              presses Apply.  Cancel or the window's close button just
%              close the dialog.
%   fig        the dialog window (returned straight away)
%
%   The dialog does NOT block: this function returns as soon as the window
%   is open and MATLAB stays responsive.  (An earlier version waited with
%   uiwait until the window closed; on top of an App Designer app that wait
%   could hang for a long time when the dialog was closed.)  It stays on top
%   of the app while open.
%
%   Settings are grouped on four tabs; hover over any setting to see what it
%   does.  "Restore defaults" resets every field on every tab to
%   busLayoutOptions().  Settings that the app sets itself (substation
%   location, clip polygon, verbose) are not shown.
%
%   To add a setting: add a field (with a comment) to busLayoutOptions, then
%   one row to the SPEC table below.

    if nargin < 2, parentFig = []; end
    if nargin < 3, onApply = @(o) []; end
    defaults = busLayoutOptions();

    % ---- SPEC: one row per setting --------------------------------------
    %   {tab, field, label, kind, limits/choices, tooltip}
    %   kind: 'num' real number, 'int' whole number, 'bool' tick box,
    %         'choice' drop-down, 'vec' space-separated list of numbers
    spec = {
    'Objective', 'errorMode', 'Error weighting', 'choice', {'balanced', 'absolute', 'relative'}, ...
        ['How zone errors are counted. balanced: each squared miss divided by the bus''s target ' ...
         '(fair to small and large buses, best in testing). absolute: misses in percentage points ' ...
         '(favours big buses). relative: misses as a fraction of each target (lets big buses drift).']
    'Objective', 'lambda', 'Line-length weight (lambda)', 'num', [0 Inf], ...
        'Penalty on long lines. Higher keeps buses closer to their neighbours but makes zone areas less accurate.'
    'Objective', 'mu', 'Sharp-turn weight (mu)', 'num', [0 Inf], ...
        'Penalty on turns sharper than the turn limit. Higher straightens the feeder but makes zone areas less accurate.'
    'Objective', 'turnLimit_deg', 'Turn limit (deg)', 'num', [0 180], ...
        'Smallest angle wanted between a bus''s incoming and outgoing lines. 180 = straight on, 90 = right angle.'
    'Objective', 'siblingLimit_deg', 'Branch split limit (deg)', 'num', [0 180], ...
        'Smallest angle wanted between two lines leaving the same bus.'

    'Search', 'maxIter', 'Max iterations per start', 'int', [1 1e6], ...
        'Hard cap on correction iterations for each starting layout.'
    'Search', 'patience', 'Patience (iterations)', 'int', [1 1e6], ...
        'Stop a start after this many iterations in a row without improvement.'
    'Search', 'stepFrac', 'Initial step (fraction of area width)', 'num', [1e-6 1], ...
        'First step size, as a fraction of the coverage area''s width (sqrt of its area).'
    'Search', 'stepDecayEvery', 'Shrink step after (failures)', 'int', [1 1e6], ...
        'After this many iterations in a row without improvement, the step size is reduced.'
    'Search', 'stepDecay', 'Step shrink factor', 'num', [0.01 0.99], ...
        'Factor the step size is multiplied by when it is reduced.'
    'Search', 'adamBeta1', 'Adam momentum (beta1)', 'num', [0 0.999], ...
        'How much each move keeps the direction of earlier moves. Smooths the jittery raster gradient.'
    'Search', 'adamBeta2', 'Adam scaling memory (beta2)', 'num', [0 0.9999], ...
        'Memory of the typical gradient size used to give every bus a similar step.'
    'Search', 'repairTries', 'Crossing repair halvings', 'int', [1 100], ...
        'How many times a move that creates a crossing is halved before the step is rejected.'
    'Search', 'useWeightedStarts', 'Load-weighted starting layouts', 'bool', [], ...
        'Also start from Kamada-Kawai drawings whose line lengths follow the load shares (4 extra starts).'
    'Search', 'useReflections', 'Mirrored starting layouts', 'bool', [], ...
        'Try every starting drawing in all 4 mirror orientations (x4 starts).'
    'Search', 'kkIterations', 'Kamada-Kawai iterations', 'int', [1 1e5], ...
        'Iterations used to draw the feeder tree for the starting layouts.'

    'Area', 'targetPixels', 'Raster pixels', 'int', [1000 2e6], ...
        'Number of pixels the coverage area is divided into. More = smoother zones but slower.'
    'Area', 'staircase', 'Boundary length correction', 'num', [0.5 1], ...
        'Converts pixel-edge counts to true boundary length (pi/4 = 0.785 for random directions).'
    'Area', 'margin_km', 'Margin around area (km)', 'num', [0 10], ...
        'Empty border kept around the coverage area in the raster.'
    'Area', 'bufferRadius_km', 'Address buffer (km)', 'num', [0 5], ...
        'Only for areas built from addresses: radius of land given to each address.'
    'Area', 'closeRadius_km', 'Gap closing radius (km)', 'num', [0 5], ...
        'Only for areas built from addresses: gaps narrower than about twice this are filled in.'
    'Area', 'admd_kVA', 'ADMD per dwelling (kVA)', 'num', [0.1 100], ...
        'After-diversity maximum demand per dwelling, used to size the area (4369 kVA / ADMD dwellings).'

    'PSO', 'usePSO', 'Run PSO refinement', 'bool', [], ...
        'Polish the corrected layout with a particle swarm. About 4x slower; a few percent better.'
    'PSO', 'psoParticles', 'Particles', 'int', [2 1000], ...
        'Number of particles (candidate layouts) in the swarm.'
    'PSO', 'psoIterations', 'Iterations', 'int', [1 1e5], ...
        'Number of swarm iterations.'
    'PSO', 'psoInertia', 'Inertia (w)', 'num', [0 1.5], ...
        'How much of its previous velocity each particle keeps.'
    'PSO', 'psoC1', 'Own-best pull (c1)', 'num', [0 5], ...
        'Pull of each particle towards the best layout it has found itself.'
    'PSO', 'psoC2', 'Swarm-best pull (c2)', 'num', [0 5], ...
        'Pull of each particle towards the best layout the whole swarm has found.'
    'PSO', 'psoVmaxFrac', 'Max speed (fraction of width)', 'num', [1e-4 1], ...
        'Largest move per iteration, as a fraction of the coverage area''s width.'
    'PSO', 'psoJitterFrac', 'Seed spread (fractions)', 'vec', [0 1], ...
        'Spread of the starting particles around the seed layout, as fractions of the width, e.g. 0.01 0.03 0.1.'
    'PSO', 'psoCrossingPenalty', 'Penalty per crossing', 'num', [0 Inf], ...
        'Added to the score for each line crossing; must be far above any normal score.'
    'PSO', 'psoSeed', 'Random seed', 'int', [0 2^31], ...
        'Seed for the random numbers, so a run can be repeated exactly.'
    };

    % ---- Window ------------------------------------------------------------
    W = 560; H = 470;
    pos = [100 100 W H];
    if ~isempty(parentFig) && isvalid(parentFig)
        p = parentFig.Position;
        pos(1:2) = p(1:2) + (p(3:4) - [W H]) / 2;
    end
    fig = uifigure('Name', 'Bus Partition Settings', 'Position', pos, ...
        'WindowStyle', 'alwaysontop', 'Resize', 'off');
    fig.CloseRequestFcn = @(~, ~) finish(false);

    outer = uigridlayout(fig, [2 1], 'RowHeight', {'1x', 34}, 'Padding', [10 10 10 10]);
    tg = uitabgroup(outer);
    tabs = unique(spec(:, 1), 'stable');
    ctrl = cell(size(spec, 1), 1);               % the input control of each row

    for t = 1:numel(tabs)
        rows = find(strcmp(spec(:, 1), tabs{t}));
        tab = uitab(tg, 'Title', tabs{t});
        g = uigridlayout(tab, [numel(rows) 2], 'ColumnWidth', {'1x', 150}, ...
            'RowHeight', repmat({24}, 1, numel(rows)), 'RowSpacing', 6, ...
            'Padding', [12 12 12 12], 'Scrollable', 'on');
        for r = 1:numel(rows)
            k = rows(r);
            [~, field, label, kind, lim, tip] = spec{k, :};
            uilabel(g, 'Text', label, 'Tooltip', tip);
            switch kind
                case 'bool'
                    c = uicheckbox(g, 'Text', '', 'Value', logical(opts.(field)));
                case 'choice'
                    c = uidropdown(g, 'Items', lim, 'Value', char(opts.(field)));
                case 'int'
                    c = uieditfield(g, 'numeric', 'Limits', lim, 'RoundFractionalValues', 'on', ...
                        'ValueDisplayFormat', '%.0f', 'Value', opts.(field));
                case 'num'
                    c = uieditfield(g, 'numeric', 'Limits', lim, ...
                        'ValueDisplayFormat', '%.4g', 'Value', opts.(field));
                case 'vec'
                    c = uieditfield(g, 'text', 'Value', num2str(opts.(field)(:)'));
            end
            c.Tooltip = tip;
            ctrl{k} = c;
        end
    end

    % ---- Buttons -------------------------------------------------------------
    bar = uigridlayout(outer, [1 4], 'ColumnWidth', {130, '1x', 90, 90}, 'Padding', [0 0 0 0]);
    uibutton(bar, 'Text', 'Restore defaults', 'ButtonPushedFcn', @(~, ~) restoreDefaults());
    uilabel(bar, 'Text', '');
    uibutton(bar, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
    uibutton(bar, 'Text', 'Apply', 'ButtonPushedFcn', @(~, ~) finish(true));

    % ---- Nested helpers --------------------------------------------------------
    function restoreDefaults()
        for kk = 1:size(spec, 1)
            f = spec{kk, 2}; v = defaults.(f);
            switch spec{kk, 4}
                case 'bool',   ctrl{kk}.Value = logical(v);
                case 'choice', ctrl{kk}.Value = char(v);
                case 'vec',    ctrl{kk}.Value = num2str(v(:)');
                otherwise,     ctrl{kk}.Value = v;
            end
        end
    end

    function finish(apply)
        % Apply: read every control, check it, hand the settings to onApply.
        % Cancel / close button: just close.
        if apply
            out = opts;
            for kk = 1:size(spec, 1)
                f = spec{kk, 2};
                switch spec{kk, 4}
                    case 'vec'
                        v = str2num(ctrl{kk}.Value); %#ok<ST2NM> - plain list of numbers
                        lim = spec{kk, 5};
                        if isempty(v) || any(~isfinite(v)) || any(v < lim(1)) || any(v > lim(2))
                            uialert(fig, sprintf('"%s" must be a list of numbers between %g and %g.', ...
                                spec{kk, 3}, lim(1), lim(2)), 'Invalid setting');
                            return
                        end
                        out.(f) = v(:)';
                    otherwise
                        out.(f) = ctrl{kk}.Value;
                end
            end
            delete(fig);
            onApply(out);
        else
            delete(fig);
        end
    end
end
