function XY = fromLatLon(cov, lat, lon)
%FROMLATLON Degrees -> the coverage's local km frame.  XY = [x y], N x 2.
    g = cov.geo;
    XY = [(lon(:) - g.lon0) * g.kx - g.offset(1), ...
          (lat(:) - g.lat0) * g.ky - g.offset(2)];
end
