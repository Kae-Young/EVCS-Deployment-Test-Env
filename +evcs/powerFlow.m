function pf = powerFlow(net, addP_kW, addQ_kvar)
%POWERFLOW Forward-backward sweep load flow of the radial feeder.
%
%   pf = evcs.powerFlow(net)                       base case
%   pf = evcs.powerFlow(net, addP_kW, addQ_kvar)   with extra constant-power
%                                                  load (33x1, by bus index;
%                                                  row 1 = substation, ignored)
%
%   Loads are constant power (EVCS included, as in the proposal).  The
%   substation is held at 1.0 p.u.
%
%   OUTPUT
%     pf.V        33x1 complex bus voltages (p.u.), row 1 = substation
%     pf.Vmag     |V|
%     pf.PL_kW    total real power loss  sum |I_v|^2 R_v
%     pf.QL_kvar  not computed (left out for speed)
%     pf.AVDI     (1/NB) sum |Vref - V_u| over all NB = 33 buses
%     pf.Vmin, pf.VminBus  lowest voltage and its IEEE bus number
%     pf.iter, pf.converged

    P = net.P0_pu; Q = net.Q0_pu;
    if nargin >= 2 && ~isempty(addP_kW)
        P = P + addP_kW(2:end) / net.Sbase_kVA;
    end
    if nargin >= 3 && ~isempty(addQ_kvar)
        Q = Q + addQ_kvar(2:end) / net.Sbase_kVA;
    end
    S = P + 1i * Q;

    V = ones(net.nBus - 1, 1);
    converged = false;
    for it = 1:net.maxIter
        I = conj(S ./ V);                 % load currents
        Vnew = 1 - net.DLF * I;           % V0 = 1 p.u.
        if max(abs(Vnew - V)) < net.tol
            V = Vnew; converged = true; break
        end
        V = Vnew;
    end
    I = conj(S ./ V);
    J = net.BIBC * I;                     % branch currents

    pf.V = [1; V];
    pf.Vmag = abs(pf.V);
    pf.PL_kW = sum(abs(J).^2 .* net.R_pu) * net.Sbase_kVA;
    pf.AVDI = mean(abs(1 - pf.Vmag));
    [pf.Vmin, k] = min(pf.Vmag);
    pf.VminBus = k - 1;
    pf.iter = it;
    pf.converged = converged;
end
