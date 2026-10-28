function buildGnafMaster(psvFile, outFile)
%BUILDGNAFMASTER Cull the full G-NAF .psv file into a compact .mat master.
%
%   buildGnafMaster(psvFile, outFile) reads the pipe-delimited G-NAF file
%   (e.g. australia_gnaf_core.psv, ~3.3 GB, 27 columns) and saves outFile
%   (e.g. gnaf_master.mat, ~220 MB) containing, for each address kept:
%       Latitude   double column vector
%       Longitude  double column vector
%       IsAlias    logical column vector - true for ALIAS addresses
%       Source     string describing how the file was made
%
%   Culling rules
%     * PRIMARY addresses are removed. These are the building-level address
%       of a unit complex (PRIMARY_SECONDARY = "PRIMARY"); each unit in the
%       complex is already listed as its own SECONDARY address, so keeping
%       the PRIMARY row would count the building as an extra dwelling.
%     * ALIAS addresses are kept but flagged with IsAlias. An alias
%       (ALIAS_PRINCIPAL = "ALIAS") is an alternative name for an address
%       already in the file (linked by PRINCIPAL_PID, ~99% at identical
%       coordinates), so they can be excluded later without rebuilding.
%     * All other columns (address text, IDs, etc.) are dropped.
%
%   Takes about a minute. The original .psv file is not modified.

    if nargin < 2 || strlength(string(outFile)) == 0
        outFile = fullfile(fileparts(psvFile), "gnaf_master.mat");
    end
    if ~isfile(psvFile)
        [srcDir, srcName, srcExt] = fileparts(psvFile);
        if strlength(string(srcDir)) == 0
            srcDir = pwd;
        end
        [~, outName, outExt] = fileparts(outFile);
        error("buildGnafMaster:noSource", ...
            "%s%s is missing and needs to be rebuilt from the original G-NAF data.\n\n" + ...
            "Please add %s%s to:\n%s", outName, outExt, srcName, srcExt, srcDir);
    end

    fprintf("Building %s from %s (about a minute)...\n", outFile, psvFile);
    t0 = tic;

    ds = tabularTextDatastore(psvFile, ...
        "FileExtensions", ".psv", ...
        "Delimiter", "|", ...
        "ReadSize", 500000);
    ds.SelectedVariableNames = {'ALIAS_PRINCIPAL', 'PRIMARY_SECONDARY', 'LATITUDE', 'LONGITUDE'};
    ds.SelectedFormats(1:2) = {'%C', '%C'};   % read the two flag columns as categorical

    latC = {}; lonC = {}; aliasC = {};
    nRead = 0;
    while hasdata(ds)
        c = read(ds);
        nRead = nRead + height(c);

        keep = ~(c.PRIMARY_SECONDARY == "PRIMARY") & ...
               isfinite(c.LATITUDE) & isfinite(c.LONGITUDE);

        latC{end+1, 1}   = c.LATITUDE(keep);                     %#ok<AGROW>
        lonC{end+1, 1}   = c.LONGITUDE(keep);                    %#ok<AGROW>
        aliasC{end+1, 1} = c.ALIAS_PRINCIPAL(keep) == "ALIAS";   %#ok<AGROW>
    end

    Latitude  = vertcat(latC{:});
    Longitude = vertcat(lonC{:});
    IsAlias   = vertcat(aliasC{:});
    [~, srcName, srcExt] = fileparts(psvFile);
    Source = sprintf("%s%s with PRIMARY (unit-complex building) addresses removed; " + ...
        "IsAlias marks alias rows. Built %s by buildGnafMaster.", ...
        srcName, srcExt, string(datetime("now")));

    outDir = fileparts(outFile);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(outFile, "Latitude", "Longitude", "IsAlias", "Source", "-v7");

    fprintf("Done in %.0f s: kept %d of %d addresses (%d flagged as aliases).\n", ...
        toc(t0), numel(Latitude), nRead, nnz(IsAlias));
end
