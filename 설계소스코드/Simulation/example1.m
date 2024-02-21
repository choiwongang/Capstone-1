function [allData, scenario, sensors] = example1()
%example2 - Returns sensor detections
%    allData = example2 returns sensor detections in a structure
%    with time for an internally defined scenario and sensor suite.
%
%    [allData, scenario, sensors] = example2 optionally returns
%    the drivingScenario and detection generator objects.

% Generated by MATLAB(R) 23.2 (R2023b) and Automated Driving Toolbox 23.2 (R2023b).
% Generated on: 06-Dec-2023 06:45:55

% Create the drivingScenario object and ego car
[scenario, egoVehicle] = createDrivingScenario;

% Create all the sensors
[sensors, numSensors] = createSensors(scenario);

allData = struct('Time', {}, 'ActorPoses', {}, 'ObjectDetections', {}, 'LaneDetections', {}, 'PointClouds', {}, 'INSMeasurements', {});
running = true;
while running

    % Generate the target poses of all actors relative to the ego vehicle
    poses = targetPoses(egoVehicle);
    time  = scenario.SimulationTime;

    objectDetections = {};
    laneDetections   = [];
    ptClouds = {};
    insMeas = {};
    isValidTime = false(1, numSensors);
    isValidLaneTime = false(1, numSensors);
    isValidPointCloudTime = false(1, numSensors);
    isValidINSTime = false(1, numSensors);

    % Generate detections for each sensor
    for sensorIndex = 1:numSensors
        sensor = sensors{sensorIndex};
        % Generate the ego vehicle lane boundaries
        if isa(sensor, 'visionDetectionGenerator')
            maxLaneDetectionRange = min(500,sensor.MaxRange);
            lanes = laneBoundaries(egoVehicle, 'XDistance', linspace(-maxLaneDetectionRange, maxLaneDetectionRange, 101));
        end
        type = getDetectorOutput(sensor);
        if strcmp(type, 'Objects only')
            if isa(sensor,'ultrasonicDetectionGenerator')
                [objectDets, isValidTime(sensorIndex)] = sensor(poses, time);
                numObjects = length(objectDets);
            else
                [objectDets, numObjects, isValidTime(sensorIndex)] = sensor(poses, time);
            end
            objectDetections = [objectDetections; objectDets(1:numObjects)]; %#ok<AGROW>
        elseif strcmp(type, 'Lanes only')
            [laneDets, ~, isValidTime(sensorIndex)] = sensor(lanes, time);
            laneDetections   = [laneDetections laneDets]; %#ok<AGROW>
        elseif strcmp(type, 'Lanes and objects')
            [objectDets, numObjects, isValidTime(sensorIndex), laneDets, ~, isValidLaneTime(sensorIndex)] = sensor(poses, lanes, time);
            objectDetections = [objectDetections; objectDets(1:numObjects)]; %#ok<AGROW>
            laneDetections   = [laneDetections laneDets]; %#ok<AGROW>
        elseif strcmp(type, 'Lanes with occlusion')
            [laneDets, ~, isValidLaneTime(sensorIndex)] = sensor(poses, lanes, time);
            laneDetections   = [laneDetections laneDets]; %#ok<AGROW>
        elseif strcmp(type, 'PointCloud')
            if sensor.HasRoadsInputPort
                rdmesh = roadMesh(egoVehicle,min(500,sensor.MaxRange));
                [ptCloud, isValidPointCloudTime(sensorIndex)] = sensor(poses, rdmesh, time);
            else
                [ptCloud, isValidPointCloudTime(sensorIndex)] = sensor(poses, time);
            end
            ptClouds = [ptClouds; ptCloud]; %#ok<AGROW>
        elseif strcmp(type, 'INSMeasurement')
            insMeasCurrent = sensor(actorState, time);
            insMeas = [insMeas; insMeasCurrent]; %#ok<AGROW>
            isValidINSTime(sensorIndex) = true;
        end
    end

    % Aggregate all detections into a structure for later use
    if any(isValidTime) || any(isValidLaneTime) || any(isValidPointCloudTime) || any(isValidINSTime)
        allData(end + 1) = struct( ...
            'Time',       scenario.SimulationTime, ...
            'ActorPoses', actorPoses(scenario), ...
            'ObjectDetections', {objectDetections}, ...
            'LaneDetections', {laneDetections}, ...
            'PointClouds',   {ptClouds}, ... %#ok<AGROW>
            'INSMeasurements',   {insMeas}); %#ok<AGROW>
    end

    % Advance the scenario one time step and exit the loop if the scenario is complete
    running = advance(scenario);
end

