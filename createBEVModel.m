function bevModel = createBEVModel(vehicleParams)
% CREATEBEVMODEL Creates a Battery Electric Vehicle model for simulation
% This function serves as an interface to the Virtual Vehicle Composer
%
% Input:
%   vehicleParams - Structure with vehicle parameters:
%     .mass (kg)
%     .frontalArea (m²)
%     .dragCoefficient
%     .rollingResistance
%     .wheelRadius (m)
%     .batteryCapacity (kWh)
%     .motorPower (kW)
%     .auxPower (kW) - Power consumption of auxiliary systems
%     .regenerativeEfficiency - Efficiency of regenerative braking (0-1)
%
% Output:
%   bevModel - Structure containing the configured BEV model

    % Default parameters if not provided
    if nargin < 1
        vehicleParams = struct();
    end
    
    % Set default values for missing parameters
    defaultParams = struct(...
        'mass', 1800, ...                  % Vehicle mass in kg
        'frontalArea', 2.3, ...            % Frontal area in m²
        'dragCoefficient', 0.28, ...       % Aerodynamic drag coefficient
        'rollingResistance', 0.015, ...    % Rolling resistance coefficient
        'wheelRadius', 0.33, ...           % Wheel radius in m
        'batteryCapacity', 60, ...         % Battery capacity in kWh
        'motorPower', 150, ...             % Motor power in kW
        'auxPower', 1.5, ...               % Auxiliary power in kW
        'regenerativeEfficiency', 0.7 ...  % Efficiency of regenerative braking
    );
    
    fieldNames = fieldnames(defaultParams);
    for i = 1:numel(fieldNames)
        if ~isfield(vehicleParams, fieldNames{i})
            vehicleParams.(fieldNames{i}) = defaultParams.(fieldNames{i});
        end
    end
    
    % Check if Virtual Vehicle Composer is installed
    if ~exist('vehiclecomposer.utils.Configuration', 'class')
        warning(['Virtual Vehicle Composer not found. ', ...
                'Please install it or ensure it is on the MATLAB path.']);
        fprintf(['This function is designed to interface with Virtual Vehicle Composer.\n', ...
                'Since it is not available, a simplified BEV model will be created instead.\n']);
        
        % Create a simplified BEV model structure
        bevModel = createSimplifiedBEVModel(vehicleParams);
        return;
    end
    
    try
        % Create model using Virtual Vehicle Composer API
        fprintf('Initializing Virtual Vehicle Composer...\n');
        
        % Create configuration and vehicle object
        config = vehiclecomposer.utils.Configuration();
        vehicle = vehiclecomposer.Vehicle(config);
        
        % Set vehicle parameters
        vehicle.setParameter('VehicleMass', vehicleParams.mass);
        vehicle.setParameter('FrontalArea', vehicleParams.frontalArea);
        vehicle.setParameter('DragCoefficient', vehicleParams.dragCoefficient);
        vehicle.setParameter('RollingResistance', vehicleParams.rollingResistance);
        vehicle.setParameter('WheelRadius', vehicleParams.wheelRadius);
        
        % Configure powertrain as BEV
        powertrain = vehicle.getPowertrain();
        powertrain.setType('BEV');
        
        % Configure battery
        battery = powertrain.getBattery();
        battery.setParameter('Capacity', vehicleParams.batteryCapacity);
        battery.setParameter('InitialSOC', 100);  % Start with full battery
        
        % Configure electric motor
        motor = powertrain.getElectricMachine();
        motor.setParameter('PeakPower', vehicleParams.motorPower);
        
        % Configure regenerative braking
        brakes = vehicle.getBrakes();
        brakes.setParameter('RegenerativeEfficiency', vehicleParams.regenerativeEfficiency);
        
        % Configure auxiliary power consumers
        aux = vehicle.getAuxiliaries();
        aux.setParameter('PowerConsumption', vehicleParams.auxPower);
        
        % Export the model to Simulink
        fprintf('Exporting BEV model to Simulink...\n');
        modelName = 'BEVModel';
        exportedModel = vehicle.export(modelName);
        
        % Return the model information
        bevModel = struct();
        bevModel.modelName = modelName;
        bevModel.params = vehicleParams;
        bevModel.exportedModel = exportedModel;
        
        fprintf('BEV model created successfully!\n');
        
    catch e
        warning('Error creating BEV model with Virtual Vehicle Composer');
        fprintf('Creating simplified BEV model instead.\n');
        
        % Fall back to simplified model
        bevModel = createSimplifiedBEVModel(vehicleParams);
    end
