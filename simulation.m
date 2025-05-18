


% BEV Trip Energy Simulation - Main Script (Fixed Version)
% This script runs the BEV Trip Energy Simulation with fixes for all identified issues

%% Setup and Configuration
clear;
clc;
close all;

% Define your Google Maps API key
apiKey = 'APIKEY'; % Replace with your actual key (optional for this demo)

% Define trip origin and destination
origin = 'San Francisco, CA';
destination = 'Palo Alto, CA';

% Define vehicle parameters
vehicleParams = struct(...
    'mass', 1800, ...            % Vehicle mass in kg
    'frontalArea', 2.3, ...      % Frontal area in m²
    'dragCoefficient', 0.28, ... % Aerodynamic drag coefficient
    'rollingResistance', 0.015, ... % Rolling resistance coefficient
    'wheelRadius', 0.33, ...     % Wheel radius in m
    'batteryCapacity', 60, ...   % Battery capacity in kWh
    'motorPower', 150, ...       % Motor power in kW
    'auxPower', 1.5, ...         % Auxiliary power in kW (A/C, electronics, etc.)
    'regenerativeEfficiency', 0.7 ... % Efficiency of regenerative braking
);

%% Step 1: Get Route Data from Google Maps API
fprintf('Step 1: Acquiring route data from Google Maps API...\n');

% For demonstration, we'll use pre-defined route data
% In practice, you would call: routeData = getRouteData(origin, destination, apiKey);

% Example route data structure (simulated)
routeData = struct();
routeData.origin = origin;
routeData.destination = destination;

% Create sample route points (lat, lon)
% This would normally come from Google Maps API
numPoints = 100;
routeData.latlon = [
    37.7749, -122.4194;  % San Francisco
    37.7647, -122.4124;
    37.7447, -122.4104;
    37.7247, -122.4084;
    37.6879, -122.4016;
    37.6519, -122.4056;
    37.5519, -122.3156;
    37.5012, -122.2419;
    37.4419, -122.1430;
    37.4419, -122.1419   % Palo Alto
];

% Interpolate to get more points
interpFactor = ceil(numPoints / size(routeData.latlon, 1));
routeData.latlon = interp1(1:size(routeData.latlon, 1), routeData.latlon, linspace(1, size(routeData.latlon, 1), numPoints));

% Create sample elevation data
% This would normally come from Google Maps Elevation API
baseElevation = 10;
routeData.elevation = baseElevation + 100 * sin(linspace(0, 2*pi, numPoints))';

% Sample distance and estimated time
routeData.totalDistance = 58000;  % 58 km
routeData.totalDuration = 3600;   % 1 hour

% Create sample traffic data (optional)
trafficData = struct();
trafficData.congestionFactors = 0.7 + 0.3 * rand(numPoints-1, 1);  % Random traffic conditions
trafficData.timeOfDay = 'midday';  % Time of day for traffic model

% Display route summary
fprintf('Route from %s to %s:\n', origin, destination);
fprintf('Distance: %.1f km\n', routeData.totalDistance/1000);
fprintf('Estimated duration: %.1f minutes\n', routeData.totalDuration/60);

%% Step 2: Generate Driving Cycle from Route Data
fprintf('\nStep 2: Generating driving cycle from route data...\n');

try
    % Call the fixed generateDrivingCycle function with traffic data
    drivingCycle = generateDrivingCycle(routeData, trafficData);
    
    % Print driving cycle summary
    fprintf('Driving cycle generated:\n');
    fprintf('Total distance: %.1f km\n', drivingCycle.totalDistance/1000);
    fprintf('Total time: %.1f minutes\n', drivingCycle.totalTime/60);
    fprintf('Average speed: %.1f km/h\n', drivingCycle.averageSpeed * 3.6);
catch e
    fprintf('Error in generating driving cycle: %s\n', e.message);
    fprintf('Error details: %s\n', getReport(e));
    return;
end

%% Step 3: Create BEV Model
fprintf('\nStep 3: Creating BEV model...\n');

