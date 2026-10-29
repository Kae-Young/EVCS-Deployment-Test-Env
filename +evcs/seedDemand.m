function demand = seedDemand(cov, opts)
%SEEDDEMAND Synthetic EV charging demand from the coverage's dwellings.
%
%   demand = evcs.seedDemand(cov, opts)
%
%   cov   coverage with dwellings attached (busLayout.coverageFromAddresses,
%         or busLayout.addDwellings for a drawn polygon) - uses cov.dwellXY
%   opts  evcs.defaultOptions()
%
%   METHOD (proposal 3.3.2)
%   Every dwelling is a household.  Independently for each household:
%     vehicle 1 with probability pVehicle1 (91.3%, ABS 2021 Census)
%     vehicle 2 with probability pVehicle2 (55.1%), only if it has vehicle 1
%     each vehicle is an EV with probability pEV (2%, NTC)
%   Every household with at least one EV is a demand node.
%
%   The draw uses its own random stream (opts.demandSeed), so the demand is
%   identical every time for the same coverage, whatever the global rng is
%   doing.  It is drawn once and then held constant across all PSO runs and
%   all sensitivity perturbations, as the proposal requires.
%
%   OUTPUT
%     demand.xy          K x 2 demand-node positions (km, coverage frame)
%     demand.nEV         K x 1 EVs at each node (1 or 2)
%     demand.weight      K x 1 customers at each node (nEV, or 1 per
%                        household if opts.customerUnit = 'household')
%     demand.NT          total customers = sum(weight)
%     demand.dwellingIdx K x 1 row of cov.dwellXY each node came from
%     demand.nHouseholds, .nVehicles, .nEV   totals, for reporting
%     demand.expectedEV  expected number of EVs for this many households

    if ~isfield(cov, 'dwellXY') || isempty(cov.dwellXY)
        error('evcs:seedDemand:noDwellings', ...
            'The coverage has no dwellings: build it with coverageFromAddresses or addDwellings.');
    end
    H = size(cov.dwellXY, 1);
    rs = RandStream('mt19937ar', 'Seed', opts.demandSeed);

    v1 = rand(rs, H, 1) < opts.pVehicle1;
    v2 = v1 & (rand(rs, H, 1) < opts.pVehicle2);
    nVeh = double(v1) + double(v2);
    ev1 = v1 & (rand(rs, H, 1) < opts.pEV);
    ev2 = v2 & (rand(rs, H, 1) < opts.pEV);
    nEV = double(ev1) + double(ev2);

    idx = find(nEV > 0);
    demand.xy = cov.dwellXY(idx, :);
    demand.nEV = nEV(idx);
    switch lower(opts.customerUnit)
        case 'ev',        demand.weight = demand.nEV;
        case 'household', demand.weight = ones(numel(idx), 1);
        otherwise, error('evcs:seedDemand:unit', 'Unknown customerUnit "%s".', opts.customerUnit);
    end
    demand.NT = sum(demand.weight);
    demand.dwellingIdx = idx;
    demand.nHouseholds = H;
    demand.nVehicles = sum(nVeh);
    demand.nEVtotal = sum(nEV);
    demand.expectedEV = H * opts.pVehicle1 * (1 + opts.pVehicle2) * opts.pEV;
    demand.seed = opts.demandSeed;

    if opts.verbose
        fprintf(['  Demand: %d households -> %d vehicles -> %d EVs at %d demand nodes ' ...
                 '(expected %.1f EVs)\n'], H, demand.nVehicles, demand.nEVtotal, ...
                 numel(idx), demand.expectedEV);
    end
end
