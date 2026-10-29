function grid = rasterGrid(xy, opts)
%RASTERGRID Pixel grid covering a set of points in local km coordinates.
%
%   grid = busLayout.rasterGrid(xy, opts)
%
%   xy     N x 2 [x y] points (km) relative to the area's centre; rows with
%          NaN (e.g. polygon part separators) are ignored
%   grid   .offset        1x2 shift that puts the points' bounding box at
%                         (margin, margin), so all grid coordinates are >= 0
%                         (grid xy = xy - offset)
%          .width_km      grid width  = bounding-box width  + 2 margins
%          .height_km     grid height = bounding-box height + 2 margins
%          .pixelSize_km  side of a square pixel, chosen so the grid holds
%                         about opts.targetPixels pixels
%          .nx, .ny       number of pixel columns and rows
%
%   Shared by coverageFromAddresses and coverageFromPolygon.

    ok = all(isfinite(xy), 2);
    grid.offset = min(xy(ok, :), [], 1) - opts.margin_km;
    shifted = xy(ok, :) - grid.offset;
    grid.width_km  = max(shifted(:, 1)) + opts.margin_km;
    grid.height_km = max(shifted(:, 2)) + opts.margin_km;
    grid.pixelSize_km = sqrt(grid.width_km * grid.height_km / opts.targetPixels);
    grid.nx = ceil(grid.width_km  / grid.pixelSize_km);
    grid.ny = ceil(grid.height_km / grid.pixelSize_km);
end