% Call the createBEVModel function
try
    bevModel = createBEVModel(vehicleParams);
    fprintf('BEV model created: %s\n', bevModel.modelName);
catch e
    fprintf('Error creating BEV model: %s\n', e.message);
    fprintf('Continuing with simulation using synthetic data...\n');
end

%% Step 4: Simulate Energy Consumption
fprintf('\nStep 4: Simulating energy consumption...\n');

% Extract driving cycle data
t = drivingCycle.time;
speed = drivingCycle.speed;
grade = drivingCycle.grade;

% Physical constants
g = 9.81;                   % gravitational constant (m/s²)
rho = 1.225;                % air density (kg/m³)

% Extract vehicle parameters
m = vehicleParams.mass;
Cd = vehicleParams.dragCoefficient;
A = vehicleParams.frontalArea;
Crr = vehicleParams.rollingResistance;

% Calculate forces and power at each time step
aeroPower = 0.5 * rho * Cd * A * speed.^3;  % Aerodynamic drag power (W)
rollPower = Crr * m * g * cos(deg2rad(grade)) .* speed;  % Rolling resistance power (W)
gradePower = m * g * sin(deg2rad(grade)) .* speed;  % Grade resistance power (W)
auxPower = vehicleParams.auxPower * 1000 * ones(size(speed)); % Auxiliary power (W)

% Total power (W)
totalPower = aeroPower + rollPower + gradePower + auxPower;

% Apply drivetrain efficiency (approximately 90% efficient in drive mode)
driveIdx = totalPower > 0;
totalPower(driveIdx) = totalPower(driveIdx) / 0.9;

% Set negative power (regenerative braking) with efficiency factor
regenIdx = totalPower < 0;
totalPower(regenIdx) = totalPower(regenIdx) * vehicleParams.regenerativeEfficiency;

% Calculate energy (Wh) at each step
dt = diff([0; t]);
energyWh = totalPower .* dt / 3600;

% Calculate cumulative energy consumption (Wh)
cumulativeEnergyWh = cumsum(energyWh);

% Calculate SOC (%)
initialSOC = 100;
batteryCapacityWh = vehicleParams.batteryCapacity * 1000;
SOC = initialSOC - 100 * cumulativeEnergyWh / batteryCapacityWh;
SOC = max(SOC, 0);  % Ensure SOC doesn't go below 0%

%% Step 5: Calculate and Display Performance Metrics
fprintf('\nStep 5: Calculating performance metrics...\n');

% Calculate efficiency metrics
finalSOC = SOC(end);
SOCdrop = initialSOC - finalSOC;

% Calculate energy consumed (kWh)
energyConsumedWh = vehicleParams.batteryCapacity * 1000 * SOCdrop / 100;
energyConsumedkWh = energyConsumedWh / 1000;

% Calculate efficiency (Wh/km)
totalDistanceKm = routeData.totalDistance / 1000;
efficiencyWhKm = energyConsumedWh / totalDistanceKm;

% Calculate range estimate based on full battery
estimatedRangeKm = (vehicleParams.batteryCapacity * 1000) / efficiencyWhKm;

% Calculate trip cost (assuming electricity cost of $0.15 per kWh)
electricityCost = 0.15; % $ per kWh
tripCost = energyConsumedkWh * electricityCost;

% Calculate CO2 emissions saved compared to ICE vehicle
avgICEEmissions = 120; % g CO2/km for average gasoline car
electricityEmissionFactor = 450; % g CO2/kWh (depends on electricity source)
evEmissions = electricityEmissionFactor * energyConsumedkWh / totalDistanceKm;
co2Saved = (avgICEEmissions - evEmissions) * totalDistanceKm / 1000; % kg CO2