end

function bevModel = createSimplifiedBEVModel(params)
    % Create a simplified BEV model when Virtual Vehicle Composer isn't available
    
    % Create model name with timestamp to avoid conflicts
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    modelName = ['SimplifiedBEVModel_', timestamp];
    
    % Create new Simulink model
    close_system(modelName, 0);  % Close if exists, without saving
    new_system(modelName);
    open_system(modelName);
    
    fprintf('Creating simplified BEV model in Simulink...\n');
    
    try
        % Add driving cycle source
        add_block('powertrain_lib/Drive Cycle Source', [modelName, '/DrivingCycle']);
        
        % Add vehicle dynamics block
        add_block('powertrainlib/Vehicle Body', [modelName, '/VehicleBody']);
        set_param([modelName, '/VehicleBody'], ...
            'Mass', num2str(params.mass), ...
            'FrontalArea', num2str(params.frontalArea), ...
            'DragCoefficient', num2str(params.dragCoefficient), ...
            'RollingResistanceCoefficient', num2str(params.rollingResistance));
            
        % Add electric motor
        add_block('powertrainlib/Electric Motor', [modelName, '/ElectricMotor']);
        set_param([modelName, '/ElectricMotor'], 'PeakPower', num2str(params.motorPower * 1000));  % Convert to W
            
        % Add battery
        add_block('powertrainlib/Battery', [modelName, '/Battery']);
        set_param([modelName, '/Battery'], ...
            'NominalCapacity', num2str(params.batteryCapacity * 3600), ...  % Convert kWh to kJ
            'InitialSOC', '100');  % Start with full battery
            
        % Add auxiliary power subsystem
        add_block('simulink/Sources/Constant', [modelName, '/AuxiliaryPower']);
        set_param([modelName, '/AuxiliaryPower'], 'Value', num2str(params.auxPower * 1000));  % Convert to W
            
        % Add energy management controller
        add_block('simulink/Ports & Subsystems/Subsystem', [modelName, '/EnergyController']);
            
        % Add scopes for monitoring
        add_block('simulink/Sinks/Scope', [modelName, '/Speed_Scope']);
        add_block('simulink/Sinks/Scope', [modelName, '/SOC_Scope']);
        add_block('simulink/Sinks/Scope', [modelName, '/Power_Scope']);
            
        % Connect blocks (simplified connections)
        add_line(modelName, 'DrivingCycle/1', 'VehicleBody/1');
        add_line(modelName, 'VehicleBody/1', 'ElectricMotor/1');
        add_line(modelName, 'ElectricMotor/1', 'Battery/1');
        add_line(modelName, 'AuxiliaryPower/1', 'Battery/2');
        add_line(modelName, 'VehicleBody/1', 'Speed_Scope/1');
        add_line(modelName, 'Battery/1', 'SOC_Scope/1');
        add_line(modelName, 'ElectricMotor/2', 'Power_Scope/1');
            
        % Save model
        save_system(modelName);
            
        fprintf('Simplified BEV model created successfully!\n');
    catch e
        warning('Error creating simplified BEV model');
    end
    
    % Return model information
    bevModel = struct();
    bevModel.modelName = modelName;
    bevModel.params = params;
    bevModel.isSimplified = true;
end