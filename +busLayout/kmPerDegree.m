function [kx, ky] = kmPerDegree(lat0)
%KMPERDEGREE Kilometres per degree of longitude (kx) and latitude (ky) at lat0.
%   Flat-earth (equirectangular) approximation, accurate to well under 1% over
%   the few-km extent of a feeder area.
    kx = 111.32 * cosd(lat0);
    ky = 110.57;
end
