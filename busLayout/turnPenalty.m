function [pen, ang, G] = turnPenalty(Q, tree, opts)
%TURNPENALTY Penalty for sharp turns and cramped branch splits (hairpins).
%
%   [pen, ang]    = turnPenalty(Q, tree, opts)
%   [pen, ang, G] = turnPenalty(Q, tree, opts)   also returns the gradient
%
%   For every angle check in tree.triples (see ieee33Tree), the angle at the
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

    pen = penaltyOnly(Q, tree, opts);
    if nargout > 1
        [~, ang] = penaltyOnly(Q, tree, opts);
    end
    if nargout > 2
        span = max(max(Q, [], 1) - min(Q, [], 1));
        h = 1e-4 * span;                           % finite-difference step
        G = zeros(size(Q));
        for k = 2:tree.n                           % the substation never moves
            for dim = 1:2
                Qh = Q; Qh(k, dim) = Qh(k, dim) + h;
                G(k, dim) = (penaltyOnly(Qh, tree, opts) - pen) / h;
            end
        end
    end
end


function [pen, ang] = penaltyOnly(Q, tree, opts)
    T = tree.triples;
    u = Q(T(:, 1), :) - Q(T(:, 2), :);              % middle bus -> first end
    w = Q(T(:, 3), :) - Q(T(:, 2), :);              % middle bus -> second end
    c = sum(u .* w, 2) ./ (sqrt(sum(u.^2, 2)) .* sqrt(sum(w.^2, 2)) + 1e-12);
    ang = acosd(min(max(c, -1), 1));                % angle in degrees
    lim = opts.turnLimit_deg * ones(size(ang));
    lim(T(:, 4) == 1) = opts.siblingLimit_deg;
    h = max(0, (lim - ang) ./ lim);
    pen = sum(h.^2);
end