% Restart the driving scenario to return the actors to their initial positions.
restart(scenario);

% Release all the sensor objects so they can be used again.
for sensorIndex = 1:numSensors
    release(sensors{sensorIndex});
end

%%%%%%%%%%%%%%%%%%%%
% Helper functions %
%%%%%%%%%%%%%%%%%%%%

% Units used in createSensors and createDrivingScenario
% Distance/Position - meters
% Speed             - meters/second
% Angles            - degrees
% RCS Pattern       - dBsm

function [sensors, numSensors] = createSensors(scenario)
% createSensors Returns all sensor objects to generate detections

% Assign into each sensor the physical and radar profiles for all actors
profiles = actorProfiles(scenario);
sensors{1} = visionDetectionGenerator('SensorIndex', 1, ...
    'SensorLocation', [3.7 0], ...
    'MaxRange', 100, ...
    'DetectorOutput', 'Lanes and objects', ...
    'Intrinsics', cameraIntrinsics([1814.81018227767 1814.81018227767],[320 240],[480 1000]), ...
    'ActorProfiles', profiles);
sensors{2} = visionDetectionGenerator('SensorIndex', 2, ...
    'SensorLocation', [-1 0], ...
    'Yaw', -180, ...
    'MaxRange', 100, ...
    'DetectorOutput', 'Objects only', ...
    'Intrinsics', cameraIntrinsics([1814.81018227767 1814.81018227767],[320 240],[480 1000]), ...
    'ActorProfiles', profiles);
sensors{3} = lidarPointCloudGenerator('SensorIndex', 3, ...
    'SensorLocation', [1.5 0], ...
    'EgoVehicleActorID', 3, ...
    'ActorProfiles', profiles);
numSensors = 3;

function [scenario, egoVehicle] = createDrivingScenario
% createDrivingScenario Returns the drivingScenario defined in the Designer

% Construct a drivingScenario object.
scenario = drivingScenario;

% Add all road segments
roadCenters = [57.6 -0.3 0;
    26 0.4 0;
    -2.7 -0.3 0];
laneSpecification = lanespec(2, 'Width', 7.425);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road');

% Add the barriers
barrierCenters = [53.4 5.9 0;
    53.4 0.9 0];
barrier(scenario, barrierCenters, ...
    'ClassID', 5, ...
    'Width', 0.61, ...
    'Height', 0.81, ...
    'Mesh', driving.scenario.jerseyBarrierMesh, 'PlotColor', [0.65 0.65 0.65], 'Name', 'Jersey Barrier');

% Add the actors
vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [47.8 3.5 0], ...
    'Mesh', driving.scenario.carMesh, ...
    'Name', 'Car');

targetCar = vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [28.4984539004466 3.5039468991367 0], ...
    'Mesh', driving.scenario.carMesh, ...
    'Name', 'TargetCar');
waypoints = [28.4984539004466 3.5039468991367 0;
    35.2 3.5 0;
    39.1 3.4 0;
    42.3 3.4 0];
speed = [30;20;10;0];
waittime = [0;0;0;0];
trajectory(targetCar, waypoints, speed, waittime);

% Add the ego vehicle
egoVehicle = vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [13.7555231616355 3.39963977515666 0], ...
    'Mesh', driving.scenario.carMesh, ...
    'Name', 'Car2');
waypoints = [13.7555231616355 3.39963977515666 0;
    22.2 3.5 0;
    27.2 3.5 0;
    32.1 3.4 0;
    35.6 3.4 0];
speed = [50;40;30;15;0];
waittime = [0;0;0;0;0];
trajectory(egoVehicle, waypoints, speed, waittime);

truck = vehicle(scenario, ...
    'ClassID', 2, ...
    'Length', 8.2, ...
    'Width', 2.5, ...
    'Height', 3.5, ...
    'Position', [2.08741210677921 -3.42991926785201 0], ...
    'RearOverhang', 1, ...
    'FrontOverhang', 0.9, ...
    'Mesh', driving.scenario.truckMesh, ...
    'Name', 'Truck');
waypoints = [2.08741210677921 -3.42991926785201 0;
    15.7 -3.1 0;
    21.6 -3.1 0;
    27.3 -3.2 0;
    33.6 -3.1 0];
speed = [30;30;30;30;30];
trajectory(truck, waypoints, speed);

function output = getDetectorOutput(sensor)

if isa(sensor, 'visionDetectionGenerator')
    output = sensor.DetectorOutput;
elseif isa(sensor, 'lidarPointCloudGenerator')
    output = 'PointCloud';
elseif isa(sensor, 'insSensor')
    output = 'INSMeasurement';
else
    output = 'Objects only';
end

