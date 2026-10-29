function opts = busLayoutOptions(varargin)
%BUSLAYOUTOPTIONS Default settings for the IEEE-33 geographic bus layout.
%
%   opts = busLayoutOptions()                 returns every setting at its default
%   opts = busLayoutOptions('name', value, ...) overrides individual settings
%
%   Every function in this folder takes this one options struct, so all of
%   the tuning knobs for the whole method live (and are documented) here.
%
%   ------------------------------------------------------------------------
%   WHAT THE METHOD DOES (overview - each step has its own function)
%   ------------------------------------------------------------------------
%   Goal: place the 33 buses of the IEEE-33 feeder over a map so that, when
%   the map is divided into Voronoi cells ("electrical zones": every point
%   belongs to its nearest bus), the share of AREA each bus gets equals the
%   share of LOAD that bus carries in the IEEE-33 system.  The layout must
%   also look like a believable feeder: lines must not cross and the feeder
%   must not double back on itself (no hairpin turns).
%
%     1. coverageFromAddresses / coverageFromPolygon
%          turn the study area into a raster (grid of small square pixels).
%     2. ieee33Tree
%          read the feeder: which bus feeds which, and each bus's load share.
%     3. graphLayoutStarts
%          draw the feeder tree as a tidy graph (Kamada-Kawai) and stretch it
%          over the study area -> 8 candidate starting layouts.
%     4. correctLayout
%          from each start, repeatedly nudge buses so zone areas move towards
%          their load shares, while refusing any move that makes lines cross
%          and penalising sharp turns.
%     5. generateBusLayout
%          runs 3 + 4 for every start and keeps the best result.
%     6. psoPolish (optional)
%          a particle swarm seeded with the best result, for a final polish.
%
%   ------------------------------------------------------------------------
%   SETTINGS
%   ------------------------------------------------------------------------

    % ---- Study-area sizing ------------------------------------------------
    % Size of the study area is set by the electrical capacity of the feeder.
    % IEEE-33 aggregate demand: 3715 kW + j2300 kvar -> |S| = 4.37 MVA.
    % Ergon Energy's after-diversity maximum demand (ADMD) per detached
    % suburban dwelling is ~5 kVA (Shahnia et al., 2012), so the feeder can
    % serve about 4370 / 5 = 874 dwellings.  ieee33Tree computes the number
    % from the actual load data using this ADMD value.
    opts.admd_kVA = 5;

    % ---- Raster (grid) resolution --------------------------------------------
    % The coverage area is drawn on a grid of square pixels.  The cell size is
    % chosen automatically so the bounding box holds about this many pixels.
    % More pixels = smoother zone boundaries but slower.  40 000 gives
    % ~5-10 m pixels for a feeder-sized (~1 km^2) area.
    opts.targetPixels = 40000;

    % ---- Building a coverage area from address points ------------------------
    % Each address is "inflated" by a disc of this radius, then gaps narrower
    % than about 2 x closeRadius_km (streets, small parks) are closed.
    opts.bufferRadius_km = 0.06;    % 60 m around each dwelling
    opts.closeRadius_km  = 0.10;    % closes gaps up to ~200 m wide
    opts.margin_km       = 0.10;    % empty border kept around the area

    % Optional clipping polygon (e.g. a coastline) in degrees.  Pixels outside
    % this polygon are removed from the coverage.  Leave empty for none.
    opts.clipLat = [];
    opts.clipLon = [];

    % ---- Substation ----------------------------------------------------------
    % Location of bus 0 (the substation) as [lat lon].  Empty = let the graph
    % layout decide (it ends up beside bus 1).  The substation has zero load,
    % so it never gets a zone of its own and never moves during correction.
    opts.substationLatLon = [];

    % ---- Objective weights ---------------------------------------------------
    % The correction minimises
    %     F = SSE  +  lambda * LINE  +  mu * TURN
    % where
    %     SSE  = weighted sum over buses of (area share - load share)^2
    %            (the goal; see errorMode below)
    %     LINE = mean squared line length / D^2  (D = sqrt(coverage area));
    %            keeps lines short so buses stay near their neighbours
    %     TURN = sum of squared "too-sharp" amounts over all turns (see below)
    opts.lambda = 0.02;
    opts.mu     = 3e-3;

    % How zone errors are counted in SSE (full explanation and test results
    % in errorWeights.m):
    %   'balanced' - each squared miss divided by the bus's target share
    %                (chi-squared form).  Small buses get fair zones and big
    %                buses stay accurate in points.  Best in testing (default)
    %   'absolute' - misses in percentage points of the total area; favours
    %                the big buses, small ones can drift by 40-80%
    %   'relative' - misses as a fraction of each bus's own target; lets the
    %                two big buses drift and gives worse layouts
    opts.errorMode = 'balanced';

    % ---- Turn limits (the "no hairpins" rule) --------------------------------
    % At every bus, the angle between the incoming line (from the parent) and
    % each outgoing line (to a child) should be at least turnLimit_deg.
    % 180 deg = the feeder carries straight on; 90 deg = a right-angle turn;
    % small angles = the line folds back on itself.
    % Lines leaving the same bus should be at least siblingLimit_deg apart so
    % two branches do not leave a junction on top of each other.
    % These are SOFT limits: violations are penalised (weight mu), not banned,
    % because a hard ban was found to freeze buses and ruin area accuracy.
    opts.turnLimit_deg    = 120;
    opts.siblingLimit_deg = 45;

    % ---- Correction (gradient descent) settings ------------------------------
    opts.maxIter       = 600;   % hard cap on iterations per start
    opts.patience      = 50;    % stop after this many iterations w/o improvement
    opts.stepFrac      = 0.02;  % initial step = stepFrac * D (D = sqrt(area))
    opts.stepDecayEvery = 10;   % shrink the step after this many failures ...
    opts.stepDecay     = 0.6;   % ... by this factor
    opts.adamBeta1     = 0.8;   % Adam momentum (smooths gradient direction)
    opts.adamBeta2     = 0.95;  % Adam scaling (per-bus step normalisation)
    opts.repairTries   = 40;    % max halvings when a move creates a crossing
    opts.staircase     = pi/4;  % pixel-edge -> true boundary length correction

    % ---- Starting layouts ----------------------------------------------------
    % Kamada-Kawai drawings: plain (every line the same ideal length) and
    % load-weighted (ideal line length ~ sqrt of the two buses' load shares,
    % so heavily loaded buses get more room).  Each is tried in 4 mirror
    % orientations -> 8 starts.
    opts.useWeightedStarts = true;
    opts.useReflections    = true;
    opts.kkIterations      = 300;

    % ---- Optional PSO polish ---------------------------------------------------
    % Testing showed PSO seeded with the corrected layout improves the score by
    % 3-16% at ~4x the run time, while PSO from scratch is far worse.  Off by
    % default.
    opts.usePSO        = false;
    opts.psoParticles  = 30;
    opts.psoIterations = 300;
    opts.psoInertia    = 0.729;    % Clerc-Kennedy constriction values
    opts.psoC1         = 1.494;    % pull towards each particle's own best
    opts.psoC2         = 1.494;    % pull towards the swarm's best
    opts.psoVmaxFrac   = 0.05;     % max speed per iteration = 5% of D
    opts.psoJitterFrac = [0.01 0.03 0.10];  % spread of seeded particles
    opts.psoCrossingPenalty = 1.0; % added to F per crossing (>> any feasible F)
    opts.psoSeed       = 1;        % random seed for repeatability

    % ---- Reporting -----------------------------------------------------------
    opts.verbose = true;

    % ---- Apply 'name', value overrides ----------------------------------------
    if mod(numel(varargin), 2) ~= 0
        error('busLayoutOptions:args', 'Overrides must be name/value pairs.');
    end
    for k = 1:2:numel(varargin)
        name = varargin{k};
        if ~isfield(opts, name)
            error('busLayoutOptions:unknown', 'Unknown option "%s".', name);
        end
        opts.(name) = varargin{k + 1};
    end
end
