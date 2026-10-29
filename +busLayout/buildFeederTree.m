function tree = buildFeederTree(branches, buses, opts)
%BUILDFEEDERTREE Describe a radial feeder (IEEE-33 by default) as a tree
%for the layout functions.
%
%   tree = buildFeederTree()                      reads networkData33Bus()
%   tree = buildFeederTree(branches, buses)       uses tables you already loaded
%   tree = buildFeederTree(branches, buses, opts) also uses opts.admd_kVA
%
%   INDEXING CONVENTION (used by every function in the package)
%   ------------------------------------------------------------
%   networkData33Bus numbers the nodes 0..32 (0 = substation).  MATLAB arrays
%   start at 1, so here
%
%         array index k  <->  IEEE node number k-1
%
%   i.e. index 1 is the substation and indices 2..33 are buses 1..32.
%   A layout is always a 33x2 matrix busXY of [x y] positions in km, one row per
%   index.  Only rows 2..33 (the loaded buses) get Voronoi zones; row 1 (the
%   substation) has no load, so it gets no zone and is held fixed.
%
%   OUTPUT FIELDS
%   -------------
%     tree.n          33, number of nodes
%     tree.br         32x2 [parent child] pairs (array indices)
%     tree.parent     33x1, parent index of each node (0 for the substation)
%     tree.children   33x1 cell, child indices of each node
%     tree.P_kW       33x1 active load at each node
%     tree.Q_kvar     33x1 reactive load at each node
%     tree.zoneIdx    indices that get Voronoi zones (2..33)
%     tree.target     32x1 target area share for each zone = load share
%     tree.lateral    33x1 0 = main feeder, otherwise the index of the first
%                     bus of the lateral the node sits on (used for colours)
%     tree.nodeNo     33x1 IEEE node numbers (0..32) for labelling
%     tree.dwellings  feeder capacity in dwellings = |S_total| / ADMD
%     tree.triples    angle checks (see below)
%
%   ANGLE CHECKS (tree.triples)
%   ---------------------------
%   Each row [a n b isSibling] asks for the angle at node n between the
%   lines n->a and n->b:
%     isSibling = 0 : a = parent of n, b = a child of n   (a "turn")
%     isSibling = 1 : a and b are two children of n        (a "split")
%   turnPenalty uses these to penalise hairpins.

    if nargin < 2 || isempty(branches)
        [branches, ~, buses] = networkData33Bus();
    end
    if nargin < 3
        opts = busLayout.defaultOptions();
    end

    % ---- Branches: networkData33Bus stores FromNode = upstream (parent),
    %      ToNode = downstream (child), both 0-based -> add 1.
    par = double(branches.FromNode(:)) + 1;
    chi = double(branches.ToNode(:)) + 1;
    tree.n  = height(buses);
    tree.br = [par chi];

    tree.parent = zeros(tree.n, 1);
    tree.parent(chi) = par;
    tree.children = cell(tree.n, 1);
    for k = 1:size(tree.br, 1)
        tree.children{par(k)}(end + 1) = chi(k);
    end

    % ---- Loads: row i of the buses table is node i-1, which is already our
    %      array index i.
    tree.P_kW   = double(buses.PL_kW(:));
    tree.Q_kvar = double(buses.QL_kvar(:));

    % ---- Zones and their targets.  The target AREA share of each zone is its
    %      share of the total ACTIVE load (kW).  The substation (index 1) has
    %      no load and therefore no zone.
    tree.zoneIdx = 2:tree.n;
    tree.target  = tree.P_kW(tree.zoneIdx) / sum(tree.P_kW(tree.zoneIdx));

    % ---- Feeder capacity expressed as a number of dwellings:
    %      |S| = sqrt(P^2 + busXY^2) = sqrt(3715^2 + 2300^2) = 4369 kVA
    %      4369 kVA / 5 kVA per dwelling = 874 dwellings
    S_kVA = hypot(sum(tree.P_kW), sum(tree.Q_kvar));
    tree.dwellings = round(S_kVA / opts.admd_kVA);

    tree.nodeNo = (0:tree.n - 1)';

    % ---- Main feeder vs laterals (only used for colouring plots).
    %      The main feeder is taken as the longest path from the substation to
    %      a leaf.  Every other node belongs to the lateral that branches off
    %      that path; the lateral is named by its first bus.
    depth = zeros(tree.n, 1);
    order = treeOrder(tree);                       % parents before children
    for k = order(2:end)'
        depth(k) = depth(tree.parent(k)) + 1;
    end
    [~, deepest] = max(depth);
    onMain = false(tree.n, 1);
    k = deepest;
    while k > 0
        onMain(k) = true;
        k = tree.parent(k);
    end
    tree.lateral = zeros(tree.n, 1);
    for k = order(2:end)'
        if ~onMain(k)
            p = tree.parent(k);
            if onMain(p)
                tree.lateral(k) = k;               % first bus of a lateral
            else
                tree.lateral(k) = tree.lateral(p); % inherit from parent
            end
        end
    end

    % ---- Angle checks (see header).
    T = zeros(0, 4);
    for nIdx = 1:tree.n
        cs = tree.children{nIdx};
        if tree.parent(nIdx) > 0
            for c = cs
                T(end + 1, :) = [tree.parent(nIdx) nIdx c 0]; %#ok<AGROW>
            end
        end
        for i = 1:numel(cs)
            for j = i + 1:numel(cs)
                T(end + 1, :) = [cs(i) nIdx cs(j) 1]; %#ok<AGROW>
            end
        end
    end
    tree.triples = T;

    % ---- Branch pairs that could cross: two lines that share a bus always
    %      touch at that bus, so only pairs with four distinct buses count.
    nb = size(tree.br, 1);
    [I, J] = find(triu(true(nb), 1));
    keep = true(numel(I), 1);
    for k = 1:numel(I)
        keep(k) = numel(unique([tree.br(I(k), :) tree.br(J(k), :)])) == 4;
    end
    tree.crossPairs = [I(keep) J(keep)];
end


function order = treeOrder(tree)
% Breadth-first order from the substation: every parent comes before its
% children, so values can be propagated down the tree in one pass.
    order = zeros(tree.n, 1);
    order(1) = 1;
    head = 1; tail = 1;
    while head <= tail
        k = order(head); head = head + 1;
        for c = tree.children{k}
            tail = tail + 1;
            order(tail) = c;
        end
    end
end
