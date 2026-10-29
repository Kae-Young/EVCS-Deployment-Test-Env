function [n, buses] = countCrossings(busXY, tree)
%COUNTCROSSINGS Number of pairs of feeder lines that cross each other.
%
%   [n, buses] = countCrossings(busXY, tree)
%
%   n      number of crossing line pairs
%   buses  indices of every bus at either end of a crossing line (used by
%          correctLayout to know which moves to undo)
%
%   Each line is the straight segment between a bus and its parent.  Only
%   pairs of lines with four distinct end buses are tested (tree.crossPairs):
%   lines that share a bus always meet there and that is not a crossing.
%
%   Two segments AB and CD cross properly when C and D lie on opposite sides
%   of line AB AND A and B lie on opposite sides of line CD.  "Which side" is
%   the sign of the 2-D cross product (orientation test).

    P = tree.crossPairs;
    A = busXY(tree.br(P(:, 1), 1), :);  B = busXY(tree.br(P(:, 1), 2), :);
    C = busXY(tree.br(P(:, 2), 1), :);  D = busXY(tree.br(P(:, 2), 2), :);

    hit = orient(A, B, C) .* orient(A, B, D) < 0 & ...
          orient(C, D, A) .* orient(C, D, B) < 0;
    n = sum(hit);
    if nargout > 1
        buses = unique([tree.br(P(hit, 1), :); tree.br(P(hit, 2), :)]);
    end
end


function s = orient(p, q, r)
% Sign of the cross product (q - p) x (r - p): +1 if r is left of p->q,
% -1 if right, 0 if the three points are in a line.
    s = sign((q(:, 1) - p(:, 1)) .* (r(:, 2) - p(:, 2)) - ...
             (q(:, 2) - p(:, 2)) .* (r(:, 1) - p(:, 1)));
end
