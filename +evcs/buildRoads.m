function roads = buildRoads(cov, opts)
%BUILDROADS Drivable OpenStreetMap roads around the coverage, as a graph.
%
%   roads = evcs.buildRoads(cov, opts)
%
%   Downloads the OSM "highway" ways of the classes in opts.roadClasses
%   inside the coverage's bounding box plus opts.roadMargin_km, from the
%   Overpass API, and caches them in data/cache/roads_<bbox>.mat so later
%   runs (and the 30 x 8 experiment) never touch the network.  The margin
%   matters: the shortest road path between two points inside the area can
%   leave it.
%
%   GRAPH
%   Road segments longer than opts.roadStep_km are split into equal pieces
%   so there is a candidate siting point at least every ~20 m along every
%   road (proposal 3.3.2: "roads are the only allowable siting location").
%   Edge weights are segment lengths in km.  Only the largest connected
%   piece is kept, so every pair of points has a road path.
%
%   OUTPUT  (empty [] if roads are unavailable - callers fall back to
%            straight-line distance)
%     roads.xy      P x 2 road points (km, coverage frame)
%     roads.G       graph over those points, Weight = km
%     roads.nWays   ways downloaded;  roads.source  cache file or URL
%     roads.latLim, roads.lonLim

    roads = [];
    if ~opts.useRoads, return; end

    % ---- Bounding box in degrees (grid corners + margin).
    [ny, nx] = size(cov.mask);
    W = nx * cov.pixelSize_km; H = ny * cov.pixelSize_km; m = opts.roadMargin_km;
    [la, lo] = busLayout.toLatLon(cov, [-m -m; W + m H + m]);
    latLim = sort(la(:))'; lonLim = sort(lo(:))';

    cacheDir = opts.roadCacheDir;
    if isempty(cacheDir)
        cacheDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data', 'cache');
    end
    if ~isfolder(cacheDir), mkdir(cacheDir); end
    key = sprintf('roads_%.4f_%.4f_%.4f_%.4f', latLim(1), lonLim(1), latLim(2), lonLim(2));
    key = strrep(strrep(key, '-', 'm'), '.', 'p');
    cacheFile = fullfile(cacheDir, [key '.mat']);

    if isfile(cacheFile)
        S = load(cacheFile, 'nodeId', 'nodeLat', 'nodeLon', 'ways');
        source = cacheFile;
    else
        [S, source] = download(latLim, lonLim, opts);
        if isempty(S)
            warning('evcs:buildRoads:unavailable', ...
                'Could not download OSM roads; using straight-line distances instead.');
            return
        end
        save(cacheFile, '-struct', 'S');
    end

    % ---- Node lookup, then densified edge list in km.
    xyNode = busLayout.fromLatLon(cov, S.nodeLat, S.nodeLon);
    [ids, ord] = sort(S.nodeId(:));
    xyNode = xyNode(ord, :);
    pts = xyNode;                       % grows as segments are split
    s = zeros(0, 1); t = zeros(0, 1); w = zeros(0, 1);
    step = opts.roadStep_km;
    for k = 1:numel(S.ways)
        [ok, loc] = ismember(S.ways{k}(:), ids);
        loc = loc(ok);
        for e = 1:numel(loc) - 1
            a = loc(e); b = loc(e + 1);
            if a == b, continue; end
            L = norm(pts(b, :) - pts(a, :));
            nSeg = max(1, ceil(L / step));
            if nSeg == 1
                s(end + 1, 1) = a; t(end + 1, 1) = b; w(end + 1, 1) = L; %#ok<AGROW>
            else
                f = (1:nSeg - 1)' / nSeg;
                newPts = pts(a, :) + f .* (pts(b, :) - pts(a, :));
                newIdx = size(pts, 1) + (1:nSeg - 1)';
                pts = [pts; newPts]; %#ok<AGROW>
                chain = [a; newIdx; b];
                s = [s; chain(1:end - 1)]; t = [t; chain(2:end)]; %#ok<AGROW>
                w = [w; repmat(L / nSeg, nSeg, 1)]; %#ok<AGROW>
            end
        end
    end

    G = graph(s, t, w, size(pts, 1));
    G = simplify(G, 'min');
    bins = conncomp(G);
    big = mode(bins(degree(G)' > 0));
    keep = find(bins == big);
    G = subgraph(G, keep);

    roads.xy = pts(keep, :);
    roads.G = G;
    roads.nWays = numel(S.ways);
    roads.source = source;
    roads.latLim = latLim; roads.lonLim = lonLim;
    if opts.verbose
        fprintf('  Roads: %d OSM ways -> %d road points, %.1f km of road (%s)\n', ...
            roads.nWays, numnodes(G), sum(G.Edges.Weight), source);
    end
end


function [S, source] = download(latLim, lonLim, opts)
% Overpass query: drivable ways in the box, then their nodes.
    S = []; source = '';
    cls = strjoin(opts.roadClasses, '|');
    q = sprintf(['[out:json][timeout:%d];' ...
        'way["highway"~"^(%s)$"]["access"!~"private|no"](%.6f,%.6f,%.6f,%.6f);' ...
        'out body;>;out skel qt;'], ...
        opts.overpassTimeout_s, cls, latLim(1), lonLim(1), latLim(2), lonLim(2));
    wo = weboptions('Timeout', opts.overpassTimeout_s, 'ContentType', 'json');
    for u = opts.overpassUrls
        try
            if opts.verbose, fprintf('  Downloading OSM roads from %s ...\n', u); end
            r = webwrite(char(u), 'data', q, wo);
            S = parse(r.elements);
            source = char(u);
            return
        catch err
            if opts.verbose, fprintf('    failed: %s\n', err.message); end
        end
    end
end


function S = parse(el)
% webread returns a struct array when every element has the same fields,
% otherwise a cell array of structs.  Normalise to a cell array.
    if isstruct(el), el = num2cell(el); end
    isNode = cellfun(@(e) strcmp(e.type, 'node'), el);
    nodes = [el{isNode}];
    S.nodeId  = [nodes.id]';
    S.nodeLat = [nodes.lat]';
    S.nodeLon = [nodes.lon]';
    wayEl = el(cellfun(@(e) strcmp(e.type, 'way'), el));
    S.ways = cellfun(@(e) double(e.nodes(:)), wayEl, 'UniformOutput', false);
end
