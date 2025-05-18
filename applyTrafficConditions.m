
function speed_kmph = applyTrafficConditions(speed_kmph, trafficData)
% APPLYTRAFFICCONDITIONS Applies traffic conditions to speed profile
%
% Inputs:
%   speed_kmph - Array of speed limits in km/h
%   trafficData - Structure containing traffic information:
%       .congestionFactors - Array of factors (0-1) for each segment
%       .timeOfDay - Optional string ('morning', 'midday', 'evening', 'night')
%
% Output:
%   speed_kmph - Adjusted speed array after applying traffic conditions

    % Default traffic model (mild congestion) if no specific data
    if nargin < 2 || isempty(trafficData)
        % Apply default 10% reduction for mild traffic
        speed_kmph = speed_kmph * 0.9;
        return;
    end
    
    % Apply segment-specific congestion factors if available
    if isfield(trafficData, 'congestionFactors')
        congestionFactors = trafficData.congestionFactors;
        
        % Make sure congestion factors have the right size
        if length(congestionFactors) == length(speed_kmph)
            speed_kmph = speed_kmph .* congestionFactors;
        elseif length(congestionFactors) < length(speed_kmph)
            % Pad with last value
            padding = length(speed_kmph) - length(congestionFactors);
            congestionFactors = [congestionFactors; 
                                 ones(padding, 1) * congestionFactors(end)];
            speed_kmph = speed_kmph .* congestionFactors;
        else
            % Truncate
            congestionFactors = congestionFactors(1:length(speed_kmph));
            speed_kmph = speed_kmph .* congestionFactors;
        end
    end
    
    % Apply time-of-day effects if specified
    if isfield(trafficData, 'timeOfDay')
        switch lower(trafficData.timeOfDay)
            case 'morning'
                % Morning rush hour (reduces speed more in urban areas)
                urbanIdx = speed_kmph < 60;
                speed_kmph(urbanIdx) = speed_kmph(urbanIdx) * 0.7;
                
            case 'evening'
                % Evening rush hour (even slower)
                urbanIdx = speed_kmph < 60;
                speed_kmph(urbanIdx) = speed_kmph(urbanIdx) * 0.6;
                
            case 'night'
                % Night (less traffic but slower for safety)
                speed_kmph = speed_kmph * 0.95;
                
            case 'midday'
                % Midday (slight reduction)
                speed_kmph = speed_kmph * 0.9;
        end
    end
    
    % Ensure minimum speed is not too low (avoid unrealistic crawling)
    speed_kmph = max(speed_kmph, 5);
end

