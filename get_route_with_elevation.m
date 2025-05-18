function routeData = get_route_with_elevation(origin, destination, apiKey)
% GET_ROUTE_WITH_ELEVATION Gets route and elevation data between two points
% Inputs:
%   origin, destination - Strings like 'City, Country' or lat,long
%   apiKey - Your Google Maps API key

    try
        %% Step 1: Get Directions from Google Maps
        fprintf('Fetching directions from Google Maps API...\n');
        baseUrl = 'https://maps.googleapis.com/maps/api/directions/json?';
        params = sprintf('origin=%s&destination=%s&key=%s', ...
                         urlencode(origin), urlencode(destination), apiKey);
        url = [baseUrl, params];

        % Request directions
        response = webread(url);
        
        % Check if we got any routes
        if isempty(response.routes)
            error('No route found between origin and destination.');
        end

        % Extract encoded polyline
        encodedPolyline = response.routes(1).overview_polyline.points;
        fprintf('Received polyline of length %d characters\n', length(encodedPolyline));

        %% Step 2: Decode Polyline into Lat/Lon Coordinates
        fprintf('Decoding polyline...\n');
        latlon = decodePolyline(encodedPolyline);  % Nx2 matrix [lat, lon]
        
        % Debug output
        fprintf('Number of decoded coordinates: %d\n', size(latlon, 1));
        fprintf('Sample coordinates (first 3 points):\n');
        for i = 1:min(3, size(latlon, 1))
            fprintf('  Point %d: (%.6f, %.6f)\n', i, latlon(i,1), latlon(i,2));
        end

        %% Step 3: Get Elevation Data
        fprintf('Preparing elevation API request...\n');
        
        % Restrict the number of points to avoid URL too long errors
        maxPoints = 300;
        if size(latlon, 1) > maxPoints
            % Sample points evenly along the route
            indices = round(linspace(1, size(latlon, 1), maxPoints));
            sampledLatLon = latlon(indices, :);
        else
            sampledLatLon = latlon;
        end
        
        % Create batches of coordinates to avoid URL length limits (max 512 characters)
        % Each API call can handle about 300-400 coordinates based on URL length limits
        batchSize = 100;
        numBatches = ceil(size(sampledLatLon, 1) / batchSize);
        allElevations = [];
        
        fprintf('Processing %d elevation API batches...\n', numBatches);
        
        for batch = 1:numBatches
            % Get start and end indices for this batch
            startIdx = (batch-1) * batchSize + 1;
            endIdx = min(batch * batchSize, size(sampledLatLon, 1));
            batchPoints = sampledLatLon(startIdx:endIdx, :);
            
            % Format coordinates for API call
            locations = cell(size(batchPoints, 1), 1);
            for i = 1:size(batchPoints, 1)
                locations{i} = sprintf('%.6f,%.6f', batchPoints(i,1), batchPoints(i,2));
            end
            latlonStr = strjoin(locations, '|');
            
            % Make elevation API call
            elevationBaseUrl = 'https://maps.googleapis.com/maps/api/elevation/json?';
            elevationParams = sprintf('locations=%s&key=%s', latlonStr, apiKey);
            elevationUrl = [elevationBaseUrl, elevationParams];
            
            % Fetch elevation data
            fprintf('Making elevation API call for batch %d of %d (%d points)...\n', ...
                    batch, numBatches, size(batchPoints, 1));
            elevationResponse = webread(elevationUrl);
            
            % Check response status
            if ~strcmpi(elevationResponse.status, 'OK')
                error('Elevation API error: %s', elevationResponse.status);
            end
            
            % Extract elevations from this batch
            batchElevations = zeros(length(elevationResponse.results), 1);
            for i = 1:length(elevationResponse.results)
                batchElevations(i) = elevationResponse.results(i).elevation;
            end
            
            % Add to our collection
            allElevations = [allElevations; batchElevations];
        end

        %% Output Structure
        routeData.latlon = sampledLatLon;  % Use the same points as for elevation
        routeData.elevation = allElevations;
        
        fprintf('Successfully retrieved %d route points with elevations\n', length(allElevations));
        
    catch e
        fprintf('Error in get_route_with_elevation: %s\n', e.message);
        fprintf('Stack trace:\n');
        for i = 1:length(e.stack)
            fprintf('  %s (line %d)\n', e.stack(i).name, e.stack(i).line);
        end
        rethrow(e);
    end
end