function fig = evcsSettingsDialog(kind, opts, parentFig, onApply)
%EVCSSETTINGSDIALOG Settings dialog for the EVCS steps of the app.
%
%   fig = evcsSettingsDialog(kind, opts, parentFig, onApply)
%
%   kind       'demand'       Seed EV Demand settings
%              'sites'        Identify EVCS Sites settings
%              'sensitivity'  Sensitivity Analysis settings
%   opts       current settings (evcs.defaultOptions), shown in the dialog
%   parentFig  figure to centre the dialog over (or [])
%   onApply    called as onApply(newOpts) when Apply is pressed.  newOpts
%              holds ONLY the settings shown in this dialog (merge them into
%              the full options), so several dialogs can be open at once
%              without one undoing another's changes.
%
%   Works like busLayoutSettingsDialog: it does not block, stays on top of
%   the app, has a tooltip on every setting, and "Restore defaults" resets
%   the fields of this dialog to evcs.defaultOptions().
%
%   To add a setting: add a field (with a comment) to evcs.defaultOptions,
%   then one row to the matching SPEC below.

    if nargin < 3, parentFig = []; end
    if nargin < 4, onApply = @(o) []; end
    defaults = evcs.defaultOptions();

    % ---- SPEC: one row per setting --------------------------------------
    %   {tab, field, label, kind, limits/choices, tooltip}
    %   kind: 'num' real number, 'int' whole number, 'bool' tick box,
    %         'choice' drop-down, 'vec' space-separated numbers
    %         (limits [lo hi] or [lo hi n] for exactly n numbers),
    %         'ivec' like 'vec' but whole numbers,
    %         'numauto' number where 0 means "automatic" (stored as [])
    switch kind
        case 'demand'
            name = 'EV Demand Settings';
            spec = {
            'EV demand', 'pVehicle1', 'P(household has a vehicle)', 'num', [0 1], ...
                'Chance that a household has at least one vehicle. ABS 2021 Census: 0.913.'
            'EV demand', 'pVehicle2', 'P(second vehicle | first)', 'num', [0 1], ...
                'Chance that a household with one vehicle has a second. ABS 2021 Census: 0.551.'
            'EV demand', 'pEV', 'P(vehicle is an EV)', 'num', [0 1], ...
                ['Chance that each vehicle is a plug-in EV. NTC: 1.67% of the fleet, 13% of 2024 sales; ' ...
                 'the proposal uses 0.02 to allow minor growth.']
            'EV demand', 'customerUnit', 'Count customers per', 'choice', {'ev', 'household'}, ...
                'ev: a 2-EV household counts as 2 customers. household: every EV household counts as 1.'
            'EV demand', 'demandSeed', 'Random seed', 'int', [0 2^31], ...
                'Seed for the demand draw. The same seed and coverage always give the same demand.'
            };
        case 'sites'
            name = 'EVCS Site Selection Settings';
            spec = {
            'Stations', 'stationCounts', 'Station counts to test', 'ivec', [1 50], ...
                'Each number of stations is tested in turn, e.g. 1 2 3 4 5 6 7 8 (proposal 3.3.2).'
            'Stations', 'runs', 'PSO runs per station count', 'int', [1 1000], ...
                'Independent PSO runs (seeds 1..n) for each station count; best/worst/mean are reported. Proposal: 30.'
            'Stations', 'mapStations', 'Station count shown on map', 'int', [1 50], ...
                'The best placement for this many stations is drawn on the map (the largest tested count if not tested).'
            'Stations', 'totalCapacity_kVA', 'Total EVCS capacity (kVA)', 'num', [1 1e5], ...
                'Capacity shared between the stations. Proposal: 800 kVA.'
            'Stations', 'sizing', 'Capacity sharing', 'choice', {'equal', 'demand'}, ...
                ['equal: every station gets total / M. demand: in proportion to the customers it serves ' ...
                 '(rho is then the same for every layout).']
            'Stations', 'evcsPF', 'EVCS power factor', 'num', [0.5 1], ...
                'Power factor of the station load (constant power). 1 = no reactive power.'
            'Stations', 'useParallel', 'Run PSO runs in parallel', 'bool', [], ...
                'Use parfor over the runs (Parallel Computing Toolbox). The progress bar then moves once per station count.'

            'Objective', 'weights', 'Weights w1..w4', 'vec', [0 Inf 4], ...
                'Weights of f1 = PL0/PL, f2 = AVDI0/AVDI, f3 = Dref/Davg, f4 = rhoRef/rho (four numbers).'
            'Objective', 'rhoMode', 'rho aggregation', 'choice', {'max', 'sum'}, ...
                ['max: customers per kVA at the busiest station. sum: the proposal''s formula, which is the ' ...
                 'same for every layout under equal sizing.']
            'Objective', 'Dref_km', 'Distance reference Dref (km)', 'numauto', [0 100], ...
                'f3 = Dref / Davg. 0 = automatic (square root of the coverage area).'

            'PSO', 'psoParticles', 'Particles', 'int', [2 1000], ...
                'Number of particles (candidate placements) in the swarm.'
            'PSO', 'psoIterations', 'Max iterations', 'int', [1 1e5], ...
                'Hard cap on swarm iterations per run.'
            'PSO', 'psoStall', 'Stop after (iterations without gain)', 'int', [1 1e5], ...
                'A run stops early when the swarm''s best has not improved for this many iterations.'
            'PSO', 'psoInertia', 'Inertia (w)', 'num', [0 1.5], ...
                'How much of its previous velocity each particle keeps.'
            'PSO', 'psoC1', 'Own-best pull (c1)', 'num', [0 5], ...
                'Pull of each particle towards the best placement it has found itself.'
            'PSO', 'psoC2', 'Swarm-best pull (c2)', 'num', [0 5], ...
                'Pull of each particle towards the best placement the whole swarm has found.'
            'PSO', 'psoVmaxFrac', 'Max speed (fraction of width)', 'num', [1e-4 1], ...
                'Largest move per iteration, as a fraction of the coverage area''s width.'

            'Roads', 'useRoads', 'Use OSM road network', 'bool', [], ...
                ['Snap stations to roads and measure road distance (downloaded once from OpenStreetMap, then cached). ' ...
                 'Off: straight-line distance, stations anywhere in the area.']
            'Roads', 'roadMargin_km', 'Road margin around area (km)', 'num', [0 10], ...
                'Roads are fetched this far beyond the coverage, so shortest paths may leave the area.'
            'Roads', 'roadStep_km', 'Candidate spacing on roads (km)', 'num', [0.001 1], ...
                'Long road segments are split so there is a candidate site at least this often.'
            };
        case 'sensitivity'
            name = 'Sensitivity Analysis Settings';
            spec = {
            'Perturbations', 'sensMagnitudes_frac', 'Jumble sizes (fraction of width)', 'vec', [0 1], ...
                ['How far every bus is moved, each in its own random direction, as a fraction of the ' ...
                 'coverage width (sqrt of its area). E.g. 0.025 0.05 0.1 = 2.5%, 5% and 10%.']
            'Perturbations', 'sensTrials', 'Random trials per size', 'int', [1 1000], ...
                'How many different random jumbles are tried for each size.'
            'Perturbations', 'sensSeed', 'Random seed', 'int', [0 2^31], ...
                'Seed of the first jumble (the others use the next seeds), so the analysis can be repeated exactly.'
            'Perturbations', 'sensStationCounts', 'Station counts to test', 'ivec', [1 50], ...
                'Station counts tested for every perturbation (separate from Identify EVCS Sites).'
            'Perturbations', 'sensRuns', 'PSO runs per station count', 'int', [1 1000], ...
                'Runs per station count for every perturbation. 16 cases x 8 counts x 30 runs takes about 10 minutes.'
            };
        otherwise
            error('evcsSettingsDialog:kind', 'Unknown dialog "%s".', kind);
    end

    % ---- Window ------------------------------------------------------------
    W = 560; H = 470;
    pos = [100 100 W H];
    if ~isempty(parentFig) && isvalid(parentFig)
        p = parentFig.Position;
        pos(1:2) = p(1:2) + (p(3:4) - [W H]) / 2;
    end
    fig = uifigure('Name', name, 'Position', pos, 'WindowStyle', 'alwaysontop', 'Resize', 'off');
    fig.CloseRequestFcn = @(~, ~) finish(false);

    outer = uigridlayout(fig, [2 1], 'RowHeight', {'1x', 34}, 'Padding', [10 10 10 10]);
    tg = uitabgroup(outer);
    tabs = unique(spec(:, 1), 'stable');
    ctrl = cell(size(spec, 1), 1);

    for t = 1:numel(tabs)
        rows = find(strcmp(spec(:, 1), tabs{t}));
        tab = uitab(tg, 'Title', tabs{t});
        g = uigridlayout(tab, [numel(rows) 2], 'ColumnWidth', {'1x', 170}, ...
            'RowHeight', repmat({24}, 1, numel(rows)), 'RowSpacing', 6, ...
            'Padding', [12 12 12 12], 'Scrollable', 'on');
        for r = 1:numel(rows)
            k = rows(r);
            [~, field, label, kd, lim, tip] = spec{k, :};
            uilabel(g, 'Text', label, 'Tooltip', tip);
            c = makeControl(g, kd, lim, opts.(field));
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
            setControl(ctrl{kk}, spec{kk, 4}, defaults.(spec{kk, 2}));
        end
    end

    function finish(apply)
        if ~apply
            delete(fig);
            return
        end
        out = struct();
        for kk = 1:size(spec, 1)
            f = spec{kk, 2}; kd = spec{kk, 4}; lim = spec{kk, 5};
            switch kd
                case {'vec', 'ivec'}
                    v = str2num(ctrl{kk}.Value); %#ok<ST2NM> - plain list of numbers
                    ok = ~isempty(v) && all(isfinite(v)) && all(v >= lim(1)) && all(v <= lim(2));
                    if numel(lim) > 2, ok = ok && numel(v) == lim(3); end
                    if strcmp(kd, 'ivec'), ok = ok && all(v == round(v)); end
                    if ~ok
                        if numel(lim) > 2, what = sprintf('exactly %d numbers', lim(3));
                        elseif strcmp(kd, 'ivec'), what = 'a list of whole numbers';
                        else, what = 'a list of numbers'; end
                        uialert(fig, sprintf('"%s" must be %s between %g and %g.', ...
                            spec{kk, 3}, what, lim(1), lim(2)), 'Invalid setting');
                        return
                    end
                    if strcmp(kd, 'ivec'), v = unique(v); end
                    out.(f) = v(:)';
                case 'numauto'
                    v = ctrl{kk}.Value;
                    if v == 0, v = []; end
                    out.(f) = v;
                otherwise
                    out.(f) = ctrl{kk}.Value;
            end
        end
        if isfield(out, 'weights') && sum(out.weights) <= 0
            uialert(fig, 'At least one weight must be above zero.', 'Invalid setting');
            return
        end
        delete(fig);
        onApply(out);
    end
end


function c = makeControl(g, kd, lim, v)
    switch kd
        case 'bool'
            c = uicheckbox(g, 'Text', '');
        case 'choice'
            c = uidropdown(g, 'Items', lim);
        case 'int'
            c = uieditfield(g, 'numeric', 'Limits', lim, 'RoundFractionalValues', 'on', ...
                'ValueDisplayFormat', '%.0f');
        case {'num', 'numauto'}
            c = uieditfield(g, 'numeric', 'Limits', lim(1:2), 'ValueDisplayFormat', '%.4g');
        case {'vec', 'ivec'}
            c = uieditfield(g, 'text');
    end
    setControl(c, kd, v);
end


function setControl(c, kd, v)
    switch kd
        case 'bool',      c.Value = logical(v);
        case 'choice',    c.Value = char(v);
        case {'vec', 'ivec'}, c.Value = strtrim(sprintf('%g ', v));
        case 'numauto'
            if isempty(v), v = 0; end
            c.Value = v;
        otherwise,        c.Value = v;
    end
end