% Display performance metrics
fprintf('\nPerformance Metrics:\n');
fprintf('------------------------------------------\n');
fprintf('Total distance: %.1f km\n', totalDistanceKm);
fprintf('Total time: %.1f minutes\n', t(end)/60);
fprintf('Initial SOC: %.1f%%\n', initialSOC);
fprintf('Final SOC: %.1f%%\n', finalSOC);
fprintf('SOC used: %.1f%%\n', SOCdrop);
fprintf('Energy consumed: %.2f kWh\n', energyConsumedkWh);
fprintf('Energy efficiency: %.1f Wh/km\n', efficiencyWhKm);
fprintf('Estimated full range: %.1f km\n', estimatedRangeKm);
fprintf('Estimated trip cost: $%.2f\n', tripCost);
fprintf('CO2 emissions saved: %.1f kg\n', co2Saved);
fprintf('------------------------------------------\n');

%% Step 6: Visualize Results
fprintf('\nStep 6: Creating visualizations...\n');

% Create a figure to show key results
figure('Name', 'BEV Trip Energy Simulation Results', 'Position', [100, 100, 900, 700]);

% 1. Speed and elevation profile
subplot(2, 2, 1);
yyaxis left;
plot(t/60, speed*3.6, 'b-', 'LineWidth', 1.5);
ylabel('Speed (km/h)');
yyaxis right;
plot(t/60, interp1(linspace(0, t(end), length(routeData.elevation)), routeData.elevation, t), 'r-', 'LineWidth', 1.5);
ylabel('Elevation (m)');
xlabel('Time (minutes)');
title('Speed and Elevation Profile');
grid on;

% 2. Battery State of Charge
subplot(2, 2, 2);
plot(t/60, SOC, 'g-', 'LineWidth', 2);
ylabel('Battery SOC (%)');
xlabel('Time (minutes)');
title('Battery State of Charge');
grid on;
ylim([max(0, min(SOC)-5), 100]);

% 3. Power consumption
subplot(2, 2, 3);
plot(t/60, totalPower/1000, 'b-', 'LineWidth', 1.5);
ylabel('Power (kW)');
xlabel('Time (minutes)');
title('Power Consumption');
grid on;
hold on;
plot([0, t(end)/60], [0, 0], 'k--');
hold off;

% 4. Energy breakdown
subplot(2, 2, 4);
% Calculate energy components in kWh
aeroEnergy = sum(aeroPower .* dt) / 3600 / 1000;
rollEnergy = sum(rollPower .* dt) / 3600 / 1000;
gradeEnergy = sum(gradePower .* dt) / 3600 / 1000;
auxEnergy = sum(auxPower .* dt) / 3600 / 1000;

% Only include positive values for the pie chart (energy consumed)
energyComponents = [max(0, aeroEnergy), max(0, rollEnergy), max(0, gradeEnergy), auxEnergy];
labels = {'Aerodynamic', 'Rolling', 'Grade', 'Auxiliary'};

% Filter out zero or negative components
nonZeroIdx = energyComponents > 0;
pie(energyComponents(nonZeroIdx), labels(nonZeroIdx));
title('Energy Consumption Breakdown (kWh)');

% Add a title with summary
sgtitle(sprintf('BEV Trip: %s to %s (%.1f km, %.1f kWh)', ...
    origin, destination, totalDistanceKm, energyConsumedkWh), ...
    'FontSize', 14, 'FontWeight', 'bold');

%% Step 7: Export Results (optional)
fprintf('\nStep 7: Exporting results to workspace...\n');

% Create results structure to export
results = struct();
results.routeInfo = routeData;
results.drivingCycle = drivingCycle;
results.vehicle = vehicleParams;
results.energy = struct(...
    'totalPower', totalPower, ...
    'aeroPower', aeroPower, ...
    'rollPower', rollPower, ...
    'gradePower', gradePower, ...
    'auxPower', auxPower, ...
    'energyWh', energyWh, ...
    'cumulativeEnergyWh', cumulativeEnergyWh, ...
    'SOC', SOC);
results.performance = struct(...
    'initialSOC', initialSOC, ...
    'finalSOC', finalSOC, ...
    'energyConsumedkWh', energyConsumedkWh, ...
    'efficiencyWhKm', efficiencyWhKm, ...
    'estimatedRangeKm', estimatedRangeKm, ...
    'tripCost', tripCost, ...
    'co2Saved', co2Saved);

% Export to workspace
simulationResults = results;

fprintf('\nSimulation completed successfully!\n');

