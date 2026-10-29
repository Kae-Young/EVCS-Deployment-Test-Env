function [lat, lon] = toLatLon(cov, XY)
%TOLATLON The coverage's local km frame -> degrees.  XY is N x 2 [x y].
    g = cov.geo;
    lon = (XY(:, 1) + g.offset(1)) / g.kx + g.lon0;
    lat = (XY(:, 2) + g.offset(2)) / g.ky + g.lat0;
end
