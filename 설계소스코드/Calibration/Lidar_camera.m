clc; close all; clear;
%% Original PointCloud Velodyne 
ptCloud = pcread('1621940222454757.pcd');
figure
pcshow(ptCloud)
xlabel('X')
ylabel('Y')
zlabel('Z')

%% Extract XYZ data
data = ptCloud.Location;
x_data = data(:,1);
y_data = data(:,2);
z_data = data(:,3);

x_lidar = (x_data);
y_lidar = (y_data);
z_lidar = (z_data);

%% Limits of data
x_data(x_lidar<0) = [];
y_data(x_lidar<0) = [];
z_data(x_lidar<0) = [];
ptCloud_2 = pointCloud([x_data' ; y_data' ; z_data']');

%% Plot data to process 
figure
pcshow(ptCloud_2)

%% Limit PointCloud only in range of the camera
j = 1;
for i = 1:length(x_data)    
    ang = abs(atan(x_data(i) / y_data(i)));
    if(ang > 0.9 && ang < 1.6)
        z_arr(j) = z_data(i);
        y_arr(j) = y_data(i);
        x_arr(j) = x_data(i);
        j = j + 1;
    end
end

x_data = x_arr';
y_data = y_arr';
z_data = z_arr';

figure
plot3(x_data, y_data, z_data, '.')
grid on
xlabel('X')
ylabel('Y')
zlabel('Z')
title('Point Cloud in angle camera range')
axis equal; 

%% Camera Matrix calibration 
Mc = [ 893.509583 0.000000 632.748104 0.000000;
       0.000000 910.772888 393.341688 0.000000;
       0.000000 0.000000 1.000000 0.000000];

%% Matrix rotation Lidar-camera
Rlc = [0.999478 0.0301283 0.0116781;
       -0.0240397 0.9348230 -0.3542980;
       -0.0215914 0.3538320 0.9350600];    

%% Matrix translation Lidar-camera
Tlc = [0.0103788;
       -0.00362065;
       -0.0790913];

%% Matrix rotation translation  
R_T_lc = [[Rlc Tlc]; 0 0 0 1];

%% Matrix lidar data referring to camera data
lidar_data = [-y_data'; -z_data'; x_data'; ones(size(x_data))'];

%% Transform Lidar data to image data
trans = Mc * R_T_lc * lidar_data;

px = round(trans(1,:) ./ trans(3,:)); 
py = round(trans(2,:) ./ trans(3,:)); 

%% Filter based on px, py conditions
valid_indices = ~(px < 0 | px > 1280 | py < 0 | py > 720);
ax = px(valid_indices); 
by = py(valid_indices);
x_data = x_data(valid_indices);
y_data = y_data(valid_indices);
z_data = z_data(valid_indices);

%% Plot data transformation on image 
figure
c = imread('frame0.jpg');
image(c);
axis on
hold on
plot(ax, by, '.')

%% Blue Representation
figure
plot3(x_lidar, y_lidar, z_lidar, 'g.')
hold on
% 여기서 x_data, y_data, z_data를 사용
plot3(x_data, y_data, z_data, 'b.')
% bluePlot 함수에 대한 정의가 필요합니다.
% bluePlot(-0.70, 0, -1.05, 0, 0, 0.001);
legend('3D-LiDAR data', 'PointCloud in camera range')
grid on
xlabel('X')
ylabel('Y')
zlabel('Z')
title('LiDAR 3D + Cámara')
axis equal;
camlight('headlight');
xlim([-2 40])
ylim([-10 10])
zlim([-2 10])

%% Color representation 
figure
c = imread('frame0.jpg');
a = image(c);
axis on
hold on
grid minor
grid on

 for i=1:length(x_data)
     if (x_data(i)<2)
        color = [1,0,0];  
     elseif (x_data(i)<4 && x_data(i)>=2)
        color = [0.8,0.2,0];  
     elseif (x_data(i)<6 && x_data(i)>=4)
        color = [0.5,0.5,0];  
     elseif (x_data(i)<8 && x_data(i)>=6)
        color = [0.2,0.8,0]; 
     elseif (x_data(i)<10 && x_data(i)>=8)
        color = [0,1,0]; 
     elseif (x_data(i)<12 && x_data(i)>=10)
        color = [0,0.8,0.2]; 
     elseif (x_data(i)<14 && x_data(i)>=12)
        color = [0.2,0.5,0.5]; 
     elseif (x_data(i)<16 && x_data(i)>=14)
        color = [0,0.2,0.8];  
     elseif (x_data(i)>=16)
        color = [0,0,1];  
     end
     plot (ax(i),by(i),'.','Color',color)
 hold on
 end
