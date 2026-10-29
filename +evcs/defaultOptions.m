function opts = defaultOptions(varargin)
%DEFAULTOPTIONS Default settings for EVCS demand seeding and PSO placement.
%
%   opts = evcs.defaultOptions()                    every setting at its default
%   opts = evcs.defaultOptions('name', value, ...)  overrides individual settings
%
%   Follows proposal sections 3.3.1 (objectives) and 3.3.2 (site selection).
%   Same naming rules as busLayout.defaultOptions: physical quantities end
%   in their unit, fractions in Frac, switches start with use.
%
%   ------------------------------------------------------------------------
%   PIPELINE (one function per step)
%   ------------------------------------------------------------------------
%     1. seedDemand     dwellings -> vehicles -> EVs; EV households are the
%                       demand nodes (fixed seed, held constant across runs)
%     2. buildRoads     OSM drivable roads around the coverage as a graph
%                       (cached).  Falls back to straight-line distance.
%     3. buildContext   candidate sites (road points inside the coverage),
%                       road distance from every candidate to every demand
%                       node, the bus (electrical zone) of every candidate,
%                       and the base-case power flow
%     4. evaluate       snap stations to roads, run the power flow and score
%                       PL, AVDI, Davg, rho and the combined objective F
%     5. pso            particle swarm over the stations' x/y positions
%     6. runExperiment  1..8 stations x 30 runs -> best/worst/mean tables

    % ---- 1. Synthetic EV demand (proposal 3.3.2) ----------------------------
    % ABS 2021 Census: 91.3% of households have >= 1 vehicle, and 55.1% of
    % those have a second.  NTC: plug-in EVs are 1.67% of the light fleet and
    % 13% of 2024 new sales; 2% per vehicle allows minor growth.
    opts.pVehicle1   = 0.913;
    opts.pVehicle2   = 0.551;     % conditional on having a first vehicle
    opts.pEV         = 0.02;      % per vehicle
    opts.demandSeed  = 2026;      % demand is drawn ONCE and held constant
    % Each EV household is a demand node.  'ev' counts each EV as one
    % customer (a 2-EV household counts twice); 'household' counts 1.
    opts.customerUnit = 'ev';

    % ---- 2. Road layer --------------------------------------------------------
    opts.useRoads       = true;   % false = straight-line distances, no snapping to roads
    opts.roadMargin_km  = 0.3;    % roads fetched this far beyond the coverage
    opts.roadStep_km    = 0.02;   % long road segments split into <= 20 m pieces
    % OSM highway classes counted as places a car can drive and park beside.
    opts.roadClasses = ["motorway" "trunk" "primary" "secondary" "tertiary" ...
        "unclassified" "residential" "living_street" "service" ...
        "motorway_link" "trunk_link" "primary_link" "secondary_link" "tertiary_link"];
    opts.overpassUrls = ["https://overpass-api.de/api/interpreter" ...
                         "https://overpass.kumi.systems/api/interpreter"];
    opts.overpassTimeout_s = 120;
    opts.roadCacheDir = '';       % '' = <project>/data/cache

    % ---- 3. Stations and the network -------------------------------------------
    opts.totalCapacity_kVA = 800; % shared between the stations
    % 'equal'  : each of M stations gets totalCapacity / M
    % 'demand' : capacity proportional to the customers a station serves
    %            (rho is then the same for every layout - see evaluate.m)
    opts.sizing   = 'equal';
    opts.evcsPF   = 1.0;          % power factor of EVCS load (constant power)
    opts.Vbase_kV = 12.66;        % IEEE-33 base voltage
    opts.Sbase_MVA = 1;
    opts.pfTol    = 1e-9;         % forward-backward sweep tolerance (p.u.)
    opts.pfMaxIter = 50;

    % ---- 4. Objective (proposal 3.3.1) -----------------------------------------
    %   F = w1*f1 + w2*f2 + w3*f3 + w4*f4    (maximised)
    % with each f the reciprocal of its metric, NORMALISED so the four terms
    % are comparable (raw 1/PL [1/kW] and 1/AVDI differ by ~4 orders of
    % magnitude, so unnormalised weights would be meaningless):
    %   f1 = PL0 / PL        PL0   = real loss with no EVCS (202.7 kW)
    %   f2 = AVDI0 / AVDI    AVDI0 = AVDI with no EVCS
    %   f3 = Dref / Davg     Dref  = sqrt(coverage area) unless set below
    %   f4 = rhoRef / rho    rhoRef = customers / total capacity, i.e. the
    %                        value of rho if demand were perfectly balanced
    opts.weights = [0.25 0.25 0.25 0.25];
    opts.Dref_km = [];            % [] = cov.D
    % How rho is aggregated over stations:
    %   'max' : max_i N_i / S_i   (busiest station, customers per kVA)
    %   'sum' : sum_i N_i / S_i   (proposal's formula as written - NB with
    %                              'equal' sizing this is M*NT/Stotal for
    %                              every layout, so it cannot steer the PSO)
    opts.rhoMode = 'max';

    % ---- 5. PSO -----------------------------------------------------------------
    opts.psoParticles  = 40;
    opts.psoIterations = 200;
    opts.psoInertia    = 0.729;   % Clerc-Kennedy constriction
    opts.psoC1         = 1.494;
    opts.psoC2         = 1.494;
    opts.psoVmaxFrac   = 0.15;    % max speed per iteration = 15% of area width
    opts.psoStall      = 60;      % stop after this many iterations w/o gbest gain

    % ---- 6. Experiment (proposal 3.3.2) ------------------------------------------
    opts.stationCounts = 1:8;
    opts.runs          = 30;
    opts.useParallel   = false;   % parfor over runs (Parallel Computing Toolbox)
    opts.mapStations   = 4;       % station count whose best placement is drawn on the map

    % ---- 7. Sensitivity analysis (proposal 3.3.3) --------------------------------
    % The test routine above is repeated with the bus layout JUMBLED: every
    % bus moves the same distance in its own random direction
    % (evcs.perturbLayout).  The distance is a fraction of the coverage's
    % width D = sqrt(area), e.g. 0.05 = 5% of D (about 58 m for a 1.35 km^2
    % area).  Each magnitude is tried sensTrials times with different random
    % directions (seeds sensSeed, sensSeed+1, ...).  The unperturbed control
    % is always included.
    opts.sensMagnitudes_frac = [0.025 0.05 0.10];
    opts.sensTrials          = 5;
    opts.sensSeed            = 1;
    % Station counts and runs used for every perturbation (kept separate from
    % stationCounts / runs above, since the analysis repeats them per case).
    opts.sensStationCounts = 1:8;
    opts.sensRuns          = 30;

    % Results of the app's Identify EVCS Sites and Sensitivity Analysis runs
    % are also written to this folder as .xlsx + .mat ('' = <project>/results).
    opts.resultsDir = '';

    opts.verbose = true;

    % ---- Apply 'name', value overrides ---------------------------------------
    if mod(numel(varargin), 2) ~= 0
        error('evcs:defaultOptions:args', 'Overrides must be name/value pairs.');
    end
    for k = 1:2:numel(varargin)
        name = varargin{k};
        if ~isfield(opts, name)
            error('evcs:defaultOptions:unknown', 'Unknown option "%s".', name);
        end
        opts.(name) = varargin{k + 1};
    end
end
