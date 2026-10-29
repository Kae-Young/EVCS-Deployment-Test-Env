function cov = coverageFromPolygon(polyLat, polyLon, opts)
%COVERAGEFROMPOLYGON Coverage area from a boundary polygon (e.g. suburb or
%coastline-bounded region you have drawn or loaded).
%
%   cov = coverageFromPolygon(polyLat, polyLon, opts)
%
%   polyLat, polyLon  polygon vertices in degrees (NaN-separated parts allowed)
%   opts              defaultOptions()
%
%   Every pixel whose centre lies inside the polygon is part of the coverage.
%   It is up to you to choose a polygon that holds about tree.dwellings
%   dwellings; nothing here checks that.

    polyLat = polyLat(:); polyLon = polyLon(:);
    ok = isfinite(polyLat) & isfinite(polyLon);
    lat0 = mean(polyLat(ok)); lon0 = mean(polyLon(ok));
    [kx, ky] = busLayout.kmPerDegree(lat0);

    % Polygon in local km, shifted so its bounding box starts at (margin, margin).
    PX = (polyLon - lon0) * kx;
    PY = (polyLat - lat0) * ky;
    grid = busLayout.rasterGrid([PX PY], opts);
    PX = PX - grid.offset(1); PY = PY - grid.offset(2);

    % Pixel grid and inside test on pixel centres.
    pixelSize_km = grid.pixelSize_km;
    nx = grid.nx; ny = grid.ny;
    [CX, CY] = meshgrid(((1:nx) - 0.5) * pixelSize_km, ((1:ny) - 0.5) * pixelSize_km);
    mask = inpolygon(CX, CY, PX, PY);

    geo = struct('lat0', lat0, 'lon0', lon0, 'kx', kx, 'ky', ky, 'offset', grid.offset);
    cov = busLayout.finishCoverage(mask, pixelSize_km, geo, opts);
    cov.addr = zeros(0, 2);
    cov.polygon = [PX PY];
end
