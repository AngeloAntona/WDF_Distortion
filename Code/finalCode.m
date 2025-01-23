clear; close all; clc

%% Simscape File for Ground Truth
load('ssc_output.mat')

%% Sampling Frequency
fs = 96e3;

%% Sampling Period
Ts = 1/fs;

%% Simulation Duration
stop_time = 1;  % [seconds]

%% Input Signal
% Fundamental Frequency
f0 = 440;

% Time Axis
t = 0:Ts:stop_time;

% Signal Amplitude
A = 1.5;
vin = A * sin(2*pi*f0*t);

% Music Signal Test (Uncomment the following lines for test)
%[vin, fs_rec] = audioread('guitar_input.wav');
%vin_clean = vin;
%G = 5;                                  % Gain factor 
%vin = G * (vin(:, 1) + vin(:, 2))/2;    % Convert the signal to MONO
%vin = resample(vin, fs, fs_rec);        % Resampling the signal from 44.1 kHz to 96 kHz
%t = 0:Ts:Ts*(length(vin)-1);

%% Circuit Parameters
Rin  =   1;
R1   =   1e4;
Rout =   1e4;
C1   =   1e-6;
C2   =   1e-9;

% Adaptation Conditions
Z11  =   R1;
Z12  =   Rin;
Z9   =   Ts / (2 * C1);
Z6   =   Rout;
Z5   =   Ts / (2 * C2);

% Make Ports of Adaptors Reflection-Free 
Z4   =   (Z5 * Z6) / (Z5 + Z6);
Z3   =   Z4;
Z10  =   Z11 + Z12;
Z8   =   Z10;
Z7   =   Z8 + Z9;
Z2   =   Z7;
Z1   =   (Z3 * Z2) / (Z3 + Z2);

%% Computing Scattering Matrices

% Series adapter S2 (port 10, 11, 12)
gammaSer2 = Z11/(Z11+Z12);
Sser2 = [       0        ,       -1       ,      -1       ;
         -gammaSer2      ,  (1-gammaSer2) ,  -gammaSer2   ;
        (gammaSer2-1)    ,  (gammaSer2-1) ,   gammaSer2   ];

% Series adapter S1 (port 7, 8, 9)
gammaSer1 = Z8/(Z8+Z9);
Sser1 = [      0         ,       -1       ,      -1       ;
          -gammaSer1     ,  (1-gammaSer1) ,  -gammaSer1   ;
          (gammaSer1-1)  ,  (gammaSer1-1) ,   gammaSer1   ];

% Parallel adapter P2 (port 4, 5, 6)
gammaPar2 = Z5/(Z5+Z6);
Spar2 = [    0    ,  (1-gammaPar2) ,   gammaPar2   ;
             1    ,   -gammaPar2   ,   gammaPar2   ;
             1    ,  (1-gammaPar2) , (gammaPar2-1) ];

% Parallel adapter P1 (port 1, 2, 3)
gammaPar1 = Z2/(Z2+Z3);
Spar1 = [    0    ,  (1-gammaPar1) ,   gammaPar1    ;
             1    ,   -gammaPar1   ,   gammaPar1    ;
             1    ,  (1-gammaPar1) , (gammaPar1-1)  ];

%% Initialization of Waves
a1 = 0; a2 = 0; a3 = 0; b1 = 0; b2 = 0; b3 = 0;
a4 = 0; a5 = 0; a6 = 0; b4 = 0; b5 = 0; b6 = 0;
a7 = 0; a8 = 0; a9 = 0; b7 = 0; b8 = 0; b9 = 0;
a10 = 0; a11 = 0; a12 = 0; b10 = 0; b11 = 0; b12 = 0;

%% Initialization of Output Signals
vout = zeros(1, length(t));

%% Simulation Algorithm
for n = 1:length(t)

    % Dynamic elements
    a5 = b5; % port 5 (P2) < - > C2
    a9 = b9; % port 9 (S1) < - > C1

    % ------------ FORWARD SCAN --------------

    % SERIES ADAPTER S2
    a12 = vin(n); % Input wave at port 12
    b10 = Sser2(1,:)*[0; a11; a12]; % port 11 <-> R1, port 12 <-> input stage

    a8 = b10; % S1 < - > S2

    % SERIES ADAPTER S1
    b7 = Sser1(1,:)*[0; a8; a9]; % port 8 <-> S1, port 9 <-> C1

    % PARALLEL ADAPTER P2
    b4 = Spar2(1,:)*[0; a5; a6];  
    
    a2 = b7; % P1 < - > S1
    a3 = b4; % P1 < - > P2

    % PARALLEL ADAPTER P1
    b1 = Spar1(1,:)*[0; a2; a3];
    
    % --------- ANTIPARALLEL DIODES -----------

    a1 = antiparallel_diodes(b1, Z1);
    
    % ------------ BACKWARD SCAN --------------

    % PARALLEL ADAPTER P1
    b2 = Spar1(2,:)*[a1; a2; a3];
    b3 = Spar1(3,:)*[a1; a2; a3];

    a4 = b3; % P1 < - > P2
    a7 = b2; % P1 < - > S1

    % SERIES ADAPTER S1
    b8 = Sser1(2,:)*[a7; a8; a9];
    b9 = Sser1(3,:)*[a7; a8; a9];

    a10 = b8; % S1 < - > S2
    
    % SERIES ADAPTER S2
    b11 = Sser2(2,:)*[a10; a11; a12];
    b12 = Sser2(3,:)*[a10; a11; a12];
    
    % PARALLEL ADAPTER P2
    b5 = Spar2(2,:)*[a4; a5; a6];
    b6 = Spar2(3,:)*[a4; a5; a6];
    
    % Read Output
    vout(n) = (a6 + b6) / 2;
end

%% Uncomment the following line to hear the Diode Clipper
% sound(vout, fs)

%% Output Plots
plot_lim = 5 / f0; % Limit the plot to just 5 periods of the output signal

figure
set(gcf, 'Color', 'w');
plot(gt(1, :), gt(2, :), 'r', 'Linewidth', 2);
hold on;
plot(t, vout, 'b--', 'Linewidth', 2);
grid on;
xlim([0, plot_lim]);
xlabel('Time [seconds]','Fontsize',16,'interpreter','latex');
ylabel('$V_{\mathrm{out}}$ [V]','Fontsize',16,'interpreter','latex');
legend('Simscape','WDF','Fontsize',16,'interpreter','latex');
title('Output Signal','Fontsize',18,'interpreter','latex');

%% Error Plots
figure
set(gcf, 'Color', 'w');
hold on;
plot(t, vout - gt(2, :), 'k', 'Linewidth', 2);
grid on;
xlim([0, plot_lim]);
xlabel('Time [seconds]','Fontsize',16,'interpreter','latex');
ylabel('$E_{\mathrm{out}}$ [V]','Fontsize',16,'interpreter','latex');
title('Error Signal','Fontsize',18,'interpreter','latex');

%% Compute Mean Squared Error (MSE)
mse = mean((vout - gt(2, :)).^2);
disp('MSE = ')
disp(mse)