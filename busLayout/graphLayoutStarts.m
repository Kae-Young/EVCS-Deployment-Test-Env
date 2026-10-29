function starts = graphLayoutStarts(cov, tree, opts)
%GRAPHLAYOUTSTARTS Candidate starting layouts drawn from the feeder graph.
%
%   starts = graphLayoutStarts(cov, tree, opts)
%
%   starts(k).Q    33x2 layout (km), snapped onto coverage pixels
%   starts(k).tag  e.g. 'KK  +x+y' or 'KKw -x+y' (which variant it is)
%
%   STEP 1 - DRAW THE TREE (Kamada-Kawai)
%   -------------------------------------
%   Kamada & Kawai (1989) draw a graph by treating every PAIR of nodes as a
%   spring whose natural length is their distance through the graph
%   (number of lines between them, or a weighted version), and finding the
%   positions where the springs are least stretched:
%
%        minimise  sum_{i<j}  w_ij (|x_i - x_j| - d_ij)^2,   w_ij = d_ij^-2
%
%   For a tree this produces a clean, uncrossed drawing in which the feeder
%   spreads out evenly.  The energy is minimised here by stress
%   majorisation (Gansner, Koren & North, 2004), which solves exactly the
%   same Kamada-Kawai energy but by a simple repeated linear update that is
%   guaranteed to go downhill and needs no tuning.
%
%   Two versions of the ideal line length are used:
%     'KK'  plain:          every line has length 1
%     'KKw' load-weighted:  line length = mean(sqrt(t_parent), sqrt(t_child))
%                           where t = target area share.  A zone of area A
%                           is roughly sqrt(A) across, so heavily loaded buses
%                           are pushed further from their neighbours.
%
%   STEP 2 - FIT THE DRAWING TO THE COVERAGE AREA
%   ---------------------------------------------
%   The drawing has arbitrary scale and orientation.  Both point clouds (the
%   33 drawn nodes and the coverage pixels) are reduced to their centre and
%   principal axes (via SVD).  The drawing is rotated so its long axis lies
%   along the coverage's long axis, and stretched so its spread (standard
%   deviation) along each axis matches the coverage's.
%
%   STEP 3 - FOUR MIRROR IMAGES
%   ---------------------------
%   Principal axes have no preferred direction, so the drawing can be
%   flipped along either axis.  All 4 combinations are kept; they give
%   genuinely different starting points (e.g. which end of the suburb the
%   main feeder runs to) and the best one is chosen after correction.
%
%   Finally every layout is snapped onto distinct coverage pixels and any
%   start that already has crossing lines is dropped.

    variants = {'KK', false};
    if opts.useWeightedStarts
        variants(end + 1, :) = {'KKw', true};
    end
    if opts.useReflections
        flips = [1 1; -1 1; 1 -1; -1 -1];
    else
        flips = [1 1];
    end

    % Substation's ideal "size" for the weighted version: it has no zone, so
    % give it a small value (a quarter of the smallest zone) rather than 0.
    t = [0.25 * min(tree.target); tree.target];

    starts = struct('Q', {}, 'tag', {});
    for v = 1:size(variants, 1)
        % ---- Ideal length of each line.
        if variants{v, 2}
            len = (sqrt(t(tree.br(:, 1))) + sqrt(t(tree.br(:, 2)))) / 2;
        else
            len = ones(size(tree.br, 1), 1);
        end
        X = kamadaKawai(tree, len, opts.kkIterations);

        for f = 1:size(flips, 1)
            Q = fitToCoverage(X, cov, flips(f, :));

            % Optional fixed substation: shift the whole drawing so bus 0
            % lands on the requested point (shape and orientation kept).
            if ~isempty(opts.substationLatLon)
                s = fromLatLon(cov, opts.substationLatLon(1), opts.substationLatLon(2));
                Q = Q + (s - Q(1, :));
            end

            Q = snapToPixels(cov, Q);
            if countCrossings(Q, tree) == 0
                starts(end + 1).Q = Q; %#ok<AGROW>
                starts(end).tag = sprintf('%-3s %+dx%+dy', variants{v, 1}, flips(f, 1), flips(f, 2));
            end
        end
    end
    if isempty(starts)
        error('graphLayoutStarts:none', 'Every starting layout had crossing lines.');
    end
end


function X = kamadaKawai(tree, len, iters)
% Kamada-Kawai layout of the tree by stress majorisation (SMACOF).

    n = tree.n;
    % ---- Graph distance between every pair of nodes: sum of the ideal line
    %      lengths along the (unique) path between them.  Floyd-Warshall is
    %      plenty fast for 33 nodes.
    d = inf(n);
    d(1:n + 1:end) = 0;
    for k = 1:size(tree.br, 1)
        a = tree.br(k, 1); b = tree.br(k, 2);
        d(a, b) = len(k); d(b, a) = len(k);
    end
    for m = 1:n
        d = min(d, d(:, m) + d(m, :));
    end

    % ---- Spring stiffness: short springs are stiff, long ones are slack.
    w = d.^-2;
    w(1:n + 1:end) = 0;

    % ---- Starting guess: classical multidimensional scaling (the 2-D picture
    %      whose straight-line distances best match d).  Deterministic, so the
    %      whole method gives the same answer every run.
    J = eye(n) - ones(n) / n;
    Bc = -0.5 * J * (d.^2) * J;
    Bc = (Bc + Bc') / 2;
    [V, E] = eig(Bc);
    [ev, order] = sort(diag(E), 'descend');
    X = V(:, order(1:2)) .* sqrt(max(ev(1:2)', 0));

    % ---- Majorisation: X_new = Lw^+ * B(X) * X.
    %      Lw is the weighted graph Laplacian (fixed), B(X) depends on the
    %      current distances.  Each update can only lower the KK energy.
    Lw = -w;
    Lw(1:n + 1:end) = sum(w, 2);
    LwInv = pinv(Lw);
    prevStress = inf;
    for it = 1:iters
        dist = sqrt(max(sum(X.^2, 2) + sum(X.^2, 2)' - 2 * (X * X'), 0));
        B = -w .* d ./ max(dist, 1e-12);
        B(1:n + 1:end) = 0;
        B(1:n + 1:end) = -sum(B, 2);
        X = LwInv * (B * X);
        stress = sum(sum(w .* (dist - d).^2)) / 2;
        if abs(prevStress - stress) < 1e-9 * max(stress, 1), break; end
        prevStress = stress;
    end
end


function Q = fitToCoverage(X, cov, flip)
% Rotate, stretch, mirror and move the drawing X onto the coverage area.
    [cX, axX, sdX] = frame(X);
    [cC, axC, sdC] = frame(cov.pix);
    U = (X - cX) * axX';            % drawing in its own principal axes
    U = U ./ sdX .* flip;           % unit spread, optionally mirrored
    Q = (U .* sdC) * axC + cC;      % coverage spread, coverage axes, centre
end

function [c, ax, sd] = frame(P)
% Centre, principal axes (rows of ax) and spread along each axis.
    c = mean(P, 1);
    [~, S, V] = svd(P - c, 'econ');
    ax = V';
    sd = diag(S)' / sqrt(size(P, 1));
end
