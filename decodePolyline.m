function latlon = decodePolyline(encoded)
% DECODEPOLYLINE Decodes a Google Maps encoded polyline string into an Nx2 array of coordinates
%   This function decodes a polyline string encoded using Google's algorithm
%   See: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
%
%   Input:
%       encoded - String containing the encoded polyline
%   Output:
%       latlon - Nx2 array of [latitude, longitude] coordinates

    % Initialize variables
    points = [];
    index = 1;
    len = length(encoded);
    lat = 0;
    lng = 0;
    
    % Process the entire string
    while index <= len
        % Process latitude
        [dlat, index] = decodeValue(encoded, index);
        lat = lat + dlat;
        
        % Process longitude
        [dlng, index] = decodeValue(encoded, index);
        lng = lng + dlng;
        
        % Store the point (divide by 1e5 to convert to degrees)
        points = [points; lat/1e5, lng/1e5];
    end
    
    latlon = points;
end

function [value, index] = decodeValue(encoded, index)
    % DECODEVALUE Helper function to decode a single value from the polyline
    
    % Initialize variables
    result = 0;
    shift = 0;
    
    % Process chunks of 5 bits until we get a chunk with the continuation bit unset
    while true
        % Get the next byte
        b = double(encoded(index)) - 63;
        index = index + 1;
        
        % Extract the 5 data bits and add them to the result
        result = bitor(result, bitshift(bitand(b, 31), shift));
        shift = shift + 5;
        
        % If the continuation bit (bit 6) is not set, we're done with this value
        if bitand(b, 32) == 0
            break;
        end
    end
    
    % If the result is odd, it's negative; if even, it's positive
    if bitand(result, 1)
        value = -bitshift(bitshift(result, -1) + 1, 0); % Two's complement
    else
        value = bitshift(result, -1);
    end
end