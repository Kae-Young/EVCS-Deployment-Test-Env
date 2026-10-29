function net = buildNetwork(tree, branches, opts)
%BUILDNETWORK Precompute the matrices for a fast forward-backward sweep.
%
%   net = evcs.buildNetwork(tree, branches, opts)
%
%   tree      busLayout.buildFeederTree (indices 1..33, 1 = substation)
%   branches  networkData33Bus branch table (R_ohm, X_ohm, same row order
%             as tree.br)
%   opts      evcs.defaultOptions()
%
%   FORWARD-BACKWARD SWEEP IN MATRIX FORM (Teng's BIBC / BCBV method)
%   For a radial feeder with load currents I (one per non-substation bus):
%     backward sweep:  branch currents  J  = BIBC * I
%                      BIBC(k,j) = 1 if bus j is at or below the branch k
%     forward sweep:   voltage drops    dV = BCBV * J
%                      BCBV(j,k) = Z_k if branch k is on the path to bus j
%   so  V = V0 - DLF * I  with  DLF = BCBV * BIBC.  Each sweep iteration is
%   then one 32x32 matrix-vector product, which keeps thousands of PSO
%   evaluations cheap.  It is exactly the same calculation as the
%   loop-based sweep used by Bharathi and Kirthiga [6].
%
%   OUTPUT
%     net.nBus, net.nBr      33, 32
%     net.P0_pu, net.Q0_pu   base loads at buses 2..33 (p.u.)
%     net.R_pu               32x1 branch resistance (p.u.)
%     net.BIBC, net.DLF      as above
%     net.Sbase_kVA          to convert p.u. power to kVA

    nBus = tree.n; nBr = size(tree.br, 1);
    Zbase = opts.Vbase_kV^2 / opts.Sbase_MVA;          % ohm
    R = double(branches.R_ohm(:)) / Zbase;
    X = double(branches.X_ohm(:)) / Zbase;
    Z = R + 1i * X;

    % Load index j = bus index - 1 (bus 2 -> 1, ..., bus 33 -> 32).
    % Branch k feeds bus tree.br(k,2); find the branch feeding each bus.
    feedBr = zeros(nBus, 1);
    feedBr(tree.br(:, 2)) = 1:nBr;

    BIBC = zeros(nBr, nBus - 1);
    for b = 2:nBus                      % walk from bus b up to the substation
        k = b;
        while k ~= 1
            BIBC(feedBr(k), b - 1) = 1;
            k = tree.parent(k);
        end
    end
    BCBV = BIBC.' .* Z.';               % (bus j, branch k) = Z_k on j's path

    net.nBus = nBus; net.nBr = nBr;
    net.Sbase_kVA = opts.Sbase_MVA * 1000;
    net.P0_pu = tree.P_kW(2:end)   / net.Sbase_kVA;
    net.Q0_pu = tree.Q_kvar(2:end) / net.Sbase_kVA;
    net.R_pu = R;
    net.BIBC = BIBC;
    net.DLF = BCBV * BIBC;
    net.tol = opts.pfTol;
    net.maxIter = opts.pfMaxIter;
end
