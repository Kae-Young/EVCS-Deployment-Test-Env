function [branches, tieLines, buses] = networkData33Bus()
%NETWORKDATA33BUS Network data of the 33-bus radial test system (Baran & Wu).
%
%   [branches, tieLines, buses] = networkData33Bus() returns three tables:
%
%   branches (32 rows) - line data only
%       BranchNo   Branch number
%       RecvNode   Upstream node, towards the substation (node 0 = substation)
%       SendNode   Downstream node fed by this branch
%       R_ohm      Branch resistance (ohm)
%       X_ohm      Branch reactance (ohm)
%
%   tieLines (5 rows) - normally-open tie switches
%       BranchNo, RecvNode, SendNode, R_ohm, X_ohm
%
%   buses (33 rows, nodes 0..32) - bus/load data
%       Node       Bus number (0 = substation)
%       PL_kW      Active load at the bus (kW)
%       QL_kvar    Reactive load at the bus (kvar)
%       VSquared   |V|^2 at the bus (p.u., base-case power flow)
%       Vmag       |V| at the bus (p.u.) = sqrt(VSquared)
%       PL_share   Fraction of total active load at this bus   (sums to 1)
%       QL_share   Fraction of total reactive load at this bus (sums to 1)
%       SL_share   Fraction of total apparent load (kVA) at this bus (sums to 1)
%   The substation (node 0) has no load; its voltage is taken as 1.0 p.u.
%
%   The source table lists each bus's load on the row of the branch that
%   feeds it (possible because the network is radial: every bus except the
%   substation has exactly one incoming branch). Here they are split apart.
%
%   Note: node numbering is 0-based as in the source table (0 = substation).
%   Row i of buses is node i-1, so buses(node+1,:) looks up a node, and
%   graph(branches.RecvNode+1, branches.SendNode+1) builds the network.

    % BrNo RcNd SnNd   r(ohm)  x(ohm)   PL(kW) QL(kvar) |V|^2
    B = [
         1    0    1   0.0922  0.0470   100     60     0.9927
         2    1    2   0.4930  0.2511    90     40     0.9574
         3    2    3   0.3660  0.1864   120     80     0.9374
         4    3    4   0.3811  0.1941    60     30     0.9176
         5    4    5   0.8190  0.7070    60     20     0.8707
         6    5    6   0.1872  0.6188   200    100     0.8641
         7    6    7   0.7114  0.2351   200    100     0.8550
         8    7    8   1.0300  0.7400    60     20     0.8432
         9    8    9   1.0440  0.7400    60     20     0.8324
        10    9   10   0.1966  0.0650    45     30     0.8308
        11   10   11   0.3744  0.1238    60     35     0.8280
        12   11   12   1.4680  1.1550    60     35     0.8167
        13   12   13   0.5416  0.7129   120     80     0.8125
        14   13   14   0.5910  0.5260    60     10     0.8099
        15   14   15   0.7463  0.5450    60     20     0.8074
        16   15   16   1.2890  1.7210    60     20     0.8037
        17   16   17   0.7320  0.5740    90     40     0.8026
        18    1   18   0.1640  0.1565    90     40     0.9916
        19   18   19   1.5042  1.3554    90     40     0.9845
        20   19   20   0.4095  0.4784    90     40     0.9831
        21   20   21   0.7089  0.9373    90     40     0.9818
        22    2   22   0.4512  0.3083    90     50     0.9504
        23   22   23   0.8980  0.7091   420    200     0.9373
        24   23   24   0.8960  0.7011   420    200     0.9309
        25    5   25   0.2030  0.1034    60     25     0.8643
        26   25   26   0.2842  0.1447    60     25     0.8557
        27   26   27   1.0590  0.9337    60     20     0.8201
        28   27   28   0.8042  0.7006   120     70     0.7945
        29   28   29   0.5075  0.2585   200    600     0.7816
        30   29   30   0.9744  0.9630   150     70     0.7739
        31   30   31   0.3105  0.3619   210    100     0.7723
        32   31   32   0.3410  0.5302    60     40     0.7717
    ];

    % ---- Branch (line) data ----
    branches = array2table(B(:,1:5), 'VariableNames', ...
        {'BranchNo','RecvNode','SendNode','R_ohm','X_ohm'});

    % ---- Bus data (load sits at the node each branch feeds) ----
    nNodes = 33;                         % nodes 0..32
    Node     = (0:nNodes-1)';
    PL_kW    = zeros(nNodes,1);
    QL_kvar  = zeros(nNodes,1);
    VSquared = ones(nNodes,1);           % substation = 1.0 p.u.
    idx = B(:,3) + 1;                    % SendNode -> row index
    PL_kW(idx)    = B(:,6);
    QL_kvar(idx)  = B(:,7);
    VSquared(idx) = B(:,8);

    buses = table(Node, PL_kW, QL_kvar, VSquared);
    buses.Vmag = sqrt(buses.VSquared);

    % Proportion of the total system load at each bus (sums to 1)
    buses.PL_share = buses.PL_kW   / sum(buses.PL_kW);      % active
    buses.QL_share = buses.QL_kvar / sum(buses.QL_kvar);    % reactive
    SL_kVA = hypot(buses.PL_kW, buses.QL_kvar);
    buses.SL_share = SL_kVA / sum(SL_kVA);                  % apparent

    % ---- Tie lines (normally open) ----
    % BrNo RcNd SnNd  r(ohm)  x(ohm)
    T = [
        33    7   20   2.0000  2.0000
        34    8   14   2.0000  2.0000
        35   11   21   2.0000  2.0000
        36   17   32   0.5000  0.5000
        37   24   28   0.5000  0.5000
    ];

    tieLines = array2table(T, 'VariableNames', ...
        {'BranchNo','RecvNode','SendNode','R_ohm','X_ohm'});
end
