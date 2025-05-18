% test_run.m
% Test script for running the route elevation tool

% Clear workspace and close figures
clear;
close all;

% Set API key
apiKey = 'API key';  % Your Google Maps API key

% Define origin and destination
origin = 'Bangalore, India';
destination = 'Mysore, India';

try
    % Fetch route and elevation
    fprintf('\nFetching route from %s to %s...\n\n', origin, destination);
    routeData = get_route_with_elevation(origin, destination, apiKey);
    
    % Check if we got valid data
    if isempty(routeData) || size(routeData.latlon, 1) < 2
        error('Could not retrieve valid route data.');
    end
    
    fprintf('\nProcessing and visualizing route data...\n');
    
    % Calculate distance along the route
    distanceKm = zeros(size(routeData.latlon, 1), 1);
    for i = 2:size(routeData.latlon, 1)
        % Calculate distance using Haversine formula (approximate)
        lat1 = routeData.latlon(i-1,1);
        lon1 = routeData.latlon(i-1,2);
        lat2 = routeData.latlon(i,1);
        lon2 = routeData.latlon(i,2);
        
        % Convert to radians
        lat1 = lat1 * pi/180;
        lon1 = lon1 * pi/180;
        lat2 = lat2 * pi/180;
        lon2 = lon2 * pi/180;
        
        % Haversine formula
        R = 6371; % Earth's radius in km
        dLat = lat2 - lat1;
        dLon = lon2 - lon1;
        a = sin(dLat/2)^2 + cos(lat1) * cos(lat2) * sin(dLon/2)^2;
        c = 2 * atan2(sqrt(a), sqrt(1-a));
        d = R * c; % Distance in km
        
        distanceKm(i) = distanceKm(i-1) + d;
    end
    
    % Plot the route on a geographic map
    figure('Name', 'Route Map', 'Position', [100, 100, 800, 600]);
    
    % Check if geoplot is available (requires Mapping Toolbox)
    if exist('geoplot', 'file')
        % Use geoplot with basemap for nicer visualization
        geoplot(routeData.latlon(:,1), routeData.latlon(:,2), 'b-', 'LineWidth', 2);
        hold on;
        geoplot(routeData.latlon(1,1), routeData.latlon(1,2), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
        geoplot(routeData.latlon(end,1), routeData.latlon(end,2), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
        hold off;
        geobasemap('streets');
    else
        % Fallback to regular plot if geoplot is not available
        plot(routeData.latlon(:,2), routeData.latlon(:,1), 'b-', 'LineWidth', 2);
        hold on;
        plot(routeData.latlon(1,2), routeData.latlon(1,1), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
        plot(routeData.latlon(end,2), routeData.latlon(end,1), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
        hold off;
        axis equal;
        grid on;
    end
    
    title(sprintf('Route from %s to %s', origin, destination));
    
    % Plot elevation profile
    figure('Name', 'Elevation Profile', 'Position', [100, 100, 800, 400]);
    
    % Plot elevation vs distance
    plot(distanceKm, routeData.elevation, 'r-', 'LineWidth', 2);
    title('Elevation Profile Along Route');
    xlabel('Distance (km)');
    ylabel('Elevation (meters)');
    grid on;
    
    % Add a smoother elevation profile (moving average) if we have enough points
    if length(routeData.elevation) > 5
        hold on;
        window = 5; % Window size for moving average
        smoothElev = movmean(routeData.elevation, window);
        plot(distanceKm, smoothElev, 'b-', 'LineWidth', 1.5);
        legend('Raw Elevation', 'Smoothed Elevation');
        hold off;
    end
    
    % Display route information
    totalDistance = distanceKm(end);
    minElevation = min(routeData.elevation);
    maxElevation = max(routeData.elevation);
    elevationGain = sum(max(0, diff(routeData.elevation)));
    elevationLoss = abs(sum(min(0, diff(routeData.elevation))));
    
    fprintf('\nRoute Information:\n');
    fprintf('  Total Distance: %.2f km\n', totalDistance);
    fprintf('  Minimum Elevation: %.2f meters\n', minElevation);
    fprintf('  Maximum Elevation: %.2f meters\n', maxElevation);
    fprintf('  Elevation Range: %.2f meters\n', maxElevation - minElevation);
    fprintf('  Total Elevation Gain: %.2f meters\n', elevationGain);
    fprintf('  Total Elevation Loss: %.2f meters\n', elevationLoss);
    fprintf('  Average Elevation: %.2f meters\n', mean(routeData.elevation));
    
catch e
    % Display error information
    fprintf('\nError: %s\n', e.message);
    if isfield(e, 'stack')
        fprintf('Stack trace:\n');
        for i = 1:length(e.stack)
            fprintf('  File: %s, Line: %d, Function: %s\n', ...
                e.stack(i).file, e.stack(i).line, e.stack(i).name);
        end
    end
end