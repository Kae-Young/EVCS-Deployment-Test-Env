function C = sensitivityCases(opts)
%SENSITIVITYCASES The cases of the sensitivity analysis (proposal 3.3.3).
%
%   C = evcs.sensitivityCases(opts)
%
%   Case 1 is the control (the layout as created).  Then, for every
%   magnitude in opts.sensMagnitudes_frac, opts.sensTrials random jumbles
%   (evcs.perturbLayout): every bus moves magnitude * sqrt(coverage area) in
%   its own random direction.  Jumble seeds are opts.sensSeed + 0, 1, 2, ...
%   in case order, so each case is repeatable on its own.
%
%   C is a table: Case, Name, Magnitude (fraction), Trial, Seed.

    mags = opts.sensMagnitudes_frac(:)';
    nT = opts.sensTrials;
    n = 1 + numel(mags) * nT;
    Name = strings(n, 1); Mag = zeros(n, 1); Trial = zeros(n, 1); Seed = zeros(n, 1);
    Name(1) = "Control";
    k = 1;
    for m = mags
        for t = 1:nT
            k = k + 1;
            Name(k) = sprintf('Jumble %g%% #%d', 100 * m, t);
            Mag(k) = m; Trial(k) = t; Seed(k) = opts.sensSeed + k - 2;
        end
    end
    C = table((1:n)', Name, Mag, Trial, Seed, ...
        'VariableNames', {'Case', 'Name', 'Magnitude', 'Trial', 'Seed'});
end
