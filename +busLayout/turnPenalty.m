function [pen, ang, G] = turnPenalty(busXY, tree, opts)
%TURNPENALTY Penalty for sharp turns and cramped branch splits (hairpins).
%
%   [pen, ang]    = turnPenalty(busXY, tree, opts)
%   [pen, ang, G] = turnPenalty(busXY, tree, opts)   also returns the gradient
%
%   For every angle check in tree.triples (see buildFeederTree), the angle at the
%   middle bus between its two lines is measured.  If it is smaller than the
%   limit (opts.turnLimit_deg for turns, opts.siblingLimit_deg for splits),
%   the shortfall is counted:
%
%        h = (limit - angle) / limit        (0 when the angle is OK)
%        pen = sum(h.^2)
%
%   So a turn just under the limit costs almost nothing and a full hairpin
%   (angle near 0) costs 1.  Squaring makes the penalty smooth, so its
%   gradient is well behaved.
%
%   The gradient G (33x2) is taken by finite differences: each bus is nudged
%   by a tiny amount in x and in y and the change in penalty is measured.
%   That is 64 cheap evaluations - far cheaper than a Voronoi update - and
%   avoids a page of angle-derivative algebra.

    [pen, ang] = penaltyOnly(busXY, tree, opts);
    if nargout > 2
        span = max(max(busXY, [], 1) - min(busXY, [], 1));
        h = 1e-4 * span;                           % finite-difference step
        G = zeros(size(busXY));
        for k = 2:tree.n                           % the substation never moves
            for dim = 1:2
                nudgedXY = busXY; nudgedXY(k, dim) = nudgedXY(k, dim) + h;
                G(k, dim) = (penaltyOnly(nudgedXY, tree, opts) - pen) / h;
            end
        end
    end
end


function [pen, ang] = penaltyOnly(busXY, tree, opts)
    T = tree.triples;
    u = busXY(T(:, 1), :) - busXY(T(:, 2), :);              % middle bus -> first end
    w = busXY(T(:, 3), :) - busXY(T(:, 2), :);              % middle bus -> second end
    c = sum(u .* w, 2) ./ (sqrt(sum(u.^2, 2)) .* sqrt(sum(w.^2, 2)) + 1e-12);
    ang = acosd(min(max(c, -1), 1));                % angle in degrees
    lim = opts.turnLimit_deg * ones(size(ang));
    lim(T(:, 4) == 1) = opts.siblingLimit_deg;
    h = max(0, (lim - ang) ./ lim);
    pen = sum(h.^2);
end
