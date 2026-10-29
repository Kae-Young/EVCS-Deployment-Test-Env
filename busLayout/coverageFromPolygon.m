function cov = coverageFromPolygon(polyLat, polyLon, opts)
%COVERAGEFROMPOLYGON Coverage area from a boundary polygon (e.g. suburb or
%coastline-bounded region you have drawn or loaded).
%
%   cov = coverageFromPolygon(polyLat, polyLon, opts)
%
%   polyLat, polyLon  polygon vertices in degrees (NaN-separated parts allowed)
%   opts              busLayoutOptions()
%
%   Every pixel whose centre lies inside the polygon is part of the coverage.
%   It is up to you to choose a polygon that holds about tree.dwellings
%   dwellings; nothing here checks that.

    polyLat = polyLat(:); polyLon = polyLon(:);
    ok = isfinite(polyLat) & isfinite(polyLon);
    lat0 = mean(polyLat(ok)); lon0 = mean(polyLon(ok));
    [kx, ky] = kmPerDegree(lat0);

    % Polygon in local km, shifted so its bounding box starts at (margin, margin).
    PX = (polyLon - lon0) * kx;
    PY = (polyLat - lat0) * ky;
    offset = [min(PX(ok)) min(PY(ok))] - opts.margin_km;
    PX = PX - offset(1); PY = PY - offset(2);
    W = max(PX(ok)) + opts.margin_km;
    H = max(PY(ok)) + opts.margin_km;

    % Pixel grid and inside test on pixel centres.
    cell = sqrt(W * H / opts.targetPixels);
    nx = ceil(W / cell); ny = ceil(H / cell);
    [CX, CY] = meshgrid(((1:nx) - 0.5) * cell, ((1:ny) - 0.5) * cell);
    mask = inpolygon(CX, CY, PX, PY);

    geo = struct('lat0', lat0, 'lon0', lon0, 'kx', kx, 'ky', ky, 'offset', offset);
    cov = finishCoverage(mask, cell, geo, opts);
    cov.addr = zeros(0, 2);
    cov.polygon = [PX PY];
end
