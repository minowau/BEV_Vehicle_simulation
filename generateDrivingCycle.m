



function drivingCycle = generateDrivingCycle(routeData, varargin)
% GENERATEDRIVINGCYCLE Converts route data to time-speed profile with grade calculation
% 
% Inputs:
%   routeData - Structure containing route information
%   varargin - Optional arguments:
%       'plot' - Boolean to enable plotting (default: false)
%       'trafficData' - Structure with traffic conditions
%
% Outputs:
%   drivingCycle - Structure with time, speed, distance, and grade data
%
% This function creates a realistic driving cycle based on route data,
% including speed profiles, elevation changes, and traffic conditions.

    % Default options
    plotEnabled = false;
    trafficData = [];

    % Parse optional arguments
    if nargin > 1
        if isstruct(varargin{1}) % Check if second argument is traffic data struct
            trafficData = varargin{1};
            varargin = varargin(2:end); % Remove traffic data from varargin
        end
        
        for i = 1:2:length(varargin)
            if ischar(varargin{i}) || (isstring(varargin{i}) && isscalar(varargin{i}))
                key = lower(char(varargin{i}));
                switch key
                    case 'plot'
                        if i+1 <= length(varargin)
                            plotEnabled = varargin{i+1};
                        end
                end
            end
        end
    end

    % Extract lat/lon coordinates
    lat = routeData.latlon(:,1);
    lon = routeData.latlon(:,2);
    
    % Get elevations (should be in routeData)
    if isfield(routeData, 'elevation')
        elevation = routeData.elevation;
    else
        % Default flat terrain if no elevation data
        elevation = zeros(size(lat));
    end

    % Calculate segment distances using haversine formula
    R = 6371000; % Earth's radius in meters
    lat1 = deg2rad(lat(1:end-1));
    lat2 = deg2rad(lat(2:end));
    dlat = lat2 - lat1;
    dlon = deg2rad(lon(2:end) - lon(1:end-1));
    a = sin(dlat/2).^2 + cos(lat1).*cos(lat2).*sin(dlon/2).^2;
    c = 2 * atan2(sqrt(a), sqrt(1-a));
    segmentDistances = R * c; % in meters

    % Calculate cumulative distance
    cumulativeDistance = [0; cumsum(segmentDistances)];
    
    % Calculate grade (elevation change / horizontal distance) in percent
    elevDiff = diff(elevation);
    grade = zeros(size(segmentDistances));
    for i = 1:length(segmentDistances)
        if segmentDistances(i) > 0
            grade(i) = (elevDiff(i) / segmentDistances(i)) * 100;
        else
            grade(i) = 0;
        end
    end
    % Add a final grade value to match dimensions
    grade = [grade; grade(end)];

    % Estimate speed limits based on segment distances
    speed_kmph = estimateSpeedLimits(segmentDistances); % in km/h
    
    % Apply traffic conditions if available
    if ~isempty(trafficData) && isfield(trafficData, 'congestionFactors')
        congestionFactors = trafficData.congestionFactors;
        % Adjust speeds based on congestion (congestion factors are between 0-1)
        % where 1 means no congestion and 0 means complete standstill
        speed_kmph = speed_kmph .* congestionFactors;
    end
    
    % Append last speed to match dimensions with other arrays
    speed_kmph = [speed_kmph; speed_kmph(end)];
    
    % Convert to m/s for calculations
    speedMS = speed_kmph * (1000/3600);

    % Calculate time for each segment
    timeDiffs = zeros(size(segmentDistances));
    for i = 1:length(segmentDistances)
        if speedMS(i+1) > 0 % Avoid division by zero
            timeDiffs(i) = segmentDistances(i) / speedMS(i+1);
        else
            timeDiffs(i) = 0;
        end
    end
    timeSeconds = [0; cumsum(timeDiffs)];

    % Create complete driving cycle information
    drivingCycle = struct();
    drivingCycle.time = timeSeconds;
    drivingCycle.speed = speedMS;
    drivingCycle.distance = cumulativeDistance;
    drivingCycle.grade = grade;
    drivingCycle.elevation = elevation;
    drivingCycle.totalDistance = cumulativeDistance(end);
    drivingCycle.totalTime = timeSeconds(end);
    drivingCycle.averageSpeed = drivingCycle.totalDistance / drivingCycle.totalTime;

    % Optional plotting
    if plotEnabled
        figure('Name', 'Driving Cycle');
        
        % Create subplots
        subplot(3,1,1);
        plot(drivingCycle.time/60, drivingCycle.speed*3.6);
        xlabel('Time (min)');
        ylabel('Speed (km/h)');
        title('Speed Profile');
        grid on;
        
        subplot(3,1,2);
        plot(drivingCycle.distance/1000, drivingCycle.elevation);
        xlabel('Distance (km)');
        ylabel('Elevation (m)');
        title('Elevation Profile');
        grid on;
        
        subplot(3,1,3);
        plot(drivingCycle.distance/1000, drivingCycle.grade);
        xlabel('Distance (km)');
        ylabel('Grade (%)');
        title('Road Grade');
        grid on;
        
        sgtitle('Generated Driving Cycle');
    end
end
