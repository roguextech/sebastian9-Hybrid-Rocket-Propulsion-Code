%% Main
clear all; clc; close all
% Global varialbes
global env
global log
% Create rocket class
DTF = rocket(init_rocket());% creates class with the initial values
%%
motor_init( DTF ); %loads rocket motor
%%
% Initilize Environmental variables
% optional argument: Elevation(m) Temperature(C)and Pressure(Pa)
env = environement(350, 15, 86000, DTF);
%% Phase: Accent
tend=30;
[t, state] = accent_calc(DTF,tend);
%%
% figure(1);
plot(t,state(:,3))
xlabel('Time(s)')
ylabel('Height (m)')
%
figure(2);
plot3(state(:,1),state(:,2),state(:,3))
xlabel('x(m)')
ylabel('y (m)')
zlabel('Height (m)')
axis([-500 500 -500 500 0 800])
h_max=max(state(:,3))
%%
extract_data(state,t);
%% Debugging plots
% figure(3)
%
% plot(log(:,10),log(:,2))
% 
% xlabel('Time')
% ylabel('Value1, Value2')
% %axis([0 20 0.0 1])
% %
% figure(4)
% plot(log(:,10),log(:,1))
% xlabel('Time')
% ylabel('Value1, Value2')
%% Plot flight and stability data
