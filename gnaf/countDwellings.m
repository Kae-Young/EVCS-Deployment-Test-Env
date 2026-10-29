function [count, inside] = countDwellings(dwellingTable, polygonLatLon)
%COUNTDWELLINGS Count dwellings inside a polygon.
%
%   [count, inside] = countDwellings(dwellingTable, polygonLatLon)
%
%   dwellingTable : table with Latitude and Longitude variables
%   polygonLatLon : N-by-2 array of [lat lon] vertices
%   count         : number of dwellings inside (or on the edge of) the polygon
%   inside        : logical vector, one entry per table row

    polyLat = polygonLatLon(:,1);
    polyLon = polygonLatLon(:,2);

    lat = dwellingTable.Latitude;
    lon = dwellingTable.Longitude;

    % Bounding-box prefilter so inpolygon only runs on nearby points
    inBox = lat >= min(polyLat) & lat <= max(polyLat) & ...
            lon >= min(polyLon) & lon <= max(polyLon);

    inside = false(height(dwellingTable), 1);
    inside(inBox) = inpolygon(lat(inBox), lon(inBox), polyLat, polyLon);

    count = nnz(inside);
end
