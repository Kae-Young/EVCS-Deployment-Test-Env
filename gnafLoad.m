function T = gnafLoad(srcFile, latLim, lonLim, keepVars, outFile)
% GNAFLOAD Load the G-NAF addresses inside a rectangular region, optionally
% saving the result to a .mat cache file.
%   srcFile  : either the culled master gnaf_master.mat (fast, ~1-2 s), or
%              the original pipe-delimited australia_gnaf_core.psv (slow, ~40 s)
%   latLim   : [latMin latMax]
%   lonLim   : [lonMin lonMax]
%   keepVars : (optional, .psv only) string array of extra columns to keep
%   outFile  : (optional) path of a .mat file to save the table to
%   T        : table of addresses inside the rectangle, with Latitude and
%              Longitude variables (plus IsAlias when loaded from the .mat master)
%
%   gnaf_master.mat holds Latitude, Longitude and IsAlias for every G-NAF
%   address except PRIMARY (unit-complex building) addresses, whose units are
%   already listed individually. IsAlias marks alias rows: alternative names
%   for an address that is already in the file, at the same location.

    if nargin < 4
        keepVars = [];
    end
    if nargin < 5
        outFile = "";
    end

    latLim = sort(latLim);
    lonLim = sort(lonLim);

    [~, ~, ext] = fileparts(srcFile);
    if strcmpi(ext, ".mat")
        T = loadFromMat(srcFile, latLim, lonLim);
    else
        T = loadFromPsv(srcFile, latLim, lonLim, keepVars);
    end

    % Save the truncated table
    if strlength(string(outFile)) > 0
        outDir = fileparts(outFile);
        if ~isempty(outDir) && ~isfolder(outDir)
            mkdir(outDir);
        end
        save(outFile, "T", "latLim", "lonLim");
    end
end


function T = loadFromMat(matFile, latLim, lonLim)
% Fast path: culled master with Latitude, Longitude and IsAlias arrays
    M = load(matFile, "Latitude", "Longitude", "IsAlias");

    inRect = M.Latitude  >= latLim(1) & M.Latitude  <= latLim(2) & ...
             M.Longitude >= lonLim(1) & M.Longitude <= lonLim(2);

    T = table(M.Latitude(inRect), M.Longitude(inRect), M.IsAlias(inRect), ...
        'VariableNames', {'Latitude', 'Longitude', 'IsAlias'});
end


function T = loadFromPsv(psvFile, latLim, lonLim, keepVars)
% Slow path: scan the original pipe-delimited G-NAF file in chunks
    if isempty(keepVars)
        keepVars = strings(1, 0);
    end
    keepVars = unique([string(keepVars), "LONGITUDE", "LATITUDE"], "stable");

    ds = tabularTextDatastore(psvFile, ...
        "FileExtensions", ".psv", ...
        "Delimiter", "|", ...
        "TextType", "string", ...
        "SelectedVariableNames", cellstr(keepVars), ...
        "ReadSize", 250000);

    chunks = {};
    while hasdata(ds)
        chunk = read(ds);

        % Rectangle test (rows with missing coordinates evaluate false)
        inRect = chunk.LATITUDE  >= latLim(1) & chunk.LATITUDE  <= latLim(2) & ...
                 chunk.LONGITUDE >= lonLim(1) & chunk.LONGITUDE <= lonLim(2);

        if any(inRect)
            chunks{end+1} = chunk(inRect, :); %#ok<AGROW>
        end
    end

    if isempty(chunks)
        T = table();
    else
        T = vertcat(chunks{:});
        T = renamevars(T, ["LATITUDE", "LONGITUDE"], ["Latitude", "Longitude"]);
    end
end
