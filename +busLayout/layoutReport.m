function txt = layoutReport(res, cov, opts)
%LAYOUTREPORT Text summary of a generate result (for the app's
%output box, the command window or a log file).
%
%   txt = layoutReport(res, cov, opts)
%
%   SHARE DEVIATION
%   Every bus's target share is its share of the feeder's active load; its
%   actual share is the fraction of the coverage area in its zone.  The
%   deviation is actual - target, in percentage points of the total area:
%   +0.50 means the zone holds half a percent more of the area than the bus
%   holds of the load.
%
%   RELATIVE DEVIATION
%   The same deviation divided by the bus's own target share:
%       relative deviation = (actual - target) / target
%   e.g. a bus with a 1.62% target that gets 1.94% of the area is +20%: its
%   zone is a fifth too big.  This is the fair way to compare buses, because
%   a 0.3-point miss is trivial for an 11.3% bus but large for a 1.6% one.
%   The summary reports the largest and the average |relative deviation|.
%
%   Output layout
%     Bus placement complete in ... (summary lines)
%     <blank line>
%     Bus No: Target share | Actual share | Share deviation (%) |
%             Relative deviation (%) | Zone area (ha)
%     b1:  ... one line per bus ...
%   Lines starting "Bus No:" or "b<number>:" are shown in a fixed-width font
%   by outputBox.html, so the columns line up.

    dev = 100 * res.err;                         % percentage points, signed
    rel = 100 * res.err ./ res.target;           % % of each bus's own target, signed
    [maxRel, worst] = max(abs(rel));
    zoneArea_ha = res.share * cov.area * 100;    % km^2 -> hectares
    if opts.usePSO, how = 'on'; else, how = 'off'; end

    L = {};
    L{end+1} = sprintf('Bus placement complete in %.1f s (PSO refinement %s).', res.runtime_s, how);
    L{end+1} = sprintf(['Maximum relative share deviation: %.1f%% (bus %d), average relative share ' ...
                        'deviation: %.1f%%, total line length: %.2f km.'], ...
                        maxRel, worst, mean(abs(rel)), res.lineLength_km);
    L{end+1} = sprintf(['Coverage area: %.2f km%s, line crossings: %d, sharpest turn: %.0f%s ' ...
                        '(180%s = straight).'], cov.area, char(178), res.crossings, ...
                        res.sharpestTurn_deg, char(176), char(176));
    L{end+1} = sprintf('Substation (node 0) at %.5f, %.5f; best of %d starting layouts: %s.', ...
                        res.lat(1), res.lon(1), numel(res.startsF), strtrim(res.startTag));
    L{end+1} = '';
    % Header and rows share one format, so the columns line up in a
    % fixed-width font: bus label, then five right-aligned columns.
    fmt = '%-8s%12s | %12s | %19s | %22s | %14s';
    L{end+1} = sprintf(fmt, 'Bus No:', 'Target share', 'Actual share', ...
                       'Share deviation (%)', 'Relative deviation (%)', 'Zone area (ha)');
    for k = 1:numel(res.target)
        L{end+1} = sprintf(fmt, sprintf('b%d:', k), ...
            sprintf('%.2f%%', 100 * res.target(k)), sprintf('%.2f%%', 100 * res.share(k)), ...
            sprintf('%+.2f', dev(k)), sprintf('%+.1f', rel(k)), ...
            sprintf('%.2f', zoneArea_ha(k))); %#ok<AGROW>
    end
    txt = strjoin(L, newline);
end
