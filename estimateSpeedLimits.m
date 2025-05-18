
function speedLimits = estimateSpeedLimits(distances)
% ESTIMATESPEEDLIMITS Assigns speed limits based on segment lengths
%
% Input:
%   distances - Array of segment distances in meters
%
% Output:
%   speedLimits - Estimated speed limits in km/h
%
% This function uses segment length as a proxy for road type:
% - Very short segments (<100m): Local roads (30 km/h)
% - Short segments (100-300m): Urban roads (50 km/h)
% - Medium segments (300-1000m): Suburban/regional roads (70 km/h)
% - Long segments (1000-2000m): Major roads (90 km/h)
% - Very long segments (>2000m): Highways (110 km/h)

    % Initialize speed limits array
    speedLimits = zeros(size(distances));
    
    % Add small random variations to make speed profile more natural (±5 km/h)
    randomVariation = 5 * (rand(size(distances)) - 0.5);
    
    % Assign speed limits based on segment lengths
    for i = 1:length(distances)
        if distances(i) < 100        % Very short segments (local roads)
            baseSpeed = 30;
        elseif distances(i) < 300    % Short segments (urban roads)
            baseSpeed = 50;
        elseif distances(i) < 1000   % Medium segments (suburban/regional roads)
            baseSpeed = 70;
        elseif distances(i) < 2000   % Long segments (major roads)
            baseSpeed = 90;
        else                         % Very long segments (highways)
            baseSpeed = 110;
        end
        
        % Apply random variation but keep within reasonable limits
        speedLimits(i) = max(min(baseSpeed + randomVariation(i), baseSpeed + 10), baseSpeed - 10);
    end
    
    % Smooth the speed limits to avoid unrealistic jumps
    % Use a simple moving average filter (3-point)
    if length(speedLimits) > 2
        smoothedLimits = speedLimits;
        for i = 2:length(speedLimits)-1
            smoothedLimits(i) = mean(speedLimits(i-1:i+1));
        end
        speedLimits = smoothedLimits;
    end
end